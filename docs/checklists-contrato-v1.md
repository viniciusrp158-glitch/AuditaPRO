# Checklists — contrato de integração v1

Atualização: o restante do fluxo de planejamento/checklists foi implementado em
07/10/2026. Abaixo permanece o diagnóstico original; estado atual, testes e limites
de homologação estão em [Validação v2](checklists-validacao-v2.md).

Base: planejamento de checklists v0.1 enviado pelo proprietário do Audita PRO.
Referência do código analisado: `0f82ba2`.
Data: 07/10/2026 UTC.

Estado: primeiro incremento implementado e aplicado em 07/10/2026 ao projeto
Supabase `zlckcpeqcxmtrgbdquee`, após comparação do schema e das 42 migrações
anteriores com o repositório. O banco tinha zero auditorias, modelos e avaliações.
Os testes usam transação com rollback e não deixam auditorias fictícias.
Este contrato registra também o objetivo completo; itens pendentes estão no
relatório `checklists-validacao-v1.md`. Não representa aprovação integral dos
28 critérios de aceitação.

## Decisões comuns a Plano, Checklist, Dashboard e RDA

| Conceito | Contrato |
|---|---|
| Unidade de execução | Pergunta identificada + processo/contexto, dentro da mesma auditoria |
| Avaliação diária | Unidade + dia auditado explícito; gravações mantêm autoria e revisão |
| Resultado | Conforme, Parcialmente Conforme, Não Conforme, Não Aplicável, Não Avaliado |
| Estado | Não iniciado, Em avaliação, Concluído; resultado provisório não conclui |
| Progresso | Unidades concluídas / unidades previstas no escopo vigente |
| N/A | Conta como concluído quando permitido e justificado; não significa conformidade |
| Escopo vazio | Exibir “Sem itens definidos”, sem percentual artificial |
| Requisitos | Contagem separada das perguntas; sem agregação técnica automática |
| Constatações | NC, OBS e OM separadas do resultado e do denominador |
| Complemento | Aprofundamento da pergunta; não aumenta o denominador |
| Documento emitido | Snapshot próprio, imutável; revisão gera outra versão |
| Consolidado final | Último estado por unidade; não somar RDAs |

Auditor de apoio permanece em consulta. Somente o condutor designado grava a
execução. Administrador administra modelos, mas só executa quando for condutor.
Cliente recebe projeções autorizadas pelo servidor, sem notas internas.

## Estruturas a reutilizar

- Identidade: `auth.users`, `user_profiles`, `organization_memberships`, perfis e permissões.
- Escopo empresarial: `organizations`, `organization_units`, `audits`.
- Biblioteca: `audit_types`, `checklist_templates`, `checklist_revisions`,
  `checklist_sections`, `checklist_requirements`.
- Plano: `audit_checklists`, `audit_plan_versions`, `audit_days`,
  `audit_processes`, `schedule_items`, `schedule_requirements`.
- Execução: `requirement_assessments`, `evidence_files`, `nonconformities`, `action_plans`.
- Documentos: relatórios diários/finais, versões, atas e destinatários existentes.

A entidade Pergunta deve ser acrescentada somente após confirmar que não existe
equivalente remoto. O UUID do requisito legado será preservado. Cada item legado
terá uma pergunta inicial vinculada, sem recriar avaliações ou evidências.
Critério/seção/requisito/pergunta devem ter identidades distintas; referência
legível como “4.1” não é identidade global.

## Pontos de integração encontrados

| Consumidor | Mudança necessária |
|---|---|
| `private.workspace_catalog` | Deixar de recriar requisitos ao salvar; várias perguntas por requisito; revisões imutáveis |
| `private.workspace_context` | Biblioteca filtrada e sugestões autorizadas; congelar metadados publicados |
| `private.workspace_command` | Seleção de conjunto, confirmação do condutor, plano por perguntas/contexto |
| `private.workspace_detail` | Separar projeção interna da projeção do cliente; paginar perguntas/histórico |
| `private.workspace_item_states` | Contar pergunta/contexto e considerar conclusão explícita |
| `public.audit_workspace_stats` | Regra versionada comum e contagem separada de requisitos |
| `public.dashboard_admin_summary` | Consumir a mesma regra de progresso |
| `private.workspace_snapshot` | Lista explícita de campos publicáveis, amostragem, constatações e evidências selecionadas |
| `private.workspace_documents` | Exigir avaliações concluídas e NC pertinente no fechamento |
| `private.workspace_evidence` / `audit-evidence` | Idempotência, legendas, vínculos múltiplos e seleção para RDA |
| `audita-pro-audits.js` | Construtor e execução separados; autosave com revisão e tratamento de conflito |

## Conflitos identificados no código local

1. O salvamento de modelo apaga e recria linhas de rascunho e rejeita referências
   repetidas. Isso não atende a várias perguntas estáveis por requisito.
2. A avaliação atual não distingue rascunho de conclusão. Os indicadores usam o
   resultado, enquanto o novo contrato depende também do estado operacional.
3. O painel atual retira N/A do denominador. O novo contrato inclui N/A concluído.
   Documentos anteriores não devem ser recalculados pela nova fórmula.
4. A seleção visual atual exige um modelo/tipo principal. A composição precisa
   fixar revisões de base e herdar a restrição de cliente mais restritiva.
5. `workspace_detail` serializa avaliações completas para participantes.
   `workspace_snapshot` serializa `ra.*`. Há risco de incluir notas internas em
   respostas e documentos; conferir as definições efetivas e aplicar projeções
   explícitas antes de introduzir novos campos confidenciais.
6. O fechamento permite justificar resultado Não Conforme sem NC. O novo contrato
   exige NC vinculada; justificativa técnica é alternativa apenas para Parcialmente
   Conforme, conforme a metodologia adotada.
7. Migrações anteriores alteram funções por substituição textual. Conferir a
   definição final remota antes de substituir funções ou acrescentar wrappers.

Esses achados são da leitura do repositório; não demonstram exploração de acesso
nem confirmam o conteúdo atualmente instalado no Supabase.

## Transição e execução em incrementos

1. Inventariar schema real, migrações, funções, grants, RLS, buckets e contagens
   agregadas. Comparar com o Git. Não coletar textos de clientes ou credenciais.
2. Acrescentar perguntas e mapeamento legado de modo aditivo. Validar contagens,
   vínculos e preservação de IDs. Não converter `improvement` automaticamente.
3. Implementar biblioteca/construtor e publicação com identidades estáveis,
   revisões, metadados congelados e composição não recursiva.
4. Implementar seleção confirmada e escopo por pergunta/contexto, com compatibilidade
   explícita dos planos existentes e validação de exclusividade por organização.
5. Implementar avaliação com revisão otimista, patch de campos, amostragem,
   conclusão explícita, autosave serializado e conflitos recuperáveis.
6. Integrar evidências idempotentes, NC existente, OBS/OM, complementos e notas
   internas segregadas no servidor.
7. Integrar regra de indicadores e snapshots versionados em Plano, Dashboard e RDA.
8. Validar CHK-01 a CHK-28 e regressão; só então ativar para auditorias reais.

Cada incremento terá testes funcionais e negativos pertinentes: duas empresas,
condutor, apoio, cliente, usuário inativo, chamadas diretas, revisão concorrente,
falha/repetição de upload, dia fechado e preservação de documentos antigos.

## Conexão e aplicação verificadas

A conexão AUDITAPRO foi validada. Foram aplicadas cinco migrações aditivas de
checklists e publicada a versão 2 da função `audit-evidence`. As estruturas
centrais existentes foram reutilizadas. Não foram usados segredos administrativos
no frontend. Testes de execução, segregação de acesso, revisão e snapshot passaram;
a homologação visual com login real e os cenários restantes continuam pendentes.
