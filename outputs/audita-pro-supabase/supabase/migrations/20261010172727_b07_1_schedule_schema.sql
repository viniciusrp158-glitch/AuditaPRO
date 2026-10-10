-- B07 Parte 1/3: campos do cronograma e da continuidade (PA-07/08/17/19, RDA-08). Aditiva.
-- Reaproveita schedule_items/audit_days/schedule_movements/audit_plan_versions; nenhuma estrutura paralela.
alter table public.schedule_items
 add column if not exists location text,
 add column if not exists display_order integer,
 add column if not exists assignee_ids uuid[] not null default '{}',
 add column if not exists outcome text,
 add column if not exists outcome_note text,
 add column if not exists performed_summary text,
 add column if not exists remaining_summary text,
 add column if not exists continuation_of uuid references public.schedule_items(id);
alter table public.schedule_items
 add constraint schedule_items_outcome_check check (outcome is null or outcome in ('completed','partial','rescheduled','not_performed')),
 add constraint schedule_items_b07_text_limits check (coalesce(length(location),0) <= 300 and coalesce(length(outcome_note),0) <= 2000
  and coalesce(length(performed_summary),0) <= 2000 and coalesce(length(remaining_summary),0) <= 2000),
 add constraint schedule_items_no_self_continuation check (continuation_of is null or continuation_of <> id);
create index if not exists schedule_items_continuation_idx on public.schedule_items (continuation_of) where continuation_of is not null;

-- Legado: o responsável único passa a ser o primeiro auditor da linha; nada é inventado além disso.
update public.schedule_items set assignee_ids = array[assignee_membership_id]
 where assignee_membership_id is not null and cardinality(assignee_ids) = 0;

comment on column public.schedule_items.assignee_ids is 'B07: auditores da equipe designados para a linha. Não concede permissão (PA-19/D06).';
comment on column public.schedule_items.continuation_of is 'B07: atividade de origem do trabalho restante transferido; cadeias formam histórico navegável (PA-17).';
comment on column public.schedule_items.display_order is 'B07: ordem manual de apresentação; não altera data, dia nem numeração de RDA.';
