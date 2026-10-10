-- B06 / Identificação v1 — PROPOSTA NÃO EXECUTÁVEL AUTOMATICAMENTE.
-- Depende de aprovação do contrato e conversão posterior em migration oficial.
-- Deliberadamente aditiva: não redefine workspace_command/workspace_detail (B02)
-- nem funções de métricas/projeção (B03).

begin;

alter table public.audits
  add column if not exists evaluation_type text,
  add column if not exists declared_start_date date,
  add column if not exists declared_end_date date,
  add column if not exists participants_text text,
  add column if not exists comments text,
  add column if not exists evaluation_other text;

alter table public.audits
  drop constraint if exists audits_declared_period_check,
  add constraint audits_declared_period_check check (
    declared_start_date is null
    or declared_end_date is null
    or declared_end_date >= declared_start_date
  );

alter table public.audits
  drop constraint if exists audits_evaluation_type_check,
  add constraint audits_evaluation_type_check check (
    evaluation_type is null or evaluation_type in (
      'initial', 'certification', 'maintenance', 'recertification',
      'follow_up', 'diagnostic', 'other'
    )
  );

create or replace function private.b06_identification(command text, payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  aid uuid;
  current_audit public.audits%rowtype;
  requested_unit uuid;
  requested_criteria uuid[];
  before_identification jsonb;
begin
  if actor is null or not private.is_active_account(actor) then
    raise exception 'Sessão ativa necessária' using errcode = '42501';
  end if;

  if command = 'capabilities' then
    return jsonb_build_object(
      'contract_version', 1,
      'commands', jsonb_build_array('detail', 'save'),
      'fields', jsonb_build_array(
        'unit_id', 'title', 'objective', 'scope', 'criterion_ids', 'purpose',
        'party', 'modality', 'location', 'criteria', 'evaluation_type',
        'evaluation_other', 'declared_start_date', 'declared_end_date',
        'participants_text', 'comments'
      )
    );
  end if;

  begin
    aid := nullif(payload ->> 'audit_id', '')::uuid;
  exception when invalid_text_representation then
    raise exception 'Auditoria inválida';
  end;
  if aid is null then raise exception 'Auditoria obrigatória'; end if;

  select * into current_audit from public.audits where id = aid;
  if current_audit.id is null
     or current_audit.workspace_version = 0
     or not private.workspace_conductor(aid) then
    raise exception 'Identificação indisponível' using errcode = '42501';
  end if;

  if command = 'detail' then
    return jsonb_build_object(
      'contract_version', 1,
      'identification', jsonb_build_object(
        'audit_id', current_audit.id,
        'lock_version', current_audit.lock_version,
        'unit_id', current_audit.unit_id,
        'title', current_audit.title,
        'objective', current_audit.objective,
        'scope', current_audit.scope,
        'criterion_ids', to_jsonb(current_audit.criterion_ids),
        'purpose', current_audit.purpose,
        'party', current_audit.party,
        'modality', current_audit.modality,
        'location', current_audit.location,
        'criteria', current_audit.criteria,
        'evaluation_type', current_audit.evaluation_type,
        'evaluation_other', current_audit.evaluation_other,
        'declared_start_date', current_audit.declared_start_date,
        'declared_end_date', current_audit.declared_end_date,
        'participants_text', current_audit.participants_text,
        'comments', current_audit.comments
      )
    );
  end if;

  if command <> 'save' then raise exception 'Comando não reconhecido'; end if;
  select * into current_audit from public.audits where id = aid for update;
  if current_audit.id is null or not private.workspace_conductor(aid) then
    raise exception 'Identificação indisponível' using errcode = '42501';
  end if;
  if current_audit.status <> 'draft' or current_audit.plan_revision <> 0 then
    raise exception 'Cabeçalho publicado exige fluxo de revisão do plano';
  end if;
  if current_audit.lock_version <> coalesce((payload ->> 'expected_lock_version')::integer, -1) then
    raise exception 'Identificação alterada em outra sessão. Recarregue antes de salvar';
  end if;
  if length(trim(coalesce(payload ->> 'title', ''))) < 2 then
    raise exception 'Título obrigatório';
  end if;
  if payload ->> 'party' is not null and payload ->> 'party' not in ('first', 'second', 'third') then raise exception 'Parte inválida'; end if;
  if payload ->> 'modality' is not null and payload ->> 'modality' not in ('presential', 'remote', 'hybrid') then raise exception 'Modalidade inválida'; end if;
  if nullif(trim(payload ->> 'evaluation_type'), '') is not null and payload ->> 'evaluation_type' not in
    ('initial', 'certification', 'maintenance', 'recertification', 'follow_up', 'diagnostic', 'other') then
    raise exception 'Tipo de avaliação inválido';
  end if;
  if length(coalesce(payload ->> 'participants_text', '')) > 5000
     or length(coalesce(payload ->> 'comments', '')) > 10000 then
    raise exception 'Texto acima do limite';
  end if;

  requested_unit := nullif(payload ->> 'unit_id', '')::uuid;
  if requested_unit is not null and not exists (
    select 1 from public.organization_units
    where id = requested_unit and organization_id = current_audit.organization_id and status = 'active'
  ) then raise exception 'Unidade fora da empresa'; end if;

  if jsonb_typeof(coalesce(payload -> 'criterion_ids', '[]'::jsonb)) <> 'array' then
    raise exception 'Critérios inválidos';
  end if;
  requested_criteria := array(
    select value::uuid
    from jsonb_array_elements_text(coalesce(payload -> 'criterion_ids', '[]'::jsonb))
      with ordinality requested(value, position)
    group by value
    order by min(position)
  );
  if cardinality(requested_criteria) = 0 or exists (
    select 1 from unnest(requested_criteria) criterion_id
    where not exists (
      select 1 from public.audit_types
      where id = criterion_id and (active or criterion_id = any(current_audit.criterion_ids))
    )
  ) then raise exception 'Selecione critérios ativos'; end if;
  if requested_criteria is distinct from current_audit.criterion_ids and (
    exists (select 1 from public.audit_checklists where audit_id = aid)
    or exists (select 1 from public.requirement_assessments where audit_id = aid)
  ) then
    raise exception 'Critérios já aplicados exigem revisão de escopo própria';
  end if;

  before_identification := jsonb_build_object(
    'unit_id', current_audit.unit_id, 'title', current_audit.title,
    'objective', current_audit.objective, 'scope', current_audit.scope,
    'criterion_ids', current_audit.criterion_ids, 'purpose', current_audit.purpose,
    'party', current_audit.party, 'modality', current_audit.modality,
    'location', current_audit.location, 'criteria', current_audit.criteria,
    'evaluation_type', current_audit.evaluation_type,
    'evaluation_other', current_audit.evaluation_other,
    'declared_start_date', current_audit.declared_start_date,
    'declared_end_date', current_audit.declared_end_date,
    'participants_text', current_audit.participants_text, 'comments', current_audit.comments
  );

  update public.audits
  set unit_id = requested_unit,
      title = trim(payload ->> 'title'),
      objective = nullif(trim(payload ->> 'objective'), ''),
      scope = nullif(trim(payload ->> 'scope'), ''),
      criterion_ids = requested_criteria,
      standards = case when requested_criteria is distinct from current_audit.criterion_ids then array(
        select t.code || case when nullif(t.edition, '') is null then '' else ':' || t.edition end
        from public.audit_types t where t.id = any(requested_criteria) order by t.code, t.edition
      ) else current_audit.standards end,
      type_id = case when requested_criteria is distinct from current_audit.criterion_ids then requested_criteria[1] else current_audit.type_id end,
      purpose = coalesce(nullif(trim(payload ->> 'purpose'), ''), current_audit.purpose),
      party = coalesce(payload ->> 'party', current_audit.party),
      modality = coalesce(payload ->> 'modality', current_audit.modality),
      location = nullif(trim(payload ->> 'location'), ''),
      criteria = nullif(trim(payload ->> 'criteria'), ''),
      evaluation_type = nullif(trim(payload ->> 'evaluation_type'), ''),
      evaluation_other = nullif(trim(payload ->> 'evaluation_other'), ''),
      declared_start_date = nullif(payload ->> 'declared_start_date', '')::date,
      declared_end_date = nullif(payload ->> 'declared_end_date', '')::date,
      participants_text = nullif(trim(payload ->> 'participants_text'), ''),
      comments = nullif(trim(payload ->> 'comments'), ''),
      lock_version = lock_version + 1,
      updated_at = clock_timestamp()
  where id = aid and lock_version = (payload ->> 'expected_lock_version')::integer
  returning * into current_audit;
  if not found then
    raise exception 'Identificação alterada em outra sessão. Recarregue antes de salvar';
  end if;

  insert into public.audit_events(
    organization_id, actor_user_id, event_type, entity_type, entity_id, metadata
  ) values (
    current_audit.organization_id, actor, 'b06_identification_saved', 'audits', aid,
    jsonb_build_object(
      'contract_version', 1,
      'lock_version', current_audit.lock_version,
      'before', before_identification,
      'after', jsonb_build_object(
        'unit_id', current_audit.unit_id, 'title', current_audit.title,
        'objective', current_audit.objective, 'scope', current_audit.scope,
        'criterion_ids', current_audit.criterion_ids, 'purpose', current_audit.purpose,
        'party', current_audit.party, 'modality', current_audit.modality,
        'location', current_audit.location, 'criteria', current_audit.criteria,
        'evaluation_type', current_audit.evaluation_type,
        'evaluation_other', current_audit.evaluation_other,
        'declared_start_date', current_audit.declared_start_date,
        'declared_end_date', current_audit.declared_end_date,
        'participants_text', current_audit.participants_text, 'comments', current_audit.comments
      )
    )
  );

  return jsonb_build_object(
    'contract_version', 1,
    'audit_id', aid,
    'lock_version', current_audit.lock_version
  );
exception
  when invalid_text_representation or check_violation or not_null_violation then
    raise exception 'Identificação inválida: %', sqlerrm;
end;
$$;

create or replace function public.audit_identification(command text, payload jsonb default '{}'::jsonb)
returns jsonb
language sql
security invoker
set search_path = ''
as $$ select private.b06_identification(command, payload); $$;

revoke all on function private.b06_identification(text, jsonb) from public, anon, authenticated;
revoke all on function public.audit_identification(text, jsonb) from public, anon;
grant execute on function private.b06_identification(text, jsonb) to authenticated;
grant execute on function public.audit_identification(text, jsonb) to authenticated;

commit;
