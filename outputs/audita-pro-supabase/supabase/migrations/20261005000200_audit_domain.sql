-- Audita PRO MVP — audit execution, reporting, acknowledgement and archive.
-- Depends on 20261005000100_foundation.sql. Apply only to a development project first.
begin;

create table public.checklist_templates (
  id uuid primary key default gen_random_uuid(), name text not null, description text,
  status text not null default 'draft' check (status in ('draft','published','inactive')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.checklist_revisions (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.checklist_templates(id) on delete restrict,
  revision_number integer not null check (revision_number > 0),
  status text not null default 'draft' check (status in ('draft','published','retired')),
  created_by uuid references auth.users(id) on delete set null,
  published_at timestamptz, created_at timestamptz not null default now(),
  unique (template_id, revision_number)
);
create table public.checklist_sections (
  id uuid primary key default gen_random_uuid(),
  revision_id uuid not null references public.checklist_revisions(id) on delete restrict,
  title text not null, sort_order integer not null default 0, unique (revision_id, sort_order)
);
create table public.checklist_requirements (
  id uuid primary key default gen_random_uuid(),
  section_id uuid not null references public.checklist_sections(id) on delete restrict,
  reference text not null, prompt text not null, guidance text,
  sort_order integer not null default 0, unique (section_id, sort_order)
);

create table public.audits (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid,
  code text not null unique, title text not null, objective text, scope text,
  standards text[] not null default '{}', start_date date, end_date date,
  status text not null default 'draft'
    check (status in ('draft','planned','in_progress','awaiting_signoff','completed','cancelled')),
  leader_membership_id uuid not null references public.organization_memberships(id) on delete restrict,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  constraint audit_unit_belongs_to_org foreign key (unit_id, organization_id)
    references public.organization_units(id, organization_id) deferrable initially immediate,
  check (end_date is null or start_date is null or end_date >= start_date)
);
create table public.audit_checklists (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.audits(id) on delete restrict,
  revision_id uuid not null references public.checklist_revisions(id) on delete restrict,
  attached_at timestamptz not null default now(), attached_by uuid references auth.users(id) on delete set null,
  unique (audit_id, revision_id)
);
create table public.audit_days (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.audits(id) on delete restrict,
  day_number integer not null check (day_number > 0), audit_date date not null,
  started_at timestamptz, ended_at timestamptz,
  status text not null default 'planned' check (status in ('planned','in_progress','completed')),
  created_at timestamptz not null default now(), unique (audit_id, day_number), unique (audit_id, audit_date),
  check (ended_at is null or started_at is null or ended_at >= started_at)
);
create table public.audit_participants (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.audits(id) on delete restrict,
  membership_id uuid not null references public.organization_memberships(id) on delete restrict,
  participant_type text not null check (participant_type in ('leader','auditor','client','observer')),
  is_signatory boolean not null default false, active boolean not null default true,
  added_by uuid references auth.users(id) on delete set null, added_at timestamptz not null default now(),
  unique (audit_id, membership_id)
);
create table public.audit_processes (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.audits(id) on delete restrict,
  name text not null, sort_order integer not null default 0, created_at timestamptz not null default now(),
  unique (audit_id, name)
);
create table public.schedule_items (
  id uuid primary key default gen_random_uuid(),
  audit_day_id uuid not null references public.audit_days(id) on delete restrict,
  process_id uuid references public.audit_processes(id) on delete set null,
  requirement_id uuid references public.checklist_requirements(id) on delete set null,
  title text not null, planned_start timestamptz, planned_end timestamptz,
  assignee_membership_id uuid references public.organization_memberships(id) on delete set null,
  status text not null default 'planned' check (status in ('planned','in_progress','completed','not_done')),
  origin_day_id uuid references public.audit_days(id) on delete restrict,
  move_reason text, moved_at timestamptz, moved_by uuid references auth.users(id) on delete set null,
  notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (planned_end is null or planned_start is null or planned_end >= planned_start),
  check ((origin_day_id is null and moved_at is null and moved_by is null)
      or (origin_day_id is not null and moved_at is not null and moved_by is not null))
);
create table public.requirement_assessments (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.audits(id) on delete restrict,
  audit_day_id uuid not null references public.audit_days(id) on delete restrict,
  requirement_id uuid not null references public.checklist_requirements(id) on delete restrict,
  process_id uuid references public.audit_processes(id) on delete set null,
  result text not null default 'not_assessed'
    check (result in ('conforming','nonconforming','improvement','not_applicable','not_assessed')),
  notes text, created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (audit_id, audit_day_id, requirement_id)
);
create table public.nonconformities (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.audits(id) on delete restrict,
  audit_day_id uuid not null references public.audit_days(id) on delete restrict,
  requirement_id uuid references public.checklist_requirements(id) on delete set null,
  process_id uuid references public.audit_processes(id) on delete set null,
  code text not null, description text not null, classification text,
  status text not null default 'open'
    check (status in ('open','action_planned','in_progress','pending_review','closed')),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (audit_id, code)
);
create table public.action_plans (
  id uuid primary key default gen_random_uuid(),
  nonconformity_id uuid not null references public.nonconformities(id) on delete restrict,
  action_text text not null, responsible_name text not null, due_date date,
  status text not null default 'planned'
    check (status in ('planned','in_progress','completed','approved','rejected')),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.evidence_files (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.audits(id) on delete restrict,
  assessment_id uuid references public.requirement_assessments(id) on delete restrict,
  nonconformity_id uuid references public.nonconformities(id) on delete restrict,
  storage_path text not null unique, description text,
  uploaded_by uuid not null references auth.users(id) on delete restrict,
  uploaded_at timestamptz not null default now(),
  check (assessment_id is not null or nonconformity_id is not null)
);

create table public.daily_reports (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.audits(id) on delete restrict,
  audit_day_id uuid not null unique references public.audit_days(id) on delete restrict,
  status text not null default 'draft' check (status in ('draft','review','pending_acknowledgements','completed')),
  content jsonb not null default '{}'::jsonb,
  generated_at timestamptz not null default now(),
  edited_by uuid references auth.users(id) on delete set null,
  finalized_by uuid references auth.users(id) on delete set null,
  finalized_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.daily_report_versions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.daily_reports(id) on delete restrict,
  version_number integer not null check (version_number > 0),
  content jsonb not null,
  checksum text not null,
  frozen_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id) on delete restrict,
  unique(report_id, version_number)
);
create table public.report_acknowledgements (
  id uuid primary key default gen_random_uuid(),
  report_version_id uuid not null references public.daily_report_versions(id) on delete restrict,
  membership_id uuid not null references public.organization_memberships(id) on delete restrict,
  status text not null default 'pending' check (status in ('pending','acknowledged')),
  acknowledged_at timestamptz,
  acknowledged_by uuid references auth.users(id) on delete restrict,
  unique(report_version_id, membership_id),
  check ((status = 'pending' and acknowledged_at is null and acknowledged_by is null)
      or (status = 'acknowledged' and acknowledged_at is not null and acknowledged_by is not null))
);
create table public.report_external_files (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.daily_reports(id) on delete restrict,
  storage_path text not null unique,
  file_type text not null check (file_type in ('gov_signed_pdf','attachment')),
  uploaded_by uuid not null references auth.users(id) on delete restrict,
  uploaded_at timestamptz not null default now()
);
create table public.notification_outbox (
  id uuid primary key default gen_random_uuid(),
  acknowledgement_id uuid not null references public.report_acknowledgements(id) on delete restrict,
  channel text not null check(channel in ('email','in_app')),
  scheduled_at timestamptz not null,
  sent_at timestamptz,
  attempts integer not null default 0 check(attempts >= 0),
  last_error text,
  unique(acknowledgement_id, channel, scheduled_at)
);

-- Reject cross-organization and cross-audit references even when a caller fabricates UUIDs.
create or replace function private.enforce_audit_consistency()
returns trigger language plpgsql set search_path = '' as $$
declare parent_audit uuid;
begin
  if tg_table_name='audits' then
    if not exists(select 1 from public.organization_memberships m
      where m.id=new.leader_membership_id and m.organization_id=new.organization_id) then
      raise exception 'Auditor líder deve pertencer à empresa da auditoria';
    end if;
  elsif tg_table_name='audit_participants' then
    if not exists(select 1 from public.audits a join public.organization_memberships m on m.organization_id=a.organization_id
      where a.id=new.audit_id and m.id=new.membership_id) then
      raise exception 'Participante deve pertencer à empresa auditada';
    end if;
  elsif tg_table_name='requirement_assessments' then
    if not exists(select 1 from public.audit_days d where d.id=new.audit_day_id and d.audit_id=new.audit_id) then
      raise exception 'Dia da avaliação deve pertencer à mesma auditoria';
    end if;
    if new.process_id is not null and not exists(select 1 from public.audit_processes p where p.id=new.process_id and p.audit_id=new.audit_id) then
      raise exception 'Processo da avaliação deve pertencer à mesma auditoria';
    end if;
  elsif tg_table_name='nonconformities' then
    if not exists(select 1 from public.audit_days d where d.id=new.audit_day_id and d.audit_id=new.audit_id) then
      raise exception 'Dia da não conformidade deve pertencer à mesma auditoria';
    end if;
    if new.process_id is not null and not exists(select 1 from public.audit_processes p where p.id=new.process_id and p.audit_id=new.audit_id) then
      raise exception 'Processo da não conformidade deve pertencer à mesma auditoria';
    end if;
  elsif tg_table_name='schedule_items' then
    select d.audit_id into parent_audit from public.audit_days d where d.id=new.audit_day_id;
    if parent_audit is null then raise exception 'Dia do cronograma inválido'; end if;
    if new.process_id is not null and not exists(select 1 from public.audit_processes p where p.id=new.process_id and p.audit_id=parent_audit) then
      raise exception 'Processo do cronograma deve pertencer à mesma auditoria';
    end if;
    if new.origin_day_id is not null and not exists(select 1 from public.audit_days d where d.id=new.origin_day_id and d.audit_id=parent_audit) then
      raise exception 'Dia original deve pertencer à mesma auditoria';
    end if;
  elsif tg_table_name='evidence_files' then
    if new.assessment_id is not null and not exists(select 1 from public.requirement_assessments a where a.id=new.assessment_id and a.audit_id=new.audit_id) then
      raise exception 'Avaliação da evidência deve pertencer à mesma auditoria';
    end if;
    if new.nonconformity_id is not null and not exists(select 1 from public.nonconformities n where n.id=new.nonconformity_id and n.audit_id=new.audit_id) then
      raise exception 'Não conformidade da evidência deve pertencer à mesma auditoria';
    end if;
  elsif tg_table_name='daily_reports' then
    if not exists(select 1 from public.audit_days d where d.id=new.audit_day_id and d.audit_id=new.audit_id) then
      raise exception 'Dia do relatório deve pertencer à mesma auditoria';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_audit_consistency() from public;

create index on public.audits(organization_id, status, start_date);
create index on public.audit_days(audit_id, audit_date);
create index on public.schedule_items(audit_day_id, status, planned_start);
create index on public.requirement_assessments(audit_id, result);
create index on public.nonconformities(audit_id, status);
create index on public.action_plans(nonconformity_id, status);
create index on public.daily_reports(audit_id, status);
create index on public.report_acknowledgements(report_version_id, status);

-- Authorization helpers run outside exposed schemas and resolve explicit per-user overrides.
create or replace function private.has_org_permission(target_org uuid, required_permission text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_platform_admin() or exists (
    select 1 from public.organization_memberships m
    join public.access_permissions p on p.permission_key = required_permission
    left join public.access_profile_permissions pp on pp.profile_id = m.access_profile_id and pp.permission_id = p.id
    left join public.membership_permissions mp on mp.membership_id = m.id and mp.permission_id = p.id
    where m.organization_id = target_org and m.user_id = auth.uid() and m.status = 'active'
      and m.competence_status in ('approved','not_required') and coalesce(mp.allowed, pp.allowed, false)
  );
$$;
create or replace function private.has_audit_permission(target_audit uuid, required_permission text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.audits a where a.id = target_audit
    and private.has_org_permission(a.organization_id, required_permission));
$$;
create or replace function private.is_audit_participant(target_audit uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_platform_admin() or exists (
    select 1 from public.audit_participants ap
    join public.organization_memberships m on m.id = ap.membership_id
    where ap.audit_id = target_audit and ap.active and m.user_id = auth.uid()
      and m.status = 'active' and m.competence_status in ('approved','not_required'));
$$;
create or replace function private.is_audit_leader(target_audit uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_platform_admin() or exists (
    select 1 from public.audit_participants ap join public.organization_memberships m on m.id = ap.membership_id
    where ap.audit_id = target_audit and ap.participant_type = 'leader' and ap.active and m.user_id = auth.uid());
$$;
create or replace function private.audit_id_for_report_version(target_version uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select r.audit_id from public.daily_report_versions v join public.daily_reports r on r.id = v.report_id
  where v.id = target_version;
$$;
create or replace function public.finalize_daily_report(target_report uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  current_report public.daily_reports%rowtype;
  next_version integer;
  version_id uuid;
begin
  select * into current_report from public.daily_reports where id=target_report for update;
  if not found or not private.is_audit_leader(current_report.audit_id) then
    raise exception 'Relatório inexistente ou usuário sem permissão de auditor líder';
  end if;
  if current_report.status not in ('draft','review') then
    raise exception 'Relatório não está em estado editável';
  end if;
  select coalesce(max(version_number),0)+1 into next_version
    from public.daily_report_versions where report_id=target_report;
  insert into public.daily_report_versions(report_id,version_number,content,checksum,created_by)
    values(target_report,next_version,current_report.content,
      encode(extensions.digest(convert_to(current_report.content::text,'UTF8'),'sha256'),'hex'),auth.uid())
    returning id into version_id;
  insert into public.report_acknowledgements(report_version_id,membership_id)
    select version_id, ap.membership_id from public.audit_participants ap
    where ap.audit_id=current_report.audit_id and ap.active and ap.is_signatory;
  if not found then raise exception 'Defina ao menos um signatário antes de finalizar'; end if;
  insert into public.notification_outbox(acknowledgement_id,channel,scheduled_at)
    select a.id,c.channel,t.scheduled_at
    from public.report_acknowledgements a
    cross join (values ('email'::text),('in_app'::text)) c(channel)
    cross join (values (now()),(now()+interval '24 hours'),(now()+interval '48 hours')) t(scheduled_at)
    where a.report_version_id=version_id;
  update public.daily_reports set status='pending_acknowledgements', finalized_by=auth.uid(), finalized_at=now()
    where id=target_report;
  return version_id;
end;
$$;
create or replace function public.acknowledge_report(target_acknowledgement uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.report_acknowledgements ra
    set status='acknowledged', acknowledged_at=now(), acknowledged_by=auth.uid()
    where ra.id=target_acknowledgement and ra.status='pending'
      and exists(select 1 from public.organization_memberships m where m.id=ra.membership_id and m.user_id=auth.uid())
      and private.has_audit_permission(private.audit_id_for_report_version(ra.report_version_id),'report.acknowledge');
  if not found then raise exception 'Confirmação indisponível para este usuário'; end if;
  update public.daily_reports r set status='completed', completed_at=now()
    where r.id=(select v.report_id from public.report_acknowledgements a join public.daily_report_versions v on v.id=a.report_version_id where a.id=target_acknowledgement)
      and not exists(select 1 from public.report_acknowledgements a join public.daily_report_versions v on v.id=a.report_version_id
        where v.report_id=r.id and a.status='pending');
end;
$$;
create or replace function private.log_audit_event()
returns trigger language plpgsql security definer set search_path = '' as $$
declare row_data jsonb; audit_uuid uuid; org_uuid uuid; entity_uuid uuid;
begin
  row_data := case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
  entity_uuid := nullif(row_data->>'id','')::uuid;
  audit_uuid := nullif(row_data->>'audit_id','')::uuid;
  if tg_table_name='audits' then audit_uuid:=entity_uuid; end if;
  if audit_uuid is not null then select a.organization_id into org_uuid from public.audits a where a.id=audit_uuid; end if;
  insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,metadata)
  values(org_uuid,auth.uid(),lower(tg_op),tg_table_name,entity_uuid,
    jsonb_build_object('changed_fields',case when tg_op='UPDATE' then
      (select coalesce(jsonb_agg(key),'[]'::jsonb) from jsonb_each(to_jsonb(new)) e(key,value)
       where to_jsonb(old)->key is distinct from value) else '[]'::jsonb end));
  if tg_op='DELETE' then return old; else return new; end if;
end;
$$;
revoke all on function private.has_org_permission(uuid,text), private.has_audit_permission(uuid,text),
  private.is_audit_participant(uuid), private.is_audit_leader(uuid), private.audit_id_for_report_version(uuid) from public;
grant execute on function private.has_org_permission(uuid,text), private.has_audit_permission(uuid,text),
  private.is_audit_participant(uuid), private.is_audit_leader(uuid), private.audit_id_for_report_version(uuid) to authenticated;
revoke all on function public.finalize_daily_report(uuid), public.acknowledge_report(uuid) from public;
grant execute on function public.finalize_daily_report(uuid), public.acknowledge_report(uuid) to authenticated;
revoke all on function private.log_audit_event() from public;

alter table public.checklist_templates enable row level security;
alter table public.checklist_revisions enable row level security;
alter table public.checklist_sections enable row level security;
alter table public.checklist_requirements enable row level security;
alter table public.audits enable row level security;
alter table public.audit_checklists enable row level security;
alter table public.audit_days enable row level security;
alter table public.audit_participants enable row level security;
alter table public.audit_processes enable row level security;
alter table public.schedule_items enable row level security;
alter table public.requirement_assessments enable row level security;
alter table public.nonconformities enable row level security;
alter table public.action_plans enable row level security;
alter table public.evidence_files enable row level security;
alter table public.daily_reports enable row level security;
alter table public.daily_report_versions enable row level security;
alter table public.report_acknowledgements enable row level security;
alter table public.report_external_files enable row level security;
alter table public.notification_outbox enable row level security;

create policy checklist_read on public.checklist_templates for select to authenticated using(status='published' or public.is_platform_admin());
create policy checklist_admin on public.checklist_templates for all to authenticated using(public.is_platform_admin()) with check(public.is_platform_admin());
create policy revisions_read on public.checklist_revisions for select to authenticated using(status='published' or public.is_platform_admin());
create policy revisions_admin on public.checklist_revisions for all to authenticated using(public.is_platform_admin()) with check(public.is_platform_admin());
create policy sections_read on public.checklist_sections for select to authenticated using(exists(select 1 from public.checklist_revisions r where r.id=revision_id and (r.status='published' or public.is_platform_admin())));
create policy sections_admin on public.checklist_sections for all to authenticated using(public.is_platform_admin()) with check(public.is_platform_admin());
create policy requirements_read on public.checklist_requirements for select to authenticated using(exists(select 1 from public.checklist_sections s join public.checklist_revisions r on r.id=s.revision_id where s.id=section_id and (r.status='published' or public.is_platform_admin())));
create policy requirements_admin on public.checklist_requirements for all to authenticated using(public.is_platform_admin()) with check(public.is_platform_admin());

create policy audits_read on public.audits for select to authenticated using(private.is_audit_participant(id) or public.is_platform_admin());
create policy audits_insert on public.audits for insert to authenticated with check(private.has_org_permission(organization_id,'audit.create'));
create policy audits_update on public.audits for update to authenticated using(private.has_audit_permission(id,'audit.update')) with check(private.has_audit_permission(id,'audit.update'));
create policy audit_children_read on public.audit_checklists for select to authenticated using(private.is_audit_participant(audit_id));
create policy audit_children_insert on public.audit_checklists for insert to authenticated with check(private.has_audit_permission(audit_id,'audit.update'));
create policy days_read on public.audit_days for select to authenticated using(private.is_audit_participant(audit_id));
create policy days_write on public.audit_days for all to authenticated using(private.has_audit_permission(audit_id,'audit.update')) with check(private.has_audit_permission(audit_id,'audit.update'));
create policy participants_read on public.audit_participants for select to authenticated using(private.is_audit_participant(audit_id));
create policy participants_write on public.audit_participants for all to authenticated using(private.has_audit_permission(audit_id,'audit.manage_participants')) with check(private.has_audit_permission(audit_id,'audit.manage_participants'));
create policy processes_read on public.audit_processes for select to authenticated using(private.is_audit_participant(audit_id));
create policy processes_write on public.audit_processes for all to authenticated using(private.has_audit_permission(audit_id,'audit.update')) with check(private.has_audit_permission(audit_id,'audit.update'));
create policy schedule_read on public.schedule_items for select to authenticated using(exists(select 1 from public.audit_days d where d.id=audit_day_id and private.is_audit_participant(d.audit_id)));
create policy schedule_write on public.schedule_items for all to authenticated using(exists(select 1 from public.audit_days d where d.id=audit_day_id and private.has_audit_permission(d.audit_id,'schedule.manage'))) with check(exists(select 1 from public.audit_days d where d.id=audit_day_id and private.has_audit_permission(d.audit_id,'schedule.manage')));
create policy assessments_read on public.requirement_assessments for select to authenticated using(private.is_audit_participant(audit_id));
create policy assessments_write on public.requirement_assessments for all to authenticated using(private.has_audit_permission(audit_id,'audit.update')) with check(private.has_audit_permission(audit_id,'audit.update'));
create policy nc_read on public.nonconformities for select to authenticated using(private.is_audit_participant(audit_id));
create policy nc_insert on public.nonconformities for insert to authenticated with check(private.has_audit_permission(audit_id,'nonconformity.create'));
create policy nc_update on public.nonconformities for update to authenticated using(private.has_audit_permission(audit_id,'nonconformity.update')) with check(private.has_audit_permission(audit_id,'nonconformity.update'));
create policy actions_read on public.action_plans for select to authenticated using(exists(select 1 from public.nonconformities n where n.id=nonconformity_id and private.is_audit_participant(n.audit_id)));
create policy actions_insert on public.action_plans for insert to authenticated with check(exists(select 1 from public.nonconformities n where n.id=nonconformity_id and private.has_audit_permission(n.audit_id,'action.create')));
create policy actions_update on public.action_plans for update to authenticated using(exists(select 1 from public.nonconformities n where n.id=nonconformity_id and (private.has_audit_permission(n.audit_id,'action.update') or private.has_audit_permission(n.audit_id,'action.approve')))) with check(exists(select 1 from public.nonconformities n where n.id=nonconformity_id and (private.has_audit_permission(n.audit_id,'action.update') or private.has_audit_permission(n.audit_id,'action.approve'))));
create policy evidence_read on public.evidence_files for select to authenticated using(private.is_audit_participant(audit_id));
create policy evidence_write on public.evidence_files for all to authenticated using(private.has_audit_permission(audit_id,'evidence.upload')) with check(private.has_audit_permission(audit_id,'evidence.upload'));

create policy reports_read on public.daily_reports for select to authenticated using(private.is_audit_participant(audit_id) and private.has_audit_permission(audit_id,'report.view'));
create policy reports_create on public.daily_reports for insert to authenticated with check(private.is_audit_leader(audit_id));
create policy reports_edit on public.daily_reports for update to authenticated using(status in ('draft','review') and private.has_audit_permission(audit_id,'report.edit')) with check(status in ('draft','review') and private.has_audit_permission(audit_id,'report.edit'));
create policy versions_read on public.daily_report_versions for select to authenticated using(private.is_audit_participant(private.audit_id_for_report_version(id)));
create policy acknowledgements_read on public.report_acknowledgements for select to authenticated using(private.is_audit_participant(private.audit_id_for_report_version(report_version_id)));
create policy acknowledgements_self on public.report_acknowledgements for update to authenticated using(status='pending' and exists(select 1 from public.organization_memberships m where m.id=membership_id and m.user_id=auth.uid())) with check(status='acknowledged' and acknowledged_by=auth.uid() and acknowledged_at is not null and exists(select 1 from public.organization_memberships m where m.id=membership_id and m.user_id=auth.uid()));
create policy report_files_read on public.report_external_files for select to authenticated using(exists(select 1 from public.daily_reports r where r.id=report_id and private.is_audit_participant(r.audit_id)));
create policy report_files_insert on public.report_external_files for insert to authenticated with check(exists(select 1 from public.daily_reports r where r.id=report_id and private.has_audit_permission(r.audit_id,'report.gov_upload')));
create policy outbox_admin_read on public.notification_outbox for select to authenticated using(public.is_platform_admin());

create trigger audits_event after insert or update or delete on public.audits for each row execute function private.log_audit_event();
create trigger audit_days_event after insert or update or delete on public.audit_days for each row execute function private.log_audit_event();
create trigger schedule_event after insert or update or delete on public.schedule_items for each row execute function private.log_audit_event();
create trigger assessment_event after insert or update or delete on public.requirement_assessments for each row execute function private.log_audit_event();
create trigger nonconformity_event after insert or update or delete on public.nonconformities for each row execute function private.log_audit_event();
create trigger report_event after insert or update or delete on public.daily_reports for each row execute function private.log_audit_event();
create trigger audits_consistency before insert or update on public.audits for each row execute function private.enforce_audit_consistency();
create trigger participants_consistency before insert or update on public.audit_participants for each row execute function private.enforce_audit_consistency();
create trigger assessments_consistency before insert or update on public.requirement_assessments for each row execute function private.enforce_audit_consistency();
create trigger nonconformities_consistency before insert or update on public.nonconformities for each row execute function private.enforce_audit_consistency();
create trigger schedule_consistency before insert or update on public.schedule_items for each row execute function private.enforce_audit_consistency();
create trigger evidence_consistency before insert or update on public.evidence_files for each row execute function private.enforce_audit_consistency();
create trigger reports_consistency before insert or update on public.daily_reports for each row execute function private.enforce_audit_consistency();

grant select,insert,update,delete on public.checklist_templates, public.checklist_revisions, public.checklist_sections, public.checklist_requirements to authenticated;
grant select,insert,update,delete on public.audits, public.audit_checklists, public.audit_days, public.audit_participants, public.audit_processes, public.schedule_items, public.requirement_assessments, public.nonconformities, public.action_plans, public.evidence_files, public.daily_reports, public.report_external_files to authenticated;
grant select on public.daily_report_versions, public.report_acknowledgements, public.notification_outbox to authenticated;
revoke update on public.report_acknowledgements from authenticated;
revoke insert,update,delete on public.daily_report_versions, public.notification_outbox from authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('audit-evidence','audit-evidence',false,20971520,array['application/pdf','image/jpeg','image/png','image/webp']),
       ('audit-reports','audit-reports',false,20971520,array['application/pdf'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create policy audit_evidence_read on storage.objects for select to authenticated using(bucket_id='audit-evidence' and (storage.foldername(name))[1]='audit' and private.is_audit_participant(((storage.foldername(name))[2])::uuid));
create policy audit_evidence_insert on storage.objects for insert to authenticated with check(bucket_id='audit-evidence' and (storage.foldername(name))[1]='audit' and private.has_audit_permission(((storage.foldername(name))[2])::uuid,'evidence.upload'));
create policy audit_reports_read on storage.objects for select to authenticated using(bucket_id='audit-reports' and (storage.foldername(name))[1]='audit' and private.is_audit_participant(((storage.foldername(name))[2])::uuid));
create policy audit_reports_insert on storage.objects for insert to authenticated with check(bucket_id='audit-reports' and (storage.foldername(name))[1]='audit' and private.has_audit_permission(((storage.foldername(name))[2])::uuid,'report.gov_upload'));

commit;

