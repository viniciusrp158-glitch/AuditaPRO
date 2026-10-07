begin;
create table public.profile_submissions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict,
 membership_id uuid references public.organization_memberships(id) on delete restrict,
 reviewer_id uuid references auth.users(id) on delete restrict,
 state text not null default 'draft' check(state in ('draft','submitted','approved','rejected','withdrawn')),
 version integer not null, personal jsonb not null default '{}', professional jsonb not null default '{}',
 access_profile_id uuid references public.access_profiles(id), required_types text[] not null default '{}',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 submitted_at timestamptz, reviewed_at timestamptz, review_note text,
 unique nulls not distinct(user_id,membership_id,version)
);
create unique index profile_one_open on public.profile_submissions(user_id,coalesce(membership_id,'00000000-0000-0000-0000-000000000000'::uuid)) where state in ('draft','submitted');
create index profile_review_queue on public.profile_submissions(reviewer_id,submitted_at desc) where state='submitted';
alter table public.organization_memberships add column professional_data jsonb not null default '{}';
alter table public.user_documents drop constraint user_documents_document_type_check;
alter table public.user_documents add constraint user_documents_document_type_check check(document_type in ('identity','auditor_certificate','leader_certificate'));
alter table public.user_documents add column submission_id uuid references public.profile_submissions(id) on delete restrict,
 add column is_current boolean not null default true, add column filename text,
 add column size_bytes integer check(size_bytes between 1 and 10000000), add column issued_on date,
 add column expires_on date, add column no_expiry boolean not null default true,
 add column issuer text, add column document_number text,
 add constraint document_dates_valid check(expires_on is null or issued_on is null or expires_on>=issued_on),
 add constraint document_expiry_choice check((no_expiry and expires_on is null) or (not no_expiry and expires_on is not null));
alter table public.user_documents drop constraint user_documents_storage_path_key;
drop index public.user_documents_one_pending_per_membership_idx;
create unique index profile_document_current on public.user_documents(submission_id,document_type) where is_current and submission_id is not null;
create index profile_document_membership on public.user_documents(membership_id,uploaded_at desc);
drop trigger if exists user_documents_competence on public.user_documents;

create function private.profile_required(profile uuid) returns text[] language sql stable security definer set search_path='' as $$
 select case name when 'Auditor Líder' then array['identity','leader_certificate'] when 'Auditor' then array['identity','auditor_certificate'] else array['identity'] end from public.access_profiles where id=profile and status='active';
$$;
create function private.profile_admin(actor uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.is_active_account(actor) and exists(select 1 from auth.users where id=actor and raw_app_meta_data->>'platform_role'='admin');
$$;
create function private.profile_ready(member uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profile_submissions s join public.organization_memberships m on m.id=s.membership_id join public.user_profiles p on p.user_id=m.user_id
 where m.id=member and s.state='approved' and s.access_profile_id=m.access_profile_id
 and s.personal->>'cpf'=p.cpf and s.personal->>'full_name'=p.full_name
 and (s.professional->>'position_id')::uuid=m.position_id and nullif(s.professional->>'unit_id','')::uuid is not distinct from m.unit_id
 and not exists(select 1 from unnest(private.profile_required(m.access_profile_id)) t where not exists(select 1 from public.user_documents d where d.submission_id=s.id and d.document_type=t and d.is_current and d.status='approved' and (d.expires_on is null or d.expires_on>=current_date))))
 and not exists(select 1 from public.profile_submissions s where s.membership_id=member and s.state='submitted');
$$;
create or replace function private.guard_membership_changes() returns trigger language plpgsql security definer set search_path='' as $$
declare recheck boolean;
begin
 recheck:=tg_op='INSERT';
 if tg_op='UPDATE' then
  if new.competence_status is distinct from old.competence_status and new.competence_status in ('approved','not_required') and not private.profile_ready(old.id) then raise exception 'A competência exige aprovação integral do cadastro'; end if;
  recheck:=new.position_id is distinct from old.position_id or new.access_profile_id is distinct from old.access_profile_id or new.unit_id is distinct from old.unit_id;
  if old.status='active' and (new.status<>'active' or recheck) and exists(select 1 from public.audits where leader_membership_id=old.id and status in ('planned','in_progress','awaiting_signoff')) then raise exception 'Substitua o Auditor Líder das auditorias ativas antes de alterar este vínculo'; end if;
 end if;
 if recheck then
  if new.position_id is not null and not exists(select 1 from public.positions where id=new.position_id and status='active') then raise exception 'Cargo inválido ou inativo'; end if;
  if new.access_profile_id is not null and not exists(select 1 from public.access_profiles where id=new.access_profile_id and status='active') then raise exception 'Perfil inválido ou inativo'; end if;
  new.competence_status:='pending';
 end if;
 return new;
end; $$;
-- Extend every existing operational gate, retaining its scope and participation rules.
do $$ declare f record; definition text; begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname in ('is_active_org_member','has_org_permission','is_audit_participant','has_audit_permission','is_audit_leader') loop
  definition:=pg_get_functiondef(f.oid);
  definition:=replace(definition,'m.competence_status in (''approved'',''not_required'')','m.competence_status in (''approved'',''not_required'') and private.profile_ready(m.id)');
  execute definition;
 end loop;
end $$;

create function private.profile_document_allowed(submission uuid,member uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.is_active_account(auth.uid()) and (private.is_active_membership_owner(member) or exists(select 1 from public.profile_submissions s where s.id=submission and s.reviewer_id=auth.uid() and private.profile_admin(auth.uid())));
$$;
alter table public.profile_submissions enable row level security;
create policy profile_submissions_read on public.profile_submissions for select to authenticated using(user_id=auth.uid() or public.is_platform_admin());
grant select on public.profile_submissions to authenticated;
grant all on public.profile_submissions to service_role;
revoke insert,update,delete on public.user_documents from authenticated;
drop policy if exists user_documents_admin_update on public.user_documents;
drop policy if exists user_documents_admin_delete on public.user_documents;
drop policy if exists user_documents_select on public.user_documents;
create policy user_documents_select on public.user_documents for select to authenticated using(private.profile_document_allowed(submission_id,membership_id));
drop policy if exists identity_objects_select on storage.objects;
drop policy if exists identity_objects_delete_admin on storage.objects;
create policy identity_objects_select on storage.objects for select to authenticated using(bucket_id='identity-documents' and exists(select 1 from public.user_documents d where d.storage_path=name and private.profile_document_allowed(d.submission_id,d.membership_id)));
update storage.buckets set file_size_limit=10000000, allowed_mime_types=array['application/pdf','image/jpeg','image/png'] where id='identity-documents';

create function private.profile_command(command text, payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); s public.profile_submissions%rowtype; prior public.profile_submissions%rowtype; m public.organization_memberships%rowtype;
 p public.user_profiles%rowtype; target uuid; member uuid; reviewer uuid; result jsonb; org public.organizations%rowtype; personal jsonb; professional jsonb; missing boolean;
begin
 if not private.is_active_account(actor) then raise exception 'Conta inativa ou sessão ausente' using errcode='42501'; end if;
 if command='context' then
  select to_jsonb(p0) into personal from public.user_profiles p0 where user_id=actor;
  return jsonb_build_object('profile',personal,'admin',private.profile_admin(actor),'memberships',coalesce((select jsonb_agg(to_jsonb(q)) from (select m0.*,o.legal_name organization,ap.name profile,private.profile_ready(m0.id) ready from public.organization_memberships m0 join public.organizations o on o.id=m0.organization_id left join public.access_profiles ap on ap.id=m0.access_profile_id where m0.user_id=actor and m0.status='active' and o.status='active') q),'[]'::jsonb),'positions',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.positions where status='active'),'[]'::jsonb),'requests',coalesce((select jsonb_agg(to_jsonb(q)) from (select organization_name,status,review_note from public.organization_access_requests where user_id=actor order by created_at desc limit 10) q),'[]'::jsonb));
 end if;
 if command='search_organizations' then
  if length(trim(coalesce(payload->>'search','')))<3 then return '[]'; end if;
  return coalesce((select jsonb_agg(to_jsonb(q)) from (select id,legal_name,cnpj from public.organizations where status='active' and (legal_name ilike '%'||left(payload->>'search',100)||'%' or cnpj like '%'||left(payload->>'search',100)||'%') order by legal_name limit 10) q),'[]');
 end if;
 if command='request_organization' then
  select * into org from public.organizations where id=(payload->>'organization_id')::uuid and status='active';
  if not found then raise exception 'Organização indisponível'; end if;
  if exists(select 1 from public.organization_memberships where user_id=actor and organization_id=org.id and status='active') then raise exception 'Você já possui vínculo com esta organização'; end if;
  insert into public.organization_access_requests(user_id,organization_name,cnpj,note) values(actor,org.legal_name,org.cnpj,'Solicitação por Meu Perfil') on conflict do nothing;
  return jsonb_build_object('message','Solicitação enviada. Aguarde o Administrador atribuir seu vínculo e perfil.');
 end if;
 if command='queue' then
  if not private.profile_admin(actor) then raise exception 'Acesso restrito ao Administrador'; end if;
  return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(q)) from (select s0.id,s0.user_id,s0.reviewer_id,s0.state,s0.version,s0.submitted_at,p0.full_name,o.legal_name organization,ap.name profile,r.full_name reviewer from public.profile_submissions s0 join public.user_profiles p0 on p0.user_id=s0.user_id left join public.organization_memberships m0 on m0.id=s0.membership_id left join public.organizations o on o.id=m0.organization_id left join public.access_profiles ap on ap.id=s0.access_profile_id left join public.user_profiles r on r.user_id=s0.reviewer_id where s0.state='submitted' and (coalesce((payload->>'mine')::boolean,false)=false or s0.reviewer_id=actor) order by s0.submitted_at,s0.id limit 20 offset greatest(0,least(coalesce((payload->>'page')::int,0),10000))*20) q),'[]'::jsonb),'admins',coalesce((select jsonb_agg(jsonb_build_object('id',user_id,'name',full_name)) from public.user_profiles where private.profile_admin(user_id)),'[]'::jsonb));
 end if;
 if command in ('open','new_revision') then
  member:=nullif(payload->>'membership_id','')::uuid;
  select * into p from public.user_profiles where user_id=actor for update;
  if member is not null then
   select * into m from public.organization_memberships where id=member and user_id=actor and status='active';
   if not found then raise exception 'Vínculo não autorizado'; end if;
  end if;
  select * into s from public.profile_submissions where user_id=actor and membership_id is not distinct from member order by version desc limit 1;
  if s.id is null or (command='new_revision' and s.state in ('approved','rejected','withdrawn')) then
   prior:=s;
   reviewer:=m.created_by;
   if reviewer is null then select created_by into reviewer from public.user_invites where user_id=actor and organization_id is not distinct from m.organization_id order by created_at desc limit 1; end if;
   if reviewer=actor or not private.profile_admin(reviewer) then reviewer:=null; end if;
   if prior.id is null and member is not null then select * into prior from public.profile_submissions where user_id=actor and membership_id is null order by version desc limit 1; end if;
   insert into public.profile_submissions(user_id,membership_id,version,reviewer_id,personal,professional,access_profile_id,required_types)
    values(actor,member,coalesce(s.version,0)+1,reviewer,coalesce(prior.personal,jsonb_build_object('full_name',p.full_name,'cpf',p.cpf,'phone',p.phone)),
      coalesce(prior.professional,'{}')||jsonb_build_object('position_id',m.position_id,'unit_id',m.unit_id),m.access_profile_id,coalesce(private.profile_required(m.access_profile_id),'{}')) returning * into s;
   if prior.membership_id=member then
    insert into public.user_documents(membership_id,document_type,storage_path,submission_id,filename,size_bytes,issued_on,expires_on,no_expiry,issuer,document_number)
    select member,document_type,storage_path,s.id,filename,size_bytes,issued_on,expires_on,no_expiry,issuer,document_number from public.user_documents where submission_id=prior.id and is_current;
   end if;
  end if;
  target:=s.id;
 else target:=(payload->>'submission_id')::uuid;
 end if;
 select * into s from public.profile_submissions where id=target for update;
 if not found then raise exception 'Cadastro não encontrado'; end if;
 if s.user_id<>actor and not private.profile_admin(actor) then raise exception 'Acesso não autorizado' using errcode='42501'; end if;
 if command='assign' then
  if not private.profile_admin(actor) or s.state<>'submitted' then raise exception 'Reatribuição não permitida'; end if;
  reviewer:=(payload->>'reviewer_id')::uuid;
  if reviewer=s.user_id or not private.profile_admin(reviewer) then raise exception 'Selecione outro Administrador ativo'; end if;
  if length(trim(coalesce(payload->>'reason','')))<3 then raise exception 'Informe o motivo da reatribuição'; end if;
  update public.profile_submissions set reviewer_id=reviewer,updated_at=now() where id=s.id;
 elsif command='save' then
  if s.user_id<>actor or s.state<>'draft' then raise exception 'Retire o cadastro da análise antes de editar'; end if;
  personal:=jsonb_build_object('full_name',left(trim(payload->'personal'->>'full_name'),200),'cpf',nullif(regexp_replace(coalesce(payload->'personal'->>'cpf',''),'[^0-9]','','g'),''),'phone',left(trim(payload->'personal'->>'phone'),32));
  if length(coalesce(personal->>'full_name',''))<2 then raise exception 'Informe o nome completo'; end if;
  if personal->>'cpf' is not null and not private.valid_cpf(personal->>'cpf') then raise exception 'CPF inválido'; end if;
  if exists(select 1 from public.user_profiles where cpf=personal->>'cpf' and user_id<>actor) then raise exception 'CPF já cadastrado. Solicite revisão administrativa'; end if;
  professional:=jsonb_build_object('position_id',nullif(payload->'professional'->>'position_id','')::uuid,'unit_id',nullif(payload->'professional'->>'unit_id','')::uuid,'function',left(payload->'professional'->>'function',160),'department',left(payload->'professional'->>'department',160),'manager',left(payload->'professional'->>'manager',200),'manager_contact',left(payload->'professional'->>'manager_contact',200));
  if s.membership_id is not null then
   select * into m from public.organization_memberships where id=s.membership_id;
   if professional->>'position_id' is not null and not exists(select 1 from public.positions where id=(professional->>'position_id')::uuid and status='active') then raise exception 'Cargo inválido'; end if;
   if professional->>'unit_id' is not null and not exists(select 1 from public.organization_units where id=(professional->>'unit_id')::uuid and organization_id=m.organization_id and status='active') then raise exception 'Unidade inválida para esta empresa'; end if;
  end if;
  update public.profile_submissions set personal=profile_command.personal,professional=profile_command.professional,updated_at=now() where id=s.id;
  if s.membership_id is null and private.profile_admin(actor) then update public.user_profiles set full_name=personal->>'full_name',cpf=personal->>'cpf',phone=personal->>'phone' where user_id=actor; end if;
 elsif command='submit' then
  if s.user_id<>actor then raise exception 'Somente o titular pode enviar'; end if;
  if s.state='submitted' then return jsonb_build_object('id',s.id,'state',s.state); end if;
  if s.state<>'draft' or s.membership_id is null then raise exception 'Aguarde a definição do seu vínculo e perfil pelo Administrador'; end if;
  select * into m from public.organization_memberships where id=s.membership_id and status='active';
  if not found or m.access_profile_id is null or m.access_profile_id is distinct from s.access_profile_id then raise exception 'Perfil alterado. Solicite revisão do cadastro'; end if;
  if not exists(select 1 from public.organizations where id=m.organization_id and status='active') then raise exception 'Organização inativa'; end if;
  if s.professional->>'position_id' is null or not private.valid_cpf(s.personal->>'cpf') or length(coalesce(s.personal->>'full_name',''))<2 then raise exception 'Complete nome, CPF e cargo'; end if;
  if exists(select 1 from unnest(private.profile_required(m.access_profile_id)) t where not exists(select 1 from public.user_documents d where d.submission_id=s.id and d.is_current and d.document_type=t and (d.expires_on is null or d.expires_on>=current_date))) then raise exception 'Envie todos os documentos obrigatórios válidos'; end if;
  update public.profile_submissions set state='submitted',submitted_at=now(),updated_at=now(),required_types=private.profile_required(m.access_profile_id),reviewer_id=case when reviewer_id<>actor and private.profile_admin(reviewer_id) then reviewer_id else null end where id=s.id;
  update public.organization_memberships set competence_status='pending' where id=m.id;
 elsif command='withdraw' then
  if s.user_id<>actor or s.state<>'submitted' then raise exception 'Esta versão não pode ser retirada'; end if;
  update public.profile_submissions set state='withdrawn',updated_at=now() where id=s.id;
 elsif command in ('review_document','decide') then
  if not private.profile_admin(actor) or s.reviewer_id is distinct from actor or actor=s.user_id or s.state<>'submitted' then raise exception 'Análise restrita ao responsável designado e à versão pendente' using errcode='42501'; end if;
  if payload->>'decision' not in ('approved','rejected') or payload->>'decision' is null then raise exception 'Decisão inválida'; end if;
  if payload->>'decision'='rejected' and length(trim(coalesce(payload->>'reason','')))<3 then raise exception 'Informe o motivo da reprovação'; end if;
  if command='review_document' then
   update public.user_documents set status=payload->>'decision',reviewed_by=actor,reviewed_at=now(),review_note=nullif(trim(payload->>'reason'),'') where id=(payload->>'document_id')::uuid and submission_id=s.id and is_current;
   if not found then raise exception 'Documento não encontrado nesta versão'; end if;
  else
   if payload->>'decision'='approved' then
    select * into m from public.organization_memberships where id=s.membership_id and status='active' for update;
    if not found or m.access_profile_id is distinct from s.access_profile_id then raise exception 'O vínculo ou perfil foi alterado; solicite correção'; end if;
    if exists(select 1 from unnest(private.profile_required(m.access_profile_id)) t where not exists(select 1 from public.user_documents d where d.submission_id=s.id and d.document_type=t and d.is_current and d.status='approved' and (d.expires_on is null or d.expires_on>=current_date))) then raise exception 'Aprove todos os documentos obrigatórios válidos antes de concluir'; end if;
    update public.user_profiles set full_name=s.personal->>'full_name',cpf=s.personal->>'cpf',phone=s.personal->>'phone' where user_id=s.user_id;
    update public.organization_memberships set position_id=(s.professional->>'position_id')::uuid,unit_id=nullif(s.professional->>'unit_id','')::uuid,professional_data=s.professional where id=s.membership_id;
   end if;
   update public.profile_submissions set state=payload->>'decision',reviewed_at=now(),review_note=nullif(trim(payload->>'reason'),''),updated_at=now() where id=s.id;
   update public.organization_memberships set competence_status=payload->>'decision' where id=s.membership_id;
  end if;
 elsif command not in ('open','new_revision','detail','save','submit','withdraw','assign') then raise exception 'Ação desconhecida';
 end if;
 if command not in ('open','detail') then
  insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,metadata) values(actor,'profile_'||command,'profile_submission',s.id,jsonb_build_object('version',s.version,'decision',payload->>'decision','reviewer_id',case when command='assign' then reviewer else s.reviewer_id end,'reason',case when command in ('assign','decide','review_document') then left(payload->>'reason',500) else null end));
 end if;
 select to_jsonb(s0)||jsonb_build_object('email',p0.email,'reviewer_name',r.full_name,'organization',o.legal_name,'profile_name',ap.name,'units',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.name)) from public.organization_units u where u.organization_id=m0.organization_id and u.status='active'),'[]'::jsonb),'documents',case when s0.user_id=actor or s0.reviewer_id=actor then coalesce((select jsonb_agg(to_jsonb(d) order by d.uploaded_at desc) from public.user_documents d where d.submission_id=s0.id),'[]'::jsonb) else '[]'::jsonb end,'history',coalesce((select jsonb_agg(jsonb_build_object('version',h.version,'state',h.state,'submitted_at',h.submitted_at,'reviewed_at',h.reviewed_at,'review_note',h.review_note) order by h.version desc) from public.profile_submissions h where h.user_id=s0.user_id and h.membership_id is not distinct from s0.membership_id),'[]'::jsonb)) into result
 from public.profile_submissions s0 join public.user_profiles p0 on p0.user_id=s0.user_id left join public.user_profiles r on r.user_id=s0.reviewer_id left join public.organization_memberships m0 on m0.id=s0.membership_id left join public.organizations o on o.id=m0.organization_id left join public.access_profiles ap on ap.id=s0.access_profile_id where s0.id=s.id;
 return result;
end; $$;
revoke all on function private.profile_command(text,jsonb) from public;
grant execute on function private.profile_command(text,jsonb) to authenticated;
create function public.profile_command(command text,payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$ select private.profile_command(command,payload); $$;
revoke all on function public.profile_command(text,jsonb) from public;
grant execute on function public.profile_command(text,jsonb) to authenticated;

-- Only the file-validating Edge Function may register a newly uploaded object.
create function public.profile_register_document(actor uuid,submission uuid,info jsonb) returns uuid language plpgsql security invoker set search_path='' as $$
declare s public.profile_submissions%rowtype; doc uuid;
begin
 select * into s from public.profile_submissions where id=submission for update;
 if s.user_id is distinct from actor or s.state<>'draft' or s.membership_id is null or not private.is_active_membership_owner_service(actor,s.membership_id) then raise exception 'Envio não autorizado ou cadastro já submetido'; end if;
 if not (info->>'document_type'=any(s.required_types)) then raise exception 'Tipo de documento não exigido'; end if;
 update public.user_documents set is_current=false where submission_id=s.id and document_type=info->>'document_type' and is_current;
 insert into public.user_documents(membership_id,submission_id,document_type,storage_path,filename,size_bytes,issued_on,expires_on,no_expiry,issuer,document_number)
 values(s.membership_id,s.id,info->>'document_type',info->>'storage_path',left(info->>'filename',200),(info->>'size_bytes')::int,nullif(info->>'issued_on','')::date,nullif(info->>'expires_on','')::date,(info->>'no_expiry')::boolean,left(info->>'issuer',200),left(info->>'document_number',100)) returning id into doc;
 insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,metadata) values(actor,'profile_document_uploaded','profile_submission',s.id,jsonb_build_object('document_type',info->>'document_type','version',s.version));
 return doc;
end; $$;
create function private.is_active_membership_owner_service(actor uuid,member uuid) returns boolean language sql security invoker set search_path='' as $$
 select private.is_active_account(actor) and exists(select 1 from public.organization_memberships m join public.organizations o on o.id=m.organization_id where m.id=member and m.user_id=actor and m.status='active' and o.status='active');
$$;
revoke all on function public.profile_register_document(uuid,uuid,jsonb),private.is_active_membership_owner_service(uuid,uuid) from public;
grant execute on function public.profile_register_document(uuid,uuid,jsonb),private.is_active_membership_owner_service(uuid,uuid) to service_role;
grant usage on schema private to service_role;
grant execute on function private.is_active_account(uuid) to service_role;
grant select,insert,update on public.user_documents,public.audit_events to service_role;
grant select on public.organization_memberships,public.organizations,public.user_profiles to service_role;
revoke all on function private.profile_required(uuid),private.profile_admin(uuid),private.profile_ready(uuid),private.profile_document_allowed(uuid,uuid) from public;
grant execute on function private.profile_required(uuid),private.profile_admin(uuid),private.profile_ready(uuid),private.profile_document_allowed(uuid,uuid) to authenticated,service_role;
-- Personal sensitive edits are submitted for review rather than written by the old form.
revoke update(full_name,cpf) on public.user_profiles from authenticated;
commit;
