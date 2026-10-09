# B07 — Contratos propostos para cronograma e continuidade

Data: 09/10/2026. Especificação para revisão do Codex 01, sem endpoints, migrations ou regras novas ativadas. Os nomes de operações abaixo são conceituais; conciliá-los com `audit_workspace` e os comandos atuais antes de implementar.

## Dependências de entrada

- B06: período declarado, localização/unidade, equipe habilitada, critérios e versões aplicados. A preparação de B06 não equivale à sua implementação.
- B02: autorização por recurso, conta/vínculo ativo e regra de Admin/Líder/Auditor/Participante. Não copiar literalmente a restrição histórica de Admin presente no documento-fonte do Plano se divergir de D04/B02.
- B03: identidades e cálculos temporais comuns. Não criar contagem de requisitos nem numeração de dias paralelas.
- B01: contrato de snapshot e referência de fuso. D06/D09 constam no plano mestre; recuperar/conferir seus registros finais antes de implementar. O registro final D09 não foi localizado nesta cópia; não exigir nova aprovação do que já tiver sido decidido.
- B09/B10/B11: consumidores de publicação e RDA; B07 prepara a persistência das referências, sem emitir PDF ou fechar relatório.

## Modelo mínimo a conciliar

| Estrutura existente | Reaproveitamento | Extensão proposta e cuidado |
|---|---|---|
| `schedule_items` | ID da atividade, dia, processo, horários previstos/reais, categoria, notas e retirada | Local por linha e posição visual; não usar posição como identidade nem sobrescrever horários reais ao reprogramar |
| `assignee_membership_id` | Responsável legado de uma linha | Associação de múltiplos membros por atividade, única por atividade/membro; adaptar consumidores e preservar o membro legado. Não manter duas fontes divergentes de equipe |
| `schedule_requirements` / `schedule_question_scope` | Vínculos ao escopo versionado | Copiar referências autorizadas, nunca avaliações; excluir duplicatas pela identidade completa, não pelo texto/número da cláusula |
| `audit_days` | Data real, identidade e `opening_plan_version` | Criar somente datas explicitamente planejadas; preservar IDs, numeração e referências emitidas. Dia inserido antes de dia existente exige exibição cronológica sem renumerar os já emitidos |
| `audit_day_attendance` | Presença efetiva | Não preencher a partir dos auditores escalados nem copiar entre dias |
| `audit_plan_versions` | Snapshot original e versões | Capturar também local, equipe por linha e posição visual no contrato aprovado; não modificar versões antigas |
| `schedule_movements` | Antes/depois, motivo, autor/data | Registrar cada transferência e sua ligação ao trabalho original e à operação anterior; avaliar se metadados existentes comportam isso antes de acrescentar campos |

Quando houver trabalho parcial, a execução realizada continua vinculada à atividade original. O restante precisa ter identidade/referência explícita, sem recriar perguntas/avaliações já concluídas. Uma possível extensão é um vínculo de continuidade com atividade raiz, origem, destino, parcela realizada/restante e movimento anterior; seu nome/tabela só deve ser definido após conciliar o modelo real de B03.

Não usar uma porcentagem arbitrária como substituto da descrição do realizado/restante. Não inferir dados históricos que o sistema nunca registrou. Migração deve marcar a ausência de informação legada e conservar os registros existentes.

## Envelope de comandos

Cada gravação proposta contém `audit_id`, identificador de operação idempotente, versão esperada do agregado e dados da ação. Autor/data vêm da sessão e do servidor, nunca de um campo confiado ao navegador. IDs de dia, processo, membro, requisito e destino devem pertencer à mesma auditoria ou ao domínio elegível explicitamente validado.

Usar a versão do agregado já mantida no projeto (`audits.lock_version`) se continuar adequada: bloquear/revalidar a auditoria dentro da transação e atualizar versão somente ao concluir. Toda escrita concorrente no mesmo agregado, inclusive via comandos antigos, deve participar do mesmo protocolo. Conferir wrappers B02/B03; não substituir funções antigas por cópias locais desatualizadas.

Repetir a mesma operação com o mesmo conteúdo devolve o resultado anterior; mesma operação com conteúdo diferente deve ser recusada. Falha antes do commit não deixa movimento, dia ou linha parcialmente criado. Reautorizar antes de devolver resultado de retentativa. Não armazenar resultado público de operação que possa expor dados após revogação.

| Operação conceitual | Entrada específica | Resultado/invariante |
|---|---|---|
| Adicionar/editar linha | Local, data, início/fim, descrição/processo, categoria, auditores, requisitos e notas | ID único; membros elegíveis da equipe; sem mudar permissões; vínculos de escopo válidos |
| Duplicar linha | ID de origem e destino explícito | Novo ID; copiar apenas planejamento selecionado. Sem status de execução, horários reais, evidências, avaliações, presenças ou cadeia de transferência |
| Copiar próximo horário | Origem, início sugerido = fim original, duração original | Prévia editável; se atravessar meia-noite, exigir duas linhas/datas explícitas. Não truncar duração nem salvar silenciosamente no dia seguinte |
| Copiar outro dia | Origem e data escolhida | Oferecer próximo dia realmente planejado; sem presumir amanhã. Manter requisitos como referências, não como avaliações duplicadas |
| Reordenar | IDs/posições de linhas no escopo autorizado | Afeta somente ordem de apresentação; não muda datas, dia, código ou número de RDA; detectar lista desatualizada |
| Remover/retirar | ID e justificativa quando controlada | Apagar somente rascunho sem publicação nem dependência operacional; caso contrário retirada explícita preserva versões, movimentos e execução |
| Registrar execução antecipada | Atividade prevista, instante real, dia real e justificativa | Não reescrever a previsão original. Validar regra de abertura do dia e presença; conservar a comparação previsto × realizado |
| Registrar parcial | Atividade, descrição realizada, descrição restante e encaminhamento | Mantém realizada parcialmente na origem; não marca concluída ao transferir o restante |
| Reprogramar restante | Origem/restante, destino real, motivo, movimento anterior | Acrescenta elo de continuidade e evento; preserva anteriores; recusa ciclos, destino de outra auditoria e transferência de parcela já concluída |
| Não realizada sem destino | Origem, motivo e encaminhamento | Pendência explícita, sem conclusão fictícia nem destino inventado |

## Regras temporais

Tratar data/hora local segundo o fuso da auditoria, convertido no servidor para instantes consistentes. Não interpretar `datetime-local` pelo fuso do navegador. Para hora ambígua/inexistente, exigir resolução explícita; não corrigir silenciosamente. Não introduzir dependência técnica sem conferir runtime e documentação durante a implementação.

- Uma linha pertence a uma única data: fim deve ser posterior ao início. Travessia de meia-noite pede divisão em duas linhas. Na implementação, definir explicitamente a representação de 24:00 como limite exclusivo do primeiro dia e 00:00 como início do seguinte, sem perder minutos com um corte artificial em 23:59.
- Período declarado de B06 é diferente da menor/maior data do cronograma. Uma linha fora do período bloqueia validação/publicação e aponta a correção. Rascunho incompleto deve permanecer salvável quando permitido pelo contrato B06/B09; erro estrutural como data impossível não deve virar timestamp inválido persistido.
- Sobreposição usa intervalos semiabertos: uma atividade terminar às 10h e outra começar às 10h não é conflito. Interseção de horário E pelo menos um auditor comum gera aviso; equipes disjuntas podem ocorrer simultaneamente.
- Aviso de sobreposição não concede acesso nem bloqueia automaticamente atividade conjunta. Não reordenar nem reagendar sozinho para resolver aviso.
- Sem dias automáticos para os intervalos entre datas. O próximo dia real é selecionado entre datas planejadas ou informado pelo condutor.

## Preservação temporal e RDA

Manter três referências distintas: plano original, versão vigente quando o dia foi aberto e sequência de alterações posteriores. A abertura do dia deve fixar `opening_plan_version` atomicamente; não alterar esse valor quando um novo plano for publicado. Para legado sem referência, apontar ausência, não reconstruir retrospectivamente um snapshot como se tivesse sido registrado.

Projeção para B10/B11 precisa expor atividade raiz, previsão no início do dia, movimentos até o corte, horários reais, parcela realizada/restante e destino. O estado atual sozinho não explica transferências repetidas. Um RDA já congelado nunca deve ser recalculado usando a posição ou data atual da atividade.

Caso ilustrativo: atividade A no dia 09, execução parcial com restante R transferido para dia 13; R depois transferido para dia 16. O dia 09 continua parcial. O dia 13 evidencia a reprogramação do restante; o dia 16 recebe sua continuidade. Não contar três vezes a mesma pergunta/processo nos indicadores acumulados B03. Não criar dias 10, 11, 12, 14 e 15 automaticamente.

Uma nota livre no RDA pode referenciar pendência, mas só um comando confirmado de reprogramação modifica o cronograma. Guardar confirmação, motivo e autor de cada movimento.

## Interface e tratamento de falhas

Editor com colunas Local; Data; Início/Fim; Área/processo/atividade; Auditores. Detalhe expande categoria, requisitos e observações. Ações explícitas Adicionar, Duplicar, Copiar horário, Copiar dia, Subir, Descer e Remover/Retirar. Arrastar é opcional. No mobile, cartões legíveis mantêm todas as ações e foco de teclado.

Ao duplicar, apresentar a cópia como novo planejamento antes de salvar. Ao reprogramar parcial, mostrar origem, realizado, restante e destino antes da confirmação. Diferenciar essas duas ações na interface e no servidor.

Erros: conflito de versão pede recarregar/comparar, mantendo o rascunho local; falha de rede não apresenta sucesso; retentativa usa a mesma operação; acesso revogado bloqueia gravação. Nenhum botão oculto substitui autorização no servidor.

## Roteiro de implementação

1. Integrar e verificar B06, preservar baseline B02/B03 e reservar arquivos compartilhados.
2. Reconciliar modelo/migração mínima para local, ordem e múltiplos auditores; definir plano e movimentos com C0/C1.
3. Implementar operações transacionais, idempotência, autorização e compatibilidade dos consumidores antigos.
4. Implementar editor e cópia segura, validações temporais e avisos de sobreposição.
5. Implementar continuidade parcial, transferências encadeadas e referência do dia; ligar projeção B03/B10 sem gerar RDA neste bloco.
6. Executar critérios e regressões em ambiente isolado; só então integrar migrations e homologar com perfis reais.

Esta proposta não implementa os comandos nem aprova critérios. Os testes concretos estão em `criterios-e-testes.md` e todos aguardam execução funcional.
