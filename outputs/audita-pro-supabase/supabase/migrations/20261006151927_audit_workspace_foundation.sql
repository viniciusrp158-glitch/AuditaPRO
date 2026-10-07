begin;
create table public.audit_types (
 id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name)) between 2 and 160),
 code text not null unique, edition text, description text, active boolean not null default true,
 created_at timestamptz not null default now()
);
insert into public.audit_types(name,code) values ('ISO 9001 — Qualidade','ISO 9001'),('ISO 14001 — Meio Ambiente','ISO 14001'),('ISO 45001 — Segurança e Saúde no Trabalho','ISO 45001');
alter table public.checklist_templates add column organization_id uuid references public.organizations(id), add column type_id uuid references public.audit_types(id);
alter table public.audits add column workspace_version integer not null default 0,
 add column type_id uuid references public.audit_types(id), add column purpose text not null default 'Interna',
 add column party text not null default 'first' check(party in ('first','second','third')),
 add column modality text not null default 'presential', add column location text, add column timezone text not null default 'America/Sao_Paulo',
 add column criteria text, add column plan_draft jsonb not null default '[]', add column plan_revision integer not null default 0,
 add column lock_version integer not null default 0, add column team_reviewed boolean not null default false,
 add column execution_started_at timestamptz, add column execution_ended_at timestamptz,
 add column certification jsonb not null default '{"status":"not_applicable"}';
create table public.audit_plan_versions (
 id uuid primary key default gen_random_uuid(), audit_id uuid not null references public.audits(id),
 version_number integer not null, content jsonb not null, reason text not null,
 created_by uuid not null references auth.users(id), created_at timestamptz not null default now(), unique(audit_id,version_number)
);
create table public.audit_day_attendance (
 audit_day_id uuid not null references public.audit_days(id), membership_id uuid not null references public.organization_memberships(id),
 recorded_by uuid not null references auth.users(id), primary key(audit_day_id,membership_id)
);
alter table public.audit_days add column opening_plan_version integer, add column attendance_confirmed boolean not null default false;
alter table public.schedule_items add column category text not null default 'assessment' check(category in ('assessment','opening','closing','meeting','break','other')),
 add column actual_start timestamptz, add column actual_end timestamptz, add column withdrawn boolean not null default false;
create table public.schedule_requirements (
 schedule_item_id uuid not null references public.schedule_items(id), requirement_id uuid not null references public.checklist_requirements(id),
 primary key(schedule_item_id,requirement_id)
);
insert into public.schedule_requirements select id,requirement_id from public.schedule_items where requirement_id is not null;
create table public.schedule_movements (
 id uuid primary key default gen_random_uuid(), audit_id uuid not null references public.audits(id),
 schedule_item_id uuid not null references public.schedule_items(id), previous_data jsonb not null, new_data jsonb not null,
 reason text not null, created_by uuid not null references auth.users(id), created_at timestamptz not null default now()
);
alter table public.requirement_assessments drop constraint requirement_assessments_audit_id_audit_day_id_requirement_i_key;
create unique index assessments_day_process_req on public.requirement_assessments(audit_id,audit_day_id,requirement_id,coalesce(process_id,'00000000-0000-0000-0000-000000000000'::uuid));
alter table public.requirement_assessments add column evidence_text text, add column nc_justification text;
alter table public.evidence_files add column filename text, add column mime_type text, add column size_bytes integer;
create table public.audit_minutes (
 id uuid primary key default gen_random_uuid(), audit_id uuid not null references public.audits(id),
 schedule_item_id uuid not null unique references public.schedule_items(id), kind text not null check(kind in ('opening','closing','meeting')),
 content jsonb not null, status text not null default 'review' check(status in ('review','completed')),
 generated_at timestamptz not null default now(), finalized_at timestamptz, finalized_by uuid references auth.users(id)
);
create table public.audit_minutes_versions (
 id uuid primary key default gen_random_uuid(), report_id uuid not null references public.audit_minutes(id),
 version_number integer not null, content jsonb not null, checksum text not null, frozen_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id), unique(report_id,version_number)
);
create table public.audit_document_recipients (
 audit_id uuid not null references public.audits(id), document_id uuid not null,
 document_kind text not null check(document_kind in ('daily','final','minutes')),
 membership_id uuid not null references public.organization_memberships(id),
 primary key(document_id,document_kind,membership_id)
);
create index audit_plan_versions_audit on public.audit_plan_versions(audit_id,version_number desc);
create index schedule_movements_audit on public.schedule_movements(audit_id,created_at desc);
create index doc_recipients_member on public.audit_document_recipients(membership_id,audit_id);

create function private.workspace_member(org uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.is_active_account(auth.uid()) and exists(select 1 from public.organization_memberships m join public.user_profiles u on u.user_id=m.user_id where m.organization_id=org and m.user_id=auth.uid() and m.status='active' and m.competence_status in ('approved','not_required') and u.cpf is not null);
$$;
create function private.workspace_eligible(member uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.organization_memberships m join public.user_profiles u on u.user_id=m.user_id join public.access_profiles p on p.id=m.access_profile_id where m.id=member and m.status='active' and private.is_active_account(m.user_id) and ((private.profile_admin(m.user_id)) or (p.name='Auditor Líder' and p.status='active' and m.competence_status in ('approved','not_required') and u.cpf is not null)));
$$;
create function private.workspace_conductor(aid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.audits a join public.organization_memberships m on m.id=a.leader_membership_id join public.organizations o on o.id=a.organization_id where a.id=aid and m.user_id=auth.uid() and o.status='active' and private.workspace_eligible(m.id));
$$;
create function private.workspace_template_visible(tid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.profile_admin(auth.uid()) or exists(select 1 from public.checklist_templates t where t.id=tid and (t.organization_id is null or private.workspace_member(t.organization_id)));
$$;
create policy template_scope on public.checklist_templates as restrictive for select to authenticated using(private.workspace_template_visible(id));
create policy revision_scope on public.checklist_revisions as restrictive for select to authenticated using(private.workspace_template_visible(template_id));
create policy section_scope on public.checklist_sections as restrictive for select to authenticated using(exists(select 1 from public.checklist_revisions r where r.id=revision_id and private.workspace_template_visible(r.template_id)));
create policy requirement_scope on public.checklist_requirements as restrictive for select to authenticated using(exists(select 1 from public.checklist_sections s join public.checklist_revisions r on r.id=s.revision_id where s.id=section_id and private.workspace_template_visible(r.template_id)));

-- New workflows mutate through validated commands only. Existing records keep legacy routes.
create policy workspace_audit_insert on public.audits as restrictive for insert to authenticated with check(workspace_version=0);
create policy workspace_audit_update on public.audits as restrictive for update to authenticated using(workspace_version=0) with check(workspace_version=0);
do $$ declare tbl text; expr text; begin
 foreach tbl in array array['audit_checklists','audit_days','audit_participants','audit_processes','requirement_assessments','evidence_files','daily_reports','audit_final_reports'] loop
  expr:='not exists(select 1 from public.audits wa where wa.id=audit_id and wa.workspace_version>0)';
  execute format('create policy workspace_write_insert on public.%I as restrictive for insert to authenticated with check (%s)',tbl,expr);
  execute format('create policy workspace_write_update on public.%I as restrictive for update to authenticated using (%s) with check (%s)',tbl,expr,expr);
  execute format('create policy workspace_write_delete on public.%I as restrictive for delete to authenticated using (%s)',tbl,expr);
 end loop;
 expr:='not exists(select 1 from public.audit_days wd join public.audits wa on wa.id=wd.audit_id where wd.id=audit_day_id and wa.workspace_version>0)';
 execute format('create policy workspace_schedule_insert on public.schedule_items as restrictive for insert to authenticated with check (%s)',expr);
 execute format('create policy workspace_schedule_update on public.schedule_items as restrictive for update to authenticated using (%s) with check (%s)',expr,expr);
 execute format('create policy workspace_schedule_delete on public.schedule_items as restrictive for delete to authenticated using (%s)',expr);
 foreach tbl in array array['audit_types','audit_plan_versions','audit_day_attendance','schedule_requirements','schedule_movements','audit_minutes','audit_minutes_versions','audit_document_recipients'] loop
  execute format('alter table public.%I enable row level security',tbl);
  execute format('revoke all on public.%I from anon,authenticated',tbl);
  execute format('grant all on public.%I to service_role',tbl);
 end loop;
end $$;
revoke all on function private.workspace_member(uuid),private.workspace_eligible(uuid),private.workspace_conductor(uuid),private.workspace_template_visible(uuid) from public;
grant execute on function private.workspace_template_visible(uuid) to authenticated;
commit;
