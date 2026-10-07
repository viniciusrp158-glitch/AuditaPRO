begin;
create sequence public.checklist_code_seq;
alter table public.checklist_templates add column code text unique default ('CHK-'||lpad(nextval('public.checklist_code_seq')::text,6,'0')),
 add column category text not null default 'normative' check(category in ('normative','custom','integrated'));
alter table public.checklist_revisions add column header jsonb not null default '{}', add column reason text,
 add column lock_version integer not null default 0;
alter table public.checklist_sections add column criterion_id uuid references public.audit_types(id);
create table public.checklist_questions (
 id uuid primary key default gen_random_uuid(), requirement_id uuid not null references public.checklist_requirements(id),
 prompt text not null, theme text, premise text, guidance text, expected_evidence text, internal_notes text,
 required boolean not null default true, allow_na boolean not null default true, active boolean not null default true,
 sort_order integer not null default 0, legacy boolean not null default false
);
create index checklist_questions_requirement on public.checklist_questions(requirement_id,sort_order);
create table public.checklist_components (
 revision_id uuid not null references public.checklist_revisions(id), source_revision_id uuid not null references public.checklist_revisions(id),
 primary key(revision_id,source_revision_id), check(revision_id<>source_revision_id)
);
create index checklist_components_source on public.checklist_components(source_revision_id);
insert into public.checklist_questions(requirement_id,prompt,guidance,sort_order,legacy)
 select id,prompt,guidance,sort_order,true from public.checklist_requirements;
update public.checklist_sections s set criterion_id=t.type_id from public.checklist_revisions r join public.checklist_templates t on t.id=r.template_id where r.id=s.revision_id;
update public.checklist_revisions r set header=jsonb_build_object('name',t.name,'description',t.description,'code',t.code,'category',t.category,'organization_id',t.organization_id,'type_id',t.type_id,'criteria',coalesce((select jsonb_agg(to_jsonb(c)) from public.audit_types c where c.id=t.type_id),'[]')) from public.checklist_templates t where t.id=r.template_id;
alter table public.checklist_questions enable row level security;
alter table public.checklist_components enable row level security;
revoke all on public.checklist_questions,public.checklist_components from anon,authenticated;
revoke all on sequence public.checklist_code_seq from anon,authenticated;
grant all on public.checklist_questions,public.checklist_components to service_role;

create function private.checklist_revision_json(rid uuid) returns jsonb language sql security definer set search_path='' as $$
 select to_jsonb(r)||jsonb_build_object('components',coalesce((select jsonb_agg(source_revision_id) from public.checklist_components where revision_id=rid),'[]'),
 'sections',coalesce((select jsonb_agg(to_jsonb(s)||jsonb_build_object('requirements',coalesce((select jsonb_agg(to_jsonb(q)||jsonb_build_object('questions',coalesce((select jsonb_agg(to_jsonb(x) order by x.sort_order,x.id) from public.checklist_questions x where x.requirement_id=q.id),'[]')) order by q.sort_order,q.id) from public.checklist_requirements q where q.section_id=s.id),'[]')) order by s.sort_order,s.id) from public.checklist_sections s where s.revision_id=rid),'[]')) from public.checklist_revisions r where r.id=rid;
$$;
revoke all on function private.checklist_revision_json(uuid) from public,anon,authenticated;

create function private.checklist_immutable() returns trigger language plpgsql set search_path='' as $$
declare rid uuid; rid2 uuid;
begin
 if tg_table_name='checklist_revisions' then
  if old.status<>'draft' and ((to_jsonb(new)-'status') is distinct from (to_jsonb(old)-'status') or new.status='draft') then raise exception 'Revisão publicada é imutável'; end if; return new;
 elsif tg_table_name='checklist_sections' then
  if tg_op<>'INSERT' then rid:=old.revision_id; end if; if tg_op<>'DELETE' then rid2:=new.revision_id; end if;
 elsif tg_table_name='checklist_requirements' then
  if tg_op<>'INSERT' then select revision_id into rid from public.checklist_sections where id=old.section_id; end if;
  if tg_op<>'DELETE' then select revision_id into rid2 from public.checklist_sections where id=new.section_id; end if;
 elsif tg_table_name='checklist_questions' then
  if tg_op<>'INSERT' then select s.revision_id into rid from public.checklist_requirements q join public.checklist_sections s on s.id=q.section_id where q.id=old.requirement_id; end if;
  if tg_op<>'DELETE' then select s.revision_id into rid2 from public.checklist_requirements q join public.checklist_sections s on s.id=q.section_id where q.id=new.requirement_id; end if;
 else
  if tg_op<>'INSERT' then rid:=old.revision_id; end if; if tg_op<>'DELETE' then rid2:=new.revision_id; end if;
 end if;
 if exists(select 1 from public.checklist_revisions where id in(rid,rid2) and status<>'draft') then raise exception 'Conteúdo publicado é imutável; crie uma nova revisão'; end if;
 if tg_op='DELETE' then return old; end if; return new;
end $$;
create trigger checklist_revision_immutable before update on public.checklist_revisions for each row execute function private.checklist_immutable();
create trigger checklist_sections_immutable before insert or update or delete on public.checklist_sections for each row execute function private.checklist_immutable();
create trigger checklist_requirements_immutable before insert or update or delete on public.checklist_requirements for each row execute function private.checklist_immutable();
create trigger checklist_questions_immutable before insert or update or delete on public.checklist_questions for each row execute function private.checklist_immutable();
create trigger checklist_components_immutable before insert or update or delete on public.checklist_components for each row execute function private.checklist_immutable();
revoke all on function private.checklist_immutable() from public,anon,authenticated;

create function private.checklist_library(cmd text,p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid; rid uuid; sid uuid; qid uuid; xid uuid; t public.checklist_templates%rowtype; r public.checklist_revisions%rowtype;
 h jsonb; sec jsonb; req jsonb; x jsonb; i int; j int; k int; keep_s uuid[]:='{}'; keep_q uuid[]:='{}'; keep_x uuid[]:='{}'; source uuid; org uuid; copy_mode boolean:=false;
begin
 if auth.uid() is null or not private.is_active_account(auth.uid()) or not private.profile_admin(auth.uid()) then raise exception 'Somente Administrador ativo pode gerenciar a biblioteca'; end if;
 if cmd='list' then
  return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(z)) from (
   select t.*, (select coalesce(jsonb_agg(jsonb_build_object('id',rr.id,'number',rr.revision_number,'status',rr.status,'at',rr.created_at,'reason',rr.reason) order by rr.revision_number desc),'[]') from public.checklist_revisions rr where rr.template_id=t.id) revisions
   from public.checklist_templates t where (coalesce(p->>'search','')='' or concat(t.code,' ',t.name) ilike '%'||(p->>'search')||'%')
   and (coalesce(p->>'category','')='' or t.category=p->>'category') and (coalesce(p->>'status','')='' or t.status=p->>'status')
   and (coalesce(p->>'organization_id','')='' or t.organization_id=nullif(p->>'organization_id','')::uuid)
   and (coalesce(p->>'criterion_id','')='' or exists(select 1 from public.checklist_revisions cr join public.checklist_sections cs on cs.revision_id=cr.id where cr.template_id=t.id and cs.criterion_id=nullif(p->>'criterion_id','')::uuid))
   order by t.created_at desc,t.id limit 30 offset greatest(0,coalesce((p->>'page')::int,0))*30) z),'[]'));
 elsif cmd='get' then return private.checklist_revision_json((p->>'revision_id')::uuid);
 elsif cmd='archive' then
  update public.checklist_templates set status='inactive',updated_at=now() where id=(p->>'template_id')::uuid; return '{}';
 elsif cmd in ('new','revise','duplicate') then
  if cmd<>'new' then
   select * into r from public.checklist_revisions where id=(p->>'revision_id')::uuid;
   if r.id is null then raise exception 'Revisão não encontrada'; end if;
   select * into t from public.checklist_templates where id=r.template_id for update;
   h:=private.checklist_revision_json(r.id); copy_mode:=true;
  else h:=jsonb_build_object('header',jsonb_build_object('name','Novo checklist','category','custom'),'sections','[]','components','[]'); end if;
  if cmd='revise' then
   if exists(select 1 from public.checklist_revisions where template_id=t.id and status='draft') then raise exception 'Já existe um rascunho; abra-o na biblioteca'; end if;
   tid:=t.id;
  else
   insert into public.checklist_templates(name,description,organization_id,type_id,created_by,category)
    values(case when cmd='duplicate' then t.name||' — cópia' else 'Novo checklist' end,t.description,t.organization_id,t.type_id,auth.uid(),coalesce(t.category,'custom')) returning id into tid;
  end if;
  insert into public.checklist_revisions(template_id,revision_number,created_by,header)
   select tid,coalesce(max(revision_number),0)+1,auth.uid(),(h->'header')||jsonb_build_object('name',(select name from public.checklist_templates where id=tid),'code',(select code from public.checklist_templates where id=tid)) from public.checklist_revisions where template_id=tid returning id into rid;
  i:=0;
  for sec in select value from jsonb_array_elements(h->'sections') loop
   insert into public.checklist_sections(revision_id,title,sort_order,criterion_id) values(rid,sec->>'title',i,nullif(sec->>'criterion_id','')::uuid) returning id into sid; i:=i+1; j:=0;
   for req in select value from jsonb_array_elements(sec->'requirements') loop
    insert into public.checklist_requirements(section_id,reference,prompt,guidance,sort_order) values(sid,req->>'reference',req->>'prompt',req->>'guidance',j) returning id into qid; j:=j+1;
    for x in select value from jsonb_array_elements(req->'questions') loop
     insert into public.checklist_questions(requirement_id,prompt,theme,premise,guidance,expected_evidence,internal_notes,required,allow_na,active,sort_order,legacy)
      values(qid,x->>'prompt',x->>'theme',x->>'premise',x->>'guidance',x->>'expected_evidence',x->>'internal_notes',(x->>'required')::boolean,(x->>'allow_na')::boolean,(x->>'active')::boolean,(x->>'sort_order')::int,coalesce((x->>'legacy')::boolean,false));
    end loop;
   end loop;
  end loop;
  insert into public.checklist_components select rid,value::uuid from jsonb_array_elements_text(h->'components');
  return private.checklist_revision_json(rid);
 elsif cmd in ('save','publish') then
  rid:=(p->>'revision_id')::uuid;
  select * into r from public.checklist_revisions where id=rid for update;
  if r.id is null or r.status<>'draft' then raise exception 'Abra um rascunho para editar'; end if;
  select * into t from public.checklist_templates where id=r.template_id for update;
  if r.lock_version<>coalesce((p->>'lock_version')::int,-1) then raise exception using errcode='40001',message='Conflito: revisão alterada em outra sessão'; end if;
  h:=p->'header'; org:=nullif(h->>'organization_id','')::uuid;
  if t.organization_id is not null and org is distinct from t.organization_id then raise exception 'A restrição de cliente deve ser preservada'; end if;
  if org is not null and not exists(select 1 from public.organizations where id=org and status='active') then raise exception 'Cliente inválido'; end if;
  if length(trim(coalesce(h->>'name','')))<2 then raise exception 'Informe o nome'; end if;
  if coalesce(h->>'category','') not in ('normative','custom','integrated') then raise exception 'Categoria inválida'; end if;
  if jsonb_typeof(p->'sections') is distinct from 'array' then raise exception 'Seções inválidas'; end if;
  -- Temporary negative positions avoid uniqueness conflicts when reordering.
  update public.checklist_sections set sort_order=-sort_order-1 where revision_id=rid;
  update public.checklist_requirements set sort_order=-sort_order-1 where section_id in(select id from public.checklist_sections where revision_id=rid);
  i:=0;
  for sec in select value from jsonb_array_elements(p->'sections') loop
   sid:=coalesce(nullif(sec->>'id','')::uuid,gen_random_uuid());
   if exists(select 1 from public.checklist_sections where id=sid and revision_id<>rid) then raise exception 'Seção fora da revisão'; end if;
   insert into public.checklist_sections(id,revision_id,title,criterion_id,sort_order) values(sid,rid,coalesce(sec->>'title',''),nullif(sec->>'criterion_id','')::uuid,i)
    on conflict(id) do update set title=excluded.title,criterion_id=excluded.criterion_id,sort_order=excluded.sort_order;
   keep_s:=array_append(keep_s,sid); i:=i+1;j:=0;
   for req in select value from jsonb_array_elements(coalesce(sec->'requirements','[]')) loop
    qid:=coalesce(nullif(req->>'id','')::uuid,gen_random_uuid());
    if exists(select 1 from public.checklist_requirements where id=qid and section_id<>sid) then raise exception 'Requisito fora da seção'; end if;
    insert into public.checklist_requirements(id,section_id,reference,prompt,guidance,sort_order) values(qid,sid,coalesce(req->>'reference',''),coalesce(req->>'prompt',''),req->>'guidance',j)
     on conflict(id) do update set reference=excluded.reference,prompt=excluded.prompt,guidance=excluded.guidance,sort_order=excluded.sort_order;
    keep_q:=array_append(keep_q,qid);j:=j+1;k:=0;
    for x in select value from jsonb_array_elements(coalesce(req->'questions','[]')) loop
     xid:=coalesce(nullif(x->>'id','')::uuid,gen_random_uuid());
     if exists(select 1 from public.checklist_questions where id=xid and requirement_id<>qid) then raise exception 'Pergunta fora do requisito'; end if;
     insert into public.checklist_questions(id,requirement_id,prompt,theme,premise,guidance,expected_evidence,internal_notes,required,allow_na,active,sort_order)
      values(xid,qid,coalesce(x->>'prompt',''),x->>'theme',x->>'premise',x->>'guidance',x->>'expected_evidence',x->>'internal_notes',coalesce((x->>'required')::boolean,true),coalesce((x->>'allow_na')::boolean,true),coalesce((x->>'active')::boolean,true),k)
      on conflict(id) do update set prompt=excluded.prompt,theme=excluded.theme,premise=excluded.premise,guidance=excluded.guidance,expected_evidence=excluded.expected_evidence,internal_notes=excluded.internal_notes,required=excluded.required,allow_na=excluded.allow_na,active=excluded.active,sort_order=excluded.sort_order;
     keep_x:=array_append(keep_x,xid);k:=k+1;
    end loop;
   end loop;
  end loop;
  delete from public.checklist_questions where requirement_id in(select q.id from public.checklist_requirements q join public.checklist_sections s on s.id=q.section_id where s.revision_id=rid) and not(id=any(keep_x));
  delete from public.checklist_requirements where section_id in(select id from public.checklist_sections where revision_id=rid) and not(id=any(keep_q));
  delete from public.checklist_sections where revision_id=rid and not(id=any(keep_s));
  delete from public.checklist_components where revision_id=rid;
  for source in select value::uuid from jsonb_array_elements_text(coalesce(p->'components','[]')) loop
   if not exists(select 1 from public.checklist_revisions cr join public.checklist_templates ct on ct.id=cr.template_id where cr.id=source and cr.status in ('published','retired') and ct.category<>'integrated' and (ct.organization_id is null or ct.organization_id=org)) then raise exception 'Origem inválida, recursiva ou exclusiva de outro cliente'; end if;
   insert into public.checklist_components values(rid,source);
  end loop;
  if h->>'category'<>'integrated' and exists(select 1 from public.checklist_components where revision_id=rid) then raise exception 'Somente modelos integrados aceitam composição'; end if;
  h:=h||jsonb_build_object('code',t.code,'criteria',coalesce((select jsonb_agg(to_jsonb(c)) from public.audit_types c where c.id in(select criterion_id from public.checklist_sections where revision_id=rid)),'[]'));
  update public.checklist_revisions set header=h,reason=p->>'reason',lock_version=lock_version+1 where id=rid;
  if cmd='publish' then
   if nullif(trim(p->>'reason'),'') is null then raise exception 'Informe o motivo da revisão'; end if;
   if h->>'category'='integrated' then
    if not exists(select 1 from public.checklist_components where revision_id=rid) or exists(select 1 from public.checklist_sections where revision_id=rid) then raise exception 'Composição requer modelos de base e nenhuma seção própria'; end if;
   elsif not exists(select 1 from public.checklist_questions x join public.checklist_requirements q on q.id=x.requirement_id join public.checklist_sections s on s.id=q.section_id where s.revision_id=rid and x.active) then raise exception 'Inclua uma pergunta ativa'; end if;
   if exists(select 1 from public.checklist_sections s left join public.audit_types c on c.id=s.criterion_id where s.revision_id=rid and (nullif(trim(s.title),'') is null or c.id is null or not c.active)) then raise exception 'Cada seção exige título e critério ativo'; end if;
   if exists(select 1 from public.checklist_requirements q join public.checklist_sections s on s.id=q.section_id where s.revision_id=rid and (nullif(trim(q.reference),'') is null or not exists(select 1 from public.checklist_questions x where x.requirement_id=q.id))) then raise exception 'Requisito exige referência e perguntas'; end if;
   if exists(select 1 from public.checklist_questions x join public.checklist_requirements q on q.id=x.requirement_id join public.checklist_sections s on s.id=q.section_id where s.revision_id=rid and x.active and nullif(trim(x.prompt),'') is null) then raise exception 'Preencha as perguntas ativas'; end if;
   update public.checklist_revisions set status='retired' where template_id=t.id and status='published';
   update public.checklist_revisions set status='published',published_at=now() where id=rid;
   update public.checklist_templates set name=h->>'name',description=h->>'description',category=h->>'category',organization_id=org,status='published',type_id=(select criterion_id from public.checklist_sections where revision_id=rid order by sort_order limit 1),updated_at=now() where id=t.id;
  elsif t.status='draft' then update public.checklist_templates set name=h->>'name',category=h->>'category',organization_id=org where id=t.id; end if;
  return private.checklist_revision_json(rid);
 end if;
 raise exception 'Comando de biblioteca inválido';
end $$;
create function public.checklist_library(command text,payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$select private.checklist_library(command,payload);$$;
revoke all on function private.checklist_library(text,jsonb),public.checklist_library(text,jsonb) from public,anon;
grant execute on function private.checklist_library(text,jsonb),public.checklist_library(text,jsonb) to authenticated;
commit;
