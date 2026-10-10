-- B09 Parte 7c (correção): lista de revisões e comandos do Plano sobre private.plan_revisions; rótulo Rev.NN conta as publicações.
create or replace function private.b09_versions_json(aid uuid, internal boolean) returns jsonb language sql stable security definer set search_path = '' as $$
 select coalesce(jsonb_agg(t.x order by t.sort_at desc), '[]') from (
  select jsonb_build_object('id', r.id, 'version_number', r.revision_number, 'revision_label', r.revision_label, 'state', r.state, 'reason', r.reason,
    'created_at', r.created_at, 'published_at', r.published_at,
    'author', (select coalesce(nullif(btrim(p.full_name), ''), 'Usuário') from public.user_profiles p where p.user_id = r.created_by),
    'emission_id', r.emission_id, 'emission', (select private.b08_json(e) from private.document_emissions e where e.id = r.emission_id),
    'discarded_reason', r.discarded_reason) x, r.created_at sort_at
  from private.plan_revisions r where r.audit_id = aid and (internal or r.state in ('published', 'superseded'))
  union all
  select jsonb_build_object('id', v.id, 'version_number', v.version_number, 'revision_label', 'Versão ' || v.version_number, 'state', 'legacy', 'reason', v.reason,
    'created_at', v.created_at, 'published_at', v.created_at,
    'author', (select coalesce(nullif(btrim(p.full_name), ''), 'Usuário') from public.user_profiles p where p.user_id = v.created_by),
    'emission_id', null, 'emission', null, 'discarded_reason', null), v.created_at
  from public.audit_plan_versions v where v.audit_id = aid and not exists (select 1 from private.plan_revisions r where r.plan_version_id = v.id)) t;
$$;

create or replace function private.b09_command(command text, payload jsonb) returns jsonb
 language plpgsql security definer set search_path = '' as $$
#variable_conflict use_variable
declare actor uuid := auth.uid(); aid uuid := (payload->>'audit_id')::uuid; a public.audits%rowtype; ck jsonb; op uuid; prior jsonb;
 published int; label text; reason text; snap jsonb; vid uuid; e private.document_emissions; v private.plan_revisions%rowtype; result jsonb;
 internal boolean; fname text;
begin
 if actor is null or not private.is_active_account(actor) then raise exception 'Sessão ativa necessária' using errcode = '42501'; end if;
 if command in ('discard', 'publish_ready') then
  select * into v from private.plan_revisions where id = (payload->>'version_id')::uuid; aid := v.audit_id;
 end if;
 select * into a from public.audits where id = aid;
 if a.id is null then raise exception 'Auditoria não encontrada' using errcode = '42501'; end if;
 internal := private.workspace_conductor(aid) or private.checklist_internal(aid);
 select count(*) into published from public.audit_plan_versions x where x.audit_id = aid; -- uma linha por publicação (legado ou B09)

 if command = 'versions' then
  if not (internal or (a.plan_revision > 0 and private.workspace_member(a.organization_id))) then raise exception 'Plano indisponível para este acesso' using errcode = '42501'; end if;
  return jsonb_build_object('versions', private.b09_versions_json(aid, internal), 'plan_revision', a.plan_revision);
 end if;
 if not internal then raise exception 'Plano indisponível para este acesso' using errcode = '42501'; end if;
 if command = 'status' then
  ck := private.b09_checks(aid, null);
  return jsonb_build_object('checks', ck->'checks', 'warnings', ck->'warnings', 'ok', ck->'ok', 'lock_version', a.lock_version,
   'status', a.status, 'plan_revision', a.plan_revision, 'next_label', 'Rev.' || lpad(published::text, 2, '0'), 'requires_reason', published > 0,
   'can_validate', private.workspace_conductor(aid) and a.status in ('draft', 'planned', 'in_progress'),
   'open', (select jsonb_build_object('version_id', x.id, 'revision_label', x.revision_label, 'emission', private.b08_json(em))
     from private.plan_revisions x left join private.document_emissions em on em.id = x.emission_id where x.audit_id = aid and x.state = 'validated'),
   'versions', private.b09_versions_json(aid, true));
 elsif command = 'preview' then
  ck := private.b09_checks(aid, null);
  return private.b09_snapshot(aid, ck->'items', 'Prévia', 'Prévia sem validade', actor) || jsonb_build_object('preview', true, 'ok', ck->'ok');
 end if;

 if not private.workspace_conductor(aid) then raise exception 'Somente o condutor ou o Administrador valida o plano' using errcode = '42501'; end if;
 if a.status not in ('draft', 'planned', 'in_progress') then raise exception 'Auditoria encerrada ou cancelada: plano somente para consulta'; end if;

 if command = 'validate' then
  op := (payload->>'operation_id')::uuid;
  if op is null then raise exception 'operation_id obrigatório'; end if;
  select o.response into prior from private.b06_operations o where o.operation_id = op and o.actor = actor and o.command = 'b09_validate';
  if prior is not null then return prior; end if;
  select * into a from public.audits where id = aid for update;
  if exists (select 1 from private.plan_revisions x where x.audit_id = aid and x.state = 'validated') then
   raise exception 'Há uma revisão validada aguardando o PDF. Acompanhe, tente novamente ou descarte antes de validar outra'; end if;
  ck := private.b09_checks(aid, coalesce((payload->>'expected_lock_version')::int, -1));
  if not (ck->>'ok')::boolean then
   raise exception 'Validação bloqueada: % verificação(ões) pendente(s). Corrija-as pelos atalhos da lista',
    (select count(*) from jsonb_array_elements(ck->'checks') c where not (c->>'ok')::boolean) using errcode = 'P0001'; end if;
  label := 'Rev.' || lpad(published::text, 2, '0');
  reason := nullif(btrim(payload->>'reason'), '');
  if published > 0 and (reason is null or length(reason) < 5) then raise exception 'Informe o motivo da nova revisão (mínimo 5 caracteres)'; end if;
  reason := coalesce(reason, 'Emissão inicial do plano');
  snap := private.b09_snapshot(aid, ck->'items', label, reason, actor);
  insert into private.plan_revisions (audit_id, revision_number, content, reason, created_by, revision_label, state, content_sha256, template_version, operation_id)
  values (aid, (select coalesce(max(revision_number), 0) + 1 from private.plan_revisions where audit_id = aid), snap, reason, actor, label, 'validated',
    encode(sha256(convert_to(snap::text, 'UTF8')), 'hex'), 1, op) returning id into vid;
  fname := regexp_replace(coalesce(a.code, 'AUDITORIA'), '[^A-Za-z0-9._-]', '-', 'g') || '_Plano_' || replace(label, '.', '') || '.pdf';
  e := private.b08_request('plan', aid, vid, a.organization_id, aid, label, 'Plano de Auditoria ' || coalesce(a.code, '') || ' ' || label, fname,
    'plan', 1, snap, true, actor, null);
  update private.plan_revisions set emission_id = e.id where id = vid;
  update public.audits set lock_version = lock_version + 1, updated_at = clock_timestamp() where id = aid returning * into a;
  insert into public.audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata)
  values (a.organization_id, actor, 'plan_validated', 'plan_revisions', vid, jsonb_build_object('audit_id', aid, 'revision', label, 'reason', reason, 'emission_id', e.id));
  perform private.b08_dispatch('process', e.id);
  result := jsonb_build_object('version_id', vid, 'revision_label', label, 'lock_version', a.lock_version, 'emission', private.b08_json(e));
  insert into private.b06_operations (operation_id, actor, command, response) values (op, actor, 'b09_validate', result);
  return result;
 end if;

 if v.id is null or v.state is distinct from 'validated' then raise exception 'Revisão não está aguardando publicação'; end if;
 select * into e from private.document_emissions where id = v.emission_id;
 if command = 'discard' then
  if e.status in ('pending', 'processing') then raise exception 'PDF em geração: aguarde o resultado antes de descartar'; end if;
  if e.status = 'published' then raise exception 'Revisão já publicada'; end if;
  if length(coalesce(btrim(payload->>'reason'), '')) < 5 then raise exception 'Informe o motivo do descarte'; end if;
  update private.plan_revisions set state = 'discarded', discarded_reason = btrim(payload->>'reason') where id = v.id;
  update public.audits set lock_version = lock_version + 1 where id = aid;
  insert into public.audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata)
  values (a.organization_id, actor, 'plan_revision_discarded', 'plan_revisions', v.id, jsonb_build_object('revision', v.revision_label, 'reason', btrim(payload->>'reason')));
  return jsonb_build_object('discarded', true);
 elsif command = 'publish_ready' then
  if e.status <> 'ready' then raise exception 'O PDF desta revisão ainda não está pronto'; end if;
  e := private.b08_publish(e.id, actor);
  return jsonb_build_object('published', e.status = 'published', 'blocked', case when e.status <> 'published' then e.last_error end, 'emission', private.b08_json(e));
 end if;
 raise exception 'Comando desconhecido';
end;$$;
