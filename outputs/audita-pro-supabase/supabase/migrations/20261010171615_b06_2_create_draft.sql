-- B06 Parte 2/4: criação de rascunho incompleto da auditoria (PA-04). Aditiva.
-- Mesmas regras de permissão/condutor do comando create existente; título, escopo e critério podem ficar para depois.
create table private.b06_operations (
 operation_id uuid primary key, actor uuid not null references auth.users(id), command text not null,
 response jsonb not null, created_at timestamptz not null default now());
alter table private.b06_operations enable row level security;
revoke all on private.b06_operations from public, anon, authenticated;

create function private.b06_create_draft(payload jsonb) returns jsonb
 language plpgsql security definer set search_path = '' as $$
#variable_conflict use_variable
declare actor uuid := auth.uid(); org public.organizations%rowtype; leader uuid; op uuid; prior jsonb; aid uuid; crit uuid[]; result jsonb; acode text;
begin
 op := (payload->>'operation_id')::uuid;
 if op is null then raise exception 'operation_id obrigatório'; end if;
 select o.response into prior from private.b06_operations o where o.operation_id = op and o.actor = actor;
 if prior is not null then return prior; end if;
 select * into org from public.organizations where id = (payload->>'organization_id')::uuid and status = 'active';
 if org.id is null then raise exception 'Selecione um cliente ativo'; end if;
 if not private.has_org_permission(org.id, 'audit.create') then raise exception 'Sem permissão para criar auditoria' using errcode = '42501'; end if;
 leader := nullif(payload->>'leader_membership_id','')::uuid;
 if leader is null and private.profile_admin(actor) then
  insert into public.organization_memberships (organization_id, user_id, access_profile_id, competence_status, created_by)
  values (org.id, actor, (select profile_id from private.b02_profile_roles where role_key = 'leader' limit 1), 'not_required', actor)
  on conflict (organization_id, user_id) do nothing;
  select id into leader from public.organization_memberships where organization_id = org.id and user_id = actor;
 end if;
 if leader is null then
  select id into leader from public.organization_memberships where organization_id = org.id and user_id = actor and private.workspace_eligible(id);
 end if;
 if not private.workspace_eligible(leader) or not exists (select 1 from public.organization_memberships m where m.id = leader
    and m.organization_id = org.id and (m.user_id = actor or private.profile_admin(actor))) then
  raise exception 'Condutor inelegível ou fora da empresa';
 end if;
 if nullif(payload->>'unit_id','') is not null and not exists (select 1 from public.organization_units
    where id = (payload->>'unit_id')::uuid and organization_id = org.id and status = 'active') then
  raise exception 'Unidade fora da empresa'; end if;
 crit := array(select v::uuid from jsonb_array_elements_text(coalesce(payload->'criterion_ids','[]'::jsonb)) with ordinality x(v, n) group by v order by min(n));
 if exists (select 1 from unnest(crit) c where not exists (select 1 from public.audit_types t where t.id = c and t.active)) then
  raise exception 'Critério inválido'; end if;
 insert into public.audits (organization_id, unit_id, code, title, objective, scope, standards, leader_membership_id, created_by,
  workspace_version, type_id, criterion_ids, purpose, party, modality, location)
 values (org.id, nullif(payload->>'unit_id','')::uuid, 'AUD-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)),
  coalesce(nullif(btrim(payload->>'title'),''), 'Auditoria — ' || org.legal_name), nullif(btrim(payload->>'objective'),''),
  nullif(btrim(payload->>'scope'),''),
  array(select t.code || case when nullif(t.edition,'') is null then '' else ':' || t.edition end from public.audit_types t where t.id = any(crit) order by t.code, t.edition),
  leader, actor, 1, crit[1], crit, coalesce(nullif(btrim(payload->>'purpose'),''), 'A definir'), coalesce(payload->>'party','first'),
  coalesce(payload->>'modality','presential'), nullif(btrim(payload->>'location'),''))
 returning id, code into aid, acode;
 insert into public.audit_participants (audit_id, membership_id, participant_type, added_by) values (aid, leader, 'leader', actor);
 insert into public.audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata)
 values (org.id, actor, 'b06_draft_created', 'audits', aid, jsonb_build_object('code', acode));
 result := jsonb_build_object('contract_version', 1, 'audit_id', aid, 'id', aid, 'code', acode);
 insert into private.b06_operations (operation_id, actor, command, response) values (op, actor, 'create_draft', result);
 return result;
end;$$;
revoke all on function private.b06_create_draft(jsonb) from public, anon, authenticated;
