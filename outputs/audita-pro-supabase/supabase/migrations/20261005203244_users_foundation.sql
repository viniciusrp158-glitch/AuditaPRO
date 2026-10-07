-- Audita PRO: extend the existing identity and organization model.
-- Depends on foundation, audit domain and dashboard migrations.
begin;

create or replace function private.valid_cpf(value text)
returns boolean language plpgsql immutable set search_path = '' as $$
declare digits int[]; total int; check_digit int; i int;
begin
  if value is null or value !~ '^[0-9]{11}$' or value = repeat(left(value,1),11) then return false; end if;
  digits := array(select substring(value from n for 1)::int from generate_series(1,11) n);
  total := 0;
  for i in 1..9 loop total := total + digits[i] * (11-i); end loop;
  check_digit := (total * 10) % 11;
  if check_digit = 10 then check_digit := 0; end if;
  if digits[10] <> check_digit then return false; end if;
  total := 0;
  for i in 1..10 loop total := total + digits[i] * (12-i); end loop;
  check_digit := (total * 10) % 11;
  if check_digit = 10 then check_digit := 0; end if;
  return digits[11] = check_digit;
end;
$$;

create or replace function private.valid_cnpj(value text)
returns boolean language plpgsql immutable set search_path = '' as $$
declare digits int[]; total int; check_digit int; i int;
begin
  if value is null or value !~ '^[0-9]{14}$' or value = repeat(left(value,1),14) then return false; end if;
  digits := array(select substring(value from n for 1)::int from generate_series(1,14) n);
  total := 0;
  for i in 1..12 loop total := total + digits[i] * (case when i <= 4 then 6-i else 14-i end); end loop;
  check_digit := case when total % 11 < 2 then 0 else 11 - total % 11 end;
  if digits[13] <> check_digit then return false; end if;
  total := 0;
  for i in 1..13 loop total := total + digits[i] * (case when i <= 5 then 7-i else 15-i end); end loop;
  check_digit := case when total % 11 < 2 then 0 else 11 - total % 11 end;
  return digits[14] = check_digit;
end;
$$;

alter table public.user_profiles
  add column if not exists status text not null default 'active'
  check (status in ('active','inactive'));

alter table public.user_profiles
  add constraint user_profiles_cpf_digits_valid
  check (cpf is null or private.valid_cpf(cpf)) not valid;
alter table public.organizations
  add constraint organizations_cnpj_digits_valid
  check (private.valid_cnpj(cnpj)) not valid;

create table if not exists public.user_invites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  email text not null,
  status text not null default 'pending'
    check (status in ('pending','sent','accepted','failed','expired','existing_account')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  sent_at timestamptz,
  expires_at timestamptz,
  last_error text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists user_invites_email_time_idx
  on public.user_invites(lower(email),created_at desc);
create index if not exists user_invites_org_status_idx
  on public.user_invites(organization_id,status,created_at desc);
create trigger user_invites_updated_at before update on public.user_invites
  for each row execute function private.set_updated_at();

create table if not exists public.audit_participant_history (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.audits(id) on delete restrict,
  membership_id uuid not null references public.organization_memberships(id) on delete restrict,
  participant_id uuid references public.audit_participants(id) on delete set null,
  action text not null check (action in ('added','changed','removed','snapshot')),
  full_name text not null,
  participant_type text not null,
  active boolean not null,
  is_signatory boolean not null,
  occurred_at timestamptz not null default now(),
  actor_user_id uuid references auth.users(id) on delete set null
);
create index if not exists audit_participant_history_audit_time_idx
  on public.audit_participant_history(audit_id,occurred_at desc);

create or replace function private.record_participant_history()
returns trigger language plpgsql security definer set search_path = '' as $$
declare row_value public.audit_participants%rowtype; member_name text;
begin
  if tg_op = 'UPDATE' and new.active is not distinct from old.active
     and new.participant_type is not distinct from old.participant_type
     and new.is_signatory is not distinct from old.is_signatory then return new; end if;
  if tg_op = 'DELETE' then row_value := old; else row_value := new; end if;
  select coalesce(nullif(trim(p.full_name),''),'Participante') into member_name
    from public.organization_memberships m
    left join public.user_profiles p on p.user_id=m.user_id
    where m.id=row_value.membership_id;
  insert into public.audit_participant_history
    (audit_id,membership_id,participant_id,action,full_name,participant_type,active,is_signatory,actor_user_id)
  values (row_value.audit_id,row_value.membership_id,
    case when tg_op='DELETE' then null else row_value.id end,
    case when tg_op='INSERT' then 'added' when tg_op='DELETE' then 'removed' else 'changed' end,
    coalesce(member_name,'Participante'),row_value.participant_type,row_value.active,row_value.is_signatory,auth.uid());
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;
drop trigger if exists participant_history_event on public.audit_participants;
create trigger participant_history_event after insert or update or delete on public.audit_participants
  for each row execute function private.record_participant_history();

insert into public.audit_participant_history
  (audit_id,membership_id,participant_id,action,full_name,participant_type,active,is_signatory,occurred_at)
select ap.audit_id,ap.membership_id,ap.id,'snapshot',
  coalesce(nullif(trim(up.full_name),''),'Participante'),ap.participant_type,ap.active,ap.is_signatory,ap.added_at
from public.audit_participants ap
join public.organization_memberships m on m.id=ap.membership_id
left join public.user_profiles up on up.user_id=m.user_id
where not exists (select 1 from public.audit_participant_history h where h.participant_id=ap.id);

create or replace function private.guard_user_profile_changes()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null and not public.is_platform_admin()
    and (new.cpf is distinct from old.cpf or new.email is distinct from old.email
      or new.status is distinct from old.status) then
    raise exception 'Somente o Administrador pode alterar CPF, e-mail ou status da conta';
  end if;
  if old.status='active' and new.status='inactive'
    and exists(select 1 from auth.users u where u.id=old.user_id
      and u.raw_app_meta_data->>'platform_role'='admin')
    and not exists(select 1 from auth.users u
      join public.user_profiles p on p.user_id=u.id
      where u.id<>old.user_id and u.raw_app_meta_data->>'platform_role'='admin'
        and p.status='active') then
    raise exception 'O último Administrador ativo não pode ser inativado';
  end if;
  return new;
end;
$$;
drop trigger if exists guard_user_profile_changes on public.user_profiles;
create trigger guard_user_profile_changes before update on public.user_profiles
  for each row execute function private.guard_user_profile_changes();

create or replace function private.guard_membership_changes()
returns trigger language plpgsql security definer set search_path = '' as $$
declare identity_required boolean; profile_name text; recheck_required boolean;
begin
  recheck_required := tg_op='INSERT';
  if tg_op='UPDATE' then
    if new.competence_status is distinct from old.competence_status
      and pg_trigger_depth() < 2 then
      raise exception 'A competência é definida pela análise do documento';
    end if;
    recheck_required := new.position_id is distinct from old.position_id
      or new.access_profile_id is distinct from old.access_profile_id;
    if old.status='active'
      and (new.status<>'active' or recheck_required)
      and exists(select 1 from public.audits a where a.leader_membership_id=old.id
        and a.status in ('planned','in_progress','awaiting_signoff')) then
      raise exception 'Substitua o Auditor Líder das auditorias ativas antes de alterar este vínculo';
    end if;
  end if;
  if recheck_required then
    select p.requires_identity_document into identity_required
      from public.positions p where p.id=new.position_id and p.status='active';
    if new.position_id is not null and identity_required is null then
      raise exception 'Cargo inválido ou inativo';
    end if;
    select p.name into profile_name from public.access_profiles p
      where p.id=new.access_profile_id and p.status='active';
    if new.access_profile_id is not null and profile_name is null then
      raise exception 'Perfil inválido ou inativo';
    end if;
    identity_required := coalesce(identity_required,false)
      or profile_name in ('Auditor Líder','Auditor','Participante / Auditado');
    new.competence_status := case when coalesce(identity_required,false) then 'pending' else 'not_required' end;
  end if;
  return new;
end;
$$;
create or replace function private.sync_document_competence()
returns trigger language plpgsql security definer set search_path = '' as $$
declare latest_status text;
begin
  select d.status into latest_status from public.user_documents d
    where d.membership_id=new.membership_id and d.document_type='identity'
    order by d.uploaded_at desc,d.id desc limit 1;
  update public.organization_memberships m
    set competence_status=coalesce(latest_status,'pending')
    where m.id=new.membership_id and m.competence_status is distinct from coalesce(latest_status,'pending');
  return new;
end;
$$;
drop trigger if exists user_documents_competence on public.user_documents;
create trigger user_documents_competence after insert or update of status on public.user_documents
  for each row execute function private.sync_document_competence();

create or replace function private.guard_organization_inactivation()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.status='active' and new.status='inactive' and exists (
    select 1 from public.audits a where a.organization_id=old.id
      and a.status in ('planned','in_progress','awaiting_signoff')) then
    raise exception 'Conclua ou cancele as auditorias ativas antes de inativar esta organização';
  end if;
  return new;
end;
$$;
drop trigger if exists guard_organization_inactivation on public.organizations;
create trigger guard_organization_inactivation before update on public.organizations
  for each row execute function private.guard_organization_inactivation();

update public.positions set name='Participante / Auditado' where name='Cliente'
  and not exists(select 1 from public.positions where name='Participante / Auditado');

-- Existing profile IDs remain stable; only their permission assignments change.
insert into public.access_profiles(name,is_system,status)
values ('Auditor Líder',true,'active'),('Participante / Auditado',true,'active')
on conflict(name) do update set status='active';
delete from public.access_profile_permissions pp
  using public.access_profiles p
  where pp.profile_id=p.id and p.name='Auditor';
insert into public.access_profile_permissions(profile_id,permission_id,allowed)
select p.id,a.id,true from public.access_profiles p
join public.access_permissions a on
  (p.name='Auditor' and a.permission_key in ('audit.view','report.view','indicators.view'))
  or (p.name='Participante / Auditado' and a.permission_key in ('audit.view','report.view','indicators.view'))
  or (p.name='Auditor Líder' and a.permission_key in
      ('audit.view','audit.create','audit.update','audit.close','audit.manage_participants',
       'schedule.manage','schedule.execute','evidence.upload','nonconformity.create',
       'nonconformity.update','action.create','action.update','report.view','report.edit',
       'report.finalize','report.acknowledge','report.gov_upload','indicators.view'))
where p.name in ('Auditor','Participante / Auditado','Auditor Líder')
on conflict(profile_id,permission_id) do update set allowed=true;

-- Preserve old leader rights by moving only clearly identified leaders to the new profile.
update public.organization_memberships m
set access_profile_id=(select id from public.access_profiles where name='Auditor Líder')
where m.access_profile_id=(select id from public.access_profiles where name='Auditor')
  and m.position_id=(select id from public.positions where name='Auditor Líder');
update public.organization_memberships m
set access_profile_id=(select id from public.access_profiles where name='Participante / Auditado')
where m.access_profile_id=(select id from public.access_profiles where name='Consulta')
  and m.position_id=(select id from public.positions where name='Participante / Auditado');
update public.access_profiles set status='inactive'
where name in ('Gestor','Consulta','Personalizado');

drop trigger if exists guard_membership_changes on public.organization_memberships;
create trigger guard_membership_changes before insert or update on public.organization_memberships
  for each row execute function private.guard_membership_changes();

revoke all on function private.valid_cpf(text),private.valid_cnpj(text),
  private.record_participant_history(),private.guard_user_profile_changes(),
  private.guard_membership_changes(),private.sync_document_competence(),
  private.guard_organization_inactivation() from public;

commit;
