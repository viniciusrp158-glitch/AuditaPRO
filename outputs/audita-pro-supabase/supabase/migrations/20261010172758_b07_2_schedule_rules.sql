-- B07 Parte 2/3: normalização e verificações do rascunho do cronograma (PA-07..10, PA-22). Aditiva.
-- Horários são interpretados no fuso da auditoria (audits.timezone), no servidor, nunca no fuso do navegador.
create function private.b07_local_ts(d date, t text, tz text) returns timestamptz
 language sql immutable set search_path = '' as $$
 select case when d is null or t is null or t !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then null
  else (d + t::time) at time zone coalesce(nullif(tz, ''), 'America/Sao_Paulo') end;
$$;

-- Converte o rascunho (formato B07 ou legado com start/end ISO) para o formato canônico; erro só para dado estruturalmente inválido.
create function private.b07_normalize(aid uuid, items jsonb) returns jsonb
 language plpgsql stable security definer set search_path = '' as $$
declare tz text; out jsonb := '[]'::jsonb; it jsonb; n int := 0; d date; st text; en text; k uuid;
begin
 select coalesce(timezone, 'America/Sao_Paulo') into tz from public.audits where id = aid;
 if jsonb_typeof(coalesce(items, '[]'::jsonb)) <> 'array' then raise exception 'Cronograma inválido'; end if;
 if jsonb_array_length(items) > 500 then raise exception 'Cronograma acima de 500 atividades'; end if;
 for it in select value from jsonb_array_elements(items) loop
  n := n + 1;
  if jsonb_typeof(it) <> 'object' then raise exception 'Linha % inválida', n; end if;
  d := nullif(it->>'date', '')::date;
  st := coalesce(nullif(it->>'start_time', ''), case when nullif(it->>'start', '') is not null then to_char((it->>'start')::timestamptz at time zone tz, 'HH24:MI') end);
  en := coalesce(nullif(it->>'end_time', ''), case when nullif(it->>'end', '') is not null then to_char((it->>'end')::timestamptz at time zone tz, 'HH24:MI') end);
  if st is not null and st !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then raise exception 'Linha %: horário de início inválido', n; end if;
  if en is not null and en !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then raise exception 'Linha %: horário de término inválido', n; end if;
  if coalesce(it->>'category', 'assessment') not in ('assessment','opening','closing','meeting','break','other') then raise exception 'Linha %: categoria inválida', n; end if;
  k := coalesce(nullif(it->>'key', '')::uuid, nullif(it->>'id', '')::uuid, gen_random_uuid());
  if length(coalesce(it->>'title','')) > 300 or length(coalesce(it->>'location','')) > 300 or length(coalesce(it->>'notes','')) > 2000
     or length(coalesce(it->>'process','')) > 200 or length(coalesce(it->>'remaining_summary','')) > 2000 then
   raise exception 'Linha %: texto acima do limite', n; end if;
  out := out || jsonb_build_array(jsonb_build_object(
   'key', k, 'id', nullif(it->>'id', '')::uuid, 'continuation_of', nullif(it->>'continuation_of', '')::uuid,
   'remaining_summary', nullif(btrim(it->>'remaining_summary'), ''),
   'title', coalesce(btrim(it->>'title'), ''), 'process', nullif(btrim(it->>'process'), ''), 'category', coalesce(it->>'category', 'assessment'),
   'date', d, 'start_time', st, 'end_time', en,
   'start', private.b07_local_ts(d, st, tz), 'end', private.b07_local_ts(d, en, tz),
   'location', nullif(btrim(it->>'location'), ''), 'notes', nullif(btrim(it->>'notes'), ''),
   'assignee_ids', coalesce((select jsonb_agg(distinct v::uuid) from jsonb_array_elements_text(coalesce(it->'assignee_ids', '[]'::jsonb)) v), '[]'::jsonb),
   'requirements', coalesce((select jsonb_agg(distinct v::uuid) from jsonb_array_elements_text(coalesce(it->'requirements', '[]'::jsonb)) v), '[]'::jsonb),
   'display_order', n));
 end loop;
 if (select count(*) <> count(distinct x->>'key') from jsonb_array_elements(out) x) then raise exception 'Linhas do cronograma com identificação repetida'; end if;
 return out;
exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow then
 raise exception 'Cronograma com dado inválido na linha %: %', n, sqlerrm;
end;$$;

-- Erros impedem a validação do plano (B09); avisos pedem revisão sem bloquear (PA-10).
create function private.b07_issues(aid uuid, items jsonb) returns jsonb
 language sql stable security definer set search_path = '' as $$
 with a as (select * from public.audits where id = aid),
 team as (select ap.membership_id from public.audit_participants ap where ap.audit_id = aid and ap.active and ap.participant_type in ('leader','auditor')),
 scope as (select q.id from public.audit_checklists ac join public.checklist_sections s on s.revision_id = ac.revision_id
   join public.checklist_requirements q on q.section_id = s.id where ac.audit_id = aid),
 plan_rows as (select value r, (value->>'display_order')::int ord from jsonb_array_elements(items)),
 row_issues as (
  select r->>'key' k, 'error' lvl, f, m from plan_rows, lateral (values
   ('title', case when r->>'title' = '' then 'Descreva a área, o processo ou a atividade' end),
   ('date', case when r->>'date' is null then 'Informe a data' end),
   ('time', case when r->>'start_time' is null or r->>'end_time' is null then 'Informe início e término' end),
   ('time', case when r->>'start_time' >= r->>'end_time' then 'O término deve ser posterior ao início; trabalho após a meia-noite exige outra linha na data seguinte' end),
   ('location', case when r->>'location' is null then 'Informe a localização da atividade' end),
   ('assignees', case when jsonb_array_length(r->'assignee_ids') = 0 then 'Selecione ao menos um auditor da equipe' end),
   ('assignees', case when exists (select 1 from jsonb_array_elements_text(r->'assignee_ids') x where x::uuid not in (select membership_id from team)) then 'Auditor fora da equipe da auditoria' end),
   ('date', case when (select declared_start_date from a) is not null and (r->>'date')::date < (select declared_start_date from a) then 'Data anterior ao período declarado' end),
   ('date', case when (select declared_end_date from a) is not null and (r->>'date')::date > (select declared_end_date from a) then 'Data posterior ao período declarado' end),
   ('process', case when r->>'category' = 'assessment' and r->>'process' is null then 'Atividade de avaliação exige processo' end),
   ('requirements', case when r->>'category' = 'assessment' and jsonb_array_length(r->'requirements') = 0 then 'Atividade de avaliação exige requisitos' end),
   ('requirements', case when exists (select 1 from jsonb_array_elements_text(r->'requirements') x where x::uuid not in (select id from scope)) then 'Requisito fora dos checklists da auditoria' end),
   ('identity', case when r->>'id' is not null and (select count(*) from plan_rows z where z.r->>'id' = plan_rows.r->>'id') > 1 then 'Duas linhas com a mesma atividade publicada; use Duplicar para criar uma nova atividade' end),
   ('continuation', case when r->>'continuation_of' is not null and not exists (select 1 from public.schedule_items si join public.audit_days d on d.id = si.audit_day_id
     where si.id = (r->>'continuation_of')::uuid and d.audit_id = aid) then 'Origem do trabalho restante não pertence à auditoria' end)
  ) v(f, m) where m is not null),
 overlap_warn as (
  select x.r->>'key' k, 'warning' lvl, 'assignees' f,
   'Mesmo auditor em horário sobreposto com "' || coalesce(nullif(y.r->>'title',''), 'outra linha') || '" (' || (y.r->>'start_time') || '–' || (y.r->>'end_time') || ')' m
  from plan_rows x join plan_rows y on x.ord <> y.ord and x.r->>'date' = y.r->>'date'
   and x.r->>'start_time' < y.r->>'end_time' and y.r->>'start_time' < x.r->>'end_time'
   and exists (select 1 from jsonb_array_elements_text(x.r->'assignee_ids') i join jsonb_array_elements_text(y.r->'assignee_ids') j on i = j)),
 order_warn as (
  select x.r->>'key' k, 'warning' lvl, 'order' f, 'Linha fora da ordem cronológica em relação à anterior' m
  from plan_rows x join plan_rows y on y.ord = x.ord - 1
  where (x.r->>'date', coalesce(x.r->>'start_time','')) < (y.r->>'date', coalesce(y.r->>'start_time',''))),
 plan_issues as (
  select null::text k, 'error' lvl, f, m from (values
   ('schedule', case when not exists (select 1 from plan_rows) then 'Inclua ao menos uma atividade no cronograma' end),
   ('period', case when (select declared_start_date is null or declared_end_date is null from a) then 'Defina o período da auditoria na identificação' end),
   ('requirements', (select case when count(*) > 0 then count(*) || ' requisito(s) dos checklists ainda não distribuído(s) no cronograma' end
     from scope where id::text not in (select jsonb_array_elements_text(r->'requirements') from plan_rows)))
  ) v(f, m) where m is not null)
 select coalesce(jsonb_agg(jsonb_build_object('key', k, 'level', lvl, 'field', f, 'message', m) order by lvl, k nulls first), '[]'::jsonb)
 from (select * from plan_issues union all select * from row_issues union all select * from overlap_warn union all select * from order_warn) all_issues;
$$;
revoke all on function private.b07_local_ts(date, text, text), private.b07_normalize(uuid, jsonb), private.b07_issues(uuid, jsonb) from public, anon, authenticated;
