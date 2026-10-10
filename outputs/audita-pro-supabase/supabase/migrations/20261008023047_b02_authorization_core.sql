-- Recuperada de supabase_migrations.schema_migrations em 2026-10-10 (B00, Claude).
-- JA APLICADA no projeto zlckcpeqcxmtrgbdquee. NAO reaplicar. md5(statements)=732209bc722e6ae747afd4f527ce4c59

-- B02 / AUTH-1: additive proposal. C0 must review before remote application.
-- Names are resolved ONCE to existing IDs; runtime authorization uses those IDs.
create table private.b02_profile_roles (
 profile_id uuid primary key references public.access_profiles(id),
 role_key text not null check (role_key in ('leader','auditor','participant'))
);

insert into private.b02_profile_roles(profile_id,role_key)
 select id,case name when 'Auditor Líder' then 'leader' when 'Auditor' then 'auditor' else 'participant' end
 from public.access_profiles where name in ('Auditor Líder','Auditor','Participante / Auditado');

revoke all on private.b02_profile_roles from public,anon,authenticated;

create function private.b02_profile_role(profile_id uuid) returns text
 language sql stable security definer set search_path='' as $$
 select role_key from private.b02_profile_roles r where r.profile_id=$1;
$$;

create function private.b02_member_ready(mid uuid) returns boolean
 language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.organization_memberships m
 join public.organizations o on o.id=m.organization_id and o.status='active'
 join public.access_profiles p on p.id=m.access_profile_id and p.status='active'
 join public.user_profiles u on u.user_id=m.user_id and u.status='active'
 where m.id=mid and m.status='active' and m.competence_status in ('approved','not_required')
 and u.cpf is not null and private.profile_ready(m.id));
$$;

create function private.b02_member_permission(mid uuid, permission text) returns boolean
 language sql stable security definer set search_path='' as $$
 select coalesce((select coalesce(mp.allowed,pp.allowed,false)
 from public.organization_memberships m join public.access_permissions p on p.permission_key=permission
 left join public.access_profile_permissions pp on pp.profile_id=m.access_profile_id and pp.permission_id=p.id
 left join public.membership_permissions mp on mp.membership_id=m.id and mp.permission_id=p.id
 where m.id=mid),false);
$$;

-- Existing participation is the audit-specific grant; daily attendance remains independent.
alter table public.audit_participants
 add column access_reason text,
 add column access_requires_admin boolean not null default false,
 add column access_changed_by uuid references auth.users(id),
 add column access_changed_at timestamptz,
 add column access_revoked_at timestamptz;

-- A legacy inactive grant must be revalidated by Administration, never silently resurrected.
update public.audit_participants set access_requires_admin=true where not active;

-- Preserve legacy responsible users only where no explicit grant/revocation exists.
insert into public.audit_participants(audit_id,membership_id,participant_type,added_by,access_reason)
 select a.id,a.leader_membership_id,'leader',a.created_by,'Migração do responsável legado'
 from public.audits a on conflict(audit_id,membership_id) do nothing;

create function private.b02_scope(aid uuid) returns boolean
 language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.audits a where a.id=aid and
 (private.profile_admin(auth.uid()) or exists(
 select 1 from public.audit_participants ap join public.organization_memberships m on m.id=ap.membership_id
 where ap.audit_id=a.id and ap.active and m.organization_id=a.organization_id
 and m.user_id=auth.uid() and private.b02_member_ready(m.id)
 and private.b02_member_permission(m.id,'audit.view'))));
$$;

create or replace function private.workspace_conductor(aid uuid) returns boolean
 language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.audits a where a.id=aid and
 (private.profile_admin(auth.uid()) or exists(
 select 1 from public.organization_memberships m join public.audit_participants ap on ap.membership_id=m.id and ap.audit_id=a.id
 where m.id=a.leader_membership_id and m.organization_id=a.organization_id and m.user_id=auth.uid()
 and ap.active and private.b02_member_ready(m.id)
 and private.b02_profile_role(m.access_profile_id)='leader'
 and private.b02_member_permission(m.id,'audit.update'))));
$$;

create or replace function private.is_audit_leader(target_audit uuid) returns boolean
 language sql stable security definer set search_path='' as $$select private.workspace_conductor(target_audit);$$;

create or replace function private.is_audit_participant(target_audit uuid) returns boolean
 language sql stable security definer set search_path='' as $$select private.b02_scope(target_audit);$$;

create or replace function private.checklist_internal(aid uuid) returns boolean
 language sql stable security definer set search_path='' as $$
 select private.workspace_conductor(aid) or (private.b02_scope(aid) and exists(
 select 1 from public.audit_participants ap join public.organization_memberships m on m.id=ap.membership_id
 where ap.audit_id=aid and ap.active and m.user_id=auth.uid() and private.b02_member_ready(m.id)
 and private.b02_profile_role(m.access_profile_id) in ('leader','auditor') and ap.participant_type in ('leader','auditor')));
$$;

create or replace function private.workspace_eligible(member uuid) returns boolean
 language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.organization_memberships m join public.organizations o on o.id=m.organization_id
 where m.id=member and m.status='active' and o.status='active' and
 (private.profile_admin(m.user_id) or (private.b02_member_ready(m.id) and private.b02_profile_role(m.access_profile_id)='leader')));
$$;

create or replace function private.workspace_member(org uuid) returns boolean
 language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.organization_memberships m where m.organization_id=org and m.user_id=auth.uid() and private.b02_member_ready(m.id));
$$;

create or replace function private.has_org_permission(target_org uuid,required_permission text) returns boolean
 language sql stable security definer set search_path='' as $$
 select private.profile_admin(auth.uid()) or exists(select 1 from public.organization_memberships m
 where m.organization_id=target_org and m.user_id=auth.uid() and private.b02_member_ready(m.id)
 and private.b02_profile_role(m.access_profile_id)='leader' and private.b02_member_permission(m.id,required_permission));
$$;

create or replace function private.has_audit_permission(target_audit uuid,required_permission text) returns boolean
 language sql stable security definer set search_path='' as $$
 select private.b02_scope(target_audit) and (private.profile_admin(auth.uid()) or exists(
 select 1 from public.audit_participants ap join public.organization_memberships m on m.id=ap.membership_id
 where ap.audit_id=target_audit and ap.active and m.user_id=auth.uid() and private.b02_member_ready(m.id)
 and private.b02_member_permission(m.id,required_permission)
 and (required_permission in ('audit.view','report.view','indicators.view','report.acknowledge') or private.workspace_conductor(target_audit))));
$$;

create function private.b02_original_access(aid uuid) returns boolean
 language sql stable security definer set search_path='' as $$
 select private.workspace_conductor(aid) or (private.checklist_internal(aid) and exists(
 select 1 from public.audit_participants ap join public.organization_memberships m on m.id=ap.membership_id
 where ap.audit_id=aid and ap.active and m.user_id=auth.uid() and private.b02_member_ready(m.id)
 and private.b02_member_permission(m.id,'evidence.approve')));
$$;

-- Corporate library authorization primitive for B04/B05; no duplicate library is created.
create function private.b02_corporate_access(write_access boolean default false) returns boolean
 language sql stable security definer set search_path='' as $$
 select private.profile_admin(auth.uid()) or (not write_access and exists(select 1 from public.organization_memberships m
 where m.user_id=auth.uid() and private.b02_member_ready(m.id) and private.b02_profile_role(m.access_profile_id) in ('leader','auditor')));
$$;

create function private.b02_grant_guard() returns trigger
 language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and old.access_requires_admin and new.active and not private.profile_admin(auth.uid()) then
  raise exception 'Revogação administrativa exige nova concessão da Administração' using errcode='42501';
 end if;
 if private.profile_admin(auth.uid()) then new.access_requires_admin:=not new.active;
 elsif tg_op='UPDATE' then new.access_requires_admin:=old.access_requires_admin;
 else new.access_requires_admin:=false;end if;
 if tg_op='UPDATE' and (new.audit_id<>old.audit_id or new.membership_id<>old.membership_id) then
  raise exception 'Concessão imutável: revogue e crie outra' using errcode='42501';
 end if;
 if not exists(select 1 from public.audits a join public.organization_memberships m on m.organization_id=a.organization_id where a.id=new.audit_id and m.id=new.membership_id) then
  raise exception 'Vínculo fora da auditoria' using errcode='42501';
 end if;
 if tg_op='INSERT' or new.active is distinct from old.active or new.participant_type is distinct from old.participant_type or new.is_signatory is distinct from old.is_signatory then
  new.access_changed_by:=auth.uid(); new.access_changed_at:=clock_timestamp();
  new.access_revoked_at:=case when not new.active then clock_timestamp() end;
 else
  new.access_changed_by:=old.access_changed_by;new.access_changed_at:=old.access_changed_at;new.access_revoked_at:=old.access_revoked_at;
 end if;
 if tg_op='INSERT' then
  new.added_by:=coalesce(auth.uid(),new.added_by);new.added_at:=clock_timestamp();
 else
  new.added_by:=old.added_by;new.added_at:=old.added_at;
 end if;
 return new;
end;$$;

create trigger b02_grant_guard before insert or update on public.audit_participants for each row execute function private.b02_grant_guard();

-- Explicit grants and transfer/reopen commands use CMD-1, serialized by audit row lock.
create table private.b02_operations (
 operation_id uuid primary key, actor uuid not null references auth.users(id),
 audit_id uuid not null references public.audits(id), command text not null,
 request jsonb not null, response jsonb not null, created_at timestamptz not null default now()
);

revoke all on private.b02_operations from public,anon,authenticated;

create function public.audit_access(command text,payload jsonb) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare a public.audits%rowtype; m public.organization_memberships%rowtype; op private.b02_operations%rowtype;
 aid uuid; oid uuid; mid uuid; p jsonb:=payload->'payload'; result jsonb; why text; previous uuid;
begin
 if not private.is_active_account(auth.uid()) then return jsonb_build_object('error',jsonb_build_object('code','AUTH_REQUIRED','message','Sessão ativa necessária','field_errors','{}'::jsonb,'retryable',false));end if;
 if not private.profile_admin(auth.uid()) then return jsonb_build_object('error',jsonb_build_object('code','NOT_ALLOWED_OR_NOT_FOUND','message','Operação indisponível','field_errors','{}'::jsonb,'retryable',false));end if;
 if payload->>'contract_version' is distinct from '1' or command not in ('grant','revoke','transfer','reopen') or jsonb_typeof(p) is distinct from 'object' then raise exception 'Contrato inválido';end if;
 aid:=(payload->>'audit_id')::uuid; oid:=(payload->>'operation_id')::uuid;
 if oid is null or aid is null then raise exception 'Identificadores obrigatórios';end if;
 select * into a from public.audits where id=aid for update;
 if a.id is null then return jsonb_build_object('error',jsonb_build_object('code','NOT_ALLOWED_OR_NOT_FOUND','message','Operação indisponível','field_errors','{}'::jsonb,'retryable',false));end if;
 select * into op from private.b02_operations where operation_id=oid;
 if found then
  if op.actor<>auth.uid() or op.audit_id<>aid or op.command<>command or op.request<>payload then raise exception 'operation_id já utilizado com outro conteúdo';end if;
  return op.response;
 end if;
 if a.lock_version is distinct from (payload->>'expected_lock_version')::int then return jsonb_build_object('error',jsonb_build_object('code','VERSION_CONFLICT','message','Auditoria alterada; atualize antes de continuar','field_errors','{}'::jsonb,'retryable',false));end if;
 why:=nullif(trim(p->>'reason'),''); if why is null then raise exception 'Informe o motivo';end if;
 if command in ('grant','revoke','transfer') then
  mid:=(p->>'membership_id')::uuid;
  select * into m from public.organization_memberships where id=mid and organization_id=a.organization_id;
  if m.id is null then raise exception 'Vínculo indisponível';end if;
 end if;
 if command='grant' then
  if not private.b02_member_ready(mid) or private.b02_profile_role(m.access_profile_id) is null then raise exception 'Vínculo não habilitado';end if;
  insert into public.audit_participants(audit_id,membership_id,participant_type,added_by,access_reason)
  values(aid,mid,case when mid=a.leader_membership_id then 'leader' when private.b02_profile_role(m.access_profile_id) in ('leader','auditor') then 'auditor' else 'client' end,auth.uid(),why)
  on conflict(audit_id,membership_id) do update set active=true,access_reason=excluded.access_reason,participant_type=excluded.participant_type;
 elsif command='revoke' then
  if mid=a.leader_membership_id then raise exception 'Transfira a responsabilidade antes de revogar o líder';end if;
  update public.audit_participants set active=false,access_reason=why where audit_id=aid and membership_id=mid;
  if not found then raise exception 'Concessão indisponível';end if;
 elsif command='transfer' then
  if not private.workspace_eligible(mid) or mid=a.leader_membership_id then raise exception 'Novo responsável inelegível';end if;
  previous:=a.leader_membership_id;
  update public.audit_participants set participant_type='auditor',active=coalesce((p->>'retain_previous_read')::boolean,false),access_reason=why where audit_id=aid and membership_id=previous;
  insert into public.audit_participants(audit_id,membership_id,participant_type,added_by,access_reason) values(aid,mid,'leader',auth.uid(),why)
  on conflict(audit_id,membership_id) do update set active=true,participant_type='leader',access_reason=excluded.access_reason;
  update public.audits set leader_membership_id=mid where id=aid;
 elsif command='reopen' then
  if a.status not in ('completed','awaiting_signoff') then raise exception 'Etapa não elegível para reabertura';end if;
  update public.audits set status='in_progress' where id=aid;
 end if;
 update public.audits set lock_version=lock_version+1 where id=aid returning lock_version,status into a.lock_version,a.status;
 insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,metadata)
 values(a.organization_id,auth.uid(),'b02_'||command,'audits',aid,jsonb_build_object('reason',why,'membership_id',mid,'previous_leader',previous,'operation_id',oid,'retain_previous_read',coalesce((p->>'retain_previous_read')::boolean,false)));
 result:=jsonb_build_object('contract_version',1,'operation_id',oid,'entity_id',aid,'lock_version',a.lock_version,'state',a.status,'warnings','[]'::jsonb);
 insert into private.b02_operations values(oid,auth.uid(),aid,command,payload,result,now());
 return result;
exception when invalid_text_representation or check_violation or raise_exception or not_null_violation or unique_violation then
 return jsonb_build_object('error',jsonb_build_object('code','VALIDATION_FAILED','message',sqlerrm,'field_errors','{}'::jsonb,'retryable',false));
end;$$;

revoke all on function public.audit_access(text,jsonb) from public,anon;

grant execute on function public.audit_access(text,jsonb) to authenticated;

-- Private helpers are needed by RLS, never exposed as RPC through public schema.
revoke all on function private.b02_grant_guard() from public,anon,authenticated;
