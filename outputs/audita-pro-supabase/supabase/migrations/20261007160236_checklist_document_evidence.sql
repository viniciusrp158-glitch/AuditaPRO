CREATE OR REPLACE FUNCTION private.workspace_evidence(cmd text, p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.requirement_assessments%rowtype; e public.evidence_files%rowtype; doc jsonb;
begin
 if auth.uid() is null or not private.is_active_account(auth.uid()) then raise exception 'Sessão necessária'; end if;
 if cmd='authorize' then
  select * into r from public.requirement_assessments where id=(p->>'assessment_id')::uuid;
  if r.operational_state='completed' then raise exception 'Reabra a avaliação antes de anexar';end if; if r.id is null or not private.workspace_conductor(r.audit_id) or not exists(select 1 from public.audits where id=r.audit_id and status='in_progress') or exists(select 1 from public.audit_days where id=r.audit_day_id and status='completed') then raise exception 'Avaliação indisponível para anexos'; end if;
  return jsonb_build_object('audit_id',r.audit_id,'assessment_id',r.id,'user_id',auth.uid());
 elsif cmd='view' then
  select * into e from public.evidence_files where id=(p->>'id')::uuid;
  if e.id is null then raise exception 'Evidência indisponível'; end if;
  if not private.checklist_internal(e.audit_id) then
   if nullif(p->>'document_id','') is null then raise exception 'Evidência restrita'; end if;
   doc:=private.workspace_documents('get',jsonb_build_object('audit_id',e.audit_id,'document_id',p->>'document_id','kind',p->>'kind'));
   if coalesce(doc->>'status','') not in ('completed','pending_acknowledgements') or not exists(select 1 from jsonb_array_elements(doc->'content'->'assessments') ar cross join lateral jsonb_array_elements(ar->'evidence_files') ef where ef->>'id'=e.id::text) then raise exception 'Arquivo não publicado neste documento'; end if;
  end if;
  return jsonb_build_object('path',e.storage_path);
 end if;
 raise exception 'Ação inválida';
end $function$
;
notify pgrst,'reload schema';
