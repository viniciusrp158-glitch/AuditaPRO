-- Recuperada de supabase_migrations.schema_migrations em 2026-10-10 (B00, Claude).
-- JA APLICADA no projeto zlckcpeqcxmtrgbdquee. NAO reaplicar. md5(statements)=1fe539b9fe51b1d23f35d661a73ff34c

-- B02 / READ-1: restrictive barriers also protect direct PostgREST/Storage access.
-- Readers use whitelisted RPC projections instead of whole operational rows.
create policy b02_audit_projection on public.audits as restrictive for select to authenticated using(private.workspace_conductor(id));

create policy b02_assessments_internal on public.requirement_assessments as restrictive for select to authenticated using(private.checklist_internal(audit_id));

create policy b02_evidence_original on public.evidence_files as restrictive for select to authenticated using(private.b02_original_access(audit_id));

create policy b02_checklists_internal on public.audit_checklists as restrictive for select to authenticated using(private.checklist_internal(audit_id));

create policy b02_team_internal on public.audit_participants as restrictive for select to authenticated using(private.checklist_internal(audit_id));

create policy b02_team_history_internal on public.audit_participant_history as restrictive for select to authenticated using(private.checklist_internal(audit_id));

create policy b02_days_internal on public.audit_days as restrictive for select to authenticated using(private.checklist_internal(audit_id));

create policy b02_processes_internal on public.audit_processes as restrictive for select to authenticated using(private.checklist_internal(audit_id));

create policy b02_findings_internal on public.nonconformities as restrictive for select to authenticated using(private.checklist_internal(audit_id));

create policy b02_actions_internal on public.action_plans as restrictive for select to authenticated using(exists(select 1 from public.nonconformities n where n.id=nonconformity_id and private.checklist_internal(n.audit_id)));

create policy b02_schedule_internal on public.schedule_items as restrictive for select to authenticated using(exists(select 1 from public.audit_days d where d.id=audit_day_id and private.checklist_internal(d.audit_id)));

-- Full document rows may include draft/private source-only fields; public reads use audit_documents.
create policy b02_daily_projection on public.daily_reports as restrictive for select to authenticated using(private.workspace_conductor(audit_id));

create policy b02_final_projection on public.audit_final_reports as restrictive for select to authenticated using(private.workspace_conductor(audit_id));

create policy b02_notification_scope on public.in_app_notifications as restrictive for select to authenticated using(entity_type is distinct from 'audit' or private.b02_scope(entity_id));

-- Even legacy direct team editing cannot change customer grants via leader authority.
create policy b02_team_admin_insert on public.audit_participants as restrictive for insert to authenticated with check(private.profile_admin(auth.uid()));

create policy b02_team_admin_update on public.audit_participants as restrictive for update to authenticated using(private.profile_admin(auth.uid())) with check(private.profile_admin(auth.uid()));

create policy b02_team_admin_delete on public.audit_participants as restrictive for delete to authenticated using(private.profile_admin(auth.uid()));

-- Self science remains reachable even while the parent report has a successor draft.
drop policy acknowledgements_read on public.report_acknowledgements;

create policy acknowledgements_read on public.report_acknowledgements for select to authenticated using(
 private.b02_scope(private.audit_id_for_report_version(report_version_id)) and
 (private.workspace_conductor(private.audit_id_for_report_version(report_version_id)) or exists(select 1 from public.organization_memberships m where m.id=membership_id and m.user_id=auth.uid()))
);

-- Fix legacy workspace write barriers: RLS on the parent must not turn NOT EXISTS into permission.
create function private.b02_is_workspace(aid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select workspace_version>0 from public.audits where id=aid),true);
$$;

do $$declare tbl text;begin
 foreach tbl in array array['audit_participants','audit_days','audit_processes','audit_checklists','requirement_assessments','evidence_files','daily_reports','audit_final_reports'] loop
  execute format('alter policy workspace_write_insert on public.%I with check (not private.b02_is_workspace(audit_id))',tbl);
  execute format('alter policy workspace_write_update on public.%I using (not private.b02_is_workspace(audit_id)) with check (not private.b02_is_workspace(audit_id))',tbl);
  execute format('alter policy workspace_write_delete on public.%I using (not private.b02_is_workspace(audit_id))',tbl);
 end loop;
end;$$;

-- Resource registry rather than path prefix decides original file and published report access.
create function private.b02_storage_read(bucket text,object_name text) returns boolean
language sql stable security definer set search_path='' as $$
 select case bucket
 when 'audit-evidence' then exists(select 1 from public.evidence_files e where e.storage_path=object_name and private.b02_original_access(e.audit_id))
 when 'audit-evidence-workspace' then false -- authenticated edge authorization only
 when 'audit-reports' then false -- only the authenticated download broker issues a fixed TTL
 else true end;
$$;

create policy b02_storage_resource on storage.objects as restrictive for select to authenticated using(private.b02_storage_read(bucket_id,name));

-- Document registries may be read without opening raw snapshot content.
drop policy report_files_read on public.report_external_files;

create policy report_files_read on public.report_external_files for select to authenticated using(exists(select 1 from public.daily_reports r where r.id=report_id and private.workspace_document_access(r.id,'daily',r.audit_id,r.finalized_at is not null)));

-- Function below avoids parent-RLS suppression for the dedicated artifact reader in later blocks.
create function public.audit_published_files(target_audit uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.b02_scope(target_audit) then raise exception 'Documento indisponível' using errcode='42501';end if;
 return coalesce((select jsonb_agg(x) from (
 select f.id,r.id document_id,'daily' kind,f.storage_path from public.report_external_files f join public.daily_reports r on r.id=f.report_id
 where r.audit_id=target_audit and private.workspace_document_access(r.id,'daily',r.audit_id,r.finalized_at is not null)
 union all
 select f.id,r.id,'final',f.storage_path from public.audit_final_report_files f join public.audit_final_reports r on r.id=f.report_id
 where r.audit_id=target_audit and private.workspace_document_access(r.id,'final',r.audit_id,r.finalized_at is not null)
 )x),'[]');
end;$$;

revoke all on function public.audit_published_files(uuid) from public,anon;

grant execute on function public.audit_published_files(uuid) to authenticated;

-- Legacy audit rows must not permit direct leader transfer/reopen by a leader.
create function private.b02_audit_governance() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is not null and not private.profile_admin(auth.uid()) and
 (new.leader_membership_id is distinct from old.leader_membership_id or
  (old.status in ('completed','awaiting_signoff','cancelled') and new.status in ('draft','planned','in_progress'))) then
  raise exception 'Transferência e reabertura exigem Administração' using errcode='42501';
 end if;
 return new;
end;$$;

create trigger b02_audit_governance before update on public.audits for each row execute function private.b02_audit_governance();

-- RLS executes as caller; only boolean authorization helpers are callable by authenticated.
revoke all on function private.b02_scope(uuid),private.b02_original_access(uuid),private.b02_is_workspace(uuid),private.b02_storage_read(text,text) from public,anon;

grant execute on function private.b02_scope(uuid),private.b02_original_access(uuid),private.b02_is_workspace(uuid),private.b02_storage_read(text,text),private.workspace_conductor(uuid),private.checklist_internal(uuid) to authenticated;

revoke all on function private.b02_audit_governance() from public,anon,authenticated;

-- Edge writes evidence using service_role after user authorization. Recheck the
-- real uploader against CURRENT account/grant state while holding the audit lock.
create or replace function private.checklist_evidence_guard() returns trigger
language plpgsql security definer set search_path='' as $$
declare a public.audits%rowtype; r public.requirement_assessments%rowtype;
begin
 select * into a from public.audits where id=new.audit_id for update;
 select * into r from public.requirement_assessments where id=new.assessment_id;
 if r.question_id is not null or r.extra_question_id is not null then
  if a.status<>'in_progress' or r.operational_state='completed' or exists(select 1 from public.audit_days where id=r.audit_day_id and status='completed') then raise exception 'Avaliação encerrada para anexos';end if;
  if not (private.profile_admin(new.uploaded_by) or exists(
   select 1 from public.organization_memberships m join public.audit_participants ap on ap.membership_id=m.id and ap.audit_id=a.id
   where m.id=a.leader_membership_id and m.organization_id=a.organization_id and m.user_id=new.uploaded_by
   and ap.active and private.b02_member_ready(m.id) and private.b02_profile_role(m.access_profile_id)='leader'
   and private.b02_member_permission(m.id,'audit.update'))) then raise exception 'Autor sem autorização atual para anexar';end if;
 end if;
 update public.assessment_uploads set status='completed',updated_at=now() where operation_id=new.operation_id and assessment_id=new.assessment_id;
 return new;
end;$$;

-- Only authorization metadata crosses RPC. Browser cannot sign/download this
-- bucket directly; the Edge broker reauthorizes as caller and signs with TTL 60.
create function public.audit_document_file_access(target_file uuid,document_kind text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not private.is_active_account(auth.uid()) then raise exception 'Arquivo indisponível' using errcode='42501';end if;
 if document_kind='daily' then
  select jsonb_build_object('bucket','audit-reports','path',f.storage_path,'document_id',r.id,'audit_id',r.audit_id) into result
  from public.report_external_files f join public.daily_reports r on r.id=f.report_id
  where f.id=target_file and private.workspace_document_access(r.id,'daily',r.audit_id,r.finalized_at is not null);
 elsif document_kind='final' then
  select jsonb_build_object('bucket','audit-reports','path',f.storage_path,'document_id',r.id,'audit_id',r.audit_id) into result
  from public.audit_final_report_files f join public.audit_final_reports r on r.id=f.report_id
  where f.id=target_file and private.workspace_document_access(r.id,'final',r.audit_id,r.finalized_at is not null);
 end if;
 if result is null then raise exception 'Arquivo indisponível' using errcode='42501';end if;
 return result;
end;$$;

revoke all on function public.audit_document_file_access(uuid,text) from public,anon;

grant execute on function public.audit_document_file_access(uuid,text) to authenticated;
