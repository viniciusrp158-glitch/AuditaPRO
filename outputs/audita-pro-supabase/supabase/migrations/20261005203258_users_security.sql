-- Audita PRO: authorization for the four approved profiles and onboarding.
begin;

alter table public.organizations add constraint organizations_segment_required
  check (segment is not null and length(trim(segment)) between 2 and 160) not valid;
alter table public.user_documents add constraint user_documents_rejection_note_required
  check (status<>'rejected' or length(trim(coalesce(review_note,'')))>=3) not valid;

create or replace function private.is_active_account(target_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select target_user is not null and exists (
    select 1 from public.user_profiles p where p.user_id=target_user and p.status='active'
  );
$$;

-- Consult current protected Auth metadata so a stale JWT cannot retain admin rights.
create or replace function public.is_platform_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_active_account(auth.uid()) and exists (
    select 1 from auth.users u where u.id=auth.uid()
      and u.raw_app_meta_data->>'platform_role'='admin'
  );
$$;

create or replace function private.is_active_org_member(target_organization_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_active_account(auth.uid()) and exists (
    select 1 from public.organization_memberships m
    join public.organizations o on o.id=m.organization_id
    join public.user_profiles up on up.user_id=m.user_id
    join public.access_profiles prof on prof.id=m.access_profile_id
    where m.organization_id=target_organization_id and m.user_id=auth.uid()
      and m.status='active' and o.status='active' and up.cpf is not null
      and prof.status='active'
      and m.competence_status in ('approved','not_required')
  );
$$;

-- Ownership of a pending document must work before competence approval.
create or replace function private.is_active_membership_owner(target_membership_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_active_account(auth.uid()) and exists (
    select 1 from public.organization_memberships m
    join public.organizations o on o.id=m.organization_id
    where m.id=target_membership_id and m.user_id=auth.uid()
      and m.status='active' and o.status='active'
  );
$$;

create or replace function private.has_org_permission(target_org uuid,required_permission text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_platform_admin() or (
    private.is_active_account(auth.uid()) and exists (
      select 1 from public.organization_memberships m
      join public.organizations o on o.id=m.organization_id
      join public.user_profiles up on up.user_id=m.user_id
      join public.access_profiles prof on prof.id=m.access_profile_id
      join public.access_permissions p on p.permission_key=required_permission
      left join public.access_profile_permissions pp
        on pp.profile_id=m.access_profile_id and pp.permission_id=p.id
      left join public.membership_permissions mp
        on mp.membership_id=m.id and mp.permission_id=p.id
      where m.organization_id=target_org and m.user_id=auth.uid()
        and m.status='active' and o.status='active' and prof.status='active'
        and up.cpf is not null and m.competence_status in ('approved','not_required')
        and prof.name='Auditor Líder'
        and coalesce(mp.allowed,pp.allowed,false)
    )
  );
$$;

create or replace function private.is_audit_participant(target_audit uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_platform_admin() or (
    private.is_active_account(auth.uid()) and exists (
      select 1 from public.audits a
      join public.organizations o on o.id=a.organization_id
      join public.organization_memberships m on m.organization_id=a.organization_id
        and m.user_id=auth.uid() and m.status='active'
        and m.competence_status in ('approved','not_required')
      join public.user_profiles up on up.user_id=m.user_id
      join public.access_profiles prof on prof.id=m.access_profile_id and prof.status='active'
      where a.id=target_audit and o.status='active' and up.cpf is not null
        and (a.leader_membership_id=m.id or exists (
          select 1 from public.audit_participants ap
          where ap.audit_id=a.id and ap.membership_id=m.id and ap.active
        ))
    )
  );
$$;

create or replace function private.has_audit_permission(target_audit uuid,required_permission text)
returns boolean language sql stable security definer set search_path = '' as $$
  select (public.is_platform_admin() and exists (
    select 1 from public.audits a join public.organizations o on o.id=a.organization_id
    where a.id=target_audit and (o.status='active'
      or required_permission in ('audit.view','report.view','indicators.view'))
  )) or (
    private.is_active_account(auth.uid()) and exists (
      select 1 from public.audits a
      join public.organizations o on o.id=a.organization_id
      join public.organization_memberships m on m.organization_id=a.organization_id
        and m.user_id=auth.uid() and m.status='active'
        and m.competence_status in ('approved','not_required')
      join public.user_profiles up on up.user_id=m.user_id
      join public.access_profiles prof on prof.id=m.access_profile_id and prof.status='active'
      join public.access_permissions p on p.permission_key=required_permission
      left join public.access_profile_permissions pp
        on pp.profile_id=m.access_profile_id and pp.permission_id=p.id
      left join public.membership_permissions mp
        on mp.membership_id=m.id and mp.permission_id=p.id
      where a.id=target_audit and o.status='active' and up.cpf is not null
        and coalesce(mp.allowed,pp.allowed,false)
        and (prof.name='Auditor Líder' or
          (prof.name in ('Auditor','Participante / Auditado')
            and required_permission in ('audit.view','report.view','indicators.view','report.acknowledge')))
        and (a.leader_membership_id=m.id or exists (
          select 1 from public.audit_participants ap
          where ap.audit_id=a.id and ap.membership_id=m.id and ap.active
        ))
    )
  );
$$;

create or replace function private.is_audit_leader(target_audit uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_platform_admin() or (
    private.is_active_account(auth.uid()) and exists (
      select 1 from public.audits a
      join public.organizations o on o.id=a.organization_id
      join public.organization_memberships m on m.organization_id=a.organization_id
        and m.user_id=auth.uid() and m.status='active'
        and m.competence_status in ('approved','not_required')
      join public.user_profiles up on up.user_id=m.user_id
      join public.access_profiles prof on prof.id=m.access_profile_id
      where a.id=target_audit and o.status='active' and up.cpf is not null
        and prof.name='Auditor Líder' and prof.status='active'
        and (a.leader_membership_id=m.id or exists (
          select 1 from public.audit_participants ap
          where ap.audit_id=a.id and ap.membership_id=m.id
            and ap.participant_type='leader' and ap.active
        ))
    )
  );
$$;

-- Direct browser upload may bypass file-signature checks. The Edge Function
-- validates bytes and writes with its server credential instead.
drop policy if exists user_documents_insert_self on public.user_documents;
drop policy if exists identity_objects_insert_self on storage.objects;

alter table public.user_invites enable row level security;
drop policy if exists user_invites_admin_read on public.user_invites;
create policy user_invites_admin_read on public.user_invites for select to authenticated
  using (public.is_platform_admin());
grant select on public.user_invites to authenticated;
revoke insert,update,delete on public.user_invites from authenticated;

alter table public.audit_participant_history enable row level security;
drop policy if exists audit_participant_history_read on public.audit_participant_history;
create policy audit_participant_history_read on public.audit_participant_history
  for select to authenticated using (private.is_audit_participant(audit_id));
grant select on public.audit_participant_history to authenticated;

-- The existing self-update policy still permits name/phone. A trigger rejects
-- self-edits to CPF, email or status; admins may edit those columns.
grant update (full_name,phone,cpf,email,status) on public.user_profiles to authenticated;

create or replace function public.audit_team_directory(target_audit uuid)
returns table(user_id uuid,full_name text,participant_type text,active boolean,is_signatory boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not private.is_audit_participant(target_audit)
    or not private.has_audit_permission(target_audit,'audit.view') then
    raise exception 'Acesso à equipe não autorizado' using errcode='42501';
  end if;
  return query
    select m.user_id,coalesce(nullif(trim(p.full_name),''),'Participante'),
      ap.participant_type,ap.active,ap.is_signatory
    from public.audit_participants ap
    join public.organization_memberships m on m.id=ap.membership_id
    left join public.user_profiles p on p.user_id=m.user_id
    where ap.audit_id=target_audit
    union all
    select m.user_id,coalesce(nullif(trim(p.full_name),''),'Auditor Líder'),
      'leader'::text,true,false
    from public.audits a
    join public.organization_memberships m on m.id=a.leader_membership_id
    left join public.user_profiles p on p.user_id=m.user_id
    where a.id=target_audit and not exists (
      select 1 from public.audit_participants ap
      where ap.audit_id=a.id and ap.membership_id=m.id
    );
end;
$$;

revoke all on function public.audit_team_directory(uuid) from public;
grant execute on function public.audit_team_directory(uuid) to authenticated;

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
        order by d.uploaded_at desc,d.id desc limit 1)
    ) order by o.legal_name) from public.organization_memberships m
      join public.organizations o on o.id=m.organization_id
      left join public.positions pos on pos.id=m.position_id
      left join public.access_profiles ap on ap.id=m.access_profile_id
      where m.user_id=p.user_id),'[]'::jsonb)
  ) into result from public.user_profiles p where p.user_id=auth.uid();
  return coalesce(result,'{}'::jsonb);
end;
$$;
revoke all on function public.my_onboarding_context() from public;
grant execute on function public.my_onboarding_context() to authenticated;

create or replace function private.require_active_organization_for_audit()
returns trigger language plpgsql set search_path = '' as $$
begin
  if not exists(select 1 from public.organizations o
    where o.id=new.organization_id and o.status='active') then
    raise exception 'Não é possível criar auditoria em organização inativa';
  end if;
  return new;
end;
$$;
drop trigger if exists active_organization_for_audit on public.audits;
create trigger active_organization_for_audit before insert or update of organization_id on public.audits
  for each row execute function private.require_active_organization_for_audit();
revoke all on function private.is_active_account(uuid),
  private.has_org_permission(uuid,text),private.has_audit_permission(uuid,text),
  private.is_audit_participant(uuid),private.is_audit_leader(uuid),
  private.is_active_org_member(uuid),private.is_active_membership_owner(uuid) from public;
revoke all on function private.require_active_organization_for_audit() from public;
grant execute on function private.is_active_account(uuid),
  private.has_org_permission(uuid,text),private.has_audit_permission(uuid,text),
  private.is_audit_participant(uuid),private.is_audit_leader(uuid),
  private.is_active_org_member(uuid),private.is_active_membership_owner(uuid) to authenticated;
revoke all on function public.is_platform_admin() from public;
grant execute on function public.is_platform_admin() to authenticated;

commit;
