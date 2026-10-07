-- Audita PRO — consultas consolidadas e exclusivamente administrativas do Dashboard.
-- SECURITY INVOKER mantém as policies RLS das tabelas base ativas.
begin;

create or replace function public.dashboard_admin_summary()
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  dashboard_data jsonb;
begin
  if not public.is_platform_admin() then
    raise exception 'Acesso exclusivo ao Dashboard do Administrador'
      using errcode = '42501';
  end if;

  with checklist_items as (
    select distinct a.id as audit_id, req.id as requirement_id
    from public.audit_checklists ac
    join public.audits a on a.id = ac.audit_id
    join public.checklist_revisions rev on rev.id = ac.revision_id
    join public.checklist_sections sec on sec.revision_id = rev.id
    join public.checklist_requirements req on req.section_id = sec.id
  ), latest_assessments as (
    select distinct on (ra.audit_id,ra.requirement_id)
      ra.audit_id,ra.requirement_id,ra.result
    from public.requirement_assessments ra
    join checklist_items ci
      on ci.audit_id = ra.audit_id and ci.requirement_id = ra.requirement_id
    order by ra.audit_id,ra.requirement_id,ra.updated_at desc,ra.created_at desc,ra.id desc
  ), item_states as (
    select ci.audit_id,ci.requirement_id,coalesce(la.result,'not_assessed') as result
    from checklist_items ci
    left join latest_assessments la
      on la.audit_id = ci.audit_id and la.requirement_id = ci.requirement_id
  ), checklist_metrics as (
    select count(*)::integer as total,
      count(*) filter (where result='conforming')::integer as conforming,
      count(*) filter (where result='partially_conforming')::integer as partially_conforming,
      count(*) filter (where result='nonconforming')::integer as nonconforming,
      count(*) filter (where result='improvement')::integer as improvement,
      count(*) filter (where result='not_assessed')::integer as not_assessed,
      count(*) filter (where result='not_applicable')::integer as not_applicable,
      (count(*) filter (where result in ('conforming','partially_conforming','nonconforming','improvement')))::integer as evaluated
    from item_states
  ), items_by_audit as (
    select audit_id,count(*)::integer as total,
      count(*) filter (where result='conforming')::integer as conforming,
      count(*) filter (where result='partially_conforming')::integer as partially_conforming,
      count(*) filter (where result='nonconforming')::integer as nonconforming,
      count(*) filter (where result='improvement')::integer as improvement,
      count(*) filter (where result='not_assessed')::integer as not_assessed,
      count(*) filter (where result='not_applicable')::integer as not_applicable,
      (count(*) filter (where result in ('conforming','partially_conforming','nonconforming','improvement')))::integer as evaluated
    from item_states group by audit_id
  ), audits_metrics as (
    select count(*)::integer as total,
      count(*) filter (where status='in_progress')::integer as in_progress,
      count(*) filter (where status='planned')::integer as scheduled,
      count(*) filter (where status='completed')::integer as completed,
      count(*) filter (where status='awaiting_signoff')::integer as awaiting_signoff,
      count(*) filter (where end_date < current_date and status not in ('completed','cancelled'))::integer as overdue
    from public.audits
  ), nonconformity_metrics as (
    select count(*)::integer as total,
      count(*) filter (where n.status='open')::integer as open,
      count(*) filter (where n.status in ('action_planned','in_progress'))::integer as in_treatment,
      count(*) filter (where n.status='pending_review')::integer as awaiting_verification,
      count(*) filter (where n.status='closed')::integer as closed,
      count(*) filter (where n.status<>'closed' and exists (
        select 1 from public.action_plans ap
        where ap.nonconformity_id=n.id and ap.due_date < current_date
          and ap.status not in ('completed','approved')
      ))::integer as overdue
    from public.nonconformities n
  ), action_metrics as (
    select count(*) filter (where status not in ('completed','approved'))::integer as active,
      count(*) filter (where status not in ('completed','approved') and due_date < current_date)::integer as overdue,
      count(*) filter (where status not in ('completed','approved') and due_date between current_date and current_date+7)::integer as due_soon,
      count(*) filter (where status not in ('completed','approved') and due_date >= current_date+8)::integer as on_time
    from public.action_plans
  ), team_by_audit as (
    select ap.audit_id,jsonb_agg(jsonb_build_object(
      'name',coalesce(nullif(trim(up.full_name),''),'Participante'),
      'role',ap.participant_type
    ) order by ap.added_at) as team
    from public.audit_participants ap
    join public.organization_memberships m on m.id=ap.membership_id
    left join public.user_profiles up on up.user_id=m.user_id
    where ap.active and m.status='active'
    group by ap.audit_id
  ), active_audits as (
    select a.id,a.organization_id,a.code,a.title,a.scope,a.standards,a.start_date,a.end_date,a.status,
      o.legal_name,o.trade_name,o.cnpj,
      coalesce(nullif(trim(leader_profile.full_name),''),'Responsável não identificado') as leader_name,
      coalesce(ib.total,0) as checklist_total,
      coalesce(ib.evaluated,0) as checklist_evaluated,
      coalesce(ib.conforming,0) as conforming,
      coalesce(ib.partially_conforming,0) as partially_conforming,
      coalesce(ib.nonconforming,0) as nonconforming,
      coalesce(ib.improvement,0) as improvement,
      coalesce(ib.not_assessed,0) as not_assessed,
      coalesce(ib.not_applicable,0) as not_applicable,
      case when coalesce(ib.total,0)=0 then 0
        when coalesce(ib.total,0)=coalesce(ib.not_applicable,0) then 100
        else round(100.0*coalesce(ib.evaluated,0)/nullif(ib.total-ib.not_applicable,0),1)
      end as progress_percent,
      coalesce(nc.nonconformity_count,0) as nonconformity_count,
      coalesce(t.team,'[]'::jsonb) as team
    from public.audits a
    join public.organizations o on o.id=a.organization_id
    left join public.organization_memberships leader on leader.id=a.leader_membership_id
    left join public.user_profiles leader_profile on leader_profile.user_id=leader.user_id
    left join items_by_audit ib on ib.audit_id=a.id
    left join lateral (
      select count(*)::integer as nonconformity_count
      from public.nonconformities n where n.audit_id=a.id
    ) nc on true
    left join team_by_audit t on t.audit_id=a.id
    where a.status in ('in_progress','awaiting_signoff')
  )
  select jsonb_build_object(
    'audits', (select to_jsonb(am) from audits_metrics am),
    'nonconformities', (select to_jsonb(nm) from nonconformity_metrics nm),
    'actions', (select to_jsonb(acm) from action_metrics acm),
    'checklist', (select to_jsonb(cm) from checklist_metrics cm),
    'active_audits', coalesce((select jsonb_agg(to_jsonb(aa) order by aa.start_date nulls last,aa.code)
                               from active_audits aa),'[]'::jsonb)
  ) into dashboard_data;

  return dashboard_data;
end;
$$;

revoke all on function public.dashboard_admin_summary() from public;
grant execute on function public.dashboard_admin_summary() to authenticated;

commit;
