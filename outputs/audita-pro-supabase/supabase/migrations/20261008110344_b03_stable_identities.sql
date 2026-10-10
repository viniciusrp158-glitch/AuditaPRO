-- Recuperada de supabase_migrations.schema_migrations em 2026-10-10 (B00, Claude).
-- JA APLICADA no projeto zlckcpeqcxmtrgbdquee. NAO reaplicar. md5(statements)=c8ceb7b9bb43242a76018673433017ca

begin;

-- B03 keeps readable identities separate from UUID relationship keys.  The
-- counter row is the serialization point for each independent namespace.
create table private.stable_identity_counters (
  identity_type text not null,
  scope_key text not null,
  last_value bigint not null check (last_value >= 0),
  updated_at timestamptz not null default clock_timestamp(),
  primary key (identity_type, scope_key)
);

revoke all on table private.stable_identity_counters from public, anon, authenticated;

grant all on table private.stable_identity_counters to service_role;

create function private.format_stable_number(value bigint, minimum_width integer)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select case
    when length(value::text) < minimum_width
      then repeat('0', minimum_width - length(value::text)) || value::text
    else value::text
  end;
$$;

create function private.allocate_stable_identity(counter_type text, counter_scope text)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  allocated bigint;
begin
  if nullif(counter_type, '') is null or nullif(counter_scope, '') is null then
    raise exception 'Tipo e escopo do identificador são obrigatórios'
      using errcode = '22023';
  end if;

  insert into private.stable_identity_counters(identity_type, scope_key, last_value)
  values (counter_type, counter_scope, 1)
  on conflict (identity_type, scope_key) do update
    set last_value = private.stable_identity_counters.last_value + 1,
        updated_at = clock_timestamp()
  returning last_value into allocated;

  return allocated;
end;
$$;

revoke all on function private.format_stable_number(bigint, integer),
  private.allocate_stable_identity(text, text) from public, anon, authenticated;

grant execute on function private.format_stable_number(bigint, integer),
  private.allocate_stable_identity(text, text) to service_role;

alter table public.organizations add column code text;

alter table public.daily_reports add column code text;

alter table public.daily_report_versions add column revision_label text
  generated always as (
    'Rev.' || case
      when length((version_number - 1)::text) < 2
        then repeat('0', 2 - length((version_number - 1)::text)) ||
          (version_number - 1)::text
      else (version_number - 1)::text
    end
  ) stored;

-- Backfill is a schema conversion, not a business edit.  Existing document
-- guards may reject every UPDATE after publication, so hold the table's DDL
-- lock and suspend user triggers only while writing the new identity column.
-- Preserve any trigger that was already disabled and verify that no other
-- report field changes.  A migration failure rolls everything back.
create temporary table b03_disabled_daily_report_triggers
on commit drop
as
select t.tgname
from pg_catalog.pg_trigger t
where t.tgrelid = 'public.daily_reports'::regclass
  and not t.tgisinternal
  and t.tgenabled = 'D';

create temporary table b03_daily_report_backfill_snapshot
on commit drop
as
select r.id, to_jsonb(r) - 'code' as row_before
from public.daily_reports r;

alter table public.daily_reports disable trigger user;

-- Reuse an explicit RDA identity already frozen in legacy content.  Generic
-- content.code is deliberately ignored because it can identify another item.
with candidates as (
  select r.id,
         coalesce(nullif(r.content->>'rda_code', ''),
                  nullif(r.content#>>'{identity,rda_code}', '')) as legacy_code,
         row_number() over (
           partition by r.audit_id,
             coalesce(nullif(r.content->>'rda_code', ''),
                      nullif(r.content#>>'{identity,rda_code}', ''))
           order by coalesce(r.finalized_at, r.completed_at, r.created_at), r.id
         ) as duplicate_order
  from public.daily_reports r
  where r.finalized_at is not null
     or r.status in ('pending_acknowledgements', 'completed')
)
update public.daily_reports r
set code = c.legacy_code
from candidates c
where c.id = r.id
  and c.legacy_code ~ '^RDA-[0-9]+$'
  and c.duplicate_order = 1;

-- Seed every namespace from preserved codes before allocating anything new.
insert into private.stable_identity_counters(identity_type, scope_key, last_value)
select 'audit', substring(code from '^AUD-([0-9]{4})-'),
       max(substring(code from '^AUD-[0-9]{4}-([0-9]+)$')::bigint)
from public.audits
where code ~ '^AUD-[0-9]{4}-[0-9]{1,18}$'
group by substring(code from '^AUD-([0-9]{4})-')
on conflict (identity_type, scope_key) do update
  set last_value = greatest(private.stable_identity_counters.last_value, excluded.last_value),
      updated_at = clock_timestamp();

insert into private.stable_identity_counters(identity_type, scope_key, last_value)
select 'rda', audit_id::text,
       max(substring(code from '^RDA-([0-9]+)$')::bigint)
from public.daily_reports
where code ~ '^RDA-[0-9]{1,18}$'
group by audit_id
on conflict (identity_type, scope_key) do update
  set last_value = greatest(private.stable_identity_counters.last_value, excluded.last_value),
      updated_at = clock_timestamp();

insert into private.stable_identity_counters(identity_type, scope_key, last_value)
select 'finding:' || kind, audit_id::text, max(sequence_number)
from (
  select f.kind, f.audit_id,
         substring(f.code from '^(?:NC|OBS|OM)-([0-9]+)$')::bigint as sequence_number
  from public.assessment_findings f
  where f.code ~ '^(NC|OBS|OM)-[0-9]{1,18}$'
  union all
  select 'NC', n.audit_id,
         substring(n.code from '^NC-([0-9]+)$')::bigint
  from public.nonconformities n
  where n.code ~ '^NC-[0-9]{1,18}$'
) preserved_findings
group by kind, audit_id
on conflict (identity_type, scope_key) do update
  set last_value = greatest(private.stable_identity_counters.last_value, excluded.last_value),
      updated_at = clock_timestamp();

-- Existing clients did not have a dedicated code.  Their initial allocation is
-- deterministic and never changes names, CNPJs, UUIDs, or other legacy keys.
do $$
declare
  organization_row record;
  allocated bigint;
begin
  for organization_row in
    select id
    from public.organizations
    where code is null
    order by created_at, id
  loop
    allocated := private.allocate_stable_identity('client', 'global');
    update public.organizations
    set code = 'CLI-' || private.format_stable_number(allocated, 4)
    where id = organization_row.id;
  end loop;
end;
$$;

-- Closed legacy RDAs without a frozen code receive a stable identity in their
-- historical closing order.  Drafts remain unnumbered until first closing.
do $$
declare
  report_row record;
  allocated bigint;
begin
  for report_row in
    select r.id, r.audit_id
    from public.daily_reports r
    left join public.audit_days d on d.id = r.audit_day_id
    where r.code is null
      and (r.finalized_at is not null
        or r.status in ('pending_acknowledgements', 'completed'))
    order by r.audit_id,
      coalesce(r.finalized_at, r.completed_at, r.created_at),
      d.audit_date,
      r.id
  loop
    allocated := private.allocate_stable_identity('rda', report_row.audit_id::text);
    update public.daily_reports
    set code = 'RDA-' || private.format_stable_number(allocated, 2)
    where id = report_row.id;
  end loop;
end;
$$;

alter table public.daily_reports enable trigger user;

do $$
declare
  trigger_row record;
begin
  for trigger_row in
    select tgname from b03_disabled_daily_report_triggers order by tgname
  loop
    execute format(
      'alter table public.daily_reports disable trigger %I',
      trigger_row.tgname
    );
  end loop;

  if exists (
    select 1
    from b03_daily_report_backfill_snapshot s
    join public.daily_reports r on r.id = s.id
    where (to_jsonb(r) - 'code') is distinct from s.row_before
  ) then
    raise exception 'Backfill de RDA alterou dados além da nova identidade';
  end if;
end;
$$;

alter table public.organizations alter column code set not null;

alter table public.organizations
  add constraint organizations_code_key unique (code);

alter table public.daily_reports
  add constraint daily_reports_audit_id_code_key unique (audit_id, code);

comment on column public.organizations.code is
  'Identificador público permanente CLI-n, alocado globalmente pelo servidor.';

comment on column public.audits.code is
  'Identificador público permanente AUD-AAAA-n; legados são preservados.';

comment on column public.daily_reports.code is
  'Identificador lógico permanente RDA-n dentro da auditoria; atribuído no primeiro fechamento.';

comment on column public.daily_report_versions.revision_label is
  'Revisão visível: version_number 1 corresponde a Rev.00.';

create function private.assign_stable_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  allocated bigint;
  audit_year integer;
  linked_nc record;
begin
  if tg_table_name = 'organizations' then
    if tg_op = 'INSERT' then
      allocated := private.allocate_stable_identity('client', 'global');
      new.code := 'CLI-' || private.format_stable_number(allocated, 4);
    elsif new.code is distinct from old.code then
      raise exception 'O código do cliente é imutável'
        using errcode = '23514';
    end if;

  elsif tg_table_name = 'audits' then
    if tg_op = 'INSERT' then
      audit_year := extract(year from
        (coalesce(new.created_at, clock_timestamp()) at time zone
          coalesce(nullif(new.timezone, ''), 'America/Sao_Paulo')))::integer;
      allocated := private.allocate_stable_identity('audit', audit_year::text);
      new.code := 'AUD-' || audit_year::text || '-' ||
        private.format_stable_number(allocated, 4);
    elsif new.code is distinct from old.code then
      raise exception 'O código da auditoria é imutável'
        using errcode = '23514';
    end if;

  elsif tg_table_name = 'daily_reports' then
    if tg_op = 'UPDATE' and old.code is not null then
      if new.code is distinct from old.code then
        raise exception 'O código do RDA é imutável'
          using errcode = '23514';
      end if;
      if new.audit_id is distinct from old.audit_id then
        raise exception 'A auditoria de um RDA numerado é imutável'
          using errcode = '23514';
      end if;
    elsif tg_op = 'INSERT' or old.code is null then
      -- Discard any client-supplied value.  Only a non-draft state allocates it.
      new.code := null;
      if new.finalized_at is not null
         or new.status in ('pending_acknowledgements', 'completed') then
        allocated := private.allocate_stable_identity('rda', new.audit_id::text);
        new.code := 'RDA-' || private.format_stable_number(allocated, 2);
      end if;
    end if;

  elsif tg_table_name = 'nonconformities' then
    if tg_op = 'INSERT' then
      allocated := private.allocate_stable_identity('finding:NC', new.audit_id::text);
      new.code := 'NC-' || private.format_stable_number(allocated, 3);
    elsif new.code is distinct from old.code
       or new.audit_id is distinct from old.audit_id then
      raise exception 'A identidade da não conformidade é imutável'
        using errcode = '23514';
    end if;

  elsif tg_table_name = 'assessment_findings' then
    if tg_op = 'INSERT' then
      if new.kind = 'NC' and new.nonconformity_id is not null then
        select n.audit_id, n.code into linked_nc
        from public.nonconformities n
        where n.id = new.nonconformity_id;
        if not found or linked_nc.audit_id <> new.audit_id then
          raise exception 'A NC vinculada deve pertencer à mesma auditoria'
            using errcode = '23503';
        end if;
        new.code := linked_nc.code;
      else
        allocated := private.allocate_stable_identity(
          'finding:' || new.kind, new.audit_id::text
        );
        new.code := new.kind || '-' || private.format_stable_number(allocated, 3);
      end if;
    elsif new.code is distinct from old.code
       or new.audit_id is distinct from old.audit_id
       or new.kind is distinct from old.kind then
      raise exception 'A identidade do achado é imutável'
        using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.assign_stable_identity() from public, anon, authenticated;

grant execute on function private.assign_stable_identity() to service_role;

create trigger b03_organizations_stable_identity
before insert or update on public.organizations
for each row execute function private.assign_stable_identity();

create trigger b03_audits_stable_identity
before insert or update on public.audits
for each row execute function private.assign_stable_identity();

create trigger b03_daily_reports_stable_identity
before insert or update on public.daily_reports
for each row execute function private.assign_stable_identity();

create trigger b03_nonconformities_stable_identity
before insert or update on public.nonconformities
for each row execute function private.assign_stable_identity();

create trigger b03_assessment_findings_stable_identity
before insert or update on public.assessment_findings
for each row execute function private.assign_stable_identity();

commit;
