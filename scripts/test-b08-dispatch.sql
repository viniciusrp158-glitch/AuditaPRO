-- B08: retomada durável (varredura pg_cron) e bilhetes de uso único (pg_net). Banco local com stubs net/cron, transação revertida.
create temp table t_res (n serial, name text, ok boolean, detail text);
grant all on t_res to service_role, authenticated; grant usage on sequence t_res_n_seq to service_role, authenticated;
create temp table t_ids (k text primary key, v text); grant all on t_ids to service_role;
create function pg_temp.id(key text) returns uuid language sql as $$ select v::uuid from t_ids where k = key $$;
create function pg_temp.ok(label text, cond boolean, info text default '') returns void language sql as
 $$ insert into t_res(name, ok, detail) values (label, coalesce(cond, false), info) $$;
grant execute on all functions in schema pg_temp to service_role, authenticated;
do $$ declare e1 private.document_emissions; e2 private.document_emissions; e3 private.document_emissions; n int; t uuid; begin
 e1 := private.b08_request('specimen', gen_random_uuid(), gen_random_uuid(), null, null, 'Rev.00', 'P1', 'p1.pdf', 'specimen', 1, '{"a":1}', true, 'a0000000-0000-4000-8000-000000000001');
 e2 := private.b08_request('specimen', gen_random_uuid(), gen_random_uuid(), null, null, 'Rev.00', 'P2', 'p2.pdf', 'specimen', 1, '{"a":2}', true, 'a0000000-0000-4000-8000-000000000001');
 e3 := private.b08_request('specimen', gen_random_uuid(), gen_random_uuid(), null, null, 'Rev.00', 'P3', 'p3.pdf', 'specimen', 1, '{"a":3}', true, 'a0000000-0000-4000-8000-000000000001');
 insert into t_ids values ('e1', e1.id), ('e2', e2.id), ('e3', e3.id);
 n := private.b08_sweep();
 perform pg_temp.ok('Pedido recém-criado aguarda o acionamento normal (30 s) antes da varredura', n = 0, n::text);
end $$;
-- Simula a passagem do tempo: pedidos criados há 1 minuto (a coluna é imutável; desliga o guarda só neste teste).
alter table private.document_emissions disable trigger document_emissions_guard;
update private.document_emissions set requested_at = clock_timestamp() - interval '1 minute' where id in (pg_temp.id('e1'), pg_temp.id('e2'), pg_temp.id('e3'));
alter table private.document_emissions enable trigger document_emissions_guard;
do $$ declare n int; n2 int; r jsonb; begin
 n := private.b08_sweep();
 perform pg_temp.ok('Varredura aciona os pedidos pendentes com bilhete', n = 3 and (select count(*) from private.document_emission_tickets where consumed_at is null) = 3
   and (select count(*) from net.stub_requests where url like 'https://%/functions/v1/document-emission' and body->>'action' = 'ticket') = 3, n::text);
 n2 := private.b08_sweep();
 perform pg_temp.ok('Bilhete em aberto não é duplicado', n2 = 0, n2::text);
 perform pg_temp.ok('Agendamento a cada minuto registrado', exists (select 1 from cron.stub_jobs where jobname = 'b08-document-emission-sweep' and schedule = '* * * * *'));
 insert into t_ids values ('t1', (select ticket from private.document_emission_tickets where emission_id = pg_temp.id('e1')));
end $$;
set local role service_role;
do $$ declare r jsonb; r2 jsonb; begin
 r := public.document_emission_ticket('consume', jsonb_build_object('ticket', pg_temp.id('t1')));
 r2 := public.document_emission_ticket('consume', jsonb_build_object('ticket', pg_temp.id('t1')));
 perform pg_temp.ok('Bilhete vale uma única vez', (r->>'valid')::boolean and r->>'purpose' = 'process' and (r->>'emission_id')::uuid = pg_temp.id('e1')
   and not (r2->>'valid')::boolean, r2::text);
 r := public.document_emission_ticket('consume', jsonb_build_object('ticket', gen_random_uuid()));
 perform pg_temp.ok('Bilhete inexistente é recusado', not (r->>'valid')::boolean);
 r := public.document_emission_ticket('result', jsonb_build_object('ticket', pg_temp.id('t1'), 'result', '{"state":"published"}'::jsonb));
 r2 := public.document_emission_ticket('result', jsonb_build_object('ticket', pg_temp.id('t1'), 'result', '{"state":"x"}'::jsonb));
 perform pg_temp.ok('Resultado registrado uma vez', (r->>'recorded')::boolean and not (r2->>'recorded')::boolean);
end $$;
reset role;
do $$ begin
 perform pg_temp.ok('Resultado do bilhete guardado', (select result->>'state' from private.document_emission_tickets where ticket = pg_temp.id('t1')) = 'published', (select to_jsonb(k)::text from private.document_emission_tickets k where ticket = pg_temp.id('t1')));
 begin delete from private.document_emission_tickets where ticket = pg_temp.id('t1'); perform pg_temp.ok('Bilhete não é excluído', false);
 exception when others then perform pg_temp.ok('Bilhete não é excluído', position('não são excluídos' in sqlerrm) > 0, sqlerrm); end;
end $$;
set local role authenticated;
do $$ begin perform public.document_emission_ticket('consume', '{}'); perform pg_temp.ok('Navegador não usa bilhetes', false);
exception when insufficient_privilege then perform pg_temp.ok('Navegador não usa bilhetes', true, sqlerrm); end $$;
reset role;
select n, name, ok, left(detail, 120) from t_res order by n;
