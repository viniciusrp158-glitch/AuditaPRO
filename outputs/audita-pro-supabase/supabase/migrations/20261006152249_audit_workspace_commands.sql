begin;
create function private.workspace_catalog(cmd text,p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid; rid uuid; sid uuid; item jsonb; n int:=0; org uuid:=nullif(p->>'organization_id','')::uuid;
begin
 if not private.profile_admin(auth.uid()) then raise exception 'Somente Administrador pode personalizar auditorias'; end if;
 if cmd='type_save' then
  tid:=coalesce(nullif(p->>'id','')::uuid,gen_random_uuid());
  insert into public.audit_types(id,name,code,edition,description,active) values(tid,p->>'name',p->>'code',p->>'edition',p->>'description',coalesce((p->>'active')::boolean,true))
   on conflict(id) do update set name=excluded.name,code=excluded.code,edition=excluded.edition,description=excluded.description,active=excluded.active;
  return jsonb_build_object('id',tid);
 elsif cmd='template_inactivate' then
  update public.checklist_templates set status='inactive' where id=(p->>'id')::uuid; return '{}';
 elsif cmd='template_save' then
  tid:=coalesce(nullif(p->>'id','')::uuid,gen_random_uuid());
  if length(trim(coalesce(p->>'name','')))<2 then raise exception 'Informe o nome do modelo'; end if;
  if jsonb_array_length(coalesce(p->'items','[]'))=0 then raise exception 'Adicione ao menos um item'; end if;
  if exists(select 1 from public.checklist_templates where id=tid) then
   perform 1 from public.checklist_templates where id=tid for update;
   if exists(select 1 from public.checklist_revisions r join public.audit_checklists ac on ac.revision_id=r.id where r.template_id=tid) and (select organization_id from public.checklist_templates where id=tid) is distinct from org then raise exception 'Duplique o modelo para alterar sua empresa'; end if;
   update public.checklist_templates set name=p->>'name',description=p->>'description',organization_id=org,type_id=(p->>'type_id')::uuid,updated_at=now() where id=tid;
  else
   insert into public.checklist_templates(id,name,description,organization_id,type_id,created_by) values(tid,p->>'name',p->>'description',org,(p->>'type_id')::uuid,auth.uid());
  end if;
  select id into rid from public.checklist_revisions where template_id=tid and status='draft' order by revision_number desc limit 1;
  if rid is null then
   insert into public.checklist_revisions(template_id,revision_number,created_by) select tid,coalesce(max(revision_number),0)+1,auth.uid() from public.checklist_revisions where template_id=tid returning id into rid;
  else
   delete from public.checklist_requirements where section_id in(select id from public.checklist_sections where revision_id=rid);
   delete from public.checklist_sections where revision_id=rid;
  end if;
  for item in select value from jsonb_array_elements(p->'items') loop
   if nullif(trim(item->>'reference'),'') is null or nullif(trim(item->>'prompt'),'') is null then raise exception 'Número e premissa são obrigatórios'; end if;
   if exists(select 1 from public.checklist_requirements q join public.checklist_sections s on s.id=q.section_id where s.revision_id=rid and q.reference=item->>'reference') then raise exception 'Número de item duplicado'; end if;
   insert into public.checklist_sections(revision_id,title,sort_order) values(rid,coalesce(nullif(item->>'section',''),'Requisitos'),n) returning id into sid;
   insert into public.checklist_requirements(section_id,reference,prompt,guidance,sort_order) values(sid,item->>'reference',item->>'prompt',item->>'guidance',n); n:=n+1;
  end loop;
  if coalesce((p->>'publish')::boolean,false) then
   update public.checklist_revisions set status='published',published_at=now() where id=rid;
   update public.checklist_templates set status='published' where id=tid;
  end if;
  return jsonb_build_object('id',tid,'revision_id',rid);
 end if;
 raise exception 'Comando de catálogo inválido';
end $$;

create function private.workspace_context(p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
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
end $$;

create function private.workspace_detail(aid uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.audits%rowtype; full_access boolean; result jsonb;
begin
 select * into a from public.audits where id=aid;
 full_access:=private.is_audit_participant(aid) or private.workspace_conductor(aid);
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
 'nonconformities',case when full_access then coalesce((select jsonb_agg(to_jsonb(n)) from public.nonconformities n where n.audit_id=aid),'[]') else '[]'::jsonb end) into result;
 return result;
end $$;

create function private.workspace_command(cmd text,p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare aid uuid:=nullif(p->>'audit_id','')::uuid; a public.audits%rowtype; org uuid; leader uuid; rid uuid; sid uuid; dayid uuid; proc uuid; item jsonb; req text; prev jsonb; n int; result jsonb; s public.schedule_items%rowtype; d public.audit_days%rowtype; mid uuid;
begin
 if auth.uid() is null or not private.is_active_account(auth.uid()) then raise exception 'Sessão ativa necessária'; end if;
 if cmd in ('type_save','template_save','template_inactivate') then return private.workspace_catalog(cmd,p); end if;
 if cmd='context' then return private.workspace_context(p); end if;
 if cmd='template_detail' then
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
  if not private.workspace_eligible(leader) or not exists(select 1 from public.organization_memberships where id=leader and organization_id=org and (user_id=auth.uid() or private.profile_admin(auth.uid()))) then raise exception 'Responsável inelegível ou fora da empresa'; end if;
  rid:=(p->>'revision_id')::uuid;
  if not exists(select 1 from public.checklist_revisions r join public.checklist_templates t on t.id=r.template_id where r.id=rid and r.status='published' and t.status='published' and (t.organization_id is null or t.organization_id=org) and t.type_id=(p->>'type_id')::uuid) then raise exception 'Selecione modelo publicado compatível com a empresa e tipo'; end if;
  if length(trim(coalesce(p->>'title','')))<2 or nullif(trim(p->>'scope'),'') is null then raise exception 'Título e escopo obrigatórios'; end if;
  insert into public.audits(organization_id,unit_id,code,title,objective,scope,standards,leader_membership_id,created_by,workspace_version,type_id,purpose,party,modality,location,criteria)
   values(org,nullif(p->>'unit_id','')::uuid,'AUD-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)),p->>'title',p->>'objective',p->>'scope',array[(select code||coalesce(':'||nullif(edition,''),'') from public.audit_types where id=(p->>'type_id')::uuid and active)],leader,auth.uid(),1,(p->>'type_id')::uuid,coalesce(p->>'purpose','Interna'),coalesce(p->>'party','first'),coalesce(p->>'modality','presential'),p->>'location',p->>'criteria') returning id into aid;
  insert into public.audit_checklists(audit_id,revision_id,attached_by) values(aid,rid,auth.uid());
  insert into public.audit_participants(audit_id,membership_id,participant_type,added_by) values(aid,leader,'leader',auth.uid());
  return jsonb_build_object('id',aid);
 end if;
 if cmd='detail' then return private.workspace_detail(aid); end if;
 select * into a from public.audits where id=aid for update;
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
   if not exists(select 1 from public.organization_memberships m where m.id=mid and m.organization_id=a.organization_id and m.status='active' and m.competence_status in ('approved','not_required')) then raise exception 'Participante não aprovado para a empresa'; end if;
   insert into public.audit_participants(audit_id,membership_id,participant_type,is_signatory,added_by) select aid,m.id,case when m.id=a.leader_membership_id then 'leader' when ap.name='Auditor' then 'auditor' else 'client' end,coalesce((item->>'signatory')::boolean,false),auth.uid() from public.organization_memberships m join public.access_profiles ap on ap.id=m.access_profile_id where m.id=mid on conflict(audit_id,membership_id) do update set active=true,is_signatory=excluded.is_signatory;
  end loop;
  update public.audit_participants set active=false where audit_id=aid and membership_id<>a.leader_membership_id and membership_id not in(select (value->>'id')::uuid from jsonb_array_elements(p->'members'));
  update public.audits set team_reviewed=true where id=aid; return '{}';
 elsif cmd='plan_save' then
  if a.lock_version<>coalesce((p->>'lock_version')::int,-1) then raise exception 'Plano alterado em outra sessão. Recarregue antes de salvar'; end if;
  if jsonb_typeof(p->'items')<>'array' or jsonb_array_length(p->'items')>500 then raise exception 'Plano inválido ou acima de 500 atividades'; end if;
  update public.audits set plan_draft=p->'items',lock_version=lock_version+1 where id=aid; return '{}';
 elsif cmd='plan_publish' then
  if a.lock_version<>coalesce((p->>'lock_version')::int,-1) then raise exception 'Plano alterado. Recarregue'; end if;
  if not a.team_reviewed or jsonb_array_length(a.plan_draft)=0 then raise exception 'Revise a equipe e preencha o plano'; end if;
  if nullif(trim(p->>'reason'),'') is null then raise exception 'Informe motivo da publicação/revisão'; end if;
  if exists(select 1 from public.audit_checklists ac join public.checklist_sections cs on cs.revision_id=ac.revision_id join public.checklist_requirements q on q.section_id=cs.id where ac.audit_id=aid and not exists(select 1 from jsonb_array_elements(a.plan_draft) e where coalesce(e->'requirements','[]') ? q.id::text)) then raise exception 'Distribua todos os requisitos no cronograma'; end if;
  for item in select value from jsonb_array_elements(a.plan_draft) loop
   if nullif(trim(item->>'title'),'') is null or nullif(item->>'date','') is null then raise exception 'Atividade e data obrigatórias'; end if;
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
    if prev->>'status'='completed' and (prev->>'audit_day_id')::uuid<>dayid then raise exception 'Atividade concluída mantém sua data real'; end if;
   end if;
   if exists(select 1 from public.audit_days where id=dayid and status='completed') and (prev is null or (prev->>'audit_day_id')::uuid<>dayid) then raise exception 'Não adicionar trabalho a um dia encerrado'; end if;
   insert into public.schedule_items(id,audit_day_id,process_id,title,planned_start,planned_end,assignee_membership_id,category,notes)
    values(coalesce(sid,gen_random_uuid()),dayid,proc,item->>'title',nullif(item->>'start','')::timestamptz,nullif(item->>'end','')::timestamptz,a.leader_membership_id,coalesce(item->>'category','assessment'),item->>'notes')
    on conflict(id) do update set audit_day_id=excluded.audit_day_id,process_id=excluded.process_id,title=excluded.title,planned_start=excluded.planned_start,planned_end=excluded.planned_end,category=excluded.category,notes=excluded.notes,withdrawn=false returning id into sid;
   if prev is not null and prev is distinct from (select to_jsonb(si) from public.schedule_items si where id=sid) then
    insert into public.schedule_movements(audit_id,schedule_item_id,previous_data,new_data,reason,created_by) select aid,sid,prev,to_jsonb(si),p->>'reason',auth.uid() from public.schedule_items si where id=sid;
    if (prev->>'audit_day_id')::uuid<>dayid then update public.schedule_items set origin_day_id=coalesce(origin_day_id,(prev->>'audit_day_id')::uuid),move_reason=p->>'reason',moved_at=now(),moved_by=auth.uid() where id=sid; end if;
   end if;
   delete from public.schedule_requirements where schedule_item_id=sid;
   insert into public.schedule_requirements select sid,value::uuid from jsonb_array_elements_text(coalesce(item->'requirements','[]')) on conflict do nothing;
  end loop;
  -- Omission is an explicit withdrawal in this revision; retain rows and assessments.
  update public.schedule_items si set withdrawn=true from public.audit_days ad where ad.id=si.audit_day_id and ad.audit_id=aid and si.id not in (select nullif(e->>'id','')::uuid from jsonb_array_elements(a.plan_draft) e where nullif(e->>'id','') is not null) and si.created_at < now() and si.status<>'completed';
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
  if cmd='assessment_save' then
   rid:=(p->>'requirement_id')::uuid;
   if not exists(select 1 from public.schedule_requirements where schedule_item_id=s.id and requirement_id=rid) then raise exception 'Requisito fora da atividade'; end if;
   if s.status='completed' then raise exception 'Atividade concluída'; end if;
   if p->>'result'<>'not_assessed' and nullif(trim(p->>'evidence_text'),'') is null and not exists(select 1 from public.evidence_files e join public.requirement_assessments ra on ra.id=e.assessment_id where ra.audit_id=aid and ra.audit_day_id=d.id and ra.requirement_id=rid and ra.process_id is not distinct from s.process_id) then raise exception 'Informe evidência textual ou salve rascunho e anexe arquivo'; end if;
   insert into public.requirement_assessments(audit_id,audit_day_id,requirement_id,process_id,result,evidence_text,notes,nc_justification,created_by) values(aid,d.id,rid,s.process_id,p->>'result',p->>'evidence_text',p->>'notes',p->>'nc_justification',auth.uid()) on conflict(audit_id,audit_day_id,requirement_id,(coalesce(process_id,'00000000-0000-0000-0000-000000000000'::uuid))) do update set result=excluded.result,evidence_text=excluded.evidence_text,notes=excluded.notes,nc_justification=excluded.nc_justification,updated_at=now() returning id into rid;
   return jsonb_build_object('id',rid);
  elsif cmd='activity_complete' then
   if exists(select 1 from public.schedule_requirements sr where sr.schedule_item_id=s.id and not exists(select 1 from public.requirement_assessments ra where ra.audit_id=aid and ra.requirement_id=sr.requirement_id and ra.process_id is not distinct from s.process_id and ra.result<>'not_assessed')) then raise exception 'Há requisitos não avaliados'; end if;
   update public.schedule_items set status='completed',actual_start=coalesce(actual_start,now()),actual_end=now() where id=s.id;
  else update public.schedule_items set status='in_progress',actual_start=coalesce(actual_start,now()) where id=s.id; end if;
  return '{}';
 end if;
 raise exception 'Comando não reconhecido';
end $$;
create function public.audit_workspace(command text,payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$select private.workspace_command(command,payload);$$;
revoke all on function private.workspace_catalog(text,jsonb),private.workspace_context(jsonb),private.workspace_detail(uuid),private.workspace_command(text,jsonb),public.audit_workspace(text,jsonb) from public;
grant execute on function private.workspace_command(text,jsonb),public.audit_workspace(text,jsonb) to authenticated;
commit;
