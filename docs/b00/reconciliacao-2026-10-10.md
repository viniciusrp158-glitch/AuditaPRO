# B00 — Reconciliação da baseline (Claude C0)

**Data:** 10/10/2026, ~13h20 (America/Sao_Paulo). **Responsável:** Claude (C0). **Branch:** `integracao/b00-baseline`.
**Natureza:** somente leitura do banco e do GitHub; nenhuma escrita no Supabase, nenhuma publicação.

B00 foi informado como concluído pelo proprietário; o `baseline.md` original não foi localizado. Este documento renova a conciliação na troca de coordenação (Codex → Claude), sem reabrir o bloco.

## 1. Status dos blocos informado pelo proprietário (10/10/2026)

| Bloco | Status |
|---|---|
| B00–B03 | Desenvolvido e implementado |
| B04 | Iniciado, com pendências |
| B05–B15 | Não iniciado |

As branches `feat/b06-identificacao-fpa`, `feat/b07-preparacao` e `feat/b08-preparacao` contêm rascunhos do Codex (código parcial B06; documentação B07/B08). Seguindo o status acima, são **material de referência**, não entregas: serão revisados e reaproveitados quando seus blocos começarem, sem integração automática.

## 2. Git

| Referência | Commit | Observação |
|---|---|---|
| `main` | `0f82ba2` | Importação inicial (06/10). Não representa o banco. |
| `feat/checklists-v01` | `bee387f` | Checklist versionado + CORS do deploy de validação |
| `feat/b04-preparacao` | `566b569` | **Commit-base desta integração** (B04 em andamento) |
| `feat/b06-identificacao-fpa` | `cf7fa1f` | Rascunho (referência) |
| `feat/b07-preparacao` | `20f0dec` | Rascunho (referência) |
| `feat/b08-preparacao` | `85ff485` | Rascunho (referência) |

Histórico linear: `0f82ba2 → c38889b → 914d3be → bee387f → 72c1e2f → 566b569 → cf7fa1f → 20f0dec → 85ff485`.

## 3. Supabase

Organização `rgoxlbcmppivjidrsjot`, acessada pelo conector Supabase desta sessão.

| Projeto | Ref | Região | Papel |
|---|---|---|---|
| AuditaPRO | `zlckcpeqcxmtrgbdquee` | us-east-1, PG 17.6.1.084, ACTIVE_HEALTHY | **Banco do Audita PRO (e futuro AUDITA HUB)** |
| audita-dev | `avfqgxckcclzktrojynj` | sa-east-1, PG 17.11 | Sistema AUDITA de Operação (schema `audita`, 13 migrations i1–i8), em desenvolvimento por outra sessão. **Fora do escopo: não alterar.** |

### 3.1 Migrations — 61 no banco, 61 no repositório

- Nenhuma migration nova desde a inspeção do Codex (09/10, 23h17–23h22); última: `20261009151754_b04_checklist_list_alias_fix`.
- As **52** migrations já versionadas foram comparadas com `supabase_migrations.schema_migrations.statements` (normalizando espaços e comentários): **52/52 idênticas**.
- As **9** ausentes do GitHub foram recuperadas do próprio banco, com md5 conferido, e gravadas com cabeçalho "JÁ APLICADA — NÃO reaplicar":

  - `20261008023047_b02_authorization_core`
  - `20261008023610_b02_access_adapters`
  - `20261008023812_b02_rls_storage`
  - `20261008024101_b02_profile_guards`
  - `20261008110344_b03_stable_identities`
  - `20261008110345_b03_temporal_metrics`
  - `20261008110929_b03_portfolio_metrics`
  - `20261008191655_b02_reassign_cmd1_guard`
  - `20261009151754_b04_checklist_list_alias_fix`

### 3.2 Edge Functions

| Função | Versão | verify_jwt | Repositório |
|---|---|---|---|
| user-management | v11 | sim | Equivalente ao arquivo versionado (inclui origem `audita-pro-validacao…chatgpt.site`) |
| audit-evidence | v4 | sim | Equivalente ao arquivo versionado |
| audit-document-download | v1 | não (valida o token em código) | **Recuperada nesta branch** (CRLF normalizado para LF) |

Comparação por marcadores de código e tamanho, não byte a byte (o conector não fornece o pacote exato).

## 4. Frontend e hospedagem

- Frontend estático em `outputs/` (HTML/CSS/JS), cliente Supabase em `audita-pro-auth.js` apontando para `zlckcpeqcxmtrgbdquee`.
- Deploy de validação anterior: `https://audita-pro-validacao.vinicius-eloisa2.chatgpt.site` (hospedado pela ferramenta anterior; C0 não publica ali).
- **Destino definido pelo proprietário: `auditapro.app.br`.** O domínio responde, mas bloqueia leitura automatizada (robots), então o provedor não foi identificado. Antes da primeira publicação será preciso: (a) definir provedor e procedimento de publicação; (b) acrescentar a origem a `AUDITA_PRO_ALLOWED_ORIGINS` (user-management); (c) ajustar Site URL e Redirect URLs do Supabase Auth (convites e recuperação de senha).

## 5. Ambiente de testes (sessão Claude)

- Node 22 (o `package.json` pede ≥24); o registro npm está inacessível nesta sessão, logo `happy-dom` não instala.
- Disponíveis offline: Playwright + Chromium (testes em navegador real) e `pdf-lib` (candidata B08).
- `scripts/test-b04-navigation.mjs` passa em `566b569`; os testes com `happy-dom` não rodam aqui sem o npm.

## 6. Pendências de B00 que permanecem

| Item | Situação |
|---|---|
| Família de tabelas PascalCase (`Audit`, `Company`, `User`…) | Herdado do plano; reavaliar no inventário de segurança antes do B05 |
| Advisors de segurança/desempenho | Não reexecutados nesta conciliação |
| Backup/restauração de banco e Storage | Procedimento a preparar antes da primeira migration nova |
| Contas de teste (4 perfis, 2 organizações) | Propor ao proprietário antes da homologação do B04 |

## 7. Reversão

Somente documentação e arquivos de versionamento; nenhuma alteração de banco. Reverter = descartar a branch.
