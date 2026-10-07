begin;
create function private.checklist_catalog_read(tid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.profile_admin(auth.uid()) or exists(select 1 from public.checklist_revisions r join public.audit_checklists ac on ac.revision_id=r.id where r.template_id=tid and private.checklist_internal(ac.audit_id));
$$;
revoke all on function private.checklist_catalog_read(uuid) from public,anon;
grant execute on function private.checklist_catalog_read(uuid) to authenticated;
create policy checklist_master_templates on public.checklist_templates as restrictive for select to authenticated using(private.checklist_catalog_read(id));
create policy checklist_master_revisions on public.checklist_revisions as restrictive for select to authenticated using(private.checklist_catalog_read(template_id));
create policy checklist_master_sections on public.checklist_sections as restrictive for select to authenticated using(exists(select 1 from public.checklist_revisions r where r.id=revision_id and private.checklist_catalog_read(r.template_id)));
-- Guard legacy template-detail RPC as well as raw table access.
do $$declare f text;begin
 f:=pg_get_functiondef('private.workspace_command(text,jsonb)'::regprocedure);
 if strpos(f,'if cmd=''template_detail'' then')=0 then raise exception 'Revisar integração template_detail';end if;
 f:=replace(f,'if cmd=''template_detail'' then','if cmd=''template_detail'' then if not private.profile_admin(auth.uid()) then raise exception ''Biblioteca restrita à Administração''; end if;');execute f;
end $$;
-- Serializes file registration with day closure, including service-role Edge writes.
create function private.checklist_evidence_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare a public.audits%rowtype; r public.requirement_assessments%rowtype;
begin
 select * into a from public.audits where id=new.audit_id for update;
 select * into r from public.requirement_assessments where id=new.assessment_id;
 if r.question_id is not null then
  if a.status<>'in_progress' or r.operational_state='completed' or exists(select 1 from public.audit_days where id=r.audit_day_id and status='completed') then raise exception 'Avaliação encerrada para anexos';end if;
  if not exists(select 1 from public.organization_memberships where id=a.leader_membership_id and user_id=new.uploaded_by and status='active') then raise exception 'Autor não é o condutor';end if;
 end if;
 return new;
end $$;
create trigger checklist_evidence_guard before insert on public.evidence_files for each row execute function private.checklist_evidence_guard();
revoke all on function private.checklist_evidence_guard() from public,anon,authenticated;
commit;
