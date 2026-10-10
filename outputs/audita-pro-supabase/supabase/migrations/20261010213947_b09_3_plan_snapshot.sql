-- B09 Parte 3: retrato congelado da revisão do Plano (cabeçalho, cliente, critérios, equipe, cronograma, escopo, FPA de referência,
-- controle de revisões e notas). É o conteúdo do pedido de emissão (B08): o PDF nunca relê o cadastro atual.
-- Numeração dos dias: dias já iniciados mantêm o número; dias planejados e novos seguem em ordem cronológica.
create function private.b09_day_numbers(aid uuid, dates date[]) returns table (audit_date date, day_number int)
 language sql stable security definer set search_path = '' as $$
 with started as (select d.audit_date, d.day_number from public.audit_days d where d.audit_id = aid and d.status <> 'planned'),
  base as (select coalesce(max(s.day_number), 0) n from started s),
  rest as (select x.dt, row_number() over (order by x.dt) k from (select distinct unnest(dates) dt) x where x.dt not in (select s.audit_date from started s))
 select s.audit_date, s.day_number from started s
 union all select r.dt, (select n from base) + r.k::int from rest r;
$$;

create function private.b09_address(addr jsonb) returns text language sql immutable set search_path = '' as $$
 select nullif(concat_ws(' · ', nullif(concat_ws(', ', nullif(btrim(addr->>'street'), ''), nullif(btrim(addr->>'number'), '')), ''),
   nullif(btrim(addr->>'district'), ''), nullif(concat_ws('/', nullif(btrim(addr->>'city'), ''), nullif(btrim(addr->>'state'), '')), ''),
   case when nullif(btrim(addr->>'zip'), '') is not null then 'CEP ' || btrim(addr->>'zip') end), '');
$$;

create function private.b09_snapshot(aid uuid, items jsonb, label text, reason text, actor uuid) returns jsonb
 language sql stable security definer set search_path = '' as $$
 with a as (select * from public.audits where id = aid),
  o as (select * from public.organizations where id = (select organization_id from a)),
  names as (select m.id mid, coalesce(nullif(btrim(p.full_name), ''), 'Usuário') nm from public.organization_memberships m
    left join public.user_profiles p on p.user_id = m.user_id),
  reqs as (select q.id, q.reference, t.code || coalesce(':' || nullif(t.edition, ''), '') crit from public.audit_checklists ac
    join public.checklist_sections s on s.revision_id = ac.revision_id join public.checklist_requirements q on q.section_id = s.id
    left join public.audit_types t on t.id = s.criterion_id where ac.audit_id = aid),
  days as (select * from private.b09_day_numbers(aid, (select array_agg(distinct (x->>'date')::date) from jsonb_array_elements(items) x))),
  fpa as (select f.*, v.version_number, v.received_on, v.filename from private.audit_fpa f left join private.audit_fpa_versions v on v.id = f.sufficient_version_id where f.audit_id = aid)
 select jsonb_build_object(
  'schema', 'plan.v1', 'template_version', 1,
  'audit', (select jsonb_build_object('id', id, 'code', code, 'title', title, 'timezone', coalesce(timezone, 'America/Sao_Paulo')) from a),
  'client', (select jsonb_build_object('legal_name', legal_name, 'trade_name', trade_name, 'code', code, 'cnpj', cnpj, 'address', private.b09_address(address)) from o),
  'header', (select jsonb_build_object('location', location, 'unit', (select u.name from public.organization_units u where u.id = a.unit_id),
     'start_date', declared_start_date, 'end_date', declared_end_date,
     'criteria', (select coalesce(jsonb_agg(jsonb_build_object('code', t.code, 'edition', t.edition, 'name', t.name) order by t.code), '[]') from public.audit_types t where t.id = any(a.criterion_ids)),
     'party', case party when 'first' then '1ª parte' when 'second' then '2ª parte' when 'third' then '3ª parte' end,
     'evaluation', case evaluation_type when 'initial' then 'Inicial' when 'certification' then 'Certificação' when 'maintenance' then 'Manutenção'
       when 'recertification' then 'Recertificação' when 'follow_up' then 'Follow-up' when 'diagnostic' then 'Diagnóstico' when 'other' then 'Outra: ' || evaluation_other end,
     'modality', case modality when 'presential' then 'Presencial' when 'remote' then 'Remota' when 'hybrid' then 'Híbrida' else modality end,
     'objective', objective, 'scope', scope, 'participants_text', participants_text, 'comments', comments) from a),
  'team', (select coalesce(jsonb_agg(jsonb_build_object('membership_id', ap.membership_id, 'name', n.nm,
     'role', case when ap.membership_id = a.leader_membership_id then 'Condutor' else 'Auditor de apoio' end)
     order by ap.membership_id <> a.leader_membership_id, n.nm), '[]')
    from public.audit_participants ap cross join a join names n on n.mid = ap.membership_id
    where ap.audit_id = aid and ap.active and ap.participant_type in ('leader', 'auditor')),
  'days', (select coalesce(jsonb_agg(jsonb_build_object('date', audit_date, 'day_number', day_number) order by audit_date), '[]') from days),
  'schedule', (select coalesce(jsonb_agg(x || jsonb_build_object(
     'day_number', (select d.day_number from days d where d.audit_date = (x->>'date')::date),
     'assignees', (select coalesce(jsonb_agg(n.nm order by n.nm), '[]') from jsonb_array_elements_text(x->'assignee_ids') v join names n on n.mid = v::uuid),
     'requirement_refs', (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'reference', r.reference, 'criterion', r.crit) order by r.crit, r.reference), '[]')
       from jsonb_array_elements_text(x->'requirements') v join reqs r on r.id = v::uuid),
     'category_label', case x->>'category' when 'assessment' then 'Avaliação' when 'opening' then 'Reunião de abertura' when 'closing' then 'Reunião de encerramento'
       when 'meeting' then 'Reunião' when 'break' then 'Intervalo' else 'Outra atividade' end)
     order by x->>'date', x->>'start_time', (x->>'display_order')::int), '[]') from jsonb_array_elements(items) x),
  'fpa', (select jsonb_build_object('version_number', version_number, 'received_on', received_on, 'analyzed_at', analyzed_at,
     'analyzed_by', (select coalesce(nullif(btrim(p.full_name), ''), 'Usuário') from public.user_profiles p where p.user_id = fpa.analyzed_by)) from fpa),
  'revision', jsonb_build_object('label', label, 'reason', reason, 'at', clock_timestamp(),
     'author', (select coalesce(nullif(btrim(p.full_name), ''), 'Usuário') from public.user_profiles p where p.user_id = actor)),
  'history', (select coalesce(jsonb_agg(jsonb_build_object('label', coalesce(v.revision_label, 'Versão ' || v.version_number || ' (legada)'),
     'at', coalesce(v.published_at, v.created_at), 'reason', v.reason,
     'author', (select coalesce(nullif(btrim(p.full_name), ''), 'Usuário') from public.user_profiles p where p.user_id = v.created_by)) order by v.version_number), '[]')
    from public.audit_plan_versions v where v.audit_id = aid and (v.state is null or v.state in ('published', 'superseded'))),
  'notes', private.b09_plan_notes(1), 'notes_version', 1);
$$;
revoke all on function private.b09_day_numbers(uuid, date[]), private.b09_address(jsonb), private.b09_snapshot(uuid, jsonb, text, text, uuid) from public, anon, authenticated;
