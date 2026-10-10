-- B06 Parte 3/4: FPA — Formulário de Preparação para Auditoria (PA-11/12, D09). Aditiva.
-- D09: FPA mínimo por arquivo recebido e registrado pelo condutor; sem upload do cliente no piloto;
-- legados não recebem FPA inventado; FPA não integra automaticamente o PDF nem a projeção do cliente.
create table private.audit_fpa (
 audit_id uuid primary key references public.audits(id),
 status text not null default 'not_requested' check (status in ('not_requested','requested','received','in_analysis','complement_requested','sufficient')),
 recipient_name text check (recipient_name is null or length(btrim(recipient_name)) between 2 and 200),
 recipient_contact text check (recipient_contact is null or length(recipient_contact) <= 200),
 due_date date,
 requested_at timestamptz, requested_by uuid references auth.users(id),
 complement_questions text check (complement_questions is null or length(complement_questions) <= 5000),
 complement_due_date date,
 analysis_note text check (analysis_note is null or length(analysis_note) <= 5000),
 analyzed_at timestamptz, analyzed_by uuid references auth.users(id),
 sufficient_version_id uuid,
 lock_version integer not null default 1,
 updated_at timestamptz not null default now(),
 check (status <> 'sufficient' or (sufficient_version_id is not null and analyzed_at is not null and analyzed_by is not null))
);

create table private.audit_fpa_versions (
 id uuid primary key default gen_random_uuid(),
 audit_id uuid not null references private.audit_fpa(audit_id),
 version_number integer not null check (version_number > 0),
 format text not null check (format in ('pdf','docx','xlsx')),
 storage_path text not null unique,
 filename text not null check (length(filename) between 1 and 200),
 size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 20971520),
 sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
 mime_type text not null,
 received_on date not null,
 source_note text check (source_note is null or length(source_note) <= 1000),
 registered_by uuid not null references auth.users(id),
 registered_at timestamptz not null default now(),
 unique (audit_id, version_number)
);
alter table private.audit_fpa add constraint audit_fpa_sufficient_version_fk
 foreign key (sufficient_version_id) references private.audit_fpa_versions(id);

create table private.audit_fpa_events (
 id bigint generated always as identity primary key,
 audit_id uuid not null references private.audit_fpa(audit_id),
 action text not null, from_status text, to_status text,
 version_id uuid references private.audit_fpa_versions(id),
 actor uuid not null references auth.users(id),
 occurred_at timestamptz not null default now(),
 details jsonb not null default '{}'::jsonb
);
create index audit_fpa_events_audit_idx on private.audit_fpa_events (audit_id, occurred_at);

alter table private.audit_fpa enable row level security;
alter table private.audit_fpa_versions enable row level security;
alter table private.audit_fpa_events enable row level security;
revoke all on private.audit_fpa, private.audit_fpa_versions, private.audit_fpa_events from public, anon, authenticated;

-- Versões e eventos são imutáveis: correção = nova versão/novo evento.
create function private.b06_fpa_immutable() returns trigger language plpgsql set search_path = '' as $$
begin raise exception 'Registro de FPA é imutável' using errcode = '42501'; end;$$;
create trigger audit_fpa_versions_immutable before update or delete on private.audit_fpa_versions
 for each row execute function private.b06_fpa_immutable();
create trigger audit_fpa_events_immutable before update or delete on private.audit_fpa_events
 for each row execute function private.b06_fpa_immutable();
revoke all on function private.b06_fpa_immutable() from public, anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('audit-fpa', 'audit-fpa', false, 20971520, array['application/pdf',
 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'])
on conflict (id) do nothing;
