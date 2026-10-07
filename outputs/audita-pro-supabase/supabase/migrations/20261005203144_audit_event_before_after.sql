-- Audita PRO — detailed, privacy-aware before/after audit trail.
-- Additive migration: preserves the previously applied migration history.
begin;

create or replace function private.audit_event_snapshot(p_row jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  result jsonb := coalesce(p_row, '{}'::jsonb);
  field_name text;
  field_value text;
begin
  -- Never copy personal identifiers, credentials, or private object locations into the log.
  result := result - array[
    'cpf', 'email', 'phone', 'password', 'password_hash', 'token_hash',
    'access_token', 'refresh_token', 'storage_path', 'file_path', 'file_url',
    'original_filename', 'raw_user_meta_data', 'raw_app_meta_data',
    'ip_address', 'user_agent'
  ];

  -- Free text can contain personal or confidential details. Record a digest and length
  -- so changes remain detectable without copying the text into the audit log.
  foreach field_name in array array[
    'description', 'action_text', 'notes', 'content', 'objective', 'scope',
    'review_note', 'move_reason', 'reason', 'payload', 'responsible_name', 'location'
  ] loop
    if result ? field_name then
      field_value := coalesce(result ->> field_name, '');
      result := (result - field_name) || jsonb_build_object(
        field_name || '_integrity',
        jsonb_build_object(
          'sha256', encode(extensions.digest(convert_to(field_value, 'UTF8'), 'sha256'), 'hex'),
          'characters', char_length(field_value)
        )
      );
    end if;
  end loop;

  return result;
end;
$$;

create or replace function private.log_audit_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_row jsonb := '{}'::jsonb;
  new_row jsonb := '{}'::jsonb;
  old_snapshot jsonb := '{}'::jsonb;
  new_snapshot jsonb := '{}'::jsonb;
  old_values jsonb := '{}'::jsonb;
  new_values jsonb := '{}'::jsonb;
  changed_fields jsonb := '[]'::jsonb;
  row_data jsonb;
  audit_uuid uuid;
  org_uuid uuid;
  entity_uuid uuid;
  field_name text;
begin
  if tg_op in ('UPDATE', 'DELETE') then old_row := to_jsonb(old); end if;
  if tg_op in ('INSERT', 'UPDATE') then new_row := to_jsonb(new); end if;

  old_snapshot := private.audit_event_snapshot(old_row);
  new_snapshot := private.audit_event_snapshot(new_row);

  if tg_op in ('UPDATE', 'DELETE') then
    entity_uuid := coalesce(
      nullif(old_row ->> 'id', '')::uuid,
      nullif(old_row ->> 'membership_id', '')::uuid,
      nullif(old_row ->> 'user_id', '')::uuid,
      nullif(old_row ->> 'profile_id', '')::uuid
    );
  else
    entity_uuid := coalesce(
      nullif(new_row ->> 'id', '')::uuid,
      nullif(new_row ->> 'membership_id', '')::uuid,
      nullif(new_row ->> 'user_id', '')::uuid,
      nullif(new_row ->> 'profile_id', '')::uuid
    );
  end if;

  row_data := case when tg_op = 'DELETE' then old_row else new_row end;
  if tg_table_name = 'organizations' then
    if tg_op = 'DELETE' then
      -- The deleted organization's id remains in old_values; leave the FK nullable.
      org_uuid := null;
    else
      org_uuid := nullif(row_data ->> 'id', '')::uuid;
    end if;
  elsif row_data ? 'organization_id' then
    org_uuid := nullif(row_data ->> 'organization_id', '')::uuid;
  elsif row_data ? 'audit_id' then
    audit_uuid := nullif(row_data ->> 'audit_id', '')::uuid;
  elsif row_data ? 'audit_day_id' then
    select d.audit_id into audit_uuid
      from public.audit_days d where d.id = nullif(row_data ->> 'audit_day_id', '')::uuid;
  elsif row_data ? 'nonconformity_id' then
    select n.audit_id into audit_uuid
      from public.nonconformities n where n.id = nullif(row_data ->> 'nonconformity_id', '')::uuid;
  elsif row_data ? 'report_version_id' then
    select r.audit_id into audit_uuid
      from public.daily_report_versions v
      join public.daily_reports r on r.id = v.report_id
      where v.id = nullif(row_data ->> 'report_version_id', '')::uuid;
  elsif row_data ? 'report_id' then
    select r.audit_id into audit_uuid
      from public.daily_reports r
      where r.id = nullif(row_data ->> 'report_id', '')::uuid;
  elsif row_data ? 'membership_id' then
    select m.organization_id into org_uuid
      from public.organization_memberships m
      where m.id = nullif(row_data ->> 'membership_id', '')::uuid;
  end if;

  if audit_uuid is not null then
    select a.organization_id into org_uuid from public.audits a where a.id = audit_uuid;
  end if;

  if tg_op = 'INSERT' then
    old_values := '{}'::jsonb;
    new_values := new_snapshot;
    select coalesce(jsonb_agg(key order by key), '[]'::jsonb)
      into changed_fields from jsonb_object_keys(new_snapshot) as keys(key);
  elsif tg_op = 'DELETE' then
    old_values := old_snapshot;
    new_values := '{}'::jsonb;
    select coalesce(jsonb_agg(key order by key), '[]'::jsonb)
      into changed_fields from jsonb_object_keys(old_snapshot) as keys(key);
  else
    for field_name in
      select keys.key
      from (
        select jsonb_object_keys(old_snapshot) as key
        union
        select jsonb_object_keys(new_snapshot) as key
      ) as keys
      order by keys.key
    loop
      if old_snapshot -> field_name is distinct from new_snapshot -> field_name then
        changed_fields := changed_fields || jsonb_build_array(field_name);
        old_values := old_values || jsonb_build_object(field_name, old_snapshot -> field_name);
        new_values := new_values || jsonb_build_object(field_name, new_snapshot -> field_name);
      end if;
    end loop;

    -- Ignore no-op updates so the history reflects actual changes only.
    if changed_fields = '[]'::jsonb then
      return new;
    end if;
  end if;

  insert into public.audit_events (
    organization_id, actor_user_id, event_type, entity_type, entity_id, metadata
  ) values (
    org_uuid,
    auth.uid(),
    lower(tg_op),
    tg_table_name,
    entity_uuid,
    jsonb_build_object(
      'changed_fields', changed_fields,
      'old_values', old_values,
      'new_values', new_values
    )
  );

  if tg_op = 'DELETE' then return old; else return new; end if;
end;
$$;

-- Detailed log contents are restricted to the platform administrator until the
-- tenant-level permission matrix is implemented and approved in its own step.
drop policy if exists audit_events_select on public.audit_events;
create policy audit_events_select on public.audit_events
for select to authenticated
using (public.is_platform_admin());

-- Existing history triggers use the upgraded function and gain old/new snapshots.
-- Add coverage for corrective plans, participant/permission changes and approvals.
create trigger action_plans_event
  after insert or update or delete on public.action_plans
  for each row execute function private.log_audit_event();
create trigger audit_participants_event
  after insert or update or delete on public.audit_participants
  for each row execute function private.log_audit_event();
create trigger organizations_event
  after insert or update or delete on public.organizations
  for each row execute function private.log_audit_event();
create trigger positions_event
  after insert or update or delete on public.positions
  for each row execute function private.log_audit_event();
create trigger access_profiles_event
  after insert or update or delete on public.access_profiles
  for each row execute function private.log_audit_event();
create trigger access_permissions_event
  after insert or update or delete on public.access_permissions
  for each row execute function private.log_audit_event();
create trigger memberships_event
  after insert or update or delete on public.organization_memberships
  for each row execute function private.log_audit_event();
create trigger membership_permissions_event
  after insert or update or delete on public.membership_permissions
  for each row execute function private.log_audit_event();
create trigger profile_permissions_event
  after insert or update or delete on public.access_profile_permissions
  for each row execute function private.log_audit_event();
create trigger user_documents_event
  after insert or update or delete on public.user_documents
  for each row execute function private.log_audit_event();
create trigger report_acknowledgements_event
  after insert or update or delete on public.report_acknowledgements
  for each row execute function private.log_audit_event();
create trigger report_versions_event
  after insert or update or delete on public.daily_report_versions
  for each row execute function private.log_audit_event();
create trigger report_external_files_event
  after insert or update or delete on public.report_external_files
  for each row execute function private.log_audit_event();

revoke all on function private.audit_event_snapshot(jsonb) from public;
revoke all on function private.log_audit_event() from public;

commit;
