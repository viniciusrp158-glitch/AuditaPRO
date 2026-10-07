begin;
do $$
declare actor uuid; r jsonb; cid uuid; rid uuid; p jsonb;
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
end $$;
rollback;
