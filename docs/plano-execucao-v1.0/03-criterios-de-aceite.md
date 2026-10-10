# Audita PRO — Critérios de aceite por etapa

Data: 07/10/2026. Transcrição dos critérios dos quatro anexos, com blocos responsáveis. Nenhum resultado de teste é presumido.

Os critérios condicionais continuam condicionais. D01/D02/D03/D05/D07/D10 exigem ajuste de expectativa documentado quando a decisão alterar a redação original. Não eliminar o critério original da rastreabilidade.

## BIB — audita-planejamento-menu-biblioteca-documentos-v0.1.md

| ID | Critério original integral | Blocos | Decisão específica | Resultado |
|---|---|---|---|---|
| CA-01 | Nos quatro perfis, as abas Não conformidades, Planos de ação e Indicadores deixam de aparecer no menu lateral, inclusive recolhido e em tela menor. | B04 | Conforme B01 | Não executado |
| CA-02 | O item antigo é substituído por Biblioteca de documentos; os demais itens mantêm sua ordem e regras de acesso. | B04 | Conforme B01 | Não executado |
| CA-03 | Abrir a biblioteca pelo menu mostra os documentos, sem apresentar o histórico automaticamente, inclusive após visita anterior ao histórico. | B04 B05 | Conforme B01 | Não executado |
| CA-04 | O Administrador insere um arquivo válido e vê confirmação somente após concluir o envio. Falha de envio ou campo inválido não publica cadastro incompleto. | B05 | Conforme B01 | Não executado |
| CA-05 | Auditor Líder e Auditor localizam e baixam documentos permitidos; não veem ações de gestão e têm recusadas tentativas diretas de escrita. | B02 B05 | Conforme B01 | Não executado |
| CA-06 | O download entrega o arquivo e a revisão selecionados; um usuário sem autorização não consegue baixar usando o endereço direto. | B02 B05 | Conforme B01 | Não executado |
| CA-07 | O histórico abre somente mediante ação explícita no acesso proposto, permite voltar aos documentos e preserva os registros existentes. | B05 | Conforme B01 | Não executado |
| CA-08 | Se PC-03 for aprovada, o histórico não fica acessível ao Auditor Líder, Auditor ou Participante / Auditado, inclusive por acesso direto. | B02 B05 | D07 | Não executado |
| CA-09 | Se PC-04 for aprovada, rascunhos e arquivos retirados de uso não ficam disponíveis aos auditores; a nova revisão preserva o original anterior. | B05 | D07 | Não executado |
| CA-10 | Arquivos com formato ou tamanho fora das regras aprovadas são recusados com mensagem clara. | B05 | D07 | Não executado |
| CA-11 | Biblioteca vazia, busca sem resultado e falha de download têm mensagens próprias; erro de carregamento não aparece como ausência de documentos. | B05 | Conforme B01 | Não executado |
| CA-12 | Auditorias, relatórios, dados existentes e o histórico não são removidos ou modificados como efeito da retirada das três abas. | B04 B14 | Conforme B01 | Não executado |
| CA-13 | Se V-07 do planejamento de perfis for aprovada, o Participante não vê nem acessa a biblioteca corporativa, inclusive por endereço direto. Os relatórios autorizados da sua organização continuam acessíveis em Auditorias. | B02 B05 B12 | D07 | Não executado |

## PER — audita-planejamento-perfis-permissoes-dashboards-v0.1.md

| ID | Critério original integral | Blocos | Decisão específica | Resultado |
|---|---|---|---|---|
| PER-01 | Os quatro perfis aparecem com nomenclatura consistente; não surge um perfil separado chamado Administrativo. | B02 B04 | Conforme B01 | Não executado |
| PER-02 | Administrador acessa todas as organizações e executa operações de gestão e auditoria; sua autoria fica registrada. | B02 | D04 | Não executado |
| PER-03 | Auditor Líder cria auditoria, planeja, preenche checklist e valida relatórios diário e de encerramento nas auditorias sob sua responsabilidade. | B02 B06 B09 B11 | Conforme B01 | Não executado |
| PER-04 | Auditor acompanha auditorias da equipe e consulta os relatórios permitidos, mas não cria, conduz, assume responsabilidade ou valida, inclusive por acesso direto. | B02 | Conforme B01 | Não executado |
| PER-05 | Participante acompanha o planejamento disponibilizado e consulta relatórios validados, sem modificar dados ou realizar validações. | B02 B09 B12 | D01 D02 D10 | Não executado |
| PER-06 | Participante da empresa X não vê qualquer dado da empresa Y em telas, gráficos, totais, filtros, buscas, notificações, exportações ou arquivos. | B02 B13 B14 | Conforme B01 | Não executado |
| PER-07 | Trocar o identificador da empresa, auditoria, documento ou arquivo em uma solicitação não contorna as permissões. | B02 B14 | Conforme B01 | Não executado |
| PER-08 | Auditor Líder e Auditor não recebem acesso a outras auditorias de uma empresa apenas por participarem de uma auditoria daquela empresa. | B02 | Conforme B01 | Não executado |
| PER-09 | Relatório em rascunho não fica visível ao cliente. Após validação e disponibilização, a versão correta pode ser consultada. Falha de geração não libera conteúdo incompleto. | B09 B12 | Conforme B01 | Não executado |
| PER-10 | Nova revisão em elaboração não altera a versão já disponibilizada ao cliente; a mudança ocorre conforme o fluxo aprovado. | B09 B11 B12 | Conforme B01 | Não executado |
| PER-11 | Cada dashboard mostra somente o âmbito do perfil e os gráficos correspondentes. Os totais coincidem com a listagem autorizada sob os mesmos filtros. | B13 | Conforme B01 | Não executado |
| PER-12 | Ao clicar em um gráfico, o usuário abre apenas a lista de auditorias já autorizadas, com os filtros correspondentes. | B13 | Conforme B01 | Não executado |
| PER-13 | Auditor Líder vê sua responsabilidade atual e histórico permitido; Auditor vê suas participações. Nenhum deles recebe acesso global. | B02 B13 | D06 | Não executado |
| PER-14 | Contas desativadas e vínculos revogados deixam de permitir novos acessos conforme a regra de sessão e arquivos implementada e testada. | B02 B12 | Conforme B01 | Não executado |
| PER-15 | Trocar de usuário não reaproveita dados de dashboard ou arquivos da conta anterior. | B02 B13 | Conforme B01 | Não executado |
| PER-16 | Auditoria sem dados, período vazio e falha de carregamento produzem estados diferentes; falha não é apresentada como zero. Percentuais sem base não são inventados. | B13 | Conforme B01 | Não executado |
| PER-17 | Dashboards funcionam em tela menor, com rótulos legíveis, alternativas textuais aos gráficos e sem depender só da cor. | B13 | Conforme B01 | Não executado |
| PER-18 | Histórico de auditorias encerradas permanece disponível conforme os vínculos aprovados, sem reativar acesso explicitamente revogado. | B02 B12 B13 | D06 | Não executado |
| PER-19 | A biblioteca mantém inserção exclusiva do Administrador e download permitido ao Auditor Líder e Auditor; o cliente segue a decisão validada sobre acesso corporativo. | B02 B05 | D07 | Não executado |
| PER-20 | Meu Perfil não permite alterar o próprio perfil de acesso ou organização. A regra específica do Participante é respeitada. | B02 B04 | D05 | Não executado |

## PLA — audita-pro-planejamento-plano-auditoria-v0.1.md

| ID | Critério original integral | Blocos | Decisão específica | Resultado |
|---|---|---|---|---|
| PA-01 | Criar duas auditorias do mesmo cliente → Código do cliente permanece; códigos de auditoria são distintos | B03 B06 | D09 | Não executado |
| PA-02 | Cadastro simultâneo/cancelamento → Nenhum código duplicado, alterado manualmente ou reutilizado | B03 B06 | D09 | Não executado |
| PA-03 | Selecionar cliente → Código e endereço aparecem automaticamente | B06 | Conforme B01 | Não executado |
| PA-04 | Salvar rascunho incompleto → Permitido; validar continua bloqueado com indicação dos campos | B06 B09 | Conforme B01 | Não executado |
| PA-05 | Preencher cabeçalho → Todos os campos solicitados presentes; N/A aceito nos dois campos indicados | B06 | Conforme B01 | Não executado |
| PA-06 | Selecionar ISO 14001 + ISO 45001 → Uma auditoria, dois critérios e requisitos sem colisão de numeração | B06 | Conforme B01 | Não executado |
| PA-07 | Programar vários processos no mesmo dia → Linhas, locais, horários e auditores preservados | B07 | Conforme B01 | Não executado |
| PA-08 | Duplicar/copiar/reordenar linha → Nova atividade sem copiar execução ou multiplicar indevidamente requisitos | B07 | Conforme B01 | Não executado |
| PA-09 | Atividade fora do período ou horário inválido → Validação bloqueada com orientação clara | B07 B09 | Conforme B01 | Não executado |
| PA-10 | Mesmo auditor em horários sobrepostos → Aviso visível; não confundir com atividades simultâneas de equipes distintas | B07 | Conforme B01 | Não executado |
| PA-11 | FPA não recebido ou insuficiente → Impedir validação final, mantendo possibilidade de trabalhar no rascunho | B06 B09 | D09 | Não executado |
| PA-12 | FPA analisado → Versão usada e autoria da análise vinculadas à revisão do plano | B06 B09 | D09 | Não executado |
| PA-13 | Validar plano → Rev.00 congelada, PDF gerado e acesso disponibilizado uma única vez | B09 B08 | Conforme B01 | Não executado |
| PA-14 | Erro na geração/duplo clique → Retomar a mesma emissão, sem PDF quebrado nem revisão duplicada | B08 B09 | Conforme B01 | Não executado |
| PA-15 | Alterar plano publicado → Exigir motivo; emitir nova revisão e preservar PDF anterior | B09 | Conforme B01 | Não executado |
| PA-16 | Alterar cadastro do cliente → PDF antigo mantém cabeçalho original | B09 B08 | Conforme B01 | Não executado |
| PA-17 | Transferir trabalho após execução parcial → Preservar parcela realizada, origem, destino, motivo e reflexo no RDA | B07 B10 | Conforme B01 | Não executado |
| PA-18 | RDA emitido e plano revisado depois → RDA anterior permanece inalterado | B09 B11 | Conforme B01 | Não executado |
| PA-19 | Auditor de apoio designado na linha → Nome aparece; não ganha permissão de conduzir/editar automaticamente | B02 B07 | Conforme B01 | Não executado |
| PA-20 | Cliente de outra organização ou vínculo pendente → Acesso recusado, inclusive por URL/API/download | B02 B09 | D01 | Não executado |
| PA-21 | Plano com muitas linhas → Tabela legível, rodapé/paginação em todas as páginas e notas completas na última | B09 B08 | D08 | Não executado |
| PA-22 | Auditoria com dias não consecutivos → Datas reais e numeração do dia coerentes, sem gerar dias auditados vazios | B07 | Conforme B01 | Não executado |
| PA-23 | Duas sessões editando → Conflito detectado, sem sobrescrever alteração silenciosamente | B07 B09 | Conforme B01 | Não executado |
| PA-24 | Operação com único Administrador/condutor → Elaboração, validação e execução possíveis sem outro aprovador | B02 B09 | Conforme B01 | Não executado |

## RDA — audita-pro-planejamento-rda-v0.1.md

| ID | Critério original integral | Blocos | Decisão específica | Resultado |
|---|---|---|---|---|
| RDA-01 | Encerrar um dos cinco dias → Criar somente o RDA daquele dia, vinculado a empresa/auditoria/data | B11 | Conforme B01 | Não executado |
| RDA-02 | Pré-visualizar antes do fechamento → Conteúdo completo com gráficos, seleção de fotos e indicação de rascunho | B10 B11 | Conforme B01 | Não executado |
| RDA-03 | Outra sessão alterar dados após a prévia → Impedir fechamento silencioso e pedir atualização da revisão | B11 | Conforme B01 | Não executado |
| RDA-04 | Exemplo 55 C, 5 PC, 3 NC, 7 N/A e 30 pendentes → Exibir 70% processados; distinguir dia e acumulado | B03 B10 | D03 | Não executado |
| RDA-05 | Mesmo item salvo várias vezes → Não multiplicar contagens; preservar autoria/histórico | B03 | D03 | Não executado |
| RDA-06 | Mesmo requisito em dois processos → Contar as unidades previstas separadamente | B03 B10 | D03 | Não executado |
| RDA-07 | Escopo vazio ou totalmente N/A → Não dividir por zero nem apresentar falsa conformidade | B03 B10 | D03 | Não executado |
| RDA-08 | Atividade parcial e transferência repetida → Preservar execução, previsão anterior, motivos e trabalho restante | B07 B10 B11 | Conforme B01 | Não executado |
| RDA-09 | Item não conforme sem NC → Bloquear emissão e apontar o item a formalizar | B10 B11 | Conforme B01 | Não executado |
| RDA-10 | Selecionar duas de doze fotos → Publicar apenas duas, com legenda/referência e boa legibilidade | B10 B12 | Conforme B01 | Não executado |
| RDA-11 | Correção no dia seguinte → Rev.00 e seu PDF permanecem iguais; correção controlada gera Rev.01 | B11 B12 | Conforme B01 | Não executado |
| RDA-12 | Falha de PDF ou duplo clique → Preservar fechamento, permitir retomada e não duplicar documento/aviso | B08 B11 B12 | Conforme B01 | Não executado |
| RDA-13 | Gestor ativo autorizado sem presença → Consultar RDA emitido da própria organização | B02 B12 | D01 D02 | Não executado |
| RDA-14 | Conta pendente, inativa ou de outro cliente → Recusar consulta e download por API e URL | B02 B12 | D01 D02 | Não executado |
| RDA-15 | Novo leitor na organização → Consultar histórico emitido sem aparecer como participante dos dias | B02 B12 | D01 D02 | Não executado |
| RDA-16 | Publicar revisão substituta → Biblioteca abre vigente; histórico identifica anterior; avisos sem duplicidade | B12 | D10 | Não executado |
| RDA-17 | RDA com várias páginas → Cabeçalho, rodapé, numeração, gráficos e tabelas legíveis em todas | B08 B12 | D08 | Não executado |
| RDA-18 | Auditoria ainda em andamento → RDA não informa decisão de certificação nem gera relatório final | B10 B12 | Conforme B01 | Não executado |
| RDA-19 | Aplicar mudança de autorização → Não ampliar acesso a evidências originais, atas ou finais por acidente | B02 B12 | D01 | Não executado |
| RDA-20 | Abrir documento legado → Preservar sua fórmula, conteúdo e arquivo originais | B03 B12 | Conforme B01 | Não executado |
| RDA-21 | Um único profissional Administrador/condutor → Concluir o fluxo sem precisar criar aprovador fictício | B02 B11 | Conforme B01 | Não executado |

## Critérios transversais adicionais

- BASE-01: frontend e sequência de migrations conciliados, sem reaplicar as dez migrations remotas.
- SEG-01: permissões testadas por RPC, consulta direta e arquivo; combinar policies permissivas/restritivas corretamente.
- MET-01: contrato 3 distingue pergunta/processo, requisito e atividade; nenhuma mudança retroativa de fórmula.
- HIST-01: retificação anterior não incorpora trabalho de dia posterior; hash de versão emitida preservado.
- OPS-01: backup inclui banco e arquivos; restauração testada em ambiente apropriado antes da liberação.
- UX-01: link entregue responde e abre a aplicação atualizada; localhost só após servidor verificado.
- COB-01: todas as linhas normativas da matriz têm implementação/evidência ou decisão explícita de escopo, sem conclusão fictícia.
