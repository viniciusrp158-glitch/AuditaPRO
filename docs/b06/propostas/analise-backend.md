# B06 — análise de backend e limites da proposta

Inspeção em modo somente leitura realizada em 09/10/2026 no projeto `zlckcpeqcxmtrgbdquee`. Nenhuma migration, função ou dado foi alterado no ambiente compartilhado.

## Evidência confirmada no ambiente

- PostgreSQL 17.6.
- B02 está presente no banco, embora não esteja no Git desta base: helpers `private.b02_*`, RPC `public.audit_access` e policies restritivas B02 existem.
- B03 está presente no banco, embora não esteja no Git desta base: helpers `private.b03_*` e RPCs `audit_portfolio_metrics`, `audit_temporal_metrics` e `audit_public_schedule_progress` existem.
- `audits` já contém `criterion_ids`, `checklist_contract`, `workspace_version`, identificação básica e `lock_version`.
- `workspace_command('create')` já aceita múltiplos `criterion_ids`; `workspace_detail` já aplica projeções diferentes conforme escopo B02.
- O plano publicado já tem versões imutáveis por `(audit_id, version_number)` e usa `lock_version` no fluxo de planejamento.
- O banco ainda não possui campos explícitos para tipo de avaliação, período declarado, participantes textuais ou comentários do cabeçalho.
- Não foi identificada estrutura de FPA no schema inspecionado.

Essa divergência torna inseguro copiar uma migration local e redefinir funções existentes: isso poderia apagar controles implantados por B02/B03. A proposta usa uma função nova e colunas aditivas.

## Proposta independente

[`identificacao-v1.sql`](./identificacao-v1.sql) define um RPC versionado e opt-in. Ele:

- exige conta ativa e autorização pelo helper existente `workspace_conductor`, sem criar regra nova de papel;
- mantém equipe/permissões fora de `participants_text`;
- valida unidade na organização e critérios ativos;
- bloqueia a linha antes de revalidar autorização e usa `expected_lock_version`;
- limita a gravação ao rascunho ainda não publicado;
- impede trocar critérios quando já existem checklists aplicados ou avaliações vinculadas;
- registra no evento os valores de identificação anteriores e posteriores;
- revoga execução pública/anônima;
- não altera funções ou policies B02/B03.

O arquivo é uma proposta, não uma migration pronta. Antes de promovê-lo, é necessário reconstruir uma baseline que inclua as migrations B02/B03 e executar testes reais de integração/RLS em banco isolado.

## Decisão que ainda bloqueia a ativação do FPA

A fonte local já propõe o piloto de FPA, seus estados e o bloqueio da validação final, mas continua marcada como documento para validação. Não foi localizado o registro B01/D09 que confirme a decisão sobre o piloto, códigos e tratamento do legado. Até recuperar essa decisão, o backend não deve modificar `plan_publish`, criar FPA fictício para histórico ou incluir conteúdo FPA na projeção empresarial.

Depois da decisão, limites e tipos de arquivo devem ser confirmados contra a implementação e validados no gate C01; isso é uma verificação técnica, não uma nova regra presumida.

## Verificação executada

`git diff --check` passou. Não há Postgres, Docker ou Supabase CLI disponíveis localmente; portanto, a proposta SQL foi revisada manualmente, mas ainda não possui validação de compilação/execução. Ela não deve ser apresentada como teste de banco aprovado e precisa passar pelo gate C01 em ambiente isolado após reconstrução da baseline B02/B03.
