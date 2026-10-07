begin;
create or replace function private.checklist_execution(cmd text,p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare aid uuid:=nullif(p->>'audit_id','')::uuid;a public.audits%rowtype;s public.schedule_items%rowtype;d public.audit_days%rowtype;r public.requirement_assessments%rowtype;x public.checklist_questions%rowtype;
 rid uuid;tid uuid;source uuid;fid uuid;nid uuid;op uuid;patch jsonb;out jsonb;rev public.checklist_revisions%rowtype;hdr jsonb;ids uuid[];lastid uuid;sections jsonb;off int:=greatest(0,coalesce((p->>'page')::int,0))*30;
begin
 if auth.uid() is null or not private.is_active_account(auth.uid()) then raise exception 'Sessão ativa necessária';end if;
 select * into a from public.audits where id=aid;
 if a.id is null or not(private.is_audit_participant(aid) or private.workspace_member(a.organization_id) or private.workspace_conductor(aid)) then raise exception 'Auditoria indisponível';end if;
 if cmd='suggest' then
  if not(private.workspace_conductor(aid) or private.profile_admin(auth.uid())) then raise exception 'Sem permissão';end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id',cr.id,'template_id',t.id,'number',cr.revision_number,'header',cr.header-'internal_notes','components',(select coalesce(jsonb_agg(source_revision_id),'[]') from public.checklist_components where revision_id=cr.id))) from public.checklist_revisions cr join public.checklist_templates t on t.id=cr.template_id where cr.status='published' and t.status='published' and (t.organization_id is null or t.organization_id=a.organization_id)),'[]');
 elsif cmd='context' then
  if not private.checklist_internal(aid) then raise exception 'Execução restrita à equipe interna';end if;
  return jsonb_build_object('audit',to_jsonb(a),'company',(select legal_name from public.organizations where id=a.organization_id),'can_edit',private.workspace_conductor(aid),'days',coalesce((select jsonb_agg(to_jsonb(d) order by audit_date) from public.audit_days d where audit_id=aid),'[]'),'activities',coalesce((select jsonb_agg(to_jsonb(si)||jsonb_build_object('process',(select name from public.audit_processes where id=si.process_id))) from public.schedule_items si join public.audit_days ad on ad.id=si.audit_day_id where ad.audit_id=aid and not si.withdrawn and si.category='assessment'),'[]'),'models',coalesce((select jsonb_agg(metadata) from public.audit_checklists where audit_id=aid),'[]'),'stats',private.checklist_stats(aid));
 elsif cmd='questions' then
  if not private.checklist_internal(aid) then raise exception 'Execução restrita à equipe interna';end if;
  select si.* into s from public.schedule_items si join public.audit_days ad on ad.id=si.audit_day_id where si.id=(p->>'schedule_id')::uuid and ad.audit_id=aid and not si.withdrawn;
  if s.id is null then raise exception 'Atividade indisponível';end if;
  return (with filtered as(select cq.*,q.reference,q.prompt requirement_title,cs.title section,cr.header->'criteria' criteria,
   (select to_jsonb(ar) from public.requirement_assessments ar where ar.question_id=cq.id and ar.audit_id=aid and ar.audit_day_id=s.audit_day_id and ar.process_id is not distinct from s.process_id) assessment
   from public.schedule_requirements sr join public.checklist_requirements q on q.id=sr.requirement_id join public.checklist_sections cs on cs.id=q.section_id join public.checklist_revisions cr on cr.id=cs.revision_id join public.checklist_questions cq on cq.requirement_id=q.id
   where sr.schedule_item_id=s.id and cq.active and (coalesce(p->>'search','')='' or concat(q.reference,' ',cq.prompt,' ',cq.theme) ilike '%'||(p->>'search')||'%'))
   select jsonb_build_object('total',(select count(*) from filtered),'items',coalesce((select jsonb_agg(to_jsonb(z)) from(select * from filtered where (coalesce(p->>'result','')='' or assessment->>'result'=p->>'result') and (coalesce(p->>'state','')='' or coalesce(assessment->>'operational_state','not_started')=p->>'state') order by section,reference,sort_order,id limit 30 offset off)z),'[]')));
 elsif cmd='assessment' then
  select * into r from public.requirement_assessments where id=(p->>'assessment_id')::uuid and audit_id=aid;
  if r.id is null or not private.checklist_internal(aid) then raise exception 'Avaliação indisponível';end if;
  return jsonb_build_object('record',to_jsonb(r),'findings',coalesce((select jsonb_agg(to_jsonb(f)) from public.assessment_findings f where f.assessment_id=r.id or exists(select 1 from public.assessment_finding_links l where l.finding_id=f.id and l.assessment_id=r.id)),'[]'),'complements',coalesce((select jsonb_agg(to_jsonb(c)) from public.assessment_complements c where c.assessment_id=r.id),'[]'),'evidence',coalesce((select jsonb_agg(to_jsonb(e)-'storage_path') from public.evidence_files e where e.assessment_id=r.id or exists(select 1 from public.evidence_assessment_links l where l.evidence_id=e.id and l.assessment_id=r.id)),'[]'),'history',coalesce((select jsonb_agg(to_jsonb(h) order by revision desc) from (select * from public.assessment_history where assessment_id=r.id order by revision desc limit 20)h),'[]'));
 end if;
 perform 1 from public.audits where id=aid for update;
 select * into a from public.audits where id=aid;
 if not private.workspace_conductor(aid) then raise exception 'Somente o condutor designado pode gravar';end if;
 if a.status in ('completed','cancelled','awaiting_signoff') then raise exception 'Auditoria encerrada';end if;
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
  update public.audits set checklist_confirmed_at=now(),checklist_confirmed_by=auth.uid(),checklist_contract=2,lock_version=lock_version+1 where id=aid;
  return '{}';
 end if;
 if a.status<>'in_progress' then raise exception 'Inicie a auditoria antes de registrar a execução';end if;
 if cmd in ('save','complete') then
  select si.* into s from public.schedule_items si join public.audit_days ad on ad.id=si.audit_day_id where si.id=(p->>'schedule_id')::uuid and ad.audit_id=aid and not si.withdrawn;
  select * into d from public.audit_days where id=s.audit_day_id;
  select q.* into x from public.checklist_questions q join public.schedule_requirements sr on sr.requirement_id=q.requirement_id where q.id=(p->>'question_id')::uuid and sr.schedule_item_id=s.id and q.active;
  if s.id is null or x.id is null or d.status='completed' or s.status='completed' then raise exception 'Pergunta ou dia indisponível';end if;
  select * into r from public.requirement_assessments where audit_id=aid and audit_day_id=d.id and question_id=x.id and process_id is not distinct from s.process_id for update;
  op:=(p->>'operation_id')::uuid;
  if op is null then raise exception 'Identificador da operação obrigatório';end if;
  if r.last_operation=op then return to_jsonb(r);end if;
  if coalesce(r.lock_version,0)<>coalesce((p->>'lock_version')::int,-1) then raise exception using errcode='40001',message='Conflito: outra sessão salvou esta pergunta. Revise antes de reenviar';end if;
  patch:=coalesce(p->'patch','{}');
  if r.id is null then
   insert into public.requirement_assessments(audit_id,audit_day_id,requirement_id,question_id,process_id,created_by,updated_by) values(aid,d.id,x.requirement_id,x.id,s.process_id,auth.uid(),auth.uid()) returning * into r;
  end if;
  update public.requirement_assessments set result=case when patch?'result' then patch->>'result' else result end,
   evidence_text=case when patch?'evidence_text' then patch->>'evidence_text' else evidence_text end,
   notes=case when patch?'notes' then patch->>'notes' else notes end,
   sampling=case when patch?'sampling' then nullif(patch->>'sampling','') else sampling end,
   sample_description=case when patch?'sample_description' then patch->>'sample_description' else sample_description end,
   nc_justification=case when patch?'nc_justification' then patch->>'nc_justification' else nc_justification end,
   operational_state='in_progress',lock_version=lock_version+1,last_operation=op,updated_at=clock_timestamp(),updated_by=auth.uid() where id=r.id returning * into r;
  if cmd='complete' then
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
  update public.assessment_complements set response=p->>'response' where id=(p->>'id')::uuid and assessment_id=r.id;return '{}';
 elsif cmd='evidence_metadata' then
  update public.evidence_files set caption=p->>'caption',include_in_rda=coalesce((p->>'include_in_rda')::boolean,false),display_order=coalesce((p->>'display_order')::int,0) where id=(p->>'id')::uuid and assessment_id=r.id;return '{}';
 elsif cmd='link_evidence' then
  if not exists(select 1 from public.evidence_files where id=(p->>'id')::uuid and audit_id=aid) then raise exception 'Evidência fora da auditoria';end if;
  insert into public.evidence_assessment_links values((p->>'id')::uuid,r.id) on conflict do nothing;return '{}';
 end if;
 raise exception 'Comando de execução inválido';
end $$;

commit;
