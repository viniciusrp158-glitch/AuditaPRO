-- Emulação mínima da plataforma Supabase para testes locais (PostgreSQL 16).
-- Não é usado em produção. Reproduz roles, auth.uid()/jwt(), auth.users e storage.* consumidos pelas migrations.
do $$ begin
 if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin noinherit; end if;
 if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin noinherit; end if;
 if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin noinherit bypassrls; end if;
 if not exists (select 1 from pg_roles where rolname = 'authenticator') then create role authenticator login noinherit; end if;
end $$;
grant anon, authenticated, service_role to authenticator;
create schema auth; create schema storage; create schema extensions;
create extension pgcrypto with schema extensions;
grant usage on schema public, auth, storage, extensions to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
create table auth.users (
 instance_id uuid, id uuid primary key, aud varchar(255), role varchar(255), email varchar(255),
 encrypted_password varchar(255), email_confirmed_at timestamptz, invited_at timestamptz,
 raw_app_meta_data jsonb default '{}'::jsonb, raw_user_meta_data jsonb default '{}'::jsonb,
 created_at timestamptz default now(), updated_at timestamptz default now(), phone text,
 last_sign_in_at timestamptz, banned_until timestamptz, deleted_at timestamptz, is_anonymous boolean not null default false);
create function auth.jwt() returns jsonb language sql stable as
 $$ select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $$;
create function auth.uid() returns uuid language sql stable as
 $$ select nullif(coalesce(current_setting('request.jwt.claim.sub', true), auth.jwt()->>'sub'), '')::uuid $$;
create function auth.role() returns text language sql stable as
 $$ select coalesce(current_setting('request.jwt.claim.role', true), auth.jwt()->>'role') $$;
grant execute on all functions in schema auth to anon, authenticated, service_role;
grant select on auth.users to service_role;
create table storage.buckets (id text primary key, name text not null, owner uuid, created_at timestamptz default now(),
 updated_at timestamptz default now(), public boolean default false, avif_autodetection boolean default false,
 file_size_limit bigint, allowed_mime_types text[], owner_id text, type text);
create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text references storage.buckets(id),
 name text, owner uuid, created_at timestamptz default now(), updated_at timestamptz default now(),
 last_accessed_at timestamptz default now(), metadata jsonb, path_tokens text[] generated always as (string_to_array(name, '/')) stored,
 version text, owner_id text, user_metadata jsonb, unique (bucket_id, name));
alter table storage.buckets enable row level security;
alter table storage.objects enable row level security;
grant all on storage.buckets, storage.objects to service_role;
grant select, insert, update, delete on storage.objects to authenticated;
grant select on storage.buckets to authenticated, anon;
create function storage.foldername(name text) returns text[] language plpgsql immutable as
 $$ declare p text[]; begin p := string_to_array(name, '/'); return p[1:array_length(p, 1) - 1]; end $$;
grant execute on function storage.foldername(text) to anon, authenticated, service_role;
-- pg_net e pg_cron (B08): stubs que registram as chamadas para verificação nos testes.
create schema net; create schema cron;
create table net.stub_requests (id bigserial primary key, url text, body jsonb, headers jsonb, timeout_milliseconds int, created_at timestamptz default clock_timestamp());
create function net.http_post(url text, body jsonb default '{}'::jsonb, params jsonb default '{}'::jsonb,
 headers jsonb default '{"Content-Type": "application/json"}'::jsonb, timeout_milliseconds int default 5000) returns bigint
 language sql as $$ insert into net.stub_requests (url, body, headers, timeout_milliseconds) values (url, body, headers, timeout_milliseconds) returning id $$;
create table cron.stub_jobs (jobid bigserial primary key, jobname text unique, schedule text, command text);
create function cron.schedule(job_name text, schedule text, command text) returns bigint language sql as
 $$ insert into cron.stub_jobs (jobname, schedule, command) values (job_name, schedule, command)
    on conflict (jobname) do update set schedule = excluded.schedule, command = excluded.command returning jobid $$;
