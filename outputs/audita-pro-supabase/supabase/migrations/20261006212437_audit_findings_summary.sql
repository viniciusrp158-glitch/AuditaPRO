begin;
do $$ declare def text; begin
 def:=pg_get_functiondef('private.workspace_detail(uuid)'::regprocedure);
 def:=replace(def,'jsonb_agg(to_jsonb(n)) from public.nonconformities n', 'jsonb_agg(to_jsonb(n)||jsonb_build_object(''actions'',(select coalesce(jsonb_agg(to_jsonb(ac) order by ac.due_date),''[]'') from public.action_plans ac where ac.nonconformity_id=n.id))) from public.nonconformities n');
 execute def;
end $$;
commit;
