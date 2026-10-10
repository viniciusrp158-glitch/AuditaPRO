-- B06: PA-01..06, PA-11/12, PA-19/20, PA-23 (identificação), PER-03/04/08 e D09, no banco local (transação revertida).
-- Contas (scripts/localdb/10-fixtures.sql): 001 Admin | 002 Líder X | 003 Auditor X | 004 Participante X | 005 Líder Y | 009 Líder2 X
create temp table t_res (n serial, name text, ok boolean, detail text);
grant all on t_res to authenticated; grant usage on sequence t_res_n_seq to authenticated;
create temp table t_ids (k text primary key, v text); grant all on t_ids to authenticated;
create function pg_temp.as_user(uid text) returns void language sql as
 $$ select set_config('request.jwt.claims', json_build_object('sub', ('a0000000-0000-4000-8000-0000000000' || uid), 'role', 'authenticated')::text, true); $$;
create function pg_temp.id(key text) returns uuid language sql as $$ select v::uuid from t_ids where k = key $$;
create function pg_temp.lv(key text) returns int language sql as $$ select v::int from t_ids where k = key $$;
create function pg_temp.ok(label text, cond boolean, info text default '') returns void language sql as
 $$ insert into t_res(name, ok, detail) values (label, coalesce(cond, false), info) $$;
create function pg_temp.err(label text, fn text, cmd text, payload jsonb, needle text) returns void language plpgsql as $$
begin
 if fn = 'id' then perform public.audit_identification(cmd, payload); else perform public.audit_fpa(cmd, payload); end if;
 insert into t_res(name, ok, detail) values (label, false, 'sem erro');
exception when others then insert into t_res(name, ok, detail) values (label, position(lower(needle) in lower(sqlerrm)) > 0, sqlerrm);
end $$;
update public.audit_types set edition = '2015' where code = 'ISO 14001';
update public.audit_types set edition = '2018' where code = 'ISO 45001';
insert into t_ids select 'c14', id from public.audit_types where code = 'ISO 14001';
insert into t_ids select 'c45', id from public.audit_types where code = 'ISO 45001';
update public.organizations set address = '{"street":"Rua Teste","number":"100","city":"Curitiba","state":"PR"}' where id = '0000000a-0000-4000-8000-00000000000a';

-- ===== Criação de rascunho (PA-01/02/04) =====
select pg_temp.as_user('02'); set local role authenticated;
do $$ declare r jsonb; r2 jsonb; m uuid; begin
 r := public.audit_identification('create_draft', jsonb_build_object('operation_id', '11111111-1111-4111-8111-000000000001',
  'organization_id', '0000000a-0000-4000-8000-00000000000a'));
 r2 := public.audit_identification('create_draft', jsonb_build_object('operation_id', '11111111-1111-4111-8111-000000000001',
  'organization_id', '0000000a-0000-4000-8000-00000000000a'));
 perform pg_temp.ok('PA-04 rascunho sem título/escopo/critério', r->>'audit_id' is not null, r::text);
 perform pg_temp.ok('PA-02 duplo clique não duplica', r = r2);
 insert into t_ids values ('A', r->>'audit_id'), ('codeA', r->>'code');
end $$;
reset role;
select pg_temp.as_user('01'); set local role authenticated;
do $$ declare r jsonb; begin
 r := public.audit_identification('create_draft', jsonb_build_object('operation_id', '11111111-1111-4111-8111-000000000002',
  'organization_id', '0000000a-0000-4000-8000-00000000000a', 'title', 'Auditoria integrada',
  'leader_membership_id', (select m.id from public.organization_memberships m where m.user_id = 'a0000000-0000-4000-8000-000000000002')));
 insert into t_ids values ('B', r->>'audit_id'), ('codeB', r->>'code');
 perform pg_temp.ok('PA-01 códigos de auditoria distintos e estáveis', (select v from t_ids where k='codeA') <> r->>'code'
  and r->>'code' ~ '^AUD-[0-9]{4}-[0-9]+$', (select v from t_ids where k='codeA') || ' / ' || (r->>'code'));
end $$;
reset role;
select pg_temp.ok('PA-01 mesmo código de cliente nas duas auditorias',
 (select count(distinct o.code) from public.audits a join public.organizations o on o.id = a.organization_id where a.id in (pg_temp.id('A'), pg_temp.id('B'))) = 1);
select pg_temp.ok('PA-02 unicidade garantida no banco', exists (select 1 from pg_indexes where tablename = 'audits' and indexdef ilike '%unique%(code)%'));
select pg_temp.as_user('04'); set local role authenticated;
select pg_temp.err('PER-05 participante não cria auditoria', 'id', 'create_draft', jsonb_build_object('operation_id', gen_random_uuid(), 'organization_id', '0000000a-0000-4000-8000-00000000000a'), 'permissão');
reset role; select pg_temp.as_user('03'); set local role authenticated;
select pg_temp.err('PER-04 auditor não cria auditoria', 'id', 'create_draft', jsonb_build_object('operation_id', gen_random_uuid(), 'organization_id', '0000000a-0000-4000-8000-00000000000a'), 'permissão');
reset role;

-- ===== Identificação (PA-03/05/06, PA-23) =====
select pg_temp.as_user('02'); set local role authenticated;
do $$ declare d jsonb; s jsonb; begin
 d := public.audit_identification('detail', jsonb_build_object('audit_id', pg_temp.id('A')));
 perform pg_temp.ok('PA-03 código e endereço do cliente automáticos', d->'identification'->'client'->>'code' = 'CLI-0001'
  and d->'identification'->'client'->'address'->>'city' = 'Curitiba', d->'identification'->>'client');
 perform pg_temp.ok('Condutor na equipe e pode editar', (d->>'can_edit')::boolean and d->'identification'->'team'->0->>'conductor' = 'true', d->'identification'->>'team');
 s := public.audit_identification('save', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', (d->'identification'->>'lock_version')::int,
  'title', 'Auditoria integrada SGA/SST', 'criterion_ids', jsonb_build_array(pg_temp.id('c14'), pg_temp.id('c45')),
  'party', 'third', 'modality', 'hybrid', 'evaluation_type', 'certification', 'declared_start_date', '2026-10-20', 'declared_end_date', '2026-10-23',
  'participants_text', 'N/A', 'comments', 'N/A', 'location', 'Rua Teste, 100 · Curitiba · PR', 'objective', 'Avaliar conformidade'));
 insert into t_ids values ('lvA', s->>'lock_version');
 d := public.audit_identification('detail', jsonb_build_object('audit_id', pg_temp.id('A')));
 perform pg_temp.ok('PA-04 escopo pode ficar vazio no rascunho', d->'identification'->>'scope' is null);
 perform pg_temp.ok('PA-05 N/A aceito em participantes e comentários', d->'identification'->>'participants_text' = 'N/A' and d->'identification'->>'comments' = 'N/A');
 perform pg_temp.ok('PA-05 natureza, tipo de avaliação e período gravados', d->'identification'->>'party' = 'third' and d->'identification'->>'evaluation_type' = 'certification'
  and d->'identification'->>'declared_end_date' = '2026-10-23');
 perform pg_temp.ok('PA-06 dois critérios com edições próprias', jsonb_array_length(d->'identification'->'criteria_items') = 2
  and d->'identification'->'standards' @> '["ISO 14001:2015","ISO 45001:2018"]', d->'identification'->>'standards');
end $$;
select pg_temp.err('PA-23 versão desatualizada recusada', 'id', 'save', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', 0, 'title', 'Outro'), 'outra sessão');
select pg_temp.err('Tipo de avaliação inválido recusado', 'id', 'save', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.lv('lvA'), 'title', 'X1', 'evaluation_type', 'interna'), 'inválid');
select pg_temp.err('Período com fim antes do início recusado', 'id', 'save', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.lv('lvA'), 'title', 'X1',
 'declared_start_date', '2026-10-20', 'declared_end_date', '2026-10-01'), 'inválid');
select pg_temp.err('Unidade de outra empresa recusada', 'id', 'save', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.lv('lvA'), 'title', 'X1',
 'unit_id', gen_random_uuid()), 'unidade');
reset role;

-- ===== Isolamento (PER-04/08, PA-19/20) =====
select pg_temp.as_user('09'); set local role authenticated;
select pg_temp.err('PER-08 outro Líder da mesma empresa não acessa', 'id', 'detail', jsonb_build_object('audit_id', pg_temp.id('A')), 'indisponível');
reset role; select pg_temp.as_user('05'); set local role authenticated;
select pg_temp.err('PA-20 Líder de outra organização não acessa', 'id', 'detail', jsonb_build_object('audit_id', pg_temp.id('A')), 'indisponível');
select pg_temp.err('PA-20 FPA de outra organização recusada', 'fpa', 'detail', jsonb_build_object('audit_id', pg_temp.id('A')), 'indisponível');
reset role; select pg_temp.as_user('04'); set local role authenticated;
select pg_temp.err('Participante não lê rascunho do cabeçalho', 'id', 'detail', jsonb_build_object('audit_id', pg_temp.id('A')), 'indisponível');
reset role; select pg_temp.as_user('03'); set local role authenticated;
select pg_temp.err('Auditor fora da equipe não acessa', 'id', 'detail', jsonb_build_object('audit_id', pg_temp.id('A')), 'indisponível');
reset role;
select pg_temp.as_user('01');
insert into public.audit_participants (audit_id, membership_id, participant_type) select pg_temp.id('A'), m.id, 'auditor'
 from public.organization_memberships m where m.user_id = 'a0000000-0000-4000-8000-000000000003';
select pg_temp.as_user('03'); set local role authenticated;
do $$ declare d jsonb; begin
 d := public.audit_identification('detail', jsonb_build_object('audit_id', pg_temp.id('A')));
 perform pg_temp.ok('PA-19 apoio aparece na equipe sem poder editar', not (d->>'can_edit')::boolean
  and exists (select 1 from jsonb_array_elements(d->'identification'->'team') t where t->>'role' = 'auditor'), d->'identification'->>'team');
end $$;
select pg_temp.err('PER-04 apoio não edita por chamada direta', 'id', 'save', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.lv('lvA'), 'title', 'Invasão'), 'condutor');
reset role;

-- ===== FPA (PA-11/12, D09) =====
select pg_temp.as_user('02'); set local role authenticated;
do $$ declare f jsonb; begin
 f := public.audit_fpa('detail', jsonb_build_object('audit_id', pg_temp.id('A')));
 perform pg_temp.ok('D09 auditoria sem FPA inventada', f->>'status' = 'not_requested' and jsonb_array_length(f->'versions') = 0, f::text);
end $$;
select pg_temp.err('D09 sem recebimento antes da solicitação', 'fpa', 'authorize_upload', jsonb_build_object('audit_id', pg_temp.id('A'), 'format', 'pdf'), 'solicitação');
select pg_temp.err('Solicitação exige destinatário', 'fpa', 'request', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', 1), 'destinatário');
do $$ declare f jsonb; up jsonb; begin
 f := public.audit_fpa('request', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', 1, 'recipient_name', 'Gestora da Qualidade', 'due_date', '2026-10-15'));
 perform pg_temp.ok('FPA solicitada com destinatário e prazo', f->>'status' = 'requested' and f->>'recipient_name' = 'Gestora da Qualidade' and f->>'due_date' = '2026-10-15', f::text);
 insert into t_ids values ('lvF', f->>'lock_version');
 up := public.audit_fpa('authorize_upload', jsonb_build_object('audit_id', pg_temp.id('A'), 'format', 'xlsx'));
 insert into t_ids values ('p1', up->>'path');
end $$;
select pg_temp.err('Concorrência na FPA detectada', 'fpa', 'start_analysis', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', 1), 'outra sessão');
select pg_temp.err('Recebimento sem arquivo no armazenamento recusado', 'fpa', 'register_file', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.lv('lvF'),
 'format', 'xlsx', 'path', (select v from t_ids where k = 'p1'), 'filename', 'fpa.xlsx', 'size_bytes', 500, 'sha256', repeat('c', 64), 'mime_type', 'x', 'received_on', '2026-10-09'), 'incompleto');
reset role;
insert into storage.objects (bucket_id, name, metadata) values ('audit-fpa', (select v from t_ids where k = 'p1'), '{"size": 500}');
select pg_temp.as_user('02'); set local role authenticated;
select pg_temp.err('Data de recebimento futura recusada', 'fpa', 'register_file', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.lv('lvF'),
 'format', 'xlsx', 'path', (select v from t_ids where k = 'p1'), 'filename', 'fpa.xlsx', 'size_bytes', 500, 'sha256', repeat('c', 64), 'mime_type', 'x', 'received_on', '2099-01-01'), 'não futura');
do $$ declare f jsonb; begin
 f := public.audit_fpa('register_file', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.lv('lvF'),
  'format', 'xlsx', 'path', (select v from t_ids where k = 'p1'), 'filename', 'fpa.xlsx', 'size_bytes', 500, 'sha256', repeat('c', 64),
  'mime_type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'received_on', '2026-10-09', 'source_note', 'Recebido por e-mail'));
 perform pg_temp.ok('Recebimento registra versão 1 com arquivo', f->>'status' = 'received' and f->'versions'->0->>'version_number' = '1', f->>'versions');
 update t_ids set v = f->>'lock_version' where k = 'lvF';
 insert into t_ids values ('v1', f->'versions'->0->>'id');
end $$;
select pg_temp.err('PA-11 não fica suficiente sem análise', 'fpa', 'mark_sufficient', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.lv('lvF'), 'version_id', pg_temp.id('v1')), 'em análise');
reset role;
-- Administrador (não condutor) opera com autoria real (D04).
select pg_temp.as_user('01'); set local role authenticated;
do $$ declare f jsonb; begin
 f := public.audit_fpa('start_analysis', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.lv('lvF')));
 perform pg_temp.ok('D04 Admin opera a FPA', f->>'status' = 'in_analysis');
 perform pg_temp.ok('D04 autoria real do Admin no histórico', f->'events'->0->>'actor' = 'Admin Teste', f->'events'->0->>'actor');
 update t_ids set v = f->>'lock_version' where k = 'lvF';
end $$;
reset role; select pg_temp.as_user('02'); set local role authenticated;
do $$ declare f jsonb; up jsonb; begin
 f := public.audit_fpa('request_complement', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.lv('lvF'), 'questions', 'Informar número de colaboradores por turno', 'due_date', '2026-10-17'));
 perform pg_temp.ok('Complementação solicitada com pendências e prazo', f->>'status' = 'complement_requested' and f->>'complement_due_date' = '2026-10-17');
 update t_ids set v = f->>'lock_version' where k = 'lvF';
 up := public.audit_fpa('authorize_upload', jsonb_build_object('audit_id', pg_temp.id('A'), 'format', 'pdf'));
 insert into t_ids values ('p2', up->>'path');
end $$;
reset role;
insert into storage.objects (bucket_id, name, metadata) values ('audit-fpa', (select v from t_ids where k = 'p2'), '{"size": 900}');
select pg_temp.as_user('02'); set local role authenticated;
do $$ declare f jsonb; begin
 f := public.audit_fpa('register_file', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.lv('lvF'),
  'format', 'pdf', 'path', (select v from t_ids where k = 'p2'), 'filename', 'fpa-v2.pdf', 'size_bytes', 900, 'sha256', repeat('d', 64), 'mime_type', 'application/pdf', 'received_on', '2026-10-10'));
 insert into t_ids values ('v2', f->'versions'->0->>'id');
 f := public.audit_fpa('start_analysis', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', (f->>'lock_version')::int));
 update t_ids set v = f->>'lock_version' where k = 'lvF';
 perform pg_temp.ok('Versão anterior preservada', jsonb_array_length(f->'versions') = 2);
end $$;
select pg_temp.err('PA-12 análise exige a versão mais recente', 'fpa', 'mark_sufficient', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.lv('lvF'), 'version_id', pg_temp.id('v1')), 'mais recente');
do $$ declare f jsonb; begin
 f := public.audit_fpa('mark_sufficient', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', pg_temp.lv('lvF'), 'version_id', pg_temp.id('v2'), 'note', 'Informações suficientes para planejar'));
 perform pg_temp.ok('PA-12 versão usada e autoria da análise registradas', f->>'status' = 'sufficient' and f->>'sufficient_version_id' = (select v from t_ids where k='v2')
  and f->>'analyzed_by' = 'Lider X Teste' and f->>'analyzed_at' is not null, f::text);
 perform pg_temp.ok('Histórico completo de eventos', jsonb_array_length(f->'events') = 7, jsonb_array_length(f->'events')::text);
end $$;
reset role; select pg_temp.as_user('03'); set local role authenticated;
do $$ declare f jsonb; begin
 f := public.audit_fpa('detail', jsonb_build_object('audit_id', pg_temp.id('A')));
 perform pg_temp.ok('Equipe interna consulta a FPA sem editar', f->>'status' = 'sufficient' and not (f->>'can_edit')::boolean);
end $$;
select pg_temp.err('Apoio não altera a FPA', 'fpa', 'request', jsonb_build_object('audit_id', pg_temp.id('A'), 'expected_lock_version', 99, 'recipient_name', 'X'), 'condutor');
reset role; select pg_temp.as_user('04'); set local role authenticated;
select pg_temp.err('D09 Participante não acessa a FPA', 'fpa', 'detail', jsonb_build_object('audit_id', pg_temp.id('A')), 'indisponível');
select pg_temp.err('D09 Participante não baixa FPA por chamada direta', 'fpa', 'download', jsonb_build_object('audit_id', pg_temp.id('A'), 'version_id', pg_temp.id('v1')), 'indisponível');
reset role;
do $$ begin
 update private.audit_fpa_versions set filename = 'x' where id = pg_temp.id('v1');
 perform pg_temp.ok('Versão de FPA imutável', false, 'alterou');
exception when others then perform pg_temp.ok('Versão de FPA imutável', position('imutável' in sqlerrm) > 0, sqlerrm); end $$;
select pg_temp.ok('Histórico do sistema registra FPA e identificação', (select count(*) from public.audit_events where entity_id = pg_temp.id('A')
 and event_type like 'b06_%') >= 9, (select count(*) from public.audit_events where entity_id = pg_temp.id('A') and event_type like 'b06_%')::text);

select n, name, ok, left(detail, 150) detail from t_res order by n;
