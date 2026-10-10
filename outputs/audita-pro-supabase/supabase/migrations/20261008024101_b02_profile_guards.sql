-- Recuperada de supabase_migrations.schema_migrations em 2026-10-10 (B00, Claude).
-- JA APLICADA no projeto zlckcpeqcxmtrgbdquee. NAO reaplicar. md5(statements)=cedaf810e773f0f0add73c732fcadcf8

-- B02 / D05 / PER-20. Approved functional data is managed administratively;
-- renewing personal evidence remains the existing versioned onboarding workflow.
create function private.b02_participant_approved(mid uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.organization_memberships m
 where m.id=mid and private.b02_profile_role(m.access_profile_id)='participant'
 and exists(select 1 from public.profile_submissions s where s.membership_id=m.id
 and s.access_profile_id=m.access_profile_id and s.state='approved'));
$$;

create function private.b02_functional_profile(mid uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('position_id',m.position_id,'unit_id',m.unit_id,
 'function',m.professional_data->>'function','department',m.professional_data->>'department',
 'manager',m.professional_data->>'manager','manager_contact',m.professional_data->>'manager_contact')
 from public.organization_memberships m where m.id=mid;
$$;

create function private.b02_functional_fields(value jsonb) returns jsonb
language sql immutable set search_path='' as $$
 select jsonb_build_object('position_id',nullif(value->>'position_id',''),
 'unit_id',nullif(value->>'unit_id',''),'function',nullif(value->>'function',''),
 'department',nullif(value->>'department',''),'manager',nullif(value->>'manager',''),
 'manager_contact',nullif(value->>'manager_contact',''));
$$;

-- Triggers also guard future SECURITY DEFINER callers; no request flag can bypass
-- them. Admin RPCs retain their real auth.uid(); trusted service provisioning is
-- allowed, and cannot be invoked with the browser's publishable key.
create function private.b02_profile_submission_guard() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is not null and not private.profile_admin(auth.uid()) then
  if tg_op='UPDATE' and (new.user_id is distinct from old.user_id
   or new.membership_id is distinct from old.membership_id
   or new.access_profile_id is distinct from old.access_profile_id) then
   raise exception 'Perfil e vínculo são definidos pela Administração' using errcode='42501';
  end if;
  if new.membership_id is not null and private.b02_participant_approved(new.membership_id) then
   if tg_op='INSERT' then
    -- A renewal copies current managed data, never an outdated prior revision.
    new.professional:=private.b02_functional_profile(new.membership_id);
   elsif (new.professional is distinct from old.professional or new.state='submitted') and private.b02_functional_fields(new.professional) is distinct from
     private.b02_functional_fields(private.b02_functional_profile(new.membership_id)) then
    raise exception 'Dados funcionais aprovados são consultivos; solicite correção administrativa' using errcode='42501';
   end if;
  end if;
 end if;
 return new;
end;$$;

create trigger b02_profile_submission_guard before insert or update on public.profile_submissions
 for each row execute function private.b02_profile_submission_guard();

create function private.b02_membership_profile_guard() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and auth.uid() is not null and not private.profile_admin(auth.uid()) then
  if new.user_id is distinct from old.user_id or new.organization_id is distinct from old.organization_id
   or new.access_profile_id is distinct from old.access_profile_id then
   raise exception 'Perfil e empresa são definidos pela Administração' using errcode='42501';
  end if;
  if private.b02_participant_approved(old.id) and
   (new.position_id is distinct from old.position_id or new.unit_id is distinct from old.unit_id
    or new.professional_data is distinct from old.professional_data) then
   raise exception 'Dados funcionais aprovados são consultivos; solicite correção administrativa' using errcode='42501';
  end if;
 end if;
 -- Serialize activations/profile changes by user without rewriting old records.
 -- Any active participant relationship excludes a second active organization,
 -- including a differently named profile in that second organization.
 if new.status='active' and (tg_op='INSERT' or old.status is distinct from new.status
  or old.user_id is distinct from new.user_id or old.organization_id is distinct from new.organization_id
  or old.access_profile_id is distinct from new.access_profile_id) then
  perform pg_advisory_xact_lock(hashtextextended('b02-participant-org:'||new.user_id::text,0));
  if exists(select 1 from public.organization_memberships m where m.user_id=new.user_id
   and m.id<>new.id and m.status='active' and m.organization_id<>new.organization_id
   and (private.b02_profile_role(new.access_profile_id)='participant'
    or private.b02_profile_role(m.access_profile_id)='participant')) then
   raise exception 'Participante possui vínculo ativo em outra organização; regularize antes de ativar este vínculo' using errcode='23514';
  end if;
 end if;
 return new;
end;$$;

create trigger b02_membership_profile_guard before insert or update on public.organization_memberships
 for each row execute function private.b02_membership_profile_guard();

-- Preserve the reviewed onboarding implementation and its optimistic locks.
alter function private.profile_command(text,jsonb) rename to b02_profile_command_base;

revoke all on function private.b02_profile_command_base(text,jsonb) from public,anon,authenticated;

create function private.profile_command(command text,payload jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; mid uuid; locked boolean; functional jsonb;
begin
 if not private.is_active_account(auth.uid()) then raise exception 'Conta inativa ou sessão ausente' using errcode='42501';end if;
 if command in ('search_organizations','request_organization') and not private.profile_admin(auth.uid())
  and exists(select 1 from public.organization_memberships m where m.user_id=auth.uid()
   and private.b02_participant_approved(m.id)) then
  raise exception 'Empresa aprovada é consultiva; solicite correção administrativa' using errcode='42501';
 end if;
 if command in ('save','submit','withdraw') then
  select s.membership_id into mid from public.profile_submissions s
   where s.id=nullif(payload->>'submission_id','')::uuid and s.user_id=auth.uid();
 else mid:=nullif(payload->>'membership_id','')::uuid;end if;
 locked:=mid is not null and private.b02_participant_approved(mid) and not private.profile_admin(auth.uid());
 if locked then
  functional:=private.b02_functional_fields(private.b02_functional_profile(mid));
  if command='save' and private.b02_functional_fields(payload->'professional') is distinct from functional then
   raise exception 'Dados funcionais aprovados são consultivos; solicite correção administrativa' using errcode='42501';
  elsif command='update_contacts' then
   -- Phone is personal; this endpoint's functional payload must stay unchanged.
   if private.b02_functional_fields(private.b02_functional_profile(mid)||
    jsonb_build_object('function',payload->>'function','department',payload->>'department',
     'manager',payload->>'manager','manager_contact',payload->>'manager_contact')) is distinct from functional then
    raise exception 'Dados funcionais aprovados são consultivos; solicite correção administrativa' using errcode='42501';
   end if;
  end if;
 end if;
 result:=private.b02_profile_command_base(command,payload);
 if command in ('open','new_revision') and result->>'state'='draft'
  and private.b02_participant_approved(nullif(result->>'membership_id','')::uuid)
  and not private.profile_admin(auth.uid()) then
  -- An administrative correction may have happened while this draft was open.
  -- Refresh only the managed fields; personal inputs and documents are retained.
  mid:=(result->>'membership_id')::uuid;
  update public.profile_submissions set professional=private.b02_functional_profile(mid)
   where id=(result->>'id')::uuid and user_id=auth.uid()
   and professional is distinct from private.b02_functional_profile(mid);
  result:=result||jsonb_build_object('professional',private.b02_functional_profile(mid),
   'updated_at',(select updated_at from public.profile_submissions where id=(result->>'id')::uuid));
 end if;
 if command='context' then
  result:=jsonb_set(result,'{memberships}',coalesce((select jsonb_agg(v||jsonb_build_object(
   'participant_functional_readonly',private.b02_participant_approved((v->>'id')::uuid) and not private.profile_admin(auth.uid())))
   from jsonb_array_elements(result->'memberships') v),'[]'::jsonb));
 elsif result ? 'membership_id' then
  mid:=nullif(result->>'membership_id','')::uuid;
  result:=result||jsonb_build_object('participant_functional_readonly',
   mid is not null and private.b02_participant_approved(mid) and not private.profile_admin(auth.uid()));
 end if;
 return result;
end;$$;

revoke all on function private.profile_command(text,jsonb),private.b02_participant_approved(uuid),
 private.b02_functional_profile(uuid),private.b02_functional_fields(jsonb),
 private.b02_profile_submission_guard(),private.b02_membership_profile_guard() from public,anon,authenticated;

grant execute on function private.profile_command(text,jsonb) to authenticated;
