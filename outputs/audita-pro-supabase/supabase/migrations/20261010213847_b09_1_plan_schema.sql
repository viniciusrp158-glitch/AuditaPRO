-- B09 Parte 1: controle das revisões do Plano (validado → publicado → substituído), identidade de atividade substituída,
-- dia planejado retirado e notas institucionais versionadas. Aditiva, sem DELETE (AD-15). Linhas legadas ficam como estão.
alter table public.audit_plan_versions
  add column revision_label text,
  add column state text check (state is null or state in ('validated', 'published', 'superseded', 'discarded')),
  add column emission_id uuid,
  add column content_sha256 text,
  add column template_version int,
  add column operation_id uuid,
  add column published_at timestamptz,
  add column superseded_by uuid references public.audit_plan_versions(id),
  add column discarded_reason text;
comment on column public.audit_plan_versions.state is 'B09: null = versão legada (publicada pelo fluxo anterior, sem PDF persistido)';

alter table public.schedule_items add column replaced_by uuid references public.schedule_items(id);
alter table public.audit_days add column withdrawn boolean not null default false;
comment on column public.schedule_items.replaced_by is 'B09: atividade não iniciada cujo escopo encolheu ganha nova identidade; a antiga fica retirada e aponta a sucessora';
comment on column public.audit_days.withdrawn is 'B09: dia planejado sem atividades na revisão publicada; numerado após os dias ativos e oculto das listas';

-- Revisão B09 é imutável no conteúdo; só avança de estado (validated → published | discarded; published → superseded).
create function private.b09_version_guard() returns trigger language plpgsql set search_path = '' as $$
begin
 if tg_op = 'DELETE' then
  if old.state is not null then raise exception 'Revisões do plano não são excluídas'; end if;
  return old;
 end if;
 if old.state is null then return new; end if;
 if (new.audit_id, new.version_number, new.reason, new.created_by, new.created_at, new.revision_label, new.content_sha256, new.template_version, new.operation_id)
    is distinct from (old.audit_id, old.version_number, old.reason, old.created_by, old.created_at, old.revision_label, old.content_sha256, old.template_version, old.operation_id)
    or new.content::text is distinct from old.content::text then
  raise exception 'Conteúdo da revisão do plano é imutável'; end if;
 if new.state is distinct from old.state and not ((old.state = 'validated' and new.state in ('published', 'discarded')) or (old.state = 'published' and new.state = 'superseded')) then
  raise exception 'Transição de revisão inválida: % → %', old.state, new.state; end if;
 return new;
end;$$;
create trigger audit_plan_versions_b09_guard before update or delete on public.audit_plan_versions
 for each row execute function private.b09_version_guard();
revoke all on function private.b09_version_guard() from public, anon, authenticated;
create unique index audit_plan_versions_operation on public.audit_plan_versions (created_by, operation_id) where operation_id is not null;
create unique index audit_plan_versions_one_open on public.audit_plan_versions (audit_id) where state = 'validated';

-- Anexo A do planejamento do Plano: texto institucional integral (modelo v1). Mudança futura = nova versão, sem alterar PDFs anteriores.
create function private.b09_plan_notes(v int default 1) returns jsonb language sql immutable set search_path = '' as $$
 select case when v = 1 then jsonb_build_array(
  'Plano de Auditoria - Os horários estabelecidos neste plano são previstos e poderão ser ajustados durante a execução da auditoria em razão das condições encontradas, disponibilidade dos envolvidos ou necessidade de aprofundamento das verificações. Quando houver mais de um auditor, a equipe poderá atuar conjuntamente ou distribuir as atividades conforme o planejamento e as necessidades identificadas.',
  'Documentação - A organização deverá disponibilizar à equipe auditora, quando solicitado, os documentos, procedimentos, registros e demais informações necessárias à avaliação dos processos abrangidos pela auditoria, preferencialmente em meio digital e em suas versões vigentes.',
  'Objetivos da Auditoria - Avaliar o atendimento aos critérios estabelecidos para a auditoria, incluindo, quando aplicável, requisitos normativos, legais, regulamentares, contratuais e internos; avaliar a implementação e eficácia dos controles e processos abrangidos; e identificar conformidades, não conformidades e oportunidades de melhoria.',
  'Formulário de Preparação para Auditoria (FPA) - Com o objetivo de proporcionar um planejamento adequado e assegurar que a equipe auditora disponha previamente das informações necessárias para a execução da auditoria, a organização auditada deverá preencher o Formulário de Preparação para Auditoria disponibilizado pela AUDITA e encaminhá-lo dentro do prazo estabelecido. O formulário deverá fornecer informações preliminares sobre a organização, incluindo ramo de atividade, número de colaboradores, unidades e áreas envolvidas, processos e atividades desenvolvidas, escopo pretendido, requisitos aplicáveis e demais informações relevantes para a compreensão do contexto da organização.',
  'Idioma - Salvo acordo prévio em contrário, a auditoria, as comunicações e os relatórios serão realizados em português.',
  'Entrevistas - Sempre que necessário, a equipe auditora poderá entrevistar colaboradores e demais pessoas envolvidas nos processos e atividades abrangidos pelo escopo da auditoria, visando obter evidências e compreender a execução das atividades.',
  'Amostragem - A auditoria é realizada com base em amostragem de informações e evidências disponíveis durante o período de avaliação. Portanto, a ausência de constatações ou não conformidades em determinada área, processo ou atividade não constitui garantia de inexistência de desvios.',
  'Relatórios - As constatações da auditoria serão registradas e disponibilizadas conforme o processo estabelecido pela AUDITA. Quando aplicável, poderão ser emitidos relatórios diários e, ao término da auditoria, relatório final contendo a consolidação dos resultados. Os documentos poderão ser disponibilizados pelo Audita PRO e/ou encaminhados eletronicamente ao cliente.',
  'Confidencialidade - As informações e evidências obtidas pela AUDITA durante o planejamento, execução e acompanhamento da auditoria serão tratadas de forma confidencial e utilizadas exclusivamente para as finalidades relacionadas aos serviços contratados, ressalvadas obrigações legais ou autorizações expressas aplicáveis.')
 end;
$$;
revoke all on function private.b09_plan_notes(int) from public, anon, authenticated;
