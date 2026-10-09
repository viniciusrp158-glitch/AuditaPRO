# B07 — diagnóstico do cronograma e da continuidade

## Escopo e limite da leitura

Este diagnóstico confronta o B07 do plano mestre, a matriz de requisitos e as fontes Plano/RDA com o frontend e as migrations presentes no checkout `cf7fa1f` (B06 parcial). Também incorpora a inspeção somente leitura do banco feita pela sessão coordenadora em 09/10/2026. Essa inspeção confirmou formas e assinaturas, mas não executou RPCs nem mutações; portanto, este texto não declara comportamento vivo validado.

As migrations locais são evidência histórica de intenção e ajudam a explicar o frontend. Elas não são tratadas como fotografia final do Supabase: B02/B03 foram confirmados pelo usuário no ambiente vivo e ainda não estão representados integralmente no Git.

## Resultado executivo

O B07 deve evoluir o fluxo existente, não criar outro editor ou outra cadeia de checklist. Há contratos reutilizáveis para rascunho/publicação (`audit_workspace`), versões (`audit_plan_versions`), dias (`audit_days`), linhas (`schedule_items`), requisitos (`schedule_requirements`), histórico (`schedule_movements`), presença (`audit_day_attendance`) e execução de perguntas (`checklist_execution`).

O contrato disponível no checkout, porém, só cobre uma atividade inteira. Faltam dados e operações para localização por linha, ordem manual, múltiplos auditores, cópia segura, conflitos de agenda, período declarado e continuidade parcial. A transferência existente muda a data da mesma `schedule_item`; isso é adequado para reagendar uma linha ainda não executada, mas não representa “parcela realizada + restante com identidade de origem/destino”. Tentar resolver o B07 apenas acrescentando botões ao modal atual perderia informação exigida por PA-07–10/17/19/22/23 e RDA-08.

## Fluxo observado no frontend

### Editor e publicação em `outputs/audita-pro-audits.js`

O frontend chama `public.audit_workspace(command, payload)` por meio de `rpc`. Ao abrir uma auditoria usa:

- `detail`: `{ audit_id }`;
- o retorno consumido inclui `audit`, `plan`, `versions`, `days`, `schedule`, `processes`, `movements`, `requirements`, `team`, `attendance`, `can_edit` e `full_access`.

O modal `planEdit()` parte de `audit.plan_draft`, quando não vazio, ou da última versão em `current.plan`. Cada linha enviada por `plan_save` tem exatamente:

```json
{
  "id": "uuid ou null",
  "title": "texto",
  "date": "YYYY-MM-DD",
  "category": "assessment|opening|closing|meeting|break|other",
  "process": "texto",
  "start": "timestamptz ISO ou null",
  "end": "timestamptz ISO ou null",
  "notes": "texto",
  "requirements": ["requirement_uuid"]
}
```

O primeiro RPC é:

```json
{
  "command": "plan_save",
  "payload": {
    "audit_id": "uuid",
    "lock_version": 0,
    "items": []
  }
}
```

Se a opção de publicar estiver marcada, o frontend chama em seguida:

```json
{
  "command": "plan_publish",
  "payload": {
    "audit_id": "uuid",
    "lock_version": 1,
    "reason": "texto"
  }
}
```

O `+1` é calculado no cliente, pressupondo que `plan_save` incrementou a versão exatamente uma vez. Não há `operation_id` nos dois comandos. A tela recarrega `detail` após os dois RPCs.

O editor atual permite adicionar e retirar uma linha do rascunho. Não oferece duplicar, copiar para horário/dia, subir/descer, localização por linha nem seleção de auditores. A ordem enviada é a ordem do DOM, mas a publicação histórica ordena itens por `date/start` e não persiste uma posição manual. O horário é convertido com `new Date(date + 'T' + time).toISOString()`, usando o fuso do navegador; a auditoria possui `timezone`, mas ele não participa dessa conversão.

A agenda renderiza `current.days` e `current.schedule`; mostra horário, processo/categoria, requisitos, estado e `origin_day_id`/`move_reason`. Não mostra localização, auditores planejados ou cadeia de transferências. “Imprimir plano” usa `current.plan`, abre HTML e chama impressão do navegador; esse caminho não é uma versão documental persistida.

### Execução em `outputs/audita-pro-execution.js`

O checklist chama `public.checklist_execution(command, payload)` e sempre injeta `audit_id`. O contexto expõe `days`, `activities`, modelos e estatísticas. As perguntas são carregadas com:

```json
{
  "command": "questions",
  "payload": {
    "audit_id": "uuid",
    "schedule_id": "uuid ou null",
    "page": 0,
    "search": "...",
    "criterion_id": "uuid",
    "section_id": "uuid",
    "process_id": "uuid",
    "day_id": "uuid",
    "author_id": "uuid",
    "result": "...",
    "state": "...",
    "with_nc": true,
    "pending": true
  }
}
```

As gravações de pergunta usam `schedule_id`, `question_id`, `lock_version`, `operation_id` e `patch`; conclusão repete o mesmo contrato no comando `complete`. Inclusão/antecipação usa `scope_include` com `schedule_id`, `question_id`, pesquisa e `reason`; retirada usa `scope_exclude` com `schedule_id`, `question_id` e `reason`. Assim, `schedule_id` já é uma chave operacional compartilhada pelo cronograma e checklist. Uma cópia deve criar nova identidade e só então compor seu próprio escopo; jamais copiar avaliações, evidências ou estado.

O executor mostra um único `planned_author`, derivado do responsável planejado da atividade. Não há consumidor para vários auditores por linha. O checklist já tem concorrência mais robusta que o editor: usa `lock_version` por avaliação, `operation_id`, preserva o conteúdo local e trata `40001` com comparação/recarregamento.

### Comandos de execução ainda usados pela agenda

- `activity_start`: `{ audit_id, schedule_id }`;
- `activity_complete`: `{ audit_id, schedule_id }`;
- `attendance`: `{ audit_id, day_id, members: [membership_uuid] }`.

O modelo histórico inicia o dia junto com a primeira atividade e fixa `audit_days.opening_plan_version` com a revisão vigente. A presença efetiva fica separada da equipe, o que deve ser preservado.

## Estrutura confirmada e capacidade real

A leitura do banco em 09/10 confirmou:

| Estrutura | Forma confirmada | Reuso no B07 | Limite atual |
|---|---|---|---|
| `audit_days` | id e `day_number` estáveis, `audit_date`, estado, `opening_plan_version` | Identidade do dia e plano vigente na abertura | Renumeração/inserção precisa respeitar RDAs existentes |
| `schedule_items` | dia, processo, requisito legado, título, início/fim planejados, um `assignee_membership_id`, estado, origem/motivo/autor/data de movimento, notas, categoria, início/fim reais e `withdrawn` | Linha operacional existente | Sem localização, ordem manual ou múltiplos auditores; origem única não expressa cadeia/parcial |
| `schedule_requirements` | N:N atividade–requisito | Manter escopo por atividade | Publicação histórica local apaga e reinsere vínculos de toda linha |
| `schedule_question_scope` | escopo de pergunta por atividade | Preservar inclusão/retirada do checklist | Uma nova cópia não pode herdar resultados; regra de copiar escopo precisa ser explícita |
| `schedule_movements` | antes/depois em JSON, motivo, autor e data | Auditoria imutável de alteração | Snapshot de linha não contém requisitos, auditores múltiplos, localização ou fração restante; não há vínculo explícito origem→destino |
| `audit_plan_versions` | snapshots JSON versionados | Plano original e revisões | Snapshot atual é centrado nas linhas; B09 ainda precisa congelar o documento completo |
| `audit_day_attendance` | presença separada por dia | Atende distinção equipe planejada/presença real | Não substitui designação por linha |

Também foram confirmadas as funções de workspace `workspace_command`/`workspace_detail`, a assinatura pública `audit_workspace(text,jsonb)` e o contrato B03 `audit_public_schedule_progress`. A existência foi verificada; permissões, execução e efeitos não foram testados nesta preparação. RLS B02 convive com políticas legadas e deve ser analisada na migration do B07 sem deduzir autorização apenas pela interface.

## O que as migrations locais indicam, sem promovê-las a verdade viva

A versão local mais recente de `workspace_command` valida `lock_version` em `plan_save` e `plan_publish`, exige checklist confirmado, equipe revisada, motivo e distribuição de todos os requisitos. Ela cria somente os dias presentes no rascunho, de modo que datas não consecutivas não geram dias vazios.

Na publicação, cada item é associado/criado por `id`; omissão retira linhas não concluídas com `withdrawn=true`; linhas concluídas não podem trocar data nem escopo. Mudança de uma linha grava `schedule_movements` e, ao mudar o dia, preenche `origin_day_id` apenas na primeira transferência. Depois cria um snapshot em `audit_plan_versions` e recalcula `audits.start_date/end_date` pelas datas efetivamente planejadas.

Essas regras fornecem continuidade básica e preservam linhas concluídas, mas há riscos concretos:

- `plan_save` aceita o JSON do rascunho com pouca validação estrutural; a validação forte ocorre só na publicação;
- o encadeamento cliente `lock_version + 1` é frágil e não é idempotente;
- o período é derivado do cronograma, logo não existe período declarado contra o qual bloquear uma linha;
- não há validação explícita de `end > start`, sobreposição, travessia de meia-noite ou coerência com auditores;
- o uso de `timestamptz` montado pelo navegador pode deslocar dia/horário quando navegador e auditoria têm fusos distintos;
- a ordenação manual se perde na publicação;
- a linha sempre recebe o condutor como responsável nas migrations históricas;
- mover a mesma identidade é incompatível com preservar uma parte executada e criar um restante rastreável;
- `schedule_movements.previous_data/new_data` não inclui relações N:N e não basta, isoladamente, para reconstruir o escopo integral em cada movimento;
- dias antigos sem linhas podem permanecer; eliminá-los ou renumerá-los automaticamente colocaria relatórios e `opening_plan_version` em risco;
- o fechamento diário histórico exige resolver atividades pendentes; o RDA pede encerramento com pendência documentada e encaminhada.

## Lacunas por critério de aceite

| Critério | Cobertura observada | Lacuna para saída do B07 |
|---|---|---|
| PA-07 | Várias linhas/dia e horários já existem | Persistir localização e auditores por linha; verificar render/projeção |
| PA-08 | IDs existentes preservam edição; omissão vira retirada | Duplicar/copiar/reordenar com nova identidade, posição estável e sem copiar execução/escopo indevido |
| PA-09 | Data/título e coerência básica são validados na publicação | Período declarado, duração positiva, meia-noite e erros por linha |
| PA-10 | Nenhuma verificação observada | Detectar sobreposição por auditor; aviso, não bloqueio global |
| PA-17 | Movimento antes/depois e primeira origem existem | Modelar parcial/restante e vínculo explícito entre origem e destino, inclusive repetição |
| PA-19 | Um responsável por linha existe | Múltiplos auditores habilitados, nome na agenda/documentos, sem ampliar autorização |
| PA-22 | Dias são criados só para datas planejadas | Ordem cronológica e numeração estável após revisões/RDAs; casos de inserção entre dias |
| PA-23 | `lock_version` rejeita rascunho obsoleto | Retornar versão atual do servidor; idempotência e UX de comparar/recarregar no editor |
| RDA-08 | Plano inicial, abertura do dia, movimentos e horários reais têm bases | Classificação parcial/reprogramada/não realizada, restante quantificado/descrito, cadeia e congelamento por RDA |

## Contrato mínimo a ampliar

O caminho mais seguro é manter `audit_workspace` e `checklist_execution`, acrescentando campos e comandos compatíveis. Não é necessário introduzir framework novo.

### Campos de linha

Acrescentar ao contrato de item, com defaults compatíveis:

- `location` ou `location_text`, com eventual `unit_id` se a unidade cadastrada for aplicável;
- `display_order` inteiro, definido pelo usuário e independente da data;
- `assignee_ids` como projeção de relação N:N; manter `assignee_membership_id` durante transição;
- metadados de continuidade somente onde houver operação de parcial/restante, evitando sobrecarregar `notes`.

Uma tabela relacional `schedule_item_assignees(schedule_item_id, membership_id, role)` é mais adequada que array para validar empresa/equipe e detectar conflitos. Ela não concede permissão de escrita; autorização continua no contrato B02/D04/D06 vigente, incluindo o tratamento do Administrador global.

### Operações

Manter `plan_save`/`plan_publish` no primeiro incremento, mas retornar `{ lock_version, draft }` e aceitar `operation_id` em gravações idempotentes. Cópia pode continuar sendo preparada no cliente e publicada pelo mesmo contrato se o backend rejeitar IDs reutilizados e limpar qualquer campo operacional. Para continuidade após execução, usar comando dedicado, por exemplo `schedule_transfer_remaining`, que receba atividade de origem, destino/data/horários, descrição do restante, motivo, versão esperada e `operation_id`.

Esse comando deve ser transacional: preservar a origem e seus horários/resultados reais, criar uma nova atividade planejada com nova identidade, registrar o vínculo origem→destino e o evento com antes/depois, motivo e autor. Transferência repetida deve formar uma cadeia navegável. Alterar apenas `audit_day_id` da mesma linha continua reservado ao reagendamento integral antes de execução relevante.

## Incrementos futuros viáveis

1. **Compatibilidade e editor:** migration pequena para ordem, localização e relação de auditores; projeção compatível em `detail`; editor com adicionar, retirar, duplicar, copiar e Subir/Descer. Preservar IDs existentes e o vínculo `schedule_id` do checklist.
2. **Validação temporal:** interpretar data/hora no `audits.timezone` no servidor; bloquear término não posterior, travessia de data e linha fora do período declarado; avisar sobreposição por auditor. Testar dias não consecutivos sem criar datas intermediárias.
3. **Concorrência:** `operation_id` e retorno de versão em `plan_save/publish`; comparação de rascunho local/servidor semelhante à execução do checklist. Não depender de `lock_version + 1` calculado pelo browser.
4. **Continuidade:** operação transacional de parcial/restante e cadeia origem–destino; estados/documentação suficientes para realizada, parcial, reprogramada e não realizada. Preparar a projeção de pendência documentada e encaminhada para o fechamento do dia; alteração do comando de fechamento pertence à integração coordenada com B10/B11.
5. **Consumidores:** agenda, checklist, projeção B03, histórico e payload documental passam a ler ordem, localização, todos os auditores e cadeia. Antes de alterar B03, comparar o contrato vivo de `audit_public_schedule_progress` para manter a projeção cliente já entregue.
6. **Aceite integrado:** PA-07–10/17/19/22/23 e RDA-08, incluindo duas sessões, cópia após execução, transferência repetida e um RDA já emitido que permaneça congelado.

## Guardas para a implementação

- Não recriar checklist, dias, movimentos ou versões do plano em estruturas paralelas.
- Não usar `notes` como substituto de localização, ordem, destino ou trabalho restante.
- Não conceder escrita ao auditor de apoio por incluí-lo em uma linha.
- Não copiar avaliações, evidências, presença, estado, horários reais nem `schedule_question_scope` sem uma regra explícita de composição.
- Não renumerar um dia que já tenha execução ou documento; a posição visual deve ser independente de `day_number`.
- Não reconstruir o plano vigente de tabelas mutáveis para documentos já emitidos; usar o snapshot versionado aplicável à abertura/fechamento do dia.
- Antes da migration, recuperar as definições vivas das funções/políticas tocadas e produzir `CREATE OR REPLACE` sobre essa base, incorporando B02/B03 que ainda faltam no Git.

## Evidência consultada

- `../review-plan/audita-plano-execucao/01-plano-mestre.md`, seção B07.
- `../review-plan/audita-plano-execucao/02-matriz-requisitos.csv`, linhas vinculadas a B07.
- `../review-plan/audita-plano-execucao/03-criterios-de-aceite.md`, PA-07–10/17/19/22/23 e RDA-08.
- `../review-plan/audita-plano-execucao/fontes/audita-pro-planejamento-plano-auditoria-v0.1.md`, seções 7, 8, 12 e 15.
- `../review-plan/audita-plano-execucao/fontes/audita-pro-planejamento-rda-v0.1.md`, seção 7.
- `outputs/audita-pro-audits.js` e `outputs/audita-pro-execution.js`.
- Migrations locais de domínio, workspace, revisão de plano e checklist; usadas como histórico, não como afirmação de estado vivo.
- Inspeção somente leitura do banco pela sessão coordenadora em 09/10/2026.
