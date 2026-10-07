begin;
do $$ declare def text; begin
 def:=pg_get_functiondef('private.workspace_command(text,jsonb)'::regprocedure);
 def:=replace(def,'mid uuid;', 'mid uuid; keep_ids uuid[]:=array[]::uuid[];');
 def:=replace(def,'if prev is not null and prev is distinct', 'keep_ids:=array_append(keep_ids,sid); if prev is not null and prev is distinct');
 def:=replace(def,'si.id not in (select nullif(e->>''id'','''')::uuid from jsonb_array_elements(a.plan_draft) e where nullif(e->>''id'','''') is not null) and si.created_at < now()', 'not(si.id=any(keep_ids))');
 execute def;
end $$;
commit;
