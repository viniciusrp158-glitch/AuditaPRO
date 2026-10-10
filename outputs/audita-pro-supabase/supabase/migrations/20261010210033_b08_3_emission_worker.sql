-- B08 Parte 3/3: comandos do processador de emissão (somente service_role, chamados pela Edge Function document-emission).
-- claim: posse exclusiva com prazo (lease); complete: compare-and-set pela posse e pelo caminho da tentativa; fail: erro saneado.
create function private.b08_worker(command text, payload jsonb) returns jsonb
 language plpgsql security definer set search_path = '' as $$
#variable_conflict use_variable
declare e private.document_emissions; tok uuid; att int; planned text; actor uuid := (payload->>'triggered_by')::uuid;
 now_ts timestamptz := clock_timestamp(); h text; err text;
begin
 select * into e from private.document_emissions where id = (payload->>'emission_id')::uuid for update;
 if e.id is null then raise exception 'Pedido de emissão não encontrado'; end if;

 if command = 'claim' then
  if e.status in ('ready', 'published') then return jsonb_build_object('state', 'done', 'emission', private.b08_json(e)); end if;
  if e.status = 'processing' and e.lease_expires_at > now_ts then return jsonb_build_object('state', 'busy', 'emission', private.b08_json(e)); end if;
  if e.attempt_count >= e.max_attempts then return jsonb_build_object('state', 'exhausted', 'emission', private.b08_json(e)); end if;
  h := encode(sha256(convert_to(e.content::text, 'UTF8')), 'hex');
  if h <> e.content_sha256 then
   update private.document_emissions set status = 'failed', last_error = 'Conteúdo congelado não confere com o hash registrado' where id = e.id returning * into e;
   return jsonb_build_object('state', 'integrity_error', 'emission', private.b08_json(e));
  end if;
  -- Posse anterior expirada: a tentativa fica registrada como perdida.
  if e.status = 'processing' then
   update private.document_emission_attempts set finished_at = now_ts, outcome = 'lease_lost', error = 'Prazo de processamento expirado'
    where emission_id = e.id and attempt_number = e.attempt_count and outcome is null;
  end if;
  tok := gen_random_uuid(); att := e.attempt_count + 1;
  planned := coalesce(e.organization_id::text, 'sistema') || '/' || e.document_kind || '/' || e.id || '/tentativa-' || att || '-' || left(tok::text, 8) || '.pdf';
  update private.document_emissions set status = 'processing', attempt_count = att, lease_token = tok,
    lease_expires_at = now_ts + make_interval(secs => least(greatest(coalesce((payload->>'lease_seconds')::int, 180), 30), 600)),
    started_at = coalesce(started_at, now_ts), last_error = null
   where id = e.id returning * into e;
  insert into private.document_emission_attempts (emission_id, attempt_number, lease_token, triggered_by, storage_path)
  values (e.id, att, tok, actor, planned);
  return jsonb_build_object('state', 'claimed', 'lease_token', tok, 'attempt', att, 'storage_bucket', 'document-emissions', 'storage_path', planned,
    'kind', e.document_kind, 'template_key', e.template_key, 'template_version', e.template_version, 'content', e.content,
    'content_sha256', e.content_sha256, 'title', e.title, 'revision_label', e.revision_label, 'filename', e.filename,
    'version_id', e.version_id, 'requested_at', e.requested_at);
 end if;

 tok := (payload->>'lease_token')::uuid;
 select attempt_number, storage_path into att, planned from private.document_emission_attempts where emission_id = e.id and lease_token = tok;
 if att is null then raise exception 'Tentativa desconhecida'; end if;

 if command = 'complete' then
  if e.status <> 'processing' or e.lease_token is distinct from tok then
   update private.document_emission_attempts set finished_at = now_ts, outcome = 'lease_lost', error = 'Posse perdida antes da confirmação',
     pdf_sha256 = payload->>'pdf_sha256', size_bytes = (payload->>'size_bytes')::bigint
    where emission_id = e.id and attempt_number = att and outcome is null;
   return jsonb_build_object('accepted', false, 'reason', 'lease_lost', 'emission', private.b08_json(e));
  end if;
  if payload->>'storage_path' is distinct from planned then raise exception 'Caminho do arquivo diferente do reservado para a tentativa'; end if;
  if coalesce(payload->>'pdf_sha256', '') !~ '^[0-9a-f]{64}$' or coalesce((payload->>'size_bytes')::bigint, 0) <= 0
     or coalesce((payload->>'page_count')::int, 0) <= 0 or coalesce(payload->>'verified_sha256', '') <> payload->>'pdf_sha256' then
   raise exception 'Integridade do arquivo não comprovada'; end if;
  update private.document_emission_attempts set finished_at = now_ts, outcome = 'ready', pdf_sha256 = payload->>'pdf_sha256',
    size_bytes = (payload->>'size_bytes')::bigint, metrics = payload->'metrics'
   where emission_id = e.id and attempt_number = att;
  update private.document_emissions set status = 'ready', storage_bucket = 'document-emissions', storage_path = planned,
    pdf_sha256 = payload->>'pdf_sha256', size_bytes = (payload->>'size_bytes')::bigint, page_count = (payload->>'page_count')::int,
    engine_version = payload->>'engine_version', asset_manifest = coalesce(payload->'asset_manifest', '[]'::jsonb), metrics = payload->'metrics',
    completed_at = now_ts, lease_token = null, lease_expires_at = null, last_error = null
   where id = e.id returning * into e;
  insert into public.audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata)
  values (e.organization_id, actor, 'document_emitted', 'document_emissions', e.id,
    jsonb_build_object('kind', e.document_kind, 'version_id', e.version_id, 'pdf_sha256', e.pdf_sha256, 'pages', e.page_count, 'attempt', att));
  if e.auto_publish then e := private.b08_publish(e.id, coalesce(actor, e.requested_by)); end if;
  return jsonb_build_object('accepted', true, 'emission', private.b08_json(e));

 elsif command = 'fail' then
  err := left(regexp_replace(coalesce(payload->>'error', 'Falha não informada'), '\s+', ' ', 'g'), 500);
  update private.document_emission_attempts set finished_at = now_ts, outcome = 'failed', error = err, metrics = payload->'metrics'
   where emission_id = e.id and attempt_number = att and outcome is null;
  if e.status = 'processing' and e.lease_token = tok then
   update private.document_emissions set status = 'failed', last_error = err, lease_token = null, lease_expires_at = null
    where id = e.id returning * into e;
   insert into public.audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata)
   values (e.organization_id, actor, 'document_emission_failed', 'document_emissions', e.id, jsonb_build_object('attempt', att, 'error', err));
  end if;
  return jsonb_build_object('accepted', true, 'emission', private.b08_json(e));
 end if;
 raise exception 'Comando desconhecido';
end;$$;

create function public.document_emission_worker(command text, payload jsonb) returns jsonb
 language sql set search_path = '' as $$ select private.b08_worker(command, payload); $$;
revoke all on function private.b08_worker(text, jsonb) from public, anon, authenticated;
grant execute on function private.b08_worker(text, jsonb) to service_role;
revoke all on function public.document_emission_worker(text, jsonb) from public, anon, authenticated;
grant execute on function public.document_emission_worker(text, jsonb) to service_role;
