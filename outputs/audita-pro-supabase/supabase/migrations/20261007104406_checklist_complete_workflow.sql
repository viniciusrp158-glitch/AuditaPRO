-- Question-level scope and additional audit-only questions preserve master revisions.
alter table public.audits add column criterion_ids uuid[] not null default '{}';
update public.audits set criterion_ids=array[type_id] where type_id is not null;
create table public.schedule_question_scope (
 schedule_id uuid not null references public.schedule_items(id), question_id uuid not null references public.checklist_questions(id),
 included boolean not null, reason text not null, actor uuid not null references auth.users(id),updated_at timestamptz not null default now(),primary key(schedule_id,question_id));
create table public.audit_extra_questions (
 id uuid primary key default gen_random_uuid(),audit_id uuid not null references public.audits(id),requirement_id uuid not null references public.checklist_requirements(id),
 origin_complement_id uuid references public.assessment_complements(id),prompt text not null,premise text,theme text,guidance text,expected_evidence text,
 required boolean not null default true,allow_na boolean not null default true,active boolean not null default true,sort_order integer not null default 10000,
 reason text not null,created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),operation_id uuid not null,unique(audit_id,operation_id));
create table public.schedule_extra_questions(schedule_id uuid not null references public.schedule_items(id),question_id uuid not null references public.audit_extra_questions(id),included boolean not null default true,primary key(schedule_id,question_id));
alter table public.requirement_assessments add column extra_question_id uuid references public.audit_extra_questions(id),add constraint assessment_one_question check(question_id is null or extra_question_id is null);
drop index public.assessments_legacy_day_process;
create unique index assessments_legacy_day_process on public.requirement_assessments(audit_id,audit_day_id,requirement_id,coalesce(process_id,'00000000-0000-0000-0000-000000000000'::uuid)) where question_id is null and extra_question_id is null;
create unique index assessments_extra_question on public.requirement_assessments(audit_id,audit_day_id,extra_question_id,coalesce(process_id,'00000000-0000-0000-0000-000000000000'::uuid)) where extra_question_id is not null;
create table public.checklist_record_history(id uuid primary key default gen_random_uuid(),audit_id uuid not null references public.audits(id),entity_type text not null,entity_id uuid not null,content jsonb not null,actor uuid not null references auth.users(id),created_at timestamptz not null default now());
create index checklist_record_history_entity on public.checklist_record_history(entity_id,created_at desc);
create table public.assessment_uploads(operation_id uuid primary key,assessment_id uuid not null references public.requirement_assessments(id),status text not null check(status in('pending','failed','completed','cancelled')),filename text not null,reason text,actor uuid not null references auth.users(id),updated_at timestamptz not null default now());
create table public.finding_evidence_links(finding_id uuid not null references public.assessment_findings(id),evidence_id uuid not null references public.evidence_files(id),primary key(finding_id,evidence_id));
create table public.complement_evidence_links(complement_id uuid not null references public.assessment_complements(id),evidence_id uuid not null references public.evidence_files(id),primary key(complement_id,evidence_id));
create table public.complement_finding_links(complement_id uuid not null references public.assessment_complements(id),finding_id uuid not null references public.assessment_findings(id),primary key(complement_id,finding_id));
alter table public.assessment_findings add column lock_version integer not null default 0;
alter table public.assessment_complements add column lock_version integer not null default 0;
-- All access is through authorized RPCs; deny raw table access.
do $$ declare t text;begin foreach t in array array['schedule_question_scope','audit_extra_questions','schedule_extra_questions','checklist_record_history','assessment_uploads','finding_evidence_links','complement_evidence_links','complement_finding_links'] loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant all on public.%I to service_role',t);end loop;end $$;
create or replace view private.checklist_scope as
 select ad.audit_id,si.id schedule_id,ad.id audit_day_id,ad.audit_date,si.process_id,si.assignee_membership_id,
 q.id,q.id master_question_id,null::uuid extra_question_id,q.requirement_id,q.prompt,q.theme,q.premise,q.guidance,q.expected_evidence,q.required,q.allow_na,q.active,q.sort_order,
 rq.reference,rq.prompt requirement_title,cs.id section_id,cs.title section,cs.criterion_id,cr.header->'criteria' criteria,
 coalesce(sq.included,true) included,si.status activity_status,ad.status day_status
 from public.schedule_items si join public.audit_days ad on ad.id=si.audit_day_id
 join public.schedule_requirements sr on sr.schedule_item_id=si.id join public.checklist_requirements rq on rq.id=sr.requirement_id
 join public.checklist_sections cs on cs.id=rq.section_id join public.checklist_revisions cr on cr.id=cs.revision_id
 join public.audit_checklists ac on ac.audit_id=ad.audit_id and ac.revision_id=cr.id
 join public.checklist_questions q on q.requirement_id=rq.id
 left join public.schedule_question_scope sq on sq.schedule_id=si.id and sq.question_id=q.id
 where not si.withdrawn and q.active and si.category='assessment'
 union all
 select ad.audit_id,si.id,ad.id,ad.audit_date,si.process_id,si.assignee_membership_id,
 q.id,null::uuid,q.id,q.requirement_id,q.prompt,q.theme,q.premise,q.guidance,q.expected_evidence,q.required,q.allow_na,q.active,q.sort_order,
 rq.reference,rq.prompt,cs.id,cs.title,cs.criterion_id,cr.header->'criteria',se.included,si.status,ad.status
 from public.schedule_items si join public.audit_days ad on ad.id=si.audit_day_id join public.schedule_extra_questions se on se.schedule_id=si.id
 join public.audit_extra_questions q on q.id=se.question_id and q.audit_id=ad.audit_id
 join public.checklist_requirements rq on rq.id=q.requirement_id join public.checklist_sections cs on cs.id=rq.section_id join public.checklist_revisions cr on cr.id=cs.revision_id
 where not si.withdrawn and q.active;
revoke all on private.checklist_scope from public,anon,authenticated;
create or replace function private.checklist_stats(aid uuid) returns jsonb language sql stable security definer set search_path='' as $$
 with units as(select distinct id,requirement_id,process_id,required from private.checklist_scope where audit_id=aid and included and private.checklist_internal(aid)),
 states as(select u.*,r.result,r.operational_state from units u left join lateral(select a.result,a.operational_state from public.requirement_assessments a join public.audit_days d on d.id=a.audit_day_id where a.audit_id=aid and coalesce(a.question_id,a.extra_question_id)=u.id and a.process_id is not distinct from u.process_id order by d.audit_date desc,a.updated_at desc limit 1)r on true),
 coverage as(select requirement_id,bool_and(operational_state='completed' or not required) covered from states group by requirement_id)
 select jsonb_build_object('contract',3,'total',count(*),'requirements',count(distinct requirement_id),'requirements_covered',(select count(*) from coverage where covered),
 'completed',count(*) filter(where operational_state='completed'),'conforming',count(*) filter(where operational_state='completed' and result='conforming'),
 'partially_conforming',count(*) filter(where operational_state='completed' and result='partially_conforming'),'nonconforming',count(*) filter(where operational_state='completed' and result='nonconforming'),
 'not_applicable',count(*) filter(where operational_state='completed' and result='not_applicable'),'not_assessed',count(*) filter(where operational_state is distinct from 'completed'),'improvement',0) from states;
$$;
create or replace function private.workspace_item_states(target uuid default null) returns table(audit_id uuid,requirement_id uuid,process_id uuid,result text) language sql stable security definer set search_path='' as $$
 with units as(select distinct audit_id,id,requirement_id,process_id from private.checklist_scope where included and (target is null or audit_id=target) and private.checklist_internal(audit_id))
 select u.audit_id,u.requirement_id,u.process_id,case when r.operational_state='completed' then r.result else 'not_assessed' end
 from units u left join lateral(select a.result,a.operational_state from public.requirement_assessments a join public.audit_days d on d.id=a.audit_day_id where a.audit_id=u.audit_id and coalesce(a.question_id,a.extra_question_id)=u.id and a.process_id is not distinct from u.process_id order by d.audit_date desc,a.updated_at desc limit 1)r on true;
$$;


CREATE OR REPLACE FUNCTION private.workspace_context(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare org uuid:=nullif(p->>'organization_id','')::uuid; admin boolean:=private.profile_admin(auth.uid()); result jsonb;
begin
 if org is not null and not admin and not private.workspace_member(org) then raise exception 'Empresa fora do seu acesso'; end if;
 select jsonb_build_object('admin',admin,'user_id',auth.uid(),
 'organizations',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.legal_name,'cnpj',o.cnpj,'can_create',private.has_org_permission(o.id,'audit.create'))) from public.organizations o where o.status='active' and (admin or private.workspace_member(o.id))),'[]'),
 'types',coalesce((select jsonb_agg(to_jsonb(t) order by t.name) from public.audit_types t),'[]'),
 'units',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.organization_units where organization_id=org and status='active'),'[]'),
 'members',case when org is not null and (admin or private.has_org_permission(org,'audit.create')) then coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'user_id',m.user_id,'name',u.full_name,'role',ap.name,'eligible',private.workspace_eligible(m.id),'ready',m.competence_status in ('approved','not_required'))) from public.organization_memberships m join public.user_profiles u on u.user_id=m.user_id left join public.access_profiles ap on ap.id=m.access_profile_id where m.organization_id=org and m.status='active'),'[]') else '[]'::jsonb end,
 'templates',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'name',t.name,'status',t.status,'organization_id',t.organization_id,'type_id',t.type_id,'revisions',(select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'number',r.revision_number,'status',r.status) order by r.revision_number desc),'[]') from public.checklist_revisions r where r.template_id=t.id and (admin or r.status='published')))) from public.checklist_templates t where private.workspace_template_visible(t.id) and (admin or t.status='published')),'[]')) into result;
 return result;
end $function$;

CREATE OR REPLACE FUNCTION private.workspace_command(cmd text, p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare aid uuid:=nullif(p->>'audit_id','')::uuid; a public.audits%rowtype; org uuid; leader uuid; rid uuid; sid uuid; dayid uuid; proc uuid; item jsonb; req text; prev jsonb; n int; result jsonb; s public.schedule_items%rowtype; d public.audit_days%rowtype; mid uuid; keep_ids uuid[]:=array[]::uuid[];
begin
 if auth.uid() is null or not private.is_active_account(auth.uid()) then raise exception 'Sessão ativa necessária'; end if;
 if cmd='template_save' then raise exception 'Utilize a Biblioteca de Checklists'; end if; if cmd in ('type_save','template_save','template_inactivate') then return private.workspace_catalog(cmd,p); end if;
 if cmd='context' then return private.workspace_context(p); end if;
 if cmd='template_detail' then if not private.profile_admin(auth.uid()) then raise exception 'Biblioteca restrita à Administração'; end if;
  rid:=(p->>'revision_id')::uuid;
  if not exists(select 1 from public.checklist_revisions r where r.id=rid and private.workspace_template_visible(r.template_id) and (r.status='published' or private.profile_admin(auth.uid()))) then raise exception 'Modelo indisponível'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('reference',q.reference,'prompt',q.prompt,'guidance',q.guidance,'section',s.title) order by s.sort_order,q.sort_order),'[]') from public.checklist_sections s join public.checklist_requirements q on q.section_id=s.id where s.revision_id=rid);
 end if;
 if cmd='list' then
  return (with filtered as (select a.id,a.code,a.title,a.status,a.start_date,a.end_date,a.standards,a.organization_id,o.legal_name company,u.full_name leader from public.audits a join public.organizations o on o.id=a.organization_id join public.organization_memberships m on m.id=a.leader_membership_id join public.user_profiles u on u.user_id=m.user_id where (private.is_audit_participant(a.id) or (a.plan_revision>0 and private.workspace_member(a.organization_id))) and (coalesce(p->>'status','')='' or a.status=p->>'status') and (coalesce(p->>'search','')='' or concat(a.code,' ',a.title,' ',o.legal_name,' ',o.cnpj) ilike '%'||(p->>'search')||'%')) select jsonb_build_object('total',(select count(*) from filtered),'items',coalesce((select jsonb_agg(to_jsonb(x)) from (select * from filtered order by start_date desc nulls last,id limit 20 offset greatest(0,coalesce((p->>'page')::int,0))*20) x),'[]')));
 end if;
 if cmd='create' then
  org:=(p->>'organization_id')::uuid; leader:=nullif(p->>'leader_membership_id','')::uuid;
  if not private.has_org_permission(org,'audit.create') then raise exception 'Sem permissão para criar auditoria'; end if;
  if leader is null and private.profile_admin(auth.uid()) then
   insert into public.organization_memberships(organization_id,user_id,access_profile_id,competence_status,created_by) values(org,auth.uid(),(select id from public.access_profiles where name='Auditor Líder'),'not_required',auth.uid()) on conflict(organization_id,user_id) do nothing;
   select id into leader from public.organization_memberships where organization_id=org and user_id=auth.uid();
  end if;
  if leader is null then select id into leader from public.organization_memberships where organization_id=org and user_id=auth.uid() and private.workspace_eligible(id);end if;
  if not private.workspace_eligible(leader) or not exists(select 1 from public.organization_memberships where id=leader and organization_id=org and (user_id=auth.uid() or private.profile_admin(auth.uid()))) then raise exception 'Responsável inelegível ou fora da empresa'; end if;
  if nullif(p->>'unit_id','') is not null and not exists(select 1 from public.organization_units where id=(p->>'unit_id')::uuid and organization_id=org and status='active') then raise exception 'Unidade fora da empresa';end if;
  if not exists(select 1 from public.audit_types where id=(p->>'type_id')::uuid and active) then raise exception 'Selecione um critério ativo';end if;
  rid:=nullif(p->>'revision_id','')::uuid;
  if rid is not null and not exists(select 1 from public.checklist_revisions r join public.checklist_templates t on t.id=r.template_id where r.id=rid and r.status='published' and t.status='published' and (t.organization_id is null or t.organization_id=org) and t.type_id=(p->>'type_id')::uuid) then raise exception 'Selecione modelo publicado compatível com a empresa e tipo'; end if;
  if length(trim(coalesce(p->>'title','')))<2 or nullif(trim(p->>'scope'),'') is null then raise exception 'Título e escopo obrigatórios'; end if;
  insert into public.audits(organization_id,unit_id,code,title,objective,scope,standards,leader_membership_id,created_by,workspace_version,type_id,purpose,party,modality,location,criteria)
   values(org,nullif(p->>'unit_id','')::uuid,'AUD-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)),p->>'title',p->>'objective',p->>'scope',array[(select code||coalesce(':'||nullif(edition,''),'') from public.audit_types where id=(p->>'type_id')::uuid and active)],leader,auth.uid(),1,(p->>'type_id')::uuid,coalesce(p->>'purpose','Interna'),coalesce(p->>'party','first'),coalesce(p->>'modality','presential'),p->>'location',p->>'criteria') returning id into aid;
  if exists(select 1 from jsonb_array_elements_text(coalesce(p->'criterion_ids','[]')) v where not exists(select 1 from public.audit_types t where t.id=v::uuid and t.active)) then raise exception 'Critério inválido';end if;
  update public.audits set criterion_ids=array(select distinct v::uuid from jsonb_array_elements_text(coalesce(p->'criterion_ids',jsonb_build_array(p->>'type_id')))v),standards=array(select code||case when nullif(edition,'') is not null then ':'||edition else '' end from public.audit_types where id in(select v::uuid from jsonb_array_elements_text(coalesce(p->'criterion_ids',jsonb_build_array(p->>'type_id')))v)) where id=aid;
  if rid is not null then insert into public.audit_checklists(audit_id,revision_id,attached_by) values(aid,rid,auth.uid()); end if;
  insert into public.audit_participants(audit_id,membership_id,participant_type,added_by) values(aid,leader,'leader',auth.uid());
  return jsonb_build_object('id',aid);
 end if;
 if cmd='detail' then return private.workspace_detail(aid); end if;
 select * into a from public.audits where id=aid for update; if a.status='awaiting_signoff' then raise exception 'Execução encerrada; conclua a validação documental'; end if;
 if a.id is null or a.workspace_version=0 then raise exception 'Auditoria indisponível para este módulo'; end if;
 if cmd='reassign' then
  if not private.profile_admin(auth.uid()) or nullif(trim(p->>'reason'),'') is null then raise exception 'Administrador e motivo necessários'; end if;
  leader:=(p->>'membership_id')::uuid;
  if not private.workspace_eligible(leader) or not exists(select 1 from public.organization_memberships where id=leader and organization_id=a.organization_id) then raise exception 'Responsável inelegível'; end if;
  update public.audit_participants set participant_type='auditor' where audit_id=aid and participant_type='leader';
  insert into public.audit_participants(audit_id,membership_id,participant_type,added_by) values(aid,leader,'leader',auth.uid()) on conflict(audit_id,membership_id) do update set participant_type='leader',active=true;
  update public.audits set leader_membership_id=leader,lock_version=lock_version+1 where id=aid;
  insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,metadata) values(a.organization_id,auth.uid(),'reassign','audits',aid,jsonb_build_object('reason',p->>'reason','previous',a.leader_membership_id,'new',leader));
  return '{}';
 end if;
 if not private.workspace_conductor(aid) then raise exception 'Somente o condutor designado pode alterar esta auditoria'; end if;
 if a.status in ('completed','cancelled') then raise exception 'Auditoria encerrada: utilize retificação documental'; end if;
 if cmd='team_save' then
  for item in select value from jsonb_array_elements(p->'members') loop
   mid:=(item->>'id')::uuid;
   if not exists(select 1 from public.organization_memberships m where m.id=mid and m.organization_id=a.organization_id and m.status='active' and (m.competence_status in ('approved','not_required') or (m.id=a.leader_membership_id and private.workspace_eligible(m.id)))) then raise exception 'Participante não aprovado para a empresa'; end if;
   insert into public.audit_participants(audit_id,membership_id,participant_type,is_signatory,added_by) select aid,m.id,case when m.id=a.leader_membership_id then 'leader' when ap.name='Auditor' then 'auditor' else 'client' end,coalesce((item->>'signatory')::boolean,false),auth.uid() from public.organization_memberships m join public.access_profiles ap on ap.id=m.access_profile_id where m.id=mid on conflict(audit_id,membership_id) do update set active=true,is_signatory=excluded.is_signatory;
  end loop;
  update public.audit_participants set active=false where audit_id=aid and membership_id<>a.leader_membership_id and membership_id not in(select (value->>'id')::uuid from jsonb_array_elements(p->'members'));
  update public.audits set team_reviewed=true where id=aid; return '{}';
 elsif cmd='plan_save' then
  if a.lock_version<>coalesce((p->>'lock_version')::int,-1) then raise exception 'Plano alterado em outra sessão. Recarregue antes de salvar'; end if;
  if jsonb_typeof(p->'items')<>'array' or jsonb_array_length(p->'items')>500 then raise exception 'Plano inválido ou acima de 500 atividades'; end if;
  update public.audits set plan_draft=p->'items',lock_version=lock_version+1 where id=aid; return '{}';
 elsif cmd='plan_publish' then
 if a.checklist_confirmed_at is null then raise exception 'Confirme o conjunto de checklists antes de publicar o plano'; end if;
  if a.lock_version<>coalesce((p->>'lock_version')::int,-1) then raise exception 'Plano alterado. Recarregue'; end if;
  if not a.team_reviewed or jsonb_array_length(a.plan_draft)=0 then raise exception 'Revise a equipe e preencha o plano'; end if;
  if nullif(trim(p->>'reason'),'') is null then raise exception 'Informe motivo da publicação/revisão'; end if;
  if exists(select 1 from public.audit_checklists ac join public.checklist_sections cs on cs.revision_id=ac.revision_id join public.checklist_requirements q on q.section_id=cs.id where ac.audit_id=aid and not exists(select 1 from jsonb_array_elements(a.plan_draft) e where coalesce(e->'requirements','[]') ? q.id::text)) then raise exception 'Distribua todos os requisitos no cronograma'; end if;
  for item in select value from jsonb_array_elements(a.plan_draft) order by value->>'date',value->>'start' loop
   if nullif(trim(item->>'title'),'') is null or nullif(item->>'date','') is null then raise exception 'Atividade e data obrigatórias'; end if;
   if nullif(item->>'start','') is not null and ((item->>'start')::timestamptz at time zone a.timezone)::date<>(item->>'date')::date then raise exception 'Horário fora da data da atividade'; end if;
   if coalesce(item->>'category','assessment')='assessment' and (nullif(trim(item->>'process'),'') is null or jsonb_array_length(coalesce(item->'requirements','[]'))=0) then raise exception 'Atividade de avaliação exige processo e requisitos'; end if;
   for req in select jsonb_array_elements_text(coalesce(item->'requirements','[]')) loop
    if not exists(select 1 from public.audit_checklists ac join public.checklist_sections cs on cs.revision_id=ac.revision_id join public.checklist_requirements q on q.section_id=cs.id where ac.audit_id=aid and q.id=req::uuid) then raise exception 'Requisito fora do modelo'; end if;
   end loop;
   select id into dayid from public.audit_days where audit_id=aid and audit_date=(item->>'date')::date;
   if dayid is null then
    insert into public.audit_days(audit_id,day_number,audit_date) select aid,coalesce(max(day_number),0)+1,(item->>'date')::date from public.audit_days where audit_id=aid returning id into dayid;
   end if;
   proc:=null;
   if nullif(trim(item->>'process'),'') is not null then
    insert into public.audit_processes(audit_id,name) values(aid,trim(item->>'process')) on conflict(audit_id,name) do update set name=excluded.name returning id into proc;
   end if;
   sid:=nullif(item->>'id','')::uuid; prev:=null;
   if sid is not null then
    select to_jsonb(si) into prev from public.schedule_items si join public.audit_days ad on ad.id=si.audit_day_id where si.id=sid and ad.audit_id=aid;
    if prev is null then raise exception 'Atividade fora da auditoria'; end if;
    if prev->>'status'='completed' and (prev->>'title' is distinct from item->>'title' or (prev->>'process_id')::uuid is distinct from proc or (select coalesce(jsonb_agg(requirement_id::text order by requirement_id::text),'[]') from public.schedule_requirements where schedule_item_id=sid) is distinct from (select coalesce(jsonb_agg(value order by value),'[]') from jsonb_array_elements_text(coalesce(item->'requirements','[]')))) then raise exception 'Atividade concluída preserva seu escopo'; end if;
    if prev->>'status'='completed' and (prev->>'audit_day_id')::uuid<>dayid then raise exception 'Atividade concluída mantém sua data real'; end if;
   end if;
   if exists(select 1 from public.audit_days where id=dayid and status='completed') and (prev is null or (prev->>'audit_day_id')::uuid<>dayid) then raise exception 'Não adicionar trabalho a um dia encerrado'; end if;
   insert into public.schedule_items(id,audit_day_id,process_id,title,planned_start,planned_end,assignee_membership_id,category,notes)
    values(coalesce(sid,gen_random_uuid()),dayid,proc,item->>'title',nullif(item->>'start','')::timestamptz,nullif(item->>'end','')::timestamptz,a.leader_membership_id,coalesce(item->>'category','assessment'),item->>'notes')
    on conflict(id) do update set audit_day_id=excluded.audit_day_id,process_id=excluded.process_id,title=excluded.title,planned_start=excluded.planned_start,planned_end=excluded.planned_end,category=excluded.category,notes=excluded.notes,withdrawn=false returning id into sid;
   keep_ids:=array_append(keep_ids,sid); if prev is not null and prev is distinct from (select to_jsonb(si) from public.schedule_items si where id=sid) then
    insert into public.schedule_movements(audit_id,schedule_item_id,previous_data,new_data,reason,created_by) select aid,sid,prev,to_jsonb(si),p->>'reason',auth.uid() from public.schedule_items si where id=sid;
    if (prev->>'audit_day_id')::uuid<>dayid then update public.schedule_items set origin_day_id=coalesce(origin_day_id,(prev->>'audit_day_id')::uuid),move_reason=p->>'reason',moved_at=now(),moved_by=auth.uid() where id=sid; end if;
   end if;
   delete from public.schedule_requirements where schedule_item_id=sid;
   insert into public.schedule_requirements select sid,value::uuid from jsonb_array_elements_text(coalesce(item->'requirements','[]')) on conflict do nothing;
  end loop;
  -- Omission is an explicit withdrawal in this revision; retain rows and assessments.
  update public.schedule_items si set withdrawn=true from public.audit_days ad where ad.id=si.audit_day_id and ad.audit_id=aid and not(si.id=any(keep_ids)) and si.status<>'completed';
  select coalesce(jsonb_agg(to_jsonb(si)||jsonb_build_object('date',ad.audit_date,'process',pr.name,'requirements',(select coalesce(jsonb_agg(requirement_id),'[]') from public.schedule_requirements where schedule_item_id=si.id)) order by ad.audit_date,si.planned_start),'[]') into result from public.schedule_items si join public.audit_days ad on ad.id=si.audit_day_id left join public.audit_processes pr on pr.id=si.process_id where ad.audit_id=aid and not si.withdrawn;
  insert into public.audit_plan_versions(audit_id,version_number,content,reason,created_by) values(aid,a.plan_revision+1,result,p->>'reason',auth.uid());
  update public.audits set plan_revision=plan_revision+1,plan_draft=result,lock_version=lock_version+1,status=case when status='draft' then 'planned' else status end,start_date=(select min(audit_date) from public.audit_days where audit_id=aid),end_date=(select max(audit_date) from public.audit_days where audit_id=aid) where id=aid;
  return '{}';
 elsif cmd='start' then
  if a.status<>'planned' or a.plan_revision=0 then raise exception 'Publique o plano antes de iniciar'; end if;
  update public.audits set status='in_progress',execution_started_at=now() where id=aid; return '{}';
 elsif cmd='attendance' then
  dayid:=(p->>'day_id')::uuid;
  if not exists(select 1 from public.audit_days where id=dayid and audit_id=aid and status<>'completed') then raise exception 'Dia indisponível'; end if;
  delete from public.audit_day_attendance where audit_day_id=dayid;
  for req in select jsonb_array_elements_text(p->'members') loop
   if not exists(select 1 from public.audit_participants where audit_id=aid and membership_id=req::uuid and active) then raise exception 'Presença exige participante autorizado'; end if;
   insert into public.audit_day_attendance values(dayid,req::uuid,auth.uid());
  end loop;
  if not exists(select 1 from public.audit_day_attendance where audit_day_id=dayid and membership_id=a.leader_membership_id) then raise exception 'Confirme a presença do condutor'; end if;
  update public.audit_days set attendance_confirmed=true where id=dayid; return '{}';
 elsif cmd in ('activity_start','activity_complete','assessment_save') then
  if a.status<>'in_progress' then raise exception 'Inicie a auditoria primeiro'; end if;
  select si.* into s from public.schedule_items si join public.audit_days ad on ad.id=si.audit_day_id where si.id=(p->>'schedule_id')::uuid and ad.audit_id=aid and not si.withdrawn;
  if s.id is null then raise exception 'Atividade indisponível'; end if;
  select * into d from public.audit_days where id=s.audit_day_id;
  if d.status='completed' then raise exception 'Dia encerrado'; end if;
  update public.audit_days set status='in_progress',started_at=coalesce(started_at,now()),opening_plan_version=coalesce(opening_plan_version,a.plan_revision) where id=d.id;
  if cmd='assessment_save' then raise exception 'Use Checklist da Auditoria para salvar perguntas'; end if; if cmd='assessment_save' then
   rid:=(p->>'requirement_id')::uuid;
   if not exists(select 1 from public.schedule_requirements where schedule_item_id=s.id and requirement_id=rid) then raise exception 'Requisito fora da atividade'; end if;
   if s.status='completed' then raise exception 'Atividade concluída'; end if;
   if p->>'result'='not_applicable' and nullif(trim(p->>'evidence_text'),'') is null then raise exception 'Justifique a não aplicabilidade em texto'; end if;
   if p->>'result'<>'not_assessed' and nullif(trim(p->>'evidence_text'),'') is null and not exists(select 1 from public.evidence_files e join public.requirement_assessments ra on ra.id=e.assessment_id where ra.audit_id=aid and ra.audit_day_id=d.id and ra.requirement_id=rid and ra.process_id is not distinct from s.process_id) then raise exception 'Informe evidência textual ou salve rascunho e anexe arquivo'; end if;
   insert into public.requirement_assessments(audit_id,audit_day_id,requirement_id,process_id,result,evidence_text,notes,nc_justification,created_by) values(aid,d.id,rid,s.process_id,p->>'result',p->>'evidence_text',p->>'notes',p->>'nc_justification',auth.uid()) on conflict(audit_id,audit_day_id,requirement_id,(coalesce(process_id,'00000000-0000-0000-0000-000000000000'::uuid))) do update set result=excluded.result,evidence_text=excluded.evidence_text,notes=excluded.notes,nc_justification=excluded.nc_justification,updated_at=now() returning id into rid;
   return jsonb_build_object('id',rid);
  elsif cmd='activity_complete' then
 if exists(select 1 from private.checklist_scope sc where sc.schedule_id=s.id and sc.included and not exists(select 1 from public.requirement_assessments ra where ra.audit_id=aid and ra.audit_day_id=s.audit_day_id and coalesce(ra.question_id,ra.extra_question_id)=sc.id and ra.process_id is not distinct from s.process_id and ra.operational_state='completed')) then raise exception 'Há perguntas não concluídas neste dia';end if;

   if exists(select 1 from public.schedule_requirements sr where sr.schedule_item_id=s.id and not exists(select 1 from public.requirement_assessments ra where ra.audit_id=aid and ra.requirement_id=sr.requirement_id and ra.process_id is not distinct from s.process_id and ra.result<>'not_assessed')) then raise exception 'Há requisitos não avaliados'; end if;
   update public.schedule_items set status='completed',actual_start=coalesce(actual_start,now()),actual_end=now() where id=s.id;
   if s.category in ('opening','closing','meeting') then perform private.workspace_documents('minutes',jsonb_build_object('audit_id',aid,'schedule_id',s.id)); end if;
  else update public.schedule_items set status='in_progress',actual_start=coalesce(actual_start,now()) where id=s.id; end if;
  return '{}';
 end if;
 raise exception 'Comando não reconhecido';
end $function$;

CREATE OR REPLACE FUNCTION private.workspace_detail(aid uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.audits%rowtype; full_access boolean; result jsonb;
begin
 select * into a from public.audits where id=aid;
 full_access:=private.checklist_internal(aid);
 if a.id is null or not(full_access or (a.plan_revision>0 and private.workspace_member(a.organization_id))) then raise exception 'Auditoria indisponível'; end if;
 select jsonb_build_object('audit',case when full_access then to_jsonb(a) else jsonb_build_object('id',a.id,'title',a.title,'code',a.code,'organization_id',a.organization_id,'status',a.status,'plan_revision',a.plan_revision,'start_date',a.start_date,'end_date',a.end_date,'scope',a.scope,'standards',a.standards,'timezone',a.timezone) end,
 'company',(select jsonb_build_object('name',legal_name,'cnpj',cnpj) from public.organizations where id=a.organization_id),
 'can_edit',private.workspace_conductor(aid),'admin',private.profile_admin(auth.uid()),'full_access',full_access,
 'plan',coalesce((select content from public.audit_plan_versions where audit_id=aid order by version_number desc limit 1),'[]'),
 'versions',coalesce((select jsonb_agg(jsonb_build_object('number',version_number,'reason',reason,'created_at',created_at,'content',content) order by version_number desc) from public.audit_plan_versions where audit_id=aid),'[]'),
 'days',coalesce((select jsonb_agg(to_jsonb(d) order by audit_date) from public.audit_days d where d.audit_id=aid),'[]'),
 'schedule',coalesce((select jsonb_agg(to_jsonb(s)||jsonb_build_object('requirements',(select coalesce(jsonb_agg(requirement_id),'[]') from public.schedule_requirements where schedule_item_id=s.id)) order by d.audit_date,s.planned_start nulls last,s.created_at) from public.schedule_items s join public.audit_days d on d.id=s.audit_day_id where d.audit_id=aid),'[]'),
 'processes',coalesce((select jsonb_agg(to_jsonb(pr)) from public.audit_processes pr where pr.audit_id=aid),'[]'),
 'movements',coalesce((select jsonb_agg(to_jsonb(m) order by created_at desc) from public.schedule_movements m where m.audit_id=aid),'[]'),
 'requirements',coalesce((select jsonb_agg(jsonb_build_object('id',q.id,'reference',q.reference,'prompt',case when full_access then q.prompt else null end,'guidance',case when full_access then q.guidance else null end,'section',s.title) order by s.sort_order,q.sort_order) from public.audit_checklists ac join public.checklist_sections s on s.revision_id=ac.revision_id join public.checklist_requirements q on q.section_id=s.id where ac.audit_id=aid),'[]'),
 'assessments',case when full_access then coalesce((select jsonb_agg(to_jsonb(r)) from public.requirement_assessments r where r.audit_id=aid),'[]') else '[]'::jsonb end,
 'evidence',case when full_access then coalesce((select jsonb_agg(to_jsonb(e)-'storage_path') from public.evidence_files e where e.audit_id=aid),'[]') else '[]'::jsonb end,
 'team',case when full_access then coalesce((select jsonb_agg(to_jsonb(ap)||jsonb_build_object('name',u.full_name)) from public.audit_participants ap join public.organization_memberships m on m.id=ap.membership_id join public.user_profiles u on u.user_id=m.user_id where ap.audit_id=aid),'[]') else '[]'::jsonb end,
 'attendance',case when full_access then coalesce((select jsonb_agg(to_jsonb(at)) from public.audit_day_attendance at join public.audit_days d on d.id=at.audit_day_id where d.audit_id=aid),'[]') else '[]'::jsonb end,
 'nonconformities',case when full_access then coalesce((select jsonb_agg(to_jsonb(n)||jsonb_build_object('actions',(select coalesce(jsonb_agg(to_jsonb(ac) order by ac.due_date),'[]') from public.action_plans ac where ac.nonconformity_id=n.id))) from public.nonconformities n where n.audit_id=aid),'[]') else '[]'::jsonb end) into result;
 if not full_access then
   result:=result||jsonb_build_object('plan',(select coalesce(jsonb_agg(v-'notes'),'[]') from jsonb_array_elements(result->'plan') v),'schedule',(select coalesce(jsonb_agg(v-'notes'),'[]') from jsonb_array_elements(result->'schedule') v),'versions',(select coalesce(jsonb_agg(v-'content'),'[]') from jsonb_array_elements(result->'versions') v),'movements',(select coalesce(jsonb_agg(v||jsonb_build_object('previous_data',(v->'previous_data')-'notes','new_data',(v->'new_data')-'notes')),'[]') from jsonb_array_elements(result->'movements') v));
  end if;
  if not private.checklist_internal(aid) then
 result:=result||jsonb_build_object('full_access',false,'assessments','[]'::jsonb,'evidence','[]'::jsonb,
 'requirements',(select coalesce(jsonb_agg(v-'guidance'-'prompt'),'[]') from jsonb_array_elements(result->'requirements')v),
 'movements','[]'::jsonb,'versions','[]'::jsonb,
 'plan',(select coalesce(jsonb_agg(v-'notes'),'[]') from jsonb_array_elements(result->'plan')v),
 'schedule',(select coalesce(jsonb_agg(v-'notes'),'[]') from jsonb_array_elements(result->'schedule')v));
 end if; return result;
end $function$;

CREATE OR REPLACE FUNCTION private.checklist_library(cmd text, p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare tid uuid; rid uuid; sid uuid; qid uuid; xid uuid; t public.checklist_templates%rowtype; r public.checklist_revisions%rowtype;
 h jsonb; sec jsonb; req jsonb; x jsonb; i int; j int; k int; keep_s uuid[]:='{}'; keep_q uuid[]:='{}'; keep_x uuid[]:='{}'; source uuid; org uuid; copy_mode boolean:=false;
begin
 if auth.uid() is null or not private.is_active_account(auth.uid()) or not private.profile_admin(auth.uid()) then raise exception 'Somente Administrador ativo pode gerenciar a biblioteca'; end if;
 if cmd='section' then
  return (select to_jsonb(cs)||jsonb_build_object('requirements',coalesce((select jsonb_agg(to_jsonb(rq)||jsonb_build_object('questions',(select coalesce(jsonb_agg(to_jsonb(cq) order by cq.sort_order),'[]') from public.checklist_questions cq where cq.requirement_id=rq.id)) order by rq.sort_order) from public.checklist_requirements rq where rq.section_id=cs.id),'[]')) from public.checklist_sections cs where cs.id=(p->>'section_id')::uuid and cs.revision_id=(p->>'revision_id')::uuid);
 elsif cmd='outline' then
  return (select to_jsonb(cr)||jsonb_build_object('author',(select full_name from public.user_profiles where user_id=cr.created_by),'components',coalesce((select jsonb_agg(source_revision_id) from public.checklist_components where revision_id=cr.id),'[]'),'sections',coalesce((select jsonb_agg(to_jsonb(cs)||jsonb_build_object('unloaded',true,'requirements','[]'::jsonb,'question_count',(select count(*) from public.checklist_questions cq join public.checklist_requirements rq on rq.id=cq.requirement_id where rq.section_id=cs.id)) order by cs.sort_order) from public.checklist_sections cs where cs.revision_id=cr.id),'[]')) from public.checklist_revisions cr where cr.id=(p->>'revision_id')::uuid);
 elsif cmd='complements' then
  return coalesce((select jsonb_agg(z) from(select c.id,c.prompt,c.reason,c.created_at,a.code audit_code,q.reference,u.full_name author from public.assessment_complements c join public.requirement_assessments ar on ar.id=c.assessment_id join public.audits a on a.id=ar.audit_id join public.checklist_requirements q on q.id=ar.requirement_id left join public.user_profiles u on u.user_id=c.created_by order by c.created_at desc limit 30 offset greatest(0,coalesce((p->>'page')::int,0))*30)z),'[]');
 elsif cmd='incorporate' then
  if not coalesce((p->>'reviewed')::boolean,false) or nullif(trim(p->>'prompt'),'') is null then raise exception 'Revise e retire informações específicas do cliente antes de incorporar';end if;
  select to_jsonb(c)||jsonb_build_object('audit_id',ar.audit_id) into sec from public.assessment_complements c join public.requirement_assessments ar on ar.id=c.assessment_id where c.id=(p->>'complement_id')::uuid;
  if sec is null then raise exception 'Complemento inexistente';end if;
  h:=private.checklist_library('revise',jsonb_build_object('revision_id',p->>'revision_id'));
  if h->'header'->>'category'='integrated' then raise exception 'Incorpore na revisão de um modelo de base';end if;
  if jsonb_array_length(h->'sections')=0 then raise exception 'Modelo sem seção';end if;
  rid:=(h->>'id')::uuid;sid:=(h->'sections'->0->>'id')::uuid;
  select id into qid from public.checklist_requirements where section_id=sid and reference=p->>'reference' order by sort_order limit 1;
  if qid is null then raise exception 'Selecione referência existente no modelo de destino';end if;
  insert into public.checklist_questions(requirement_id,prompt,sort_order) select qid,p->>'prompt',coalesce(max(sort_order),-1)+1 from public.checklist_questions where requirement_id=qid returning id into xid;
  update public.checklist_revisions set reason='Incorporação revisada de complemento de auditoria',lock_version=lock_version+1 where id=rid;
  insert into public.checklist_record_history(audit_id,entity_type,entity_id,content,actor) values((sec->>'audit_id')::uuid,'incorporated',xid,jsonb_build_object('complement_id',p->>'complement_id','revision_id',rid),auth.uid());
  return private.checklist_revision_json(rid);
 end if;

 if cmd='list' then
  return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(z)) from (
   select t.*, (select coalesce(jsonb_agg(jsonb_build_object('id',rr.id,'number',rr.revision_number,'status',rr.status,'at',rr.created_at,'reason',rr.reason,'author',(select full_name from public.user_profiles where user_id=rr.created_by)) order by rr.revision_number desc),'[]') from public.checklist_revisions rr where rr.template_id=t.id) revisions
   from public.checklist_templates t where (coalesce(p->>'search','')='' or concat(t.code,' ',t.name) ilike '%'||(p->>'search')||'%')
   and (coalesce(p->>'category','')='' or t.category=p->>'category') and (coalesce(p->>'status','')='' or t.status=p->>'status')
   and (coalesce(p->>'organization_id','')='' or t.organization_id=nullif(p->>'organization_id','')::uuid)
   and (coalesce(p->>'criterion_id','')='' or exists(select 1 from public.checklist_revisions cr join public.checklist_sections cs on cs.revision_id=cr.id where cr.template_id=t.id and cs.criterion_id=nullif(p->>'criterion_id','')::uuid))
   order by t.created_at desc,t.id limit 30 offset greatest(0,coalesce((p->>'page')::int,0))*30) z),'[]'));
 elsif cmd='get' then return private.checklist_revision_json((p->>'revision_id')::uuid);
 elsif cmd='archive' then
  update public.checklist_templates set status='inactive',updated_at=now() where id=(p->>'template_id')::uuid; return '{}';
 elsif cmd in ('new','revise','duplicate') then
  if cmd<>'new' then
   select * into r from public.checklist_revisions where id=(p->>'revision_id')::uuid;
   if r.id is null then raise exception 'Revisão não encontrada'; end if;
   select * into t from public.checklist_templates where id=r.template_id for update;
   h:=private.checklist_revision_json(r.id); copy_mode:=true;
  else h:=jsonb_build_object('header',jsonb_build_object('name','Novo checklist','category','custom'),'sections','[]'::jsonb,'components','[]'::jsonb); end if;
  if cmd='revise' then
   if exists(select 1 from public.checklist_revisions where template_id=t.id and status='draft') then raise exception 'Já existe um rascunho; abra-o na biblioteca'; end if;
   tid:=t.id;
  else
   insert into public.checklist_templates(name,description,organization_id,type_id,created_by,category)
    values(case when cmd='duplicate' then t.name||' — cópia' else 'Novo checklist' end,t.description,t.organization_id,t.type_id,auth.uid(),coalesce(t.category,'custom')) returning id into tid;
  end if;
  insert into public.checklist_revisions(template_id,revision_number,created_by,header)
   select tid,coalesce(max(revision_number),0)+1,auth.uid(),(h->'header')||jsonb_build_object('name',(select name from public.checklist_templates where id=tid),'code',(select code from public.checklist_templates where id=tid)) from public.checklist_revisions where template_id=tid returning id into rid;
  i:=0;
  for sec in select value from jsonb_array_elements(h->'sections') loop
   insert into public.checklist_sections(revision_id,title,sort_order,criterion_id) values(rid,sec->>'title',i,nullif(sec->>'criterion_id','')::uuid) returning id into sid; i:=i+1; j:=0;
   for req in select value from jsonb_array_elements(sec->'requirements') loop
    insert into public.checklist_requirements(section_id,reference,prompt,guidance,sort_order) values(sid,req->>'reference',req->>'prompt',req->>'guidance',j) returning id into qid; j:=j+1;
    for x in select value from jsonb_array_elements(req->'questions') loop
     insert into public.checklist_questions(requirement_id,prompt,theme,premise,guidance,expected_evidence,internal_notes,required,allow_na,active,sort_order,legacy)
      values(qid,x->>'prompt',x->>'theme',x->>'premise',x->>'guidance',x->>'expected_evidence',x->>'internal_notes',(x->>'required')::boolean,(x->>'allow_na')::boolean,(x->>'active')::boolean,(x->>'sort_order')::int,coalesce((x->>'legacy')::boolean,false));
    end loop;
   end loop;
  end loop;
  insert into public.checklist_components select rid,value::uuid from jsonb_array_elements_text(h->'components');
  return private.checklist_revision_json(rid);
 elsif cmd in ('save','publish') then
  rid:=(p->>'revision_id')::uuid;
  select * into r from public.checklist_revisions where id=rid for update;
  if r.id is null or r.status<>'draft' then raise exception 'Abra um rascunho para editar'; end if;
  select * into t from public.checklist_templates where id=r.template_id for update;
  if r.lock_version<>coalesce((p->>'lock_version')::int,-1) then raise exception using errcode='40001',message='Conflito: revisão alterada em outra sessão'; end if;
  p:=jsonb_set(p,'{sections}',coalesce((select jsonb_agg(case when coalesce((v->>'unloaded')::boolean,false) then private.checklist_library('section',jsonb_build_object('revision_id',rid,'section_id',v->>'id')) else v end order by ord) from jsonb_array_elements(p->'sections') with ordinality e(v,ord)),'[]'));
  h:=p->'header'; org:=nullif(h->>'organization_id','')::uuid;
  if t.organization_id is not null and org is distinct from t.organization_id and not coalesce((p->>'reviewed_application')::boolean,false) then raise exception 'Revise o conteúdo e confirme explicitamente a mudança de aplicação'; end if;
  if org is not null and not exists(select 1 from public.organizations where id=org and status='active') then raise exception 'Cliente inválido'; end if;
  if length(trim(coalesce(h->>'name','')))<2 then raise exception 'Informe o nome'; end if;
  if coalesce(h->>'category','') not in ('normative','custom','integrated') then raise exception 'Categoria inválida'; end if;
  if jsonb_typeof(p->'sections') is distinct from 'array' then raise exception 'Seções inválidas'; end if;
  -- Temporary negative positions avoid uniqueness conflicts when reordering.
  update public.checklist_sections set sort_order=-sort_order-1 where revision_id=rid;
  update public.checklist_requirements set sort_order=-sort_order-1 where section_id in(select id from public.checklist_sections where revision_id=rid);
  i:=0;
  for sec in select value from jsonb_array_elements(p->'sections') loop
   sid:=coalesce(nullif(sec->>'id','')::uuid,gen_random_uuid());
   if exists(select 1 from public.checklist_sections where id=sid and revision_id<>rid) then raise exception 'Seção fora da revisão'; end if;
   insert into public.checklist_sections(id,revision_id,title,criterion_id,sort_order) values(sid,rid,coalesce(sec->>'title',''),nullif(sec->>'criterion_id','')::uuid,i)
    on conflict(id) do update set title=excluded.title,criterion_id=excluded.criterion_id,sort_order=excluded.sort_order;
   keep_s:=array_append(keep_s,sid); i:=i+1;j:=0;
   for req in select value from jsonb_array_elements(coalesce(sec->'requirements','[]')) loop
    qid:=coalesce(nullif(req->>'id','')::uuid,gen_random_uuid());
    if exists(select 1 from public.checklist_requirements where id=qid and section_id<>sid) then raise exception 'Requisito fora da seção'; end if;
    insert into public.checklist_requirements(id,section_id,reference,prompt,guidance,sort_order) values(qid,sid,coalesce(req->>'reference',''),coalesce(req->>'prompt',''),req->>'guidance',j)
     on conflict(id) do update set reference=excluded.reference,prompt=excluded.prompt,guidance=excluded.guidance,sort_order=excluded.sort_order;
    keep_q:=array_append(keep_q,qid);j:=j+1;k:=0;
    for x in select value from jsonb_array_elements(coalesce(req->'questions','[]')) loop
     xid:=coalesce(nullif(x->>'id','')::uuid,gen_random_uuid());
     if exists(select 1 from public.checklist_questions where id=xid and requirement_id<>qid) then raise exception 'Pergunta fora do requisito'; end if;
     insert into public.checklist_questions(id,requirement_id,prompt,theme,premise,guidance,expected_evidence,internal_notes,required,allow_na,active,sort_order)
      values(xid,qid,coalesce(x->>'prompt',''),x->>'theme',x->>'premise',x->>'guidance',x->>'expected_evidence',x->>'internal_notes',coalesce((x->>'required')::boolean,true),coalesce((x->>'allow_na')::boolean,true),coalesce((x->>'active')::boolean,true),k)
      on conflict(id) do update set prompt=excluded.prompt,theme=excluded.theme,premise=excluded.premise,guidance=excluded.guidance,expected_evidence=excluded.expected_evidence,internal_notes=excluded.internal_notes,required=excluded.required,allow_na=excluded.allow_na,active=excluded.active,sort_order=excluded.sort_order;
     keep_x:=array_append(keep_x,xid);k:=k+1;
    end loop;
   end loop;
  end loop;
  delete from public.checklist_questions where requirement_id in(select q.id from public.checklist_requirements q join public.checklist_sections s on s.id=q.section_id where s.revision_id=rid) and not(id=any(keep_x));
  delete from public.checklist_requirements where section_id in(select id from public.checklist_sections where revision_id=rid) and not(id=any(keep_q));
  delete from public.checklist_sections where revision_id=rid and not(id=any(keep_s));
  delete from public.checklist_components where revision_id=rid;
  for source in select value::uuid from jsonb_array_elements_text(coalesce(p->'components','[]')) loop
   if not exists(select 1 from public.checklist_revisions cr join public.checklist_templates ct on ct.id=cr.template_id where cr.id=source and cr.status in ('published','retired') and ct.category<>'integrated' and (ct.organization_id is null or ct.organization_id=org)) then raise exception 'Origem inválida, recursiva ou exclusiva de outro cliente'; end if;
   insert into public.checklist_components values(rid,source);
  end loop;
  if h->>'category'<>'integrated' and exists(select 1 from public.checklist_components where revision_id=rid) then raise exception 'Somente modelos integrados aceitam composição'; end if;
  h:=h||jsonb_build_object('code',t.code,'criteria',coalesce((select jsonb_agg(distinct v) from (select to_jsonb(c) v from public.audit_types c where c.id in(select criterion_id from public.checklist_sections where revision_id=rid) union all select v from public.checklist_components cc join public.checklist_revisions cr on cr.id=cc.source_revision_id cross join lateral jsonb_array_elements(cr.header->'criteria')v where cc.revision_id=rid)criteria),'[]'));
  update public.checklist_revisions set header=h,reason=p->>'reason',lock_version=lock_version+1 where id=rid;
  if cmd='publish' then
   if nullif(trim(p->>'reason'),'') is null then raise exception 'Informe o motivo da revisão'; end if;
   if h->>'category'='integrated' then
    if not exists(select 1 from public.checklist_components where revision_id=rid) or exists(select 1 from public.checklist_sections where revision_id=rid) then raise exception 'Composição requer modelos de base e nenhuma seção própria'; end if;
   elsif not exists(select 1 from public.checklist_questions x join public.checklist_requirements q on q.id=x.requirement_id join public.checklist_sections s on s.id=q.section_id where s.revision_id=rid and x.active) then raise exception 'Inclua uma pergunta ativa'; end if;
   if exists(select 1 from public.checklist_sections s left join public.audit_types c on c.id=s.criterion_id where s.revision_id=rid and (nullif(trim(s.title),'') is null or c.id is null or not c.active)) then raise exception 'Cada seção exige título e critério ativo'; end if;
   if exists(select 1 from public.checklist_requirements q join public.checklist_sections s on s.id=q.section_id where s.revision_id=rid and (nullif(trim(q.reference),'') is null or not exists(select 1 from public.checklist_questions x where x.requirement_id=q.id))) then raise exception 'Requisito exige referência e perguntas'; end if;
   if exists(select 1 from public.checklist_questions x join public.checklist_requirements q on q.id=x.requirement_id join public.checklist_sections s on s.id=q.section_id where s.revision_id=rid and x.active and nullif(trim(x.prompt),'') is null) then raise exception 'Preencha as perguntas ativas'; end if;
   update public.checklist_revisions set status='retired' where template_id=t.id and status='published';
   update public.checklist_revisions set status='published',published_at=now() where id=rid;
   update public.checklist_templates set name=h->>'name',description=h->>'description',category=h->>'category',organization_id=org,status='published',type_id=(select criterion_id from public.checklist_sections where revision_id=rid order by sort_order limit 1),updated_at=now() where id=t.id;
  elsif t.status='draft' then update public.checklist_templates set name=h->>'name',category=h->>'category',organization_id=org where id=t.id; end if;
  return private.checklist_revision_json(rid);
 end if;
 raise exception 'Comando de biblioteca inválido';
end $function$;

CREATE OR REPLACE FUNCTION private.checklist_execution(cmd text, p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare aid uuid:=nullif(p->>'audit_id','')::uuid;a public.audits%rowtype;s public.schedule_items%rowtype;d public.audit_days%rowtype;r public.requirement_assessments%rowtype;x record;
 rid uuid;tid uuid;source uuid;fid uuid;nid uuid;op uuid;patch jsonb;out jsonb;rev public.checklist_revisions%rowtype;hdr jsonb;ids uuid[];lastid uuid;sections jsonb;off int:=greatest(0,coalesce((p->>'page')::int,0))*30;
begin
 if auth.uid() is null or not private.is_active_account(auth.uid()) then raise exception 'Sessão ativa necessária';end if;
 select * into a from public.audits where id=aid;
 if a.id is null or not(private.is_audit_participant(aid) or private.workspace_member(a.organization_id) or private.workspace_conductor(aid)) then raise exception 'Auditoria indisponível';end if;
 if cmd in ('scope_catalog','findings','evidence_catalog','history','filters') then
  if not private.checklist_internal(aid) then raise exception 'Consulta restrita à equipe interna';end if;
  if cmd='scope_catalog' then return coalesce((select jsonb_agg(z) from(select q.id,q.prompt,rq.id requirement_id,rq.reference,cs.title section,cr.header->'criteria' criteria,exists(select 1 from private.checklist_scope sc where sc.audit_id=aid and sc.schedule_id=(p->>'schedule_id')::uuid and sc.id=q.id and sc.included) included from public.audit_checklists ac join public.checklist_sections cs on cs.revision_id=ac.revision_id join public.checklist_requirements rq on rq.section_id=cs.id join public.checklist_questions q on q.requirement_id=rq.id where ac.audit_id=aid and q.active and (coalesce(p->>'search','')='' or concat(q.prompt,' ',rq.reference) ilike '%'||(p->>'search')||'%') order by cs.sort_order,rq.sort_order,q.sort_order limit 30 offset off)z),'[]');end if;
  if cmd='findings' then return coalesce((select jsonb_agg(z) from(select f.*,u.full_name author,ar.audit_day_id,ar.process_id,(select coalesce(jsonb_agg(evidence_id),'[]') from public.finding_evidence_links where finding_id=f.id) evidence_ids from public.assessment_findings f join public.requirement_assessments ar on ar.id=f.assessment_id left join public.user_profiles u on u.user_id=f.created_by where f.audit_id=aid and (coalesce(p->>'kind','')='' or f.kind=p->>'kind') order by f.created_at desc limit 30 offset off)z),'[]');end if;
  if cmd='evidence_catalog' then return coalesce((select jsonb_agg(z) from(select e.id,e.filename,e.caption,e.mime_type,e.size_bytes,e.uploaded_at,e.uploaded_by,u.full_name author from public.evidence_files e left join public.user_profiles u on u.user_id=e.uploaded_by where e.audit_id=aid order by e.uploaded_at desc limit 30 offset off)z),'[]');end if;
  if cmd='history' then return coalesce((select jsonb_agg(z) from(select h.*,u.full_name author from public.checklist_record_history h left join public.user_profiles u on u.user_id=h.actor where h.audit_id=aid and (nullif(p->>'entity_id','') is null or h.entity_id=(p->>'entity_id')::uuid) order by h.created_at desc limit 30 offset off)z),'[]');end if;
  return jsonb_build_object('criteria',(select coalesce(jsonb_agg(distinct value),'[]') from public.audit_checklists ac cross join lateral jsonb_array_elements(ac.metadata->'criteria') where ac.audit_id=aid),'sections',(select coalesce(jsonb_agg(z),'[]') from(select distinct section_id id,section name from private.checklist_scope where audit_id=aid)z),'authors',(select coalesce(jsonb_agg(z),'[]') from(select distinct u.user_id id,u.full_name name from public.user_profiles u join public.organization_memberships m on m.user_id=u.user_id join public.audit_participants ap on ap.membership_id=m.id where ap.audit_id=aid and ap.active)z));
 end if;

 if cmd='suggest' then
  if not(private.workspace_conductor(aid) or private.profile_admin(auth.uid())) then raise exception 'Sem permissão';end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id',cr.id,'template_id',t.id,'number',cr.revision_number,'header',cr.header-'internal_notes','components',(select coalesce(jsonb_agg(source_revision_id),'[]') from public.checklist_components where revision_id=cr.id))) from public.checklist_revisions cr join public.checklist_templates t on t.id=cr.template_id where cr.status='published' and t.status='published' and (t.organization_id is null or t.organization_id=a.organization_id) and (cardinality(a.criterion_ids)=0 or exists(select 1 from jsonb_array_elements(cr.header->'criteria') c where (c->>'id')::uuid=any(a.criterion_ids)))),'[]');
 elsif cmd='context' then
  if not private.checklist_internal(aid) then raise exception 'Execução restrita à equipe interna';end if;
  return jsonb_build_object('audit',to_jsonb(a),'company',(select legal_name from public.organizations where id=a.organization_id),'admin',private.profile_admin(auth.uid()),'can_edit',private.workspace_conductor(aid),'days',coalesce((select jsonb_agg(to_jsonb(d) order by audit_date) from public.audit_days d where audit_id=aid),'[]'),'activities',coalesce((select jsonb_agg(to_jsonb(si)||jsonb_build_object('process',(select name from public.audit_processes where id=si.process_id))) from public.schedule_items si join public.audit_days ad on ad.id=si.audit_day_id where ad.audit_id=aid and not si.withdrawn and si.category='assessment'),'[]'),'models',coalesce((select jsonb_agg(metadata) from public.audit_checklists where audit_id=aid),'[]'),'stats',private.checklist_stats(aid));
 elsif cmd='questions' then
  if not private.checklist_internal(aid) then raise exception 'Execução restrita à equipe interna';end if;
  return (with source as(select sc.*,to_jsonb(ar) assessment,u.full_name author,pu.full_name planned_author,pr.name process,
   exists(select 1 from public.assessment_findings f where f.kind='NC' and (f.assessment_id=ar.id or exists(select 1 from public.assessment_finding_links fl where fl.finding_id=f.id and fl.assessment_id=ar.id))) has_nc
   from private.checklist_scope sc left join public.audit_processes pr on pr.id=sc.process_id left join public.organization_memberships pm on pm.id=sc.assignee_membership_id left join public.user_profiles pu on pu.user_id=pm.user_id
   left join public.requirement_assessments ar on ar.audit_id=sc.audit_id and ar.audit_day_id=sc.audit_day_id and coalesce(ar.question_id,ar.extra_question_id)=sc.id and ar.process_id is not distinct from sc.process_id
   left join public.user_profiles u on u.user_id=coalesce(ar.updated_by,ar.created_by)
   where sc.audit_id=aid and sc.included and (nullif(p->>'schedule_id','') is null or sc.schedule_id=(p->>'schedule_id')::uuid)),
 filtered as(select * from source where
 (coalesce(p->>'search','')='' or concat(reference,' ',prompt,' ',theme) ilike '%'||(p->>'search')||'%')
 and (nullif(p->>'criterion_id','') is null or criterion_id=(p->>'criterion_id')::uuid)
 and (nullif(p->>'section_id','') is null or section_id=(p->>'section_id')::uuid)
 and (nullif(p->>'process_id','') is null or process_id=(p->>'process_id')::uuid)
 and (nullif(p->>'day_id','') is null or audit_day_id=(p->>'day_id')::uuid)
 and (nullif(p->>'author_id','') is null or coalesce(assessment->>'updated_by',assessment->>'created_by')=p->>'author_id' or assignee_membership_id in(select id from public.organization_memberships where user_id=(p->>'author_id')::uuid))
 and (coalesce(p->>'result','')='' or coalesce(assessment->>'result','not_assessed')=p->>'result')
 and (coalesce(p->>'state','')='' or coalesce(assessment->>'operational_state','not_started')=p->>'state')
 and (not coalesce((p->>'with_nc')::boolean,false) or has_nc)
 and (not coalesce((p->>'pending')::boolean,false) or coalesce(assessment->>'operational_state','not_started')<>'completed'))
 select jsonb_build_object('available',(select count(*) from source),'total',(select count(*) from filtered),'items',coalesce((select jsonb_agg(z) from(select * from filtered order by audit_date,section,reference,sort_order,id limit 30 offset off)z),'[]')));
 elsif cmd='assessment' then
  select * into r from public.requirement_assessments where id=(p->>'assessment_id')::uuid and audit_id=aid;
  if r.id is null or not private.checklist_internal(aid) then raise exception 'Avaliação indisponível';end if;
  return jsonb_build_object('record',to_jsonb(r),'uploads',coalesce((select jsonb_agg(to_jsonb(up)) from public.assessment_uploads up where up.assessment_id=r.id),'[]'),'findings',coalesce((select jsonb_agg(to_jsonb(f)) from public.assessment_findings f where f.assessment_id=r.id or exists(select 1 from public.assessment_finding_links l where l.finding_id=f.id and l.assessment_id=r.id)),'[]'),'complements',coalesce((select jsonb_agg(to_jsonb(c)||jsonb_build_object('evidence_ids',(select coalesce(jsonb_agg(evidence_id),'[]') from public.complement_evidence_links where complement_id=c.id),'finding_ids',(select coalesce(jsonb_agg(finding_id),'[]') from public.complement_finding_links where complement_id=c.id))) from public.assessment_complements c where c.assessment_id=r.id),'[]'),'evidence',coalesce((select jsonb_agg(to_jsonb(e)-'storage_path') from public.evidence_files e where e.assessment_id=r.id or exists(select 1 from public.evidence_assessment_links l where l.evidence_id=e.id and l.assessment_id=r.id)),'[]'),'history',coalesce((select jsonb_agg(to_jsonb(h)||jsonb_build_object('author',(select full_name from public.user_profiles where user_id=h.actor)) order by revision desc) from (select * from public.assessment_history where assessment_id=r.id order by revision desc limit 20)h),'[]'));
 end if;
 perform 1 from public.audits where id=aid for update;
 select * into a from public.audits where id=aid;
 if not private.workspace_conductor(aid) then raise exception 'Somente o condutor designado pode gravar';end if;
 if a.status in ('completed','cancelled','awaiting_signoff') then raise exception 'Auditoria encerrada';end if;
 if cmd in ('scope_include','scope_exclude','independent') then
  select si.* into s from public.schedule_items si join public.audit_days ad on ad.id=si.audit_day_id where si.id=(p->>'schedule_id')::uuid and ad.audit_id=aid and not si.withdrawn and si.category='assessment' and ad.status<>'completed';
  if s.id is null or s.status='completed' or nullif(trim(p->>'reason'),'') is null then raise exception 'Atividade aberta e motivo obrigatórios';end if;
  if cmd='independent' then
   if not coalesce((p->>'confirm_scope')::boolean,false) or nullif(trim(p->>'prompt'),'') is null then raise exception 'Confirme a inclusão de uma unidade independente no escopo';end if;
   select c.*,ar.requirement_id into x from public.assessment_complements c join public.requirement_assessments ar on ar.id=c.assessment_id where c.id=(p->>'complement_id')::uuid and ar.audit_id=aid;
   if x.id is null then raise exception 'Complemento fora da auditoria';end if;
   insert into public.audit_extra_questions(audit_id,requirement_id,origin_complement_id,prompt,reason,created_by,operation_id) values(aid,x.requirement_id,x.id,p->>'prompt',p->>'reason',auth.uid(),(p->>'operation_id')::uuid) on conflict(audit_id,operation_id) do update set operation_id=excluded.operation_id returning id into fid;
   insert into public.schedule_extra_questions values(s.id,fid,true) on conflict do nothing;
  else
   select q.*,rq.id rid into x from public.checklist_questions q join public.checklist_requirements rq on rq.id=q.requirement_id join public.checklist_sections cs on cs.id=rq.section_id join public.audit_checklists ac on ac.revision_id=cs.revision_id where q.id=(p->>'question_id')::uuid and ac.audit_id=aid and q.active;
   if x.id is null then
    if cmd<>'scope_exclude' or not exists(select 1 from public.audit_extra_questions where id=(p->>'question_id')::uuid and audit_id=aid) then raise exception 'Pergunta fora das revisões confirmadas';end if;
    update public.schedule_extra_questions set included=false where schedule_id=s.id and question_id=(p->>'question_id')::uuid;
   else
    if not exists(select 1 from public.schedule_requirements where schedule_item_id=s.id and requirement_id=x.requirement_id) then
     if cmd='scope_exclude' then raise exception 'Pergunta não incluída';end if;
     insert into public.schedule_requirements values(s.id,x.requirement_id);
     insert into public.schedule_question_scope select s.id,q.id,false,p->>'reason',auth.uid(),now() from public.checklist_questions q where q.requirement_id=x.requirement_id on conflict do nothing;
    end if;
    insert into public.schedule_question_scope values(s.id,x.id,cmd='scope_include',p->>'reason',auth.uid(),now()) on conflict(schedule_id,question_id) do update set included=excluded.included,reason=excluded.reason,actor=excluded.actor,updated_at=now();
   end if;
   fid:=(p->>'question_id')::uuid;
  end if;
  insert into public.checklist_record_history(audit_id,entity_type,entity_id,content,actor) values(aid,cmd,fid,p,auth.uid());
  insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,metadata) values(a.organization_id,auth.uid(),cmd,'audits',aid,p);
  return jsonb_build_object('id',fid,'stats',private.checklist_stats(aid));
 end if;

 if cmd='confirm' then
  if a.plan_revision>0 then raise exception 'Conjunto fixado pelo plano; alteração exige revisão de escopo';end if;
  ids:=array(select value::uuid from jsonb_array_elements_text(p->'revisions'));
  if cardinality(ids)=0 then raise exception 'Selecione ao menos uma revisão';end if;
  -- Validate the entire selection before replacing links.
  foreach rid in array ids loop
   select cr.* into rev from public.checklist_revisions cr join public.checklist_templates ct on ct.id=cr.template_id where cr.id=rid and cr.status='published' and ct.status='published' and (ct.organization_id is null or ct.organization_id=a.organization_id) for share of cr,ct;
   if rev.id is null then raise exception 'Modelo indisponível ou substituído; confira novamente as sugestões';end if;
  end loop;
  delete from public.audit_checklists where audit_id=aid;
  foreach rid in array ids loop
   for source in select rid where not exists(select 1 from public.checklist_components where revision_id=rid) union all select source_revision_id from public.checklist_components where revision_id=rid loop
    select * into rev from public.checklist_revisions where id=source;
    if nullif(rev.header->>'organization_id','') is not null and (rev.header->>'organization_id')::uuid<>a.organization_id then raise exception 'Origem exclusiva de outra empresa';end if;
    if exists(select 1 from public.audit_checklists where audit_id=aid and revision_id=source) then raise exception 'Origem duplicada no conjunto';end if;
    insert into public.audit_checklists(audit_id,revision_id,attached_by,metadata) values(aid,source,auth.uid(),rev.header||jsonb_build_object('revision',rev.revision_number,'revision_id',source,'composition_id',rid));
   end loop;
  end loop;
  if exists(select 1 from unnest(a.criterion_ids) cid where not exists(select 1 from public.audit_checklists ac cross join lateral jsonb_array_elements(ac.metadata->'criteria')c where ac.audit_id=aid and (c->>'id')::uuid=cid)) then raise exception 'O conjunto não cobre todos os critérios selecionados';end if;
  update public.audits set checklist_confirmed_at=now(),checklist_confirmed_by=auth.uid(),checklist_contract=2,lock_version=lock_version+1 where id=aid;
  return '{}';
 end if;
 if a.status<>'in_progress' then raise exception 'Inicie a auditoria antes de registrar a execução';end if;
 if cmd in ('save','complete') then
  select si.* into s from public.schedule_items si join public.audit_days ad on ad.id=si.audit_day_id where si.id=(p->>'schedule_id')::uuid and ad.audit_id=aid and not si.withdrawn;
  select * into d from public.audit_days where id=s.audit_day_id;
  select sc.* into x from private.checklist_scope sc where sc.id=(p->>'question_id')::uuid and sc.schedule_id=s.id and sc.included;
  if s.id is null or x.id is null or d.status='completed' or s.status='completed' then raise exception 'Pergunta ou dia indisponível';end if;
  select * into r from public.requirement_assessments where audit_id=aid and audit_day_id=d.id and coalesce(question_id,extra_question_id)=x.id and process_id is not distinct from s.process_id for update;
  op:=(p->>'operation_id')::uuid;
  if op is null then raise exception 'Identificador da operação obrigatório';end if;
  if r.last_operation=op then return to_jsonb(r);end if;
  if coalesce(r.lock_version,0)<>coalesce((p->>'lock_version')::int,-1) then raise exception using errcode='40001',message='Conflito: outra sessão salvou esta pergunta. Revise antes de reenviar';end if;
  patch:=coalesce(p->'patch','{}');
  if r.id is null then
   insert into public.requirement_assessments(audit_id,audit_day_id,requirement_id,question_id,extra_question_id,process_id,created_by,updated_by) values(aid,d.id,x.requirement_id,x.master_question_id,x.extra_question_id,s.process_id,auth.uid(),auth.uid()) returning * into r;
  end if;
  update public.requirement_assessments set result=case when patch?'result' then patch->>'result' else result end,
   evidence_text=case when patch?'evidence_text' then patch->>'evidence_text' else evidence_text end,
   notes=case when patch?'notes' then patch->>'notes' else notes end,
   sampling=case when patch?'sampling' then nullif(patch->>'sampling','') else sampling end,
   sample_description=case when patch?'sample_description' then patch->>'sample_description' else sample_description end,
   nc_justification=case when patch?'nc_justification' then patch->>'nc_justification' else nc_justification end,
   operational_state='in_progress',lock_version=lock_version+1,last_operation=op,updated_at=clock_timestamp(),updated_by=auth.uid() where id=r.id returning * into r;
  if cmd='complete' then
   if exists(select 1 from public.assessment_uploads where assessment_id=r.id and status in ('pending','failed')) then raise exception 'Resolva ou cancele os uploads pendentes antes de concluir';end if;
   if r.result='not_assessed' or r.result='improvement' then raise exception 'Defina um resultado técnico';end if;
   if r.result='not_applicable' and (not x.allow_na or nullif(trim(r.evidence_text),'') is null) then raise exception 'N/A exige permissão do modelo e justificativa textual';end if;
   if nullif(trim(r.evidence_text),'') is null and not exists(select 1 from public.evidence_files e where (e.assessment_id=r.id or exists(select 1 from public.evidence_assessment_links l where l.evidence_id=e.id and l.assessment_id=r.id)) and nullif(trim(e.caption),'') is not null) then raise exception 'Informe evidência textual ou anexo com legenda';end if;
   if r.sampling is null or (r.sampling='yes' and nullif(trim(r.sample_description),'') is null) then raise exception 'Responda a amostragem; Sim exige descrição';end if;
   if r.result in ('nonconforming','partially_conforming') and not exists(select 1 from public.assessment_findings f where f.kind='NC' and (f.assessment_id=r.id or exists(select 1 from public.assessment_finding_links l where l.finding_id=f.id and l.assessment_id=r.id))) and (r.result='nonconforming' or nullif(trim(r.nc_justification),'') is null) then raise exception 'Vincule NC; resultado parcial admite decisão técnica justificada';end if;
   if exists(select 1 from public.assessment_complements c where c.assessment_id=r.id and c.blocking and nullif(trim(c.response),'') is null) then raise exception 'Responda os complementos impeditivos';end if;
   update public.requirement_assessments set operational_state='completed' where id=r.id returning * into r;
  end if;
  insert into public.assessment_history(assessment_id,revision,content,actor) values(r.id,r.lock_version,to_jsonb(r),auth.uid());
  return to_jsonb(r);
 end if;
 select * into r from public.requirement_assessments where id=(p->>'assessment_id')::uuid and audit_id=aid for update;
 if r.id is null or exists(select 1 from public.audit_days where id=r.audit_day_id and status='completed') then raise exception 'Avaliação indisponível ou dia encerrado';end if;
 if r.operational_state='completed' then raise exception 'Salve uma revisão da avaliação antes de alterar seus registros';end if;
 if cmd in ('upload_begin','upload_state') then
  op:=(p->>'operation_id')::uuid;
  if op is null then raise exception 'Identificador da operação obrigatório';end if;
  if cmd='upload_begin' then
   insert into public.assessment_uploads values(op,r.id,'pending',left(p->>'filename',200),null,auth.uid(),now()) on conflict(operation_id) do update set status=case when public.assessment_uploads.status='completed' then 'completed' else 'pending' end,updated_at=now() where public.assessment_uploads.assessment_id=r.id;
  else
   if p->>'status' not in ('failed','cancelled') then raise exception 'Estado de upload inválido';end if;
   if p->>'status'='cancelled' and nullif(trim(p->>'reason'),'') is null then raise exception 'Informe o motivo de cancelamento';end if;
   update public.assessment_uploads set status=p->>'status',reason=p->>'reason',updated_at=now() where operation_id=op and assessment_id=r.id and status<>'completed';
  end if;
  return '{}';
 elsif cmd='finding_update' then
  select * into x from public.assessment_findings where id=(p->>'id')::uuid and audit_id=aid and assessment_id=r.id for update;
  if x.id is null or x.lock_version<>coalesce((p->>'lock_version')::int,-1) then raise exception using errcode='40001',message='Constatação alterada; recarregue';end if;
  if nullif(trim(p->>'description'),'') is null or nullif(trim(p->>'reason'),'') is null then raise exception 'Descrição e motivo obrigatórios';end if;
  insert into public.checklist_record_history(audit_id,entity_type,entity_id,content,actor) values(aid,'finding_previous',x.id,to_jsonb(x)||jsonb_build_object('reason',p->>'reason'),auth.uid());
  update public.assessment_findings set description=p->>'description',lock_version=lock_version+1 where id=x.id;
  if x.nonconformity_id is not null then update public.nonconformities set description=p->>'description' where id=x.nonconformity_id;end if;
  return '{}';
 elsif cmd in ('finding_evidence','complement_evidence','complement_finding') then
  if cmd<>'complement_finding' and not exists(select 1 from public.evidence_files where id=(p->>'evidence_id')::uuid and audit_id=aid) then raise exception 'Evidência fora da auditoria';end if;
  if cmd<>'complement_evidence' and not exists(select 1 from public.assessment_findings where id=(p->>'finding_id')::uuid and audit_id=aid) then raise exception 'Constatação fora da auditoria';end if;
  if cmd<>'finding_evidence' and not exists(select 1 from public.assessment_complements where id=(p->>'complement_id')::uuid and assessment_id=r.id) then raise exception 'Complemento fora da avaliação';end if;
  if cmd='finding_evidence' then insert into public.finding_evidence_links values((p->>'finding_id')::uuid,(p->>'evidence_id')::uuid) on conflict do nothing;
  elsif cmd='complement_evidence' then insert into public.complement_evidence_links values((p->>'complement_id')::uuid,(p->>'evidence_id')::uuid) on conflict do nothing;
  else insert into public.complement_finding_links values((p->>'complement_id')::uuid,(p->>'finding_id')::uuid) on conflict do nothing;end if;
  insert into public.checklist_record_history(audit_id,entity_type,entity_id,content,actor) values(aid,cmd,r.id,p,auth.uid());return '{}';
 end if;

 if cmd='finding' then
  op:=(p->>'operation_id')::uuid;
  if op is null then raise exception 'Operação obrigatória';end if;
  select id into fid from public.assessment_findings where audit_id=aid and operation_id=op;
  if fid is not null then return jsonb_build_object('id',fid);end if;
  if p->>'kind' not in ('NC','OBS','OM') or nullif(trim(p->>'description'),'') is null then raise exception 'Tipo e descrição obrigatórios';end if;
  nid:=null;
  if p->>'kind'='NC' then
   if nullif(trim(p->>'responsible'),'') is null or nullif(p->>'due_date','') is null then raise exception 'NC exige responsável e prazo';end if;
   insert into public.nonconformities(audit_id,audit_day_id,requirement_id,process_id,code,description,classification,created_by) values(aid,r.audit_day_id,r.requirement_id,r.process_id,'NC-'||(select count(*)+1 from public.nonconformities where audit_id=aid),p->>'description',p->>'classification',auth.uid()) returning id into nid;
   insert into public.action_plans(nonconformity_id,action_text,responsible_name,due_date,created_by) values(nid,coalesce(nullif(p->>'action_text',''),'A definir'),p->>'responsible',(p->>'due_date')::date,auth.uid());
  end if;
  insert into public.assessment_findings(audit_id,assessment_id,kind,code,description,nonconformity_id,created_by,operation_id) values(aid,r.id,p->>'kind',(p->>'kind')||'-'||(select count(*)+1 from public.assessment_findings where audit_id=aid and kind=p->>'kind'),p->>'description',nid,auth.uid(),op) returning id into fid;
  return jsonb_build_object('id',fid);
 elsif cmd='link_finding' then
  fid:=(p->>'finding_id')::uuid;
  if not exists(select 1 from public.assessment_findings where id=fid and audit_id=aid) then raise exception 'Constatação fora da auditoria';end if;
  insert into public.assessment_finding_links values(fid,r.id) on conflict do nothing;return '{}';
 elsif cmd='complement' then
  if nullif(trim(p->>'prompt'),'') is null or nullif(trim(p->>'reason'),'') is null then raise exception 'Pergunta complementar e motivo obrigatórios';end if;
  insert into public.assessment_complements(assessment_id,prompt,reason,response,blocking,created_by,operation_id) values(r.id,p->>'prompt',p->>'reason',p->>'response',coalesce((p->>'blocking')::boolean,true),auth.uid(),(p->>'operation_id')::uuid) on conflict(assessment_id,operation_id) do nothing;return '{}';
 elsif cmd='complement_response' then
  select * into x from public.assessment_complements where id=(p->>'id')::uuid and assessment_id=r.id for update;
  if x.id is null then raise exception 'Complemento inexistente';end if;
  if x.lock_version<>coalesce((p->>'lock_version')::int,0) then raise exception using errcode='40001',message='Complemento alterado; recarregue';end if;
  insert into public.checklist_record_history(audit_id,entity_type,entity_id,content,actor) values(aid,'complement_previous',x.id,to_jsonb(x),auth.uid());
  update public.assessment_complements set response=p->>'response',lock_version=lock_version+1 where id=x.id;return '{}';
 elsif cmd='evidence_metadata' then
  insert into public.checklist_record_history(audit_id,entity_type,entity_id,content,actor) select aid,'evidence_previous',id,to_jsonb(e)-'storage_path',auth.uid() from public.evidence_files e where id=(p->>'id')::uuid and assessment_id=r.id;
  update public.evidence_files set caption=p->>'caption',include_in_rda=coalesce((p->>'include_in_rda')::boolean,false),display_order=coalesce((p->>'display_order')::int,0) where id=(p->>'id')::uuid and assessment_id=r.id;return '{}';
 elsif cmd='link_evidence' then
  if not exists(select 1 from public.evidence_files where id=(p->>'id')::uuid and audit_id=aid) then raise exception 'Evidência fora da auditoria';end if;
  insert into public.evidence_assessment_links values((p->>'id')::uuid,r.id) on conflict do nothing;return '{}';
 end if;
 raise exception 'Comando de execução inválido';
end $function$;

CREATE OR REPLACE FUNCTION private.workspace_documents(cmd text, p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare aid uuid:=nullif(p->>'audit_id','')::uuid; did uuid:=nullif(p->>'document_id','')::uuid; kind text:=p->>'kind'; a public.audits%rowtype; dayid uuid; s public.schedule_items%rowtype; content jsonb; tbl text; vt text; st text; v int; vid uuid; members uuid[]; result jsonb;
begin
 if auth.uid() is null or not private.is_active_account(auth.uid()) then raise exception 'Sessão ativa necessária'; end if;
 if cmd not in ('list','get') then perform 1 from public.audits where id=aid for update; end if;
 select * into a from public.audits where id=aid;
 if a.id is null then raise exception 'Auditoria inexistente'; end if;
 if cmd='list' then
  if not private.is_audit_participant(aid) and not private.workspace_member(a.organization_id) then raise exception 'Sem acesso'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(x) order by x.generated_at),'[]') from (
   select r.id,'daily' kind,'Relatório diário — Dia '||d.day_number||' — '||d.audit_date title,r.status,r.generated_at,r.finalized_at from public.daily_reports r join public.audit_days d on d.id=r.audit_day_id where r.audit_id=aid and private.workspace_document_access(r.id,'daily',aid,r.finalized_at is not null)
   union all select r.id,'final','Relatório final',r.status,r.generated_at,r.finalized_at from public.audit_final_reports r where r.audit_id=aid and private.workspace_document_access(r.id,'final',aid,r.finalized_at is not null)
   union all select r.id,'minutes',case when r.kind='opening' then 'Ata de abertura' when r.kind='closing' then 'Ata de encerramento' else 'Ata de reunião' end,r.status,r.generated_at,r.finalized_at from public.audit_minutes r where r.audit_id=aid and private.workspace_document_access(r.id,'minutes',aid,r.finalized_at is not null)
  ) x);
 end if;
 if cmd in ('get','approve','revise','notes') then
  tbl:=case kind when 'daily' then 'daily_reports' when 'final' then 'audit_final_reports' when 'minutes' then 'audit_minutes' end;
  vt:=case kind when 'daily' then 'daily_report_versions' when 'final' then 'audit_final_report_versions' when 'minutes' then 'audit_minutes_versions' end;
  if tbl is null then raise exception 'Tipo documental inválido'; end if;
  execute format('select content,status from public.%I where id=$1 and audit_id=$2',tbl) into content,st using did,aid;
  if cmd='get' and st='review' and not private.workspace_conductor(aid) and not private.profile_admin(auth.uid()) then
   execute format('select content from public.%I where report_id=$1 order by version_number desc limit 1',vt) into content using did;
   if content is not null then st:='completed'; end if;
  end if;
  if content is null or not private.workspace_document_access(did,kind,aid,st in ('completed','pending_acknowledgements')) then raise exception 'Documento indisponível'; end if;
  if cmd='get' then
   execute format('select coalesce(jsonb_agg(jsonb_build_object(''number'',version_number,''content'',content,''frozen_at'',frozen_at) order by version_number desc),''[]'') from public.%I where report_id=$1',vt) into result using did;
   return jsonb_build_object('content',content,'status',st,'versions',result,'can_approve',private.workspace_conductor(aid),'kind',kind);
  end if;
 end if;
 perform 1 from public.audits where id=aid for update;
 if not private.workspace_conductor(aid) then raise exception 'Somente o condutor pode gerar ou aprovar documentos'; end if;
 if cmd='close_day' then
 if exists(select 1 from public.requirement_assessments where audit_id=aid and audit_day_id=(p->>'day_id')::uuid and question_id is not null and operational_state<>'completed') then raise exception 'Conclua ou resolva as avaliações pendentes antes de encerrar'; end if;
  dayid:=(p->>'day_id')::uuid;
  if exists(select 1 from public.assessment_uploads up join public.requirement_assessments ar on ar.id=up.assessment_id where ar.audit_day_id=dayid and up.status in ('pending','failed')) then raise exception 'Existem uploads pendentes ou com falha; resolva no checklist';end if;
  if not exists(select 1 from public.audit_days where id=dayid and audit_id=aid and attendance_confirmed) then raise exception 'Confirme a presença do dia antes de encerrar'; end if;
  select id into did from public.daily_reports where audit_day_id=dayid;
  if did is not null then return jsonb_build_object('id',did); end if;
  if a.status<>'in_progress' then raise exception 'Auditoria não está em execução'; end if;
  if exists(select 1 from public.schedule_items where audit_day_id=dayid and not withdrawn and category<>'break' and status<>'completed') then raise exception 'Conclua ou reagende as atividades pendentes antes de encerrar o dia'; end if;
  if exists(select 1 from public.requirement_assessments ra where ra.audit_day_id=dayid and ra.result='nonconforming' and nullif(trim(ra.nc_justification),'') is null and not exists(select 1 from public.nonconformities n where n.audit_id=aid and n.requirement_id=ra.requirement_id and n.process_id is not distinct from ra.process_id)) then raise exception 'Vincule NC ou justifique os itens não conformes'; end if;
  update public.audit_days set status='completed',ended_at=now(),started_at=coalesce(started_at,now()),opening_plan_version=coalesce(opening_plan_version,a.plan_revision) where id=dayid;
  content:=private.workspace_snapshot(aid,dayid);
  insert into public.daily_reports(audit_id,audit_day_id,status,content) values(aid,dayid,'review',content) returning id into did;
  insert into public.audit_document_recipients select aid,did,'daily',membership_id from public.audit_day_attendance where audit_day_id=dayid;
  return jsonb_build_object('id',did);
 elsif cmd='minutes' then
  select si.* into s from public.schedule_items si join public.audit_days d on d.id=si.audit_day_id where si.id=(p->>'schedule_id')::uuid and d.audit_id=aid and si.status='completed' and si.category in ('opening','closing','meeting');
  if s.id is null then raise exception 'Registre a reunião como realizada'; end if;
  select id into did from public.audit_minutes where schedule_item_id=s.id;
  if did is not null then return jsonb_build_object('id',did); end if;
  if not exists(select 1 from public.audit_day_attendance where audit_day_id=s.audit_day_id) then raise exception 'Registre os participantes do dia'; end if;
  content:=private.workspace_snapshot(aid,s.audit_day_id)||jsonb_build_object('meeting',to_jsonb(s),'additional_notes',coalesce(p->>'notes',''));
  insert into public.audit_minutes(audit_id,schedule_item_id,kind,content) values(aid,s.id,s.category,content) returning id into did;
  insert into public.audit_document_recipients select aid,did,'minutes',membership_id from public.audit_day_attendance where audit_day_id=s.audit_day_id;
  return jsonb_build_object('id',did);
 elsif cmd='finish' then
  select id into did from public.audit_final_reports where audit_id=aid;
  if did is not null then return jsonb_build_object('id',did); end if;
  if a.status<>'in_progress' then raise exception 'Auditoria não está em execução'; end if;
  if exists(select 1 from public.audit_days d where d.audit_id=aid and d.status<>'completed' and exists(select 1 from public.schedule_items si where si.audit_day_id=d.id and not si.withdrawn and si.category<>'break')) then raise exception 'Encerre todos os dias auditados'; end if;
  if not exists(select 1 from public.daily_reports where audit_id=aid) or exists(select 1 from public.daily_reports where audit_id=aid and finalized_at is null) or exists(select 1 from public.audit_minutes where audit_id=aid and finalized_at is null) then raise exception 'Valide os relatórios diários e atas antes de finalizar'; end if;
  if coalesce(p->'certification'->>'status','not_applicable') not in ('not_applicable','pending','granted','not_granted') then raise exception 'Situação de certificação inválida'; end if;
  if p->'certification'->>'status' in ('granted','not_granted') and (nullif(trim(p->'certification'->>'source'),'') is null or nullif(p->'certification'->>'date','') is null or nullif(trim(p->'certification'->>'reference'),'') is null) then raise exception 'Informe origem, data e referência da decisão de certificação'; end if;
  update public.audits set status='awaiting_signoff',execution_ended_at=now(),certification=coalesce(p->'certification',certification) where id=aid;
  content:=private.workspace_snapshot(aid)||jsonb_build_object('additional_notes',coalesce(p->>'notes',''));
  insert into public.audit_final_reports(audit_id,status,content,created_by) values(aid,'review',content,auth.uid()) returning id into did;
  insert into public.audit_document_recipients select distinct aid,did,'final',at.membership_id from public.audit_day_attendance at join public.audit_days d on d.id=at.audit_day_id where d.audit_id=aid;
  return jsonb_build_object('id',did);
 elsif cmd='notes' then
  if st<>'review' then raise exception 'Crie uma retificação para alterar documento aprovado'; end if;
  
  if kind='minutes' and p ? 'meeting_members' then
   if jsonb_typeof(p->'meeting_members')<>'array' or jsonb_array_length(p->'meeting_members')=0 then raise exception 'Informe os presentes na reunião'; end if;
   if exists(select 1 from jsonb_array_elements_text(p->'meeting_members') m where not exists(select 1 from public.audit_day_attendance at where at.audit_day_id=(content->'meeting'->>'audit_day_id')::uuid and at.membership_id=m::uuid)) then raise exception 'A reunião exige participantes presentes no dia'; end if;
   content:=content||jsonb_build_object('meeting_participants',(select jsonb_agg(jsonb_build_object('membership_id',m.id,'name',up.full_name)) from public.organization_memberships m join public.user_profiles up on up.user_id=m.user_id where m.id in(select value::uuid from jsonb_array_elements_text(p->'meeting_members'))),'meeting_attendance_confirmed',true);
   delete from public.audit_document_recipients where document_id=did and document_kind='minutes';
   insert into public.audit_document_recipients select aid,did,'minutes',value::uuid from jsonb_array_elements_text(p->'meeting_members') on conflict do nothing;
  end if;
  if kind='final' and p ? 'certification' then
   if coalesce(p->'certification'->>'status','') not in ('not_applicable','pending','granted','not_granted') then raise exception 'Situação de certificação inválida'; end if;
   if p->'certification'->>'status' in ('granted','not_granted') and (nullif(trim(p->'certification'->>'source'),'') is null or nullif(p->'certification'->>'date','') is null or nullif(trim(p->'certification'->>'reference'),'') is null) then raise exception 'Informe origem, data e referência da decisão'; end if;
   content:=jsonb_set(content,'{audit,certification}',p->'certification');
  end if;
  content:=content||jsonb_build_object('additional_notes',coalesce(p->>'notes',''));
 
  execute format('update public.%I set content=$1 where id=$2',tbl) using content,did;
  return '{}';
 elsif cmd='revise' then
  if nullif(trim(p->>'reason'),'') is null then raise exception 'Justifique a retificação'; end if;
  content:=(content-'approval')||jsonb_build_object('revision_reason',p->>'reason');
  execute format('update public.%I set status=''review'',content=$1 where id=$2',tbl) using content,did;
  return '{}';
 elsif cmd='approve' then
  
  if st<>'review' then raise exception 'Documento já aprovado'; end if;
  if kind='minutes' and not coalesce((content->>'meeting_attendance_confirmed')::boolean,false) then raise exception 'Confirme os presentes na reunião antes de aprovar'; end if;
 
  execute format('select coalesce(max(version_number),0)+1 from public.%I where report_id=$1',vt) into v using did;
  content:=content||jsonb_build_object('approval',jsonb_build_object('by',(select full_name from public.user_profiles where user_id=auth.uid()),'at',clock_timestamp(),'version',v));
  execute format('insert into public.%I(report_id,version_number,content,checksum,created_by) values($1,$2,$3,$4,$5) returning id',vt) into vid using did,v,content,encode(extensions.digest(convert_to(content::text,'UTF8'),'sha256'),'hex'),auth.uid();
  execute format('update public.%I set status=''completed'',finalized_at=now(),finalized_by=$1,content=$3 where id=$2',tbl) using auth.uid(),did,content;
  if kind='daily' then
   insert into public.report_acknowledgements(report_version_id,membership_id) select vid,ap.membership_id from public.audit_participants ap join public.audit_document_recipients dr on dr.membership_id=ap.membership_id and dr.document_id=did and dr.document_kind='daily' where ap.audit_id=aid and ap.active and ap.is_signatory;
   if found then update public.daily_reports set status='pending_acknowledgements' where id=did; end if;
  elsif kind='final' then update public.audits set status='completed',certification=content->'audit'->'certification' where id=aid; end if;
  insert into public.in_app_notifications(recipient_id,event_key,event_type,entity_type,entity_id,title,message)
   select m.user_id,'audit-document:'||vid::text||':'||m.user_id,'audit_document','audit',aid,'Documento de auditoria disponível','Um documento foi aprovado. Consulte Relatórios e atas na auditoria.' from public.audit_document_recipients dr join public.organization_memberships m on m.id=dr.membership_id where dr.document_id=did and dr.document_kind=kind on conflict do nothing;
  return jsonb_build_object('version_id',vid);
 end if;
 raise exception 'Comando documental inválido';
end $function$;

CREATE OR REPLACE FUNCTION private.checklist_evidence_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.audits%rowtype; r public.requirement_assessments%rowtype;
begin
 select * into a from public.audits where id=new.audit_id for update;
 select * into r from public.requirement_assessments where id=new.assessment_id;
 if r.question_id is not null or r.extra_question_id is not null then
  if a.status<>'in_progress' or r.operational_state='completed' or exists(select 1 from public.audit_days where id=r.audit_day_id and status='completed') then raise exception 'Avaliação encerrada para anexos';end if;
  if not exists(select 1 from public.organization_memberships where id=a.leader_membership_id and user_id=new.uploaded_by and status='active') then raise exception 'Autor não é o condutor';end if;
 end if;
 update public.assessment_uploads set status='completed',updated_at=now() where operation_id=new.operation_id and assessment_id=new.assessment_id;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION private.workspace_snapshot(aid uuid, dayid uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select jsonb_build_object('audit',jsonb_build_object('id',a.id,'code',a.code,'title',a.title,'scope',a.scope,'objective',a.objective,'standards',a.standards,'purpose',a.purpose,'party',a.party,'modality',a.modality,'location',a.location,'criteria',a.criteria,'start_date',a.start_date,'end_date',a.end_date,'execution_started_at',a.execution_started_at,'execution_ended_at',a.execution_ended_at,'certification',a.certification),
 'company',(select jsonb_build_object('name',legal_name,'cnpj',cnpj,'address',address) from public.organizations where id=a.organization_id),
 'leader',(select u.full_name from public.organization_memberships m join public.user_profiles u on u.user_id=m.user_id where m.id=a.leader_membership_id),
 'generated_at',clock_timestamp(),'plan_version',a.plan_revision,
 'days',coalesce((select jsonb_agg(to_jsonb(d)||jsonb_build_object('participants',(select coalesce(jsonb_agg(jsonb_build_object('membership_id',m.id,'name',u.full_name,'role',ap.participant_type)),'[]') from public.audit_day_attendance at join public.organization_memberships m on m.id=at.membership_id join public.user_profiles u on u.user_id=m.user_id left join public.audit_participants ap on ap.membership_id=m.id and ap.audit_id=aid where at.audit_day_id=d.id)) order by d.audit_date) from public.audit_days d where d.audit_id=aid and (dayid is null or d.id=dayid)),'[]'),
 'schedule',coalesce((select jsonb_agg(to_jsonb(si)||jsonb_build_object('process',pr.name,'date',d.audit_date)) from public.schedule_items si join public.audit_days d on d.id=si.audit_day_id left join public.audit_processes pr on pr.id=si.process_id where d.audit_id=aid and (dayid is null or d.id=dayid or si.origin_day_id=dayid)),'[]'),
 'movements',coalesce((select jsonb_agg(to_jsonb(m)) from public.schedule_movements m where m.audit_id=aid and (dayid is null or m.previous_data->>'audit_day_id'=dayid::text or m.new_data->>'audit_day_id'=dayid::text)),'[]'),
 'assessments',coalesce((select jsonb_agg(to_jsonb(x)-'notes'-'last_operation') from (select distinct on(coalesce(ra.question_id,ra.extra_question_id,ra.requirement_id),ra.process_id,case when dayid is not null then ra.audit_day_id end) ra.*,(select coalesce(jsonb_agg(jsonb_build_object('id',ef.id,'filename',ef.filename,'caption',ef.caption,'order',ef.display_order,'mime_type',ef.mime_type,'author',ef.uploaded_by,'uploaded_at',ef.uploaded_at)),'[]') from public.evidence_files ef where ef.include_in_rda and (ef.assessment_id=ra.id or exists(select 1 from public.evidence_assessment_links el where el.evidence_id=ef.id and el.assessment_id=ra.id))) evidence_files,q.reference,coalesce(cq.prompt,eq.prompt,q.prompt) prompt,coalesce(cq.premise,eq.premise) premise,coalesce(cq.theme,eq.theme) theme,(select full_name from public.user_profiles where user_id=coalesce(ra.updated_by,ra.created_by)) author,(select ac.metadata->'criteria' from public.audit_checklists ac join public.checklist_sections cs on cs.revision_id=ac.revision_id where ac.audit_id=aid and cs.id=q.section_id limit 1) criteria,pr.name process from public.requirement_assessments ra join public.checklist_requirements q on q.id=ra.requirement_id left join public.checklist_questions cq on cq.id=ra.question_id left join public.audit_extra_questions eq on eq.id=ra.extra_question_id left join public.audit_processes pr on pr.id=ra.process_id where ra.audit_id=aid and ((ra.question_id is null and ra.extra_question_id is null) or ra.operational_state='completed') and (dayid is null or ra.audit_day_id=dayid) order by coalesce(ra.question_id,ra.extra_question_id,ra.requirement_id),ra.process_id,case when dayid is not null then ra.audit_day_id end,(select audit_date from public.audit_days where id=ra.audit_day_id) desc,ra.updated_at desc) x),'[]'),
 'nonconformities',coalesce((select jsonb_agg(to_jsonb(n)||jsonb_build_object('actions',(select coalesce(jsonb_agg(to_jsonb(ac)),'[]') from public.action_plans ac where ac.nonconformity_id=n.id))) from public.nonconformities n where n.audit_id=aid and (dayid is null or n.audit_day_id=dayid)),'[]'),
 'daily_reports',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'day_id',r.audit_day_id,'status',r.status,'finalized_at',r.finalized_at)) from public.daily_reports r where r.audit_id=aid),'[]'),
 'minutes',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'kind',m.kind,'status',m.status)) from public.audit_minutes m where m.audit_id=aid),'[]'),
 'plan',(select content from public.audit_plan_versions where audit_id=aid order by version_number desc limit 1),
 'original_plan',(select content from public.audit_plan_versions where audit_id=aid order by version_number limit 1),
 'pending_items',coalesce((select jsonb_agg(jsonb_build_object('reference',q.reference,'prompt',q.prompt,'process',pr.name)) from private.workspace_item_states(aid) u join public.checklist_requirements q on q.id=u.requirement_id left join public.audit_processes pr on pr.id=u.process_id where u.result='not_assessed'),'[]'),
 'opening_plan',(select pv.content from public.audit_days ad join public.audit_plan_versions pv on pv.audit_id=ad.audit_id and pv.version_number=ad.opening_plan_version where ad.id=dayid),
 'contract_version',2,'statistics',private.checklist_stats(aid),
 'findings',coalesce((select jsonb_agg(to_jsonb(f)) from public.assessment_findings f join public.requirement_assessments fa on fa.id=f.assessment_id where f.audit_id=aid and (dayid is null or fa.audit_day_id=dayid)),'[]'),
 'additional_notes','') from public.audits a where a.id=aid;
$function$;

notify pgrst,'reload schema';