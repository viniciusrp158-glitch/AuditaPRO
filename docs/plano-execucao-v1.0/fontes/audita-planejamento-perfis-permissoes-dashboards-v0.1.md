# Audita PRO — Planejamento dos perfis, permissões e dashboards

**Versão:** 0.1  
**Data:** 07/10/2026  
**Situação:** proposta para validação  
**Execução:** nenhuma alteração no sistema autorizada ou realizada nesta etapa  
**Formato de referência:** Markdown; Word e PDF somente mediante solicitação explícita

## 1. Objetivo e relação com os planejamentos anteriores

Definir o funcionamento dos quatro perfis definitivos do Audita PRO e a visão de cada um no Dashboard e nas demais abas. O acesso deve considerar a função do usuário, seu vínculo com a auditoria e, no caso do cliente, sua organização. O dashboard deve apresentar informações úteis à gestão, com gráficos claros e sem excesso de elementos.

Este planejamento se baseia na definição fornecida pelo usuário. Não houve inspeção do código, banco de dados ou configuração atual das permissões. As etapas técnicas abaixo são propostas para a implementação futura e deverão ser adaptadas à estrutura existente, após autorização.

Mantém-se o planejamento de retirar do menu as abas **Não conformidades**, **Planos de ação** e **Indicadores**, e substituir **Biblioteca / histórico** por **Biblioteca de documentos**. A retirada da aba Indicadores não impede a apresentação de indicadores e gráficos no Dashboard.

A [proposta de menu e biblioteca v0.2](audita-planejamento-menu-biblioteca-documentos-v0.2.md) incorpora os quatro perfis e deve ser lida em conjunto com este arquivo. Nenhum desses planejamentos representa implementação concluída.

### 1.1 O que está definido e o que depende de validação

- **Definido pelo usuário:** os quatro perfis, os poderes gerais do Administrador, a condução pelo Auditor Líder, a atuação de apoio do Auditor, a consulta sem alterações pelo Participante / Auditado e as visões de dashboard descritas neste documento.
- **Proposto para validação:** detalhes de atribuição de equipe, acesso histórico, visibilidade de rascunhos, gráficos e cálculos, download pelo cliente e permissões complementares não especificadas no pedido.

As decisões propostas estão reunidas na seção 12. Elas não devem ser tratadas como autorizações já concedidas.

## 2. Perfis definitivos

| Perfil | Finalidade | Regra principal |
| --- | --- | --- |
| Administrador | Administrar e operar todo o sistema. | Acesso geral a todas as organizações, auditorias, documentos, usuários e configurações, com todas as permissões funcionais. |
| Auditor Líder | Ser responsável pela auditoria e conduzi-la do planejamento ao encerramento. | Criar auditoria, elaborar planejamento, conduzir e preencher checklist, validar relatórios diários e relatório de encerramento. |
| Auditor | Apoiar o Auditor Líder como integrante da equipe. | Acompanhar auditorias das quais participa e acessar seus relatórios; não conduzir sozinho, assumir responsabilidade ou validar relatórios. |
| Participante / Auditado | Acompanhar, como cliente, o processo de auditoria da sua organização. | Consulta sem alterações, do planejamento disponibilizado ao encerramento, com acesso apenas aos relatórios validados. |

“Administrativo” será tratado como referência ao perfil **Administrador**, sem criar um quinto perfil. Na interface, utilizar os quatro nomes acima de forma consistente.

O acesso geral do Administrador inclui criar, planejar, conduzir, alterar e validar auditorias, além de gerir usuários e documentos. Suas ações devem registrar o autor real. Quando uma alteração atingir um relatório já emitido, preservar a versão anterior e registrar a nova revisão; acesso geral não deve apagar a rastreabilidade nem atribuir a ação a outra pessoa.

## 3. Vínculos que determinam o acesso

### 3.1 Auditoria, organização e equipe

Cada auditoria deve estar vinculada a uma organização e permitir identificar seu responsável, os auditores de apoio e os participantes autorizados. A organização que está sendo auditada deve ser distinguida da AUDITA, que administra o sistema.

| Perfil | Conjunto de auditorias acessível |
| --- | --- |
| Administrador | Todas as auditorias do sistema. |
| Auditor Líder | Auditorias que criou sob sua responsabilidade ou para as quais foi designado responsável, incluindo as encerradas cujo acesso histórico permaneça autorizado. |
| Auditor | Auditorias em cuja equipe foi incluído, incluindo as encerradas cujo acesso histórico permaneça autorizado. |
| Participante / Auditado | Somente auditorias da organização à qual está vinculado; propõe-se exigir também liberação específica da auditoria para esse participante. |

**Regra obrigatória:** pertencer à empresa X nunca permite visualizar auditorias, relatórios ou dados da empresa Y.

Para Auditor Líder e Auditor, ter acesso a uma auditoria de determinada empresa não concede automaticamente acesso a todas as outras auditorias dessa empresa. A visão por organização deve agrupar apenas as auditorias autorizadas ao usuário.

**Propostas de vínculo para validação:**

- Um perfil principal por conta nesta etapa, com um responsável principal por auditoria. O Administrador pode operar qualquer auditoria, sem que isso troque automaticamente seu responsável.
- Um Participante / Auditado vinculado a uma organização por vez. Necessidades de múltiplas empresas ou grupos empresariais devem ser definidas explicitamente antes de ampliar o acesso.
- O Administrador define perfis, vínculos organizacionais, acessos de clientes e transferências de responsabilidade.
- O Auditor Líder pode selecionar auditores de apoio já cadastrados e habilitados para a auditoria sob sua responsabilidade. Essa ação não permite criar usuários, alterar perfis ou conceder acesso de cliente a outra empresa.
- Encerrar uma auditoria mantém o acesso histórico dos integrantes autorizados, necessário aos dashboards solicitados. Remover ou revogar um vínculo deve impedir novos acessos, sem apagar os registros de participação e autoria.

### 3.2 Regra de decisão de acesso

Antes de apresentar qualquer informação, verificar:

1. O usuário está autenticado e ativo?
2. O perfil permite a ação solicitada?
3. O usuário pode acessar a organização e a auditoria em questão?
4. O documento está em uma situação permitida para esse usuário?

Para o Administrador, a abrangência é geral. Para os demais perfis, todos os vínculos e limites aplicáveis devem ser respeitados. A mesma regra vale para telas, buscas, gráficos, contadores, notificações, exportações, relatórios e arquivos.

## 4. Visão das abas por perfil

| Aba | Administrador | Auditor Líder | Auditor | Participante / Auditado |
| --- | --- | --- | --- | --- |
| Dashboard | Visão geral de todo o sistema. | Gestão das auditorias sob sua responsabilidade, em andamento e históricas. | Visão das auditorias de cuja equipe participa ou participou. | Acompanhamento das auditorias autorizadas da própria organização. |
| Auditorias | Acesso e operação geral. | Criação, planejamento, condução e validações no seu âmbito de responsabilidade. | Acompanhamento das auditorias da equipe; sem condução ou validação. | Consulta do planejamento e das informações disponibilizadas; relatórios somente validados. |
| Usuários | Cadastro, edição, ativação, desativação, perfis e vínculos. | Sem acesso à administração de usuários, conforme proposta. | Sem acesso, conforme proposta. | Sem acesso, conforme proposta. |
| Biblioteca de documentos | Cadastro, download e gestão dos padrões corporativos. | Consulta e download dos documentos disponibilizados. | Consulta e download dos documentos disponibilizados. | Sem acesso à biblioteca corporativa interna, conforme proposta. |
| Meu Perfil | Consulta e manutenção dos próprios dados permitidos. | Consulta e manutenção dos próprios dados permitidos. | Consulta e manutenção dos próprios dados permitidos. | Consulta dos próprios dados; controles pessoais de acesso conforme decisão da seção 12. |

O histórico de modificações do sistema continua como acesso secundário dentro da Biblioteca, somente após clique. Sua disponibilização exclusiva ao Administrador permanece uma proposta para validação. Não criar uma nova aba lateral de histórico.

Os documentos específicos do cliente serão acessados dentro da respectiva auditoria. Eles não devem ser confundidos com os modelos internos da biblioteca corporativa.

## 5. Permissões dentro de Auditorias

| Operação | Administrador | Auditor Líder | Auditor | Participante / Auditado |
| --- | --- | --- | --- | --- |
| Iniciar uma nova auditoria | Sim. | Sim, assumindo a responsabilidade inicial. | Não. | Não. |
| Elaborar e alterar o planejamento | Sim. | Sim, nas auditorias sob sua responsabilidade. | Consulta; contribuição de apoio a definir. | Consulta da versão disponibilizada. |
| Selecionar equipe de apoio | Sim. | Proposto: usuários já habilitados, sem gestão de contas. | Não. | Não. |
| Conduzir auditoria e preencher checklist oficial | Sim. | Sim. | Não nesta proposta inicial. | Não. |
| Ser responsável principal pela auditoria | Sim, se formalmente designado. | Sim. | Não. | Não. |
| Registrar observações ou anexos de apoio | Sim. | Sim. | Permissão não definida; proposta inicial sem escrita. | Não. |
| Consultar checklist e evidências internas | Sim. | Sim, no seu âmbito. | Proposto: consulta nas auditorias da equipe. | Não; somente informações incluídas nos documentos disponibilizados. |
| Consultar relatórios diários e de encerramento | Sim, inclusive rascunhos. | Sim, inclusive rascunhos das suas auditorias. | Sim; proposta inicial de acesso às versões validadas. | Somente versões validadas e disponibilizadas da própria organização. |
| Validar relatório diário | Sim, com registro de quem validou. | Sim, nas suas auditorias. | Não. | Não. |
| Validar relatório de encerramento | Sim, com registro de quem validou. | Sim, nas suas auditorias. | Não. | Não. |
| Encerrar ou reabrir auditoria | Sim, com registro. | Proposto: encerrar após as validações necessárias; reabertura reservada ao Administrador. | Não. | Não. |
| Baixar documentos da auditoria | Sim. | Sim, conforme acesso à auditoria. | Proposto: versões disponibilizadas da auditoria. | Visualização definida; download depende de validação. |

### 5.1 Apoio do Auditor

O usuário definiu que o Auditor presta apoio, mas não especificou se esse apoio inclui escrever observações, anexar evidências ou preparar conteúdo para revisão. Não conceder essas permissões por inferência.

**Proposta inicial:** acompanhamento e consulta, sem alteração do checklist oficial, validação ou responsabilidade pela auditoria. Caso seja necessário registrar contribuições, criar permissões específicas de apoio. Essas contribuições devem ter autoria própria e depender da análise do Auditor Líder, sem conceder condução ou publicação autônoma.

Mesmo sem permissão de escrita, o Auditor terá a visão de equipe e o dashboard das auditorias em que participa, conforme solicitado.

### 5.2 Participante / Auditado

O Participante / Auditado não cria nem modifica planejamento, respostas, checklist, evidências, relatórios, equipe, situações ou configurações. Não atribuir ao cliente ações de validação, encerramento, aprovação ou ciência que alterem o processo sem nova definição expressa.

Seu acompanhamento deve apresentar o planejamento disponibilizado, a etapa atual, o cronograma divulgado e os relatórios já validados. Resultados provisórios, anotações internas e rascunhos permanecem fora dessa visão.

## 6. Disponibilização do planejamento e dos relatórios

Propõe-se separar a preparação interna da versão disponibilizada para consulta. Antes de implementar, verificar e reaproveitar o fluxo existente; não criar estados duplicados para eventos que já possuem controle no sistema.

1. O Auditor Líder prepara ou revisa o planejamento e confirma a versão a disponibilizar ao cliente. Esse passo é proposto porque o usuário não definiu o momento de liberação do planejamento.
2. Durante a execução, o Auditor Líder preenche o checklist e prepara o relatório diário conforme o processo existente.
3. O relatório diário só fica disponível ao Participante / Auditado após a validação do Auditor Líder e a conclusão de sua disponibilização.
4. O relatório de encerramento segue a mesma regra: o cliente acessa a versão validada e disponibilizada.
5. O Administrador tem permissão para executar essas operações. Quando atuar, o registro identifica o Administrador como autor/validador, sem apresentar a ação como se tivesse sido realizada pelo Auditor Líder.

Se existir geração de arquivo após a validação, uma falha nessa geração não deve disponibilizar arquivo incompleto nem versão anterior como se fosse a nova. O cliente verá a última versão validada e disponibilizada, ou a indicação de que ainda não há relatório disponível.

Uma nova revisão em rascunho não deve substituir silenciosamente a última versão disponibilizada. Correções precisam preservar a versão anterior e indicar qual é a atual. A etapa operacional da auditoria e a situação documental do relatório são informações distintas.

## 7. Dashboards por perfil

### 7.1 Princípios comuns

Cada dashboard deve começar por um resumo do âmbito de acesso, por exemplo: “Visão geral do sistema”, “Auditorias sob minha responsabilidade”, “Auditorias da minha equipe” ou o nome da organização do cliente.

**Composição visual proposta:** até quatro cartões de resumo, dois gráficos principais e uma lista de auditorias ou uma linha do tempo. Usar cores consistentes, legendas e valores legíveis. O significado não pode depender apenas da cor. Evitar gráficos 3D, excesso de setores, animações decorativas e painéis com muitos blocos simultâneos.

Gráficos devem permitir abrir a listagem correspondente sem ampliar as permissões. Exibir período, filtros ativos e data de atualização. Em telas menores, reorganizar os blocos sem perder rótulos ou controles.

### 7.2 Administrador — visão geral

**Âmbito:** todas as organizações e auditorias do sistema.

| Elemento proposto | Informação e finalidade |
| --- | --- |
| Cartões | Organizações com auditorias no recorte; auditorias em planejamento; em andamento; encerradas. |
| Gráfico de rosca | Distribuição das auditorias por etapa, com quantidade e percentual de cada grupo. |
| Gráfico de barras | Volume de auditorias por organização, com opção de alternar para tipo de auditoria. |
| Lista de atenção | Próximas auditorias, auditorias com prazo ultrapassado e relatórios aguardando validação, quando houver dados confiáveis para essas situações. |
| Filtros | Período, organização, tipo de auditoria, responsável e etapa. |
| Atalhos | Abrir auditoria, iniciar auditoria e acessar gestão de usuários/documentos. |

A visão geral deve reunir a carteira de auditorias e os pontos que exigem ação administrativa. O Administrador pode abrir os detalhes de qualquer organização ou auditoria.

### 7.3 Auditor Líder — gestão das próprias auditorias

**Âmbito:** auditorias sob sua responsabilidade e histórico autorizado das auditorias que conduziu.

| Elemento proposto | Informação e finalidade |
| --- | --- |
| Cartões | Empresas auditadas no recorte; auditorias em andamento; encerradas; relatórios pendentes de sua validação. |
| Gráfico de barras por organização | Distribuição das suas auditorias por empresa, distinguindo as etapas. |
| Gráfico por tipo de auditoria | Quantidade por tipo, para acompanhar a composição das auditorias que conduz ou já conduziu. |
| Lista de trabalho | Auditorias em andamento, próxima atividade planejada e relatórios que aguardam sua validação. |
| Filtros | Período, organização, tipo de auditoria e etapa, restritos à sua carteira. |
| Atalhos | Nova auditoria, planejamento, checklist e validações permitidas. |

O Auditor Líder não deve ver totais globais da AUDITA nem auditorias conduzidas por outros responsáveis às quais não tenha acesso. Uma transferência de responsabilidade deve atualizar a lista de trabalho; a manutenção do histórico pessoal seguirá a decisão sobre vínculos históricos.

### 7.4 Auditor — acompanhamento da equipe

**Âmbito:** auditorias em cuja equipe participa ou participou, com acesso histórico autorizado.

| Elemento proposto | Informação e finalidade |
| --- | --- |
| Cartões | Empresas em que participou; auditorias em andamento; encerradas; relatórios disponibilizados no recorte. |
| Gráfico de barras por organização | Participações em auditorias por empresa e etapa. |
| Gráfico por tipo de auditoria | Distribuição dos tipos das auditorias de que participa ou participou. |
| Lista de acompanhamento | Auditorias da equipe, Auditor Líder responsável, próximas datas e relatórios disponíveis. |
| Filtros | Período, organização, tipo de auditoria e etapa, restritos às suas participações. |
| Atalhos | Acompanhar auditoria e consultar documentos permitidos. |

O visual pode ser semelhante ao do Auditor Líder, mas não deve apresentar “Conduzir”, “Validar”, “Nova auditoria” ou comandos equivalentes. Não apresentar relatórios pendentes como tarefa de validação do Auditor.

### 7.5 Participante / Auditado — acompanhamento da própria organização

**Âmbito:** sua organização e as auditorias liberadas para consulta, conforme a regra a validar.

| Elemento proposto | Informação e finalidade |
| --- | --- |
| Identificação | Nome da organização e auditoria selecionada; seletor apenas entre auditorias autorizadas dessa organização. |
| Cartões | Etapa atual; próxima atividade divulgada; relatórios diários validados disponíveis; situação do relatório de encerramento. |
| Linha do tempo | Planejamento disponibilizado, execução, relatórios diários e encerramento. Destacar etapas realizadas e próximas etapas sem sugerir que algo pendente já foi validado. |
| Gráfico de progresso | Progresso do cronograma divulgado, somente quando houver regra e dados suficientes para calculá-lo. Sem base confiável, mostrar etapas e datas, sem percentual. |
| Lista de documentos | Planejamento disponibilizado, relatórios diários validados e relatório de encerramento validado. |
| Filtros | Auditoria, período e tipo, quando houver mais de uma auditoria autorizada e esses filtros forem úteis. Nenhum seletor de outras organizações. |
| Atalhos | Consultar planejamento e abrir relatórios permitidos. |

O cliente não deve visualizar comparações com outras empresas, avaliações provisórias do checklist, rascunhos ou pendências internas da equipe. “Relatório ainda não disponibilizado” é diferente de “auditoria sem resultados”.

## 8. Definição dos indicadores e gráficos

As métricas devem ser calculadas a partir dos registros reais e somente depois de aplicar os limites de acesso. Os estados operacionais existentes deverão ser mapeados para as etapas exibidas, sem alterar sua lógica apenas para alimentar os gráficos.

| Indicador | Regra proposta |
| --- | --- |
| Total de auditorias | Quantidade de auditorias distintas acessíveis no recorte. Uma auditoria com vários membros continua contando uma vez para cada visão aplicável. |
| Empresas auditadas ou com participação | Quantidade de organizações distintas presentes nas auditorias do recorte autorizado. Não contar o cadastro global de clientes para usuários sem acesso geral. |
| Auditorias por etapa | Contar cada auditoria em sua etapa atual. Cancelamentos, quando existentes, ficam identificados separadamente, sem serem tratados como encerramentos concluídos. |
| Auditorias por organização ou tipo | Agrupar as mesmas auditorias do recorte, incluindo “Não informado” para dados ausentes. Não inventar a classificação. |
| Relatórios pendentes de validação | Relatórios na etapa efetiva de aguardar validação, restritos à responsabilidade do usuário; Administrador pode ver o total geral. |
| Relatórios disponibilizados | Documentos lógicos distintos cuja versão foi validada e disponibilizada, sem contar cada revisão como um novo relatório. |
| Auditoria com prazo ultrapassado | Data prevista de encerramento anterior à data atual e auditoria ainda ativa. Registros sem prazo não serão classificados automaticamente como atrasados. |
| Progresso do cronograma divulgado | Atividades concluídas e divulgadas ÷ total de atividades válidas do cronograma divulgado × 100. Sem denominador válido, mostrar “Progresso não calculado”. |

**Período proposto:** para a visão da carteira, filtrar auditorias pela data de início prevista, incluindo as encerradas quando pertencem ao recorte. Disponibilizar “Todo o histórico” e uma opção explícita de acompanhar todas as auditorias em andamento. Relatórios e outros indicadores de eventos devem informar a data utilizada e respeitar o recorte selecionado. Confirmar essas regras na validação antes de implementá-las.

Não introduzir índice de conformidade, nota de desempenho do cliente ou percentual de conclusão baseado apenas em preenchimento de checklist sem uma regra de negócio aprovada. Progresso operacional não significa aprovação de resultados.

Gráficos com muitas organizações devem mostrar, por exemplo, as cinco principais e agrupar o restante em “Outras”, sempre dentro do âmbito autorizado. Uma tabela ou listagem detalhada deve permitir consultar o conjunto completo permitido.

## 9. Isolamento e segurança dos dados

O isolamento por organização é requisito funcional, não apenas uma diferença visual entre dashboards.

- Aplicar as permissões no servidor e na camada de acesso aos dados, além de ocultar controles indevidos na interface.
- Verificar organização, auditoria e permissão antes de entregar registros ou arquivos. Não confiar no identificador de organização enviado pela tela.
- Filtrar os dados antes de calcular totais, percentuais e gráficos. Um cliente não pode descobrir a existência de outra empresa por contagens, filtros, buscas ou mensagens de erro.
- Aplicar a mesma verificação a relatórios, evidências, endereços diretos, exportações, notificações e buscas auxiliares. Rascunhos e evidências internas não ficam acessíveis ao cliente por conhecer o endereço do arquivo.
- Armazenar arquivos de acesso restrito de forma privada. Autorizações e links de download devem respeitar perfil, vínculo e validade; links antigos não podem se tornar públicos ou permanentes por conveniência.
- Separar dados temporários e resultados armazenados em cache por usuário, permissões e filtros. A troca de conta não pode mostrar dados da sessão anterior.
- Atualizar o acesso quando uma conta for desativada, um perfil for alterado ou um vínculo for revogado. Definir e testar a invalidação de sessões e a validade de links temporários já emitidos; não prometer revogação instantânea de arquivos já baixados.
- Impedir que alterações em Meu Perfil elevem permissões ou troquem a organização. Gestão desses campos pertence ao Administrador.
- Registrar mudanças relevantes de perfil, equipe, responsabilidade, organização e validação, identificando o usuário que realmente executou a ação.

## 10. Etapas propostas para implementação

| Etapa | Trabalho previsto | Resultado esperado |
| --- | --- | --- |
| 1. Validar as regras | Confirmar matriz de permissões, propostas complementares e dashboards. | Escopo funcional acordado. |
| 2. Levantar o funcionamento existente | Conferir perfis atuais, vínculos, menus, estados da auditoria, validação de relatórios, arquivos e origem dos dados dos gráficos. | Mapa do que pode ser reaproveitado e das diferenças a corrigir. |
| 3. Mapear os usuários existentes | Relacionar cada conta ao perfil definitivo e à organização/equipe correta, sem conversão automática ambígua. | Relação revisada pelo Administrador antes de aplicar mudanças. |
| 4. Implementar as autorizações | Centralizar as verificações de perfil, organização, auditoria e documento; proteger também os arquivos. | Permissões efetivas antes da liberação das novas telas. |
| 5. Ajustar Auditorias e disponibilização | Aplicar operações por perfil, responsabilidade, validações e consulta do cliente. | Fluxo completo do planejamento ao encerramento. |
| 6. Ajustar menu, Usuários, Biblioteca e Meu Perfil | Aplicar visibilidade e permissões consistentes com os quatro perfis e o planejamento da biblioteca. | Navegação coerente, sem as três abas removidas. |
| 7. Construir os dashboards | Implementar consultas autorizadas, cálculos, filtros, gráficos e estados de tela. | Visão específica e útil para cada perfil. |
| 8. Testar e homologar | Executar cenários de autorização e isolamento com pelo menos duas organizações. | Evidências de que cada perfil acessa somente o permitido. |
| 9. Liberar após autorização | Aplicar de forma controlada, conferir contas e dados e acompanhar erros. | Mudança liberada com possibilidade de recuperação. |

Antes de aplicar mudanças em dados existentes, preparar cópia de segurança e procedimento de recuperação. Preservar autoria e participação histórica. Contas sem mapeamento confiável não devem receber acesso amplo como solução provisória; a situação deve ser apresentada ao Administrador.

A reversão de telas ou cálculos não deve reabrir acessos entre organizações. A estratégia de recuperação precisa preservar as restrições de segurança. Prazos, tecnologias e mudanças de estrutura serão definidos após o levantamento, sem presumir uma arquitetura que ainda não foi verificada.

## 11. Critérios de aceite

| ID | Cenário e resultado esperado |
| --- | --- |
| PER-01 | Os quatro perfis aparecem com nomenclatura consistente; não surge um perfil separado chamado Administrativo. |
| PER-02 | Administrador acessa todas as organizações e executa operações de gestão e auditoria; sua autoria fica registrada. |
| PER-03 | Auditor Líder cria auditoria, planeja, preenche checklist e valida relatórios diário e de encerramento nas auditorias sob sua responsabilidade. |
| PER-04 | Auditor acompanha auditorias da equipe e consulta os relatórios permitidos, mas não cria, conduz, assume responsabilidade ou valida, inclusive por acesso direto. |
| PER-05 | Participante acompanha o planejamento disponibilizado e consulta relatórios validados, sem modificar dados ou realizar validações. |
| PER-06 | Participante da empresa X não vê qualquer dado da empresa Y em telas, gráficos, totais, filtros, buscas, notificações, exportações ou arquivos. |
| PER-07 | Trocar o identificador da empresa, auditoria, documento ou arquivo em uma solicitação não contorna as permissões. |
| PER-08 | Auditor Líder e Auditor não recebem acesso a outras auditorias de uma empresa apenas por participarem de uma auditoria daquela empresa. |
| PER-09 | Relatório em rascunho não fica visível ao cliente. Após validação e disponibilização, a versão correta pode ser consultada. Falha de geração não libera conteúdo incompleto. |
| PER-10 | Nova revisão em elaboração não altera a versão já disponibilizada ao cliente; a mudança ocorre conforme o fluxo aprovado. |
| PER-11 | Cada dashboard mostra somente o âmbito do perfil e os gráficos correspondentes. Os totais coincidem com a listagem autorizada sob os mesmos filtros. |
| PER-12 | Ao clicar em um gráfico, o usuário abre apenas a lista de auditorias já autorizadas, com os filtros correspondentes. |
| PER-13 | Auditor Líder vê sua responsabilidade atual e histórico permitido; Auditor vê suas participações. Nenhum deles recebe acesso global. |
| PER-14 | Contas desativadas e vínculos revogados deixam de permitir novos acessos conforme a regra de sessão e arquivos implementada e testada. |
| PER-15 | Trocar de usuário não reaproveita dados de dashboard ou arquivos da conta anterior. |
| PER-16 | Auditoria sem dados, período vazio e falha de carregamento produzem estados diferentes; falha não é apresentada como zero. Percentuais sem base não são inventados. |
| PER-17 | Dashboards funcionam em tela menor, com rótulos legíveis, alternativas textuais aos gráficos e sem depender só da cor. |
| PER-18 | Histórico de auditorias encerradas permanece disponível conforme os vínculos aprovados, sem reativar acesso explicitamente revogado. |
| PER-19 | A biblioteca mantém inserção exclusiva do Administrador e download permitido ao Auditor Líder e Auditor; o cliente segue a decisão validada sobre acesso corporativo. |
| PER-20 | Meu Perfil não permite alterar o próprio perfil de acesso ou organização. A regra específica do Participante é respeitada. |

Os testes devem utilizar contas dos quatro perfis, organizações X e Y, auditorias diferentes dentro de uma mesma organização e relatórios em rascunho e validados. Incluir uma conta removida da equipe, uma conta desativada e uma transferência de responsabilidade. Testes positivos devem ser acompanhados por tentativas de acesso indevido; conferir apenas o menu não comprova isolamento.

## 12. Decisões propostas para validação

Os poderes gerais dos quatro perfis e o isolamento entre empresas já foram definidos pelo usuário. As decisões abaixo detalham os pontos que permanecem abertos.

| ID | Ponto | Proposta inicial |
| --- | --- | --- |
| V-01 | Escrita pelo Auditor de apoio | Consulta sem escrita nesta primeira etapa. Se necessário, autorizar separadamente observações/anexos de apoio, sem alterar o checklist oficial ou validar. |
| V-02 | Rascunhos de relatórios para o Auditor | Acesso inicialmente às versões validadas; leitura de rascunhos internos somente se aprovada. |
| V-03 | Auditorias visíveis ao Participante | Organização correta mais liberação específica por auditoria. Alternativa a decidir: todas as auditorias da própria organização. |
| V-04 | Responsável e equipe | Um responsável principal; Auditor Líder seleciona apenas auditores de apoio já habilitados. Administrador controla perfis, acesso do cliente e transferência de responsabilidade. |
| V-05 | Visibilidade do planejamento ao cliente | Disponibilizar após confirmação do responsável, preservando as versões anteriores. |
| V-06 | Download pelo Participante | Manter a visualização solicitada. Habilitar download de versões validadas somente se aprovado; documentos corporativos internos continuam separados. |
| V-07 | Biblioteca e histórico para o cliente | Não exibir biblioteca corporativa nem histórico do sistema ao Participante. Histórico do sistema exclusivo do Administrador. |
| V-08 | Encerramento e reabertura | Auditor Líder encerra após as validações do processo; Administrador pode encerrar e reabrir, com registro. |
| V-09 | Acesso histórico | Preservar consultas às auditorias concluídas para responsáveis e integrantes autorizados; revogação explícita prevalece. Detalhar a consulta do antigo responsável após transferência. |
| V-10 | Organização e perfis por conta | Um perfil principal e uma organização por Participante nesta etapa; exceções multiempresa exigem definição específica. |
| V-11 | Meu Perfil do Participante | Dados funcionais e organização apenas para consulta. Permitir troca de senha/recuperação de acesso como manutenção da própria conta, sem alterar dados da auditoria, se confirmado. |
| V-12 | Gráficos e período | Adotar os blocos das seções 7 e 8, com até quatro cartões e dois gráficos; confirmar a data-base do filtro, o recorte inicial e a regra de progresso do cronograma divulgado. |

**Próximo passo:** revisar este planejamento, registrar os ajustes e definir a versão aprovada. A implementação deverá começar somente após autorização para executar no sistema.

## 13. Histórico do planejamento

| Versão | Data | Alteração |
| --- | --- | --- |
| 0.1 | 07/10/2026 | Proposta inicial dos quatro perfis, permissões, visões por aba, dashboards, isolamento entre organizações e etapas de implementação. Aguardando validação. |
