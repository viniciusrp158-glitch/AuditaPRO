-- B09 Parte 6d: publicação condicionada, sem bloco que engula erros. Antes de publicar um Plano, verifica-se (sem efeitos)
-- se a revisão ainda pode ser aplicada ao cronograma executável; se não puder (ex.: dia encerrado entre a validação e o PDF),
-- o arquivo íntegro fica "pronto" com o motivo, nada é publicado e não há novas tentativas automáticas.
create function private.b09_apply_blocker(e private.document_emissions) returns text
 language plpgsql stable security definer set search_path = '' as $$
declare v public.audit_plan_versions%rowtype; r jsonb; prev public.schedule_items%rowtype; dstat text; dayid uuid; reqs jsonb; t text;
begin
 select * into v from public.audit_plan_versions where id = e.version_id;
 if v.id is null or v.state is distinct from 'validated' then return 'Revisão do plano não está aguardando publicação'; end if;
 for r in select value from jsonb_array_elements(v.content->'schedule') loop
  dayid := null; dstat := null;
  select id, status into dayid, dstat from public.audit_days where audit_id = v.audit_id and audit_date = (r->>'date')::date;
  reqs := coalesce(r->'requirements', '[]'::jsonb); prev := null;
  if nullif(r->>'id', '') is not null then
   select s.* into prev from public.schedule_items s join public.audit_days d on d.id = s.audit_day_id where s.id = (r->>'id')::uuid and d.audit_id = v.audit_id;
  end if;
  if prev.id is not null and prev.status = 'completed' and (prev.title is distinct from r->>'title' or prev.audit_day_id is distinct from dayid
     or exists (select 1 from public.schedule_requirements sr where sr.schedule_item_id = prev.id and not reqs ? sr.requirement_id::text)
     or exists (select 1 from jsonb_array_elements_text(reqs) q where not exists (select 1 from public.schedule_requirements sr where sr.schedule_item_id = prev.id and sr.requirement_id = q::uuid))) then
   return 'Atividade concluída preserva descrição, data e requisitos: ' || prev.title; end if;
  if dstat = 'completed' and (prev.id is null or prev.audit_day_id is distinct from dayid) then
   return 'Dia ' || to_char((r->>'date')::date, 'DD/MM') || ' encerrado não recebe novas atividades'; end if;
  if prev.id is not null and prev.status <> 'planned' and exists (select 1 from public.schedule_requirements sr where sr.schedule_item_id = prev.id and not reqs ? sr.requirement_id::text) then
   return 'Atividade iniciada não perde requisitos: ' || prev.title; end if;
 end loop;
 select s.title into t from public.schedule_items s join public.audit_days d on d.id = s.audit_day_id
  where d.audit_id = v.audit_id and not s.withdrawn and s.status in ('in_progress', 'completed')
    and not exists (select 1 from jsonb_array_elements(v.content->'schedule') x where x->>'id' = s.id::text) limit 1;
 if t is not null then return 'Atividade iniciada não pode ser retirada do plano: ' || t; end if;
 return null;
end;$$;

create or replace function private.b08_publish(p_emission uuid, p_actor uuid) returns private.document_emissions
 language plpgsql security definer set search_path = '' as $$
declare e private.document_emissions; blocked text;
begin
 select * into e from private.document_emissions where id = p_emission for update;
 if e.id is null then raise exception 'Pedido de emissão não encontrado'; end if;
 if e.status = 'published' then return e; end if;
 if e.status <> 'ready' then raise exception 'Documento ainda sem arquivo íntegro; publicação indisponível'; end if;
 blocked := case when e.document_kind = 'plan' then private.b09_apply_blocker(e) end;
 if blocked is not null then
  update private.document_emissions set last_error = left('Arquivo íntegro; publicação bloqueada: ' || blocked, 500) where id = e.id returning * into e;
  insert into public.audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata)
  values (e.organization_id, p_actor, 'document_publication_blocked', 'document_emissions', e.id, jsonb_build_object('reason', blocked));
  return e;
 end if;
 update private.document_emissions set status = 'published', published_at = clock_timestamp(), published_by = p_actor, last_error = null where id = e.id returning * into e;
 insert into public.audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata)
 values (e.organization_id, p_actor, 'document_published', 'document_emissions', e.id, jsonb_build_object('kind', e.document_kind, 'version_id', e.version_id, 'pdf_sha256', e.pdf_sha256));
 perform private.b08_after_publish(e);
 return e;
end;$$;

create or replace function private.b09_command(command text, payload jsonb) returns jsonb
 language plpgsql security definer set search_path = '' as $$
#variable_conflict use_variable
declare actor uuid := auth.uid(); aid uuid := (payload->>'audit_id')::uuid; a public.audits%rowtype; ck jsonb; op uuid; prior jsonb;
 published int; label text; reason text; snap jsonb; vid uuid; e private.document_emissions; v public.audit_plan_versions%rowtype; result jsonb;
 internal boolean; fname text;
begin
 if actor is null or not private.is_active_account(actor) then raise exception 'Sessão ativa necessária' using errcode = '42501'; end if;
 if command in ('discard', 'publish_ready') then
  select * into v from public.audit_plan_versions where id = (payload->>'version_id')::uuid; aid := v.audit_id;
 end if;
 select * into a from public.audits where id = aid;
 if a.id is null then raise exception 'Auditoria não encontrada' using errcode = '42501'; end if;
 internal := private.workspace_conductor(aid) or private.checklist_internal(aid);
 select count(*) into published from public.audit_plan_versions x where x.audit_id = aid and (x.state is null or x.state in ('published', 'superseded'));

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
     from public.audit_plan_versions x left join private.document_emissions em on em.id = x.emission_id where x.audit_id = aid and x.state = 'validated'),
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
  if exists (select 1 from public.audit_plan_versions x where x.audit_id = aid and x.state = 'validated') then
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
  insert into public.audit_plan_versions (audit_id, version_number, content, reason, created_by, revision_label, state, content_sha256, template_version, operation_id)
  values (aid, (select coalesce(max(version_number), 0) + 1 from public.audit_plan_versions where audit_id = aid), snap, reason, actor, label, 'validated',
    encode(sha256(convert_to(snap::text, 'UTF8')), 'hex'), 1, op) returning id into vid;
  fname := regexp_replace(coalesce(a.code, 'AUDITORIA'), '[^A-Za-z0-9._-]', '-', 'g') || '_Plano_' || replace(label, '.', '') || '.pdf';
  e := private.b08_request('plan', aid, vid, a.organization_id, aid, label, 'Plano de Auditoria ' || coalesce(a.code, '') || ' ' || label, fname,
    'plan', 1, snap, true, actor, null);
  update public.audit_plan_versions set emission_id = e.id where id = vid;
  update public.audits set lock_version = lock_version + 1, updated_at = clock_timestamp() where id = aid returning * into a;
  insert into public.audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata)
  values (a.organization_id, actor, 'plan_validated', 'audit_plan_versions', vid, jsonb_build_object('audit_id', aid, 'revision', label, 'reason', reason, 'emission_id', e.id));
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
  update public.audit_plan_versions set state = 'discarded', discarded_reason = btrim(payload->>'reason') where id = v.id;
  update public.audits set lock_version = lock_version + 1 where id = aid;
  insert into public.audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata)
  values (a.organization_id, actor, 'plan_revision_discarded', 'audit_plan_versions', v.id, jsonb_build_object('revision', v.revision_label, 'reason', btrim(payload->>'reason')));
  return jsonb_build_object('discarded', true);
 elsif command = 'publish_ready' then
  if e.status <> 'ready' then raise exception 'O PDF desta revisão ainda não está pronto'; end if;
  e := private.b08_publish(e.id, actor);
  return jsonb_build_object('published', e.status = 'published', 'blocked', case when e.status <> 'published' then e.last_error end, 'emission', private.b08_json(e));
 end if;
 raise exception 'Comando desconhecido';
end;$$;

revoke all on function private.b09_apply_blocker(private.document_emissions) from public, anon, authenticated;
