begin;
create function private.workspace_library(p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not private.is_active_account(auth.uid()) then raise exception 'Sessão ativa necessária'; end if;
 return (with documents as (
  select r.id,r.audit_id,'daily' kind,'Relatório diário — Dia '||d.day_number||' — '||d.audit_date title,r.status,r.generated_at,r.finalized_at from public.daily_reports r join public.audit_days d on d.id=r.audit_day_id
  union all select id,audit_id,'final','Relatório final',status,generated_at,finalized_at from public.audit_final_reports
  union all select id,audit_id,'minutes',case kind when 'opening' then 'Ata de abertura' when 'closing' then 'Ata de encerramento' else 'Ata de reunião' end,status,generated_at,finalized_at from public.audit_minutes
 ), visible as (
  select d.*,a.title audit_title,a.code,o.legal_name company,o.cnpj from documents d join public.audits a on a.id=d.audit_id join public.organizations o on o.id=a.organization_id where a.workspace_version>0 and private.workspace_document_access(d.id,d.kind,a.id,d.finalized_at is not null) and (coalesce(p->>'search','')='' or concat(o.legal_name,' ',o.cnpj,' ',a.code,' ',a.title) ilike '%'||(p->>'search')||'%')
 ) select jsonb_build_object('total',(select count(*) from visible),'items',coalesce((select jsonb_agg(to_jsonb(x)) from(select * from visible order by generated_at desc,id limit 20 offset greatest(0,coalesce((p->>'page')::int,0))*20) x),'[]')));
end $$;
create function public.audit_document_library(payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$ select private.workspace_library(payload); $$;
revoke all on function private.workspace_library(jsonb),public.audit_document_library(jsonb) from public;
grant execute on function private.workspace_library(jsonb),public.audit_document_library(jsonb) to authenticated;
commit;
