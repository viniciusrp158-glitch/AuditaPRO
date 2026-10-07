begin;
do $$ declare def text; begin
 def:=pg_get_functiondef('private.workspace_command(text,jsonb)'::regprocedure);
 def:=replace(def,'m.competence_status in (''approved'',''not_required'')) then raise exception ''Participante','(m.competence_status in (''approved'',''not_required'') or (m.id=a.leader_membership_id and private.workspace_eligible(m.id)))) then raise exception ''Participante');
 def:=replace(def,'select * into a from public.audits where id=aid for update;', 'select * into a from public.audits where id=aid for update; if a.status=''awaiting_signoff'' then raise exception ''Execução encerrada; conclua a validação documental''; end if;');
 execute def;
 def:=pg_get_functiondef('private.notification_command(text,jsonb)'::regprocedure);
 def:=replace(def,'if command=''open'' then', 'if command=''open'' then
    if n.entity_type=''audit'' then
     if not exists(select 1 from public.audits a where a.id=n.entity_id and (private.is_audit_participant(a.id) or (a.plan_revision>0 and private.workspace_member(a.organization_id)))) then return jsonb_build_object(''action'',null,''message'',''Acesso à auditoria indisponível.''); end if;
     return jsonb_build_object(''action'',''view_audit'',''audit_id'',n.entity_id);
    end if;');
 execute def;
 -- Legacy finalizer cannot circumvent the new document workflow.
 def:=pg_get_functiondef('public.finalize_daily_report(uuid)'::regprocedure);
 def:=replace(def,'begin', 'begin
  if exists(select 1 from public.daily_reports r join public.audits a on a.id=r.audit_id where r.id=target_report and a.workspace_version>0) then raise exception ''Valide o documento na aba Auditorias''; end if;');
 execute def;
end $$;
create function private.workspace_notices() returns trigger language plpgsql security definer set search_path='' as $$
declare leader uuid; kind text; msg text; seq text;
begin
 if new.workspace_version=0 then return new; end if;
 select user_id into leader from public.organization_memberships where id=new.leader_membership_id;
 if tg_op='INSERT' or new.leader_membership_id is distinct from old.leader_membership_id then
  insert into public.in_app_notifications(recipient_id,event_key,event_type,entity_type,entity_id,title,message)
  values(leader,'audit-assigned:'||new.id||':'||new.lock_version,'audit_assigned','audit',new.id,'Auditoria atribuída a você','Revise a equipe e o plano de auditoria. A preparação está pendente.') on conflict do nothing;
 elsif new.plan_revision>old.plan_revision then
  insert into public.in_app_notifications(recipient_id,event_key,event_type,entity_type,entity_id,title,message)
   select m.user_id,'audit-plan:'||new.id||':'||new.plan_revision||':'||m.user_id,'audit_plan','audit',new.id,'Plano de auditoria publicado','Uma nova versão do plano está disponível para consulta.' from public.organization_memberships m where m.organization_id=new.organization_id and m.status='active' and m.competence_status in ('approved','not_required') on conflict do nothing;
 end if;
 return new;
end $$;
create trigger workspace_notices after insert or update on public.audits for each row execute function private.workspace_notices();
revoke all on function private.workspace_notices() from public;
commit;
