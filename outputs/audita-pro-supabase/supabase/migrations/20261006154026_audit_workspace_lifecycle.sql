begin;
do $$ declare def text; begin
 def:=pg_get_functiondef('private.workspace_command(text,jsonb)'::regprocedure);
 def:=replace(def,'update public.schedule_items set status=''completed'',actual_start=coalesce(actual_start,now()),actual_end=now() where id=s.id;', 'update public.schedule_items set status=''completed'',actual_start=coalesce(actual_start,now()),actual_end=now() where id=s.id;
   if s.category in (''opening'',''closing'',''meeting'') then perform private.workspace_documents(''minutes'',jsonb_build_object(''audit_id'',aid,''schedule_id'',s.id)); end if;');
 execute def;
 def:=pg_get_functiondef('private.notification_is_pending(public.in_app_notifications)'::regprocedure);
 def:=replace(def,'private.notification_is_pending(','private.notification_profile_pending(');
 execute def;
end $$;
create or replace function private.notification_is_pending(n public.in_app_notifications) returns boolean language sql stable security definer set search_path='' as $$
 select case when n.entity_type='audit' then
  exists(select 1 from public.audits a join public.organization_memberships m on m.id=a.leader_membership_id where a.id=n.entity_id and m.user_id=n.recipient_id and private.workspace_eligible(m.id) and
   ((n.event_type='audit_assigned' and (not a.team_reviewed or a.plan_revision=0)) or
    (n.event_type='audit_review' and (exists(select 1 from public.daily_reports r where r.audit_id=a.id and r.status='review') or exists(select 1 from public.audit_minutes r where r.audit_id=a.id and r.status='review') or exists(select 1 from public.audit_final_reports r where r.audit_id=a.id and r.status='review')))))
 else private.notification_profile_pending(n) end;
$$;
create function private.workspace_review_notice() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status='review' then
  insert into public.in_app_notifications(recipient_id,event_key,event_type,entity_type,entity_id,title,message)
   select m.user_id,'review:'||tg_table_name||':'||new.id||':'||new.generated_at,'audit_review','audit',a.id,'Documento aguardando validação','Confira o documento gerado em Relatórios e atas.' from public.audits a join public.organization_memberships m on m.id=a.leader_membership_id where a.id=new.audit_id and a.workspace_version>0 on conflict do nothing;
 end if;return new;
end $$;
create trigger workspace_daily_review after insert on public.daily_reports for each row execute function private.workspace_review_notice();
create trigger workspace_final_review after insert on public.audit_final_reports for each row execute function private.workspace_review_notice();
create trigger workspace_minutes_review after insert on public.audit_minutes for each row execute function private.workspace_review_notice();
revoke all on function private.workspace_review_notice(),private.notification_profile_pending(public.in_app_notifications) from public;

-- Capture unevaluated units and opening baseline, in addition to recorded results.
do $$ declare def text; begin
 def:=pg_get_functiondef('private.workspace_snapshot(uuid,uuid)'::regprocedure);
 def:=replace(def,'''additional_notes'',''''' ,'''pending_items'',coalesce((select jsonb_agg(jsonb_build_object(''reference'',q.reference,''prompt'',q.prompt,''process'',pr.name)) from private.workspace_item_states(aid) u join public.checklist_requirements q on q.id=u.requirement_id left join public.audit_processes pr on pr.id=u.process_id where u.result=''not_assessed''),''[]''),
 ''opening_plan'',(select pv.content from public.audit_days ad join public.audit_plan_versions pv on pv.audit_id=ad.audit_id and pv.version_number=ad.opening_plan_version where ad.id=dayid),
 ''additional_notes'',''''');
 execute def;
end $$;
commit;
