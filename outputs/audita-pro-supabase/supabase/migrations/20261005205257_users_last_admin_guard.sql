-- Keep at least one active global Administrator even under concurrent changes.
begin;

create or replace function private.guard_last_admin_role()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.raw_app_meta_data->>'platform_role'='admin'
    and new.raw_app_meta_data->>'platform_role' is distinct from 'admin' then
    perform pg_advisory_xact_lock(62022119);
    if not exists(select 1 from auth.users u
      join public.user_profiles p on p.user_id=u.id
      where u.id<>old.id and u.raw_app_meta_data->>'platform_role'='admin'
        and p.status='active') then
      raise exception 'O último Administrador ativo não pode perder esse papel';
    end if;
  end if;
  return new;
end;
$$;
create trigger guard_last_admin_role before update of raw_app_meta_data on auth.users
  for each row execute function private.guard_last_admin_role();

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
      and u.raw_app_meta_data->>'platform_role'='admin') then
    perform pg_advisory_xact_lock(62022119);
    if not exists(select 1 from auth.users u
      join public.user_profiles p on p.user_id=u.id
      where u.id<>old.user_id and u.raw_app_meta_data->>'platform_role'='admin'
        and p.status='active') then
      raise exception 'O último Administrador ativo não pode ser inativado';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.guard_last_admin_role() from public;
commit;
