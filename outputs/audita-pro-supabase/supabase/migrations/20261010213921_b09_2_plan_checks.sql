-- B09 Parte 2: as 15 verificações obrigatórias da seção 10 do Plano, com etapa de correção (atalho) e avisos separados.
-- Inclui a compatibilidade com a execução já registrada (atividade iniciada/concluída e dias encerrados preservados).
create function private.b09_checks(aid uuid, expected int default null) returns jsonb
 language plpgsql stable security definer set search_path = '' as $$
declare a public.audits%rowtype; o public.organizations%rowtype; items jsonb; iss jsonb; fpa private.audit_fpa%rowtype;
 out jsonb := '[]'::jsonb; errs jsonb; r jsonb; si record; last_started date;
begin
 select * into a from public.audits where id = aid;
 select * into o from public.organizations where id = a.organization_id;
 select * into fpa from private.audit_fpa where audit_id = aid;
 items := private.b07_normalize(aid, coalesce(a.plan_draft, '[]'::jsonb));
 iss := private.b07_issues(aid, items);
 -- Itens do cronograma agrupados nas verificações 10–13.
 errs := '[]'::jsonb;
 select max(d.audit_date) into last_started from public.audit_days d where d.audit_id = aid and d.status <> 'planned';
 for r in select value from jsonb_array_elements(items) loop
  select s.*, d.status day_status, d.audit_date into si from public.schedule_items s join public.audit_days d on d.id = s.audit_day_id
   where s.id = (r->>'id')::uuid and d.audit_id = aid;
  if si.id is not null and si.status = 'completed' and (si.title is distinct from r->>'title' or si.audit_date is distinct from (r->>'date')::date
     or (select coalesce(jsonb_agg(requirement_id::text order by requirement_id::text), '[]') from public.schedule_requirements where schedule_item_id = si.id)
        is distinct from (select coalesce(jsonb_agg(v order by v), '[]') from jsonb_array_elements_text(r->'requirements') v)) then
   errs := errs || jsonb_build_object('key', r->>'key', 'message', 'Atividade concluída preserva descrição, data e requisitos: ' || si.title);
  elsif si.id is not null and si.status in ('in_progress', 'completed') and exists (select 1 from public.schedule_requirements sr where sr.schedule_item_id = si.id
     and not (r->'requirements') ? sr.requirement_id::text) then
   errs := errs || jsonb_build_object('key', r->>'key', 'message', 'Atividade iniciada não perde requisitos; registre o resultado parcial e transfira o restante: ' || si.title);
  end if;
  if exists (select 1 from public.audit_days d where d.audit_id = aid and d.audit_date = (r->>'date')::date and d.status = 'completed')
     and (si.id is null or si.audit_date is distinct from (r->>'date')::date) then
   errs := errs || jsonb_build_object('key', r->>'key', 'message', 'Dia ' || to_char((r->>'date')::date, 'DD/MM') || ' encerrado não recebe novas atividades');
  end if;
  if last_started is not null and (r->>'date')::date < last_started and not exists (select 1 from public.audit_days d where d.audit_id = aid
     and d.audit_date = (r->>'date')::date and not d.withdrawn) then
   errs := errs || jsonb_build_object('key', r->>'key', 'message', 'Nova data anterior a um dia já iniciado não é aceita: ' || to_char((r->>'date')::date, 'DD/MM'));
  end if;
 end loop;
 for si in select s.id, s.title from public.schedule_items s join public.audit_days d on d.id = s.audit_day_id
   where d.audit_id = aid and not s.withdrawn and s.status in ('in_progress', 'completed')
     and not exists (select 1 from jsonb_array_elements(items) x where x->>'id' = s.id::text) loop
  errs := errs || jsonb_build_object('key', null, 'message', 'Atividade iniciada não pode ser retirada do plano: ' || si.title);
 end loop;

 out := jsonb_build_array(
  jsonb_build_object('n', 1, 'step', 'identification', 'label', 'Cliente válido e código do cliente',
   'errors', case when o.id is null or o.status <> 'active' then '["Selecione um cliente ativo"]' when nullif(o.code, '') is null then '["Cliente sem código: atualize o cadastro do cliente"]' else '[]' end::jsonb),
  jsonb_build_object('n', 2, 'step', 'identification', 'label', 'Código da auditoria gerado',
   'errors', case when nullif(a.code, '') is null then '["Código da auditoria ausente"]' else '[]' end::jsonb),
  jsonb_build_object('n', 3, 'step', 'identification', 'label', 'Localização preenchida',
   'errors', case when nullif(btrim(a.location), '') is null then '["Informe a localização da auditoria"]' else '[]' end::jsonb),
  jsonb_build_object('n', 4, 'step', 'identification', 'label', 'Período definido (início não posterior ao término)',
   'errors', case when a.declared_start_date is null or a.declared_end_date is null then '["Defina as datas inicial e final"]'
     when a.declared_start_date > a.declared_end_date then '["Data inicial posterior à final"]' else '[]' end::jsonb),
  jsonb_build_object('n', 5, 'step', 'identification', 'label', 'Norma / critério definido',
   'errors', case when coalesce(cardinality(a.criterion_ids), 0) = 0 then '["Selecione ao menos um critério"]' else '[]' end::jsonb),
  jsonb_build_object('n', 6, 'step', 'identification', 'label', 'Natureza e tipo de avaliação',
   'errors', (select coalesce(jsonb_agg(m), '[]') from (values
     (case when a.party is null then 'Informe a natureza (1ª, 2ª ou 3ª parte)' end),
     (case when a.evaluation_type is null then 'Informe o tipo de avaliação' end),
     (case when a.evaluation_type = 'other' and nullif(btrim(a.evaluation_other), '') is null then 'Descreva o tipo "Outra"' end)) v(m) where m is not null)),
  jsonb_build_object('n', 7, 'step', 'team', 'label', 'Equipe definida com condutor habilitado',
   'errors', (select coalesce(jsonb_agg(m), '[]') from (values
     (case when not exists (select 1 from public.audit_participants p where p.audit_id = aid and p.membership_id = a.leader_membership_id and p.active and p.participant_type = 'leader')
        or not private.workspace_eligible(a.leader_membership_id) then 'Condutor ausente ou não habilitado' end),
     (case when not a.team_reviewed then 'Revise e salve a equipe auditora' end)) v(m) where m is not null)),
  jsonb_build_object('n', 8, 'step', 'identification', 'label', 'Outros participantes e comentários (N/A aceito)',
   'errors', (select coalesce(jsonb_agg(m), '[]') from (values
     (case when nullif(btrim(a.participants_text), '') is null then 'Preencha "Outros participantes" ou informe N/A' end),
     (case when nullif(btrim(a.comments), '') is null then 'Preencha "Comentários" ou informe N/A' end)) v(m) where m is not null)),
  jsonb_build_object('n', 9, 'step', 'identification', 'label', 'Objetivo e escopo preenchidos',
   'errors', (select coalesce(jsonb_agg(m), '[]') from (values
     (case when nullif(btrim(a.objective), '') is null then 'Informe o objetivo da auditoria' end),
     (case when nullif(btrim(a.scope), '') is null then 'Informe o escopo da auditoria' end)) v(m) where m is not null)),
  jsonb_build_object('n', 10, 'step', 'schedule', 'label', 'Cronograma com atividade válida e compatível com a execução',
   'errors', (select coalesce(jsonb_agg(i->>'message'), '[]') from jsonb_array_elements(iss) i where i->>'level' = 'error' and i->>'field' = 'schedule')
     || (select coalesce(jsonb_agg(e->>'message'), '[]') from jsonb_array_elements(errs) e)),
  jsonb_build_object('n', 11, 'step', 'schedule', 'label', 'Cada linha com localização, data, horário, descrição e auditor da equipe',
   'errors', (select coalesce(jsonb_agg(distinct i->>'message'), '[]') from jsonb_array_elements(iss) i where i->>'level' = 'error'
     and (i->>'field' in ('title', 'location', 'assignees') or i->>'message' like 'Informe%'))),
  jsonb_build_object('n', 12, 'step', 'schedule', 'label', 'Datas no período e durações válidas',
   'errors', (select coalesce(jsonb_agg(distinct i->>'message'), '[]') from jsonb_array_elements(iss) i where i->>'level' = 'error'
     and i->>'key' is not null and i->>'field' in ('date', 'time') and i->>'message' not like 'Informe%')),
  jsonb_build_object('n', 13, 'step', 'schedule', 'label', 'Requisitos dos critérios da auditoria, distribuídos no cronograma',
   'errors', (case when a.checklist_confirmed_at is null then '["Confirme o conjunto de checklists da auditoria"]'::jsonb else '[]'::jsonb end)
     || (select coalesce(jsonb_agg(distinct i->>'message'), '[]') from jsonb_array_elements(iss) i where i->>'level' = 'error'
     and i->>'field' in ('requirements', 'process', 'identity', 'continuation'))),
  jsonb_build_object('n', 14, 'step', 'identification', 'label', 'FPA solicitado, recebido e analisado como suficiente',
   'errors', case when fpa.status is distinct from 'sufficient' or fpa.sufficient_version_id is null then '["Registre a análise do FPA como suficiente"]' else '[]' end::jsonb),
  jsonb_build_object('n', 15, 'step', 'review', 'label', 'Sem conflito de edição (versão revisada é a atual)',
   'errors', case when expected is not null and expected <> a.lock_version then '["O plano foi alterado em outra sessão; recarregue e revise"]' else '[]' end::jsonb));
 return jsonb_build_object('checks', (select jsonb_agg(c || jsonb_build_object('ok', jsonb_array_length(c->'errors') = 0) order by (c->>'n')::int) from jsonb_array_elements(out) c),
  'warnings', (select coalesce(jsonb_agg(jsonb_build_object('key', i->>'key', 'message', i->>'message')), '[]') from jsonb_array_elements(iss) i where i->>'level' = 'warning'),
  'items', items, 'lock_version', a.lock_version,
  'ok', not exists (select 1 from jsonb_array_elements(out) c where jsonb_array_length(c->'errors') > 0));
end;$$;
revoke all on function private.b09_checks(uuid, int) from public, anon, authenticated;
