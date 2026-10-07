create or replace function private.profile_command(command text, payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
<<profile_flow>>
declare actor uuid:=auth.uid(); s public.profile_submissions%rowtype; prior public.profile_submissions%rowtype; m public.organization_memberships%rowtype;
 p public.user_profiles%rowtype; target uuid; member uuid; reviewer uuid; result jsonb; org public.organizations%rowtype; personal jsonb; professional jsonb; missing boolean;
begin
 if not private.is_active_account(actor) then raise exception 'Conta inativa ou sessão ausente' using errcode='42501'; end if;
 if command='update_contacts' then
  select * into p from public.user_profiles where user_id=actor for update;
  update public.user_profiles set phone=left(payload->>'phone',32) where user_id=actor;
  member:=nullif(payload->>'membership_id','')::uuid;
  if member is not null then
   update public.organization_memberships set professional_data=professional_data||jsonb_build_object('function',left(payload->>'function',160),'department',left(payload->>'department',160),'manager',left(payload->>'manager',200),'manager_contact',left(payload->>'manager_contact',200)) where id=member and user_id=actor and status='active';
   if not found then raise exception 'Vínculo não autorizado'; end if;
  end if;
  insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,metadata) values(actor,'profile_contacts_updated','user_profile',actor,jsonb_build_object('membership_id',member));
  return jsonb_build_object('message','Dados de contato atualizados. A aprovação documental foi preservada.');
 end if;
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
  if s.id is not null and s.state='draft' and member is not null and s.access_profile_id is distinct from m.access_profile_id then
   update public.profile_submissions set state='withdrawn',updated_at=clock_timestamp(),review_note='Perfil alterado pelo Administrador' where id=s.id;
   s.state:='withdrawn';
   command:='new_revision';
  end if;
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
 if command in ('save','submit','withdraw','review_document','decide') and payload ? 'expected_updated_at' and (payload->>'expected_updated_at')::timestamptz is distinct from s.updated_at then
  raise exception 'Este cadastro foi alterado em outra sessão. Atualize a página antes de continuar.';
 end if;
 if command='assign' then
  if not private.profile_admin(actor) or s.state<>'submitted' then raise exception 'Reatribuição não permitida'; end if;
  reviewer:=(payload->>'reviewer_id')::uuid;
  if reviewer=s.user_id or not private.profile_admin(reviewer) then raise exception 'Selecione outro Administrador ativo'; end if;
  if length(trim(coalesce(payload->>'reason','')))<3 then raise exception 'Informe o motivo da reatribuição'; end if;
  update public.profile_submissions set reviewer_id=reviewer,updated_at=clock_timestamp() where id=s.id;
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
  update public.profile_submissions set personal=profile_flow.personal,professional=profile_flow.professional,updated_at=clock_timestamp() where id=s.id;
  if s.membership_id is null and private.profile_admin(actor) then update public.user_profiles set full_name=personal->>'full_name',cpf=personal->>'cpf',phone=personal->>'phone' where user_id=actor; end if;
 elsif command='submit' then
  if s.user_id<>actor then raise exception 'Somente o titular pode enviar'; end if;
  if s.state='submitted' then return jsonb_build_object('id',s.id,'state',s.state); end if;
  if coalesce((payload->>'confirmed')::boolean,false)=false then raise exception 'Confirme a revisão dos dados antes de enviar'; end if;
  if s.state<>'draft' or s.membership_id is null then raise exception 'Aguarde a definição do seu vínculo e perfil pelo Administrador'; end if;
  select * into m from public.organization_memberships where id=s.membership_id and status='active';
  if not found or m.access_profile_id is null or m.access_profile_id is distinct from s.access_profile_id then raise exception 'Perfil alterado. Solicite revisão do cadastro'; end if;
  if not exists(select 1 from public.organizations where id=m.organization_id and status='active') then raise exception 'Organização inativa'; end if;
  if s.professional->>'position_id' is null or not private.valid_cpf(s.personal->>'cpf') or length(coalesce(s.personal->>'full_name',''))<2 then raise exception 'Complete nome, CPF e cargo'; end if;
  if exists(select 1 from unnest(private.profile_required(m.access_profile_id)) t where not exists(select 1 from public.user_documents d where d.submission_id=s.id and d.is_current and d.document_type=t and (d.expires_on is null or d.expires_on>=current_date))) then raise exception 'Envie todos os documentos obrigatórios válidos'; end if;
  update public.profile_submissions set state='submitted',submitted_at=now(),updated_at=clock_timestamp(),required_types=private.profile_required(m.access_profile_id),reviewer_id=case when reviewer_id<>actor and private.profile_admin(reviewer_id) then reviewer_id else null end where id=s.id;
  update public.organization_memberships set competence_status='pending' where id=m.id;
 elsif command='withdraw' then
  if s.user_id<>actor or s.state<>'submitted' then raise exception 'Esta versão não pode ser retirada'; end if;
  update public.profile_submissions set state='withdrawn',updated_at=clock_timestamp() where id=s.id;
 elsif command in ('review_document','decide') then
  if not private.profile_admin(actor) or s.reviewer_id is distinct from actor or actor=s.user_id or s.state<>'submitted' then raise exception 'Análise restrita ao responsável designado e à versão pendente' using errcode='42501'; end if;
  if payload->>'decision' not in ('approved','rejected') or payload->>'decision' is null then raise exception 'Decisão inválida'; end if;
  if payload->>'decision'='rejected' and length(trim(coalesce(payload->>'reason','')))<3 then raise exception 'Informe o motivo da reprovação'; end if;
  if command='review_document' then
   update public.user_documents set status=payload->>'decision',reviewed_by=actor,reviewed_at=now(),review_note=nullif(trim(payload->>'reason'),'') where id=(payload->>'document_id')::uuid and submission_id=s.id and is_current;
   if not found then raise exception 'Documento não encontrado nesta versão'; end if;
   update public.profile_submissions set updated_at=clock_timestamp() where id=s.id;
  else
   if payload->>'decision'='approved' then
    if coalesce((payload->>'confirmed')::boolean,false)=false then raise exception 'Confirme a revisão dos dados e do vínculo'; end if;
    select * into m from public.organization_memberships where id=s.membership_id and status='active' for update;
    if not found or m.access_profile_id is distinct from s.access_profile_id then raise exception 'O vínculo ou perfil foi alterado; solicite correção'; end if;
    if exists(select 1 from unnest(private.profile_required(m.access_profile_id)) t where not exists(select 1 from public.user_documents d where d.submission_id=s.id and d.document_type=t and d.is_current and d.status='approved' and (d.expires_on is null or d.expires_on>=current_date))) then raise exception 'Aprove todos os documentos obrigatórios válidos antes de concluir'; end if;
    update public.user_profiles set full_name=s.personal->>'full_name',cpf=s.personal->>'cpf',phone=s.personal->>'phone' where user_id=s.user_id;
    update public.organization_memberships set position_id=(s.professional->>'position_id')::uuid,unit_id=nullif(s.professional->>'unit_id','')::uuid,professional_data=s.professional where id=s.membership_id;
   end if;
   update public.profile_submissions set state=payload->>'decision',reviewed_at=now(),review_note=nullif(trim(payload->>'reason'),''),updated_at=clock_timestamp() where id=s.id;
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
