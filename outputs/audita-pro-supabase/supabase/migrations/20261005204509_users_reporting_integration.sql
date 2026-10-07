-- Use real aggregate counts in the organization directory, and freeze the
-- audit team with each finalized daily report version.
begin;

create or replace function public.organization_member_counts(target_organizations uuid[])
returns table(organization_id uuid,member_count bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.is_platform_admin() then
    raise exception 'Acesso não autorizado' using errcode='42501';
  end if;
  if cardinality(target_organizations)>100 then
    raise exception 'Limite de organizações excedido';
  end if;
  return query select o.id,count(m.id) from public.organizations o
    left join public.organization_memberships m on m.organization_id=o.id
    where o.id=any(target_organizations) group by o.id;
end;
$$;
revoke all on function public.organization_member_counts(uuid[]) from public;
grant execute on function public.organization_member_counts(uuid[]) to authenticated;

create or replace function public.finalize_daily_report(target_report uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  current_report public.daily_reports%rowtype;
  report_day public.audit_days%rowtype;
  next_version integer;
  version_id uuid;
  frozen_content jsonb;
  team jsonb;
begin
  select * into current_report from public.daily_reports where id=target_report for update;
  if not found or not private.is_audit_leader(current_report.audit_id) then
    raise exception 'Relatório inexistente ou usuário sem permissão de auditor líder';
  end if;
  if current_report.status not in ('draft','review') then
    raise exception 'Relatório não está em estado editável';
  end if;
  select * into report_day from public.audit_days where id=current_report.audit_day_id;
  select coalesce(jsonb_agg(jsonb_build_object('membership_id',people.membership_id,
    'name',people.full_name,'role',people.participant_type) order by people.full_name),'[]'::jsonb)
    into team from (
      select distinct on (h.membership_id) h.membership_id,h.full_name,h.participant_type
      from public.audit_participant_history h
      where h.audit_id=current_report.audit_id
        and h.occurred_at < (report_day.audit_date + 1)::timestamptz
        and h.active
        and not exists (
          select 1 from public.audit_participant_history later
          where later.audit_id=h.audit_id and later.membership_id=h.membership_id
            and later.occurred_at>h.occurred_at
            and later.occurred_at<report_day.audit_date::timestamptz
            and not later.active
        )
      order by h.membership_id,h.occurred_at desc
    ) people;
  frozen_content := case when jsonb_typeof(current_report.content)='object'
    then current_report.content else jsonb_build_object('original_content',current_report.content) end;
  frozen_content := frozen_content || jsonb_build_object('team_snapshot',team);
  select coalesce(max(version_number),0)+1 into next_version
    from public.daily_report_versions where report_id=target_report;
  insert into public.daily_report_versions(report_id,version_number,content,checksum,created_by)
    values(target_report,next_version,frozen_content,
      encode(extensions.digest(convert_to(frozen_content::text,'UTF8'),'sha256'),'hex'),auth.uid())
    returning id into version_id;
  insert into public.report_acknowledgements(report_version_id,membership_id)
    select version_id,ap.membership_id from public.audit_participants ap
    where ap.audit_id=current_report.audit_id and ap.active and ap.is_signatory;
  if not found then raise exception 'Defina ao menos um signatário antes de finalizar'; end if;
  insert into public.notification_outbox(acknowledgement_id,channel,scheduled_at)
    select a.id,c.channel,t.scheduled_at from public.report_acknowledgements a
    cross join (values ('email'::text),('in_app'::text)) c(channel)
    cross join (values (now()),(now()+interval '24 hours'),(now()+interval '48 hours')) t(scheduled_at)
    where a.report_version_id=version_id;
  update public.daily_reports set status='pending_acknowledgements',
    finalized_by=auth.uid(),finalized_at=now() where id=target_report;
  return version_id;
end;
$$;
revoke all on function public.finalize_daily_report(uuid) from public;
grant execute on function public.finalize_daily_report(uuid) to authenticated;

commit;
