-- B05 Parte 3/4: gestão do Administrador — cadastro, identificação e revisões. Aditiva.
create function private.corporate_library_manage(command text, payload jsonb) returns jsonb
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
 -- Chamado somente por private.corporate_library; revalida o Administrador (defesa em profundidade).
 if not is_admin or not private.is_active_account(actor) then
  raise exception 'Ação restrita ao Administrador' using errcode = '42501';
 end if;
 payload := coalesce(payload, '{}'::jsonb);

 if command = 'detail' then
  select * into d from private.corporate_documents where id = (payload->>'document_id')::uuid;
  if d.id is null then raise exception 'Documento não encontrado'; end if;
  return jsonb_build_object('document', to_jsonb(d) || jsonb_build_object('status', private.corporate_status_label(d)),
   'revisions', coalesce((select jsonb_agg(private.corporate_revision_json(x.id) order by x.created_at desc)
     from private.corporate_document_revisions x where x.document_id = d.id), '[]'::jsonb),
   'events', coalesce((select jsonb_agg(jsonb_build_object('event_type', e.event_type, 'occurred_at', e.occurred_at,
     'actor', (select u.full_name from public.user_profiles u where u.user_id = e.actor_user_id), 'metadata', e.metadata) order by e.occurred_at desc)
     from public.audit_events e where e.entity_type = 'corporate_documents' and e.entity_id = d.id), '[]'::jsonb));
 end if;

 if command in ('create', 'new_revision') then
  op := (payload->>'operation_id')::uuid;
  if op is null then raise exception 'operation_id obrigatório'; end if;
  select response into prior from private.corporate_library_operations o where o.operation_id = op and o.actor = actor and o.command = command;
  if prior is not null then return prior; end if;
  if command = 'create' then
   if nullif(btrim(coalesce(payload->>'code','')), '') is not null and exists (select 1 from private.corporate_documents x
      where upper(btrim(x.code)) = upper(btrim(payload->>'code'))) then
    raise exception 'Código já utilizado por outro documento; códigos não são reutilizados';
   end if;
   insert into private.corporate_documents (title, doc_type, code, description, created_by, updated_by)
   values (btrim(payload->>'title'), payload->>'doc_type', nullif(btrim(coalesce(payload->>'code','')), ''),
    nullif(btrim(coalesce(payload->>'description','')), ''), actor, actor)
   returning * into d;
  else
   select * into d from private.corporate_documents where id = (payload->>'document_id')::uuid for update;
   if d.id is null then raise exception 'Documento não encontrado'; end if;
   if d.archived_at is not null then raise exception 'Documento arquivado: restaure antes de incluir revisão'; end if;
   if exists (select 1 from private.corporate_document_revisions x where x.document_id = d.id and x.status = 'draft') then
    raise exception 'Já existe uma revisão em rascunho para este documento';
   end if;
  end if;
  insert into private.corporate_document_revisions (document_id, revision_label, responsible, issued_on, change_summary, created_by)
  values (d.id, btrim(coalesce(payload->>'revision_label', '')), nullif(btrim(coalesce(payload->>'responsible','')), ''),
   nullif(payload->>'issued_on', '')::date, nullif(btrim(coalesce(payload->>'change_summary','')), ''), actor)
  returning * into r;
  perform private.corporate_log(case when command = 'create' then 'corporate_document_created' else 'corporate_revision_created' end,
   d.id, r.id, jsonb_build_object('title', d.title, 'code', d.code, 'revision_label', r.revision_label));
  result := jsonb_build_object('document_id', d.id, 'revision_id', r.id);
  insert into private.corporate_library_operations (operation_id, actor, command, response) values (op, actor, command, result);
  return result;
 end if;

 if command = 'update' then
  select * into d from private.corporate_documents where id = (payload->>'document_id')::uuid for update;
  if d.id is null then raise exception 'Documento não encontrado'; end if;
  if d.lock_version is distinct from (payload->>'expected_lock_version')::int then
   raise exception 'Documento alterado por outra sessão; atualize antes de salvar' using errcode = '40001';
  end if;
  if nullif(btrim(coalesce(payload->>'code','')), '') is not null and exists (select 1 from private.corporate_documents x
     where x.id <> d.id and upper(btrim(x.code)) = upper(btrim(payload->>'code'))) then
   raise exception 'Código já utilizado por outro documento; códigos não são reutilizados';
  end if;
  if nullif(btrim(coalesce(payload->>'code','')), '') is distinct from d.code and exists (
     select 1 from private.corporate_document_revisions x where x.document_id = d.id and x.status in ('current','superseded')) then
   raise exception 'Código de documento já emitido não pode ser alterado';
  end if;
  update private.corporate_documents set title = btrim(payload->>'title'), doc_type = payload->>'doc_type',
   code = nullif(btrim(coalesce(payload->>'code','')), ''), description = nullif(btrim(coalesce(payload->>'description','')), ''),
   updated_by = actor, updated_at = clock_timestamp(), lock_version = lock_version + 1
  where id = d.id;
  perform private.corporate_log('corporate_document_updated', d.id, null, jsonb_build_object('changed_fields',
   (select coalesce(jsonb_agg(k), '[]'::jsonb) from (values ('title', d.title is distinct from btrim(payload->>'title')),
     ('doc_type', d.doc_type is distinct from payload->>'doc_type'),
     ('code', d.code is distinct from nullif(btrim(coalesce(payload->>'code','')), '')),
     ('description', d.description is distinct from nullif(btrim(coalesce(payload->>'description','')), ''))) t(k, changed) where changed)));
  return jsonb_build_object('document_id', d.id, 'lock_version', d.lock_version + 1);
 end if;

 if command = 'update_revision' then
  select * into r from private.corporate_document_revisions where id = (payload->>'revision_id')::uuid for update;
  if r.id is null or r.status <> 'draft' then raise exception 'Somente revisões em rascunho podem ser editadas'; end if;
  update private.corporate_document_revisions set revision_label = btrim(coalesce(payload->>'revision_label', r.revision_label)),
   responsible = nullif(btrim(coalesce(payload->>'responsible','')), ''), issued_on = nullif(payload->>'issued_on', '')::date,
   change_summary = nullif(btrim(coalesce(payload->>'change_summary','')), '')
  where id = r.id;
  perform private.corporate_log('corporate_revision_updated', r.document_id, r.id, '{}'::jsonb);
  return private.corporate_revision_json(r.id);
 end if;

 return private.corporate_library_lifecycle(command, payload);
end;$$;

revoke all on function private.corporate_library_manage(text, jsonb) from public, anon, authenticated;
