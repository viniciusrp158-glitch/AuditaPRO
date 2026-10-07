create or replace function private.checklist_day_stats(aid uuid,did uuid) returns jsonb language sql stable security definer set search_path='' as $$
 with units as(select distinct id,requirement_id,process_id from private.checklist_scope where audit_id=aid and audit_day_id=did and included),
 states as(select u.*,ar.result,ar.operational_state from units u left join public.requirement_assessments ar on ar.audit_id=aid and ar.audit_day_id=did and coalesce(ar.question_id,ar.extra_question_id)=u.id and ar.process_id is not distinct from u.process_id)
 select jsonb_build_object('contract',3,'total',count(*),'requirements',count(distinct requirement_id),'completed',count(*) filter(where operational_state='completed'),
 'conforming',count(*) filter(where operational_state='completed' and result='conforming'),'partially_conforming',count(*) filter(where operational_state='completed' and result='partially_conforming'),
 'nonconforming',count(*) filter(where operational_state='completed' and result='nonconforming'),'not_applicable',count(*) filter(where operational_state='completed' and result='not_applicable'),
 'not_assessed',count(*) filter(where operational_state is distinct from 'completed')) from states;
$$;
revoke all on function private.checklist_day_stats(uuid,uuid) from public,anon,authenticated;
do $$declare body text;begin
 body:=pg_get_functiondef('private.checklist_stats(uuid)'::regprocedure);
 body:=replace(body,'bool_and(operational_state=''completed'' or not required)','bool_and(coalesce(operational_state=''completed'',false) or not required)');
 execute body;
 body:=pg_get_functiondef('private.workspace_snapshot(uuid,uuid)'::regprocedure);
 body:=replace(body,'''contract_version'',2,''statistics'',private.checklist_stats(aid)', '''contract_version'',3,''statistics'',case when dayid is null then private.checklist_stats(aid) else private.checklist_day_stats(aid,dayid) end,''cumulative_statistics'',private.checklist_stats(aid)');
 execute body;
end $$;
