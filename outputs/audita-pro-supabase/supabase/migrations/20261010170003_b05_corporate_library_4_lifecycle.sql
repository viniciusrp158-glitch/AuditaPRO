-- PENDENTE DE APLICAÇÃO na produção (aguarda aprovação do proprietário no conector: contém DELETE de arquivo de rascunho).
-- B05 Parte 4/4: gestão do Administrador — arquivos, publicação, cancelamento e arquivamento. Aditiva.
create function private.corporate_library_lifecycle(command text, payload jsonb) returns jsonb
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
 -- Chamado somente por private.corporate_library_manage; revalida o Administrador (defesa em profundidade).
 if not is_admin or not private.is_active_account(actor) then
  raise exception 'Ação restrita ao Administrador' using errcode = '42501';
 end if;
 payload := coalesce(payload, '{}'::jsonb);

 if command = 'authorize_upload' then
  fmt := payload->>'format';
  select * into r from private.corporate_document_revisions where id = (payload->>'revision_id')::uuid;
  if r.id is null or r.status <> 'draft' then raise exception 'Arquivos só podem ser incluídos em revisão em rascunho'; end if;
  if fmt not in ('pdf','docx','dotx') then raise exception 'Formato não permitido. Use PDF, DOCX ou DOTX'; end if;
  if exists (select 1 from private.corporate_document_files x where x.revision_id = r.id and x.format = fmt) then
   raise exception 'Esta revisão já possui arquivo %; remova-o antes de enviar outro', upper(fmt);
  end if;
  return jsonb_build_object('bucket', 'corporate-library',
   'path', r.document_id || '/' || r.id || '/' || gen_random_uuid() || '.' || fmt, 'revision_id', r.id);
 end if;

 if command = 'register_file' then
  fmt := payload->>'format'; path := payload->>'path';
  select * into r from private.corporate_document_revisions where id = (payload->>'revision_id')::uuid for update;
  if r.id is null or r.status <> 'draft' then raise exception 'Revisão indisponível para inclusão de arquivo'; end if;
  if path is null or path not like r.document_id || '/' || r.id || '/%.' || fmt then raise exception 'Caminho de arquivo inválido'; end if;
  -- Integridade: o objeto precisa existir no Storage com o tamanho declarado antes do registro (PC-06).
  select (o.metadata->>'size')::bigint into obj_size from storage.objects o where o.bucket_id = 'corporate-library' and o.name = path;
  if obj_size is null or obj_size <> (payload->>'size_bytes')::bigint then
   raise exception 'Envio incompleto: arquivo não confirmado no armazenamento';
  end if;
  insert into private.corporate_document_files (revision_id, format, storage_path, filename, size_bytes, sha256, mime_type, uploaded_by)
  values (r.id, fmt, path, left(payload->>'filename', 200), obj_size, lower(payload->>'sha256'), payload->>'mime_type', actor)
  returning * into f;
  perform private.corporate_log('corporate_file_added', r.document_id, r.id,
   jsonb_build_object('format', fmt, 'filename', f.filename, 'size_bytes', f.size_bytes, 'sha256', f.sha256));
  return jsonb_build_object('file_id', f.id, 'revision', private.corporate_revision_json(r.id));
 end if;

 if command = 'remove_file' then
  select * into f from private.corporate_document_files where id = (payload->>'file_id')::uuid;
  select * into r from private.corporate_document_revisions where id = f.revision_id for update;
  if f.id is null or r.status <> 'draft' then raise exception 'Somente arquivos de revisão em rascunho podem ser removidos'; end if;
  delete from private.corporate_document_files where id = f.id;
  perform private.corporate_log('corporate_file_removed', r.document_id, r.id, jsonb_build_object('format', f.format, 'filename', f.filename));
  return jsonb_build_object('bucket', 'corporate-library', 'path', f.storage_path, 'revision', private.corporate_revision_json(r.id));
 end if;

 if command = 'publish' then
  select * into r from private.corporate_document_revisions where id = (payload->>'revision_id')::uuid;
  if r.id is null then raise exception 'Revisão não encontrada'; end if;
  select * into d from private.corporate_documents where id = r.document_id for update;
  select * into r from private.corporate_document_revisions where id = r.id for update;
  if r.status <> 'draft' then raise exception 'Somente revisão em rascunho pode ser disponibilizada'; end if;
  if d.archived_at is not null then raise exception 'Documento arquivado não pode receber revisão vigente'; end if;
  if not exists (select 1 from private.corporate_document_files x where x.revision_id = r.id) then
   raise exception 'A revisão precisa de ao menos um arquivo íntegro';
  end if;
  if r.responsible is null or r.issued_on is null then
   raise exception 'Informe responsável e data de emissão antes de disponibilizar como vigente';
  end if;
  update private.corporate_document_revisions set status = 'superseded', superseded_at = clock_timestamp(), superseded_by_revision = r.id
   where document_id = d.id and status = 'current';
  update private.corporate_document_revisions set status = 'current', published_at = clock_timestamp(), published_by = actor
   where id = r.id;
  update private.corporate_documents set updated_at = clock_timestamp(), updated_by = actor, lock_version = lock_version + 1 where id = d.id;
  perform private.corporate_log('corporate_revision_published', d.id, r.id, jsonb_build_object('revision_label', r.revision_label,
   'responsible', r.responsible, 'issued_on', r.issued_on));
  return private.corporate_revision_json(r.id);
 end if;

 if command = 'cancel_revision' then
  select * into r from private.corporate_document_revisions where id = (payload->>'revision_id')::uuid for update;
  if r.id is null or r.status <> 'draft' then raise exception 'Somente rascunhos podem ser cancelados'; end if;
  update private.corporate_document_revisions set status = 'cancelled', cancelled_at = clock_timestamp(), cancelled_by = actor,
   cancel_reason = nullif(btrim(coalesce(payload->>'reason','')), '') where id = r.id;
  perform private.corporate_log('corporate_revision_cancelled', r.document_id, r.id, jsonb_build_object('reason', payload->>'reason'));
  return private.corporate_revision_json(r.id);
 end if;

 if command in ('archive', 'restore') then
  select * into d from private.corporate_documents where id = (payload->>'document_id')::uuid for update;
  if d.id is null then raise exception 'Documento não encontrado'; end if;
  if command = 'archive' then
   if d.archived_at is not null then return jsonb_build_object('document_id', d.id, 'status', 'arquivado'); end if;
   if nullif(btrim(coalesce(payload->>'reason','')), '') is null then raise exception 'Informe o motivo do arquivamento'; end if;
   update private.corporate_documents set archived_at = clock_timestamp(), archived_by = actor, archive_reason = btrim(payload->>'reason'),
    updated_at = clock_timestamp(), updated_by = actor, lock_version = lock_version + 1 where id = d.id;
  else
   update private.corporate_documents set archived_at = null, archived_by = null, archive_reason = null,
    updated_at = clock_timestamp(), updated_by = actor, lock_version = lock_version + 1 where id = d.id;
  end if;
  perform private.corporate_log(case when command = 'archive' then 'corporate_document_archived' else 'corporate_document_restored' end,
   d.id, null, jsonb_build_object('reason', payload->>'reason'));
  select * into d from private.corporate_documents where id = d.id;
  return jsonb_build_object('document_id', d.id, 'status', private.corporate_status_label(d), 'lock_version', d.lock_version);
 end if;

 raise exception 'Comando desconhecido';
end;$$;

revoke all on function private.corporate_library_lifecycle(text, jsonb) from public, anon, authenticated;
