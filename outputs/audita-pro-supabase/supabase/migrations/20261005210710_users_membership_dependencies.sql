begin;
create or replace function private.guard_membership_inactivation_dependencies()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status='active' and new.status='inactive' then
    if exists(select 1 from public.audit_participants ap
      join public.audits a on a.id=ap.audit_id
      where ap.membership_id=old.id and ap.active
        and a.status in ('planned','in_progress','awaiting_signoff')) then
      raise exception 'Resolva a participação nas auditorias ativas antes de inativar o vínculo';
    end if;
    if exists(select 1 from public.report_acknowledgements ra
      where ra.membership_id=old.id and ra.status='pending') then
      raise exception 'Resolva as confirmações de ciência pendentes antes de inativar o vínculo';
    end if;
  end if;
  return new;
end;
$$;
create trigger guard_membership_inactivation_dependencies before update of status
  on public.organization_memberships for each row
  execute function private.guard_membership_inactivation_dependencies();
revoke all on function private.guard_membership_inactivation_dependencies() from public;
commit;
