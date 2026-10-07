begin;
create or replace function private.guard_user_inactivation_dependencies()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status='active' and new.status='inactive' then
    if exists(select 1 from public.audits a
      join public.organization_memberships m on m.id=a.leader_membership_id
      where m.user_id=old.user_id and a.status in ('draft','planned','in_progress','awaiting_signoff')) then
      raise exception 'Substitua o Auditor Líder nas auditorias abertas antes de inativar a conta';
    end if;
    if exists(select 1 from public.audit_participants ap
      join public.organization_memberships m on m.id=ap.membership_id
      join public.audits a on a.id=ap.audit_id
      where m.user_id=old.user_id and ap.active
        and a.status in ('planned','in_progress','awaiting_signoff')) then
      raise exception 'Resolva a participação nas auditorias ativas antes de inativar a conta';
    end if;
    if exists(select 1 from public.report_acknowledgements ra
      join public.organization_memberships m on m.id=ra.membership_id
      where m.user_id=old.user_id and ra.status='pending') then
      raise exception 'Resolva as confirmações de ciência pendentes antes de inativar a conta';
    end if;
  end if;
  return new;
end;
$$;
create trigger guard_user_inactivation_dependencies before update of status
  on public.user_profiles for each row execute function private.guard_user_inactivation_dependencies();
revoke all on function private.guard_user_inactivation_dependencies() from public;
commit;
