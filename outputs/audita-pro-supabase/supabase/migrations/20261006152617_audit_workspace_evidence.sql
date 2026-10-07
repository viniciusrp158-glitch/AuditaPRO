begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('audit-evidence-workspace','audit-evidence-workspace',false,10485760,array['application/pdf','image/jpeg','image/png']) on conflict(id) do nothing;
create function private.workspace_evidence(cmd text,p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.requirement_assessments%rowtype; e public.evidence_files%rowtype;
begin
 if auth.uid() is null or not private.is_active_account(auth.uid()) then raise exception 'Sessão necessária'; end if;
 if cmd='authorize' then
  select * into r from public.requirement_assessments where id=(p->>'assessment_id')::uuid;
  if r.id is null or not private.workspace_conductor(r.audit_id) or not exists(select 1 from public.audits where id=r.audit_id and status='in_progress') or exists(select 1 from public.audit_days where id=r.audit_day_id and status='completed') then raise exception 'Avaliação indisponível para anexos'; end if;
  return jsonb_build_object('audit_id',r.audit_id,'assessment_id',r.id,'user_id',auth.uid());
 elsif cmd='view' then
  select * into e from public.evidence_files where id=(p->>'id')::uuid;
  if e.id is null or not private.is_audit_participant(e.audit_id) then raise exception 'Evidência indisponível'; end if;
  return jsonb_build_object('path',e.storage_path);
 end if;
 raise exception 'Ação inválida';
end $$;
create function public.audit_evidence(command text,payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$ select private.workspace_evidence(command,payload); $$;
revoke all on function private.workspace_evidence(text,jsonb),public.audit_evidence(text,jsonb) from public;
grant execute on function private.workspace_evidence(text,jsonb),public.audit_evidence(text,jsonb) to authenticated;
commit;
