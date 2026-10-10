-- Recuperada de supabase_migrations.schema_migrations em 2026-10-10 (B00, Claude).
-- JA APLICADA no projeto zlckcpeqcxmtrgbdquee. NAO reaplicar. md5(statements)=f005b52e6a6eacc10bf4ac60ca750e7b

-- B03: carteira autorizada, independente dos dashboards futuros de B13.
begin;

create index if not exists b03_audits_start_page on public.audits(start_date desc,id);

create index if not exists b03_reports_audit_generated on public.daily_reports(audit_id,generated_at);

create or replace function private.b03_portfolio_metrics(
  date_from date default null, date_to date default null,
  selection text default 'period', page_size integer default 25, page_offset integer default 0
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare answer jsonb;
begin
  if auth.uid() is null or not exists(select 1 from public.user_profiles where user_id=auth.uid() and status='active') then
    raise exception 'Sessão ativa necessária' using errcode='42501';
  end if;
  if selection not in ('period','all','active') or selection is null
    or page_size is null or page_size not between 1 and 100 or page_offset is null or page_offset<0
    or (date_from is not null and date_to is not null and date_from>date_to) then
    raise exception 'Filtro de carteira inválido' using errcode='22023';
  end if;
  -- Projeção limitada: o escopo B02 é aplicado antes de agregar. As tabelas
  -- operacionais inteiras continuam protegidas por RLS, inclusive do apoio.
  with visible as materialized (
    select a.* from public.audits a where private.b02_scope(a.id) and (
      selection='all' or (selection='active' and a.status in ('planned','in_progress','awaiting_signoff'))
      or (selection='period' and (date_from is null or a.start_date>=date_from) and (date_to is null or a.start_date<=date_to)))
  ), company_counts as (
    select v.organization_id,coalesce(o.legal_name,'Não informado') name,count(*) total
    from visible v left join public.organizations o on o.id=v.organization_id group by v.organization_id,o.legal_name
  ), company_ranked as (
    select *,row_number() over(order by total desc,organization_id) ranking from company_counts
  ), top_companies as (
    select organization_id::text id,name,total,ranking from company_ranked where ranking<=5
    union all select null,'Outras',sum(total),6 from company_ranked where ranking>5 having count(*)>0
  ), statuses as (select status,count(*) total from visible group by status),
  types as (
    select coalesce(nullif(standard,''),'Não informado') name,count(distinct id) total from
      (select v.id,unnest(case when cardinality(v.standards)=0 then array['Não informado'] else v.standards end) standard from visible v) t
    group by coalesce(nullif(standard,''),'Não informado')
  ), reports as (
    select r.* from public.daily_reports r join visible v on v.id=r.audit_id
    where private.workspace_document_access(r.id,'daily',r.audit_id,r.finalized_at is not null)
      and (selection<>'period' or ((date_from is null or (r.generated_at at time zone v.timezone)::date>=date_from)
      and (date_to is null or (r.generated_at at time zone v.timezone)::date<=date_to)))
  ), rows_page as (
    select v.id,v.code,v.title,v.organization_id,v.start_date,v.end_date,v.status,
      (v.end_date<(current_timestamp at time zone v.timezone)::date and v.status in ('planned','in_progress','awaiting_signoff')) overdue
    from visible v order by v.start_date desc nulls last,v.id limit page_size offset page_offset
  )
  select jsonb_build_object(
    'metric_version','PORTFOLIO-1','selection',selection,'audit_date_basis','start_date','report_date_basis','generated_at_in_audit_timezone',
    'date_from',date_from,'date_to',date_to,'calculated_at',current_timestamp,
    'audits_total',(select count(*) from visible),'organizations_total',(select count(*) from company_counts),
    'overdue',(select count(*) from visible where end_date<(current_timestamp at time zone timezone)::date and status in ('planned','in_progress','awaiting_signoff')),
    'by_status',coalesce((select jsonb_object_agg(status,total) from statuses),'{}'::jsonb),
    'by_type',coalesce((select jsonb_agg(to_jsonb(t) order by total desc,name) from types t),'[]'::jsonb),
    'by_organization_top',coalesce((select jsonb_agg(to_jsonb(t)-'ranking' order by ranking) from top_companies t),'[]'::jsonb),
    'reports_pending_validation',(select count(*) from reports r join visible v on v.id=r.audit_id
      where r.status='review' and (public.is_platform_admin() or exists(select 1 from public.organization_memberships m where m.id=v.leader_membership_id and m.user_id=auth.uid()))),
    'reports_available',(select count(*) from reports where status in ('completed','pending_acknowledgements') and finalized_at is not null),
    'reports_definition','legacy_daily_logical_documents; not PDF readiness',
    'page',jsonb_build_object('limit',page_size,'offset',page_offset,'rows',coalesce((select jsonb_agg(to_jsonb(p) order by start_date desc nulls last,id) from rows_page p),'[]'::jsonb))
  ) into answer;
  return answer;
end $$;

create or replace function public.audit_portfolio_metrics(
 date_from date default null,date_to date default null,selection text default 'period',page_size integer default 25,page_offset integer default 0
) returns jsonb language sql stable security invoker set search_path='' as $$
 select private.b03_portfolio_metrics(date_from,date_to,selection,page_size,page_offset);
$$;

revoke all on function private.b03_portfolio_metrics(date,date,text,integer,integer) from public,anon;

grant execute on function private.b03_portfolio_metrics(date,date,text,integer,integer) to authenticated;

revoke all on function public.audit_portfolio_metrics(date,date,text,integer,integer) from public,anon;

grant execute on function public.audit_portfolio_metrics(date,date,text,integer,integer) to authenticated;

comment on function public.audit_portfolio_metrics(date,date,text,integer,integer) is 'B03 PORTFOLIO-1: escopo B02 antes de agregação; múltiplas normas contam a auditoria em cada norma; total global distinto. Não recalcula relatórios antigos.';

commit;
