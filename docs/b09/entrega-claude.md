# Entrega B09 — Plano validado, versionado e publicado

- **Responsável:** Claude (C0). **Data:** 10/10/2026. **Branch:** `feat/b09-plano-claude` (base `feat/b08-emissao-claude`).
- **Base:**
  - Plano mestre §B09.
  - Planejamento do Plano §5, §7, §10–§14 e Anexo A.
  - Critérios PA-13–16, PA-18, PA-20–24, PER-09/10.

## Fluxo entregue

**Etapas:** Identificação e FPA → Equipe → Cronograma → **Validação e publicação**. A nova aba da auditoria reúne as 15 verificações, os avisos, a prévia, a validação e as revisões.

1. **15 verificações da seção 10** (`private.b09_checks`):
   - cada uma traz a mensagem do que falta e o atalho para a etapa que corrige;
   - os avisos (sobreposição do mesmo auditor, ordem fora da cronológica) ficam separados dos bloqueios;
   - a verificação 10 também protege a execução já registrada: atividade iniciada não sai do plano nem perde requisitos; atividade concluída mantém descrição, data e requisitos; dia encerrado não recebe atividade; não se cria data nova antes de um dia já iniciado.
2. **Prévia:** PDF gerado no servidor com a marca "PRÉVIA — SEM VALIDADE". Nada é gravado.
3. **Validar:**
   - congela o retrato completo da revisão: cliente, código, CNPJ, endereço, localização, período, critérios e edições, natureza, tipo, modalidade, objetivo, equipe, outros participantes, cronograma com dias numerados, escopo, comentários, FPA de referência, controle de revisões e as nove notas do Anexo A (modelo v1);
   - grava o retrato com SHA-256 em `private.plan_revisions` (estado `validated`);
   - cria o pedido de emissão do B08 (modelo `plan` v1, arquivo `AUD-AAAA-n_Plano_RevNN.pdf`) e aciona o processador pelo servidor;
   - duplo clique devolve a mesma revisão (`operation_id`);
   - Rev.00 não exige motivo; a partir da Rev.01, o motivo é obrigatório.
4. **Publicar** (só com o PDF íntegro), dentro da confirmação do processador:
   - a revisão vira `published` e a anterior, `superseded`;
   - o cronograma executável recebe a revisão sem DELETE (AD-15): atividade omitida fica retirada; atividade não iniciada que perde requisitos ganha nova identidade (`replaced_by`), copiando o escopo de perguntas; atividade movida registra origem e motivo; dia planejado sem atividade fica retirado e é numerado depois dos ativos; dias já iniciados mantêm o número;
   - o rascunho em edição recebe as identidades publicadas sem perder alterações feitas depois da validação;
   - a publicação é registrada também em `audit_plan_versions`, no contrato legado (lista das atividades vigentes, `version_number` = `plan_revision`), que as métricas do B03, o detalhe da auditoria e os documentos legados leem;
   - `plan_revision` sobe, o sino avisa uma única vez (gatilho existente) e a execução fica liberada.
5. **Falha e bloqueio:**
   - Falha no PDF: nada é publicado; o pedido é retomado (pelo botão ou pela varredura) ou a revisão é descartada com motivo.
   - Aplicação impedida (por exemplo, um dia encerrado entre a validação e o PDF): o PDF íntegro fica "pronto" com o motivo, sem publicar e sem novas tentativas automáticas.
   - Enquanto isso, a revisão anterior continua vigente.
6. **Cliente** com vínculo aprovado:
   - consulta e baixa as revisões publicadas (a vigente e as substituídas);
   - não vê rascunhos, revisões descartadas, o conteúdo bruto nem o FPA;
   - outra organização é recusada inclusive por chamada direta.
7. O `plan_publish` legado (sem validação nem PDF) agora é recusado. O botão de impressão pelo navegador foi trocado pelos PDFs persistidos.

## Critérios

| Critério | Evidência |
|---|---|
| PA-13: Rev.00 congelada, PDF e acesso uma única vez | SQL (publicado só após PDF; notificação única) · UI |
| PA-14: falha ou duplo clique | SQL (mesma revisão; segunda validação recusada) · B08 (retomada) · UI |
| PA-15: alteração exige motivo, nova revisão e PDF anterior preservado | SQL (Rev.01; Rev.00 substituída, conteúdo intacto) · UI |
| PA-16: cadastro alterado não muda o PDF antigo | SQL (nome do cliente alterado; retrato e emissão mantêm o original) |
| PA-18: RDA emitido não muda com a revisão do plano | Garantido por construção: a publicação não toca `daily_report_versions`. A prova com RDA real fica no **B11** |
| PA-20: outra organização ou vínculo pendente | SQL (consulta e download recusados) |
| PA-21: plano extenso | PDF: 150 atividades, 19 páginas, rodapé, numeração, tabela repetida e notas completas na última página |
| PA-22: dias não consecutivos | SQL (dias 1 e 2 sem intermediários; dia retirado numerado depois) |
| PA-23: duas sessões | SQL (verificação 15 com versão esperada) · B07 |
| PA-24: Admin/condutor único | SQL (Administrador valida a Rev.02 sem aprovador) |
| PER-09 / PER-10 | SQL e UI (rascunho invisível ao cliente; vigente mantida durante a geração) |

## Produção

**Migrations** (todas conferidas byte a byte por md5):
- `20261010213847_b09_1_plan_schema`
- `…213921_b09_2_plan_checks`
- `…213947_b09_3_plan_snapshot`
- `…214012_b09_4_plan_commands`
- `…214039_b09_5_plan_apply`
- `…214121_b09_6a_plan_publish_hook`
- `…214129_b09_6b_plan_client_view`
- `…214133_b09_6c_block_legacy_publish`
- `…214442_b09_6d_conditional_publish`
- Correção (AD-26): `…220407_b09_7a_plan_revisions_table`, `…220450_b09_7b_snapshot_history`, `…220518_b09_7c_plan_commands`, `…220553_b09_7d_plan_apply`, `…220604_b09_7e_apply_blocker`

**Edge Function:** `document-emission` v2, com o modelo `plan` v1, a prévia e o autoteste do modelo.

**Provas no runtime real:**
- O autoteste do modelo do Plano, com 120 atividades sintéticas e as notas lidas do banco de produção, gerou 12 páginas em 23 ms; o arquivo foi gravado, conferido e retirado.
- `audit_plan('status')` com o Admin real na auditoria em rascunho devolveu as 15 verificações, com 9 pendências esperadas (repetido após a correção AD-26: Rev.00, sem revisões abertas).
- Nenhum pedido nem arquivo ficou na produção. Os avisos de segurança não têm itens novos.

## Testes

| Teste | Resultado |
|---|---|
| `scripts/run-sql-test.sh scripts/test-b09-plan.sql` (inclui o contrato legado e as métricas do B03 após publicar) | 44/44 |
| `tsx scripts/test-b09-plan-pdf.mts` (retrato real + plano extenso) | 17/17 |
| `node scripts/test-b09-publication-ui.mjs` | 21/21 |
| `tsx scripts/test-b08-emit-flow.mts` (inclui o autoteste do modelo do Plano; banco próprio) | 17/17 |
| Regressão B04–B08 (SQL, motor e interfaces) | aprovada |
| Testes legados do checklist (continuidade, execução, v2) | aprovados; publicam o plano pela função interna, já que `plan_publish` foi recusado (AD-25) |

## Pendente / limites

- **Testes legados `test-checklist-documents.sql` e `test-checklist-permissions.sql`:** param antes do plano, na regra de apoio habilitado do B02 (deriva anterior ao B09). Ficam para a revisão de documentos do B11.

- **D08:** identidade visual (logo claro para impressão e modelo de cabeçalho). O texto institucional segue o Anexo A sem alteração.
- **B11:** prova do PA-18 com RDA emitido e uso do "plano vigente ao abrir o dia" (`opening_plan_version` legado).
- **Homologação com contas reais (B14/B15):** a validação completa depende do frontend publicado.
- **E-mail ao cliente:** fora do piloto. O aviso vai só pelo sino, e o sistema não alega envio de e-mail.

## Reversão

Ocultar a aba "Validação e publicação". O `plan_publish` legado pode ser reativado restaurando o `public.audit_workspace` anterior (wrapper SQL). Todo o schema é aditivo; revisões e PDFs ficam preservados.
