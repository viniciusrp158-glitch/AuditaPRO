# Audita PRO — Planejamento da aba Meu Perfil

**Versão:** 1.0 — 05/10/2026  
**Situação:** proposta para validação.  
**Entrega desta etapa:** documentação. Nenhuma alteração no aplicativo, no banco ou nas permissões foi realizada nesta etapa.

## 1. Objetivo

Criar uma área pessoal, navegável e integrada ao Supabase, na qual cada usuário possa completar seus dados, informar seu vínculo profissional, anexar os documentos exigidos e acompanhar a validação do cadastro pelo administrador responsável.

A aba deve atender tanto ao primeiro acesso quanto às futuras consultas e atualizações do próprio cadastro. Os dados salvos devem permanecer disponíveis após recarregar a página ou entrar em outro dispositivo.

## 2. Navegação e apresentação

- **Meu Perfil** será a última opção de navegação do menu lateral esquerdo, identificada por um ícone de pessoa e pelo texto do nome da aba.
- A opção estará presente em todas as páginas autenticadas, respeitando o comportamento responsivo do menu.
- A identidade visual seguirá a logo oficial, o azul marinho, o branco e os destaques em azul do Audita PRO.
- O título será **Meu Perfil**, acompanhado do e-mail da conta, do perfil atribuído e da situação do cadastro.
- O usuário poderá avançar, voltar, revisar os dados e salvar para continuar depois. Não será uma imagem ou formulário demonstrativo.
- No primeiro acesso com cadastro pendente, o sistema direcionará para esta aba. As demais áreas sujeitas à aprovação continuarão bloqueadas pelo servidor, com uma explicação visível.
- A aprovação não concederá acesso administrativo ou a todas as auditorias da organização: serão respeitados perfil, vínculo e participação autorizada.

## 3. Etapas do cadastro

| Etapa | Conteúdo | Ação principal |
|---|---|---|
| 1. Dados pessoais | Identificação e contato | Salvar e continuar |
| 2. Dados profissionais | Empresa, unidade, cargo, função e área | Salvar e continuar |
| 3. Documentos de competência | Anexos exigidos conforme o perfil atribuído | Salvar e continuar |
| 4. Confirmação | Revisão dos dados e envio para análise | Enviar para validação |
| 5. Concluído | Resultado positivo da análise e acesso autorizado | Acessar o Dashboard |

Após o envio, a tela exibirá **Aguardando validação**. O envio não marcará automaticamente a etapa 5 como concluída. Se houver reprovação, o usuário verá os motivos e retornará às etapas que precisam de correção.

A navegação entre etapas deve preservar informações já salvas. Ao sair com alterações não salvas, haverá aviso. O salvamento só será confirmado depois da resposta do servidor.

## 4. Etapa 1 — Dados pessoais

| Campo | Regra proposta |
|---|---|
| Nome completo | Obrigatório; preenchido inicialmente com o nome informado no convite, quando houver |
| CPF | Obrigatório para enviar à validação; validar formato e dígitos verificadores no servidor |
| E-mail | Obrigatório; exibir o e-mail autenticado da conta |
| Telefone | Opcional, mas recomendado; orientar preenchimento com DDD |

O e-mail será apresentado como informação da conta. Sua alteração dependerá de um fluxo específico de confirmação no Supabase Auth; editar apenas um campo do perfil não deve trocar o login. Para esta primeira versão, a proposta é manter esse campo somente para leitura.

CPF duplicado ou divergente deve gerar orientação para revisão administrativa, sem unir contas automaticamente. CPF e documentos não devem aparecer em listagens de outros participantes.

Empresa e unidade serão preenchidas na etapa seguinte, para evitar repetir os mesmos campos.

## 5. Etapa 2 — Dados profissionais e vínculo

| Campo | Regra proposta |
|---|---|
| Empresa / organização | Obrigatória para os perfis operacionais; selecionar uma organização já cadastrada pelo Administrador |
| Unidade | Opcional; listar apenas unidades da empresa selecionada |
| Perfil de acesso | Exibir o perfil atribuído pelo Administrador; o titular não pode alterar suas próprias permissões |
| Cargo | Obrigatório para envio; aproveitar o catálogo de cargos existente |
| Função | Opcional; descreve a atividade efetivamente exercida |
| Departamento / área | Opcional nesta primeira versão |
| Gestor responsável | Opcional nesta primeira versão; informar nome e, quando disponível, contato profissional |

**Cargo e perfil de acesso são informações diferentes.** Uma pessoa pode ter o cargo de Técnico em Segurança do Trabalho e o perfil de Auditor Líder. Nesta primeira entrega, a lista de documentos obrigatórios será determinada pelo perfil de acesso atribuído pelo Administrador.

O gestor profissional informado pelo titular não será automaticamente o aprovador do cadastro nem receberá acesso ao sistema.

### Seleção da empresa

Quando o convite já indicar empresa e unidade, essas informações aparecerão preenchidas. Se o usuário apontar uma divergência ou solicitar outra empresa, a mudança ficará pendente de aprovação.

Para localizar uma organização existente, a proposta é usar pesquisa por nome ou CNPJ, com resultados limitados a nome, CNPJ e unidades necessárias à seleção. Esse mecanismo não dará acesso à lista completa de clientes, contatos, usuários, auditorias ou documentos de outras empresas. Sempre que possível, convites já vinculados devem apresentar somente as organizações autorizadas para aquela conta.

Selecionar uma organização constitui uma **solicitação de vínculo**, sem liberação imediata. Se a empresa não for encontrada, orientar o usuário a procurar o administrador; não criar uma organização nova a partir desta tela.

A conta existente poderá conservar vários vínculos. A tela deverá identificar qual empresa está sendo regularizada e mostrar a situação de cada vínculo, sem duplicar a conta nem aprovar todos os vínculos de uma vez.

## 6. Etapa 3 — Documentos de competência

### Matriz inicial de exigências

| Perfil atribuído | Documentos obrigatórios nesta versão |
|---|---|
| Auditor Líder | Documento de identificação com foto e certificado de Auditor Líder |
| Auditor | Documento de identificação com foto e certificado de Auditor |
| Participante / Auditado | Documento de identificação com foto |
| Administrador | Proposta: preservar a regra administrativa atual; se também atuar em perfil operacional, cumprir os documentos desse vínculo |

A exigência de certificado para Auditor Líder e Auditor amplia o escopo anterior, que exigia apenas identificação. Deve ser aplicada por tipo de documento e perfil, sem substituir o documento de identificação por um certificado.

O registro profissional de Técnico em Segurança do Trabalho foi citado como exemplo de evolução. Nesta primeira versão, ele não será uma exigência adicional: o escopo inicial ficará restrito à matriz acima. A estrutura deve permitir acrescentar registros profissionais por cargo posteriormente.

### Campos de cada documento

- Tipo de documento, apresentado automaticamente conforme a exigência.
- Arquivo obrigatório.
- Número ou identificação do certificado e instituição emissora, opcionais nesta primeira versão.
- Data de emissão, opcional.
- Data de validade, quando houver, ou indicação **Sem validade informada no documento**.
- Situação da análise, data de envio e eventual motivo de reprovação.

Não se deve inventar uma data de validade para documentos ou certificados que não apresentem essa informação. A indicação de ausência de validade também será examinada pelo aprovador. Havendo data de validade, ela não poderá anteceder a emissão; documento já vencido será sinalizado e não atenderá à exigência para liberação.

### Regras dos arquivos

- Formatos permitidos: **PDF, JPEG/JPG e PNG**.
- Limite por arquivo: **10 MB**, definido nesta proposta como 10.000.000 bytes, inclusive.
- Um arquivo por exigência nesta primeira versão. Quando for necessária frente e verso, orientar o envio de um único PDF contendo as duas páginas.
- Validar tamanho e conteúdo real no servidor, além da verificação no navegador. Renomear a extensão de um arquivo não deve fazê-lo passar pela validação.
- Mostrar nome, formato, tamanho, progresso de envio e resultado da operação.
- Permitir visualizar e substituir um anexo antes do envio para análise.
- Guardar os arquivos em armazenamento privado e permitir visualização somente ao titular e ao administrador autorizado para a análise.
- Reenvios geram novas versões; não sobrescrever a evidência de uma decisão anterior.
- Mensagens devem distinguir arquivo inválido, tamanho excedido, falha de conexão e falta de autorização.

O preenchimento da etapa depende de todos os documentos exigidos pelo perfil. Enviar apenas a identificação não completa o cadastro de um Auditor Líder.

## 7. Etapa 4 — Confirmação e envio

Apresentar um resumo dos dados pessoais, empresa e unidade, dados profissionais, perfil atribuído, documentos enviados e responsável pela análise. Cada seção terá **Editar**, retornando à etapa correspondente.

Antes de enviar, o titular deverá confirmar que revisou as informações e que os documentos anexados correspondem ao seu cadastro. Essa confirmação não será apresentada como assinatura digital ou aprovação técnica.

Ao clicar em **Enviar para validação**, o servidor deverá:

1. Validar os campos obrigatórios, a solicitação de vínculo e a presença de todos os arquivos exigidos.
2. Identificar o administrador responsável pela revisão.
3. Registrar uma versão do cadastro submetido, com data e hora.
4. Alterar a situação para **Aguardando validação** e incluir o envio na fila do responsável.
5. Confirmar a operação na tela. Cliques repetidos não devem criar envios duplicados.

O conteúdo submetido ficará preservado enquanto estiver em análise. Para corrigir antes da decisão, a proposta é permitir **Retirar para corrigir**, cancelando aquela submissão pendente e exigindo um novo envio. A decisão administrativa deve verificar se a versão continua atual para evitar aprovar uma versão retirada.

## 8. Quem recebe e valida

### Regra principal solicitada

O **Administrador que criou ou convidou o usuário** será o responsável inicial por validar os dados e documentos enviados. O sistema deverá identificar esse responsável pelo cadastro/convite, sem permitir que o próprio usuário escolha seu aprovador.

Na aba **Usuários**, a área de pendências deverá mostrar:

- Nome da pessoa, empresa/unidade e perfil solicitado ou atribuído.
- Data de envio e responsável pela análise.
- Situação do cadastro e quantidade de documentos pendentes.
- Ação **Analisar cadastro**, abrindo os dados e todos os anexos da submissão.
- Filtro **Pendentes sob minha responsabilidade**, além da visão global administrativa autorizada.

### Decisões da análise

O aprovador poderá aprovar ou reprovar cada documento e revisar o vínculo e os dados cadastrais. Toda reprovação exigirá um motivo compreensível, visível ao titular, como “O documento está ilegível; envie uma imagem nítida”.

A aprovação final só será possível quando todos os documentos obrigatórios e o vínculo estiverem aprovados e os dados obrigatórios estiverem completos. A interface deve indicar exatamente o que impede a conclusão.

Registrar responsável, decisão, data, hora, motivo e versão examinada. O usuário receberá o resultado em Meu Perfil; a pendência administrativa deverá ser atualizada na mesma fonte de dados.

### Exceções propostas para validação

| Situação | Tratamento proposto |
|---|---|
| Usuário criado por cadastro público | Encaminhar para fila administrativa sem responsável e permitir que um Administrador assuma |
| Criador inativo ou sem permissão administrativa | Exigir reatribuição a outro Administrador ativo, com histórico |
| Conta já existente recebe novo vínculo | Usar como responsável o Administrador que criou o novo vínculo ou convite correspondente |
| Necessidade de substituição do aprovador | Permitir reatribuição administrativa explícita, com motivo e histórico |
| Aprovador é o próprio titular | Não permitir autoaprovação documental; preservar o acesso do administrador inicial e encaminhar eventual validação operacional a outro administrador |

Essas exceções não ampliam a gestão para usuários de organizações. Nesta versão, criar usuários e aprovar documentos continua sendo uma ação administrativa.

## 9. Etapa 5 — Concluído e acesso

Após aprovação integral, mostrar **Cadastro aprovado**, empresa, perfil autorizado, data e responsável pela aprovação. Exibir **Acessar o Dashboard**.

Para o Participante / Auditado, a aprovação permite acompanhar as auditorias às quais foi autorizado, incluindo andamento e cronograma. Caso ainda não participe de uma auditoria, mostrar: **Seu cadastro foi aprovado. Você ainda não foi vinculado a uma auditoria.**

Para Auditor e Auditor Líder, aplicar as permissões operacionais já definidas para cada perfil. Nenhuma aprovação documental poderá transformar um Auditor de apoio em líder ou administrador.

## 10. Estados e alterações posteriores

| Situação exibida | Significado | Próxima ação |
|---|---|---|
| Em preenchimento | Cadastro ainda não enviado | Completar e enviar |
| Aguardando validação | Versão submetida ao responsável | Acompanhar análise |
| Correção solicitada | Dados ou documento reprovados | Corrigir os itens indicados e reenviar |
| Aprovado | Exigências atendidas para aquele vínculo | Acessar áreas autorizadas |
| Regularização necessária | Mudança de exigência, perfil ou documento vencido | Regularizar o vínculo afetado |

Esses são estados funcionais da interface; não substituem automaticamente os estados existentes de conta, vínculo e documento no banco.

Após a aprovação, o usuário poderá continuar acessando Meu Perfil. Propostas para alterações:

- Telefone, função, área e contato do gestor podem ser atualizados com histórico, sem repetir a análise de identidade.
- Alterações de nome, CPF, empresa, unidade ou documentos exigem revisão administrativa dos dados afetados.
- Uma solicitação para outra empresa não concede acesso à nova organização nem remove silenciosamente o vínculo atual.
- Mudança de perfil é feita pelo Administrador e recalcula os documentos exigidos.
- Certificado vencido deixa o vínculo correspondente em regularização; o acesso a Meu Perfil permanece disponível. O comportamento de bloqueio operacional deverá ser aplicado também no servidor.
- Ao ativar a nova exigência de certificados para contas existentes, apresentar uma prévia dos vínculos afetados e definir a transição antes de bloquear usuários já aprovados.

As propostas sobre edição após aprovação, vencimento e transição deverão ser confirmadas antes da implementação.

## 11. Aproveitamento da estrutura atual

A análise para este documento consultou o planejamento anterior, o registro de entrega do módulo Usuários e as migrations locais. Não foi realizada uma nova inspeção do banco remoto nesta etapa.

| Estrutura existente | Uso planejado |
|---|---|
| Supabase Auth | Login, identidade da conta e e-mail autenticado |
| `user_profiles` | Nome, CPF, telefone e dados pessoais existentes |
| `organizations` e `organization_units` | Seleção e validação de empresa/unidade |
| `organization_memberships` | Vínculo, cargo, perfil e situação de competência por empresa |
| `positions` e `access_profiles` | Cargo e perfil administrados |
| `organization_access_requests` | Reaproveitar o fluxo de solicitação de vínculo, adaptando-o à seleção de empresa existente |
| `user_invites` | Rastrear o convite e o administrador criador |
| `user_documents` e armazenamento privado | Anexos, análises e histórico documental |
| `audit_events` | Eventos de envio, análise, reenvio e reatribuição |
| Função `user-management` | Reutilizar operações existentes de cadastro próprio e documentos |

### Lacunas identificadas nos arquivos locais

- `user_documents` aceita atualmente apenas o tipo `identity`. Será necessário permitir certificados distintos.
- O índice de documento pendente é atualmente único por vínculo. Ele precisará considerar também o tipo de documento para permitir identificação e certificado pendentes simultaneamente.
- A exigência atual de identificação por cargo não representa sozinha a nova matriz documental por perfil.
- A nova tela precisará representar função, área e gestor por vínculo, além de emissão/validade por documento.
- O responsável e a versão da submissão precisam ser identificados de forma inequívoca. `created_by` e os convites são fontes existentes, mas reatribuições precisam de registro próprio.
- Aprovações atualmente permitidas a administradores devem ser revistas para respeitar o responsável designado e o procedimento de reatribuição.
- Os formulários pessoais hoje presentes no módulo Usuários deverão ser aproveitados ou encaminhados para Meu Perfil, evitando dois cadastros independentes.

Na implementação, confirmar primeiro o schema remoto e as políticas vigentes. Preparar migrations pequenas e separadas por finalidade: documentos, dados profissionais, submissão/aprovador e autorização. Não criar tabelas equivalentes às existentes; novas estruturas somente quando necessárias para conceitos ainda não representados.

## 12. Segurança e histórico

- Validar autorização, dados e arquivos no servidor, além da interface.
- O titular só poderá editar seus dados permitidos, enviar seus arquivos e consultar sua própria análise.
- O titular não poderá mudar seu perfil de acesso, aprovar documentos, marcar competência como aprovada ou conceder a si próprio um vínculo autorizado.
- Proteger consultas, alterações e arquivos por conta e vínculo; selecionar uma empresa na tela não altera a autorização.
- Links de documentos serão privados e temporários. Outros participantes da auditoria não terão acesso aos documentos pessoais.
- Não armazenar senhas, conteúdo dos arquivos ou CPF completo nos eventos de operação.
- Preservar versões e decisões conforme a política de retenção do produto; exclusão ou substituição visual de um arquivo não deve apagar o histórico necessário.
- Reutilizar a sessão existente. Meu Perfil não deve exigir novo cadastro ou criar outra conta.

## 13. Comportamento da interface

Apresentar estados de carregamento, salvamento, envio de arquivo, ausência de vínculo, documento pendente, erro, aprovação e falta de autorização. Erros devem informar uma ação possível e conservar o que já foi salvo.

No celular, as etapas poderão ser apresentadas de forma compacta, mantendo o número e o nome da etapa atual. Campos devem ter rótulos, foco visível, navegação por teclado e indicação textual de situação, além das cores.

O primeiro incremento de notificações será dentro da plataforma: pendência no módulo Usuários e resultado em Meu Perfil. E-mails automáticos e lembretes ficam como evolução, aproveitando o histórico de notificações quando aplicável.

## 14. Critérios de aceite para implementação futura

| ID | Cenário | Resultado esperado |
|---|---|---|
| MP-01 | Abrir qualquer página autenticada | Meu Perfil é a última opção de navegação, com ícone de pessoa |
| MP-02 | Salvar uma etapa e entrar novamente | Dados persistem e o preenchimento pode continuar |
| MP-03 | Preencher CPF inválido | Envio bloqueado com orientação clara, inclusive em chamada direta ao servidor |
| MP-04 | Selecionar empresa existente | Solicitação é registrada sem conceder acesso imediato |
| MP-05 | Selecionar unidade de outra empresa | Operação recusada pelo servidor |
| MP-06 | Entrar como Auditor Líder | São exigidos identificação com foto e certificado de Auditor Líder |
| MP-07 | Entrar como Auditor | São exigidos identificação com foto e certificado de Auditor |
| MP-08 | Entrar como Participante / Auditado | É exigida apenas identificação com foto |
| MP-09 | Enviar arquivo permitido no limite de tamanho | Upload aceito; acima de 10.000.000 bytes ou formato inválido é recusado |
| MP-10 | Enviar somente parte dos documentos | Não é possível concluir a submissão |
| MP-11 | Enviar cadastro completo | Envio aparece na fila do Administrador criador, com versão, data e hora |
| MP-12 | Reprovar um documento | Motivo obrigatório fica visível ao titular; acesso permanece pendente |
| MP-13 | Corrigir e reenviar | Nova versão preserva a anterior e permite nova análise |
| MP-14 | Aprovar todos os itens e vínculo | Etapa Concluído aparece e são liberadas somente as permissões autorizadas |
| MP-15 | Aprovado sem auditoria atribuída | Exibir mensagem de ausência de auditorias, sem dados fictícios |
| MP-16 | Tentar aprovar a si próprio ou editar permissões pela API | Operação recusada pelo servidor |
| MP-17 | Outro usuário tenta abrir documento pessoal | Acesso recusado |
| MP-18 | Reatribuir responsável ou aprovar versão retirada | Reatribuição exige autorização e histórico; decisão sobre versão retirada é recusada |
| MP-19 | Usuário com dois vínculos | Aprovação ou pendência de um vínculo não altera indevidamente o outro |
| MP-20 | Usar celular, teclado ou conexão com falha | Navegação utilizável; erros compreensíveis; dados salvos preservados |

## 15. Ordem sugerida de desenvolvimento após validação

1. Conferir schema remoto, funções, políticas e cadastros existentes; confirmar regras propostas neste documento.
2. Ampliar tipos de documentos e dados profissionais, preservando os registros existentes.
3. Implementar submissão, aprovador responsável, histórico e regras de acesso.
4. Criar a aba Meu Perfil com as cinco etapas e integrar a fila administrativa de Usuários.
5. Validar o ciclo completo com contas de Administrador, Auditor Líder, Auditor e Participante / Auditado, incluindo reprovação e reenvio.
6. Disponibilizar o link do aplicativo para validação do usuário e registrar os ajustes solicitados.

## 16. Pontos propostos para confirmar

O fluxo principal, os cinco passos, os documentos dos três perfis operacionais e o limite de upload refletem o pedido. Para fechar o planejamento, ficam explícitas estas propostas complementares:

1. Telefone, função, departamento, gestor e unidade opcionais na primeira versão; nome, CPF, empresa, cargo e documentos obrigatórios para os perfis operacionais.
2. E-mail exibido sem edição nesta etapa; perfil de acesso definido exclusivamente pelo Administrador.
3. Administrador global mantém o acesso administrativo atual; exigências documentais aplicam-se a seus vínculos operacionais quando houver.
4. Cadastros públicos ou sem criador ativo seguem para atribuição/reassunção administrativa registrada.
5. Um arquivo por exigência, com frente e verso reunidos em PDF quando necessário.
6. Mudanças sensíveis e documentos vencidos exigem regularização; a transição de usuários já aprovados será definida antes da ativação das novas exigências.
7. Notificações dentro da plataforma nesta primeira versão; e-mails e lembretes como evolução.

**Este documento está pronto para revisão. A implementação ocorrerá em uma etapa posterior, mediante validação deste planejamento.**
