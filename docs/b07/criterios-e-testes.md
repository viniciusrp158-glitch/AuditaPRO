# B07 — critérios de aceite e roteiro de testes

## Estado desta preparação

Este documento prepara o aceite do B07, sem executar implementação, banco, migração ou teste. O B07 depende do B06 segundo `01-plano-mestre.md`; o repositório contém apenas uma entrega parcial do B06. Portanto, todos os resultados abaixo permanecem **Não executados** e nenhum cenário constitui evidência de aceite.

A rastreabilidade integral está em `docs/b07/rastreabilidade.csv`: 71 linhas originais cujo campo `blocos_execucao` contém B07, preservadas nas 16 colunas da matriz mestre e acrescidas somente de `status_implementacao_b07` e `status_teste_b07`.

## Critérios originais exigidos pelo plano mestre

Os textos desta tabela são reproduzidos integralmente de `03-criterios-de-aceite.md` e das seções 17 das fontes Plano/RDA.

| ID | Critério original integral | Blocos na matriz mestre | Resultado B07 |
|---|---|---|---|
| PA-07 | Programar vários processos no mesmo dia → Linhas, locais, horários e auditores preservados | B07 | Não executado |
| PA-08 | Duplicar/copiar/reordenar linha → Nova atividade sem copiar execução ou multiplicar indevidamente requisitos | B07 | Não executado |
| PA-09 | Atividade fora do período ou horário inválido → Validação bloqueada com orientação clara | B07 B09 | Não executado |
| PA-10 | Mesmo auditor em horários sobrepostos → Aviso visível; não confundir com atividades simultâneas de equipes distintas | B07 | Não executado |
| PA-17 | Transferir trabalho após execução parcial → Preservar parcela realizada, origem, destino, motivo e reflexo no RDA | B07 B10 | Não executado |
| PA-18 | RDA emitido e plano revisado depois → RDA anterior permanece inalterado | B09 B11 | Não executado |
| PA-19 | Auditor de apoio designado na linha → Nome aparece; não ganha permissão de conduzir/editar automaticamente | B02 B07 | Não executado |
| PA-22 | Auditoria com dias não consecutivos → Datas reais e numeração do dia coerentes, sem gerar dias auditados vazios | B07 | Não executado |
| PA-23 | Duas sessões editando → Conflito detectado, sem sobrescrever alteração silenciosamente | B07 B09 | Não executado |
| RDA-08 | Atividade parcial e transferência repetida → Preservar execução, previsão anterior, motivos e trabalho restante | B07 B10 B11 | Não executado |

### Divergência de atribuição

O plano mestre do B07 declara `PA-07–10/17–19/22–23`, o que inclui PA-18. Porém, `02-matriz-requisitos.csv` e `03-criterios-de-aceite.md` atribuem PA-18 somente a B09/B11. Por isso PA-18 aparece neste roteiro como aceite solicitado pelo plano mestre, mas não foi acrescentado a `rastreabilidade.csv`, que preserva estritamente as linhas originais contendo B07. O aceite integrado de PA-18 deverá ser coordenado com B09/B11.

## Premissas e dados mínimos

Preparar uma auditoria integrada com período declarado de 10 a 15/10/2027, critérios ISO 14001 e ISO 45001, condutor `Líder A`, apoios ativos e aprovados `Auditor B` e `Auditor C`, e locais `Matriz` e `Unidade Norte`. Publicar uma revisão inicial antes dos testes de continuidade. Criar sessões independentes S1 e S2 com a mesma revisão esperada. Registrar IDs imutáveis de atividade, revisão, dia, movimento e RDA; consultar API/banco além da tela para confirmar que uma apresentação correta não oculta perda de histórico.

Em cada cenário, guardar entradas, identidade/revisão antes e depois, resposta da operação, estado persistido e captura da tela. O resultado só pode mudar para aprovado quando o fluxo integrado estiver disponível e a dependência B06 estiver concluída.

## Cenários dos critérios de aceite

### CT-B07-01 — PA-07: várias atividades no mesmo dia

1. No dia 10/10, criar três linhas: Compras 09:00–10:00 na Matriz com Líder A; Produção 10:15–12:00 na Unidade Norte com Auditor B; Meio Ambiente 14:00–16:00 na Matriz com Líder A e Auditor C.
2. Salvar, sair, reabrir e recarregar diretamente pela API.
3. Confirmar três identidades distintas e preservação exata de data, local, início/fim, descrição/processo, categoria, critérios/requisitos, observações e conjunto de auditores.
4. Confirmar que salvar uma linha não substitui nem funde outra do mesmo dia.

**Esperado:** PA-07 integral; nenhuma perda ou troca de campos. **Estado:** Não executado.

### CT-B07-02 — PA-08: duplicar, copiar e reordenar

1. Usar uma atividade já executada em ambiente de teste, com presença, evidência e resultado; duplicá-la no rascunho/revisão permitida.
2. Confirmar nova identidade e cópia apenas dos campos planejáveis e vínculos de requisitos, sem duplicar requisitos na relação e sem presença, evidência, resultado, estado concluído ou horário real.
3. Acionar “Copiar para o próximo horário”; confirmar início sugerido igual ao término original, mesma duração e possibilidade de ajuste.
4. Acionar “Copiar para outro dia”, escolhendo 12/10; confirmar que não foi presumido 11/10.
5. Reordenar com Subir/Descer, salvar e reabrir. Se existir arrastar, verificar que os botões continuam disponíveis.

**Esperado:** PA-08 integral, ordem manual persistente e nenhuma herança operacional. **Estado:** Não executado.

### CT-B07-03 — PA-09: período, duração e meia-noite

Executar separadamente: data 16/10 fora do período; 11:00–10:00; 10:00–10:00; e 23:30–00:30 na mesma linha. Tentar salvar rascunho e validar/publicar conforme a regra de cada etapa. Corrigir o caso da meia-noite dividindo-o em duas linhas de datas distintas.

**Esperado:** validação final bloqueada com indicação da linha/campo e ação corretiva; duração deve ser positiva; uma linha não atravessa meia-noite; após correção válida, o bloqueio específico desaparece. **Estado:** Não executado.

### CT-B07-04 — PA-10: conflitos por auditor

1. Criar duas atividades 09:00–10:00 e 09:30–10:30 com Líder A; confirmar aviso visível e não destrutivo.
2. Trocar a segunda para Auditor B; confirmar que simultaneidade de equipes distintas não é classificada como conflito do mesmo auditor.
3. Criar atividade conjunta com Líder A e Auditor B e representação explícita; confirmar que o sistema não a duplica como duas atividades.
4. Manter linhas fora da ordem cronológica; confirmar sinalização sem reordenação silenciosa.

**Esperado:** aviso somente onde há interseção real para a mesma pessoa, com dados preservados. **Estado:** Não executado.

### CT-B07-05 — PA-17: parcial e transferência

1. Publique Compras para 10/10 15:00–17:00; registre execução real 15:05–16:00 e identifique o realizado e o restante.
2. Transfira apenas o restante para nova atividade em 12/10 09:00, informando motivo e autor.
3. Confirme atividade de origem como parcialmente realizada, sem apagar previsão original nem execução real; confirme destino e vínculo do movimento.
4. Consulte a projeção do RDA de 10/10 e a agenda de 12/10.

**Esperado:** origem, parcela realizada, restante, destino, motivo, autor e reflexo no RDA ficam ligados e auditáveis. **Estado:** Não executado.

### CT-B07-06 — PA-18: imutabilidade do RDA anterior

1. Emita o RDA Rev.00 de 10/10 a partir da base congelada do dia.
2. Depois, revise o plano, altere uma atividade futura e conclua uma transferência que aparece em outro dia.
3. Reabra e compare arquivo/checksum e dados congelados do RDA Rev.00.

**Esperado:** o arquivo persistido do RDA anterior mantém exatamente seus bytes/checksum, e seus dados congelados permanecem inalterados (não regenerar o PDF para fazer a comparação); a revisão nova aparece somente nos contextos posteriores. Este teste depende de B09/B11. **Estado:** Não executado.

### CT-B07-07 — PA-19: apoio sem elevação de privilégio

1. Designe Auditor B como apoio de uma linha e publique/consulte a agenda e o documento.
2. Autentique como Auditor B e tente editar cronograma, conduzir o dia, registrar resultado e validar/publicar por UI e chamadas diretas.
3. Consulte a mesma linha com o condutor.

**Esperado:** nome do apoio aparece onde previsto; as operações exclusivas do condutor são recusadas também no backend; a designação não altera perfil ou permissão. **Estado:** Não executado.

### CT-B07-08 — PA-22: dias não consecutivos

1. Planeje atividades em 10, 12 e 15/10, várias por data, e publique.
2. Copie uma linha escolhendo o próximo dia efetivamente planejado.
3. Confirme dias cronológicos 1, 2 e 3 associados às datas reais; não criar dias 11, 13 ou 14.
4. Reordene visualmente uma linha e confirme que isso não muda identidade/número de dia nem RDA já emitido.

**Esperado:** datas e numeração coerentes, sem dias vazios ou renumeração histórica. **Estado:** Não executado.

### CT-B07-09 — PA-23: edição concorrente

1. S1 e S2 carregam a mesma revisão R. S1 altera o horário da linha A e salva, produzindo R+1.
2. S2, ainda em R, altera local/observação e tenta salvar.
3. Verifique resposta de conflito, mensagem com opção segura de recarregar/reconciliar e estado persistido.
4. Repita com alterações na mesma linha e em linhas diferentes para confirmar o contrato adotado.

**Esperado:** nenhuma alteração de S1 é sobrescrita silenciosamente; S2 não recebe falso sucesso; revisão esperada é verificada na operação. **Estado:** Não executado.

### CT-B07-10 — RDA-08: transferências encadeadas

1. Execute parcialmente A em 10/10 e transfira o restante para B em 12/10, com motivo M1 e autor U1.
2. Execute parcialmente B e transfira o novo restante para C em 15/10, com M2 e U2.
3. Compare plano original, vigente no início de cada dia, alterações intradia, execução real e projeções/RDAs dos três dias.
4. Confirme a cadeia A→B→C, quantidades/descrições realizadas e restantes, horários reais, motivos/autores e previsões anteriores.

**Esperado:** nenhuma transferência substitui a anterior, nenhum trabalho é contado como concluído ou duplicado, e cada dia retrata sua própria base congelada. **Estado:** Não executado.

## Cenários adicionais derivados das demais linhas B07

| ID | Linhas cobertas | Procedimento concreto e resultado esperado | Estado |
|---|---|---|---|
| CT-B07-11 | PLA-L0144/L0146–L0152 | Criar e reabrir uma linha com localização ajustada, data, início/fim, descrição estruturada, múltiplos auditores, categoria, dois requisitos de critérios diferentes e observação. Todos os campos e vínculos permanecem distintos; reunião/intervalo salva sem requisito artificial. | Não executado |
| CT-B07-12 | PLA-L0156–L0161 | Adicionar e remover rascunho sem histórico; depois tentar remover linha publicada com registros. A primeira some sem resíduo operacional; a segunda gera retirada controlada, preserva versão anterior e registros associados. | Não executado |
| CT-B07-13 | PLA-L0165–L0171 | Exercitar várias linhas/dia, lacunas entre datas, ordem manual divergente, sobreposição, fora do período e meia-noite. Confirmar avisos/bloqueios específicos, ausência de correção silenciosa e identidade cronológica estável. | Não executado |
| CT-B07-14 | PLA-L0271/L0273/L0275–L0278 | Abrir o dia publicado, alterar o plano durante o dia e registrar horários reais. Consultar snapshots para distinguir plano original, vigente na abertura, mudanças posteriores e execução; equipe planejada não preenche presença automaticamente. | Não executado |
| CT-B07-15 | PLA-L0280/L0282/L0284/L0286 | Concluir antecipadamente sem mudar previsão; revisar escopo/equipe/período futuro sem alterar concluídos; fechar projeção diária e revisar plano depois. Preservar horário real, referências originais e cópia congelada do RDA. | Não executado |
| CT-B07-16 | PLA-L0290/L0292–L0296 | Reproduzir transferência de Compras de 10 para 12/10: exigir motivo/revisão, manter previsão/movimento, mostrar saída no dia 10 e entrada no dia 12 e não alterar RDA já emitido. | Não executado |
| CT-B07-17 | RDA-L0142/L0144/L0146–L0151 | Para realizada, parcial, reprogramada e não realizada, comparar base do início do dia com real. Parcial traz feito/falta/encaminhamento; reprogramada traz destino/motivo; não realizada permite fechamento diário apenas com motivo e continuidade documentada. | Não executado |
| CT-B07-18 | RDA-L0153/L0155/L0157 | Confirmar que estados documentais mapeiam os estados existentes sem substituição indevida; pendência transferida conserva identidade/origem/destino; editar apenas nota livre não muda agenda até confirmação na operação de reagendamento. | Não executado |
| CT-B07-19 | PLA-L0044/L0046 | Tentar preparar cronograma antes do FPA suficiente, mantendo rascunho; validar continua bloqueado. Tentar salvar auditoria sem cliente; operação recusada e nenhuma auditoria órfã é criada. | Não executado |
| CT-B07-20 | PLA-L0339/L0341/L0353/L0355 | Inventariar contratos e dados existentes antes da mudança; executar o fluxo navegável integrado sem texto normativo fictício nem nova estrutura redundante. Verificar consumidores de auditor, requisitos, dias, atividades, movimentos e versões. | Não executado |
| CT-B07-21 | PLA-L0347/L0357 | Verificar persistência de cronograma/movimentos e consumidores que presumem uma norma ou um auditor. Uma linha com dois critérios e dois auditores permanece correta em lista, agenda, execução e projeção documental. | Não executado |
| CT-B07-22 | PLA-L0358/L0359 | Tentar operações e consultas diretas sem autorização; recusá-las no backend. Confirmar que acesso a plano/PDF não concede acesso ao FPA e que armazenamento restrito não se torna público. | Não executado |
| CT-B07-23 | PLA-L0360/L0361 | Fixar versão esperada, disparar operação repetida e edição concorrente. Conteúdo/revisão permanecem consistentes, não há publicação parcial nem sobrescrita silenciosa. | Não executado |
| CT-B07-24 | PLA-L0362/L0363/L0365 | Em ensaio de migração futuro, validar compatibilidade/backfill documentado, preservação de planos legados sem FPA inventado e ausência de novo serviço pago específico para o fluxo. | Não executado |
| CT-B07-25 | RDA-L0314 | Inspecionar o modelo/migração proposto para atividades e transferências e provar com A→B→C que o vínculo de origem/destino e o histórico não dependem de texto livre. | Não executado |

## Cobertura das 71 linhas da matriz

- Plano: 59 linhas — 2 de fluxo, 20 de cronograma, 16 de execução/exemplo, 13 de plano técnico e 8 critérios PA mapeados diretamente a B07.
- RDA: 12 linhas — 10 de cronograma/desvios, 1 de plano técnico e RDA-08.
- Os critérios PA-07/08/09/10/17/19/22/23 e RDA-08 têm linhas próprias no CSV e cenários dedicados acima.
- PA-18 tem cenário dedicado por exigência do plano mestre, mas não integra as 71 linhas porque suas fontes tabularizadas não contêm B07.

## Condição de saída futura

B07 somente poderá ser considerado aceito após: B06 integrado; implementação e persistência reais disponíveis; todos os cenários aplicáveis executados; evidências vinculadas aos IDs da matriz; autorização verificada no backend; histórico/snapshots conferidos; e resultados atualizados sem apagar os textos originais ou as divergências registradas.
