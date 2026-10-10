-- B05: testes de aceite da biblioteca corporativa (CA-04..CA-13, PER-19).
-- Banco local: scripts/localdb/rebuild.sh e depois scripts/run-sql-test.sh scripts/test-b05-corporate-library.sql
-- Executado em transação revertida. Contas de scripts/localdb/10-fixtures.sql:
--  ...001 Administrador | ...003 Auditor X | ...004 Participante X | ...007 Pendente X | ...008 Inativo X
create temp table t_res (n serial, name text, ok boolean, detail text);
grant all on t_res to authenticated, anon; grant usage on sequence t_res_n_seq to authenticated, anon;
create temp table t_ids (k text primary key, v text);
grant all on t_ids to authenticated;
create function pg_temp.as_user(uid uuid) returns void language sql as
 $$ select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true); $$;
create function pg_temp.id(key text) returns uuid language sql as $$ select v::uuid from t_ids where k = key $$;
create function pg_temp.expect_error(label text, cmd text, payload jsonb, needle text) returns void language plpgsql as $$
begin
 perform public.corporate_library(cmd, payload);
 insert into t_res(name, ok, detail) values (label, false, 'sem erro');
exception when others then
 insert into t_res(name, ok, detail) values (label, position(lower(needle) in lower(sqlerrm)) > 0, sqlerrm);
end $$;

-- ===== Administrador =====
select pg_temp.as_user('a0000000-0000-4000-8000-000000000001');
set local role authenticated;
do $$ declare r jsonb; r2 jsonb; up jsonb; begin
 r := public.corporate_library('context', '{}');
 insert into t_res(name, ok, detail) values ('A01 admin context gerencia', (r->>'can_manage')::boolean and (r->>'can_history')::boolean, r::text);
 r := public.corporate_library('create', jsonb_build_object('operation_id', '11111111-1111-4111-8111-111111111111',
  'title', 'Procedimento de Auditoria', 'doc_type', 'procedimento', 'code', 'PDA-001', 'revision_label', 'Rev.00'));
 r2 := public.corporate_library('create', jsonb_build_object('operation_id', '11111111-1111-4111-8111-111111111111',
  'title', 'Procedimento de Auditoria', 'doc_type', 'procedimento', 'code', 'PDA-001', 'revision_label', 'Rev.00'));
 insert into t_res(name, ok, detail) values ('A02 criação idempotente', r = r2, r::text);
 insert into t_ids values ('doc1', r->>'document_id'), ('rev0', r->>'revision_id');
end $$;
select pg_temp.expect_error('A03 publicar sem arquivo bloqueia', 'publish', jsonb_build_object('revision_id', pg_temp.id('rev0')), 'arquivo');
do $$ declare up jsonb; begin
 up := public.corporate_library('authorize_upload', jsonb_build_object('revision_id', pg_temp.id('rev0'), 'format', 'pdf'));
 insert into t_ids values ('path0', up->>'path');
 insert into t_res(name, ok, detail) values ('A04 autoriza upload em rascunho', up->>'path' like (pg_temp.id('doc1'))::text || '/%', up::text);
end $$;
select pg_temp.expect_error('A05 registro sem objeto no storage recusado', 'register_file', jsonb_build_object('revision_id', pg_temp.id('rev0'), 'format', 'pdf',
 'path', (select v from t_ids where k = 'path0'), 'filename', 'pda.pdf', 'size_bytes', 1000, 'sha256', repeat('a', 64), 'mime_type', 'application/pdf'), 'incompleto');
reset role;
insert into storage.objects (bucket_id, name, metadata) values ('corporate-library', (select v from t_ids where k = 'path0'), '{"size": 1000, "mimetype": "application/pdf"}');
set local role authenticated;
select pg_temp.expect_error('A06 tamanho divergente recusado', 'register_file', jsonb_build_object('revision_id', pg_temp.id('rev0'), 'format', 'pdf',
 'path', (select v from t_ids where k = 'path0'), 'filename', 'pda.pdf', 'size_bytes', 999, 'sha256', repeat('a', 64), 'mime_type', 'application/pdf'), 'incompleto');
select pg_temp.expect_error('A07 caminho de outra revisão recusado', 'register_file', jsonb_build_object('revision_id', pg_temp.id('rev0'), 'format', 'pdf',
 'path', 'x/y/z.pdf', 'filename', 'pda.pdf', 'size_bytes', 1000, 'sha256', repeat('a', 64), 'mime_type', 'application/pdf'), 'caminho');
do $$ declare r jsonb; begin
 r := public.corporate_library('register_file', jsonb_build_object('revision_id', pg_temp.id('rev0'), 'format', 'pdf',
  'path', (select v from t_ids where k = 'path0'), 'filename', 'pda.pdf', 'size_bytes', 1000, 'sha256', repeat('a', 64), 'mime_type', 'application/pdf'));
 insert into t_ids values ('file0', r->>'file_id');
 insert into t_res(name, ok, detail) values ('A08 arquivo íntegro registrado', r->>'file_id' is not null, r::text);
end $$;
select pg_temp.expect_error('A09 vigente exige responsável/emissão', 'publish', jsonb_build_object('revision_id', pg_temp.id('rev0')), 'responsável');
do $$ declare r jsonb; l jsonb; begin
 perform public.corporate_library('update_revision', jsonb_build_object('revision_id', pg_temp.id('rev0'), 'revision_label', 'Rev.00',
  'responsible', 'Responsável Técnico', 'issued_on', '2026-10-10'));
 r := public.corporate_library('publish', jsonb_build_object('revision_id', pg_temp.id('rev0')));
 insert into t_res(name, ok, detail) values ('A10 publicação vigente', r->>'status' = 'current', r::text);
 l := public.corporate_library('list', '{}');
 insert into t_res(name, ok, detail) values ('A11 lista admin mostra vigente', l->'items'->0->>'status' = 'vigente' and (l->>'total')::int = 1, l::text);
 r := public.corporate_library('new_revision', jsonb_build_object('operation_id', '22222222-2222-4222-8222-222222222222', 'document_id', pg_temp.id('doc1'), 'revision_label', 'Rev.01'));
 insert into t_ids values ('rev1', r->>'revision_id');
end $$;
select pg_temp.expect_error('A12 segundo rascunho simultâneo bloqueado', 'new_revision', jsonb_build_object('operation_id', '33333333-3333-4333-8333-333333333333', 'document_id', pg_temp.id('doc1'), 'revision_label', 'Rev.02'), 'rascunho');
select pg_temp.expect_error('A13 remover arquivo de revisão emitida bloqueado', 'remove_file', jsonb_build_object('file_id', pg_temp.id('file0')), 'rascunho');
select pg_temp.expect_error('A14 código emitido não muda', 'update', jsonb_build_object('document_id', pg_temp.id('doc1'), 'expected_lock_version', 2,
 'title', 'Procedimento de Auditoria', 'doc_type', 'procedimento', 'code', 'PDA-999'), 'código');
select pg_temp.expect_error('A15 versão esperada divergente (concorrência)', 'update', jsonb_build_object('document_id', pg_temp.id('doc1'), 'expected_lock_version', 1,
 'title', 'Outro', 'doc_type', 'procedimento', 'code', 'PDA-001'), 'outra sessão');
select pg_temp.expect_error('A16 código não reutilizado (maiúsc./minúsc.)', 'create', jsonb_build_object('operation_id', '44444444-4444-4444-8444-444444444444',
 'title', 'Outro documento', 'doc_type', 'modelo', 'code', ' pda-001 ', 'revision_label', 'Rev.00'), 'código já utilizado');
do $$ declare up jsonb; begin
 up := public.corporate_library('authorize_upload', jsonb_build_object('revision_id', pg_temp.id('rev1'), 'format', 'docx'));
 insert into t_ids values ('path1', up->>'path');
end $$;
reset role;
insert into storage.objects (bucket_id, name, metadata) values ('corporate-library', (select v from t_ids where k = 'path1'), '{"size": 2048}');
set local role authenticated;
do $$ declare r jsonb; l jsonb; begin
 r := public.corporate_library('register_file', jsonb_build_object('revision_id', pg_temp.id('rev1'), 'format', 'docx',
  'path', (select v from t_ids where k = 'path1'), 'filename', 'pda.docx', 'size_bytes', 2048, 'sha256', repeat('b', 64),
  'mime_type', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'));
 insert into t_ids values ('file1', r->>'file_id');
 -- AD-15: remoção de arquivo de rascunho sem exclusão de linha; novo envio reutiliza o registro
 r := public.corporate_library('remove_file', jsonb_build_object('file_id', pg_temp.id('file1')));
 insert into t_res(name, ok, detail) values ('A16a remover arquivo do rascunho o retira da revisão',
  jsonb_array_length(r->'revision'->'files') = 0 and r->>'path' = (select v from t_ids where k = 'path1'), r::text);
 begin
  perform public.corporate_library('publish', jsonb_build_object('revision_id', pg_temp.id('rev1')));
  insert into t_res(name, ok, detail) values ('A16c sem arquivo ativo não publica', false, 'publicou');
 exception when others then insert into t_res(name, ok, detail) values ('A16c sem arquivo ativo não publica', position('arquivo' in sqlerrm) > 0, sqlerrm); end;
 r := public.corporate_library('authorize_upload', jsonb_build_object('revision_id', pg_temp.id('rev1'), 'format', 'docx'));
 insert into t_ids values ('path1b', r->>'path');
end $$;
reset role;
insert into storage.objects (bucket_id, name, metadata) values ('corporate-library', (select v from t_ids where k = 'path1b'), '{"size": 3072}');
set local role authenticated;
do $$ declare r jsonb; l jsonb; begin
 r := public.corporate_library('register_file', jsonb_build_object('revision_id', pg_temp.id('rev1'), 'format', 'docx',
  'path', (select v from t_ids where k = 'path1b'), 'filename', 'pda-v2.docx', 'size_bytes', 3072, 'sha256', repeat('c', 64),
  'mime_type', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'));
 insert into t_res(name, ok, detail) values ('A16d novo envio do mesmo formato reutiliza o registro do rascunho',
  r->>'file_id' = (select v from t_ids where k = 'file1') and r->'revision'->'files'->0->>'filename' = 'pda-v2.docx', r::text);
 perform public.corporate_library('update_revision', jsonb_build_object('revision_id', pg_temp.id('rev1'), 'revision_label', 'Rev.01',
  'responsible', 'Responsável Técnico', 'issued_on', '2026-10-11'));
 r := public.corporate_library('publish', jsonb_build_object('revision_id', pg_temp.id('rev1')));
 l := public.corporate_library('detail', jsonb_build_object('document_id', pg_temp.id('doc1')));
 insert into t_res(name, ok, detail) values ('A17 nova revisão substitui e preserva anterior',
  (select count(*) from jsonb_array_elements(l->'revisions') x where x->>'status' = 'superseded' and jsonb_array_length(x->'files') = 1) = 1
  and (select count(*) from jsonb_array_elements(l->'revisions') x where x->>'status' = 'current') = 1, l->'revisions'::text);
 insert into t_res(name, ok, detail) values ('A18 eventos no histórico do sistema', jsonb_array_length(l->'events') >= 6, jsonb_array_length(l->'events')::text);
 -- documento 2: só rascunho; documento 3: vigente e depois arquivado
 r := public.corporate_library('create', jsonb_build_object('operation_id', '55555555-5555-4555-8555-555555555555',
  'title', 'Modelo mestre', 'doc_type', 'modelo', 'revision_label', 'v1'));
 insert into t_ids values ('doc2', r->>'document_id');
end $$;
select pg_temp.expect_error('A19 arquivar exige motivo', 'archive', jsonb_build_object('document_id', pg_temp.id('doc2')), 'motivo');
reset role;

-- ===== Participante (V-07 / CA-13) =====
select pg_temp.as_user('a0000000-0000-4000-8000-000000000004');
set local role authenticated;
do $$ declare r jsonb; begin
 r := public.corporate_library('context', '{}');
 insert into t_res(name, ok, detail) values ('P01 participante sem biblioteca', not (r->>'can_read')::boolean and not (r->>'can_manage')::boolean, r::text);
end $$;
select pg_temp.expect_error('P02 participante lista recusada', 'list', '{}', 'indisponível');
select pg_temp.expect_error('P03 participante download direto recusado', 'download', jsonb_build_object('file_id', pg_temp.id('file1')), 'indisponível');
select pg_temp.expect_error('P04 participante criação recusada', 'create', jsonb_build_object('operation_id', '66666666-6666-4666-8666-666666666666', 'title', 'x', 'doc_type', 'outro', 'revision_label', 'r'), 'indisponível');
do $$ begin
 perform 1 from private.corporate_documents;
 insert into t_res(name, ok, detail) values ('P05 tabela privada inacessível', false, 'leu tabela');
exception when others then insert into t_res(name, ok, detail) values ('P05 tabela privada inacessível', sqlstate = '42501', sqlerrm); end $$;
reset role;

-- ===== Cadastro pendente (vínculo sem aprovação) =====
select pg_temp.as_user('a0000000-0000-4000-8000-000000000007');
set local role authenticated;
select pg_temp.expect_error('N01 cadastro pendente recusado', 'list', '{}', 'indisponível');
reset role;

-- ===== Visitante (anon) =====
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
do $$ begin
 perform public.corporate_library('list', '{}');
 insert into t_res(name, ok, detail) values ('V01 visitante sem execução', false, 'executou');
exception when others then insert into t_res(name, ok, detail) values ('V01 visitante sem execução', sqlstate = '42501', sqlerrm); end $$;
reset role;

-- ===== Auditor X (perfil real) =====
select pg_temp.as_user('a0000000-0000-4000-8000-000000000003');
set local role authenticated;
do $$ declare r jsonb; l jsonb; begin
 r := public.corporate_library('context', '{}');
 insert into t_res(name, ok, detail) values ('U01 auditor lê sem gerenciar', (r->>'can_read')::boolean and not (r->>'can_manage')::boolean and not (r->>'can_history')::boolean, r::text);
 l := public.corporate_library('list', '{}');
 insert into t_res(name, ok, detail) values ('U02 auditor vê só vigente (sem rascunho)', (l->>'total')::int = 1 and l->'items'->0->'draft' = 'null'::jsonb
  and l->'items'->0->'current'->>'revision_label' = 'Rev.01', l::text);
 l := public.corporate_library('list', '{"status":"rascunho"}');
 insert into t_res(name, ok, detail) values ('U03 filtro de rascunho ignorado p/ auditor', (l->>'total')::int = 1, l::text);
 r := public.corporate_library('download', jsonb_build_object('file_id', pg_temp.id('file1')));
 insert into t_res(name, ok, detail) values ('U04 auditor baixa vigente', r->>'path' = (select v from t_ids where k = 'path1b'), r::text);
 l := public.corporate_library('list', '{"search":"inexistente"}');
 insert into t_res(name, ok, detail) values ('U05 busca sem resultado', (l->>'total')::int = 0 and l->'items' = '[]'::jsonb, l::text);
end $$;
select pg_temp.expect_error('U06 auditor não baixa revisão substituída', 'download', jsonb_build_object('file_id', pg_temp.id('file0')), 'indisponível');
select pg_temp.expect_error('U07 auditor não cria', 'create', jsonb_build_object('operation_id', '77777777-7777-4777-8777-777777777777', 'title', 'x', 'doc_type', 'outro', 'revision_label', 'r'), 'restrita');
select pg_temp.expect_error('U08 auditor não publica', 'publish', jsonb_build_object('revision_id', pg_temp.id('rev1')), 'restrita');
select pg_temp.expect_error('U09 auditor não arquiva', 'archive', jsonb_build_object('document_id', pg_temp.id('doc1'), 'reason', 'x'), 'restrita');
select pg_temp.expect_error('U10 auditor não abre detalhe/revisões', 'detail', jsonb_build_object('document_id', pg_temp.id('doc1')), 'restrita');
reset role;

-- Admin arquiva doc1: auditor deixa de ver e de baixar.
select pg_temp.as_user('a0000000-0000-4000-8000-000000000001');
set local role authenticated;
select public.corporate_library('archive', jsonb_build_object('document_id', pg_temp.id('doc1'), 'reason', 'Teste de retirada de uso'));
reset role;
select pg_temp.as_user('a0000000-0000-4000-8000-000000000003');
set local role authenticated;
do $$ declare l jsonb; begin
 l := public.corporate_library('list', '{}');
 insert into t_res(name, ok, detail) values ('U11 arquivado some para auditor', (l->>'total')::int = 0, l::text);
end $$;
select pg_temp.expect_error('U12 arquivado não baixa', 'download', jsonb_build_object('file_id', pg_temp.id('file1')), 'indisponível');
reset role;

-- Conta desativada perde acesso: auditor inativo (fixture) e Admin inativado agora.
select pg_temp.as_user('a0000000-0000-4000-8000-000000000008');
set local role authenticated;
select pg_temp.expect_error('I00 auditor inativo recusado', 'context', '{}', 'sessão ativa');
reset role;
select pg_temp.as_user('a0000000-0000-4000-8000-000000000001');
update public.user_profiles set status = 'inactive' where user_id = 'a0000000-0000-4000-8000-000000000010';
select pg_temp.as_user('a0000000-0000-4000-8000-000000000010');
set local role authenticated;
select pg_temp.expect_error('I01 conta inativa recusada', 'list', '{}', 'sessão ativa');
reset role;

-- Defesa em profundidade (postgres): arquivo emitido é imutável e revisão não é excluída.
insert into t_res(name, ok, detail) select 'A16b remoção registrada no histórico do sistema, sem apagar a linha',
 exists (select 1 from public.audit_events e where e.event_type = 'corporate_file_removed') and exists (select 1 from private.corporate_document_files where id = pg_temp.id('file1')), 'ok';
do $$ begin
 update private.corporate_document_files set filename = 'x' where id = pg_temp.id('file1');
 insert into t_res(name, ok, detail) values ('D01 arquivo imutável', false, 'alterou');
exception when others then insert into t_res(name, ok, detail) values ('D01 arquivo imutável', position('imutável' in sqlerrm) > 0, sqlerrm); end $$;
do $$ begin
 delete from private.corporate_document_revisions where id = pg_temp.id('rev0');
 insert into t_res(name, ok, detail) values ('D02 revisão não é excluída', false, 'excluiu');
exception when others then insert into t_res(name, ok, detail) values ('D02 revisão não é excluída', position('excluídas' in sqlerrm) > 0, sqlerrm); end $$;

select n, name, ok, left(detail, 160) detail from t_res order by n;
