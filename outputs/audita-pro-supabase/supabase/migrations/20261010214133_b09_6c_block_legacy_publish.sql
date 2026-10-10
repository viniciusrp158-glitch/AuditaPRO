-- B09 Parte 6c: plan_publish legado (sem validação nem PDF) deixa de ser aceito.
create or replace function public.audit_workspace(command text, payload jsonb default '{}'::jsonb) returns jsonb
 language plpgsql set search_path = '' as $$
begin
 if command = 'plan_publish' then
  raise exception 'A publicação do plano agora passa pela validação com PDF (Plano de Auditoria → Validação e publicação)'; end if;
 return private.workspace_command(command, payload);
end;$$;
