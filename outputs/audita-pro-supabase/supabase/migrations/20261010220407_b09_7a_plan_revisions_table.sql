-- B09 Parte 7a (correção do próprio B09): as revisões do Plano passam a ter tabela própria. audit_plan_versions volta ao
-- contrato legado — uma linha por publicação, com a lista de atividades materializadas e version_number = plan_revision —
-- que as métricas do B03, os documentos legados e a projeção do cliente leem. Nenhuma revisão B09 existia em produção.
-- As colunas B09 acrescentadas a audit_plan_versions (parte 1) ficam sem uso (aditivo; nada é removido).
create table private.plan_revisions (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.audits(id),
  revision_number int not null check (revision_number > 0),
  revision_label text not null,
  state text not null check (state in ('validated', 'published', 'superseded', 'discarded')),
  content jsonb not null,
  content_sha256 text not null check (content_sha256 ~ '^[0-9a-f]{64}$'),
  template_version int not null,
  reason text not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  operation_id uuid,
  emission_id uuid references private.document_emissions(id),
  published_at timestamptz,
  superseded_by uuid references private.plan_revisions(id),
  discarded_reason text,
  plan_version_id uuid references public.audit_plan_versions(id),
  unique (audit_id, revision_number)
);
create unique index plan_revisions_one_open on private.plan_revisions (audit_id) where state = 'validated';
create unique index plan_revisions_operation on private.plan_revisions (created_by, operation_id) where operation_id is not null;
alter table private.plan_revisions enable row level security;
revoke all on private.plan_revisions from public, anon, authenticated;

create function private.b09_revision_guard() returns trigger language plpgsql set search_path = '' as $$
begin
 if tg_op = 'DELETE' then raise exception 'Revisões do plano não são excluídas'; end if;
 if (new.audit_id, new.revision_number, new.revision_label, new.content_sha256, new.template_version, new.reason, new.created_by, new.created_at, new.operation_id)
    is distinct from (old.audit_id, old.revision_number, old.revision_label, old.content_sha256, old.template_version, old.reason, old.created_by, old.created_at, old.operation_id)
    or new.content::text is distinct from old.content::text then
  raise exception 'Conteúdo da revisão do plano é imutável'; end if;
 if new.state is distinct from old.state and not ((old.state = 'validated' and new.state in ('published', 'discarded')) or (old.state = 'published' and new.state = 'superseded')) then
  raise exception 'Transição de revisão inválida: % → %', old.state, new.state; end if;
 if old.emission_id is not null and new.emission_id is distinct from old.emission_id then raise exception 'Emissão da revisão é imutável'; end if;
 if old.plan_version_id is not null and new.plan_version_id is distinct from old.plan_version_id then raise exception 'Versão publicada da revisão é imutável'; end if;
 return new;
end;$$;
create trigger plan_revisions_guard before update or delete on private.plan_revisions for each row execute function private.b09_revision_guard();
revoke all on function private.b09_revision_guard() from public, anon, authenticated;
