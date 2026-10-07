-- Self-service organization request without granting access, and unit safety.
begin;

create table public.organization_access_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  organization_name text not null check (length(trim(organization_name)) between 2 and 200),
  cnpj text check (cnpj is null or private.valid_cnpj(cnpj)),
  note text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz not null default now(),
  check (status <> 'rejected' or length(trim(coalesce(review_note,''))) >= 3),
  check ((status='pending' and reviewed_by is null and reviewed_at is null)
      or (status<>'pending' and reviewed_by is not null and reviewed_at is not null))
);
create index organization_access_requests_user_status_idx
  on public.organization_access_requests(user_id,status,created_at desc);
create index organization_access_requests_pending_idx
  on public.organization_access_requests(created_at) where status='pending';
alter table public.organization_access_requests enable row level security;
create policy access_requests_read on public.organization_access_requests for select to authenticated
  using (user_id=auth.uid() or public.is_platform_admin());
create policy access_requests_self_insert on public.organization_access_requests for insert to authenticated
  with check (user_id=auth.uid() and status='pending'
    and reviewed_by is null and reviewed_at is null and review_note is null
    and private.is_active_account(auth.uid()));
create policy access_requests_admin_update on public.organization_access_requests for update to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());
grant select,insert,update on public.organization_access_requests to authenticated;

create or replace function private.guard_unit_changes()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status='active' and new.status='inactive'
    and (exists(select 1 from public.organization_memberships m
      where m.unit_id=old.id and m.status='active')
      or exists(select 1 from public.audits a where a.unit_id=old.id
        and a.status in ('draft','planned','in_progress','awaiting_signoff'))) then
    raise exception 'Inative os vínculos e conclua auditorias desta unidade antes de inativá-la';
  end if;
  return new;
end;
$$;
create trigger guard_unit_changes before update on public.organization_units
  for each row execute function private.guard_unit_changes();

create or replace function private.require_active_membership_unit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status='active' and new.unit_id is not null
    and not exists(select 1 from public.organization_units u where u.id=new.unit_id
      and u.organization_id=new.organization_id and u.status='active') then
    raise exception 'Não é possível ativar vínculo em unidade inativa';
  end if;
  return new;
end;
$$;
create trigger require_active_membership_unit before insert or update of unit_id,status
  on public.organization_memberships for each row
  execute function private.require_active_membership_unit();

create or replace function private.require_active_audit_unit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.unit_id is not null and not exists(select 1 from public.organization_units u
    where u.id=new.unit_id and u.organization_id=new.organization_id and u.status='active') then
    raise exception 'A unidade da auditoria está inativa';
  end if;
  return new;
end;
$$;
create trigger require_active_audit_unit before insert or update of unit_id
  on public.audits for each row execute function private.require_active_audit_unit();

create or replace function public.my_onboarding_context()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if auth.uid() is null then raise exception 'Sessão ausente' using errcode='42501'; end if;
  select jsonb_build_object(
    'profile',jsonb_build_object('user_id',p.user_id,'full_name',p.full_name,
      'email',p.email,'cpf',p.cpf,'phone',p.phone,'status',p.status),
    'memberships',coalesce((select jsonb_agg(jsonb_build_object(
      'id',m.id,'status',m.status,'competence_status',m.competence_status,
      'organization_id',o.id,'organization',o.legal_name,'organization_status',o.status,
      'unit_id',m.unit_id,'position',pos.name,'profile',ap.name,
      'document_status',(select d.status from public.user_documents d
        where d.membership_id=m.id and d.document_type='identity'
        order by d.uploaded_at desc,d.id desc limit 1),
      'document_note',(select d.review_note from public.user_documents d
        where d.membership_id=m.id and d.document_type='identity'
        order by d.uploaded_at desc,d.id desc limit 1)
    ) order by o.legal_name) from public.organization_memberships m
      join public.organizations o on o.id=m.organization_id
      left join public.positions pos on pos.id=m.position_id
      left join public.access_profiles ap on ap.id=m.access_profile_id
      where m.user_id=p.user_id),'[]'::jsonb),
    'requests',coalesce((select jsonb_agg(jsonb_build_object(
      'id',r.id,'organization_name',r.organization_name,'cnpj',r.cnpj,
      'status',r.status,'review_note',r.review_note,'created_at',r.created_at)
      order by r.created_at desc) from public.organization_access_requests r
      where r.user_id=p.user_id),'[]'::jsonb)
  ) into result from public.user_profiles p where p.user_id=auth.uid();
  return coalesce(result,'{}'::jsonb);
end;
$$;

revoke all on function private.guard_unit_changes(),private.require_active_membership_unit(),
  private.require_active_audit_unit() from public;
commit;
