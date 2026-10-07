begin;
-- Old notices must not become pending again if a task returns to a former reviewer.
do $$ declare definition text; begin
 definition:=pg_get_functiondef('private.notification_is_pending(public.in_app_notifications)'::regprocedure);
 definition:=replace(definition,'s.state=''submitted'' and','s.state=''submitted'' and split_part(n.event_key,'':'',2)::bigint=s.notification_revision and');
 execute definition;
 definition:=pg_get_functiondef('private.notification_command(text,jsonb)'::regprocedure);
 definition:=replace(definition,'if s.state=''submitted'' and private.profile_admin(actor)', 'if s.state=''submitted'' and split_part(n.event_key,'':'',2)::bigint=s.notification_revision and private.profile_admin(actor)');
 execute definition;
end $$;
commit;
