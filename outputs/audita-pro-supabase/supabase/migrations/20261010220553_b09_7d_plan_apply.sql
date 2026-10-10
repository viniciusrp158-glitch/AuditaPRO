-- B09 Parte 7d (correção): aplicação lê private.plan_revisions e registra a publicação em audit_plan_versions (contrato legado).
create or replace function private.b09_apply(e private.document_emissions) returns void
 language plpgsql security definer set search_path = '' as $$
#variable_conflict use_variable
declare v private.plan_revisions%rowtype; pvid uuid; legacy jsonb; a public.audits%rowtype; snap jsonb; r jsonb; dayid uuid; proc uuid; sid uuid; newid uuid;
 prev public.schedule_items%rowtype; cur public.schedule_items%rowtype; keep uuid[] := '{}'; idmap jsonb := '{}'; actor uuid; why text;
 dn record; maxn int; prev_day_status text; reqs jsonb; assignees uuid[];
begin
 select * into v from private.plan_revisions where id = e.version_id for update;
 if v.id is null or v.state is distinct from 'validated' then raise exception 'Revisão do plano não está aguardando publicação'; end if;
 select * into a from public.audits where id = v.audit_id for update;
 snap := v.content; actor := v.created_by; why := v.revision_label || ': ' || v.reason;

 -- Dias: planejados saem do caminho; datas da revisão recebem a numeração calculada; dias iniciados não mudam.
 update public.audit_days set day_number = day_number + 100000 where audit_id = a.id and status = 'planned';
 for dn in select * from private.b09_day_numbers(a.id, (select array_agg(distinct (x->>'date')::date) from jsonb_array_elements(snap->'schedule') x)) loop
  update public.audit_days set day_number = dn.day_number, withdrawn = false where audit_id = a.id and audit_date = dn.audit_date and status = 'planned';
  if not found and not exists (select 1 from public.audit_days where audit_id = a.id and audit_date = dn.audit_date) then
   insert into public.audit_days (audit_id, day_number, audit_date) values (a.id, dn.day_number, dn.audit_date);
  end if;
 end loop;
 select coalesce(max(day_number), 0) into maxn from public.audit_days where audit_id = a.id and day_number < 100000;
 update public.audit_days d set withdrawn = true, day_number = maxn + x.k
  from (select id, row_number() over (order by audit_date) k from public.audit_days where audit_id = a.id and day_number >= 100000) x where d.id = x.id;

 for r in select value from jsonb_array_elements(snap->'schedule') loop
  select id, status into dayid, prev_day_status from public.audit_days where audit_id = a.id and audit_date = (r->>'date')::date;
  reqs := coalesce(r->'requirements', '[]'::jsonb);
  assignees := array(select x::uuid from jsonb_array_elements_text(coalesce(r->'assignee_ids', '[]'::jsonb)) x);
  proc := null;
  if nullif(btrim(r->>'process'), '') is not null then
   insert into public.audit_processes (audit_id, name) values (a.id, btrim(r->>'process'))
   on conflict (audit_id, name) do update set name = excluded.name returning id into proc;
  end if;
  prev := null; sid := nullif(r->>'id', '')::uuid;
  if sid is not null then
   select s.* into prev from public.schedule_items s join public.audit_days d on d.id = s.audit_day_id where s.id = sid and d.audit_id = a.id;
  end if;
  if prev.id is not null and prev.status = 'completed' and (prev.title is distinct from r->>'title' or prev.audit_day_id is distinct from dayid
     or exists (select 1 from public.schedule_requirements sr where sr.schedule_item_id = prev.id and not reqs ? sr.requirement_id::text)
     or exists (select 1 from jsonb_array_elements_text(reqs) q where not exists (select 1 from public.schedule_requirements sr where sr.schedule_item_id = prev.id and sr.requirement_id = q::uuid))) then
   raise exception 'Atividade concluída preserva descrição, data e requisitos: %', prev.title; end if;
  if prev_day_status = 'completed' and (prev.id is null or prev.audit_day_id is distinct from dayid) then
   raise exception 'Dia % encerrado não recebe novas atividades', to_char((r->>'date')::date, 'DD/MM'); end if;
  if prev.id is not null and exists (select 1 from public.schedule_requirements sr where sr.schedule_item_id = prev.id and not reqs ? sr.requirement_id::text) then
   if prev.status <> 'planned' then raise exception 'Atividade iniciada não perde requisitos: %', prev.title; end if;
   -- Escopo encolheu antes do início: nova identidade; a anterior fica retirada e aponta a sucessora.
   newid := gen_random_uuid();
   insert into public.schedule_items (id, audit_day_id, process_id, title, planned_start, planned_end, assignee_membership_id, assignee_ids, category, notes,
     location, display_order, continuation_of, remaining_summary)
   values (newid, dayid, proc, r->>'title', (r->>'start')::timestamptz, (r->>'end')::timestamptz, coalesce(assignees[1], a.leader_membership_id), assignees,
     r->>'category', r->>'notes', r->>'location', (r->>'display_order')::int, nullif(r->>'continuation_of', '')::uuid, r->>'remaining_summary');
   update public.schedule_items set withdrawn = true, replaced_by = newid, updated_at = clock_timestamp() where id = prev.id;
   insert into public.schedule_question_scope (schedule_id, question_id, included, reason, actor, updated_at)
    select newid, question_id, included, reason, actor, updated_at from public.schedule_question_scope where schedule_id = prev.id;
   insert into public.schedule_extra_questions (schedule_id, question_id, included) select newid, question_id, included from public.schedule_extra_questions where schedule_id = prev.id;
   insert into public.schedule_movements (audit_id, schedule_item_id, previous_data, new_data, reason, created_by)
    select a.id, prev.id, to_jsonb(prev), to_jsonb(s), why, actor from public.schedule_items s where s.id = newid;
   sid := newid;
  elsif prev.id is not null then
   update public.schedule_items set audit_day_id = dayid, process_id = proc, title = r->>'title', planned_start = (r->>'start')::timestamptz,
     planned_end = (r->>'end')::timestamptz, assignee_membership_id = coalesce(assignees[1], a.leader_membership_id), assignee_ids = assignees,
     category = r->>'category', notes = r->>'notes', location = r->>'location', display_order = (r->>'display_order')::int,
     continuation_of = coalesce(nullif(r->>'continuation_of', '')::uuid, continuation_of), remaining_summary = coalesce(r->>'remaining_summary', remaining_summary),
     withdrawn = false,
     origin_day_id = case when prev.audit_day_id <> dayid then coalesce(origin_day_id, prev.audit_day_id) else origin_day_id end,
     move_reason = case when prev.audit_day_id <> dayid then why else move_reason end,
     moved_at = case when prev.audit_day_id <> dayid then clock_timestamp() else moved_at end,
     moved_by = case when prev.audit_day_id <> dayid then actor else moved_by end
   where id = prev.id returning * into cur;
   if (to_jsonb(cur) - 'updated_at') is distinct from (to_jsonb(prev) - 'updated_at') then
    update public.schedule_items set updated_at = clock_timestamp() where id = prev.id;
    insert into public.schedule_movements (audit_id, schedule_item_id, previous_data, new_data, reason, created_by) values (a.id, prev.id, to_jsonb(prev), to_jsonb(cur), why, actor);
   end if;
   sid := prev.id;
  else
   sid := case when not exists (select 1 from public.schedule_items where id = (r->>'key')::uuid) then (r->>'key')::uuid else gen_random_uuid() end;
   insert into public.schedule_items (id, audit_day_id, process_id, title, planned_start, planned_end, assignee_membership_id, assignee_ids, category, notes,
     location, display_order, continuation_of, remaining_summary)
   values (sid, dayid, proc, r->>'title', (r->>'start')::timestamptz, (r->>'end')::timestamptz, coalesce(assignees[1], a.leader_membership_id), assignees,
     r->>'category', r->>'notes', r->>'location', (r->>'display_order')::int, nullif(r->>'continuation_of', '')::uuid, r->>'remaining_summary');
  end if;
  insert into public.schedule_requirements (schedule_item_id, requirement_id) select sid, q::uuid from jsonb_array_elements_text(reqs) q on conflict do nothing;
  keep := keep || sid; idmap := idmap || jsonb_build_object(r->>'key', sid);
 end loop;

 -- Omitidas na revisão: retiradas (atividade iniciada não pode ser omitida).
 for prev in select s.* from public.schedule_items s join public.audit_days d on d.id = s.audit_day_id
   where d.audit_id = a.id and not s.withdrawn and not (s.id = any(keep)) loop
  if prev.status in ('in_progress', 'completed') then raise exception 'Atividade iniciada não pode ser retirada do plano: %', prev.title; end if;
  update public.schedule_items set withdrawn = true, updated_at = clock_timestamp() where id = prev.id returning * into cur;
  insert into public.schedule_movements (audit_id, schedule_item_id, previous_data, new_data, reason, created_by) values (a.id, prev.id, to_jsonb(prev), to_jsonb(cur), 'Retirada — ' || why, actor);
 end loop;

 -- Publicação no contrato legado (lido pelo B03, documentos e projeção do cliente): lista das atividades vigentes.
 select coalesce(jsonb_agg(to_jsonb(si) || jsonb_build_object('date', ad.audit_date, 'process', pr.name,
   'requirements', (select coalesce(jsonb_agg(requirement_id), '[]'::jsonb) from public.schedule_requirements where schedule_item_id = si.id))
   order by ad.audit_date, si.planned_start), '[]'::jsonb) into legacy
 from public.schedule_items si join public.audit_days ad on ad.id = si.audit_day_id left join public.audit_processes pr on pr.id = si.process_id
 where ad.audit_id = a.id and not si.withdrawn;
 insert into public.audit_plan_versions (audit_id, version_number, content, reason, created_by)
 values (a.id, a.plan_revision + 1, legacy, why, actor) returning id into pvid;

 -- Rascunho em edição recebe as identidades publicadas (por chave), sem perder alterações feitas após a validação.
 update public.audits set plan_draft = coalesce((select jsonb_agg(case when idmap ? (x->>'key') then x || jsonb_build_object('id', idmap->>(x->>'key')) else x end)
     from jsonb_array_elements(coalesce(plan_draft, '[]'::jsonb)) x), '[]'::jsonb),
   plan_revision = plan_revision + 1, status = case when status = 'draft' then 'planned' else status end,
   start_date = (select min(audit_date) from public.audit_days where audit_id = a.id and not withdrawn),
   end_date = (select max(audit_date) from public.audit_days where audit_id = a.id and not withdrawn),
   lock_version = lock_version + 1, updated_at = clock_timestamp()
 where id = a.id;
 update private.plan_revisions set state = 'superseded', superseded_by = v.id where audit_id = a.id and state = 'published';
 update private.plan_revisions set state = 'published', published_at = clock_timestamp(), plan_version_id = pvid where id = v.id;
 insert into public.audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata)
 values (a.organization_id, actor, 'plan_published', 'plan_revisions', v.id,
   jsonb_build_object('audit_id', a.id, 'revision', v.revision_label, 'plan_version', a.plan_revision + 1, 'emission_id', e.id, 'pdf_sha256', e.pdf_sha256, 'activities', cardinality(keep)));
end;$$;
