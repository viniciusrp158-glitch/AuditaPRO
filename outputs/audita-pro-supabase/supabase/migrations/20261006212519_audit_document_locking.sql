begin;
do $$ declare def text; begin
 def:=pg_get_functiondef('private.workspace_documents(text,jsonb)'::regprocedure);
 def:=replace(def,'select * into a from public.audits where id=aid;', 'if cmd not in (''list'',''get'') then perform 1 from public.audits where id=aid for update; end if;
 select * into a from public.audits where id=aid;');
 execute def;
end $$;
commit;
