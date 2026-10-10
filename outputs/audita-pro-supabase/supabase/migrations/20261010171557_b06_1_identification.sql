-- B06 Parte 1/4: cabeçalho do Plano de Auditoria (PA-03/04/05/06). Aditiva.
-- Baseada na proposta do Codex (docs/b06/propostas/identificacao-v1.sql), com correções registradas em docs/plano-adaptacoes.md.
alter table public.audits
 add column if not exists evaluation_type text,
 add column if not exists evaluation_other text,
 add column if not exists declared_start_date date,
 add column if not exists declared_end_date date,
 add column if not exists participants_text text,
 add column if not exists comments text;
alter table public.audits
 add constraint audits_declared_period_check check (declared_start_date is null or declared_end_date is null or declared_end_date >= declared_start_date),
 add constraint audits_evaluation_type_check check (evaluation_type is null or evaluation_type in
  ('initial','certification','maintenance','recertification','follow_up','diagnostic','other')),
 add constraint audits_header_text_limits check (coalesce(length(participants_text),0) <= 5000 and coalesce(length(comments),0) <= 10000
  and coalesce(length(evaluation_other),0) <= 300);

create function private.b06_identification_json(a public.audits) returns jsonb
 language sql stable security definer set search_path = '' as $$
 select jsonb_build_object('audit_id', a.id, 'code', a.code, 'status', a.status, 'lock_version', a.lock_version,
  'plan_revision', a.plan_revision, 'unit_id', a.unit_id, 'title', a.title, 'objective', a.objective, 'scope', a.scope,
  'criterion_ids', to_jsonb(a.criterion_ids), 'standards', to_jsonb(a.standards), 'purpose', a.purpose, 'party', a.party,
  'modality', a.modality, 'location', a.location, 'criteria', a.criteria, 'evaluation_type', a.evaluation_type,
  'evaluation_other', a.evaluation_other, 'declared_start_date', a.declared_start_date, 'declared_end_date', a.declared_end_date,
  'participants_text', a.participants_text, 'comments', a.comments,
  'client', (select jsonb_build_object('id', o.id, 'code', o.code, 'name', o.legal_name, 'trade_name', o.trade_name, 'cnpj', o.cnpj, 'address', o.address)
    from public.organizations o where o.id = a.organization_id),
  'unit', (select jsonb_build_object('id', u.id, 'name', u.name, 'location', u.location) from public.organization_units u where u.id = a.unit_id),
  'criteria_items', coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'code', t.code, 'name', t.name, 'edition', t.edition) order by t.code, t.edition)
    from public.audit_types t where t.id = any(a.criterion_ids)), '[]'::jsonb),
  'team', coalesce((select jsonb_agg(jsonb_build_object('membership_id', ap.membership_id, 'name', p.full_name, 'role', ap.participant_type,
     'conductor', ap.membership_id = a.leader_membership_id) order by ap.membership_id <> a.leader_membership_id, p.full_name)
    from public.audit_participants ap join public.organization_memberships m on m.id = ap.membership_id
    join public.user_profiles p on p.user_id = m.user_id where ap.audit_id = a.id and ap.active and ap.participant_type in ('leader','auditor')), '[]'::jsonb),
  'units', coalesce((select jsonb_agg(jsonb_build_object('id', u.id, 'name', u.name, 'location', u.location) order by u.name)
    from public.organization_units u where u.organization_id = a.organization_id and u.status = 'active'), '[]'::jsonb),
  'criteria_locked', exists (select 1 from public.audit_checklists c where c.audit_id = a.id) or exists (select 1 from public.requirement_assessments r where r.audit_id = a.id));
$$;

create function private.b06_identification(command text, payload jsonb default '{}'::jsonb) returns jsonb
 language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); aid uuid; a public.audits%rowtype; unit uuid; crit uuid[]; before jsonb;
begin
 if actor is null or not private.is_active_account(actor) then raise exception 'Sessão ativa necessária' using errcode = '42501'; end if;
 if command = 'capabilities' then return jsonb_build_object('contract_version', 1, 'commands', jsonb_build_array('detail','save','create_draft')); end if;
 if command = 'create_draft' then return private.b06_create_draft(payload); end if;
 aid := nullif(payload->>'audit_id', '')::uuid;
 select * into a from public.audits where id = aid;
 -- Leitura: condutor/Admin e equipe interna (Líder/Auditor da auditoria). Participante usa a projeção publicada (B09).
 if a.id is null or not (private.workspace_conductor(aid) or private.checklist_internal(aid)) then
  raise exception 'Identificação indisponível' using errcode = '42501';
 end if;
 if command = 'detail' then
  return jsonb_build_object('contract_version', 1, 'can_edit', private.workspace_conductor(aid) and a.status in ('draft','planned','in_progress'),
   'identification', private.b06_identification_json(a));
 end if;
 if command <> 'save' then raise exception 'Comando não reconhecido'; end if;
 select * into a from public.audits where id = aid for update;
 if not private.workspace_conductor(aid) then raise exception 'Somente o condutor ou o Administrador edita a identificação' using errcode = '42501'; end if;
 -- Rascunho e revisão em elaboração são editáveis; a versão publicada fica congelada em audit_plan_versions (B09).
 if a.status not in ('draft','planned','in_progress') then raise exception 'Auditoria encerrada ou cancelada: identificação somente para consulta'; end if;
 if a.lock_version <> coalesce((payload->>'expected_lock_version')::int, -1) then
  raise exception 'Identificação alterada em outra sessão. Recarregue antes de salvar' using errcode = '40001';
 end if;
 if length(btrim(coalesce(payload->>'title',''))) < 2 then raise exception 'Título obrigatório'; end if;
 if coalesce(payload->>'party','first') not in ('first','second','third') then raise exception 'Natureza inválida'; end if;
 if coalesce(payload->>'modality','presential') not in ('presential','remote','hybrid') then raise exception 'Modalidade inválida'; end if;
 unit := nullif(payload->>'unit_id','')::uuid;
 if unit is not null and not exists (select 1 from public.organization_units where id = unit and organization_id = a.organization_id and status = 'active') then
  raise exception 'Unidade fora da empresa'; end if;
 if jsonb_typeof(coalesce(payload->'criterion_ids','[]'::jsonb)) <> 'array' then raise exception 'Critérios inválidos'; end if;
 crit := array(select v::uuid from jsonb_array_elements_text(coalesce(payload->'criterion_ids','[]'::jsonb)) with ordinality x(v, n) group by v order by min(n));
 if cardinality(crit) = 0 then crit := a.criterion_ids; end if;
 if exists (select 1 from unnest(crit) c where not exists (select 1 from public.audit_types t where t.id = c and (t.active or c = any(a.criterion_ids)))) then
  raise exception 'Selecione critérios ativos'; end if;
 if crit is distinct from a.criterion_ids and (exists (select 1 from public.audit_checklists where audit_id = aid)
    or exists (select 1 from public.requirement_assessments where audit_id = aid)) then
  raise exception 'Critérios já aplicados ao checklist exigem revisão de escopo própria'; end if;
 before := private.b06_identification_json(a);
 update public.audits set unit_id = unit, title = btrim(payload->>'title'),
  objective = nullif(btrim(payload->>'objective'),''), scope = nullif(btrim(payload->>'scope'),''),
  criterion_ids = crit, type_id = coalesce(crit[1], type_id),
  standards = case when crit is distinct from a.criterion_ids then array(select t.code || case when nullif(t.edition,'') is null then '' else ':' || t.edition end
   from public.audit_types t where t.id = any(crit) order by t.code, t.edition) else standards end,
  purpose = coalesce(nullif(btrim(payload->>'purpose'),''), purpose), party = coalesce(payload->>'party', party),
  modality = coalesce(payload->>'modality', modality), location = nullif(btrim(payload->>'location'),''),
  criteria = nullif(btrim(payload->>'criteria'),''), evaluation_type = nullif(btrim(payload->>'evaluation_type'),''),
  evaluation_other = nullif(btrim(payload->>'evaluation_other'),''),
  declared_start_date = nullif(payload->>'declared_start_date','')::date, declared_end_date = nullif(payload->>'declared_end_date','')::date,
  participants_text = nullif(btrim(payload->>'participants_text'),''), comments = nullif(btrim(payload->>'comments'),''),
  lock_version = lock_version + 1, updated_at = clock_timestamp()
 where id = aid returning * into a;
 insert into public.audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata)
 values (a.organization_id, actor, 'b06_identification_saved', 'audits', aid, jsonb_build_object('contract_version', 1,
  'lock_version', a.lock_version, 'old_values', before - 'team' - 'units' - 'client', 'new_values', private.b06_identification_json(a) - 'team' - 'units' - 'client'));
 return jsonb_build_object('contract_version', 1, 'audit_id', aid, 'lock_version', a.lock_version);
exception when invalid_text_representation or check_violation or not_null_violation or datetime_field_overflow or invalid_datetime_format then
 raise exception 'Identificação inválida: %', sqlerrm;
end;$$;

revoke all on function private.b06_identification(text, jsonb), private.b06_identification_json(public.audits) from public, anon, authenticated;
grant execute on function private.b06_identification(text, jsonb) to authenticated;
create function public.audit_identification(command text, payload jsonb default '{}'::jsonb) returns jsonb
 language sql set search_path = '' as $$ select private.b06_identification(command, payload); $$;
revoke all on function public.audit_identification(text, jsonb) from public, anon;
grant execute on function public.audit_identification(text, jsonb) to authenticated;
