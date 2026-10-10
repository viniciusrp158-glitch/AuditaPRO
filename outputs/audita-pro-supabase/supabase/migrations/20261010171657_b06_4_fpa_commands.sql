-- B06 Parte 4/4: comandos da FPA. Leitura: condutor/Admin e equipe interna; escrita: condutor/Admin (D04 com autoria real).
create function private.b06_fpa_json(aid uuid) returns jsonb language sql stable security definer set search_path = '' as $$
 select jsonb_build_object(
  'status', coalesce(f.status, 'not_requested'), 'lock_version', coalesce(f.lock_version, 0),
  'recipient_name', f.recipient_name, 'recipient_contact', f.recipient_contact, 'due_date', f.due_date,
  'requested_at', f.requested_at, 'requested_by', (select full_name from public.user_profiles where user_id = f.requested_by),
  'complement_questions', f.complement_questions, 'complement_due_date', f.complement_due_date,
  'analysis_note', f.analysis_note, 'analyzed_at', f.analyzed_at, 'analyzed_by', (select full_name from public.user_profiles where user_id = f.analyzed_by),
  'sufficient_version_id', f.sufficient_version_id,
  'versions', coalesce((select jsonb_agg(jsonb_build_object('id', v.id, 'version_number', v.version_number, 'format', v.format,
     'filename', v.filename, 'size_bytes', v.size_bytes, 'sha256', v.sha256, 'received_on', v.received_on, 'source_note', v.source_note,
     'registered_at', v.registered_at, 'registered_by', (select full_name from public.user_profiles where user_id = v.registered_by)) order by v.version_number desc)
    from private.audit_fpa_versions v where v.audit_id = aid), '[]'::jsonb),
  'events', coalesce((select jsonb_agg(jsonb_build_object('action', e.action, 'from', e.from_status, 'to', e.to_status, 'at', e.occurred_at,
     'actor', (select full_name from public.user_profiles where user_id = e.actor), 'details', e.details) order by e.occurred_at desc, e.id desc)
    from private.audit_fpa_events e where e.audit_id = aid), '[]'::jsonb))
 from (select 1) one left join private.audit_fpa f on f.audit_id = aid;
$$;

create function private.b06_fpa(command text, payload jsonb default '{}'::jsonb) returns jsonb
 language plpgsql security definer set search_path = '' as $$
#variable_conflict use_variable
declare actor uuid := auth.uid(); aid uuid; a public.audits%rowtype; f private.audit_fpa%rowtype; v private.audit_fpa_versions%rowtype;
 nxt text; fmt text; path text; obj_size bigint; num int;
begin
 if actor is null or not private.is_active_account(actor) then raise exception 'Sessão ativa necessária' using errcode = '42501'; end if;
 aid := (payload->>'audit_id')::uuid;
 select * into a from public.audits where id = aid;
 if a.id is null or not (private.workspace_conductor(aid) or private.checklist_internal(aid)) then
  raise exception 'FPA indisponível para este acesso' using errcode = '42501'; end if;
 if command = 'detail' then
  return private.b06_fpa_json(aid) || jsonb_build_object('can_edit', private.workspace_conductor(aid) and a.status in ('draft','planned','in_progress'));
 end if;
 if command = 'download' then
  select * into v from private.audit_fpa_versions where id = (payload->>'version_id')::uuid and audit_id = aid;
  if v.id is null then raise exception 'Versão de FPA não encontrada' using errcode = '42501'; end if;
  return jsonb_build_object('bucket', 'audit-fpa', 'path', v.storage_path, 'filename', v.filename, 'mime_type', v.mime_type, 'sha256', v.sha256);
 end if;
 if not private.workspace_conductor(aid) then raise exception 'Somente o condutor ou o Administrador altera a FPA' using errcode = '42501'; end if;
 if a.status not in ('draft','planned','in_progress') then raise exception 'Auditoria encerrada ou cancelada: FPA somente para consulta'; end if;
 insert into private.audit_fpa (audit_id) values (aid) on conflict (audit_id) do nothing;
 select * into f from private.audit_fpa where audit_id = aid for update;
 if command <> 'authorize_upload' and f.lock_version <> coalesce((payload->>'expected_lock_version')::int, -1) then
  raise exception 'FPA alterada em outra sessão. Recarregue antes de continuar' using errcode = '40001'; end if;

 if command = 'request' then
  if f.status not in ('not_requested','requested') then raise exception 'FPA já recebida: use complementação ou nova versão'; end if;
  if length(btrim(coalesce(payload->>'recipient_name',''))) < 2 then raise exception 'Informe o destinatário da solicitação'; end if;
  update private.audit_fpa set status = 'requested', recipient_name = btrim(payload->>'recipient_name'),
   recipient_contact = nullif(btrim(payload->>'recipient_contact'),''), due_date = nullif(payload->>'due_date','')::date,
   requested_at = clock_timestamp(), requested_by = actor where audit_id = aid;
  nxt := 'requested';
 elsif command = 'authorize_upload' then
  fmt := payload->>'format';
  if f.status = 'not_requested' then raise exception 'Registre a solicitação da FPA antes do recebimento'; end if;
  if fmt not in ('pdf','docx','xlsx') then raise exception 'Formato não permitido. Use PDF, DOCX ou XLSX'; end if;
  return jsonb_build_object('bucket', 'audit-fpa', 'path', aid || '/' || gen_random_uuid() || '.' || fmt);
 elsif command = 'register_file' then
  fmt := payload->>'format'; path := payload->>'path';
  if f.status = 'not_requested' then raise exception 'Registre a solicitação da FPA antes do recebimento'; end if;
  if path is null or path not like aid || '/%.' || fmt then raise exception 'Caminho de arquivo inválido'; end if;
  select (o.metadata->>'size')::bigint into obj_size from storage.objects o where o.bucket_id = 'audit-fpa' and o.name = path;
  if obj_size is null or obj_size <> (payload->>'size_bytes')::bigint then raise exception 'Envio incompleto: arquivo não confirmado no armazenamento'; end if;
  if nullif(payload->>'received_on','') is null or (payload->>'received_on')::date > current_date then raise exception 'Informe a data de recebimento (não futura)'; end if;
  select coalesce(max(version_number), 0) + 1 into num from private.audit_fpa_versions where audit_id = aid;
  insert into private.audit_fpa_versions (audit_id, version_number, format, storage_path, filename, size_bytes, sha256, mime_type, received_on, source_note, registered_by)
  values (aid, num, fmt, path, left(payload->>'filename', 200), obj_size, lower(payload->>'sha256'), payload->>'mime_type',
   (payload->>'received_on')::date, nullif(btrim(payload->>'source_note'),''), actor) returning * into v;
  -- Nova versão exige nova análise; a análise anterior permanece no histórico.
  update private.audit_fpa set status = 'received', analysis_note = null, analyzed_at = null, analyzed_by = null, sufficient_version_id = null where audit_id = aid;
  nxt := 'received';
 elsif command = 'start_analysis' then
  if f.status <> 'received' then raise exception 'A análise começa após o recebimento'; end if;
  update private.audit_fpa set status = 'in_analysis' where audit_id = aid; nxt := 'in_analysis';
 elsif command = 'request_complement' then
  if f.status <> 'in_analysis' then raise exception 'Complementação é solicitada durante a análise'; end if;
  if length(btrim(coalesce(payload->>'questions',''))) < 3 then raise exception 'Descreva as informações pendentes'; end if;
  update private.audit_fpa set status = 'complement_requested', complement_questions = btrim(payload->>'questions'),
   complement_due_date = nullif(payload->>'due_date','')::date where audit_id = aid;
  nxt := 'complement_requested';
 elsif command = 'mark_sufficient' then
  if f.status <> 'in_analysis' then raise exception 'Somente FPA em análise pode ser considerada suficiente'; end if;
  select * into v from private.audit_fpa_versions where audit_id = aid order by version_number desc limit 1;
  if v.id is null or v.id <> (payload->>'version_id')::uuid then raise exception 'Analise a versão mais recente da FPA'; end if;
  update private.audit_fpa set status = 'sufficient', sufficient_version_id = v.id, analysis_note = nullif(btrim(payload->>'note'),''),
   analyzed_at = clock_timestamp(), analyzed_by = actor where audit_id = aid;
  nxt := 'sufficient';
 else
  raise exception 'Comando desconhecido';
 end if;
 update private.audit_fpa set lock_version = lock_version + 1, updated_at = clock_timestamp() where audit_id = aid;
 insert into private.audit_fpa_events (audit_id, action, from_status, to_status, version_id, actor, details)
 values (aid, command, f.status, nxt, v.id, actor, payload - 'audit_id' - 'expected_lock_version' - 'path' - 'sha256');
 insert into public.audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata)
 values (a.organization_id, actor, 'b06_fpa_' || command, 'audit_fpa', aid, jsonb_build_object('from', f.status, 'to', nxt, 'version_id', v.id));
 return private.b06_fpa_json(aid) || jsonb_build_object('can_edit', true);
exception when invalid_text_representation or check_violation or datetime_field_overflow or invalid_datetime_format then
 raise exception 'Dados da FPA inválidos: %', sqlerrm;
end;$$;

revoke all on function private.b06_fpa(text, jsonb), private.b06_fpa_json(uuid) from public, anon, authenticated;
grant execute on function private.b06_fpa(text, jsonb) to authenticated;
create function public.audit_fpa(command text, payload jsonb default '{}'::jsonb) returns jsonb
 language sql set search_path = '' as $$ select private.b06_fpa(command, payload); $$;
revoke all on function public.audit_fpa(text, jsonb) from public, anon;
grant execute on function public.audit_fpa(text, jsonb) to authenticated;
