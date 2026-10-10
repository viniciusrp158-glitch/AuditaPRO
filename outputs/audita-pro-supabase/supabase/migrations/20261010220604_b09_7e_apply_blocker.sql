-- B09 Parte 7e (correção): verificador da publicação lê private.plan_revisions.
create or replace function private.b09_apply_blocker(e private.document_emissions) returns text
 language plpgsql stable security definer set search_path = '' as $$
declare v private.plan_revisions%rowtype; r jsonb; prev public.schedule_items%rowtype; dstat text; dayid uuid; reqs jsonb; t text;
begin
 select * into v from private.plan_revisions where id = e.version_id;
 if v.id is null or v.state is distinct from 'validated' then return 'Revisão do plano não está aguardando publicação'; end if;
 for r in select value from jsonb_array_elements(v.content->'schedule') loop
  dayid := null; dstat := null;
  select id, status into dayid, dstat from public.audit_days where audit_id = v.audit_id and audit_date = (r->>'date')::date;
  reqs := coalesce(r->'requirements', '[]'::jsonb); prev := null;
  if nullif(r->>'id', '') is not null then
   select s.* into prev from public.schedule_items s join public.audit_days d on d.id = s.audit_day_id where s.id = (r->>'id')::uuid and d.audit_id = v.audit_id;
  end if;
  if prev.id is not null and prev.status = 'completed' and (prev.title is distinct from r->>'title' or prev.audit_day_id is distinct from dayid
     or exists (select 1 from public.schedule_requirements sr where sr.schedule_item_id = prev.id and not reqs ? sr.requirement_id::text)
     or exists (select 1 from jsonb_array_elements_text(reqs) q where not exists (select 1 from public.schedule_requirements sr where sr.schedule_item_id = prev.id and sr.requirement_id = q::uuid))) then
   return 'Atividade concluída preserva descrição, data e requisitos: ' || prev.title; end if;
  if dstat = 'completed' and (prev.id is null or prev.audit_day_id is distinct from dayid) then
   return 'Dia ' || to_char((r->>'date')::date, 'DD/MM') || ' encerrado não recebe novas atividades'; end if;
  if prev.id is not null and prev.status <> 'planned' and exists (select 1 from public.schedule_requirements sr where sr.schedule_item_id = prev.id and not reqs ? sr.requirement_id::text) then
   return 'Atividade iniciada não perde requisitos: ' || prev.title; end if;
 end loop;
 select s.title into t from public.schedule_items s join public.audit_days d on d.id = s.audit_day_id
  where d.audit_id = v.audit_id and not s.withdrawn and s.status in ('in_progress', 'completed')
    and not exists (select 1 from jsonb_array_elements(v.content->'schedule') x where x->>'id' = s.id::text) limit 1;
 if t is not null then return 'Atividade iniciada não pode ser retirada do plano: ' || t; end if;
 return null;
end;$$;
