-- Recuperada de supabase_migrations.schema_migrations em 2026-10-10 (B00, Claude).
-- JA APLICADA no projeto zlckcpeqcxmtrgbdquee. NAO reaplicar. md5(statements)=8e4695e128cf307c6a253a6006f96258

begin;

-- B03 records every scope transition from this migration onward. The baseline row
-- marks legacy state at install time; it must not be projected into an older cut.
create table private.b03_scope_state_history (
  id bigint generated always as identity primary key,
  audit_id uuid not null,
  schedule_id uuid not null,
  question_namespace text not null check (question_namespace in ('catalog', 'extra')),
  question_id uuid not null,
  included boolean not null,
  effective_at timestamptz not null,
  source text not null check (source in ('migration_baseline', 'trigger_insert', 'trigger_update', 'trigger_delete'))
);

create index b03_scope_state_history_lookup
  on private.b03_scope_state_history
  (schedule_id, question_namespace, question_id, effective_at desc, id desc);

alter table private.b03_scope_state_history enable row level security;

revoke all on private.b03_scope_state_history from public, anon, authenticated;

create or replace function private.b03_capture_scope_state()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_schedule uuid;
  selected_question uuid;
  selected_included boolean;
  selected_audit uuid;
  selected_namespace text;
begin
  if tg_op = 'DELETE' then
    selected_schedule := old.schedule_id;
    selected_question := old.question_id;
    selected_included := false;
  else
    selected_schedule := new.schedule_id;
    selected_question := new.question_id;
    selected_included := new.included;
  end if;
  selected_namespace := case when tg_table_name = 'schedule_question_scope' then 'catalog' else 'extra' end;

  select d.audit_id into selected_audit
  from public.schedule_items s
  join public.audit_days d on d.id = s.audit_day_id
  where s.id = selected_schedule;

  if selected_audit is null then
    raise exception 'Atividade sem auditoria para histórico de escopo';
  end if;

  insert into private.b03_scope_state_history(
    audit_id, schedule_id, question_namespace, question_id, included, effective_at, source
  ) values (
    selected_audit, selected_schedule, selected_namespace, selected_question,
    selected_included, clock_timestamp(),
    case tg_op when 'INSERT' then 'trigger_insert' when 'UPDATE' then 'trigger_update' else 'trigger_delete' end
  );
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger b03_catalog_scope_state_history
after insert or update of included or delete on public.schedule_question_scope
for each row execute function private.b03_capture_scope_state();

create trigger b03_extra_scope_state_history
after insert or update of included or delete on public.schedule_extra_questions
for each row execute function private.b03_capture_scope_state();

with installed_at as (select clock_timestamp() as value)
insert into private.b03_scope_state_history(
  audit_id, schedule_id, question_namespace, question_id, included, effective_at, source
)
select d.audit_id, sq.schedule_id, 'catalog', sq.question_id, sq.included, installed_at.value, 'migration_baseline'
from public.schedule_question_scope sq
join public.schedule_items s on s.id = sq.schedule_id
join public.audit_days d on d.id = s.audit_day_id
cross join installed_at
union all
select d.audit_id, se.schedule_id, 'extra', se.question_id, se.included, installed_at.value, 'migration_baseline'
from public.schedule_extra_questions se
join public.schedule_items s on s.id = se.schedule_id
join public.audit_days d on d.id = s.audit_day_id
cross join installed_at;

-- MET-1 is additive. The contract-3 helpers remain available to legacy consumers.
create or replace function private.b03_metric_rollup(unit_rows jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
with parsed as (
  select
    value ->> 'unit_key' as unit_key,
    nullif(value ->> 'requirement_id', '')::uuid as requirement_id,
    coalesce((value ->> 'required')::boolean, true) as required,
    value ->> 'operational_state' as operational_state,
    value ->> 'result' as result,
    nullif(btrim(value ->> 'justification'), '') as justification,
    ordinality
  from jsonb_array_elements(coalesce(unit_rows, '[]'::jsonb)) with ordinality
), deduplicated as (
  select distinct on (unit_key) *
  from parsed
  where unit_key is not null
  order by unit_key, ordinality desc
), classified as (
  select *,
    coalesce(operational_state = 'completed'
      and result in ('conforming', 'partially_conforming', 'nonconforming'), false) as applicable,
    coalesce(operational_state = 'completed'
      and (
        result in ('conforming', 'partially_conforming', 'nonconforming')
        or (result = 'not_applicable' and justification is not null)
      ), false) as processed
  from deduplicated
), requirement_basis as (
  select requirement_id,
    bool_and(processed) filter (where required) as covered
  from classified
  where required and requirement_id is not null
  group by requirement_id
), totals as (
  select
    count(*)::integer as total,
    count(*) filter (where processed)::integer as processed,
    count(*) filter (where applicable)::integer as applicable,
    count(*) filter (where operational_state = 'completed' and result = 'conforming')::integer as conforming,
    count(*) filter (where operational_state = 'completed' and result = 'partially_conforming')::integer as partially_conforming,
    count(*) filter (where operational_state = 'completed' and result = 'nonconforming')::integer as nonconforming,
    count(*) filter (where operational_state = 'completed' and result = 'not_applicable' and justification is not null)::integer as not_applicable,
    count(*) filter (where not processed)::integer as pending
  from classified
), coverage as (
  select count(*)::integer as total,
    count(*) filter (where covered)::integer as covered
  from requirement_basis
)
select jsonb_build_object(
  'numerator', t.processed,
  'denominator', t.total,
  'percentage', case when t.total = 0 then null else round(100 * t.processed::numeric / t.total, 2) end,
  'reason', case when t.total = 0 then 'empty_scope' end,
  'total', t.total,
  'processed', t.processed,
  'applicable_assessed', t.applicable,
  'conforming', t.conforming,
  'partially_conforming', t.partially_conforming,
  'nonconforming', t.nonconforming,
  'not_applicable', t.not_applicable,
  'pending', t.pending,
  'fraction', case when t.total = 0 then null else t.processed::numeric / t.total end,
  'percent', case when t.total = 0 then null else round(100 * t.processed::numeric / t.total, 2) end,
  'no_base_reason', case when t.total = 0 then 'empty_scope' end,
  -- MET-1 não aprova índice de conformidade ou nota de certificação.
  'conformity_fraction', null,
  'conformity_percent', null,
  'conformity_no_base_reason', case when t.applicable = 0 then 'no_applicable_assessments' else 'outside_metric_contract' end,
  'requirement_coverage', jsonb_build_object(
    'numerator', c.covered,
    'denominator', c.total,
    'percentage', case when c.total = 0 then null else round(100 * c.covered::numeric / c.total, 2) end,
    'reason', case when c.total = 0 then 'no_required_question_basis' end,
    'total_with_required_basis', c.total,
    'covered', c.covered,
    'fraction', case when c.total = 0 then null else c.covered::numeric / c.total end,
    'percent', case when c.total = 0 then null else round(100 * c.covered::numeric / c.total, 2) end,
    'no_base_reason', case when c.total = 0 then 'no_required_question_basis' end
  )
)
from totals t cross join coverage c;
$$;

create or replace function private.b03_assessment_states(
  target_audit uuid,
  cutoff timestamptz,
  target_day uuid default null
)
returns table (
  unit_key text,
  question_namespace text,
  question_id uuid,
  requirement_id uuid,
  process_id uuid,
  audit_day_id uuid,
  operational_state text,
  result text,
  justification text,
  event_at timestamptz,
  revision integer
)
language sql
stable
security definer
set search_path = ''
as $$
with revisions as (
  select
    h.assessment_id,
    h.created_at as event_at,
    h.revision,
    h.content
  from public.assessment_history h
  join public.requirement_assessments a on a.id = h.assessment_id
  where a.audit_id = target_audit
    and (target_day is null or a.audit_day_id = target_day)
    and h.created_at <= cutoff
  union all
  select
    a.id,
    a.updated_at,
    a.lock_version,
    to_jsonb(a)
  from public.requirement_assessments a
  where a.audit_id = target_audit
    and (target_day is null or a.audit_day_id = target_day)
    and a.updated_at <= cutoff
), normalized as (
  select
    assessment_id,
    event_at,
    revision,
    case when nullif(content ->> 'extra_question_id', '') is null then 'catalog' else 'extra' end as question_namespace,
    coalesce(nullif(content ->> 'question_id', ''), nullif(content ->> 'extra_question_id', ''))::uuid as question_id,
    nullif(content ->> 'requirement_id', '')::uuid as requirement_id,
    nullif(content ->> 'process_id', '')::uuid as process_id,
    nullif(content ->> 'audit_day_id', '')::uuid as audit_day_id,
    content ->> 'operational_state' as operational_state,
    content ->> 'result' as result,
    content ->> 'evidence_text' as justification
  from revisions
), latest as (
  select distinct on (question_namespace, question_id, coalesce(process_id, '00000000-0000-0000-0000-000000000000'::uuid)) *
  from normalized
  where question_id is not null
  order by question_namespace, question_id, coalesce(process_id, '00000000-0000-0000-0000-000000000000'::uuid), event_at desc, revision desc, assessment_id desc
)
select
  question_namespace || ':' || question_id::text || ':process:' || coalesce(process_id::text, 'none'),
  question_namespace, question_id, requirement_id, process_id, audit_day_id,
  operational_state, result, justification, event_at, revision
from latest;
$$;

create or replace function private.b03_scope_units(
  target_audit uuid,
  target_scope_version integer,
  scope_at timestamptz,
  target_day uuid default null
)
returns table (
  unit_key text,
  question_namespace text,
  question_id uuid,
  requirement_id uuid,
  process_id uuid,
  schedule_id uuid,
  audit_day_id uuid,
  audited_date date,
  required boolean
)
language sql
stable
security definer
set search_path = ''
as $$
with plan as (
  select v.created_at, item
  from public.audit_plan_versions v
  cross join lateral jsonb_array_elements(v.content) item
  where v.audit_id = target_audit and v.version_number = target_scope_version
), plan_items as (
  select
    p.created_at,
    (p.item ->> 'id')::uuid as schedule_id,
    nullif(p.item ->> 'audit_day_id', '')::uuid as audit_day_id,
    nullif(p.item ->> 'date', '')::date as audited_date,
    nullif(p.item ->> 'process_id', '')::uuid as process_id,
    p.item
  from plan p
  where coalesce((p.item ->> 'withdrawn')::boolean, false) = false
    and coalesce(p.item ->> 'category', 'assessment') = 'assessment'
), catalog_candidates as (
  select i.schedule_id, q.id as question_id
  from plan_items i
  cross join lateral jsonb_array_elements_text(coalesce(i.item -> 'requirements', '[]'::jsonb)) requirement(value)
  join public.checklist_questions q on q.requirement_id = requirement.value::uuid
  union
  select i.schedule_id, h.entity_id
  from plan_items i
  join public.checklist_record_history h
    on nullif(h.content ->> 'schedule_id', '')::uuid = i.schedule_id
  where h.audit_id = target_audit
    and h.entity_type in ('scope_include', 'scope_exclude')
    and h.created_at <= scope_at
), catalog as (
  select
    'catalog'::text as question_namespace,
    q.id as question_id,
    q.requirement_id,
    i.process_id,
    i.schedule_id,
    i.audit_day_id,
    i.audited_date,
    q.required,
    coalesce((
      select h.included from private.b03_scope_state_history h
      where h.audit_id=target_audit and h.schedule_id=i.schedule_id
        and h.question_namespace='catalog' and h.question_id=q.id and h.effective_at<=scope_at
      order by h.effective_at desc,h.id desc limit 1
    ), (
      select h.entity_type = 'scope_include'
      from public.checklist_record_history h
      where h.audit_id = target_audit
        and h.entity_type in ('scope_include', 'scope_exclude')
        and h.entity_id = q.id
        and nullif(h.content ->> 'schedule_id', '')::uuid = i.schedule_id
        and h.created_at <= scope_at
      order by h.created_at desc, h.id desc limit 1
    ), (
      select sq.included
      from public.schedule_question_scope sq
      where sq.schedule_id = i.schedule_id and sq.question_id = q.id
        and sq.updated_at <= scope_at
    ), true) as included
  from plan_items i
  join catalog_candidates candidate on candidate.schedule_id = i.schedule_id
  join public.checklist_questions q on q.id = candidate.question_id
  where q.active
), extras as (
  select
    'extra'::text,
    q.id,
    q.requirement_id,
    i.process_id,
    i.schedule_id,
    i.audit_day_id,
    i.audited_date,
    q.required,
    coalesce((
      select h.included from private.b03_scope_state_history h
      where h.audit_id=target_audit and h.schedule_id=i.schedule_id
        and h.question_namespace='extra' and h.question_id=q.id and h.effective_at<=scope_at
      order by h.effective_at desc,h.id desc limit 1
    ), (
      select h.entity_type = 'scope_include'
      from public.checklist_record_history h
      where h.audit_id = target_audit
        and h.entity_type in ('scope_include', 'scope_exclude')
        and h.entity_id = q.id
        and nullif(h.content ->> 'schedule_id', '')::uuid = i.schedule_id
        and h.created_at <= scope_at
      order by h.created_at desc, h.id desc limit 1
    ), false)
  from plan_items i
  join public.schedule_extra_questions se on se.schedule_id = i.schedule_id
  join public.audit_extra_questions q on q.id = se.question_id and q.audit_id = target_audit
  where q.active and q.created_at <= scope_at
), combined as (
  select * from catalog union all select * from extras
)
select
  question_namespace || ':' || question_id::text || ':process:' || coalesce(process_id::text, 'none'),
  question_namespace, question_id, requirement_id, process_id, schedule_id,
  coalesce(audit_day_id, d.id), audited_date, required
from combined c
left join public.audit_days d on d.audit_id = target_audit and d.audit_date = c.audited_date
where included
  and (target_day is null or coalesce(c.audit_day_id, d.id) = target_day);
$$;

create or replace function private.b03_temporal_metrics(
  target_audit uuid,
  cutoff timestamptz,
  target_day uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  scope_version integer;
  audited_date date;
  audit_timezone text;
  scope_created_at timestamptz;
  scope_effective_at timestamptz;
  rows_json jsonb;
  rollup jsonb;
  schedule_metric jsonb;
  findings_metric jsonb;
  history_gaps integer;
begin
  if auth.uid() is null or not private.is_active_account(auth.uid()) then
    raise exception 'Sessão ativa necessária' using errcode = '42501';
  end if;
  if cutoff is null then raise exception 'Data de corte obrigatória'; end if;

  select a.timezone into audit_timezone from public.audits a where a.id = target_audit;
  if audit_timezone is null
    or not coalesce(private.b02_scope(target_audit), false)
    or not coalesce(private.checklist_internal(target_audit), false) then
    raise exception 'Auditoria indisponível' using errcode = '42501';
  end if;

  if target_day is not null then
    select d.audit_date, d.opening_plan_version, d.started_at
      into audited_date, scope_version, scope_effective_at
    from public.audit_days d
    where d.id = target_day and d.audit_id = target_audit;
    if audited_date is null then raise exception 'Dia fora da auditoria'; end if;
  else
    select v.version_number into scope_version
    from public.audit_plan_versions v
    where v.audit_id = target_audit and v.created_at <= cutoff
    order by v.version_number desc limit 1;
  end if;

  if target_day is not null and (scope_effective_at is null or scope_effective_at > cutoff) then
    return jsonb_build_object(
      'metric_version', 'MET-1.1', 'scope_version', scope_version, 'cutoff_at', cutoff,
      'audited_date', audited_date, 'unit_kind', 'question_namespace_process_context',
      'status', 'no_base',
      'execution', jsonb_build_object('numerator', null, 'denominator', null, 'percentage', null, 'reason', 'day_not_open_at_cutoff', 'total', null, 'processed', null, 'percent', null, 'no_base_reason', 'day_not_open_at_cutoff'),
      'requirement_coverage', jsonb_build_object('numerator', null, 'denominator', null, 'percentage', null, 'reason', 'day_not_open_at_cutoff', 'percent', null, 'no_base_reason', 'day_not_open_at_cutoff'),
      'public_schedule_progress', jsonb_build_object('numerator', null, 'denominator', null, 'percentage', null, 'reason', 'day_not_open_at_cutoff', 'percent', null, 'no_base_reason', 'day_not_open_at_cutoff'),
      'findings', jsonb_build_object('NC', null, 'OBS', null, 'OM', null),
      'history', jsonb_build_object('complete', false, 'limitations', jsonb_build_array('day_not_open_at_cutoff'))
    );
  end if;

  if scope_version is null then
    return jsonb_build_object(
      'metric_version', 'MET-1.1', 'scope_version', null, 'cutoff_at', cutoff,
      'audited_date', audited_date, 'unit_kind', 'question_namespace_process_context',
      'status', 'no_base',
      'execution', jsonb_build_object('numerator', null, 'denominator', null, 'percentage', null, 'reason', case when target_day is null then 'scope_version_not_available_at_cutoff' else 'opening_plan_baseline_unavailable' end, 'total', null, 'processed', null, 'percent', null, 'no_base_reason', case when target_day is null then 'scope_version_not_available_at_cutoff' else 'opening_plan_baseline_unavailable' end),
      'requirement_coverage', jsonb_build_object('numerator', null, 'denominator', null, 'percentage', null, 'reason', case when target_day is null then 'scope_version_not_available_at_cutoff' else 'opening_plan_baseline_unavailable' end, 'percent', null, 'no_base_reason', case when target_day is null then 'scope_version_not_available_at_cutoff' else 'opening_plan_baseline_unavailable' end),
      'public_schedule_progress', jsonb_build_object('numerator', null, 'denominator', null, 'percentage', null, 'reason', case when target_day is null then 'scope_version_not_available_at_cutoff' else 'opening_plan_baseline_unavailable' end, 'percent', null, 'no_base_reason', case when target_day is null then 'scope_version_not_available_at_cutoff' else 'opening_plan_baseline_unavailable' end),
      'findings', jsonb_build_object('NC', null, 'OBS', null, 'OM', null),
      'history', jsonb_build_object('complete', false, 'limitations', jsonb_build_array(case when target_day is null then 'scope_version_not_available_at_cutoff' else 'missing_opening_plan_version' end))
    );
  end if;

  select v.created_at into scope_created_at
  from public.audit_plan_versions v
  where v.audit_id = target_audit and v.version_number = scope_version;
  if scope_created_at is null or scope_created_at > cutoff then
    return jsonb_build_object(
      'metric_version', 'MET-1.1', 'scope_version', scope_version, 'cutoff_at', cutoff,
      'audited_date', audited_date, 'unit_kind', 'question_namespace_process_context',
      'status', 'no_base',
      'execution', jsonb_build_object('numerator', null, 'denominator', null, 'percentage', null, 'reason', 'scope_version_not_available_at_cutoff', 'total', null, 'processed', null, 'percent', null, 'no_base_reason', 'scope_version_not_available_at_cutoff'),
      'requirement_coverage', jsonb_build_object('numerator', null, 'denominator', null, 'percentage', null, 'reason', 'scope_version_not_available_at_cutoff', 'percent', null, 'no_base_reason', 'scope_version_not_available_at_cutoff'),
      'public_schedule_progress', jsonb_build_object('numerator', null, 'denominator', null, 'percentage', null, 'reason', 'scope_version_not_available_at_cutoff', 'percent', null, 'no_base_reason', 'scope_version_not_available_at_cutoff'),
      'findings', jsonb_build_object('NC', null, 'OBS', null, 'OM', null),
      'history', jsonb_build_object('complete', false, 'limitations', jsonb_build_array('scope_version_after_cutoff'))
    );
  end if;
  scope_effective_at := case
    when target_day is null then cutoff
    else coalesce(scope_effective_at, scope_created_at)
  end;

  select count(*) into history_gaps
  from public.requirement_assessments a
  where a.audit_id = target_audit
    and (target_day is null or a.audit_day_id = target_day)
    and a.created_at <= cutoff and a.updated_at > cutoff
    and not exists (
      select 1 from public.assessment_history h
      where h.assessment_id = a.id and h.created_at <= cutoff
    );

  if exists (
    select 1 from private.b03_scope_state_history h
    where h.audit_id=target_audit and h.source='migration_baseline'
      and h.effective_at>scope_effective_at
  ) then
    return jsonb_build_object(
      'metric_version','MET-1.1','scope_version',scope_version,'cutoff_at',cutoff,
      'audited_date',audited_date,'unit_kind','question_namespace_process_context','status','no_base',
      'execution',jsonb_build_object('numerator',null,'denominator',null,'percentage',null,'reason','historical_scope_unavailable'),
      'requirement_coverage',jsonb_build_object('numerator',null,'denominator',null,'percentage',null,'reason','historical_scope_unavailable'),
      'public_schedule_progress',private.b03_public_schedule_progress(target_audit,cutoff,target_day)->'public_schedule_progress',
      'findings',jsonb_build_object('NC',null,'OBS',null,'OM',null),
      'history',jsonb_build_object('complete',false,'limitations',jsonb_build_array('historical_scope_unavailable')));
  end if;

  with baseline as (
    select u.*, s.operational_state, s.result, s.justification, 1 as priority
    from private.b03_scope_units(target_audit, scope_version, scope_effective_at, target_day) u
    left join private.b03_assessment_states(target_audit, cutoff, target_day) s using (unit_key)
  ), worked as (
    select
      s.unit_key, s.question_namespace, s.question_id, s.requirement_id, s.process_id,
      null::uuid as schedule_id, s.audit_day_id, d.audit_date as audited_date,
      coalesce(q.required, x.required, true) as required,
      s.operational_state, s.result, s.justification, 2 as priority
    from private.b03_assessment_states(target_audit, cutoff, target_day) s
    join public.audit_days d on d.id = s.audit_day_id
    left join public.checklist_questions q on s.question_namespace = 'catalog' and q.id = s.question_id
    left join public.audit_extra_questions x on s.question_namespace = 'extra' and x.id = s.question_id
    where target_day is not null
  ), deduplicated as (
    select distinct on (unit_key) * from (
      select * from baseline union all select * from worked
    ) all_units
    order by unit_key, priority desc
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'unit_key', unit_key, 'namespace', question_namespace, 'question_id', question_id,
    'requirement_id', requirement_id, 'process_id', process_id, 'required', required,
    'operational_state', operational_state, 'result', result, 'justification', justification
  ) order by unit_key), '[]'::jsonb) into rows_json
  from deduplicated;

  rollup := private.b03_metric_rollup(rows_json);
  if history_gaps > 0 then
    rollup := jsonb_set(jsonb_set(rollup, '{percent}', 'null'::jsonb), '{fraction}', 'null'::jsonb);
    rollup := jsonb_set(rollup, '{percentage}', 'null'::jsonb);
    rollup := jsonb_set(rollup, '{reason}', to_jsonb('historical_assessment_revision_unavailable'::text));
    rollup := jsonb_set(rollup, '{no_base_reason}', to_jsonb('historical_assessment_revision_unavailable'::text));
    rollup := jsonb_set(rollup, '{conformity_percent}', 'null'::jsonb);
    rollup := jsonb_set(rollup, '{conformity_fraction}', 'null'::jsonb);
    rollup := jsonb_set(rollup, '{conformity_no_base_reason}', to_jsonb('historical_assessment_revision_unavailable'::text));
    rollup := jsonb_set(rollup, '{requirement_coverage,percentage}', 'null'::jsonb);
    rollup := jsonb_set(rollup, '{requirement_coverage,percent}', 'null'::jsonb);
    rollup := jsonb_set(rollup, '{requirement_coverage,fraction}', 'null'::jsonb);
    rollup := jsonb_set(rollup, '{requirement_coverage,reason}', to_jsonb('historical_assessment_revision_unavailable'::text));
    rollup := jsonb_set(rollup, '{requirement_coverage,no_base_reason}', to_jsonb('historical_assessment_revision_unavailable'::text));
  end if;

  with plan as (
    select item
    from public.audit_plan_versions v
    cross join lateral jsonb_array_elements(v.content) item
    where v.audit_id = target_audit and v.version_number = scope_version
  ), valid as (
    select item, nullif(item ->> 'id', '')::uuid as schedule_id
    from plan
    where coalesce((item ->> 'withdrawn')::boolean, false) = false
      and (target_day is null or nullif(item ->> 'date', '')::date = audited_date)
  ), counted as (
    select count(*)::integer total,
      count(*) filter (where
        coalesce((item ->> 'status') = 'completed', false)
        or exists (
          select 1 from public.schedule_items s
          where s.id = valid.schedule_id and s.actual_end is not null and s.actual_end <= cutoff
        )
      )::integer completed
    from valid
  )
  select jsonb_build_object(
    'numerator', completed, 'denominator', total,
    'percentage', case when total = 0 then null else round(100 * completed::numeric / total, 2) end,
    'reason', case when total = 0 then 'no_published_activities' end,
    'total', total, 'completed', completed,
    'fraction', case when total = 0 then null else completed::numeric / total end,
    'percent', case when total = 0 then null else round(100 * completed::numeric / total, 2) end,
    'no_base_reason', case when total = 0 then 'no_published_activities' end
  ) into schedule_metric from counted;

  select jsonb_build_object(
    'NC', count(*) filter (where f.kind = 'NC'),
    'OBS', count(*) filter (where f.kind = 'OBS'),
    'OM', count(*) filter (where f.kind = 'OM')
  ) into findings_metric
  from public.assessment_findings f
  join public.requirement_assessments a on a.id = f.assessment_id
  where f.audit_id = target_audit
    and f.created_at <= cutoff
    and (target_day is null or a.audit_day_id = target_day);

  return jsonb_build_object(
    'metric_version', 'MET-1.1',
    'scope_version', scope_version,
    'cutoff_at', cutoff,
    'audited_date', audited_date,
    'unit_kind', 'question_namespace_process_context',
    'status', case when history_gaps > 0 then 'incomplete_history' else 'available' end,
    'execution', rollup - 'requirement_coverage',
    'requirement_coverage', rollup -> 'requirement_coverage',
    'public_schedule_progress', schedule_metric,
    'findings', findings_metric,
    'history', jsonb_build_object(
      'complete', history_gaps = 0,
      'assessment_revision_gaps', history_gaps,
      'scope_source', 'audit_plan_versions',
      'limitations', case when history_gaps > 0
        then jsonb_build_array('legacy_assessment_changed_without_revision_at_or_before_cutoff')
        else '[]'::jsonb end
    )
  );
end;
$$;

create or replace function private.b03_public_schedule_progress(
  target_audit uuid,
  cutoff timestamptz,
  target_day uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  selected_scope_version integer;
  selected_date date;
  day_opened_at timestamptz;
  scope_created_at timestamptz;
  progress jsonb;
begin
  if auth.uid() is null or not private.is_active_account(auth.uid())
    or not coalesce(private.b02_scope(target_audit), false) then
    raise exception 'Auditoria indisponível' using errcode = '42501';
  end if;
  if cutoff is null then raise exception 'Data de corte obrigatória'; end if;

  if target_day is not null then
    select d.audit_date, d.opening_plan_version, d.started_at
      into selected_date, selected_scope_version, day_opened_at
    from public.audit_days d
    where d.id = target_day and d.audit_id = target_audit;
    if selected_date is null then raise exception 'Dia fora da auditoria'; end if;
  else
    select v.version_number into selected_scope_version
    from public.audit_plan_versions v
    where v.audit_id = target_audit and v.created_at <= cutoff
    order by v.version_number desc limit 1;
  end if;

  if target_day is not null and (day_opened_at is null or day_opened_at > cutoff) then
    return jsonb_build_object(
      'metric_version', 'MET-1.1', 'scope_version', selected_scope_version,
      'cutoff_at', cutoff, 'audited_date', selected_date, 'unit_kind', 'published_activity',
      'status', 'no_base',
      'public_schedule_progress', jsonb_build_object(
        'numerator', null, 'denominator', null, 'percentage', null,
        'reason', 'day_not_open_at_cutoff', 'total', null, 'completed', null,
        'percent', null, 'no_base_reason', 'day_not_open_at_cutoff'
      )
    );
  end if;

  if selected_scope_version is not null then
    select v.created_at into scope_created_at
    from public.audit_plan_versions v
    where v.audit_id = target_audit and v.version_number = selected_scope_version;
  end if;
  if selected_scope_version is null or scope_created_at is null or scope_created_at > cutoff then
    return jsonb_build_object(
      'metric_version', 'MET-1.1', 'scope_version', selected_scope_version,
      'cutoff_at', cutoff, 'audited_date', selected_date, 'unit_kind', 'published_activity',
      'status', 'no_base',
      'public_schedule_progress', jsonb_build_object(
        'numerator', null, 'denominator', null, 'percentage', null,
        'reason', case when selected_scope_version is null and target_day is not null then 'opening_plan_baseline_unavailable' else 'scope_version_not_available_at_cutoff' end,
        'total', null, 'completed', null, 'percent', null,
        'no_base_reason', case when selected_scope_version is null and target_day is not null then 'opening_plan_baseline_unavailable' else 'scope_version_not_available_at_cutoff' end
      )
    );
  end if;

  with published_plan as (
    select item
    from public.audit_plan_versions v
    cross join lateral jsonb_array_elements(v.content) item
    where v.audit_id = target_audit and v.version_number = selected_scope_version
  ), valid as (
    select item, nullif(item ->> 'id', '')::uuid as schedule_id
    from published_plan
    where coalesce((item ->> 'withdrawn')::boolean, false) = false
      and (target_day is null or nullif(item ->> 'date', '')::date = selected_date)
  ), counted as (
    select count(*)::integer total,
      count(*) filter (where
        coalesce((item ->> 'status') = 'completed', false)
        or exists (
          select 1 from public.schedule_items s
          where s.id = valid.schedule_id and s.actual_end is not null and s.actual_end <= cutoff
        )
      )::integer completed
    from valid
  )
  select jsonb_build_object(
    'numerator', completed, 'denominator', total,
    'percentage', case when total = 0 then null else round(100 * completed::numeric / total, 2) end,
    'reason', case when total = 0 then 'no_published_activities' end,
    'total', total, 'completed', completed,
    'fraction', case when total = 0 then null else completed::numeric / total end,
    'percent', case when total = 0 then null else round(100 * completed::numeric / total, 2) end,
    'no_base_reason', case when total = 0 then 'no_published_activities' end
  ) into progress from counted;

  return jsonb_build_object(
    'metric_version', 'MET-1.1', 'scope_version', selected_scope_version,
    'cutoff_at', cutoff, 'audited_date', selected_date, 'unit_kind', 'published_activity',
    'status', 'available', 'public_schedule_progress', progress
  );
end;
$$;

create or replace function public.audit_temporal_metrics(
  audit_id uuid,
  cutoff_at timestamptz default clock_timestamp(),
  audit_day_id uuid default null
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select private.b03_temporal_metrics(audit_id, cutoff_at, audit_day_id);
$$;

create or replace function public.audit_public_schedule_progress(
  audit_id uuid,
  cutoff_at timestamptz default clock_timestamp(),
  audit_day_id uuid default null
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select private.b03_public_schedule_progress(audit_id, cutoff_at, audit_day_id);
$$;

create index if not exists assessment_history_temporal_lookup
  on public.assessment_history (assessment_id, created_at desc, revision desc);

create index if not exists assessment_temporal_audit_day
  on public.requirement_assessments (audit_id, audit_day_id, updated_at desc);

create index if not exists plan_versions_temporal_lookup
  on public.audit_plan_versions (audit_id, created_at desc, version_number desc);

create index if not exists checklist_record_scope_temporal
  on public.checklist_record_history (audit_id, entity_id, created_at desc)
  where entity_type in ('scope_include', 'scope_exclude');

revoke all on function private.b03_capture_scope_state() from public, anon, authenticated;

revoke all on function private.b03_metric_rollup(jsonb) from public, anon, authenticated;

revoke all on function private.b03_assessment_states(uuid, timestamptz, uuid) from public, anon, authenticated;

revoke all on function private.b03_scope_units(uuid, integer, timestamptz, uuid) from public, anon, authenticated;

revoke all on function private.b03_temporal_metrics(uuid, timestamptz, uuid) from public, anon, authenticated;

revoke all on function private.b03_public_schedule_progress(uuid, timestamptz, uuid) from public, anon, authenticated;

revoke all on function public.audit_temporal_metrics(uuid, timestamptz, uuid) from public, anon;

revoke all on function public.audit_public_schedule_progress(uuid, timestamptz, uuid) from public, anon;

grant execute on function public.audit_temporal_metrics(uuid, timestamptz, uuid) to authenticated;

grant execute on function public.audit_public_schedule_progress(uuid, timestamptz, uuid) to authenticated;

comment on function public.audit_temporal_metrics(uuid, timestamptz, uuid) is
  'MET-1.1: execução por pergunta namespace/processo, cobertura de requisitos e progresso do cronograma no corte. Percentuais sem base são NULL.';

comment on function public.audit_public_schedule_progress(uuid, timestamptz, uuid) is
  'MET-1.1 público: somente progresso agregado das atividades da versão publicada autorizada por B02.';

commit;
