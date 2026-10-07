-- Audita PRO MVP — foundation / identity and organizations
-- Draft migration; not yet applied to a Supabase project.
-- Apply to a fresh Supabase project after reviewing the pending product decisions.
-- The application must never expose the Supabase service-role key.
-- CNPJ and CPF are stored as digits only; normalize input in the application.

begin;

create extension if not exists pgcrypto;
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  legal_name text not null check (length(trim(legal_name)) between 2 and 200),
  cnpj text not null unique check (cnpj ~ '^[0-9]{14}$'),
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists public.organization_units (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  name text not null check (length(trim(name)) between 1 and 160),
  location text,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  unique (organization_id, name),
  unique (id, organization_id)
);

create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  cpf text check (cpf is null or cpf ~ '^[0-9]{11}$'),
  email text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists user_profiles_cpf_unique
  on public.user_profiles (cpf) where cpf is not null and cpf <> '';

create table if not exists public.positions (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  requires_identity_document boolean not null default false,
  is_system boolean not null default false,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now()
);

create table if not exists public.access_permissions (
  id uuid primary key default gen_random_uuid(),
  permission_key text not null unique,
  description text not null,
  module text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.access_profiles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  is_system boolean not null default false,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now()
);

create table if not exists public.access_profile_permissions (
  profile_id uuid not null references public.access_profiles(id) on delete cascade,
  permission_id uuid not null references public.access_permissions(id) on delete cascade,
  allowed boolean not null default true,
  primary key (profile_id, permission_id)
);

create table if not exists public.organization_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid references public.organization_units(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  position_id uuid references public.positions(id) on delete set null,
  access_profile_id uuid references public.access_profiles(id) on delete set null,
  status text not null default 'active' check (status in ('active','inactive')),
  competence_status text not null default 'pending'
    check (competence_status in ('not_required','pending','approved','rejected')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  unique (organization_id, user_id),
  constraint membership_unit_belongs_to_org
    foreign key (unit_id, organization_id)
    references public.organization_units(id, organization_id)
    deferrable initially immediate
);

create table if not exists public.membership_permissions (
  membership_id uuid not null references public.organization_memberships(id) on delete cascade,
  permission_id uuid not null references public.access_permissions(id) on delete cascade,
  allowed boolean not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  primary key (membership_id, permission_id)
);

create table if not exists public.user_documents (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null references public.organization_memberships(id) on delete restrict,
  document_type text not null check (document_type = 'identity'),
  storage_path text not null unique,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  uploaded_at timestamptz not null default now(),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  review_note text,
  constraint reviewed_document_has_reviewer
    check ((status = 'pending' and reviewed_by is null and reviewed_at is null)
        or (status <> 'pending' and reviewed_by is not null and reviewed_at is not null))
);

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete restrict,
  actor_user_id uuid references auth.users(id) on delete set null,
  event_type text not null,
  entity_type text not null,
  entity_id uuid,
  occurred_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

-- Initial roles and permission catalog; the three specified positions require identity review.
insert into public.positions (name, requires_identity_document, is_system)
values
  ('Auditor Líder', true, true),
  ('Auditor', true, true),
  ('Cliente', true, true),
  ('Gestor SSMA', false, true),
  ('Instrutor SSMA', false, true),
  ('Responsável Técnico', false, true)
on conflict (name) do nothing;

insert into public.access_profiles (name, is_system)
values ('Auditor', true), ('Gestor', true), ('Consulta', true), ('Personalizado', true)
on conflict (name) do nothing;

insert into public.access_permissions (permission_key, description, module)
values
  ('audit.view', 'Visualizar auditorias autorizadas', 'audits'),
  ('audit.create', 'Criar auditorias', 'audits'),
  ('audit.update', 'Editar planejamento e execução', 'audits'),
  ('audit.close', 'Finalizar auditorias', 'audits'),
  ('audit.manage_participants', 'Gerenciar equipe e participantes', 'audits'),
  ('checklist.manage', 'Gerenciar modelos de checklist', 'checklists'),
  ('schedule.manage', 'Gerenciar cronograma e transferências', 'schedule'),
  ('schedule.execute', 'Atualizar etapas do cronograma', 'schedule'),
  ('evidence.upload', 'Enviar evidências', 'evidence'),
  ('evidence.approve', 'Aprovar evidências', 'evidence'),
  ('nonconformity.create', 'Criar não conformidades', 'findings'),
  ('nonconformity.update', 'Editar não conformidades', 'findings'),
  ('action.create', 'Criar planos de ação', 'actions'),
  ('action.update', 'Editar planos de ação', 'actions'),
  ('action.approve', 'Aprovar planos de ação', 'actions'),
  ('indicators.view', 'Visualizar indicadores', 'indicators'),
  ('report.view', 'Visualizar relatórios autorizados', 'reports'),
  ('report.edit', 'Editar rascunhos de relatório', 'reports'),
  ('report.finalize', 'Finalizar relatórios', 'reports'),
  ('report.acknowledge', 'Confirmar ciência de relatório selecionado', 'reports'),
  ('report.gov_upload', 'Anexar cópia de relatório assinada via GOV', 'reports'),
  ('user.manage', 'Gerenciar usuários e documentos', 'users'),
  ('organization.manage', 'Gerenciar empresas e unidades', 'organizations')
on conflict (permission_key) do nothing;

insert into public.access_profile_permissions (profile_id, permission_id, allowed)
select p.id, ap.id, true
from public.access_profiles p
join public.access_permissions ap on ap.permission_key = any (
  case p.name
    when 'Auditor' then array['audit.view','audit.create','audit.update','audit.close','audit.manage_participants','schedule.execute','schedule.manage','evidence.upload','nonconformity.create','nonconformity.update','action.create','action.update','report.view','report.edit','report.finalize','report.gov_upload','report.acknowledge']
    when 'Gestor' then array['audit.view','evidence.approve','action.approve','indicators.view','report.view']
    when 'Consulta' then array['audit.view','report.view','report.acknowledge']
    else array[]::text[]
  end
)
on conflict (profile_id, permission_id) do nothing;

create index if not exists memberships_user_idx
  on public.organization_memberships(user_id, status);
create index if not exists memberships_org_idx
  on public.organization_memberships(organization_id, status);
create index if not exists user_documents_membership_idx
  on public.user_documents(membership_id, uploaded_at desc);
create index if not exists audit_events_org_time_idx
  on public.audit_events(organization_id, occurred_at desc);

-- Global administrator status must be set only in protected app_metadata by an operator.
create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'platform_role') = 'admin', false);
$$;

-- SECURITY DEFINER avoids recursive RLS when policies check active organization membership.
create or replace function private.is_active_org_member(target_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_memberships m
    where m.organization_id = target_organization_id
      and m.user_id = auth.uid()
      and m.status = 'active'
      and m.competence_status in ('approved','not_required')
  );
$$;

create or replace function private.is_active_membership_owner(target_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_memberships m
    where m.id = target_membership_id
      and m.user_id = auth.uid()
      and m.status = 'active'
  );
$$;

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists user_profiles_set_updated_at on public.user_profiles;
create trigger user_profiles_set_updated_at
before update on public.user_profiles
for each row execute function private.set_updated_at();

drop trigger if exists organizations_set_updated_at on public.organizations;
create trigger organizations_set_updated_at
before update on public.organizations
for each row execute function private.set_updated_at();

-- Keep a minimal profile row when Supabase Auth creates an account.
create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.user_profiles (user_id, full_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.email
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function private.handle_new_auth_user();

revoke all on function private.set_updated_at() from public;
revoke all on function private.handle_new_auth_user() from public;

alter table public.organizations enable row level security;
alter table public.organization_units enable row level security;
alter table public.user_profiles enable row level security;
alter table public.positions enable row level security;
alter table public.access_permissions enable row level security;
alter table public.access_profiles enable row level security;
alter table public.access_profile_permissions enable row level security;
alter table public.organization_memberships enable row level security;
alter table public.membership_permissions enable row level security;
alter table public.user_documents enable row level security;
alter table public.audit_events enable row level security;

-- Organizations: company users can see their own organization; platform admins can see all.
drop policy if exists organizations_select on public.organizations;
create policy organizations_select on public.organizations
for select to authenticated
using (public.is_platform_admin() or private.is_active_org_member(id));

drop policy if exists organizations_admin_write on public.organizations;
create policy organizations_admin_write on public.organizations
for all to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());

drop policy if exists organization_units_select on public.organization_units;
create policy organization_units_select on public.organization_units
for select to authenticated
using (public.is_platform_admin() or private.is_active_org_member(organization_id));

drop policy if exists organization_units_admin_write on public.organization_units;
create policy organization_units_admin_write on public.organization_units
for all to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());

-- Users may read their own profile; platform administrators can review profiles globally.
drop policy if exists user_profiles_select on public.user_profiles;
create policy user_profiles_select on public.user_profiles
for select to authenticated
using (user_id = auth.uid() or public.is_platform_admin());

drop policy if exists user_profiles_insert_self on public.user_profiles;
create policy user_profiles_insert_self on public.user_profiles
for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists user_profiles_update_self on public.user_profiles;
create policy user_profiles_update_self on public.user_profiles
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists user_profiles_admin on public.user_profiles;
create policy user_profiles_admin on public.user_profiles
for all to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());

-- Membership records, roles and approvals are provisioned/reviewed by platform administrators.
drop policy if exists memberships_select on public.organization_memberships;
create policy memberships_select on public.organization_memberships
for select to authenticated
using (user_id = auth.uid() or public.is_platform_admin());

drop policy if exists memberships_admin_write on public.organization_memberships;
create policy memberships_admin_write on public.organization_memberships
for all to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());

drop policy if exists positions_select on public.positions;
create policy positions_select on public.positions
for select to authenticated
using (status = 'active' or public.is_platform_admin());

drop policy if exists positions_admin_write on public.positions;
create policy positions_admin_write on public.positions
for all to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());

drop policy if exists permissions_select on public.access_permissions;
create policy permissions_select on public.access_permissions
for select to authenticated
using (true);

drop policy if exists permissions_admin_write on public.access_permissions;
create policy permissions_admin_write on public.access_permissions
for all to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());

drop policy if exists access_profiles_select on public.access_profiles;
create policy access_profiles_select on public.access_profiles
for select to authenticated
using (status = 'active' or public.is_platform_admin());

drop policy if exists access_profiles_admin_write on public.access_profiles;
create policy access_profiles_admin_write on public.access_profiles
for all to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());

drop policy if exists profile_permissions_select on public.access_profile_permissions;
create policy profile_permissions_select on public.access_profile_permissions
for select to authenticated
using (true);

drop policy if exists profile_permissions_admin_write on public.access_profile_permissions;
create policy profile_permissions_admin_write on public.access_profile_permissions
for all to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());

drop policy if exists membership_permissions_select on public.membership_permissions;
create policy membership_permissions_select on public.membership_permissions
for select to authenticated
using (public.is_platform_admin() or private.is_active_membership_owner(membership_id));

drop policy if exists membership_permissions_admin_write on public.membership_permissions;
create policy membership_permissions_admin_write on public.membership_permissions
for all to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());

-- A user can submit their own pending identity document; only an administrator can review it.
drop policy if exists user_documents_select on public.user_documents;
create policy user_documents_select on public.user_documents
for select to authenticated
using (public.is_platform_admin() or private.is_active_membership_owner(membership_id));

drop policy if exists user_documents_insert_self on public.user_documents;
create policy user_documents_insert_self on public.user_documents
for insert to authenticated
with check (
  status = 'pending'
  and reviewed_by is null
  and reviewed_at is null
  and private.is_active_membership_owner(membership_id)
);

drop policy if exists user_documents_admin_update on public.user_documents;
create policy user_documents_admin_update on public.user_documents
for update to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());

drop policy if exists user_documents_admin_delete on public.user_documents;
create policy user_documents_admin_delete on public.user_documents
for delete to authenticated
using (public.is_platform_admin());

-- Audit-event writes are reserved for trusted server functions; authenticated members can read
-- events in their approved organization and administrators can read the global event stream.
drop policy if exists audit_events_select on public.audit_events;
create policy audit_events_select on public.audit_events
for select to authenticated
using (public.is_platform_admin() or (organization_id is not null and private.is_active_org_member(organization_id)));

revoke all on public.audit_events from authenticated;
grant select on public.audit_events to authenticated;

-- Restrict profile self-edits to basic contact/name fields; CPF and system decisions are admin-managed.
revoke update on public.user_profiles from authenticated;
grant update (full_name, phone) on public.user_profiles to authenticated;
grant select, insert on public.user_profiles to authenticated;

grant select, insert, update, delete on public.organizations to authenticated;
grant select, insert, update, delete on public.organization_units to authenticated;
grant select on public.organization_memberships to authenticated;
grant select, insert, update, delete on public.organization_memberships to authenticated;
grant select, insert, update, delete on public.positions to authenticated;
grant select, insert, update, delete on public.access_permissions to authenticated;
grant select, insert, update, delete on public.access_profiles to authenticated;
grant select, insert, update, delete on public.access_profile_permissions to authenticated;
grant select, insert, update, delete on public.membership_permissions to authenticated;
grant select, insert, update, delete on public.user_documents to authenticated;

revoke all on function public.is_platform_admin() from public;
revoke all on function private.is_active_org_member(uuid) from public;
revoke all on function private.is_active_membership_owner(uuid) from public;
grant execute on function public.is_platform_admin() to authenticated;
grant execute on function private.is_active_org_member(uuid) to authenticated;
grant execute on function private.is_active_membership_owner(uuid) to authenticated;

-- Create a private bucket for identity documents. Paths must be identity/<membership UUID>/<file UUID>.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('identity-documents', 'identity-documents', false, 10485760,
        array['application/pdf','image/jpeg','image/png'])
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists identity_objects_select on storage.objects;
create policy identity_objects_select on storage.objects
for select to authenticated
using (
  bucket_id = 'identity-documents'
  and (storage.foldername(name))[1] = 'identity'
  and (
    public.is_platform_admin()
    or private.is_active_membership_owner(((storage.foldername(name))[2])::uuid)
  )
);

drop policy if exists identity_objects_insert_self on storage.objects;
create policy identity_objects_insert_self on storage.objects
for insert to authenticated
with check (
  bucket_id = 'identity-documents'
  and (storage.foldername(name))[1] = 'identity'
  and private.is_active_membership_owner(((storage.foldername(name))[2])::uuid)
);

drop policy if exists identity_objects_delete_admin on storage.objects;
create policy identity_objects_delete_admin on storage.objects
for delete to authenticated
using (bucket_id = 'identity-documents' and public.is_platform_admin());

commit;


