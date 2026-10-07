begin;
do $$
declare actor uuid; r jsonb; cid uuid; rid uuid; p jsonb; base2 uuid; composition uuid; org uuid; aid uuid; selected jsonb;
begin
 select id into actor from auth.users where raw_app_meta_data->>'platform_role'='admin' limit 1;
 if actor is null then raise exception 'Administrador não disponível'; end if;
 perform set_config('request.jwt.claim.sub',actor::text,true);
 select id into cid from public.audit_types limit 1;
 r:=public.checklist_library('new','{}'); rid:=(r->>'id')::uuid;
 p:='{"header":{"name":"Teste transacional","category":"custom"},"reason":"Validação com rollback","sections":[{"title":"Seção","requirements":[{"reference":"4.1","prompt":"Requisito","questions":[{"prompt":"Pergunta A"},{"prompt":"Pergunta B"},{"prompt":"Pergunta C"}]}]}],"lock_version":0}'::jsonb;
 p:=p||jsonb_build_object('revision_id',rid);
 p:=jsonb_set(p,'{sections,0,criterion_id}',to_jsonb(cid));
 r:=public.checklist_library('publish',p);
 assert r->>'status'='published';
 assert jsonb_array_length(r->'sections'->0->'requirements'->0->'questions')=3;
 begin
  update public.checklist_questions set prompt='Alteração indevida' where id=(r->'sections'->0->'requirements'->0->'questions'->0->>'id')::uuid;
  raise exception 'TEST: imutabilidade falhou';
 exception when others then if sqlerrm='TEST: imutabilidade falhou' then raise; end if; end;
 r:=public.checklist_library('duplicate',jsonb_build_object('revision_id',rid));
 assert r->>'status'='draft';
 assert jsonb_array_length(r->'sections'->0->'requirements'->0->'questions')=3;
 base2:=(r->>'id')::uuid;
 r:=public.checklist_library('publish',jsonb_build_object('revision_id',base2,'lock_version',0,'header',r->'header','sections',r->'sections','components',r->'components','reason','Segundo modelo'));
 r:=public.checklist_library('new','{}');composition:=(r->>'id')::uuid;
 r:=public.checklist_library('publish',jsonb_build_object('revision_id',composition,'lock_version',0,'header',jsonb_build_object('name','Composição de teste','category','integrated'),'sections','[]'::jsonb,'components',jsonb_build_array(rid,base2),'reason','Integração'));
 assert jsonb_array_length(r->'header'->'criteria')=1,'Composição não herdou critérios';
 select id into org from public.organizations where status='active' limit 1;
 selected:=public.audit_workspace('create',jsonb_build_object('organization_id',org,'type_id',cid,'title','Teste integrado','scope','Mesmo número de cláusula em modelos diferentes'));
 aid:=(selected->>'id')::uuid;
 selected:=public.checklist_execution('suggest',jsonb_build_object('audit_id',aid));
 assert exists(select 1 from jsonb_array_elements(selected) el where el->>'id'=composition::text);
 perform public.checklist_execution('confirm',jsonb_build_object('audit_id',aid,'revisions',jsonb_build_array(composition)));
 assert (select count(*) from public.audit_checklists where audit_id=aid)=2;
 assert (select count(distinct q.id) from public.audit_checklists ac join public.checklist_sections cs on cs.revision_id=ac.revision_id join public.checklist_requirements rq on rq.section_id=cs.id join public.checklist_questions q on q.requirement_id=rq.id where ac.audit_id=aid)=6,'Perguntas homônimas foram fundidas';
 perform public.checklist_library('archive',jsonb_build_object('template_id',r->>'template_id'));
 selected:=public.checklist_execution('suggest',jsonb_build_object('audit_id',aid));
 assert not exists(select 1 from jsonb_array_elements(selected) el where el->>'id'=composition::text);
 assert (select count(*) from public.audit_checklists where audit_id=aid)=2;

end $$;
rollback;
