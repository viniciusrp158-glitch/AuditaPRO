-- B08: pedido de emissão idempotente, posse exclusiva (lease), retomada após interrupção, integridade antes de "pronto",
-- publicação separada, download autorizado e imutabilidade. Banco local, transação revertida.
-- Contas: 001 Admin | 002 Líder X (condutor) | 003 Auditor X (apoio) | 005 Líder Y (outra organização)
create temp table t_res (n serial, name text, ok boolean, detail text);
grant all on t_res to authenticated, service_role, anon; grant usage on sequence t_res_n_seq to authenticated, service_role, anon;
create temp table t_ids (k text primary key, v text); grant all on t_ids to authenticated, service_role, anon;
create function pg_temp.as_user(uid text) returns void language sql as
 $$ select set_config('request.jwt.claims', json_build_object('sub', ('a0000000-0000-4000-8000-0000000000' || uid), 'role', 'authenticated')::text, true); $$;
create function pg_temp.id(key text) returns uuid language sql as $$ select v::uuid from t_ids where k = key $$;
create function pg_temp.v(key text) returns text language sql as $$ select v from t_ids where k = key $$;
create function pg_temp.ok(label text, cond boolean, info text default '') returns void language sql as
 $$ insert into t_res(name, ok, detail) values (label, coalesce(cond, false), info) $$;
create function pg_temp.err(label text, cmd text, payload jsonb, needle text) returns void language plpgsql as $$
begin perform public.document_emission(cmd, payload); insert into t_res(name, ok, detail) values (label, false, 'sem erro');
exception when others then insert into t_res(name, ok, detail) values (label, position(lower(needle) in lower(sqlerrm)) > 0, sqlerrm); end $$;
create function pg_temp.werr(label text, cmd text, payload jsonb, needle text) returns void language plpgsql as $$
begin perform public.document_emission_worker(cmd, payload); insert into t_res(name, ok, detail) values (label, false, 'sem erro');
exception when others then insert into t_res(name, ok, detail) values (label, position(lower(needle) in lower(sqlerrm)) > 0, sqlerrm); end $$;
create function pg_temp.n_att(eid uuid) returns bigint language sql security definer as $$ select count(*) from private.document_emission_attempts where emission_id = eid $$;
create function pg_temp.att_out(eid uuid, k int) returns text language sql security definer as $$ select outcome from private.document_emission_attempts where emission_id = eid and attempt_number = k $$;
create function pg_temp.e_status(eid uuid) returns text language sql security definer as $$ select status from private.document_emissions where id = eid $$;
create function pg_temp.e_content(eid uuid) returns jsonb language sql security definer as $$ select content from private.document_emissions where id = eid $$;
grant execute on all functions in schema pg_temp to authenticated, service_role, anon;

-- Auditoria da organização X conduzida pelo Líder X, com o Auditor X na equipe; produtor cria o pedido da Rev.00.
do $$ declare aid uuid; lm uuid; am uuid; e private.document_emissions; e2 private.document_emissions; v uuid := gen_random_uuid(); begin
 select id into lm from public.organization_memberships where user_id = 'a0000000-0000-4000-8000-000000000002';
 select id into am from public.organization_memberships where user_id = 'a0000000-0000-4000-8000-000000000003';
 insert into public.audits (organization_id, code, title, leader_membership_id, created_by, workspace_version, purpose, party, modality)
 values ('0000000a-0000-4000-8000-00000000000a', 'AUD-E', 'Emissão', lm, 'a0000000-0000-4000-8000-000000000002', 1, 'A definir', 'first', 'presential') returning id into aid;
 insert into public.audit_participants (audit_id, membership_id, participant_type) values (aid, lm, 'leader'), (aid, am, 'auditor');
 e := private.b08_request('plan', aid, v, '0000000a-0000-4000-8000-00000000000a', aid, 'Rev.00', 'Plano de auditoria AUD-E Rev.00', 'plano-AUD-E-rev00.pdf',
   'plan', 1, '{"cabecalho":{"cliente":"Ação & Cia"},"linhas":[1,2,3]}', false, 'a0000000-0000-4000-8000-000000000002');
 e2 := private.b08_request('plan', aid, v, '0000000a-0000-4000-8000-00000000000a', aid, 'Rev.00', 'Plano de auditoria AUD-E Rev.00', 'plano-AUD-E-rev00.pdf',
   'plan', 1, '{"linhas":[1,2,3],"cabecalho":{"cliente":"Ação & Cia"}}', false, 'a0000000-0000-4000-8000-000000000002');
 insert into t_ids values ('A', aid), ('E', e.id), ('V', v);
 perform pg_temp.ok('Pedido repetido da mesma revisão reaproveita o mesmo pedido (sem segundo documento)', e2.id = e.id and
   (select count(*) from private.document_emissions where version_id = v) = 1, e.content_sha256);
 begin
  perform private.b08_request('plan', aid, v, '0000000a-0000-4000-8000-00000000000a', aid, 'Rev.00', 'x', 'x.pdf', 'plan', 1, '{"linhas":[9]}', false, 'a0000000-0000-4000-8000-000000000002');
  perform pg_temp.ok('Mesma revisão com outro conteúdo é recusada', false, 'aceitou');
 exception when others then perform pg_temp.ok('Mesma revisão com outro conteúdo é recusada', position('outro conteúdo' in sqlerrm) > 0, sqlerrm); end;
 perform pg_temp.ok('Pedido nasce pendente com SHA-256 do conteúdo', e.status = 'pending' and e.content_sha256 = encode(sha256(convert_to(e.content::text, 'UTF8')), 'hex'));
end $$;

-- Permissões
select pg_temp.as_user('02'); set local role authenticated;
do $$ declare r jsonb; begin
 r := public.document_emission('status', jsonb_build_object('emission_id', pg_temp.id('E')));
 perform pg_temp.ok('Condutor consulta e opera a emissão', r->>'status' = 'pending' and (r->>'can_operate')::boolean and r->>'content' is null, r::text);
 perform pg_temp.err('Arquivo pendente não é liberado para download', 'authorize_download', jsonb_build_object('emission_id', pg_temp.id('E')), 'não disponível');
 begin perform public.document_emission_worker('claim', jsonb_build_object('emission_id', pg_temp.id('E')));
  perform pg_temp.ok('Navegador não chama o processador', false, 'executou');
 exception when insufficient_privilege then perform pg_temp.ok('Navegador não chama o processador', true, sqlerrm); end;
end $$;
reset role; select pg_temp.as_user('03'); set local role authenticated;
do $$ declare r jsonb; begin
 r := public.document_emission('status', jsonb_build_object('emission_id', pg_temp.id('E')));
 perform pg_temp.ok('Apoio consulta sem operar', not (r->>'can_operate')::boolean, r::text);
 perform pg_temp.err('Apoio não retoma emissão', 'retry', jsonb_build_object('emission_id', pg_temp.id('E')), 'Somente o condutor');
end $$;
reset role; select pg_temp.as_user('05'); set local role authenticated;
select pg_temp.err('Outra organização não vê o pedido', 'status', jsonb_build_object('emission_id', pg_temp.id('E')), 'não encontrado');
reset role; set local role anon;
do $$ begin perform public.document_emission('status', '{}'); perform pg_temp.ok('Anônimo sem acesso', false);
exception when insufficient_privilege then perform pg_temp.ok('Anônimo sem acesso', true, sqlerrm); end $$;

-- Processamento: posse exclusiva, interrupção, retomada e integridade.
reset role; set local role service_role;
do $$ declare c jsonb; c2 jsonb; c3 jsonb; c4 jsonb; r jsonb; begin
 c := public.document_emission_worker('claim', jsonb_build_object('emission_id', pg_temp.id('E'), 'triggered_by', 'a0000000-0000-4000-8000-000000000002'));
 perform pg_temp.ok('Primeira tentativa assume a posse com caminho reservado', c->>'state' = 'claimed' and (c->>'attempt')::int = 1
   and c->>'storage_path' like '0000000a-0000-4000-8000-00000000000a/plan/' || pg_temp.id('E') || '/tentativa-1-%.pdf' and c->'content' ? 'linhas', c->>'storage_path');
 c2 := public.document_emission_worker('claim', jsonb_build_object('emission_id', pg_temp.id('E')));
 perform pg_temp.ok('Segunda chamada concorrente não cria outra tentativa', c2->>'state' = 'busy'
   and pg_temp.n_att(pg_temp.id('E')) = 1, c2->>'state');
 perform pg_temp.werr('Confirmação com caminho diferente do reservado é recusada', 'complete', jsonb_build_object('emission_id', pg_temp.id('E'),
   'lease_token', c->>'lease_token', 'storage_path', 'outro/caminho.pdf', 'pdf_sha256', repeat('a', 64), 'verified_sha256', repeat('a', 64), 'size_bytes', 10, 'page_count', 1), 'Caminho');
 perform pg_temp.werr('Sem conferência do arquivo armazenado não fica pronto', 'complete', jsonb_build_object('emission_id', pg_temp.id('E'),
   'lease_token', c->>'lease_token', 'storage_path', c->>'storage_path', 'pdf_sha256', repeat('a', 64), 'verified_sha256', repeat('b', 64), 'size_bytes', 10, 'page_count', 1), 'Integridade');
 insert into t_ids values ('tok1', c->>'lease_token'), ('path1', c->>'storage_path');
end $$;
-- Interrupção: o processo some sem responder; o prazo da posse vence.
reset role;
update private.document_emissions set lease_expires_at = clock_timestamp() - interval '1 second' where id = pg_temp.id('E');
set local role service_role;
do $$ declare c jsonb; r jsonb; begin
 c := public.document_emission_worker('claim', jsonb_build_object('emission_id', pg_temp.id('E')));
 perform pg_temp.ok('Retomada após interrupção assume nova tentativa da mesma revisão', c->>'state' = 'claimed' and (c->>'attempt')::int = 2
   and pg_temp.att_out(pg_temp.id('E'), 1) = 'lease_lost', c->>'state');
 r := public.document_emission_worker('complete', jsonb_build_object('emission_id', pg_temp.id('E'), 'lease_token', pg_temp.v('tok1'),
   'storage_path', pg_temp.v('path1'), 'pdf_sha256', repeat('c', 64), 'verified_sha256', repeat('c', 64), 'size_bytes', 10, 'page_count', 1));
 perform pg_temp.ok('Processo antigo sem posse não finaliza', not (r->>'accepted')::boolean and r->>'reason' = 'lease_lost'
   and pg_temp.e_status(pg_temp.id('E')) = 'processing', r::text);
 r := public.document_emission_worker('fail', jsonb_build_object('emission_id', pg_temp.id('E'), 'lease_token', c->>'lease_token',
   'error', E'Falha no upload:\n  conexão   encerrada'));
 perform pg_temp.ok('Falha registrada com erro saneado; snapshot preservado', r->'emission'->>'status' = 'failed'
   and r->'emission'->>'last_error' = 'Falha no upload: conexão encerrada'
   and pg_temp.e_content(pg_temp.id('E')) ? 'linhas', r::text);
 c := public.document_emission_worker('claim', jsonb_build_object('emission_id', pg_temp.id('E'), 'triggered_by', 'a0000000-0000-4000-8000-000000000002'));
 r := public.document_emission_worker('complete', jsonb_build_object('emission_id', pg_temp.id('E'), 'lease_token', c->>'lease_token',
   'storage_path', c->>'storage_path', 'pdf_sha256', repeat('d', 64), 'verified_sha256', repeat('d', 64), 'size_bytes', 2048, 'page_count', 3,
   'engine_version', 'audita-pdf 1.0.0', 'asset_manifest', '[{"key":"builtin:logo"}]', 'metrics', '{"render_ms":12}', 'triggered_by', 'a0000000-0000-4000-8000-000000000002'));
 perform pg_temp.ok('Tentativa 3 conclui: arquivo íntegro pronto, sem publicação automática', (r->>'accepted')::boolean and r->'emission'->>'status' = 'ready'
   and (r->'emission'->>'page_count')::int = 3 and r->'emission'->>'pdf_sha256' = repeat('d', 64), r::text);
 insert into t_ids values ('path3', c->>'storage_path');
 c := public.document_emission_worker('claim', jsonb_build_object('emission_id', pg_temp.id('E')));
 perform pg_temp.ok('Nova chamada após concluir não gera outro arquivo', c->>'state' = 'done'
   and pg_temp.n_att(pg_temp.id('E')) = 3, c->>'state');
end $$;

-- Download: pronto só para o operador; publicado para a equipe interna.
reset role; select pg_temp.as_user('03'); set local role authenticated;
select pg_temp.err('Apoio não baixa arquivo pronto ainda não publicado', 'authorize_download', jsonb_build_object('emission_id', pg_temp.id('E')), 'não disponível');
reset role; select pg_temp.as_user('02'); set local role authenticated;
do $$ declare r jsonb; begin
 r := public.document_emission('authorize_download', jsonb_build_object('emission_id', pg_temp.id('E')));
 perform pg_temp.ok('Condutor confere o arquivo pronto (mesmo caminho e hash)', r->>'path' = pg_temp.v('path3') and r->>'sha256' = repeat('d', 64)
   and r->>'bucket' = 'document-emissions' and r->>'filename' = 'plano-AUD-E-rev00.pdf', r::text);
end $$;
reset role;
select private.b08_publish(pg_temp.id('E'), 'a0000000-0000-4000-8000-000000000002');
select pg_temp.as_user('03'); set local role authenticated;
do $$ declare r jsonb; r2 jsonb; begin
 r := public.document_emission('authorize_download', jsonb_build_object('emission_id', pg_temp.id('E')));
 r2 := public.document_emission('authorize_download', jsonb_build_object('emission_id', pg_temp.id('E')));
 perform pg_temp.ok('Publicado: equipe baixa sempre o mesmo arquivo da revisão', r->>'path' = pg_temp.v('path3') and r::text = r2::text, r::text);
end $$;
reset role;
do $$ begin
 perform pg_temp.ok('Histórico: pedido, emissão, publicação e downloads', (select array_agg(distinct event_type order by event_type) from public.audit_events
   where entity_id = pg_temp.id('E')) = array['document_downloaded', 'document_emission_failed', 'document_emission_requested', 'document_emitted', 'document_published'],
   (select string_agg(event_type, ',') from public.audit_events where entity_id = pg_temp.id('E')));
 begin update private.document_emissions set pdf_sha256 = repeat('e', 64) where id = pg_temp.id('E'); perform pg_temp.ok('Arquivo emitido não é substituído', false, 'alterou');
 exception when others then perform pg_temp.ok('Arquivo emitido não é substituído', position('não pode ser substituído' in sqlerrm) > 0, sqlerrm); end;
 begin update private.document_emissions set content = '{}' where id = pg_temp.id('E'); perform pg_temp.ok('Conteúdo congelado é imutável', false, 'alterou');
 exception when others then perform pg_temp.ok('Conteúdo congelado é imutável', position('imutáveis' in sqlerrm) > 0, sqlerrm); end;
 begin update private.document_emissions set status = 'pending' where id = pg_temp.id('E'); perform pg_temp.ok('Publicado não volta a pendente', false, 'alterou');
 exception when others then perform pg_temp.ok('Publicado não volta a pendente', position('não volta' in sqlerrm) > 0, sqlerrm); end;
 begin delete from private.document_emissions where id = pg_temp.id('E'); perform pg_temp.ok('Pedido não é excluído', false, 'excluiu');
 exception when others then perform pg_temp.ok('Pedido não é excluído', position('não são excluídos' in sqlerrm) > 0, sqlerrm); end;
end $$;

-- Tentativas esgotadas e retomada pelo condutor.
do $$ declare e private.document_emissions; c jsonb; i int; begin
 e := private.b08_request('rda', gen_random_uuid(), gen_random_uuid(), '0000000a-0000-4000-8000-00000000000a', pg_temp.id('A'), 'Rev.00', 'RDA dia 1', 'rda-dia1.pdf',
   'rda', 1, '{"dia":1}', true, 'a0000000-0000-4000-8000-000000000002');
 insert into t_ids values ('R', e.id);
 for i in 1..5 loop
  c := public.document_emission_worker('claim', jsonb_build_object('emission_id', e.id));
  perform public.document_emission_worker('fail', jsonb_build_object('emission_id', e.id, 'lease_token', c->>'lease_token', 'error', 'Falha ' || i));
 end loop;
 c := public.document_emission_worker('claim', jsonb_build_object('emission_id', e.id));
 perform pg_temp.ok('Após 5 falhas o processamento automático para', c->>'state' = 'exhausted', c->>'state');
end $$;
select pg_temp.as_user('02'); set local role authenticated;
select pg_temp.ok('Condutor libera novas tentativas', (public.document_emission('retry', jsonb_build_object('emission_id', pg_temp.id('R')))->>'max_attempts')::int = 8);
reset role; set local role service_role;
do $$ declare c jsonb; r jsonb; begin
 c := public.document_emission_worker('claim', jsonb_build_object('emission_id', pg_temp.id('R')));
 r := public.document_emission_worker('complete', jsonb_build_object('emission_id', pg_temp.id('R'), 'lease_token', c->>'lease_token',
   'storage_path', c->>'storage_path', 'pdf_sha256', repeat('f', 64), 'verified_sha256', repeat('f', 64), 'size_bytes', 99, 'page_count', 1));
 perform pg_temp.ok('Publicação automática só depois do arquivo íntegro', c->>'state' = 'claimed' and r->'emission'->>'status' = 'published', r::text);
end $$;

-- Documento de prova: só Administrador, idempotente por operação.
reset role; select pg_temp.as_user('01'); set local role authenticated;
do $$ declare op uuid := gen_random_uuid(); r jsonb; r2 jsonb; l jsonb; begin
 r := public.document_emission('request_specimen', jsonb_build_object('operation_id', op, 'params', jsonb_build_object('rows', 5000)));
 r2 := public.document_emission('request_specimen', jsonb_build_object('operation_id', op));
 l := public.document_emission('list', '{}');
 perform pg_temp.ok('Prova do emissor: idempotente, limitada e listada ao Administrador', r->>'id' = r2->>'id' and r->>'kind' = 'specimen'
   and (pg_temp.e_content((r->>'id')::uuid)->'params'->>'rows')::int = 2000
   and exists (select 1 from jsonb_array_elements(l) x where x->>'id' = r->>'id'), r::text);
end $$;
reset role; select pg_temp.as_user('02'); set local role authenticated;
select pg_temp.err('Líder não emite documento de prova', 'request_specimen', jsonb_build_object('operation_id', gen_random_uuid()), 'Administrador');
do $$ declare l jsonb; begin
 l := public.document_emission('list', jsonb_build_object('audit_id', pg_temp.id('A')));
 perform pg_temp.ok('Lista da auditoria traz as duas emissões ao condutor', jsonb_array_length(l) = 2, l::text);
end $$;
reset role;
select n, name, ok, left(detail, 120) from t_res order by n;
