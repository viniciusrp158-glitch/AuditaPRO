# Entrega B07 — Cronograma editável e continuidade

- **Responsável:** Claude (C0). **Data:** 10/10/2026. **Branch:** `feat/b07-cronograma-claude` (base `feat/b06-identificacao-fpa-claude`, 44aff79).
- **Base:** plano mestre §B07; critérios PA-07–10, PA-17–19, PA-22–23, RDA-08 (PA-18 é verificado no B09/B11, como na matriz de critérios). O rascunho do Codex (`git show 85ff485:docs/b07/*`) serviu só de referência.

## Entregue

| Critério | Como | Evidência |
|---|---|---|
| PA-07 | Várias linhas no mesmo dia, cada uma com local, data, início/fim, área/processo/atividade, categoria, observações, requisitos e **vários auditores** (`assignee_ids`) | SQL + UI |
| PA-08 | Adicionar, duplicar, copiar para o próximo horário (mesma duração), copiar para outro dia (diálogo), subir/descer e remover por botões. A cópia gera nova chave e não leva execução, presenças, evidências ou resultados | UI |
| PA-09 | Fim ≤ início bloqueia, com orientação para dividir o trabalho após a meia-noite; data fora do período declarado bloqueia; horários interpretados no fuso da auditoria, no servidor | SQL + UI |
| PA-10 | Aviso de sobreposição apenas para o **mesmo auditor**, em intervalo semiaberto; equipes distintas simultâneas não geram aviso | SQL |
| PA-17 / RDA-08 | `record_outcome` parcial preserva o realizado e o restante; "Transferir restante" cria nova atividade com `continuation_of` (origem/destino encadeados); `schedule_movements` guarda antes/depois, motivo e autor | SQL + UI |
| Plano §B07 (não realizada) | Não realizada exige motivo e encaminhamento, fica pendente explícita e sem conclusão fictícia | SQL + UI |
| PA-19 | Só membros da equipe (condutor ou apoio) podem ser designados; o apoio consulta e não edita, inclusive por chamada direta | SQL + UI |
| PA-22 | Dias não consecutivos sem dias intermediários vazios; a ordem visual é separada da cronológica (aviso, sem reordenação automática) | SQL |
| PA-23 | `expected_lock_version` + `operation_id` idempotente; em conflito (40001), o rascunho local é preservado para comparação | SQL + UI |
| Reuniões/intervalos | Categorias opening/closing/meeting/break/other não exigem processo nem requisito | SQL |
| Cobertura | Requisito fora do checklist bloqueia; requisitos não distribuídos aparecem como pendência do plano | SQL |

**Antecipação:** o horário real já é registrado pelo fluxo de execução existente (`actual_start`/`actual_end` ao iniciar ou concluir a atividade). Ele aparece no cronograma publicado.

**Retirada controlada:** uma linha já publicada sai do rascunho como "retirada". A baixa definitiva e a renumeração acontecem na publicação (B09).

## Produção

As migrations `20261010172727_b07_1_schedule_schema`, `20261010172758_b07_2_schedule_rules` e `20261010172828_b07_3_schedule_commands` foram aplicadas, e os arquivos foram renomeados para as versões reais.

Prova na produção com o Admin real, em transação revertida:
- `draft` respondeu `can_edit=true` e apontou 2 erros esperados (sem atividade e sem período).
- `save` gravou com o lock 0→1, e 08:00 virou `11:00Z`; o banco conferido depois continuou com o lock 0 e o rascunho vazio.
- O acesso anônimo foi recusado (`42501`).

Nenhuma Edge Function nova.

## Testes

- `scripts/run-sql-test.sh scripts/test-b07-schedule.sql`: 33/33.
- `scripts/test-b07-schedule-editor-ui.mjs`: 27/27, incluindo celular sem rolagem horizontal.
- Regressão B05 (42/42 SQL, 31/31 UI) e B06 (46/46 SQL, 25/25 UI) aprovada após a reconstrução do banco local com 72 migrations.

## Pendente / limites

- **B09:** publicar o rascunho, materializando `schedule_items` e `schedule_requirements`, gravar o snapshot em `audit_plan_versions` e renumerar só os dias não iniciados. Pela regra AD-15, os vínculos serão atualizados por marcação ou versão, sem DELETE.
- **B09/B11:** guardar o "plano vigente ao abrir o dia". O legado já tem as chaves `original_plan` e `opening_plan`, que serão preenchidas na publicação e na abertura do dia.
- Arrastar para reordenar (complementar) não foi feito; os botões cobrem o critério.
- Homologação com contas reais: B14/B15.

## Reversão

Retirar o `audita-pro-schedule-editor.js` e a aba "Cronograma" do `audita-pro-audits.js`. O schema é aditivo e permanece.
