-- B05 / Biblioteca corporativa (D07 = PC-01..PC-08 + V-07). Parte 1/3: tabelas, índices, RLS e proteções. Aditiva.
create table private.corporate_documents (
 id uuid primary key default gen_random_uuid(),
 title text not null check (length(btrim(title)) between 2 and 200),
 doc_type text not null check (doc_type in ('procedimento','modelo','formulario','instrucao','politica','registro','outro')),
 code text check (code is null or length(btrim(code)) between 1 and 60),
 description text check (description is null or length(description) <= 2000),
 archived_at timestamptz,
 archived_by uuid references auth.users(id),
 archive_reason text check (archive_reason is null or length(archive_reason) <= 1000),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_by uuid references auth.users(id),
 updated_at timestamptz not null default now(),
 lock_version integer not null default 1,
 check ((archived_at is null) = (archived_by is null))
);
create unique index corporate_documents_code_key on private.corporate_documents (upper(btrim(code))) where code is not null;
create index corporate_documents_title_idx on private.corporate_documents (lower(title));

create table private.corporate_document_revisions (
 id uuid primary key default gen_random_uuid(),
 document_id uuid not null references private.corporate_documents(id),
 revision_label text not null check (length(btrim(revision_label)) between 1 and 30),
 status text not null default 'draft' check (status in ('draft','current','superseded','cancelled')),
 responsible text check (responsible is null or length(btrim(responsible)) between 2 and 200),
 issued_on date,
 change_summary text check (change_summary is null or length(change_summary) <= 2000),
 published_at timestamptz,
 published_by uuid references auth.users(id),
 superseded_at timestamptz,
 superseded_by_revision uuid references private.corporate_document_revisions(id),
 cancelled_at timestamptz,
 cancelled_by uuid references auth.users(id),
 cancel_reason text,
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
  check (status in ('draft','cancelled') or (responsible is not null and issued_on is not null and published_at is not null and published_by is not null))
);
create unique index corporate_revisions_label_key on private.corporate_document_revisions (document_id, upper(btrim(revision_label)));
create unique index corporate_revisions_one_current on private.corporate_document_revisions (document_id) where status = 'current';
create unique index corporate_revisions_one_draft on private.corporate_document_revisions (document_id) where status = 'draft';

create table private.corporate_document_files (
 id uuid primary key default gen_random_uuid(),
 revision_id uuid not null references private.corporate_document_revisions(id),
 format text not null check (format in ('pdf','docx','dotx')),
 storage_path text not null unique,
 filename text not null check (length(filename) between 1 and 200),
 size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 20971520),
 sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
 mime_type text not null,
 uploaded_by uuid not null references auth.users(id),
 uploaded_at timestamptz not null default now(),
 unique (revision_id, format)
);
create index corporate_files_revision_idx on private.corporate_document_files (revision_id);

create table private.corporate_library_operations (
 operation_id uuid primary key,
 actor uuid not null references auth.users(id),
 command text not null,
 response jsonb not null,
 created_at timestamptz not null default now()
);

alter table private.corporate_documents enable row level security;
alter table private.corporate_document_revisions enable row level security;
alter table private.corporate_document_files enable row level security;
alter table private.corporate_library_operations enable row level security;
revoke all on private.corporate_documents, private.corporate_document_revisions,
 private.corporate_document_files, private.corporate_library_operations from public, anon, authenticated;

create function private.corporate_file_guard() returns trigger
 language plpgsql set search_path = '' as $$
begin
 if tg_op = 'UPDATE' then
  raise exception 'Arquivo registrado é imutável' using errcode = '42501';
 end if;
 if exists (select 1 from private.corporate_document_revisions r where r.id = old.revision_id and r.status <> 'draft') then
  raise exception 'Arquivo de revisão emitida não pode ser removido' using errcode = '42501';
 end if;
 return old;
end;$$;
create trigger corporate_file_guard before update or delete on private.corporate_document_files
 for each row execute function private.corporate_file_guard();

create function private.corporate_revision_guard() returns trigger
 language plpgsql set search_path = '' as $$
begin
 if tg_op = 'DELETE' then raise exception 'Revisões não são excluídas' using errcode = '42501'; end if;
 if old.status <> 'draft' and (new.revision_label, new.responsible, new.issued_on, new.change_summary, new.document_id, new.published_at, new.published_by)
    is distinct from (old.revision_label, old.responsible, old.issued_on, old.change_summary, old.document_id, old.published_at, old.published_by) then
  raise exception 'Revisão emitida não pode ser alterada' using errcode = '42501';
 end if;
 if not ((old.status = new.status) or (old.status = 'draft' and new.status in ('current','cancelled')) or (old.status = 'current' and new.status = 'superseded')) then
  raise exception 'Transição de situação inválida' using errcode = '42501';
 end if;
 new.updated_at := clock_timestamp();
 return new;
end;$$;
create trigger corporate_revision_guard before update or delete on private.corporate_document_revisions
 for each row execute function private.corporate_revision_guard();

create function private.corporate_document_guard() returns trigger
 language plpgsql set search_path = '' as $$
begin
 if tg_op = 'DELETE' then raise exception 'Documentos não são excluídos; use arquivar' using errcode = '42501'; end if;
 return new;
end;$$;
create trigger corporate_document_guard before delete on private.corporate_documents
 for each row execute function private.corporate_document_guard();

revoke all on function private.corporate_file_guard(), private.corporate_revision_guard(), private.corporate_document_guard() from public, anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('corporate-library', 'corporate-library', false, 20971520, array[
 'application/pdf',
 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
 'application/vnd.openxmlformats-officedocument.wordprocessingml.template'])
on conflict (id) do nothing;
