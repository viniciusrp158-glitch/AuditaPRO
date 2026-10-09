# B07 — Preparação para implementação pelo Codex 01

Data: 09/10/2026. Responsável: Codex 03 com subagentes GPT-5.6 Sol em esforço leve e revisão final do agente principal.
Base: `cf7fa1fbb6d34379bfecf045b18889495f9bb578` (entrega parcial B06). Branch: `feat/b07-preparacao`.
**Status: preparação documental; nenhuma funcionalidade B07 implementada ou homologada.**

## Objetivo

Evoluir o cronograma para edição por linha e múltiplos auditores; cópia/reordenação segura; validação de horários/período; continuidade de trabalho parcial, antecipado, não realizado e transferido, preservando todas as referências históricas.

## Dependência que ainda permanece

B07 depende de B06. Pelo status do usuário, B06 tem preparação concluída, mas implementação ainda pendente. Logo, esta entrega pode ser revisada agora; a implementação integrada precisa dos contratos efetivos de período, local/unidade, equipe e critérios de B06. Não considerar a presença da branch B06 como evidência de conclusão desse bloco.

B04 tem pendências e B05 está em implementação pelo Codex 01. Não alterar os arquivos reservados por essas frentes; o ponto de conflito mais provável de B06/B07 é `outputs/audita-pro-audits.js`.

## Conteúdo e ordem de leitura

1. [Diagnóstico](diagnostico.md): estruturas e operações existentes, lacunas e riscos de regressão.
2. [Contratos propostos](contratos-propostos.md): modelo mínimo, operações, concorrência, datas, continuidade e integração com RDA.
3. [Critérios e testes](criterios-e-testes.md): critérios originais e cenários para implementação/homologação.
4. [Rastreabilidade](rastreabilidade.csv): 71 linhas B07 com as 16 colunas originais preservadas e status sem aprovação fictícia.

Nenhum arquivo de produto, dependência, migration, Edge Function ou policy foi alterado. Não existe SQL pronto para aplicar nem interface B07 entregue neste pacote. A entrega é a especificação de implementação solicitada pelo usuário, não código com persistência simulada.

## Evidência de inspeção

Código local e fontes do plano mestre foram lidos. Consulta ao projeto Supabase `zlckcpeqcxmtrgbdquee` limitou-se a metadados: colunas de cronograma/dias/versões/presença, assinaturas de funções e políticas. Não foram consultados dados pessoais nem executadas gravações.

No catálogo observado, `schedule_items` possui um `assignee_membership_id`, horários previstos/reais e retirada; não foram encontrados campos de local por linha ou ordem visual nessa tabela. Há `schedule_movements`, `audit_plan_versions`, `audit_days.opening_plan_version`, `audit_day_attendance`, `schedule_requirements` e `schedule_question_scope`. A proposta deve estender essa base, não recriar o domínio.

Existem contratos B02/B03 no banco que não estão integralmente versionados nesta base. A leitura de assinaturas/políticas não comprova o comportamento completo de funções nem sua segurança ponta a ponta. Codex 01 deve inspecionar as definições e a combinação de políticas permissivas/restritivas na baseline atual antes de implementar.

## Plano de validação e estado real

Nesta preparação foram verificadas as 71 linhas e 16 colunas originais da matriz, a transcrição integral dos dez critérios, os links dos documentos e o diff restrito a docs/b07. Houve revisão independente dos contratos e da entrega; a disponibilidade do registro D09 foi esclarecida após essa revisão. Não há testes funcionais B07 executados: o editor, RPCs, permissões, snapshots e continuidade ainda precisam de implementação e testes reais.

Foram preparados 25 cenários de teste. Há divergência de atribuição de PA-18: o plano mestre o inclui no intervalo B07, mas a matriz o atribui a B09/B11. O cenário foi preservado para verificação conjunta, sem alterar a matriz original.

Não reaproveitar os sete scripts aprovados na entrega B06 como prova de B07. O pacote herdado pode conter código/testes de B06; somente `docs/b07/` integra o novo diff.

## Instruções ao Codex 01

1. Usar esta documentação junto do plano mestre e das decisões B01. Incorporar apenas o incremento `docs/b07/`; não substituir o sistema pelo checkout antigo.
2. Finalizar os contratos B06 necessários e conferir D04/D06/D09, sem inventar novas permissões para apoio ou Participante.
3. Reutilizar estruturas e indicadores B03, implementando por incrementos descritos em `contratos-propostos.md`.
4. Preservar identidades, documentos emitidos, plano original, plano vigente ao abrir cada dia, histórico de transferências e execução já realizada.
5. Revisar proposta de schema antes de gerar migrations oficiais. Aplicação no banco compartilhado permanece coordenada por Codex 01, conforme comando comum do plano.
6. Executar testes funcionais e de autorização negativa em ambiente isolado, incluindo duas sessões concorrentes, retentativa, transferências repetidas e mudança de permissões.
7. Registrar commit, migrations, critérios atendidos, evidências, pendências e URL para homologação. Não marcar B07 concluído pela entrega destes documentos.

Reversão da preparação: reverter o commit documental. A futura reversão funcional deve manter snapshots e movimentos persistidos; não excluir histórico para restaurar a interface antiga.
