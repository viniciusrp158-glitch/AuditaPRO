-- Audita PRO — enforce audit assignment and report.view for report artifacts.
begin;

create or replace function private.is_audit_participant(target_audit uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_platform_admin() or exists (
    select 1
    from public.audits a
    join public.organization_memberships m
      on m.organization_id = a.organization_id
     and m.user_id = auth.uid()
     and m.status = 'active'
     and m.competence_status in ('approved','not_required')
    where a.id = target_audit
      and (
        a.leader_membership_id = m.id
        or exists (
          select 1 from public.audit_participants ap
          where ap.audit_id = a.id and ap.membership_id = m.id and ap.active
        )
      )
  );
$$;

create or replace function private.has_audit_permission(target_audit uuid, required_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_platform_admin() or exists (
    select 1
    from public.audits a
    join public.organization_memberships m
      on m.organization_id = a.organization_id
     and m.user_id = auth.uid()
     and m.status = 'active'
     and m.competence_status in ('approved','not_required')
    join public.access_permissions p on p.permission_key = required_permission
    left join public.access_profile_permissions pp
      on pp.profile_id = m.access_profile_id and pp.permission_id = p.id
    left join public.membership_permissions mp
      on mp.membership_id = m.id and mp.permission_id = p.id
    where a.id = target_audit
      and coalesce(mp.allowed,pp.allowed,false)
      and (
        a.leader_membership_id = m.id
        or exists (
          select 1 from public.audit_participants ap
          where ap.audit_id = a.id and ap.membership_id = m.id and ap.active
        )
      )
  );
$$;

create or replace function private.is_audit_leader(target_audit uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_platform_admin() or exists (
    select 1
    from public.audits a
    join public.organization_memberships m
      on m.id = a.leader_membership_id
     and m.user_id = auth.uid()
     and m.status = 'active'
     and m.competence_status in ('approved','not_required')
    where a.id = target_audit
  ) or exists (
    select 1
    from public.audit_participants ap
    join public.organization_memberships m on m.id = ap.membership_id
    where ap.audit_id = target_audit and ap.participant_type = 'leader' and ap.active
      and m.user_id = auth.uid() and m.status = 'active'
      and m.competence_status in ('approved','not_required')
  );
$$;

-- User contact data remains hidden from other company users; only the platform
-- administrator and active members of the owning organization may read it.
alter table public.organization_contacts enable row level security;
drop policy if exists organization_contacts_read on public.organization_contacts;
create policy organization_contacts_read on public.organization_contacts
  for select to authenticated
  using (public.is_platform_admin() or private.is_active_org_member(organization_id));
drop policy if exists organization_contacts_admin_write on public.organization_contacts;
create policy organization_contacts_admin_write on public.organization_contacts
  for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());
grant select,insert,update,delete on public.organization_contacts to authenticated;

-- Final report access is both audit-scoped and permission-scoped.
alter table public.audit_final_reports enable row level security;
alter table public.audit_final_report_versions enable row level security;
alter table public.audit_final_report_files enable row level security;

drop policy if exists audit_final_reports_read on public.audit_final_reports;
create policy audit_final_reports_read on public.audit_final_reports
  for select to authenticated
  using (private.is_audit_participant(audit_id)
     and private.has_audit_permission(audit_id,'report.view'));
drop policy if exists audit_final_reports_create on public.audit_final_reports;
create policy audit_final_reports_create on public.audit_final_reports
  for insert to authenticated
  with check (private.is_audit_leader(audit_id));
drop policy if exists audit_final_reports_edit on public.audit_final_reports;
create policy audit_final_reports_edit on public.audit_final_reports
  for update to authenticated
  using (status in ('draft','review') and private.has_audit_permission(audit_id,'report.edit'))
  with check (status in ('draft','review') and private.has_audit_permission(audit_id,'report.edit'));

drop policy if exists audit_final_versions_read on public.audit_final_report_versions;
create policy audit_final_versions_read on public.audit_final_report_versions
  for select to authenticated
  using (exists (
    select 1 from public.audit_final_reports r
    where r.id = report_id and private.is_audit_participant(r.audit_id)
      and private.has_audit_permission(r.audit_id,'report.view')
  ));
drop policy if exists audit_final_files_read on public.audit_final_report_files;
create policy audit_final_files_read on public.audit_final_report_files
  for select to authenticated
  using (exists (
    select 1 from public.audit_final_reports r
    where r.id = report_id and private.is_audit_participant(r.audit_id)
      and private.has_audit_permission(r.audit_id,'report.view')
  ));
drop policy if exists audit_final_files_insert on public.audit_final_report_files;
create policy audit_final_files_insert on public.audit_final_report_files
  for insert to authenticated
  with check (exists (
    select 1 from public.audit_final_reports r
    where r.id = report_id and private.has_audit_permission(r.audit_id,'report.gov_upload')
  ));

grant select,insert,update on public.audit_final_reports to authenticated;
grant select on public.audit_final_report_versions to authenticated;
grant select,insert on public.audit_final_report_files to authenticated;
revoke insert,update,delete on public.audit_final_report_versions from authenticated;
revoke update,delete on public.audit_final_report_files from authenticated;

-- A user without report.view must not retrieve frozen report content or PDFs by
-- querying their backing version/file tables directly.
drop policy if exists versions_read on public.daily_report_versions;
create policy versions_read on public.daily_report_versions
  for select to authenticated
  using (exists (
    select 1 from public.daily_reports r
    where r.id = report_id and private.is_audit_participant(r.audit_id)
      and private.has_audit_permission(r.audit_id,'report.view')
  ));
drop policy if exists acknowledgements_read on public.report_acknowledgements;
create policy acknowledgements_read on public.report_acknowledgements
  for select to authenticated
  using (private.is_audit_participant(private.audit_id_for_report_version(report_version_id))
     and private.has_audit_permission(private.audit_id_for_report_version(report_version_id),'report.view'));
drop policy if exists report_files_read on public.report_external_files;
create policy report_files_read on public.report_external_files
  for select to authenticated
  using (exists (
    select 1 from public.daily_reports r
    where r.id = report_id and private.is_audit_participant(r.audit_id)
      and private.has_audit_permission(r.audit_id,'report.view')
  ));

drop policy if exists audit_reports_read on storage.objects;
create policy audit_reports_read on storage.objects
  for select to authenticated
  using (bucket_id='audit-reports'
     and (storage.foldername(name))[1]='audit'
     and private.is_audit_participant(((storage.foldername(name))[2])::uuid)
     and private.has_audit_permission(((storage.foldername(name))[2])::uuid,'report.view'));

revoke all on function private.is_audit_participant(uuid),
  private.has_audit_permission(uuid,text), private.is_audit_leader(uuid) from public;
grant execute on function private.is_audit_participant(uuid),
  private.has_audit_permission(uuid,text), private.is_audit_leader(uuid) to authenticated;

commit;
