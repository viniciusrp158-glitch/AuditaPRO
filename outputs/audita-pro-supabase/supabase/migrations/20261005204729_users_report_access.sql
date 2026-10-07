-- Preserve own acknowledgement through the guarded RPC, and hide report drafts
-- from supporting auditors and audited participants.
begin;

insert into public.access_profile_permissions(profile_id,permission_id,allowed)
select prof.id,perm.id,true from public.access_profiles prof
cross join public.access_permissions perm
where prof.name in ('Auditor','Participante / Auditado')
  and perm.permission_key='report.acknowledge'
on conflict(profile_id,permission_id) do update set allowed=true;

drop policy if exists acknowledgements_self on public.report_acknowledgements;
revoke update on public.report_acknowledgements from authenticated;

drop policy if exists reports_read on public.daily_reports;
create policy reports_read on public.daily_reports for select to authenticated
  using (private.is_audit_participant(audit_id)
    and private.has_audit_permission(audit_id,'report.view')
    and (status in ('pending_acknowledgements','completed')
      or private.is_audit_leader(audit_id)));

drop policy if exists versions_read on public.daily_report_versions;
create policy versions_read on public.daily_report_versions for select to authenticated
  using (exists(select 1 from public.daily_reports r where r.id=report_id
    and private.is_audit_participant(r.audit_id)
    and private.has_audit_permission(r.audit_id,'report.view')
    and (r.status in ('pending_acknowledgements','completed')
      or private.is_audit_leader(r.audit_id))));

drop policy if exists report_files_read on public.report_external_files;
create policy report_files_read on public.report_external_files for select to authenticated
  using (exists(select 1 from public.daily_reports r where r.id=report_id
    and private.is_audit_participant(r.audit_id)
    and private.has_audit_permission(r.audit_id,'report.view')
    and (r.status in ('pending_acknowledgements','completed')
      or private.is_audit_leader(r.audit_id))));

drop policy if exists audit_final_reports_read on public.audit_final_reports;
create policy audit_final_reports_read on public.audit_final_reports for select to authenticated
  using (private.is_audit_participant(audit_id)
    and private.has_audit_permission(audit_id,'report.view')
    and (status in ('pending_acknowledgements','completed')
      or private.is_audit_leader(audit_id)));

drop policy if exists audit_final_versions_read on public.audit_final_report_versions;
create policy audit_final_versions_read on public.audit_final_report_versions for select to authenticated
  using (exists(select 1 from public.audit_final_reports r where r.id=report_id
    and private.is_audit_participant(r.audit_id)
    and private.has_audit_permission(r.audit_id,'report.view')
    and (r.status in ('pending_acknowledgements','completed')
      or private.is_audit_leader(r.audit_id))));

drop policy if exists audit_final_files_read on public.audit_final_report_files;
create policy audit_final_files_read on public.audit_final_report_files for select to authenticated
  using (exists(select 1 from public.audit_final_reports r where r.id=report_id
    and private.is_audit_participant(r.audit_id)
    and private.has_audit_permission(r.audit_id,'report.view')
    and (r.status in ('pending_acknowledgements','completed')
      or private.is_audit_leader(r.audit_id))));

commit;
