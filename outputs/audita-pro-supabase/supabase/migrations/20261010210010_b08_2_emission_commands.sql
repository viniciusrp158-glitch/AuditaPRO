-- B08 Parte 2/3: comandos de emissão. Produtores (B09/B11) chamam private.b08_request/b08_publish na própria transação;
-- o navegador usa public.document_emission; a Edge Function usa public.document_emission_worker (somente service_role).
create function private.b08_can_operate(e private.document_emissions, actor uuid) returns boolean
 language sql stable security definer set search_path = '' as $$
 select case when e.document_kind = 'specimen' then private.profile_admin(actor)
   else e.audit_id is not null and private.workspace_conductor(e.audit_id) end;
$$;
create function private.b08_can_view(e private.document_emissions, actor uuid) returns boolean
 language sql stable security definer set search_path = '' as $$
 select private.b08_can_operate(e, actor) or (e.document_kind <> 'specimen' and e.audit_id is not null and private.checklist_internal(e.audit_id));
$$;

create function private.b08_json(e private.document_emissions) returns jsonb language sql stable set search_path = '' as $$
 select jsonb_build_object('id', e.id, 'kind', e.document_kind, 'audit_id', e.audit_id, 'document_id', e.document_id, 'version_id', e.version_id,
  'revision_label', e.revision_label, 'title', e.title, 'filename', e.filename, 'status', e.status, 'attempt_count', e.attempt_count,
  'max_attempts', e.max_attempts, 'last_error', e.last_error, 'pdf_sha256', e.pdf_sha256, 'size_bytes', e.size_bytes, 'page_count', e.page_count,
  'template', e.template_key || ' v' || e.template_version, 'engine_version', e.engine_version, 'requested_at', e.requested_at,
  'completed_at', e.completed_at, 'published_at', e.published_at, 'metrics', e.metrics,
  'processing', e.status = 'processing' and e.lease_expires_at > clock_timestamp());
$$;

-- Produtor: cria ou reaproveita o pedido da revisão. Mesmo conteúdo → mesmo pedido; conteúdo diferente → conflito.
create function private.b08_request(p_kind text, p_document_id uuid, p_version_id uuid, p_org uuid, p_audit uuid, p_revision text,
  p_title text, p_filename text, p_template text, p_template_version int, p_content jsonb, p_auto_publish boolean, p_actor uuid,
  p_operation uuid default null) returns private.document_emissions
 language plpgsql security definer set search_path = '' as $$
declare e private.document_emissions; h text := encode(sha256(convert_to(p_content::text, 'UTF8')), 'hex');
begin
 insert into private.document_emissions (organization_id, audit_id, document_kind, document_id, version_id, revision_label, title, filename,
   template_key, template_version, content, content_sha256, auto_publish, requested_by, request_operation_id)
 values (p_org, p_audit, p_kind, p_document_id, p_version_id, p_revision, p_title, p_filename, p_template, p_template_version, p_content, h,
   p_auto_publish, p_actor, p_operation)
 on conflict (document_kind, version_id) do nothing returning * into e;
 if e.id is null then
  select * into e from private.document_emissions where document_kind = p_kind and version_id = p_version_id;
  if e.content_sha256 <> h or e.template_key <> p_template or e.template_version <> p_template_version then
   raise exception 'Esta revisão já possui pedido de emissão com outro conteúdo; gere nova revisão' using errcode = '23505'; end if;
  return e;
 end if;
 insert into public.audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata)
 values (p_org, p_actor, 'document_emission_requested', 'document_emissions', e.id,
   jsonb_build_object('kind', p_kind, 'version_id', p_version_id, 'revision', p_revision, 'content_sha256', h));
 return e;
end;$$;

-- Ponto de extensão dos produtores (B09/B11/B12 substituem com create or replace).
create function private.b08_after_publish(e private.document_emissions) returns void language plpgsql security definer set search_path = '' as $$
begin return; end;$$;

create function private.b08_publish(p_emission uuid, p_actor uuid) returns private.document_emissions
 language plpgsql security definer set search_path = '' as $$
declare e private.document_emissions;
begin
 select * into e from private.document_emissions where id = p_emission for update;
 if e.id is null then raise exception 'Pedido de emissão não encontrado'; end if;
 if e.status = 'published' then return e; end if;
 if e.status <> 'ready' then raise exception 'Documento ainda sem arquivo íntegro; publicação indisponível'; end if;
 update private.document_emissions set status = 'published', published_at = clock_timestamp(), published_by = p_actor where id = e.id returning * into e;
 insert into public.audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata)
 values (e.organization_id, p_actor, 'document_published', 'document_emissions', e.id, jsonb_build_object('kind', e.document_kind, 'version_id', e.version_id, 'pdf_sha256', e.pdf_sha256));
 perform private.b08_after_publish(e);
 return e;
end;$$;

create function private.b08_command(command text, payload jsonb) returns jsonb
 language plpgsql security definer set search_path = '' as $$
#variable_conflict use_variable
declare actor uuid := auth.uid(); e private.document_emissions; op uuid; params jsonb; n int;
begin
 if actor is null or not private.is_active_account(actor) then raise exception 'Sessão ativa necessária' using errcode = '42501'; end if;
 if command = 'request_specimen' then
  if not private.profile_admin(actor) then raise exception 'Somente o Administrador emite o documento de prova' using errcode = '42501'; end if;
  op := (payload->>'operation_id')::uuid;
  if op is null then raise exception 'operation_id obrigatório'; end if;
  select * into e from private.document_emissions where requested_by = actor and request_operation_id = op;
  if e.id is null then
   params := jsonb_build_object('rows', least(greatest(coalesce((payload->'params'->>'rows')::int, 120), 0), 2000),
     'long_cell', coalesce((payload->'params'->>'long_cell')::boolean, true), 'photos', coalesce((payload->'params'->>'photos')::boolean, true),
     'draft', coalesce((payload->'params'->>'draft')::boolean, false));
   select count(*) + 1 into n from private.document_emissions where document_kind = 'specimen';
   op := gen_random_uuid();
   e := private.b08_request('specimen', op, op, null, null, 'Rev.00', 'Documento de prova do emissor ' || lpad(n::text, 3, '0'),
     'prova-emissor-' || lpad(n::text, 3, '0') || '.pdf', 'specimen', 1,
     jsonb_build_object('params', params, 'code', 'PROVA-' || lpad(n::text, 3, '0'), 'issued_at', clock_timestamp()), true, actor, (payload->>'operation_id')::uuid);
  end if;
  return private.b08_json(e);
 elsif command = 'list' then
  if payload ? 'audit_id' and payload->>'audit_id' is not null then
   if not (private.workspace_conductor((payload->>'audit_id')::uuid) or private.checklist_internal((payload->>'audit_id')::uuid)) then
    raise exception 'Documentos indisponíveis para este acesso' using errcode = '42501'; end if;
   return coalesce((select jsonb_agg(private.b08_json(x) order by x.requested_at desc) from private.document_emissions x
     where x.audit_id = (payload->>'audit_id')::uuid), '[]'::jsonb);
  end if;
  if not private.profile_admin(actor) then raise exception 'Documentos indisponíveis para este acesso' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(private.b08_json(x) order by x.requested_at desc) from
    (select * from private.document_emissions where document_kind = 'specimen' order by requested_at desc limit 50) x), '[]'::jsonb);
 end if;
 select * into e from private.document_emissions where id = (payload->>'emission_id')::uuid;
 if e.id is null or not private.b08_can_view(e, actor) then raise exception 'Documento não encontrado' using errcode = '42501'; end if;
 if command = 'status' then
  return private.b08_json(e) || jsonb_build_object('can_operate', private.b08_can_operate(e, actor));
 elsif command = 'retry' then
  if not private.b08_can_operate(e, actor) then raise exception 'Somente o condutor ou o Administrador retoma a emissão' using errcode = '42501'; end if;
  if e.status = 'failed' and e.attempt_count >= e.max_attempts then
   update private.document_emissions set max_attempts = attempt_count + 3 where id = e.id returning * into e;
  end if;
  return private.b08_json(e);
 elsif command = 'authorize_download' then
  -- Arquivo pronto e ainda não publicado: só o operador (prévia de conferência). Publicado: leitores autorizados.
  if not (e.status = 'published' or (e.status = 'ready' and private.b08_can_operate(e, actor))) then
   raise exception 'Arquivo ainda não disponível' using errcode = 'P0002'; end if;
  insert into public.audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata)
  values (e.organization_id, actor, 'document_downloaded', 'document_emissions', e.id, jsonb_build_object('pdf_sha256', e.pdf_sha256));
  return jsonb_build_object('bucket', e.storage_bucket, 'path', e.storage_path, 'filename', e.filename, 'sha256', e.pdf_sha256, 'size_bytes', e.size_bytes);
 end if;
 raise exception 'Comando desconhecido';
end;$$;

create function public.document_emission(command text, payload jsonb default '{}'::jsonb) returns jsonb
 language sql set search_path = '' as $$ select private.b08_command(command, payload); $$;

revoke all on function private.b08_can_operate(private.document_emissions, uuid), private.b08_can_view(private.document_emissions, uuid),
 private.b08_json(private.document_emissions), private.b08_request(text, uuid, uuid, uuid, uuid, text, text, text, text, int, jsonb, boolean, uuid, uuid),
 private.b08_after_publish(private.document_emissions), private.b08_publish(uuid, uuid), private.b08_command(text, jsonb) from public, anon, authenticated;
grant execute on function private.b08_command(text, jsonb) to authenticated;
revoke all on function public.document_emission(text, jsonb) from public, anon;
grant execute on function public.document_emission(text, jsonb) to authenticated;
