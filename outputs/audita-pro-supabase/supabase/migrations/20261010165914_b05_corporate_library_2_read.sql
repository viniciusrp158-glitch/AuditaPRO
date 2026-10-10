-- B05 Parte 2/3: histórico, projeções e comandos de leitura (context/list/download). Aditiva.
-- Registro no histórico do sistema (public.audit_events, leitura restrita ao Administrador).
create function private.corporate_log(action text, doc uuid, rev uuid, details jsonb default '{}'::jsonb) returns void
 language sql security definer set search_path = '' as $$
 insert into public.audit_events (actor_user_id, event_type, entity_type, entity_id, metadata)
 values (auth.uid(), action, 'corporate_documents', doc,
  jsonb_build_object('revision_id', rev, 'source', 'corporate_library') || coalesce(details, '{}'::jsonb));
$$;

create function private.corporate_status_label(doc private.corporate_documents) returns text
 language sql stable security definer set search_path = '' as $$
 select case
  when doc.archived_at is not null then 'arquivado'
  when exists (select 1 from private.corporate_document_revisions r where r.document_id = doc.id and r.status = 'current') then 'vigente'
  when exists (select 1 from private.corporate_document_revisions r where r.document_id = doc.id and r.status = 'draft') then 'rascunho'
  else 'cancelado' end;
$$;

create function private.corporate_revision_json(rev uuid) returns jsonb
 language sql stable security definer set search_path = '' as $$
 select jsonb_build_object('id', r.id, 'revision_label', r.revision_label, 'status', r.status,
  'responsible', r.responsible, 'issued_on', r.issued_on, 'change_summary', r.change_summary,
  'published_at', r.published_at, 'superseded_at', r.superseded_at, 'cancelled_at', r.cancelled_at,
  'created_at', r.created_at,
  'files', coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'format', f.format, 'filename', f.filename,
     'size_bytes', f.size_bytes, 'sha256', f.sha256, 'uploaded_at', f.uploaded_at) order by f.format)
   from private.corporate_document_files f where f.revision_id = r.id), '[]'::jsonb))
 from private.corporate_document_revisions r where r.id = rev;
$$;

create function private.corporate_library(command text, payload jsonb default '{}'::jsonb) returns jsonb
 language plpgsql security definer set search_path = '' as $$
#variable_conflict use_variable
declare
 actor uuid := auth.uid();
 is_admin boolean := private.profile_admin(auth.uid());
 can_read boolean := private.b02_corporate_access(false);
 d private.corporate_documents%rowtype;
 r private.corporate_document_revisions%rowtype;
 f private.corporate_document_files%rowtype;
 op uuid; prior jsonb; result jsonb;
 search text; ftype text; fstatus text; pg int; psize int; total int;
 obj_size bigint; fmt text; path text;
begin
 if not private.is_active_account(actor) then
  raise exception 'Sessão ativa necessária' using errcode = '42501';
 end if;
 payload := coalesce(payload, '{}'::jsonb);

 if command = 'context' then
  return jsonb_build_object('can_read', can_read, 'can_manage', is_admin, 'can_history', is_admin,
   'formats', jsonb_build_array('pdf','docx','dotx'), 'max_bytes', 20971520,
   'types', jsonb_build_array('procedimento','modelo','formulario','instrucao','politica','registro','outro'));
 end if;

 if not can_read then
  raise exception 'Biblioteca corporativa indisponível para este perfil' using errcode = '42501';
 end if;

 if command = 'list' then
  search := nullif(btrim(left(coalesce(payload->>'search',''), 100)), '');
  ftype := nullif(payload->>'doc_type', '');
  fstatus := nullif(payload->>'status', '');
  pg := greatest(0, least(coalesce((payload->>'page')::int, 0), 10000));
  psize := greatest(1, least(coalesce((payload->>'page_size')::int, 20), 50));
  if not is_admin and fstatus is not null and fstatus <> 'vigente' then fstatus := 'vigente'; end if;
  with base as (
   select doc.*, private.corporate_status_label(doc) as status_label
   from private.corporate_documents doc
   where (search is null or doc.title ilike '%' || search || '%' or coalesce(doc.code, '') ilike '%' || search || '%')
     and (ftype is null or doc.doc_type = ftype)
  ), visible as (
   select * from base b where (is_admin or b.status_label = 'vigente')
    and (fstatus is null or b.status_label = fstatus)
  )
  select coalesce(jsonb_agg(item order by sort_title, sort_id), '[]'::jsonb)
  into result
  from (
   select lower(v.title) sort_title, v.id sort_id, jsonb_build_object(
    'id', v.id, 'title', v.title, 'doc_type', v.doc_type, 'code', v.code, 'description', v.description,
    'status', v.status_label, 'updated_at', v.updated_at, 'lock_version', case when is_admin then v.lock_version end,
    'current', (select private.corporate_revision_json(cr.id) from private.corporate_document_revisions cr where cr.document_id = v.id and cr.status = 'current'),
    'draft', case when is_admin then (select private.corporate_revision_json(dr.id) from private.corporate_document_revisions dr where dr.document_id = v.id and dr.status = 'draft') end
   ) item
   from visible v order by lower(v.title), v.id limit psize offset pg * psize
  ) page_rows;
  select count(*)::int into total from (
   select 1 from private.corporate_documents doc
   where (search is null or doc.title ilike '%' || search || '%' or coalesce(doc.code, '') ilike '%' || search || '%')
     and (ftype is null or doc.doc_type = ftype)
     and (is_admin or private.corporate_status_label(doc) = 'vigente')
     and (fstatus is null or private.corporate_status_label(doc) = fstatus)) c;
  return jsonb_build_object('items', result, 'total', total, 'page', pg, 'page_size', psize, 'as_of', now());
 end if;

 if command = 'download' then
  select * into f from private.corporate_document_files where id = (payload->>'file_id')::uuid;
  select * into r from private.corporate_document_revisions where id = f.revision_id;
  select * into d from private.corporate_documents where id = r.document_id;
  if f.id is null or (not is_admin and (r.status <> 'current' or d.archived_at is not null)) then
   raise exception 'Arquivo indisponível' using errcode = '42501';
  end if;
  return jsonb_build_object('bucket', 'corporate-library', 'path', f.storage_path, 'filename', f.filename,
   'mime_type', f.mime_type, 'sha256', f.sha256, 'size_bytes', f.size_bytes);
 end if;

 -- Daqui em diante: somente Administrador (RS-08, PC-04), inclusive por acesso direto.
 if not is_admin then
  raise exception 'Ação restrita ao Administrador' using errcode = '42501';
 end if;
 return private.corporate_library_manage(command, payload);
end;$$;

revoke all on function private.corporate_library(text, jsonb), private.corporate_log(text, uuid, uuid, jsonb),
 private.corporate_status_label(private.corporate_documents), private.corporate_revision_json(uuid) from public, anon, authenticated;
grant execute on function private.corporate_library(text, jsonb) to authenticated;

create function public.corporate_library(command text, payload jsonb default '{}'::jsonb) returns jsonb
 language sql set search_path = '' as $$ select private.corporate_library(command, payload); $$;
revoke all on function public.corporate_library(text, jsonb) from public, anon;
grant execute on function public.corporate_library(text, jsonb) to authenticated;
