-- B09: PA-13–16/18/20–24, PER-09/10 — validação (15 verificações), Rev.00/Rev.01, PDF antes da publicação, aplicação ao cronograma
-- executável sem DELETE, projeção ao cliente e preservação do que foi executado. Banco local, transação revertida.
-- Contas: 001 Admin | 002 Líder X (condutor) | 003 Auditor X (apoio) | 004 Participante X (cliente) | 006 Participante Y
create temp table t_res (n serial, name text, ok boolean, detail text);
grant all on t_res to authenticated, service_role; grant usage on sequence t_res_n_seq to authenticated, service_role;
create temp table t_ids (k text primary key, v text); grant all on t_ids to authenticated, service_role;
create function pg_temp.as_user(uid text) returns void language sql as
 $$ select set_config('request.jwt.claims', json_build_object('sub', ('a0000000-0000-4000-8000-0000000000' || uid), 'role', 'authenticated')::text, true); $$;
create function pg_temp.id(key text) returns uuid language sql as $$ select v::uuid from t_ids where k = key $$;
create function pg_temp.v(key text) returns text language sql as $$ select v from t_ids where k = key $$;
create function pg_temp.ok(label text, cond boolean, info text default '') returns void language sql as
 $$ insert into t_res(name, ok, detail) values (label, coalesce(cond, false), info) $$;
create function pg_temp.err(label text, cmd text, payload jsonb, needle text) returns void language plpgsql as $$
begin perform public.audit_plan(cmd, payload); insert into t_res(name, ok, detail) values (label, false, 'sem erro');
exception when others then insert into t_res(name, ok, detail) values (label, position(lower(needle) in lower(sqlerrm)) > 0, sqlerrm); end $$;
create function pg_temp.check_errors(st jsonb, n int) returns jsonb language sql as $$ select c->'errors' from jsonb_array_elements(st->'checks') c where (c->>'n')::int = n $$;
create function pg_temp.lv() returns int language sql security definer as $$ select lock_version from public.audits where id = (select v::uuid from t_ids where k = 'A') $$;
create function pg_temp.emission(vid uuid) returns uuid language sql security definer as $$ select emission_id from public.audit_plan_versions where id = vid $$;
-- Processador simulado (B08): posse, "upload" e confirmação com o hash conferido.
create function pg_temp.emit(vid uuid) returns jsonb language plpgsql security definer as $$
declare eid uuid := pg_temp.emission(vid); c jsonb; begin
 c := private.b08_worker('claim', jsonb_build_object('emission_id', eid));
 return private.b08_worker('complete', jsonb_build_object('emission_id', eid, 'lease_token', c->>'lease_token', 'storage_path', c->>'storage_path',
   'pdf_sha256', md5(eid::text) || md5(vid::text), 'verified_sha256', md5(eid::text) || md5(vid::text), 'size_bytes', 5000, 'page_count', 4, 'engine_version', 'audita-pdf 1.0.0'));
end $$;
grant execute on all functions in schema pg_temp to authenticated, service_role;

-- Auditoria completa (cabeçalho, equipe, checklist confirmado com 3 requisitos, FPA suficiente).
do $$ declare aid uuid; lm uuid; am uuid; tid uuid; rid uuid; sid uuid; r1 uuid; r2 uuid; r3 uuid; iso uuid; fv uuid; begin
 select id into lm from public.organization_memberships where user_id = 'a0000000-0000-4000-8000-000000000002';
 select id into am from public.organization_memberships where user_id = 'a0000000-0000-4000-8000-000000000003';
 select id into iso from public.audit_types where code = 'ISO 9001';
 update public.organizations set address = '{"street":"Rua das Indústrias","number":"100","district":"Distrito Industrial","city":"Campinas","state":"SP","zip":"13000-000"}'
  where id = '0000000a-0000-4000-8000-00000000000a';
 insert into public.audits (organization_id, title, leader_membership_id, created_by, workspace_version, purpose, party, modality, declared_start_date, declared_end_date,
   timezone, location, objective, scope, evaluation_type, participants_text, comments, criterion_ids, team_reviewed)
 values ('0000000a-0000-4000-8000-00000000000a', 'Plano integrado', lm, 'a0000000-0000-4000-8000-000000000002', 1, 'A definir', 'second', 'presential', '2026-11-03', '2026-11-06',
   'America/Sao_Paulo', 'Planta Norte', 'Avaliar o sistema de gestão da qualidade', 'Processos de compras e produção da Planta Norte', 'certification', 'N/A', 'N/A', array[iso], true)
 returning id into aid;
 insert into public.audit_participants (audit_id, membership_id, participant_type) values (aid, lm, 'leader'), (aid, am, 'auditor');
 insert into public.checklist_templates (name, status, created_by) values ('Modelo 9001', 'published', 'a0000000-0000-4000-8000-000000000001') returning id into tid;
 insert into public.checklist_revisions (template_id, revision_number, status, created_by) values (tid, 1, 'draft', 'a0000000-0000-4000-8000-000000000001') returning id into rid;
 insert into public.checklist_sections (revision_id, title, sort_order, criterion_id) values (rid, '4 Contexto', 1, iso) returning id into sid;
 insert into public.checklist_requirements (section_id, reference, prompt, sort_order) values (sid, '4.1', 'Contexto', 1) returning id into r1;
 insert into public.checklist_requirements (section_id, reference, prompt, sort_order) values (sid, '4.2', 'Partes', 2) returning id into r2;
 insert into public.checklist_requirements (section_id, reference, prompt, sort_order) values (sid, '5.1', 'Liderança', 3) returning id into r3;
 update public.checklist_revisions set status = 'published', published_at = now() where id = rid;
 insert into public.audit_checklists (audit_id, revision_id, attached_by) values (aid, rid, 'a0000000-0000-4000-8000-000000000001');
 update public.audits set checklist_confirmed_at = now(), checklist_confirmed_by = 'a0000000-0000-4000-8000-000000000002' where id = aid;
 insert into private.audit_fpa (audit_id, status, requested_at, requested_by, recipient_name) values (aid, 'requested', now(), 'a0000000-0000-4000-8000-000000000002', 'Gestora');
 insert into private.audit_fpa_versions (audit_id, version_number, format, storage_path, filename, size_bytes, sha256, mime_type, received_on, registered_by)
 values (aid, 1, 'pdf', 'x/fpa.pdf', 'fpa.pdf', 1000, repeat('a', 64), 'application/pdf', '2026-10-20', 'a0000000-0000-4000-8000-000000000002') returning id into fv;
 insert into t_ids values ('A', aid), ('lm', lm), ('am', am), ('r1', r1), ('r2', r2), ('r3', r3), ('fv', fv),
  ('k1', gen_random_uuid()), ('k2', gen_random_uuid()), ('k3', gen_random_uuid()), ('k4', gen_random_uuid());
end $$;

select pg_temp.as_user('02'); set local role authenticated;
do $$ declare s jsonb; d jsonb; begin
 d := public.audit_schedule('draft', jsonb_build_object('audit_id', pg_temp.id('A')));
 perform public.audit_schedule('save', jsonb_build_object('audit_id', pg_temp.id('A'), 'operation_id', gen_random_uuid(), 'expected_lock_version', (d->>'lock_version')::int, 'items', jsonb_build_array(
  jsonb_build_object('key', pg_temp.id('k1'), 'title', 'Reunião de abertura', 'category', 'opening', 'date', '2026-11-03', 'start_time', '08:00', 'end_time', '08:30', 'location', 'Sala 1', 'assignee_ids', jsonb_build_array(pg_temp.id('lm'))),
  jsonb_build_object('key', pg_temp.id('k2'), 'title', 'Compras', 'process', 'Compras', 'category', 'assessment', 'date', '2026-11-03', 'start_time', '08:30', 'end_time', '10:00', 'location', 'Suprimentos',
    'assignee_ids', jsonb_build_array(pg_temp.id('lm'), pg_temp.id('am')), 'requirements', jsonb_build_array(pg_temp.id('r1'), pg_temp.id('r2'))),
  jsonb_build_object('key', pg_temp.id('k3'), 'title', 'Produção', 'process', 'Produção', 'category', 'assessment', 'date', '2026-11-05', 'start_time', '09:00', 'end_time', '11:00', 'location', 'Linha 2',
    'assignee_ids', jsonb_build_array(pg_temp.id('am')), 'requirements', jsonb_build_array(pg_temp.id('r3'))))));
 s := public.audit_plan('status', jsonb_build_object('audit_id', pg_temp.id('A')));
 perform pg_temp.ok('Lista com as 15 verificações numeradas e etapa de correção', jsonb_array_length(s->'checks') = 15
   and (select bool_and(c ? 'step' and c ? 'label') from jsonb_array_elements(s->'checks') c), s->>'ok');
 perform pg_temp.ok('PA-11/14 FPA ainda não suficiente bloqueia a validação', not (s->>'ok')::boolean and jsonb_array_length(pg_temp.check_errors(s, 14)) = 1
   and (select count(*) from jsonb_array_elements(s->'checks') c where not (c->>'ok')::boolean) = 1, pg_temp.check_errors(s, 14)::text);
 perform pg_temp.ok('Primeira revisão será Rev.00, sem motivo obrigatório', s->>'next_label' = 'Rev.00' and not (s->>'requires_reason')::boolean);
 perform pg_temp.err('Validação bloqueada com pendência', 'validate', jsonb_build_object('audit_id', pg_temp.id('A'), 'operation_id', gen_random_uuid(), 'expected_lock_version', pg_temp.lv()), '1 verificação');
end $$;
reset role;
update private.audit_fpa set status = 'sufficient', sufficient_version_id = pg_temp.id('fv'), analyzed_at = now(), analyzed_by = 'a0000000-0000-4000-8000-000000000002' where audit_id = pg_temp.id('A');
-- Verificações individuais (cada uma desfeita em seguida).
do $$ declare s jsonb; begin
 update public.audits set location = ' ', comments = null, scope = null, team_reviewed = false, checklist_confirmed_at = null where id = pg_temp.id('A');
 s := private.b09_checks(pg_temp.id('A'), -5);
 perform pg_temp.ok('Verificações 3, 7, 8, 9, 13 e 15 apontam o campo pendente', jsonb_array_length(pg_temp.check_errors(s, 3)) = 1 and jsonb_array_length(pg_temp.check_errors(s, 7)) = 1
   and jsonb_array_length(pg_temp.check_errors(s, 8)) = 1 and jsonb_array_length(pg_temp.check_errors(s, 9)) = 1 and jsonb_array_length(pg_temp.check_errors(s, 13)) = 1
   and jsonb_array_length(pg_temp.check_errors(s, 15)) = 1 and (select c->>'step' from jsonb_array_elements(s->'checks') c where (c->>'n')::int = 7) = 'team', (s->'checks')::text);
 update public.audits set location = 'Planta Norte', comments = 'N/A', scope = 'Processos de compras e produção da Planta Norte', team_reviewed = true, checklist_confirmed_at = now() where id = pg_temp.id('A');
end $$;

-- Validação: Rev.00 congelada, PDF pedido, nada publicado ainda (PA-13, PER-09).
select pg_temp.as_user('02'); set local role authenticated;
do $$ declare op uuid := gen_random_uuid(); r jsonb; r2 jsonb; s jsonb; begin
 s := public.audit_plan('status', jsonb_build_object('audit_id', pg_temp.id('A')));
 perform pg_temp.ok('Todas as verificações aprovadas; aviso separado dos bloqueios', (s->>'ok')::boolean, (s->'warnings')::text);
 r := public.audit_plan('validate', jsonb_build_object('audit_id', pg_temp.id('A'), 'operation_id', op, 'expected_lock_version', pg_temp.lv()));
 r2 := public.audit_plan('validate', jsonb_build_object('audit_id', pg_temp.id('A'), 'operation_id', op, 'expected_lock_version', 0));
 insert into t_ids values ('V0', r->>'version_id');
 perform pg_temp.ok('PA-14 duplo clique devolve a mesma revisão', r::text = r2::text and r->>'revision_label' = 'Rev.00' and r->'emission'->>'status' = 'pending', r::text);
 perform pg_temp.err('Outra validação com revisão aguardando PDF é recusada', 'validate', jsonb_build_object('audit_id', pg_temp.id('A'), 'operation_id', gen_random_uuid(), 'expected_lock_version', pg_temp.lv()), 'aguardando o PDF');
end $$;
reset role;
do $$ declare v public.audit_plan_versions%rowtype; e private.document_emissions; a public.audits%rowtype; begin
 select * into v from public.audit_plan_versions where id = pg_temp.id('V0');
 select * into e from private.document_emissions where id = v.emission_id;
 select * into a from public.audits where id = pg_temp.id('A');
 perform pg_temp.ok('Revisão congelada com SHA-256 e pedido de emissão com o mesmo conteúdo', v.state = 'validated' and v.content_sha256 = e.content_sha256
   and e.content::text = v.content::text and e.filename = a.code || '_Plano_Rev00.pdf' and e.auto_publish, e.filename);
 perform pg_temp.ok('Emissão acionada pelo servidor (pg_net)', exists (select 1 from private.document_emission_tickets k where k.emission_id = e.id)
   and exists (select 1 from net.stub_requests where body->>'action' = 'ticket'));
 perform pg_temp.ok('PER-09 antes do PDF: plano não publicado e execução não liberada', a.plan_revision = 0 and a.status = 'draft'
   and not exists (select 1 from public.schedule_items s join public.audit_days d on d.id = s.audit_day_id where d.audit_id = a.id));
 perform pg_temp.ok('Retrato completo: cliente, CNPJ, endereço, critérios, natureza, tipo e equipe', v.content->'client'->>'code' = 'CLI-0001'
   and v.content->'client'->>'address' like 'Rua das Indústrias, 100 · Distrito Industrial · Campinas/SP · CEP%' and v.content->'header'->'criteria'->0->>'code' = 'ISO 9001'
   and v.content->'header'->>'party' = '2ª parte' and v.content->'header'->>'evaluation' = 'Certificação'
   and v.content->'team'->0->>'role' = 'Condutor' and v.content->'team'->1->>'name' = 'Auditor X Teste', (v.content->'client')::text);
 perform pg_temp.ok('PA-22 cronograma com dias não consecutivos numerados 1 e 2', (select jsonb_agg(d->>'day_number' order by d->>'date') from jsonb_array_elements(v.content->'days') d) = '["1","2"]'
   and v.content->'schedule'->1->'assignees' = '["Auditor X Teste", "Lider X Teste"]' and v.content->'schedule'->1->'requirement_refs'->0->>'reference' = '4.1', (v.content->'schedule'->1)::text);
 perform pg_temp.ok('Nove notas do Anexo A integrais (modelo v1) e FPA de referência', jsonb_array_length(v.content->'notes') = 9 and v.content->'notes' = private.b09_plan_notes(1)
   and (v.content->'fpa'->>'version_number')::int = 1 and not (v.content->'fpa' ? 'storage_path'), (v.content->'fpa')::text);
end $$;
select pg_temp.as_user('04'); set local role authenticated;
select pg_temp.err('PER-09 cliente não vê plano ainda não publicado', 'versions', jsonb_build_object('audit_id', pg_temp.id('A')), 'indisponível');
reset role;

-- PDF íntegro → publicação → aplicação ao cronograma executável (PA-13).
do $$ declare r jsonb; a public.audits%rowtype; begin
 r := pg_temp.emit(pg_temp.id('V0'));
 select * into a from public.audits where id = pg_temp.id('A');
 perform pg_temp.ok('PA-13 publicado só após o PDF: Rev.00 vigente, plano liberado', r->'emission'->>'status' = 'published' and a.plan_revision = 1 and a.status = 'planned'
   and (select state from public.audit_plan_versions where id = pg_temp.id('V0')) = 'published', r::text);
 perform pg_temp.ok('Cronograma materializado com as identidades do rascunho', (select count(*) from public.schedule_items where id in (pg_temp.id('k1'), pg_temp.id('k2'), pg_temp.id('k3')) and not withdrawn) = 3
   and (select assignee_ids @> array[pg_temp.id('lm'), pg_temp.id('am')] and cardinality(assignee_ids) = 2 from public.schedule_items where id = pg_temp.id('k2'))
   and (select count(*) from public.schedule_requirements where schedule_item_id = pg_temp.id('k2')) = 2
   and (select string_agg(day_number::text || '@' || audit_date, ',' order by audit_date) from public.audit_days where audit_id = a.id) = '1@2026-11-03,2@2026-11-05'
   and (select bool_and(x->>'id' = x->>'key') from jsonb_array_elements(a.plan_draft) x), a.plan_draft::text);
 perform pg_temp.ok('Notificação no sino uma única vez por destinatário', (select count(*) from public.in_app_notifications where event_type = 'audit_plan' and entity_id = a.id) > 0
   and (select count(*) = count(distinct recipient_id) from public.in_app_notifications where event_type = 'audit_plan' and entity_id = a.id));
end $$;
select pg_temp.as_user('04'); set local role authenticated;
do $$ declare r jsonb; d jsonb; begin
 r := public.audit_plan('versions', jsonb_build_object('audit_id', pg_temp.id('A')));
 d := public.document_emission('authorize_download', jsonb_build_object('emission_id', r->'versions'->0->>'emission_id'));
 perform pg_temp.ok('PA-20/D02 cliente da organização consulta e baixa o plano publicado', r->'versions'->0->>'revision_label' = 'Rev.00' and d->>'filename' like '%_Plano_Rev00.pdf'
   and not (r::text like '%storage_path%') and not (r::text like '%"content"%'), r::text);
 perform pg_temp.err('Cliente não valida nem vê a lista interna', 'status', jsonb_build_object('audit_id', pg_temp.id('A')), 'indisponível');
end $$;
reset role; select pg_temp.as_user('06'); set local role authenticated;
select pg_temp.err('PA-20 outra organização não consulta o plano', 'versions', jsonb_build_object('audit_id', pg_temp.id('A')), 'indisponível');
do $$ begin perform public.document_emission('authorize_download', jsonb_build_object('emission_id', pg_temp.emission(pg_temp.id('V0'))));
 perform pg_temp.ok('PA-20 outra organização não baixa o PDF por chamada direta', false);
exception when others then perform pg_temp.ok('PA-20 outra organização não baixa o PDF por chamada direta', position('não encontrado' in sqlerrm) > 0, sqlerrm); end $$;
reset role;

-- Rev.01: mover, encolher escopo (nova identidade), incluir e omitir; Rev.00 continua vigente até o novo PDF (PA-15, PER-10).
select pg_temp.as_user('02'); set local role authenticated;
do $$ declare d jsonb; r jsonb; begin
 perform public.audit_workspace('start', jsonb_build_object('audit_id', pg_temp.id('A')));
 d := public.audit_schedule('draft', jsonb_build_object('audit_id', pg_temp.id('A')));
 perform public.audit_schedule('save', jsonb_build_object('audit_id', pg_temp.id('A'), 'operation_id', gen_random_uuid(), 'expected_lock_version', (d->>'lock_version')::int, 'items', jsonb_build_array(
  jsonb_build_object('key', pg_temp.id('k1'), 'id', pg_temp.id('k1'), 'title', 'Reunião de abertura', 'category', 'opening', 'date', '2026-11-03', 'start_time', '08:00', 'end_time', '08:30', 'location', 'Sala 1', 'assignee_ids', jsonb_build_array(pg_temp.id('lm'))),
  jsonb_build_object('key', pg_temp.id('k2'), 'id', pg_temp.id('k2'), 'title', 'Compras', 'process', 'Compras', 'category', 'assessment', 'date', '2026-11-04', 'start_time', '09:00', 'end_time', '10:30', 'location', 'Suprimentos',
    'assignee_ids', jsonb_build_array(pg_temp.id('lm')), 'requirements', jsonb_build_array(pg_temp.id('r1'))),
  jsonb_build_object('key', pg_temp.id('k4'), 'title', 'Partes interessadas', 'process', 'Direção', 'category', 'assessment', 'date', '2026-11-04', 'start_time', '10:30', 'end_time', '11:30', 'location', 'Diretoria',
    'assignee_ids', jsonb_build_array(pg_temp.id('lm')), 'requirements', jsonb_build_array(pg_temp.id('r2'), pg_temp.id('r3'))))));
 perform pg_temp.err('PA-15 nova revisão exige motivo', 'validate', jsonb_build_object('audit_id', pg_temp.id('A'), 'operation_id', gen_random_uuid(), 'expected_lock_version', pg_temp.lv()), 'motivo');
 r := public.audit_plan('validate', jsonb_build_object('audit_id', pg_temp.id('A'), 'operation_id', gen_random_uuid(), 'expected_lock_version', pg_temp.lv(), 'reason', 'Compras transferida para 04/11 a pedido do cliente'));
 insert into t_ids values ('V1', r->>'version_id');
 perform pg_temp.ok('Rev.01 validada', r->>'revision_label' = 'Rev.01');
end $$;
reset role;
do $$ declare a public.audits%rowtype; begin
 select * into a from public.audits where id = pg_temp.id('A');
 perform pg_temp.ok('PER-10 enquanto o PDF da Rev.01 é gerado, a Rev.00 segue vigente e o cronograma não muda', a.plan_revision = 1
   and (select state from public.audit_plan_versions where id = pg_temp.id('V0')) = 'published'
   and (select d.audit_date from public.schedule_items s join public.audit_days d on d.id = s.audit_day_id where s.id = pg_temp.id('k2')) = '2026-11-03');
 perform pg_temp.emit(pg_temp.id('V1'));
 select * into a from public.audits where id = pg_temp.id('A');
 perform pg_temp.ok('Rev.01 publicada; Rev.00 substituída e preservada', a.plan_revision = 2
   and (select state || '>' || (superseded_by = pg_temp.id('V1'))::text from public.audit_plan_versions where id = pg_temp.id('V0')) = 'superseded>true'
   and (select content->'revision'->>'label' from public.audit_plan_versions where id = pg_temp.id('V0')) = 'Rev.00');
 perform pg_temp.ok('Atividade não iniciada que perdeu requisito ganha nova identidade, com rastreio', (select withdrawn and replaced_by is not null from public.schedule_items where id = pg_temp.id('k2'))
   and (select count(*) from public.schedule_requirements where schedule_item_id = (select replaced_by from public.schedule_items where id = pg_temp.id('k2'))) = 1
   and (select x->>'id' from jsonb_array_elements(a.plan_draft) x where x->>'key' = pg_temp.v('k2')) = (select replaced_by::text from public.schedule_items where id = pg_temp.id('k2')));
 perform pg_temp.ok('Omitida na revisão fica retirada; movimento registrado com o motivo', (select withdrawn from public.schedule_items where id = pg_temp.id('k3'))
   and exists (select 1 from public.schedule_movements where schedule_item_id = pg_temp.id('k3') and reason like 'Retirada — Rev.01: Compras transferida%'));
 perform pg_temp.ok('PA-22 dia sem atividade retirado e numerado após os ativos; nova data numerada em ordem', (select string_agg(day_number::text || '@' || audit_date || case when withdrawn then '*' else '' end, ',' order by day_number)
   from public.audit_days where audit_id = a.id) = '1@2026-11-03,2@2026-11-04,3@2026-11-05*',
   (select string_agg(day_number::text || '@' || audit_date || case when withdrawn then '*' else '' end, ',' order by day_number) from public.audit_days where audit_id = a.id));
end $$;

-- Execução registrada é preservada: atividade iniciada não sai do plano nem perde requisitos (validação e aplicação).
select pg_temp.as_user('02'); set local role authenticated;
do $$ declare d jsonb; s jsonb; nid uuid; begin
 select replaced_by into nid from public.schedule_items where id = pg_temp.id('k2');
 insert into t_ids values ('k2b', nid);
 perform public.audit_workspace('activity_start', jsonb_build_object('audit_id', pg_temp.id('A'), 'schedule_id', pg_temp.id('k1')));
 d := public.audit_schedule('draft', jsonb_build_object('audit_id', pg_temp.id('A')));
 perform public.audit_schedule('save', jsonb_build_object('audit_id', pg_temp.id('A'), 'operation_id', gen_random_uuid(), 'expected_lock_version', (d->>'lock_version')::int,
  'items', (select jsonb_agg(x) from jsonb_array_elements(d->'items') x where x->>'key' <> pg_temp.v('k1'))));
 s := public.audit_plan('status', jsonb_build_object('audit_id', pg_temp.id('A')));
 perform pg_temp.ok('Atividade iniciada não pode ser retirada (bloqueio na verificação 10)', not (s->>'ok')::boolean
   and pg_temp.check_errors(s, 10)::text like '%Atividade iniciada não pode ser retirada do plano: Reunião de abertura%', pg_temp.check_errors(s, 10)::text);
end $$;
do $$ begin perform public.audit_workspace('plan_publish', jsonb_build_object('audit_id', pg_temp.id('A'), 'reason', 'x', 'lock_version', pg_temp.lv()));
 perform pg_temp.ok('plan_publish legado recusado', false);
exception when others then perform pg_temp.ok('plan_publish legado recusado', position('validação com PDF' in sqlerrm) > 0, sqlerrm); end $$;
-- Publicação bloqueada na aplicação: o PDF íntegro fica pronto, a revisão pode ser descartada (sem nova tentativa automática).
reset role;
do $$ declare items jsonb; begin
 -- Restaura o rascunho publicado (Rev.01) com uma alteração de horário em k4.
 select jsonb_agg(case when x->>'key' = pg_temp.v('k4') then x || '{"end_time":"12:00"}'::jsonb else x end) into items
  from jsonb_array_elements((select content->'schedule' from public.audit_plan_versions where id = pg_temp.id('V1'))) x;
 update public.audits set plan_draft = items where id = pg_temp.id('A');
end $$;
select pg_temp.as_user('01'); set local role authenticated;
do $$ declare r jsonb; begin
 r := public.audit_plan('validate', jsonb_build_object('audit_id', pg_temp.id('A'), 'operation_id', gen_random_uuid(), 'expected_lock_version', pg_temp.lv(), 'reason', 'Ajuste de horário da direção'));
 insert into t_ids values ('V2', r->>'version_id');
 perform pg_temp.ok('PA-24 Administrador sozinho valida e publica, sem aprovador adicional', r->>'revision_label' = 'Rev.02', r::text);
end $$;
reset role;
do $$ declare r jsonb; begin
 -- Entre a validação e o PDF, o dia 04/11 é encerrado: a aplicação não pode alterar um dia encerrado.
 update public.audit_days set status = 'completed', started_at = now(), ended_at = now() where audit_id = pg_temp.id('A') and audit_date = '2026-11-04';
 r := pg_temp.emit(pg_temp.id('V2'));
 perform pg_temp.ok('Bloqueio na aplicação: PDF íntegro fica pronto com o motivo, sem publicar', r->'emission'->>'status' = 'ready'
   and r->'emission'->>'last_error' like 'Arquivo íntegro; publicação bloqueada:%' and (select state from public.audit_plan_versions where id = pg_temp.id('V2')) = 'validated'
   and (select plan_revision from public.audits where id = pg_temp.id('A')) = 2, r->'emission'->>'last_error');
 perform pg_temp.ok('Pronto não volta para a varredura automática', private.b08_sweep() = 0);
end $$;
select pg_temp.as_user('02'); set local role authenticated;
do $$ declare r jsonb; begin
 r := public.audit_plan('publish_ready', jsonb_build_object('version_id', pg_temp.id('V2')));
 perform pg_temp.ok('Publicar novamente continua bloqueado e informa o motivo', not (r->>'published')::boolean and r->>'blocked' like '%Dia 04/11 encerrado%', r::text);
end $$;
select pg_temp.err('Descartar exige motivo', 'discard', jsonb_build_object('version_id', pg_temp.id('V2')), 'motivo');
do $$ declare r jsonb; s jsonb; begin
 r := public.audit_plan('discard', jsonb_build_object('version_id', pg_temp.id('V2'), 'reason', 'Dia 04/11 encerrado antes da publicação'));
 s := public.audit_plan('status', jsonb_build_object('audit_id', pg_temp.id('A')));
 perform pg_temp.ok('Revisão descartada sai da fila; histórico preserva todas', (r->>'discarded')::boolean and s->>'open' is null and s->>'next_label' = 'Rev.02'
   and (select string_agg(x->>'revision_label' || ':' || (x->>'state'), ',' order by (x->>'version_number')::int) from jsonb_array_elements(s->'versions') x) = 'Rev.00:superseded,Rev.01:published,Rev.02:discarded',
   coalesce(s->>'open','sem-open') || ' | ' || (s->>'next_label') || ' | ' || (select string_agg(x->>'revision_label' || ':' || (x->>'state'), ',' order by (x->>'version_number')::int) from jsonb_array_elements(s->'versions') x));
end $$;
reset role;

-- PA-16 / imutabilidade: cadastro alterado não muda revisão nem PDF já emitido.
do $$ declare h text; begin
 select content_sha256 into h from public.audit_plan_versions where id = pg_temp.id('V0');
 update public.organizations set legal_name = 'TESTE Organização X Renomeada' where id = '0000000a-0000-4000-8000-00000000000a';
 perform pg_temp.ok('PA-16 revisão emitida mantém o cabeçalho original', (select content->'client'->>'legal_name' from public.audit_plan_versions where id = pg_temp.id('V0')) = 'TESTE Organização X'
   and (select content->'client'->>'legal_name' from private.document_emissions where id = pg_temp.emission(pg_temp.id('V0'))) = 'TESTE Organização X'
   and (select encode(sha256(convert_to(content::text, 'UTF8')), 'hex') from public.audit_plan_versions where id = pg_temp.id('V0')) = h);
 begin update public.audit_plan_versions set content = '{}' where id = pg_temp.id('V0'); perform pg_temp.ok('Conteúdo de revisão é imutável', false);
 exception when others then perform pg_temp.ok('Conteúdo de revisão é imutável', position('imutável' in sqlerrm) > 0, sqlerrm); end;
 begin delete from public.audit_plan_versions where id = pg_temp.id('V0'); perform pg_temp.ok('Revisão não é excluída', false);
 exception when others then perform pg_temp.ok('Revisão não é excluída', position('não são excluídas' in sqlerrm) > 0, sqlerrm); end;
end $$;
select n, name, ok, left(detail, 140) from t_res order by n;
