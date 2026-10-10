# Entrega B06 — Identificação, códigos, critérios integrados e FPA

- **Responsável:** Claude (C0). **Data:** 10/10/2026. **Branch:** `feat/b06-identificacao-fpa-claude` (base `bffc63e`).
- **Decisões:** D06 (apoio sem escrita), D09 (FPA mínimo por arquivo registrado pelo condutor; legados sem FPA inventado). Material do Codex (`entrega.md`, propostas) preservado nesta pasta.

## Entregue

| Critério | Como | Evidência |
|---|---|---|
| PA-01/02 | Códigos B03 (`CLI-n`, `AUD-AAAA-n`) atribuídos pelo servidor; `create_draft` idempotente por `operation_id` | SQL 46/46 |
| PA-03 | `audit_identification('detail')` traz código, CNPJ e endereço do cliente; a tela exibe sem redigitação | SQL + UI |
| PA-04 | `create_draft` (só cliente obrigatório); identificação salva incompleta com itens "Pendente" visíveis (validação final é B09) | SQL + UI |
| PA-05 | Período declarado, natureza, tipo de avaliação (+ "Outra"), outros participantes e comentários com orientação N/A em itálico persistente | SQL + UI |
| PA-06 | Vários critérios com edição própria (`criterion_ids`/`standards`); bloqueio de troca após aplicação ao checklist | SQL + UI |
| PA-11/12 | FPA: não solicitado → solicitado → recebido → em análise → complementação → suficiente; versão analisada e autoria registradas; nova versão exige nova análise | SQL + UI |
| PA-19, PER-04 | Apoio aparece na equipe, consulta, não edita (inclusive por chamada direta) | SQL + UI |
| PA-20, PER-08 | Outra organização / outro Líder da mesma empresa sem acesso | SQL |
| PA-23 (cabeçalho e FPA) | `expected_lock_version` em identificação e FPA | SQL + UI |
| D04 | Admin não condutor opera com autoria real no histórico | SQL |

## Produção

Migrations `20261010171557_b06_1_identification`, `…171615_b06_2_create_draft`, `…171626_b06_3_fpa_schema`, `…171657_b06_4_fpa_commands` — aplicadas e conferidas (statements idênticos ao repositório).
Edge Function `audit-fpa-files` v1 publicada. Prova na produção (Admin real, transação revertida): `detail`/`capabilities`/FPA `not_requested` ok.

## Testes

`scripts/run-sql-test.sh scripts/test-b06-identification-fpa.sql` 46/46 · `scripts/test-b06-fpa-validation.mjs` 6/6 ·
`scripts/test-b06-plan-workspace-ui.mjs` 25/25 · Codex `test-b06-identificacao.mjs` e `test-b06-fpa-workflow.mjs` ok.

## Pendente / limites

- Validação final do plano (15 verificações, bloqueio por FPA) e congelamento do cabeçalho na revisão: **B09**.
- Upload/download reais de FPA contra o Storage dependem de sessão autenticada no navegador (homologação B14/B15).
- Notificação no sino para solicitação de FPA: não implementada (destinatário normalmente fora do sistema no piloto, D09).

## Reversão

Remover a aba "Identificação e FPA" (`audita-pro-audits.js`) e voltar a criação para `audit_workspace('create')`. Schema aditivo permanece.
