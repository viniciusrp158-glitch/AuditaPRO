# Audita PRO — Desenho técnico inicial do MVP

**Versão:** 0.1 — base para planejamento da implementação  
**Data:** 5 de outubro de 2026  
**Relacionado a:** [Escopo técnico do MVP](audita-pro-escopo-mvp.md)

Este documento converte o escopo em arquitetura inicial, modelo de dados, fronteiras de segurança e plano de entrega. As definições pendentes sobre fluxo GOV, tipo de identificação e início da retenção permanecem parametrizadas e não bloqueiam o planejamento dos demais módulos.

## 1. Arquitetura proposta

Aplicação web responsiva com Supabase como plataforma de identidade, banco de dados e armazenamento privado. A interface nunca recebe a chave de serviço privilegiada; operações administrativas passam por funções de servidor.

**Fluxo técnico:** Usuário → Aplicação web → Supabase Auth para identidade; Postgres/RLS para dados e autorização; Storage privado para documentos. Funções de servidor atendem geração de PDF, e-mail e tarefas agendadas. GOV permanece fora da aplicação; o usuário anexa o PDF assinado.

### Componentes

- **Web:** interface em português, acessível por computador, tablet e celular; online-first.
- **Supabase Auth:** identidade e sessão do usuário.
- **PostgreSQL:** dados operacionais, políticas RLS, integridade referencial e trilha de eventos.
- **Supabase Storage:** buckets privados para identificação, evidências, documentos de relatório e PDFs assinados externamente.
- **Funções de servidor:** geração de PDF, envio de e-mails, rotinas programadas, geração de links de download autorizados e operações privilegiadas.
- **E-mail transacional:** avisos e lembretes; fornecedor escolhido durante implementação.
- **Assinatura GOV:** processo externo. O MVP não automatiza o GOV nem captura credenciais do usuário.

## 2. Módulos da aplicação

1. **Acesso e onboarding:** criação de conta, autenticação, envio do documento de identificação e estado de aprovação.
2. **Empresas:** diretório global do Administrador, busca por nome/CNPJ, cadastro, unidades, usuários e histórico de auditorias.
3. **Pessoas e permissões:** usuários, cargos, perfis-base, permissões personalizadas e aprovação de identificação.
4. **Modelos de auditoria:** checklists e revisões mantidos pelo Administrador.
5. **Auditorias:** planejamento, equipe, participantes, signatários e cronograma diário.
6. **Execução:** avaliações de requisitos, evidências, não conformidades, observações e planos de ação.
7. **Relatório diário:** consolidação, edição do Auditor Líder, versão congelada, ciência e upload do PDF GOV assinado.
8. **Biblioteca:** relatórios concluídos, filtros, visualização, exportação e trilha do ciclo de vida.
9. **Administração e rastreabilidade:** log de eventos, notificações pendentes e configurações.

## 3. Modelo de dados inicial

As tabelas abaixo são entidades lógicas. Nomes e colunas finais podem mudar na implementação, preservando os relacionamentos e regras.

### 3.1 Empresas, usuários e autorização

| Tabela | Campos principais | Uso |
|---|---|---|
| organizations | id, legal_name, cnpj, status, created_at | Empresa auditada |
| organization_units | id, organization_id, name, location, status | Unidades da empresa |
| user_profiles | user_id (Auth), full_name, cpf, email, phone, status | Dados comuns do perfil |
| organization_memberships | id, organization_id, unit_id, user_id, position_id, status | Vínculo do usuário com empresa/unidade |
| positions | id, name, scope, status | Cargo/qualificação configurável |
| access_permissions | id, key, description, module | Catálogo de permissões granulares |
| access_profiles | id, name, scope, is_system | Perfis-base: Auditor, Gestor, Consulta, Personalizado |
| access_profile_permissions | profile_id, permission_id, allowed | Permissões de cada perfil |
| membership_permissions | membership_id, permission_id, allowed | Sobrescritas individuais |
| user_documents | id, membership_id, document_type, storage_path, status, reviewed_by, reviewed_at, review_note | Documento de identificação e validação |

O estado de aprovação é específico do vínculo com a empresa e das exigências do cargo. No MVP, Auditor Líder, Auditor e Cliente enviam documento de identificação obrigatório.

### 3.2 Checklists e execução

| Tabela | Campos principais | Uso |
|---|---|---|
| checklist_templates | id, name, owner_org_id, status | Modelo configurável |
| checklist_revisions | id, template_id, revision, created_by, created_at | Histórico imutável de revisões |
| checklist_sections | id, revision_id, title, sort_order | Cláusula/seção |
| checklist_requirements | id, section_id, reference, prompt, guidance, sort_order | Requisito fornecido pelo responsável do Audita PRO |
| audits | id, organization_id, unit_id, code, title, scope, start_date, end_date, status, leader_membership_id | Auditoria |
| audit_checklists | id, audit_id, revision_id, copied_at | Revisão de checklist fixada à auditoria |
| audit_days | id, audit_id, day_number, audit_date, started_at, ended_at, status | Dia auditado |
| audit_participants | id, audit_id, membership_id, participant_type, is_signatory, active | Equipe/participantes e escolha de signatários |
| audit_processes | id, audit_id, name, sort_order | Processos/áreas auditados |
| schedule_items | id, audit_day_id, process_id, requirement_id, title, planned_start, planned_end, assignee_id, status, origin_day_id, moved_at, moved_by, move_reason | Etapa prevista e transferência rastreável |
| requirement_assessments | id, audit_id, audit_day_id, requirement_id, result, notes, created_by, updated_at | Resultado do requisito |
| evidence_files | id, audit_id, assessment_id, nonconformity_id, storage_path, description, uploaded_by, created_at | Metadados de evidências privadas |
| nonconformities | id, audit_id, audit_day_id, requirement_id, process_id, code, description, classification, status, created_by | Não conformidade |
| action_plans | id, nonconformity_id, action_text, responsible_name, due_date, status, created_by | Ação, responsável e prazo |

O modelo de checklist é versionado. A revisão escolhida fica fixada à auditoria; alterações futuras do modelo não reescrevem auditorias em andamento ou encerradas.

### 3.3 Relatórios e rastreabilidade

| Tabela | Campos principais | Uso |
|---|---|---|
| daily_reports | id, audit_day_id, status, current_version_id, created_by, finalized_at, archived_at | Contêiner do relatório |
| daily_report_versions | id, report_id, version_number, content_json, pdf_path, content_hash, created_by, created_at, finalized_at | Conteúdo congelado e PDF de uma versão |
| report_acknowledgements | id, version_id, membership_id, acknowledged_at, auth_user_id, client_context | Confirmação de ciência; não é assinatura legal |
| report_external_files | id, version_id, file_type, storage_path, uploaded_by, uploaded_at, note | Cópia assinada via GOV e possível comprovante |
| audit_events | id, organization_id, audit_id, actor_user_id, event_type, entity_type, entity_id, occurred_at, metadata | Histórico append-only |
| notification_outbox | id, recipient_user_id, event_type, payload, scheduled_at, sent_at, status, attempts | E-mails e lembretes com tentativas e deduplicação |

content_json guarda a cópia consolidada do relatório para uma versão. O PDF é produzido a partir dessa versão; o hash ajuda a detectar substituição acidental, sem ser apresentado como prova jurídica. Correções geram nova versão com relação à anterior e justificativa.

## 4. Regras de acesso no Supabase

### Princípios

- Ativar RLS em todas as tabelas expostas à aplicação.
- Não confiar em permissões vindas de metadados que o próprio usuário pode editar.
- Atribuir Administrador global por processo administrativo protegido, nunca por autoinscrição.
- Verificar autorização para cada leitura, escrita, upload e download.
- A chave de serviço privilegiada só pode ser usada em função/servidor protegido, nunca no navegador.
- Políticas devem considerar vínculo ativo, empresa/unidade, participação na auditoria e permissão específica.

### Matriz inicial

| Recurso | Administrador plataforma | Auditor Líder | Auditor | Cliente |
|---|---|---|---|---|
| Empresas e histórico | Todas | Auditorias autorizadas | Auditorias atribuídas | Auditorias em que participa |
| Usuários e documentos | Todas; valida documentos | Participantes da auditoria, conforme necessidade | Equipe atribuída | Próprio perfil/documento |
| Planejamento | Todas | Criar/editar auditoria atribuída | Consultar plano atribuído | Somente leitura |
| Execução e evidências | Todas | Gerenciar conforme permissão | Criar/editar conforme atribuição | Somente leitura |
| Não conformidades e ações | Todas | Gerenciar conforme permissão | Registrar/atualizar conforme permissão | Somente leitura |
| Relatório em rascunho | Todas | Editar | Leitura se autorizado | Leitura se autorizado |
| Finalização e signatários | Administração | Finalizar e escolher signatários | Sem finalizar, salvo concessão explícita | Sem edição |
| Confirmação de ciência | Ver estado | Ver estado | Se selecionado | Se selecionado |
| Arquivo GOV | Administração | Anexar/consultar conforme permissão | Leitura se autorizado | Leitura se autorizado |

A autorização efetiva combina perfil, sobrescritas individuais, vínculo, atribuição à auditoria e estado do recurso. O cliente permanece somente leitura.

### Arquivos privados

Buckets separados, ou prefixos com políticas equivalentes, para:

- identity-documents: acesso ao próprio usuário e administradores autorizados.
- audit-evidence: leitura apenas a pessoas autorizadas na auditoria.
- audit-reports: PDFs gerados e cópias assinadas via GOV, conforme participação/permissão.

Caminhos não devem incluir dados pessoais previsíveis. Downloads exigem autorização autenticada e URLs temporárias. Nome de arquivo original não é caminho confiável.

## 5. Ciclos de vida

### 5.1 Aprovação do usuário

conta criada → cadastro mínimo → documento enviado → pendente de análise → aprovado ou recusado → acesso habilitado conforme permissões

A conta pode acessar onboarding para enviar/ver o estado do documento. Até aprovação, não acessa módulos protegidos nos cargos sujeitos à regra.

### 5.2 Auditoria e cronograma

rascunho → planejada → em andamento → aguardando confirmações/arquivo GOV → concluída

- Etapas têm estados: planned, in_progress, completed, not_done.
- Transferir atualiza o dia de destino e mantém dia de origem, motivo e autor; o relatório original registra a transferência.
- Auditoria concluída não é apagada; reabertura exige permissão, motivo e evento de log.

### 5.3 Relatório diário

draft → finalized → awaiting_acknowledgements → awaiting_gov_file → archived

1. Gerar relatório com dados do dia.
2. Auditor Líder complementa e edita o rascunho.
3. Finalizar congela conteúdo e PDF; edição direta é bloqueada.
4. Signatários selecionados confirmam ciência da versão congelada.
5. PDF é assinado via GOV fora da aplicação; arquivo e eventual comprovante são anexados.
6. Administrador/Auditor Líder valida presença do arquivo segundo procedimento operacional; o sistema registra upload e arquiva.
7. Correção posterior produz nova versão; não substitui conteúdo ou arquivo anterior.

A validação automática da autenticidade da assinatura GOV não está incluída sem integração/serviço definido. A plataforma registra o arquivo anexado e não afirma que verificou sua validade criptográfica.

## 6. Notificações e tarefas programadas

Eventos que podem gerar aviso:

- Documento de identificação enviado, aprovado ou recusado.
- Auditoria atribuída ou atualizada.
- Relatório finalizado aguardando ciência.
- Lembretes de ciência após 24 e 48 horas, se ainda pendente.
- Relatório pronto para anexar cópia GOV.
- Relatório arquivado.

Usar fila/outbox para tentativas quando e-mail estiver indisponível; registrar falhas. Lembretes devem ser idempotentes, parar após confirmação e não alterar histórico.

## 7. Estratégia para relatórios e versões

- Campos automáticos e textos editáveis ficam separados em content_json, por exemplo header, schedule_summary, processes, requirements, findings, observations, action_plans e leader_notes.
- Cada geração mantém referências aos registros de origem e horário da consolidação.
- Edição antes da finalização atualiza rascunho com histórico.
- Finalizar cria versão imutável, PDF e hash do conteúdo.
- Confirmação de ciência aponta para version_id, não apenas para o relatório contêiner.
- Mudanças após finalizar exigem nova versão e novas confirmações/GOV.
- Relatório inclui planejado vs realizado, itens transferidos e itens trazidos do dia anterior.

## 8. Segurança, privacidade e retenção

- Coletar apenas os dados pessoais necessários e limitar sua visibilidade.
- E-mails e logs não podem conter conteúdo de documentos nem credenciais.
- Consultas/exportações de dados pessoais pelo Administrador global geram evento de auditoria.
- Planejar retenção de cinco anos; a data inicial será configurada quando definida.
- Descarte ao fim do prazo remove arquivos e metadados conforme política; trilha mínima e obrigações legais precisam de decisão própria.
- Antes do piloto: revisar política de privacidade, termos, papéis de controlador/operador, contratos de processamento, resposta a incidente e rotina de backup/restauração.
- Definir limites de upload, tipos aceitos e verificação contra arquivos maliciosos na implementação.

## 9. Plano de implementação por entregas

### Entrega 0 — Fundação

- Criar projetos Supabase para desenvolvimento e ambientes separados.
- Definir esquema, migrations, autenticação e RLS.
- Montar estrutura web, navegação e tratamento de erros.
- Criar buckets privados e fluxo de upload autorizado.

**Saída:** login funcional e fundação de segurança revisável.

### Entrega 1 — Empresas, pessoas e permissões

- Diretório global de empresas com nome/CNPJ, busca e detalhe.
- Unidades, usuários, cargos e perfis.
- Onboarding e upload de identificação por usuário.
- Revisão administrativa e bloqueio/liberação de acesso.

**Saída:** Administrador prepara participantes antes da auditoria.

### Entrega 2 — Planejamento e execução

- Modelos e revisões de checklist.
- Criação de auditoria, equipe, participantes e signatários.
- Cronograma por vários dias e transferência de etapa.
- Avaliação de requisitos, evidências, não conformidades e planos de ação.
- Registro da trilha de atividades.

**Saída:** auditoria piloto pode ser executada na aplicação.

### Entrega 3 — Relatórios e ciclo GOV

- Relatório diário gerado por registros do dia.
- Revisão e edição pelo Auditor Líder.
- Congelamento/versionamento, PDF e confirmação de ciência.
- Download para assinatura externa e upload da cópia assinada.
- Biblioteca, busca, notificações e linha do tempo.

**Saída:** fluxo de auditoria piloto ponta a ponta, com GOV operado externamente.

### Entrega 4 — Preparação do piloto

- Configurar checklist e dados do piloto.
- Rever segurança, permissões e cópias de segurança.
- Treinar usuários piloto e acompanhar primeira auditoria.
- Priorizar ajustes a partir do uso real.

**Saída:** MVP pronto para uso controlado em auditoria piloto.

## 10. Decisões a manter parametrizadas

Estas questões foram adiadas e não devem ser presumidas como decisão final:

1. Processo GOV: proposta manual baixar/assinar/anexar; confirmar fluxo e comprovante.
2. Identificação: documento aceito, formatos e tamanho máximo.
3. Retenção: evento inicial dos cinco anos, exclusões legais e descarte.
4. Região/plano/custo Supabase e serviço de e-mail.
5. Se Gestor é função interna do Audita PRO ou permissões dadas a membros da equipe; Cliente permanece leitura.
6. Nomes e regras finais de cargos, permissões e classificações de achados.

## 11. Próxima etapa após este desenho

O backlog priorizado e a primeira migração de fundação Supabase foram preparados em documentos próprios: audita-pro-backlog-mvp.md e audita-pro-supabase-foundation.sql. A migração ainda não foi aplicada a um projeto Supabase. A próxima ação operacional é criar o projeto Supabase de desenvolvimento, revisar/aplicar a migração e conferir isolamento RLS e acesso aos arquivos antes de inserir dados reais. Os protótipos atuais servem como referência visual; este desenho define dados e comportamento.
