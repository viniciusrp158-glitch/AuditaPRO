-- Inspeção prévia à transição de checklists. Não é uma migration.
-- Executar no projeto confirmado pelo responsável, usando acesso autorizado.
-- Somente metadados, definições e contagens: sem textos de auditoria ou dados pessoais.
begin transaction isolation level repeatable read read only;
set local statement_timeout = '30s';

select current_database() as database_name, current_user as inspection_role,
       current_setting('server_version') as postgres_version;

select version, name
from supabase_migrations.schema_migrations
order by version;

select n.nspname as schema_name, c.relname as table_name,
       c.relrowsecurity as rls_enabled, c.relforcerowsecurity as rls_forced
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
where n.nspname in ('public', 'private', 'storage') and c.relkind in ('r','p')
order by 1,2;

select table_schema, table_name, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema in ('public','private')
order by table_schema, table_name, ordinal_position;

select n.nspname as schema_name, c.relname as table_name,
       con.conname, pg_get_constraintdef(con.oid) as definition
from pg_catalog.pg_constraint con
join pg_catalog.pg_class c on c.oid=con.conrelid
join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','private')
order by 1,2,3;

select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_catalog.pg_policies
where schemaname in ('public','private','storage')
order by schemaname,tablename,policyname;

select table_schema,table_name,grantee,privilege_type
from information_schema.table_privileges
where table_schema in ('public','private','storage')
order by 1,2,3,4;

select n.nspname as schema_name,p.proname,
       pg_get_function_identity_arguments(p.oid) as arguments,
       p.prosecdef as security_definer,p.proconfig,p.proacl,
       pg_get_functiondef(p.oid) as definition
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','private') and p.prokind='f'
  and (p.proname like '%workspace%' or p.proname like '%checklist%'
       or p.proname like '%assessment%' or p.proname like '%report%'
       or p.proname like '%permission%' or p.proname like '%participant%'
       or p.proname like '%evidence%' or p.proname like '%findings%'
       or p.proname in ('dashboard_admin_summary','is_platform_admin','profile_admin'))
order by 1,2,3;

select n.nspname as schema_name,c.relname as table_name,
       t.tgname,pg_get_triggerdef(t.oid) as definition
from pg_catalog.pg_trigger t
join pg_catalog.pg_class c on c.oid=t.tgrelid
join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where not t.tgisinternal and n.nspname in ('public','private')
order by 1,2,3;

select schemaname,tablename,indexname,indexdef
from pg_catalog.pg_indexes
where schemaname in ('public','private')
order by 1,2,3;

select id,public,file_size_limit,allowed_mime_types from storage.buckets order by id;

select 'templates' as entity,count(*) from public.checklist_templates
union all select 'revisions',count(*) from public.checklist_revisions
union all select 'sections',count(*) from public.checklist_sections
union all select 'requirements',count(*) from public.checklist_requirements
union all select 'audit_checklists',count(*) from public.audit_checklists
union all select 'assessments',count(*) from public.requirement_assessments
union all select 'evidence',count(*) from public.evidence_files
union all select 'daily_report_versions',count(*) from public.daily_report_versions
union all select 'final_report_versions',count(*) from public.audit_final_report_versions;

select workspace_version,status,count(*) from public.audits group by 1,2 order by 1,2;
select result,count(*) from public.requirement_assessments group by 1 order by 1;
select status,count(*) from public.checklist_revisions group by 1 order by 1;

-- Nenhuma correção automática: divergências devem ser investigadas.
select count(*) as assessments_with_mismatched_day
from public.requirement_assessments a join public.audit_days d on d.id=a.audit_day_id
where a.audit_id<>d.audit_id;

select count(*) as evidence_with_mismatched_assessment
from public.evidence_files e join public.requirement_assessments a on a.id=e.assessment_id
where e.audit_id<>a.audit_id;

rollback;
