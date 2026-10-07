begin;
create function private.workspace_item_states(target uuid default null) returns table(audit_id uuid,requirement_id uuid,process_id uuid,result text) language sql stable security definer set search_path='' as $$
 with units as (
  select distinct a.id aid,q.id rid,null::uuid pid from public.audits a join public.audit_checklists ac on ac.audit_id=a.id join public.checklist_sections cs on cs.revision_id=ac.revision_id join public.checklist_requirements q on q.section_id=cs.id where (target is null or a.id=target) and private.is_audit_participant(a.id) and (a.workspace_version=0 or a.plan_revision=0)
  union select distinct a.id,sr.requirement_id,si.process_id from public.audits a join public.audit_days d on d.audit_id=a.id join public.schedule_items si on si.audit_day_id=d.id join public.schedule_requirements sr on sr.schedule_item_id=si.id where (target is null or a.id=target) and a.workspace_version>0 and not si.withdrawn and private.is_audit_participant(a.id)
 ) select u.aid,u.rid,u.pid,coalesce(latest.result,'not_assessed') from units u left join lateral(select ra.result from public.requirement_assessments ra join public.audits a on a.id=ra.audit_id where ra.audit_id=u.aid and ra.requirement_id=u.rid and (a.workspace_version=0 or ra.process_id is not distinct from u.pid) order by ra.updated_at desc,ra.created_at desc,ra.id desc limit 1) latest on true;
$$;
create function public.audit_workspace_stats(target uuid) returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('total',count(*),'conforming',count(*) filter(where result='conforming'),'nonconforming',count(*) filter(where result='nonconforming'),'partially_conforming',count(*) filter(where result='partially_conforming'),'improvement',count(*) filter(where result='improvement'),'not_assessed',count(*) filter(where result='not_assessed'),'not_applicable',count(*) filter(where result='not_applicable')) from private.workspace_item_states(target);
$$;
revoke all on function private.workspace_item_states(uuid),public.audit_workspace_stats(uuid) from public;
grant execute on function private.workspace_item_states(uuid),public.audit_workspace_stats(uuid) to authenticated;
do $$ declare def text; firstpos int; lastpos int; begin
 def:=pg_get_functiondef('public.dashboard_admin_summary()'::regprocedure);
 firstpos:=strpos(def,'with checklist_items as ('); lastpos:=strpos(def,'), checklist_metrics as (');
 if firstpos=0 or lastpos=0 then raise exception 'Consulta do dashboard mudou; revisar integração'; end if;
 def:=left(def,firstpos-1)||'with item_states as (select * from private.workspace_item_states(null))'||substr(def,lastpos+1);
 def:=replace(def,'when coalesce(ib.total,0)=coalesce(ib.not_applicable,0) then 100','when coalesce(ib.total,0)=coalesce(ib.not_applicable,0) then null');
 execute def;
 def:=pg_get_functiondef('private.workspace_member(uuid)'::regprocedure);
 def:=replace(def,'and u.cpf is not null','and u.cpf is not null and private.profile_ready(m.id)');execute def;
 def:=pg_get_functiondef('private.workspace_eligible(uuid)'::regprocedure);
 def:=replace(def,'and u.cpf is not null','and u.cpf is not null and private.profile_ready(m.id)');execute def;
end $$;
commit;
