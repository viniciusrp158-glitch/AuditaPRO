begin;
create or replace function public.user_inactivation_dependencies(target_user uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if auth.uid() is null or not public.is_platform_admin() then
    raise exception 'Acesso não autorizado' using errcode='42501';
  end if;
  select jsonb_build_object(
    'led_audits',(select count(*) from public.audits a
      join public.organization_memberships m on m.id=a.leader_membership_id
      where m.user_id=target_user and a.status in ('draft','planned','in_progress','awaiting_signoff')),
    'participations',(select count(*) from public.audit_participants ap
      join public.organization_memberships m on m.id=ap.membership_id
      join public.audits a on a.id=ap.audit_id
      where m.user_id=target_user and ap.active
        and a.status in ('planned','in_progress','awaiting_signoff')),
    'pending_acknowledgements',(select count(*) from public.report_acknowledgements ra
      join public.organization_memberships m on m.id=ra.membership_id
      where m.user_id=target_user and ra.status='pending')
  ) into result;
  return result;
end;
$$;
revoke all on function public.user_inactivation_dependencies(uuid) from public;
grant execute on function public.user_inactivation_dependencies(uuid) to authenticated;
commit;
