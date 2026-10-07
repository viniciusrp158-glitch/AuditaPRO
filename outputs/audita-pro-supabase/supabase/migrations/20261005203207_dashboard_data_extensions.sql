-- Audita PRO — dados de diretório e relatório final necessários ao Dashboard.
-- A migration CLI não está instalada neste ambiente; conferir e aplicar depois
-- de comparar a história remota de migrations com o pacote local.
begin;

alter table public.organizations
  add column if not exists trade_name text,
  add column if not exists segment text,
  add column if not exists address jsonb not null default '{}'::jsonb;

create table if not exists public.organization_contacts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  full_name text not null check (length(trim(full_name)) between 2 and 200),
  role_title text,
  email text,
  phone text,
  is_primary boolean not null default false,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
create index if not exists organization_contacts_org_status_idx
  on public.organization_contacts(organization_id,status);

alter table public.requirement_assessments
  drop constraint if exists requirement_assessments_result_check;
alter table public.requirement_assessments
  add constraint requirement_assessments_result_check check (
    result in ('conforming','partially_conforming','nonconforming','improvement','not_applicable','not_assessed')
  );

-- A final report is distinct from the existing one-report-per-audit-day model.
create table if not exists public.audit_final_reports (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null unique references public.audits(id) on delete restrict,
  status text not null default 'draft'
    check (status in ('draft','review','pending_acknowledgements','completed')),
  content jsonb not null default '{}'::jsonb,
  generated_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id) on delete restrict,
  edited_by uuid references auth.users(id) on delete set null,
  finalized_by uuid references auth.users(id) on delete set null,
  finalized_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_final_report_versions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.audit_final_reports(id) on delete restrict,
  version_number integer not null check (version_number > 0),
  content jsonb not null,
  checksum text not null,
  frozen_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id) on delete restrict,
  unique (report_id,version_number)
);
create index if not exists audit_final_report_versions_report_idx
  on public.audit_final_report_versions(report_id,version_number desc);

create table if not exists public.audit_final_report_files (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.audit_final_reports(id) on delete restrict,
  version_id uuid references public.audit_final_report_versions(id) on delete restrict,
  storage_path text not null unique,
  file_type text not null check (file_type in ('generated_pdf','gov_signed_pdf','attachment')),
  uploaded_by uuid not null references auth.users(id) on delete restrict,
  uploaded_at timestamptz not null default now()
);
create index if not exists audit_final_report_files_report_idx
  on public.audit_final_report_files(report_id,uploaded_at desc);

commit;
