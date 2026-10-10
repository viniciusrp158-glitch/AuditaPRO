-- B08 Parte 1/3: pedido de emissão documental persistente, tentativas e bucket privado. Aditiva, sem DELETE (AD-15).
-- Um pedido por (tipo, revisão); conteúdo congelado com SHA-256; o PDF só fica "pronto" após upload e conferência
-- de integridade; "publicado" é decisão separada do produtor (B09/B11/B12).
create table private.document_emissions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id),
  audit_id uuid references public.audits(id),
  document_kind text not null check (document_kind in ('plan', 'rda', 'final_report', 'minutes', 'specimen')),
  document_id uuid not null,
  version_id uuid not null,
  revision_label text,
  title text not null check (length(title) between 1 and 300),
  filename text not null check (filename ~ '^[A-Za-z0-9._-]{1,120}\.pdf$'),
  template_key text not null,
  template_version int not null check (template_version > 0),
  content jsonb not null,
  content_sha256 text not null check (content_sha256 ~ '^[0-9a-f]{64}$'),
  auto_publish boolean not null default false,
  status text not null default 'pending' check (status in ('pending', 'processing', 'failed', 'ready', 'published')),
  attempt_count int not null default 0,
  max_attempts int not null default 5,
  lease_token uuid,
  lease_expires_at timestamptz,
  last_error text,
  storage_bucket text,
  storage_path text,
  pdf_sha256 text check (pdf_sha256 is null or pdf_sha256 ~ '^[0-9a-f]{64}$'),
  size_bytes bigint,
  page_count int,
  engine_version text,
  asset_manifest jsonb,
  metrics jsonb,
  requested_by uuid not null references auth.users(id),
  request_operation_id uuid,
  requested_at timestamptz not null default clock_timestamp(),
  started_at timestamptz,
  completed_at timestamptz,
  published_at timestamptz,
  published_by uuid references auth.users(id),
  unique (document_kind, version_id),
  check (status not in ('ready', 'published') or (storage_path is not null and pdf_sha256 is not null and size_bytes > 0 and page_count > 0))
);
create unique index document_emissions_operation on private.document_emissions (requested_by, request_operation_id) where request_operation_id is not null;
create index document_emissions_audit on private.document_emissions (audit_id, document_kind, requested_at desc);
create index document_emissions_open on private.document_emissions (status) where status in ('pending', 'processing', 'failed');

create table private.document_emission_attempts (
  emission_id uuid not null references private.document_emissions(id),
  attempt_number int not null,
  lease_token uuid not null,
  triggered_by uuid references auth.users(id),
  started_at timestamptz not null default clock_timestamp(),
  finished_at timestamptz,
  outcome text check (outcome in ('ready', 'failed', 'lease_lost')),
  error text,
  storage_path text,
  pdf_sha256 text,
  size_bytes bigint,
  metrics jsonb,
  primary key (emission_id, attempt_number)
);

alter table private.document_emissions enable row level security;
alter table private.document_emission_attempts enable row level security;
revoke all on private.document_emissions, private.document_emission_attempts from public, anon, authenticated;

-- Imutabilidade: identidade e conteúdo nunca mudam; artefato pronto não é substituído; nada é excluído.
create function private.b08_emission_guard() returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then raise exception 'Pedidos e tentativas de emissão não são excluídos'; end if;
  if tg_table_name = 'document_emission_attempts' then
    if old.outcome is not null then raise exception 'Tentativa encerrada é imutável'; end if;
    if new.emission_id <> old.emission_id or new.attempt_number <> old.attempt_number or new.lease_token <> old.lease_token then
      raise exception 'Identidade da tentativa é imutável'; end if;
    return new;
  end if;
  if (new.organization_id, new.audit_id, new.document_kind, new.document_id, new.version_id, new.revision_label, new.title,
      new.filename, new.template_key, new.template_version, new.content_sha256, new.requested_by, new.requested_at, new.auto_publish)
     is distinct from (old.organization_id, old.audit_id, old.document_kind, old.document_id, old.version_id, old.revision_label, old.title,
      old.filename, old.template_key, old.template_version, old.content_sha256, old.requested_by, old.requested_at, old.auto_publish)
     or new.content::text is distinct from old.content::text then
    raise exception 'Identidade e conteúdo do pedido de emissão são imutáveis'; end if;
  if old.status in ('ready', 'published') then
    if (new.storage_bucket, new.storage_path, new.pdf_sha256, new.size_bytes, new.page_count, new.engine_version, new.completed_at)
       is distinct from (old.storage_bucket, old.storage_path, old.pdf_sha256, old.size_bytes, old.page_count, old.engine_version, old.completed_at)
       or new.asset_manifest::text is distinct from old.asset_manifest::text then
      raise exception 'Arquivo emitido não pode ser substituído; gere nova revisão'; end if;
    if not (new.status = old.status or (old.status = 'ready' and new.status = 'published')) then
      raise exception 'Documento emitido não volta a estado anterior'; end if;
  end if;
  return new;
end;$$;
create trigger document_emissions_guard before update or delete on private.document_emissions
  for each row execute function private.b08_emission_guard();
create trigger document_emission_attempts_guard before update or delete on private.document_emission_attempts
  for each row execute function private.b08_emission_guard();
revoke all on function private.b08_emission_guard() from public, anon, authenticated;

-- Bucket privado do artefato oficial: só a Edge Function (service role) grava e lê; o navegador recebe URL temporária.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('document-emissions', 'document-emissions', false, 52428800, array['application/pdf'])
on conflict (id) do nothing;
