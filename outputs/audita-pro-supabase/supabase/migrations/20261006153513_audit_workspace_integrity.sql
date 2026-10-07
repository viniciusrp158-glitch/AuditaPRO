begin;
revoke insert,update,delete on public.checklist_templates,public.checklist_revisions,public.checklist_sections,public.checklist_requirements from authenticated;
-- Documents in revision remain accessible through their frozen versions only.
drop policy workspace_daily_read on public.daily_reports;
create policy workspace_daily_read on public.daily_reports as restrictive for select to authenticated using(not exists(select 1 from public.audits a where a.id=audit_id and a.workspace_version>0) or private.workspace_document_access(id,'daily',audit_id,status in ('completed','pending_acknowledgements')));
drop policy workspace_final_read on public.audit_final_reports;
create policy workspace_final_read on public.audit_final_reports as restrictive for select to authenticated using(not exists(select 1 from public.audits a where a.id=audit_id and a.workspace_version>0) or private.workspace_document_access(id,'final',audit_id,status in ('completed','pending_acknowledgements')));
do $$ declare def text; begin
 def:=pg_get_functiondef('private.workspace_command(text,jsonb)'::regprocedure);
 def:=replace(def,'if coalesce(item->>''category'',''assessment'')=''assessment''', 'if nullif(item->>''start'','''') is not null and ((item->>''start'')::timestamptz at time zone a.timezone)::date<>(item->>''date'')::date then raise exception ''Horário fora da data da atividade''; end if;
   if coalesce(item->>''category'',''assessment'')=''assessment''');
 def:=replace(def,'if prev->>''status''=''completed'' and', 'if prev->>''status''=''completed'' and (prev->>''title'' is distinct from item->>''title'' or (prev->>''process_id'')::uuid is distinct from proc or (select coalesce(jsonb_agg(requirement_id::text order by requirement_id::text),''[]'') from public.schedule_requirements where schedule_item_id=sid) is distinct from (select coalesce(jsonb_agg(value order by value),''[]'') from jsonb_array_elements_text(coalesce(item->''requirements'',''[]'')))) then raise exception ''Atividade concluída preserva seu escopo''; end if;
    if prev->>''status''=''completed'' and');
 def:=replace(def,'if p->>''result''<>''not_assessed''', 'if p->>''result''=''not_applicable'' and nullif(trim(p->>''evidence_text''),'''') is null then raise exception ''Justifique a não aplicabilidade em texto''; end if;
   if p->>''result''<>''not_assessed''');
 execute def;
 def:=pg_get_functiondef('private.workspace_detail(uuid)'::regprocedure);
 def:=replace(def,'return result;', 'if not full_access then
   result:=result||jsonb_build_object(''plan'',(select coalesce(jsonb_agg(v-''notes''),''[]'') from jsonb_array_elements(result->''plan'') v),''schedule'',(select coalesce(jsonb_agg(v-''notes''),''[]'') from jsonb_array_elements(result->''schedule'') v),''versions'',(select coalesce(jsonb_agg(v-''content''),''[]'') from jsonb_array_elements(result->''versions'') v),''movements'',(select coalesce(jsonb_agg(v||jsonb_build_object(''previous_data'',v->''previous_data''-''notes'',''new_data'',v->''new_data''-''notes'')),''[]'') from jsonb_array_elements(result->''movements'') v));
  end if;
  return result;');
 execute def;
 def:=pg_get_functiondef('private.workspace_documents(text,jsonb)'::regprocedure);
 def:=replace(def,'if content is null or not private.workspace_document_access', 'if cmd=''get'' and st=''review'' and not private.workspace_conductor(aid) and not private.profile_admin(auth.uid()) then
   execute format(''select content from public.%I where report_id=$1 order by version_number desc limit 1'',vt) into content using did;
   if content is not null then st:=''completed''; end if;
  end if;
  if content is null or not private.workspace_document_access');
 def:=replace(def,'update public.audits set status=''awaiting_signoff''', 'if coalesce(p->''certification''->>''status'',''not_applicable'') not in (''not_applicable'',''pending'',''granted'',''not_granted'') then raise exception ''Situação de certificação inválida''; end if;
  if p->''certification''->>''status'' in (''granted'',''not_granted'') and (nullif(trim(p->''certification''->>''source''),'''') is null or nullif(p->''certification''->>''date'','''') is null or nullif(trim(p->''certification''->>''reference''),'''') is null) then raise exception ''Informe origem, data e referência da decisão de certificação''; end if;
  update public.audits set status=''awaiting_signoff''');
 execute def;
end $$;

-- Supplemental mutations are isolated from planning commands.
create function private.workspace_findings(cmd text,p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.audits%rowtype; r public.requirement_assessments%rowtype; nid uuid; n public.nonconformities%rowtype;
begin
 select * into a from public.audits where id=(p->>'audit_id')::uuid for update;
 if auth.uid() is null or not private.workspace_conductor(a.id) or a.status<>'in_progress' then raise exception 'Somente o condutor de auditoria em andamento'; end if;
 if cmd='create_nc' then
  select * into r from public.requirement_assessments where id=(p->>'assessment_id')::uuid and audit_id=a.id;
  if r.id is null or r.result not in ('nonconforming','partially_conforming') then raise exception 'Selecione uma avaliação não conforme ou parcial'; end if;
  if nullif(trim(p->>'description'),'') is null or nullif(trim(p->>'responsible'),'') is null or nullif(p->>'due_date','') is null then raise exception 'Descrição, responsável e prazo obrigatórios'; end if;
  select id into nid from public.nonconformities where audit_id=a.id and audit_day_id=r.audit_day_id and requirement_id=r.requirement_id and process_id is not distinct from r.process_id limit 1;
  if nid is not null then return jsonb_build_object('id',nid); end if;
  insert into public.nonconformities(audit_id,audit_day_id,requirement_id,process_id,code,description,classification,created_by) values(a.id,r.audit_day_id,r.requirement_id,r.process_id,'NC-'||upper(substr(gen_random_uuid()::text,1,8)),p->>'description',p->>'classification',auth.uid()) returning id into nid;
  insert into public.action_plans(nonconformity_id,action_text,responsible_name,due_date,created_by) values(nid,coalesce(nullif(p->>'action_text',''),'Definir e executar o tratamento da não conformidade'),p->>'responsible',(p->>'due_date')::date,auth.uid());
  return jsonb_build_object('id',nid);
 end if;
 raise exception 'Comando de achado inválido';
end $$;
create function public.audit_findings(command text,payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$select private.workspace_findings(command,payload);$$;
revoke all on function private.workspace_findings(text,jsonb),public.audit_findings(text,jsonb) from public;
grant execute on function private.workspace_findings(text,jsonb),public.audit_findings(text,jsonb) to authenticated;
commit;
