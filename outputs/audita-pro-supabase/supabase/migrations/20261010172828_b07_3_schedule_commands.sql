-- B07 Parte 3/3: comandos do cronograma (draft/save/record_outcome). Publicação do rascunho: B09.
create function private.b07_published_json(aid uuid) returns jsonb language sql stable security definer set search_path = '' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id', si.id, 'title', si.title, 'date', d.audit_date, 'day_number', d.day_number, 'day_status', d.status,
   'status', si.status, 'withdrawn', si.withdrawn, 'outcome', si.outcome, 'outcome_note', si.outcome_note,
   'performed_summary', si.performed_summary, 'remaining_summary', si.remaining_summary, 'continuation_of', si.continuation_of,
   'planned_start', si.planned_start, 'planned_end', si.planned_end, 'actual_start', si.actual_start, 'actual_end', si.actual_end,
   'location', si.location, 'assignee_ids', to_jsonb(si.assignee_ids), 'category', si.category,
   'process', (select name from public.audit_processes p where p.id = si.process_id),
   'requirements', (select coalesce(jsonb_agg(requirement_id), '[]'::jsonb) from public.schedule_requirements r where r.schedule_item_id = si.id),
   'continued_by', (select coalesce(jsonb_agg(c.id), '[]'::jsonb) from public.schedule_items c where c.continuation_of = si.id))
  order by d.audit_date, coalesce(si.display_order, 0), si.planned_start nulls last), '[]'::jsonb)
 from public.schedule_items si join public.audit_days d on d.id = si.audit_day_id where d.audit_id = aid;
$$;

create function private.b07_schedule(command text, payload jsonb default '{}'::jsonb) returns jsonb
 language plpgsql security definer set search_path = '' as $$
#variable_conflict use_variable
declare actor uuid := auth.uid(); aid uuid; a public.audits%rowtype; items jsonb; op uuid; prior jsonb; result jsonb;
 si public.schedule_items%rowtype; d public.audit_days%rowtype; prev jsonb;
begin
 if actor is null or not private.is_active_account(actor) then raise exception 'Sessão ativa necessária' using errcode = '42501'; end if;
 aid := (payload->>'audit_id')::uuid;
 select * into a from public.audits where id = aid;
 if a.id is null or not (private.workspace_conductor(aid) or private.checklist_internal(aid)) then
  raise exception 'Cronograma indisponível para este acesso' using errcode = '42501'; end if;
 if command = 'draft' then
  items := case when jsonb_array_length(coalesce(a.plan_draft, '[]'::jsonb)) > 0 then a.plan_draft else '[]'::jsonb end;
  items := private.b07_normalize(aid, items);
  return jsonb_build_object('lock_version', a.lock_version, 'timezone', coalesce(a.timezone, 'America/Sao_Paulo'), 'status', a.status,
   'plan_revision', a.plan_revision, 'declared_start_date', a.declared_start_date, 'declared_end_date', a.declared_end_date,
   'location', a.location, 'items', items, 'issues', private.b07_issues(aid, items), 'published', private.b07_published_json(aid),
   'can_edit', private.workspace_conductor(aid) and a.status in ('draft','planned','in_progress'),
   'team', coalesce((select jsonb_agg(jsonb_build_object('membership_id', ap.membership_id, 'name', p.full_name, 'role', ap.participant_type,
     'conductor', ap.membership_id = a.leader_membership_id) order by ap.membership_id <> a.leader_membership_id, p.full_name)
    from public.audit_participants ap join public.organization_memberships m on m.id = ap.membership_id join public.user_profiles p on p.user_id = m.user_id
    where ap.audit_id = aid and ap.active and ap.participant_type in ('leader','auditor')), '[]'::jsonb),
   'requirements', coalesce((select jsonb_agg(jsonb_build_object('id', q.id, 'reference', q.reference, 'section', s.title,
     'criterion', (select t.code || coalesce(' · ' || nullif(t.edition, ''), '') from public.audit_types t where t.id = s.criterion_id)) order by s.sort_order, q.sort_order)
    from public.audit_checklists ac join public.checklist_sections s on s.revision_id = ac.revision_id join public.checklist_requirements q on q.section_id = s.id
    where ac.audit_id = aid), '[]'::jsonb),
   'days', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'date', x.audit_date, 'day_number', x.day_number, 'status', x.status) order by x.audit_date)
    from public.audit_days x where x.audit_id = aid), '[]'::jsonb));
 end if;
 if not private.workspace_conductor(aid) then raise exception 'Somente o condutor ou o Administrador altera o cronograma' using errcode = '42501'; end if;
 if a.status not in ('draft','planned','in_progress') then raise exception 'Auditoria encerrada ou cancelada: cronograma somente para consulta'; end if;
 op := (payload->>'operation_id')::uuid;
 if op is null then raise exception 'operation_id obrigatório'; end if;
 select o.response into prior from private.b06_operations o where o.operation_id = op and o.actor = actor and o.command = 'b07_' || command;
 if prior is not null then return prior; end if;
 select * into a from public.audits where id = aid for update;
 if a.lock_version <> coalesce((payload->>'expected_lock_version')::int, -1) then
  raise exception 'Cronograma alterado em outra sessão. Recarregue para comparar antes de salvar' using errcode = '40001'; end if;

 if command = 'save' then
  items := private.b07_normalize(aid, payload->'items');
  update public.audits set plan_draft = items, lock_version = lock_version + 1, updated_at = clock_timestamp() where id = aid returning * into a;
  insert into public.audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata)
  values (a.organization_id, actor, 'b07_schedule_draft_saved', 'audits', aid, jsonb_build_object('rows', jsonb_array_length(items), 'lock_version', a.lock_version));
  result := jsonb_build_object('lock_version', a.lock_version, 'items', items, 'issues', private.b07_issues(aid, items));
 elsif command = 'record_outcome' then
  select si0.* into si from public.schedule_items si0 join public.audit_days d0 on d0.id = si0.audit_day_id where si0.id = (payload->>'schedule_id')::uuid and d0.audit_id = aid for update of si0;
  if si.id is null or si.withdrawn then raise exception 'Atividade publicada não encontrada'; end if;
  select * into d from public.audit_days where id = si.audit_day_id;
  if d.status = 'completed' then raise exception 'Dia encerrado: registre a continuidade por revisão do plano'; end if;
  if payload->>'outcome' not in ('partial','not_performed') then raise exception 'Resultado deve ser parcial ou não realizada'; end if;
  if payload->>'outcome' = 'partial' and (length(btrim(coalesce(payload->>'performed_summary',''))) < 3 or length(btrim(coalesce(payload->>'remaining_summary',''))) < 3) then
   raise exception 'Descreva a parcela realizada e o trabalho restante'; end if;
  if payload->>'outcome' = 'not_performed' and length(btrim(coalesce(payload->>'outcome_note',''))) < 3 then
   raise exception 'Informe o motivo e o encaminhamento da atividade não realizada'; end if;
  prev := to_jsonb(si);
  update public.schedule_items set outcome = payload->>'outcome', outcome_note = nullif(btrim(payload->>'outcome_note'),''),
   performed_summary = nullif(btrim(payload->>'performed_summary'),''), remaining_summary = nullif(btrim(payload->>'remaining_summary'),''),
   status = case when payload->>'outcome' = 'not_performed' then 'not_done' else status end, updated_at = clock_timestamp()
  where id = si.id returning * into si;
  insert into public.schedule_movements (audit_id, schedule_item_id, previous_data, new_data, reason, created_by)
  values (aid, si.id, prev, to_jsonb(si), coalesce(nullif(btrim(payload->>'outcome_note'),''), 'Execução parcial registrada'), actor);
  update public.audits set lock_version = lock_version + 1 where id = aid returning * into a;
  result := jsonb_build_object('lock_version', a.lock_version, 'published', private.b07_published_json(aid));
 else
  raise exception 'Comando desconhecido';
 end if;
 insert into private.b06_operations (operation_id, actor, command, response) values (op, actor, 'b07_' || command, result);
 return result;
end;$$;

revoke all on function private.b07_schedule(text, jsonb), private.b07_published_json(uuid) from public, anon, authenticated;
grant execute on function private.b07_schedule(text, jsonb) to authenticated;
create function public.audit_schedule(command text, payload jsonb default '{}'::jsonb) returns jsonb
 language sql set search_path = '' as $$ select private.b07_schedule(command, payload); $$;
revoke all on function public.audit_schedule(text, jsonb) from public, anon;
grant execute on function public.audit_schedule(text, jsonb) to authenticated;
