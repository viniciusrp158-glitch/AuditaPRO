# Entrega B04 (Menu e Meu Perfil) + B05 (Biblioteca corporativa)

- **Responsável:** Claude (C0). **Data:** 10/10/2026.
- **Commit-base:** `566b569` (B04 do Codex) via `integracao/b00-baseline` (`5f95da1`). **Branch:** `feat/b04-b05-biblioteca`.
- **Decisões aplicadas:** D05 (Meu Perfil preserva onboarding), D07 = PC-01..PC-08 + V-07.

## O que mudou

**Menu (B04 — CA-01/02/12, PER-20).** Em todas as páginas autenticadas: Dashboard → Auditorias → Usuários → Biblioteca de documentos → Meu Perfil.
"Usuários" aparece só para o Administrador; "Biblioteca de documentos" só quando o servidor confirma acesso (Admin, Auditor Líder, Auditor) — o Participante não a recebe (V-07).
Itens restritos começam ocultos e permanecem ocultos se a consulta de permissão falhar. Menu recolhível, Escape e tela pequena mantidos. Correção CX-01.

**Biblioteca (B05 — CA-03..CA-11, CA-13, PER-19).**
- Página `audita-pro-biblioteca.html`: busca por título/código, filtros por tipo (e situação, para o Admin), paginação, estados distintos de carregando, vazia, sem resultado, erro e sem permissão.
- Admin: Inserir documento (salvo em **Rascunho**), Gerenciar (identificação com controle de concorrência, revisões, arquivos, "Disponibilizar como vigente", cancelar rascunho, arquivar/restaurar, histórico do documento).
- Auditor Líder/Auditor: só a revisão **vigente** de documentos não arquivados; download do formato escolhido.
- Aba "Relatórios de auditorias" (fonte existente `audit_document_library`) e botão "Histórico de modificações do sistema" (Admin), com "Voltar à biblioteca".

**Backend.**
- Tabelas privadas `corporate_documents`, `corporate_document_revisions`, `corporate_document_files`, `corporate_library_operations` (RLS ativa, sem acesso direto).
- `public.corporate_library(command, payload)` → funções privadas; autorização por `private.b02_corporate_access` (B02).
- Regras no servidor: código nunca reutilizado e imutável após emissão; vigente exige arquivo íntegro + responsável + emissão; nova revisão torna a anterior Substituída preservando arquivos; arquivo emitido imutável; sem exclusão de documentos/revisões; idempotência por `operation_id`; eventos em `audit_events`.
- Bucket privado `corporate-library` (PDF/DOCX/DOTX, 20 MB), sem policies públicas.
- Edge Function `corporate-library-files` v1: valida conteúdo real (PDF completo; DOCX/DOTX verdadeiros; recusa macros, DOCM renomeado, ZIP genérico, executáveis), calcula SHA-256, envia ao Storage e só registra após o banco confirmar o objeto; remove objeto órfão em falha; download por URL assinada de 60 s.

## Migrations

| Versão | Nome | Produção |
|---|---|---|
| 20261010165809 | b05_corporate_library_1_schema | aplicada |
| 20261010165914 | b05_corporate_library_2_read | aplicada |
| 20261010170002 | b05_corporate_library_3_manage | aplicada |
| (pendente) | b05_corporate_library_4_lifecycle | **aguarda aprovação no conector** (contém DELETE de arquivo de rascunho) |

Até a parte 4 ser aplicada, upload/remoção/publicação/arquivamento retornam erro; leitura, cadastro e revisões funcionam. O frontend novo ainda não está publicado.

## Testes (resultados reais nesta sessão)

| Teste | Ambiente | Resultado |
|---|---|---|
| `scripts/run-sql-test.sh scripts/test-b05-corporate-library.sql` | Postgres local com as 65 migrations | 42/42 |
| `scripts/test-b05-office-validation.mjs` (tsx) | Node 22, arquivos reais gerados | 11/11 |
| `scripts/test-b05-library-ui.mjs` | Chromium, servidor simulado | 31/31 |
| `scripts/test-b04-menu-profiles.mjs` | Chromium, 4 perfis × 9 páginas + celular | 40/40 |
| `scripts/test-b04-navigation.mjs` | estrutural | 9 páginas |
| Testes Codex `test-b04-profile`, `test-b04-navigation-ui`, `test-checklist-ui`, `test-checklist-ui-resilience` | Chromium via `scripts/ui/happy-dom-in-chromium.mjs` | 4/4 |
| Prova na produção (transação revertida) | Admin real: `context` e `list` | ok |
| Advisors de segurança | produção | nenhum alerta novo; tabelas privadas sem policy são intencionais |

**Não testado ainda:** Edge Function contra o Storage real (depende da parte 4 e de uma sessão autenticada no navegador); upload grande medido; homologação com contas reais (B14/B15).

## Reversão

Ocultar o item "Biblioteca de documentos" (reverter `audita-pro-navigation.js`) e restaurar o link antigo para `audita-pro-historico.html`.
O schema é aditivo e pode permanecer; nenhuma tabela existente foi alterada.
