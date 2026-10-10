-- Recuperada de supabase_migrations.schema_migrations em 2026-10-10 (B00, Claude).
-- JA APLICADA no projeto zlckcpeqcxmtrgbdquee. NAO reaplicar. md5(statements)=e5d2f792667272ce7e58901f7df0d6d6

begin;

-- Transfer is governed by CMD-1 through public.audit_access. Keep the legacy
-- audit_workspace signature for every other command, but fail closed if an old
-- client still tries to mutate responsibility through `reassign`.
do $patch$
declare
  definition text;
  anchor constant text :=
    'if auth.uid() is null or not private.is_active_account(auth.uid()) then raise exception ''Sessão ativa necessária''; end if;';
  replacement constant text := anchor || E'\n if cmd=''reassign'' then\n  raise exception ''Transferência exige CMD-1; use audit_access(''''transfer'''', envelope) com operation_id e expected_lock_version'' using errcode=''42501'';\n end if;';
  occurrences integer;
begin
  definition := pg_get_functiondef('private.workspace_command(text,jsonb)'::regprocedure);
  occurrences := (length(definition) - length(replace(definition, anchor, ''))) / length(anchor);

  if occurrences <> 1 then
    raise exception 'B02 reassign guard: workspace_command anchor mismatch (found %)', occurrences;
  end if;

  definition := replace(definition, anchor, replacement);
  execute definition;

  definition := pg_get_functiondef('private.workspace_command(text,jsonb)'::regprocedure);
  if position('Transferência exige CMD-1;' in definition) = 0 then
    raise exception 'B02 reassign guard: patched definition was not installed';
  end if;
end;
$patch$;

commit;
