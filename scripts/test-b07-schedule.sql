-- B07: PA-07..10, PA-17, PA-19, PA-22/23, RDA-08 (rascunho, validações e continuidade) no banco local, transação revertida.
-- Contas: 001 Admin | 002 Líder X (condutor) | 003 Auditor X (apoio) | 004 Participante X | 005 Líder Y
create temp table t_res (n serial, name text, ok boolean, detail text);
grant all on t_res to authenticated; grant usage on sequence t_res_n_seq to authenticated;
create temp table t_ids (k text primary key, v text); grant all on t_ids to authenticated;
create function pg_temp.as_user(uid text) returns void language sql as
 $$ select set_config('request.jwt.claims', json_build_object('sub', ('a0000000-0000-4000-8000-0000000000' || uid), 'role', 'authenticated')::text, true); $$;
create function pg_temp.id(key text) returns uuid language sql as $$ select v::uuid from t_ids where k = key $$;
create function pg_temp.v(key text) returns text language sql as $$ select v from t_ids where k = key $$;
create function pg_temp.ok(label text, cond boolean, info text default '') returns void language sql as
 $$ insert into t_res(name, ok, detail) values (label, coalesce(cond, false), info) $$;
create function pg_temp.err(label text, cmd text, payload jsonb, needle text) returns void language plpgsql as $$
begin perform public.audit_schedule(cmd, payload); insert into t_res(name, ok, detail) values (label, false, 'sem erro');
exception when others then insert into t_res(name, ok, detail) values (label, position(lower(needle) in lower(sqlerrm)) > 0, sqlerrm); end $$;
create function pg_temp.has_issue(issues jsonb, k text, field text, lvl text) returns boolean language sql as
 $$ select exists (select 1 from jsonb_array_elements(issues) i where (k is null or i->>'key' = k) and i->>'field' = field and i->>'level' = lvl) $$;
-- Auditoria com equipe (Líder X condutor + Auditor X), período declarado e checklist com dois requisitos.
do $$ declare aid uuid; lm uuid; am uuid; tid uuid; rid uuid; sid uuid; r1 uuid; r2 uuid; begin
 select id into lm from public.organization_memberships where user_id = 'a0000000-0000-4000-8000-000000000002';
 select id into am from public.organization_memberships where user_id = 'a0000000-0000-4000-8000-000000000003';
 insert into public.audits (organization_id, code, title, leader_membership_id, created_by, workspace_version, purpose, party, modality, declared_start_date, declared_end_date, timezone)
 values ('0000000a-0000-4000-8000-00000000000a', 'AUD-X', 'Integrada', lm, 'a0000000-0000-4000-8000-000000000002', 1, 'A definir', 'first', 'presential', '2026-10-20', '2026-10-23', 'America/Sao_Paulo') returning id into aid;
 insert into public.audit_participants (audit_id, membership_id, participant_type) values (aid, lm, 'leader'), (aid, am, 'auditor');
 insert into public.checklist_templates (name, status, created_by) values ('Modelo teste', 'published', 'a0000000-0000-4000-8000-000000000001') returning id into tid;
 insert into public.checklist_revisions (template_id, revision_number, status, created_by) values (tid, 1, 'draft', 'a0000000-0000-4000-8000-000000000001') returning id into rid;
 insert into public.checklist_sections (revision_id, title, sort_order) values (rid, '4 Contexto', 1) returning id into sid;
 insert into public.checklist_requirements (section_id, reference, prompt, sort_order) values (sid, '4.1', 'Contexto', 1) returning id into r1;
 insert into public.checklist_requirements (section_id, reference, prompt, sort_order) values (sid, '4.2', 'Partes', 2) returning id into r2;
 update public.checklist_revisions set status = 'published', published_at = now() where id = rid;
 insert into t_ids values ('A', aid), ('lm', lm), ('am', am), ('r1', r1), ('r2', r2);
 insert into public.audit_checklists (audit_id, revision_id, attached_by) values (aid, rid, 'a0000000-0000-4000-8000-000000000001');
end $$;

select pg_temp.as_user('02'); set local role authenticated;
do $$ declare d jsonb; begin
 d := public.audit_schedule('draft', jsonb_build_object('audit_id', pg_temp.id('A')));
 insert into t_ids values ('lv', d->>'lock_version');
 perform pg_temp.ok('Rascunho vazio indica falta de atividade', pg_temp.has_issue(d->'issues', null, 'schedule', 'error'));
 perform pg_temp.ok('Equipe para designação traz condutor e apoio', jsonb_array_length(d->'team') = 2 and jsonb_array_length(d->'requirements') = 2, (d->'team')::text);
end $$;
do $$ declare r jsonb; lm text := pg_temp.v('lm'); am text := pg_temp.v('am'); begin
 r := public.audit_schedule('save', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.v('lv')::int, 'operation_id', '22222222-0000-4000-8000-000000000001',
  'items', jsonb_build_array(
   jsonb_build_object('key', '10000000-0000-4000-8000-000000000001', 'title', 'Reunião de abertura', 'category', 'opening', 'date', '2026-10-20', 'start_time', '08:00', 'end_time', '08:30', 'location', 'Sala 1', 'assignee_ids', jsonb_build_array(lm)),
   jsonb_build_object('key', '10000000-0000-4000-8000-000000000002', 'title', 'Compras', 'process', 'Compras', 'date', '2026-10-20', 'start_time', '08:30', 'end_time', '10:00', 'location', 'Almoxarifado', 'assignee_ids', jsonb_build_array(lm, am), 'requirements', jsonb_build_array(pg_temp.v('r1'))),
   jsonb_build_object('key', '10000000-0000-4000-8000-000000000003', 'title', 'Produção', 'process', 'Produção', 'date', '2026-10-20', 'start_time', '09:30', 'end_time', '11:00', 'location', 'Fábrica', 'assignee_ids', jsonb_build_array(am), 'requirements', jsonb_build_array(pg_temp.v('r1'))),
   jsonb_build_object('key', '10000000-0000-4000-8000-000000000004', 'title', 'Qualidade', 'process', 'Qualidade', 'date', '2026-10-20', 'start_time', '10:00', 'end_time', '11:00', 'location', 'Laboratório', 'assignee_ids', jsonb_build_array(lm), 'requirements', jsonb_build_array(pg_temp.v('r1'))),
   jsonb_build_object('key', '10000000-0000-4000-8000-000000000005', 'title', 'Expedição', 'process', 'Expedição', 'date', '2026-10-23', 'start_time', '14:00', 'end_time', '13:00', 'location', 'Doca', 'assignee_ids', jsonb_build_array(lm), 'requirements', jsonb_build_array(pg_temp.v('r1'))),
   jsonb_build_object('key', '10000000-0000-4000-8000-000000000006', 'title', 'Fora do período', 'category', 'meeting', 'date', '2026-10-25', 'start_time', '09:00', 'end_time', '10:00', 'location', 'Sala', 'assignee_ids', jsonb_build_array(lm)),
   jsonb_build_object('key', '10000000-0000-4000-8000-000000000007', 'title', 'Intervalo', 'category', 'break', 'date', '2026-10-20', 'start_time', '12:00', 'end_time', '13:00', 'location', 'Refeitório', 'assignee_ids', jsonb_build_array('a0000000-0000-4000-8000-000000000999')),
   jsonb_build_object('key', '10000000-0000-4000-8000-000000000008', 'title', 'Escopo inválido', 'process', 'RH', 'date', '2026-10-21', 'start_time', '09:00', 'end_time', '10:00', 'location', 'RH', 'assignee_ids', jsonb_build_array(lm), 'requirements', jsonb_build_array(gen_random_uuid()))
  )));
 insert into t_ids values ('res', r::text);
 update t_ids set v = r->>'lock_version' where k = 'lv';
 perform pg_temp.ok('PA-07 várias linhas no mesmo dia com local, horário e auditores preservados', jsonb_array_length(r->'items') = 8
  and r->'items'->1->>'location' = 'Almoxarifado' and jsonb_array_length(r->'items'->1->'assignee_ids') = 2 and r->'items'->1->>'start_time' = '08:30');
 perform pg_temp.ok('Horário interpretado no fuso da auditoria (08:00 BRT = 11:00 UTC)', (r->'items'->0->>'start')::timestamptz = '2026-10-20 11:00:00+00', r->'items'->0->>'start');
 perform pg_temp.ok('Ordem manual preservada', (r->'items'->2->>'display_order')::int = 3);
 perform pg_temp.ok('PA-10 aviso: mesmo auditor em horários sobrepostos', pg_temp.has_issue(r->'issues', '10000000-0000-4000-8000-000000000003', 'assignees', 'warning'));
 perform pg_temp.ok('PA-10 equipes distintas simultâneas sem aviso', not pg_temp.has_issue(r->'issues', '10000000-0000-4000-8000-000000000004', 'assignees', 'warning')
  or (select count(*) from jsonb_array_elements(r->'issues') i where i->>'key' = '10000000-0000-4000-8000-000000000004' and i->>'level' = 'warning' and i->>'message' like '%Produção%') = 0);
 perform pg_temp.ok('Intervalo semiaberto: terminar às 10:00 e começar às 10:00 não conflita', (select count(*) from jsonb_array_elements(r->'issues') i
  where i->>'key' = '10000000-0000-4000-8000-000000000004' and i->>'message' like '%Compras%') = 0);
 perform pg_temp.ok('PA-09 término antes do início bloqueia com orientação de meia-noite', pg_temp.has_issue(r->'issues', '10000000-0000-4000-8000-000000000005', 'time', 'error')
  and exists (select 1 from jsonb_array_elements(r->'issues') i where i->>'key' = '10000000-0000-4000-8000-000000000005' and i->>'message' like '%meia-noite%'));
 perform pg_temp.ok('PA-09 atividade fora do período declarado bloqueia', pg_temp.has_issue(r->'issues', '10000000-0000-4000-8000-000000000006', 'date', 'error'));
 perform pg_temp.ok('Reunião/intervalo sem requisito artificial', not pg_temp.has_issue(r->'issues', '10000000-0000-4000-8000-000000000001', 'requirements', 'error')
  and not pg_temp.has_issue(r->'issues', '10000000-0000-4000-8000-000000000007', 'requirements', 'error'));
 perform pg_temp.ok('PA-19 auditor fora da equipe recusado na linha', pg_temp.has_issue(r->'issues', '10000000-0000-4000-8000-000000000007', 'assignees', 'error'));
 perform pg_temp.ok('Requisito fora dos checklists da auditoria bloqueia', pg_temp.has_issue(r->'issues', '10000000-0000-4000-8000-000000000008', 'requirements', 'error'));
 perform pg_temp.ok('Requisito ainda não distribuído aparece no plano', exists (select 1 from jsonb_array_elements(r->'issues') i where i->>'key' is null and i->>'message' like '1 requisito%'));
 perform pg_temp.ok('PA-22 dias não consecutivos sem dias intermediários no rascunho', (select count(distinct x->>'date') from jsonb_array_elements(r->'items') x) = 4);
 perform pg_temp.ok('Ordem visual fora da cronológica gera aviso, sem reordenar', pg_temp.has_issue(r->'issues', '10000000-0000-4000-8000-000000000007', 'order', 'warning')
  and r->'items'->6->>'key' = '10000000-0000-4000-8000-000000000007');
end $$;
-- Idempotência e concorrência (PA-23)
do $$ declare r jsonb; begin
 r := public.audit_schedule('save', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', 0, 'operation_id', '22222222-0000-4000-8000-000000000001', 'items', '[]'::jsonb));
 perform pg_temp.ok('Mesma operação repetida devolve o resultado anterior', r::text = pg_temp.v('res'));
end $$;
select pg_temp.err('PA-23 versão desatualizada detectada sem sobrescrever', 'save', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', 0,
 'operation_id', gen_random_uuid(), 'items', '[]'::jsonb), 'outra sessão');
select pg_temp.err('Horário estruturalmente inválido recusado', 'save', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.v('lv')::int,
 'operation_id', gen_random_uuid(), 'items', jsonb_build_array(jsonb_build_object('title', 'x', 'date', '2026-10-20', 'start_time', '25:00'))), 'início inválido');
select pg_temp.err('Data impossível recusada', 'save', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.v('lv')::int,
 'operation_id', gen_random_uuid(), 'items', jsonb_build_array(jsonb_build_object('title', 'x', 'date', '2026-02-30'))), 'inválido');
select pg_temp.err('Chave repetida no rascunho recusada', 'save', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.v('lv')::int,
 'operation_id', gen_random_uuid(), 'items', jsonb_build_array(jsonb_build_object('key', '10000000-0000-4000-8000-000000000001', 'title', 'a'), jsonb_build_object('key', '10000000-0000-4000-8000-000000000001', 'title', 'b'))), 'repetida');
reset role;

-- Isolamento (PA-19, PA-20)
select pg_temp.as_user('03'); set local role authenticated;
do $$ declare d jsonb; begin
 d := public.audit_schedule('draft', jsonb_build_object('audit_id', pg_temp.id('A')));
 perform pg_temp.ok('PA-19 apoio consulta o cronograma sem editar', not (d->>'can_edit')::boolean and jsonb_array_length(d->'items') = 8);
end $$;
select pg_temp.err('PA-19 apoio não grava por chamada direta', 'save', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.v('lv')::int, 'operation_id', gen_random_uuid(), 'items', '[]'::jsonb), 'condutor');
reset role; select pg_temp.as_user('04'); set local role authenticated;
select pg_temp.err('Participante não lê rascunho do cronograma', 'draft', jsonb_build_object('audit_id', pg_temp.id('A')), 'indisponível');
reset role; select pg_temp.as_user('05'); set local role authenticated;
select pg_temp.err('PA-20 outra organização sem acesso', 'draft', jsonb_build_object('audit_id', pg_temp.id('A')), 'indisponível');
reset role;

-- Continuidade em atividade publicada (PA-17, RDA-08)
do $$ declare dayid uuid; s1 uuid; s2 uuid; begin
 insert into public.audit_days (audit_id, day_number, audit_date, status) values (pg_temp.id('A'), 1, '2026-10-20', 'in_progress') returning id into dayid;
 insert into public.schedule_items (audit_day_id, title, planned_start, planned_end, status, category, assignee_ids, actual_start)
 values (dayid, 'Compras', '2026-10-20 11:30+00', '2026-10-20 13:00+00', 'in_progress', 'assessment', array[pg_temp.id('lm')], '2026-10-20 11:35+00') returning id into s1;
 insert into public.schedule_requirements values (s1, pg_temp.id('r1'));
 insert into public.schedule_items (audit_day_id, title, planned_start, planned_end, status, category, assignee_ids) values (dayid, 'Manutenção', '2026-10-20 14:00+00', '2026-10-20 15:00+00', 'planned', 'assessment', array[pg_temp.id('lm')]) returning id into s2;
 insert into t_ids values ('s1', s1), ('s2', s2), ('day1', dayid);
end $$;
select pg_temp.as_user('02'); set local role authenticated;
select pg_temp.err('Parcial exige parcela realizada e restante', 'record_outcome', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.v('lv')::int,
 'operation_id', gen_random_uuid(), 'schedule_id', pg_temp.id('s1'), 'outcome', 'partial'), 'restante');
do $$ declare r jsonb; begin
 r := public.audit_schedule('record_outcome', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.v('lv')::int, 'operation_id', gen_random_uuid(),
  'schedule_id', pg_temp.id('s1'), 'outcome', 'partial', 'performed_summary', 'Avaliados fornecedores críticos', 'remaining_summary', 'Avaliar homologação de novos fornecedores', 'outcome_note', 'Tempo insuficiente'));
 update t_ids set v = r->>'lock_version' where k = 'lv';
 perform pg_temp.ok('PA-17 parcela realizada preservada na origem', exists (select 1 from jsonb_array_elements(r->'published') p where p->>'id' = pg_temp.v('s1')
  and p->>'outcome' = 'partial' and p->>'performed_summary' like 'Avaliados%' and p->>'actual_start' is not null and p->>'status' = 'in_progress'));
end $$;
reset role;
select pg_temp.ok('RDA-08 movimento registrado com antes/depois, motivo e autor', exists (select 1 from public.schedule_movements m where m.schedule_item_id = pg_temp.id('s1')
 and m.previous_data->>'outcome' is null and m.new_data->>'outcome' = 'partial' and m.reason = 'Tempo insuficiente' and m.created_by = 'a0000000-0000-4000-8000-000000000002'));
select pg_temp.as_user('02'); set local role authenticated;
select pg_temp.err('Não realizada exige motivo/encaminhamento', 'record_outcome', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.v('lv')::int,
 'operation_id', gen_random_uuid(), 'schedule_id', pg_temp.id('s2'), 'outcome', 'not_performed'), 'motivo');
do $$ declare r jsonb; d jsonb; begin
 r := public.audit_schedule('record_outcome', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.v('lv')::int, 'operation_id', gen_random_uuid(),
  'schedule_id', pg_temp.id('s2'), 'outcome', 'not_performed', 'outcome_note', 'Área parada; encaminhar para o dia 23'));
 update t_ids set v = r->>'lock_version' where k = 'lv';
 perform pg_temp.ok('Não realizada sem destino fica pendente explícita, sem conclusão fictícia', exists (select 1 from jsonb_array_elements(r->'published') p
  where p->>'id' = pg_temp.v('s2') and p->>'outcome' = 'not_performed' and p->>'status' = 'not_done'));
 -- Rascunho com o restante transferido (continuação), que será materializado na publicação (B09).
 r := public.audit_schedule('save', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.v('lv')::int, 'operation_id', gen_random_uuid(),
  'items', jsonb_build_array(jsonb_build_object('key', gen_random_uuid(), 'continuation_of', pg_temp.v('s1'), 'remaining_summary', 'Avaliar homologação', 'title', 'Compras (restante)',
   'process', 'Compras', 'date', '2026-10-23', 'start_time', '09:00', 'end_time', '10:00', 'location', 'Almoxarifado', 'assignee_ids', jsonb_build_array(pg_temp.v('lm')), 'requirements', jsonb_build_array(pg_temp.v('r1'))),
   jsonb_build_object('key', gen_random_uuid(), 'continuation_of', gen_random_uuid(), 'title', 'Origem inválida', 'category', 'other', 'date', '2026-10-23', 'start_time', '11:00', 'end_time', '12:00', 'location', 'X', 'assignee_ids', jsonb_build_array(pg_temp.v('lm'))))));
 perform pg_temp.ok('PA-17 restante transferido mantém vínculo com a origem e é nova atividade', r->'items'->0->>'continuation_of' = pg_temp.v('s1') and r->'items'->0->>'id' is null
  and not pg_temp.has_issue(r->'issues', r->'items'->0->>'key', 'continuation', 'error'));
 perform pg_temp.ok('Origem de continuação de outra auditoria recusada', pg_temp.has_issue(r->'issues', r->'items'->1->>'key', 'continuation', 'error'));
 update t_ids set v = r->>'lock_version' where k = 'lv';
end $$;
reset role;
update public.audit_days set status = 'completed' where id = pg_temp.id('day1');
select pg_temp.as_user('02'); set local role authenticated;
select pg_temp.err('Dia encerrado não recebe novo registro de execução', 'record_outcome', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.v('lv')::int,
 'operation_id', gen_random_uuid(), 'schedule_id', pg_temp.id('s1'), 'outcome', 'not_performed', 'outcome_note', 'tentativa'), 'encerrado');
reset role;

select n, name, ok, left(detail, 150) detail from t_res order by n;
