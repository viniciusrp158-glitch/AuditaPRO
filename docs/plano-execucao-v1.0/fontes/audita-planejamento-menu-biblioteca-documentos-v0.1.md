# Audita PRO — Planejamento do menu e da biblioteca de documentos

**Versão:** 0.2  
**Data:** 07/10/2026  
**Situação:** proposta para validação  
**Execução no sistema:** não autorizada nesta etapa

Esta versão atualiza a proposta v0.1 para considerar os quatro perfis definitivos. Deve ser lida em conjunto com o [planejamento de perfis, permissões e dashboards v0.1](audita-planejamento-perfis-permissoes-dashboards-v0.1.md). A versão anterior permanece preservada. Word e PDF serão produzidos somente mediante solicitação explícita.

O Administrador possui acesso geral ao sistema. Auditor Líder conduz auditorias sob sua responsabilidade; Auditor participa como apoio; Participante / Auditado acompanha apenas as auditorias autorizadas da própria organização, sem modificar dados. Para a biblioteca corporativa, o acesso do Participante continua não concedido nesta proposta, sujeito à validação. Os relatórios específicos do cliente são acessados em Auditorias.

Esta proposta define a retirada de três abas do menu lateral e a transformação de “Biblioteca / histórico” em “Biblioteca de documentos”. A biblioteca será o local de acesso aos documentos padrão da AUDITA, com inserção exclusiva pelo administrador e consulta para download pelos perfis Auditor Líder e Auditor.

O histórico de modificações do sistema ficará separado da listagem de documentos e será exibido somente após o usuário acionar o botão correspondente, dentro da biblioteca. Este documento é submetido à validação antes de qualquer alteração no sistema.

## 1. Objetivo e base da proposta

Organizar a navegação do Audita PRO e disponibilizar os documentos corporativos em uma biblioteca com permissões claras. A base desta proposta é a solicitação do usuário e a imagem fornecida do menu atual. O padrão documental AUDITA em elaboração orienta a apresentação e o cuidado com revisões e situação dos arquivos.

A imagem confirma os rótulos atuais do menu, mas não demonstra as permissões, rotas, estrutura de armazenamento ou funcionamento interno do histórico. Esses aspectos deverão ser conferidos na etapa de implementação, após autorização.

### 1.1 Requisitos solicitados e propostas complementares

Os requisitos identificados como RS correspondem ao pedido apresentado. As regras identificadas como PC são propostas complementares para tornar o funcionamento verificável e devem ser confirmadas na validação. Aprovar esta especificação e autorizar a execução são decisões distintas.

Escopo desta entrega: especificação para validação. Nenhuma tela, dado, permissão ou arquivo do sistema foi alterado. Não foi realizado upload dos documentos já produzidos.

## 2. Alterações no menu lateral

| Item atual | Tratamento solicitado |
| --- | --- |
| Dashboard | Manter. |
| Auditorias | Manter. |
| Não conformidades | RS-01 — Retirar a aba do menu lateral. |
| Planos de ação | RS-02 — Retirar a aba do menu lateral. |
| Indicadores | RS-03 — Retirar a aba do menu lateral. |
| Usuários | Manter, respeitando as permissões existentes. |
| Biblioteca / histórico | RS-04 — Renomear para “Biblioteca de documentos”. |
| Meu Perfil | Manter. |

A ordem proposta do menu é: Dashboard, Auditorias, Usuários, Biblioteca de documentos e Meu Perfil. Os itens devem continuar condicionados ao perfil do usuário, sem ampliar o acesso a Usuários ou a qualquer outra funcionalidade.

As três abas removidas não devem aparecer no menu lateral expandido, recolhido ou adaptado para dispositivos móveis. O novo nome da biblioteca deve ser aplicado também ao título da página e aos elementos de navegação que a identificam.

### 2.1 Limite da retirada das abas

PC-01 — A alteração solicitada é tratada como retirada de entradas da navegação. Não inclui excluir registros de não conformidades, planos de ação ou indicadores, nem remover dados ou funcionalidades internas utilizadas em auditorias e relatórios. Antes da implementação, verificar dependências e atalhos existentes.

A desativação completa de módulos ou o bloqueio de suas rotas antigas não está definido pelo pedido. Caso esse também seja o objetivo, deverá ser aprovado como ampliação de escopo, com avaliação dos dados e processos afetados. Ocultar uma aba não substitui a autorização de acesso às funcionalidades existentes.

## 3. Página inicial da biblioteca

RS-05 — Ao clicar em “Biblioteca de documentos”, abrir diretamente a listagem dos documentos corporativos disponíveis ao usuário. O histórico de modificações não deve aparecer automaticamente, nem misturado aos documentos ou aberto como área inicial.

| Elemento | Comportamento esperado |
| --- | --- |
| Título | Biblioteca de documentos. |
| Área principal | Lista dos documentos padrão da AUDITA, com identificação e opção de download. |
| Inserir documento | RS-06 — Botão exclusivo do Administrador. |
| Histórico de modificações do sistema | RS-07 — Acesso secundário dentro da biblioteca; exige clique explícito. Perfil autorizado a definir conforme PC-03. |
| Busca e filtros | PC-02 — Busca por título/código e filtros por tipo e situação, respeitando as permissões. |

## 4. Perfis e permissões

RS-08 — Somente o Administrador pode inserir documentos. RS-09 — Auditor Líder e Auditor podem acessar a biblioteca para localizar e baixar os documentos disponibilizados. Esses dois perfis não terão comandos de cadastro, alteração ou retirada de arquivos.

| Ação | Administrador | Auditor Líder | Auditor | Participante / Auditado |
| --- | --- | --- | --- | --- |
| Acessar a biblioteca e consultar a listagem | Sim | Sim | Sim | Proposto: não |
| Baixar documentos disponibilizados | Sim | Sim | Sim | Proposto: não |
| Inserir documento | Sim | Não | Não | Não |
| Alterar identificação ou incluir nova revisão¹ | Sim | Não | Não | Não |
| Arquivar documento¹ | Sim | Não | Não | Não |
| Consultar rascunhos e revisões anteriores¹ | Sim | Não | Não | Não |
| Acessar histórico de modificações do sistema² | Sim | Proposto: não | Proposto: não | Proposto: não |

¹ PC-04: gestão e visibilidade propostas. ² PC-03: exclusividade do histórico ao Administrador ainda depende de validação. O acesso geral do Administrador foi definido pelo usuário. A permissão de download não autoriza alteração dos documentos armazenados. O não acesso do Participante à biblioteca corporativa é a proposta V-07 do planejamento de perfis.

### 4.1 Proteção efetiva do acesso

As permissões devem ser verificadas no serviço que recebe os arquivos e nas operações sobre cada documento. A ausência de um botão na tela não é suficiente. Uma tentativa de inserção, alteração, nova revisão ou arquivamento por Auditor Líder, Auditor ou Participante / Auditado deve ser recusada mesmo quando feita por acesso direto.

PC-05 — Os arquivos devem ficar em armazenamento privado. O download exige usuário autenticado e autorizado, com controle do acesso ao documento solicitado. Contas desativadas e visitantes não recebem acesso. O Participante / Auditado não recebe permissão para a biblioteca corporativa nesta proposta. Os quatro perfis definitivos são os definidos no planejamento complementar; não criar perfis adicionais por esta mudança.

### 4.2 Visibilidade dos documentos

PC-04 — Administradores podem manter documentos em Rascunho e consultar suas revisões. Auditor Líder e Auditor veem e baixam somente a revisão Vigente dos documentos disponibilizados. Rascunhos, substituídos, arquivados e cancelados ficam fora da listagem desses perfis nesta proposta.

A inserção de um arquivo não o torna automaticamente Vigente. Para disponibilizar uma revisão, o Administrador deve confirmar sua aprovação e seus dados de emissão. A biblioteca deve preservar a situação real do documento. Essa regra evita que uma minuta seja apresentada como padrão oficial.

A autorização de download controla o acesso ao arquivo no sistema. Documentos Word baixados continuam editáveis localmente quando esse for seu formato; essa edição não deve alterar a cópia armazenada na biblioteca.

## 5. Cadastro e manutenção dos documentos

### 5.1 Informações do cadastro

| Campo | Regra proposta |
| --- | --- |
| Título e tipo | Obrigatórios; exemplos de tipo: procedimento, modelo, formulário e instrução. |
| Código documental | Informar quando atribuído. Não gerar código corporativo sem a regra de numeração aprovada. |
| Revisão ou versão | Obrigatória; preservar a diferença entre revisão do documento e versão do modelo. |
| Situação documental | Rascunho, Vigente, Substituído, Arquivado ou Cancelado. Cadastro inicial em Rascunho. |
| Responsável e emissão | Obrigatórios para disponibilizar como Vigente; pendências permitidas em Rascunho. |
| Arquivo | Ao menos um arquivo válido por revisão. Nome, formato e tamanho identificados. |
| Descrição | Opcional; explicar a finalidade ou o uso do documento. |
| Dados automáticos | Usuário que cadastrou, data/hora de inclusão e identificação do arquivo. Alterações registram autor, instante e ação. |

### 5.2 Fluxo de inserção

PC-06 — O Administrador acessa a biblioteca, aciona “Inserir documento”, informa os dados, seleciona o arquivo e salva o cadastro. O sistema verifica os campos, o formato, o tamanho e a conclusão do envio. Somente após sucesso confirma o cadastro; uma falha não deve deixar um documento disponível com arquivo incompleto.

PC-07 — Formatos iniciais propostos: PDF, DOCX e DOTX, suficientes para os documentos padrão já produzidos. Limite inicial proposto: 20 MB por arquivo, a confirmar. O tipo real do arquivo deve corresponder ao formato permitido; arquivos executáveis ou com macros não integram essa lista.

PC-08 — Uma mesma revisão pode oferecer mais de um formato, como Word e PDF, quando representam o mesmo documento. A listagem deve indicar os formatos disponíveis e permitir escolher qual baixar. O modelo mestre DOTX é um documento próprio, separado do procedimento PDA. Não converter arquivos automaticamente neste escopo.

### 5.3 Revisão e retirada de uso

PC-04 — O Administrador pode corrigir dados de cadastro, incluir nova revisão e arquivar documentos. Uma nova revisão deve preservar a anterior e seu arquivo original. Ao liberar a nova revisão, identificar a anterior como Substituído. Não permitir sobrescrita silenciosa de arquivo já emitido ou reutilização de código para outro documento.

A exclusão definitiva não faz parte desta proposta. Arquivar retira o documento da disponibilidade corrente sem apagar o histórico. A troca de situação deve ser registrada e refletida nas permissões de consulta e download.

## 6. Separação do histórico de modificações

RS-07 — O botão “Histórico de modificações do sistema” abre uma área própria, separada da listagem de documentos. Essa área deve oferecer “Voltar à biblioteca”. Ao abrir a biblioteca pelo menu lateral, a tela inicial deve sempre voltar aos documentos, sem reabrir o histórico por preferência da visita anterior.

PC-03 — Recomenda-se disponibilizar o histórico somente ao Administrador nesta primeira etapa, mantendo Auditor Líder e Auditor focados no acesso e download dos documentos. A exclusividade do histórico ao Administrador não foi definida pelo usuário; a restrição aos demais perfis, incluindo o Participante / Auditado, é proposta e precisa de confirmação.

O histórico existente deve ser preservado. A mudança de navegação não autoriza apagar, reconstruir ou inventar registros. Se a área atual não contiver de fato um histórico de modificações do sistema, a diferença deve ser apontada antes de desenvolver uma funcionalidade nova.

| Conceito | Conteúdo e localização |
| --- | --- |
| Biblioteca de documentos | Documentos padrão da AUDITA e formatos disponíveis para download. É a entrada principal da página. |
| Revisões de um documento | Versões e alterações daquele documento. Consulta na gestão do documento, conforme PC-04. |
| Histórico de modificações do sistema | Registros já mantidos pelo sistema sobre suas modificações. Acesso apenas pelo botão específico e com permissão. |

## 7. Exemplo de organização da tela

O exemplo abaixo descreve a disposição funcional, sem definir uma aparência final ou representar dados reais.

| Área | Administrador | Auditor Líder e Auditor |
| --- | --- | --- |
| Topo da página | Biblioteca de documentos | Biblioteca de documentos |
| Ação principal | Inserir documento | Nenhuma ação de cadastro |
| Acesso secundário | Histórico de modificações do sistema¹ | Não exibido na proposta¹ |
| Consulta | Busca, filtros e lista de documentos | Busca e lista de documentos disponibilizados |
| Documento selecionado | Baixar e gerenciar revisão/situação | Baixar no formato disponível |

¹ Condicionado à validação da PC-03. Os documentos não se misturam aos registros do histórico. O Participante / Auditado não recebe esta tela da biblioteca na proposta inicial; sua consulta de documentos ocorre dentro das auditorias autorizadas da própria organização.

### 7.1 Tratamento dos arquivos já produzidos

O PDA Rev.00 e o modelo mestre produzidos nesta conversa permanecem em Rascunho. Após a implementação ser autorizada e concluída, o Administrador poderá cadastrá-los nessa situação. Sua disponibilização como documentos vigentes dependerá da aprovação institucional, com responsável e data confirmados. Não há carga inicial automática autorizada nesta etapa.

## 8. Critérios de aceite da implementação futura

| ID | Verificação e resultado esperado |
| --- | --- |
| CA-01 | Nos quatro perfis, as abas Não conformidades, Planos de ação e Indicadores deixam de aparecer no menu lateral, inclusive recolhido e em tela menor. |
| CA-02 | O item antigo é substituído por Biblioteca de documentos; os demais itens mantêm sua ordem e regras de acesso. |
| CA-03 | Abrir a biblioteca pelo menu mostra os documentos, sem apresentar o histórico automaticamente, inclusive após visita anterior ao histórico. |
| CA-04 | O Administrador insere um arquivo válido e vê confirmação somente após concluir o envio. Falha de envio ou campo inválido não publica cadastro incompleto. |
| CA-05 | Auditor Líder e Auditor localizam e baixam documentos permitidos; não veem ações de gestão e têm recusadas tentativas diretas de escrita. |
| CA-06 | O download entrega o arquivo e a revisão selecionados; um usuário sem autorização não consegue baixar usando o endereço direto. |
| CA-07 | O histórico abre somente mediante ação explícita no acesso proposto, permite voltar aos documentos e preserva os registros existentes. |
| CA-08 | Se PC-03 for aprovada, o histórico não fica acessível ao Auditor Líder, Auditor ou Participante / Auditado, inclusive por acesso direto. |
| CA-09 | Se PC-04 for aprovada, rascunhos e arquivos retirados de uso não ficam disponíveis aos auditores; a nova revisão preserva o original anterior. |
| CA-10 | Arquivos com formato ou tamanho fora das regras aprovadas são recusados com mensagem clara. |
| CA-11 | Biblioteca vazia, busca sem resultado e falha de download têm mensagens próprias; erro de carregamento não aparece como ausência de documentos. |
| CA-12 | Auditorias, relatórios, dados existentes e o histórico não são removidos ou modificados como efeito da retirada das três abas. |
| CA-13 | Se V-07 do planejamento de perfis for aprovada, o Participante não vê nem acessa a biblioteca corporativa, inclusive por endereço direto. Os relatórios autorizados da sua organização continuam acessíveis em Auditorias. |

### 8.1 Etapas após validação

Após a aprovação do documento e a autorização expressa para executar, conferir o funcionamento atual e suas dependências; detalhar as alterações compatíveis com a estrutura existente; implementar navegação, biblioteca e permissões; testar os critérios de aceite com os quatro perfis; submeter o resultado à homologação e autorizar a liberação. Este roteiro não define prazo nem presume tecnologias ou recursos já implementados.

## 9. Decisões para validação

Os requisitos RS-01 a RS-09 registram o pedido recebido. As decisões abaixo completam a especificação e podem ser aprovadas ou ajustadas antes da implementação.

| Referência | Proposta a confirmar |
| --- | --- |
| PC-01 | Retirar as três abas da navegação, preservando dados e funções internas. Qualquer desativação completa de módulos/rotas fica fora deste escopo. |
| PC-02 | Incluir busca por título/código e filtros por tipo e situação, limitados ao que cada perfil pode consultar. |
| PC-03 | Permitir acesso ao histórico de modificações do sistema somente ao Administrador. |
| PC-04 | Reservar a gestão de revisões e arquivamento ao Administrador; disponibilizar aos auditores somente documentos vigentes; preservar as versões anteriores. |
| PC-05 | Manter arquivos privados, exigir autenticação e autorização no download e não conceder acesso a outros perfis por padrão. |
| PC-06 | Cadastrar documentos com validação de dados e envio concluído antes da confirmação. |
| PC-07 | Aceitar PDF, DOCX e DOTX, com até 20 MB por arquivo. |
| PC-08 | Permitir formatos alternativos vinculados à mesma revisão, sem conversão automática; manter o modelo mestre como documento separado. |

### 9.1 Registro da decisão

| Campo | Preenchimento |
| --- | --- |
| Resultado da validação | [Aprovado / Aprovado com ajustes / Revisar] |
| Ajustes solicitados | [Descrever os ajustes, se houver] |
| Responsável | [Nome e função] |
| Data | [DD/MM/AAAA] |
| Autorização para execução | [Aguardar / Autorização expressa a registrar] |

A implementação deve utilizar a versão validada deste documento. Ajustes que alterem permissões, disponibilidade dos arquivos ou o alcance da remoção de módulos devem ser registrados antes da execução.

## Histórico do planejamento

| Versão | Data | Descrição |
| --- | --- | --- |
| 0.1 | 07/10/2026 | Proposta inicial baseada na solicitação e na imagem do menu. Preservada para referência. |
| 0.2 | 07/10/2026 | Compatibilização com os quatro perfis definitivos, inclusão do Participante / Auditado e vínculo ao planejamento de permissões e dashboards. Aguardando validação. |
