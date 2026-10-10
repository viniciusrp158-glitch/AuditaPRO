-- B08 Parte 4 (complemento às partes 1–3): retomada durável e acionamento pelo servidor. pg_net chama a Edge Function com um bilhete de uso único
-- (validado no banco, sem segredo fora do Supabase); pg_cron varre pedidos pendentes, falhos retomáveis e posses vencidas.
-- O navegador não é necessário para concluir uma emissão já solicitada.
do $$ begin
 if exists (select 1 from pg_available_extensions where name = 'pg_net') and not exists (select 1 from pg_extension where extname = 'pg_net') then
  create extension pg_net with schema extensions; end if;
 if exists (select 1 from pg_available_extensions where name = 'pg_cron') and not exists (select 1 from pg_extension where extname = 'pg_cron') then
  create extension pg_cron with schema pg_catalog; end if;
end $$;

create table private.document_emission_tickets (
  ticket uuid primary key default gen_random_uuid(),
  purpose text not null check (purpose in ('process', 'selftest')),
  emission_id uuid references private.document_emissions(id),
  params jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null default clock_timestamp() + interval '5 minutes',
  request_id bigint,
  consumed_at timestamptz,
  finished_at timestamptz,
  result jsonb,
  check (purpose <> 'process' or emission_id is not null)
);
create index document_emission_tickets_open on private.document_emission_tickets (emission_id) where consumed_at is null;
alter table private.document_emission_tickets enable row level security;
revoke all on private.document_emission_tickets from public, anon, authenticated;
create function private.b08_ticket_guard() returns trigger language plpgsql set search_path = '' as $$
begin
 if tg_op = 'DELETE' then raise exception 'Bilhetes de emissão não são excluídos'; end if;
 if old.finished_at is not null then raise exception 'Bilhete encerrado é imutável'; end if;
 if (new.ticket, new.purpose, new.emission_id, new.created_at, new.expires_at) is distinct from (old.ticket, old.purpose, old.emission_id, old.created_at, old.expires_at)
    or new.params::text is distinct from old.params::text then raise exception 'Identidade do bilhete é imutável'; end if;
 return new;
end;$$;
create trigger document_emission_tickets_guard before update or delete on private.document_emission_tickets
 for each row execute function private.b08_ticket_guard();

create function private.b08_endpoint() returns text language sql immutable set search_path = '' as
 $$ select 'https://zlckcpeqcxmtrgbdquee.supabase.co/functions/v1/document-emission' $$;

-- Cria o bilhete e agenda a chamada HTTP (o pg_net envia depois do commit da transação).
create function private.b08_dispatch(p_purpose text, p_emission uuid default null, p_params jsonb default '{}'::jsonb) returns uuid
 language plpgsql security definer set search_path = '' as $$
declare t uuid; rid bigint;
begin
 insert into private.document_emission_tickets (purpose, emission_id, params) values (p_purpose, p_emission, coalesce(p_params, '{}'::jsonb)) returning ticket into t;
 select net.http_post(url := private.b08_endpoint(), body := jsonb_build_object('action', 'ticket', 'ticket', t),
   headers := '{"Content-Type": "application/json"}'::jsonb, timeout_milliseconds := 150000) into rid;
 update private.document_emission_tickets set request_id = rid where ticket = t;
 return t;
end;$$;

-- Varredura: até 5 pedidos por execução; não duplica bilhete em aberto; falha retomável espera 2 minutos.
create function private.b08_sweep() returns int language plpgsql security definer set search_path = '' as $$
declare r record; n int := 0;
begin
 for r in
  select e.id from private.document_emissions e
  where ((e.status = 'pending' and e.requested_at < clock_timestamp() - interval '30 seconds')
     or (e.status = 'processing' and e.lease_expires_at < clock_timestamp())
     or (e.status = 'failed' and e.attempt_count < e.max_attempts and coalesce((select max(a.finished_at) from private.document_emission_attempts a
          where a.emission_id = e.id), e.requested_at) < clock_timestamp() - interval '2 minutes'))
  and not exists (select 1 from private.document_emission_tickets k where k.emission_id = e.id and k.consumed_at is null and k.expires_at > clock_timestamp())
  order by e.requested_at limit 5
 loop
  perform private.b08_dispatch('process', r.id); n := n + 1;
 end loop;
 return n;
end;$$;

-- Bilhetes do lado da Edge Function (somente service_role): consumir uma vez e registrar o resultado.
create function private.b08_ticket(command text, payload jsonb) returns jsonb language plpgsql security definer set search_path = '' as $$
declare k private.document_emission_tickets;
begin
 select * into k from private.document_emission_tickets where ticket = (payload->>'ticket')::uuid for update;
 if command = 'consume' then
  if k.ticket is null or k.consumed_at is not null or k.expires_at < clock_timestamp() then return jsonb_build_object('valid', false); end if;
  update private.document_emission_tickets set consumed_at = clock_timestamp() where ticket = k.ticket;
  return jsonb_build_object('valid', true, 'purpose', k.purpose, 'emission_id', k.emission_id, 'params', k.params);
 elsif command = 'result' then
  if k.ticket is null or k.consumed_at is null or k.finished_at is not null then return jsonb_build_object('recorded', false); end if;
  update private.document_emission_tickets set finished_at = clock_timestamp(), result = payload->'result' where ticket = k.ticket;
  return jsonb_build_object('recorded', true);
 end if;
 raise exception 'Comando desconhecido';
end;$$;
create function public.document_emission_ticket(command text, payload jsonb) returns jsonb
 language sql set search_path = '' as $$ select private.b08_ticket(command, payload); $$;

revoke all on function private.b08_ticket_guard(), private.b08_endpoint(), private.b08_dispatch(text, uuid, jsonb), private.b08_sweep(),
 private.b08_ticket(text, jsonb) from public, anon, authenticated;
grant execute on function private.b08_ticket(text, jsonb) to service_role;
revoke all on function public.document_emission_ticket(text, jsonb) from public, anon, authenticated;
grant execute on function public.document_emission_ticket(text, jsonb) to service_role;

select cron.schedule('b08-document-emission-sweep', '* * * * *', 'select private.b08_sweep()');
