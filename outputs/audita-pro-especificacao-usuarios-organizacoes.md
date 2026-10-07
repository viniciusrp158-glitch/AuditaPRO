# Audita PRO — Planejamento da aba Usuários e Organizações

**Versão:** 1.0 — 05/10/2026  
**Situação:** planejamento validado; implementação inicial registrada em `audita-pro-modulo-usuarios-entrega.md`.  
**Entrega original desta etapa:** documentação funcional e técnica. As alterações posteriores no aplicativo e no banco são descritas no registro de implementação.

## 1. Objetivo

Transformar a aba **Usuários**, no menu lateral permanente, em uma área funcional de gestão de pessoas, contas, empresas auditadas e seus vínculos. Os cadastros devem alimentar os módulos de auditorias, cronogramas, relatórios, indicadores e permissões.

O Administrador deve conseguir cadastrar e localizar pessoas e organizações, consultar seus detalhes, editar informações permitidas, acompanhar documentos e acessos, atribuir perfis e inativar cadastros preservando o histórico.

As telas futuras devem consultar e gravar dados reais no Supabase. Uma confirmação de salvamento só deve aparecer após o servidor confirmar a operação. Alterações precisam continuar disponíveis ao recarregar a página ou acessar por outro dispositivo autorizado.

## 2. Decisões que orientam esta versão

### 2.1 Confirmadas pelo pedido mais recente

- **Administrador:** visão global e todas as permissões funcionais do Audita PRO.
- **Auditor Líder:** conduz a auditoria; registra avaliações, conformidades, não conformidades e evidências; elabora relatórios diários; inicia e finaliza auditorias.
- **Auditor:** participa como apoio e observador. Consulta a auditoria, mas não faz registros operacionais. Deve constar na equipe e nos relatórios.
- **Participante / Auditado:** acompanha exclusivamente as auditorias autorizadas de sua empresa, incluindo andamento, cronograma, dias restantes e requisitos previstos ou verificados.
- A aba Usuários oferecerá acesso a **Novo usuário**, **Nova organização**, **Usuários existentes** e **Organizações existentes**.
- O desenvolvimento ocorrerá depois da validação deste documento.

**A definição atual do Auditor substitui a definição anterior que lhe concedia escrita.** A migração futura deverá revisar permissões reais no servidor, inclusive exceções individuais já existentes. Renomear um perfil ou esconder botões não será suficiente.

### 2.2 Decisões anteriores preservadas

- Cargo representa qualificação técnica; perfil representa permissões de acesso.
- Administrador valida documentos. Para Auditor Líder, Auditor e Cliente/Auditado, o documento de identificação permanece obrigatório inicialmente.
- O próprio usuário envia seu documento após realizar login em seu dispositivo. Antes da aprovação, acessa somente as funções necessárias à regularização do cadastro.
- Apenas os signatários definidos pelo Auditor Líder confirmam ciência de relatórios. Confirmação de ciência e assinatura externa via GOV são registros distintos.
- Empresas e usuários associados a registros são inativados, preservando o histórico.
- Supabase continua como estrutura de dados e autenticação; o piloto depende de internet.
- Retenção de cinco anos permanece como requisito do produto. Marco inicial, tratamento por categoria de dado e procedimento de descarte ainda precisam de definição; este documento não transforma essa retenção em garantia jurídica.

### 2.3 Propostas deste documento, sujeitas à validação

- Usar **Participante / Auditado** como nome visível do perfil anteriormente chamado Cliente.
- Reservar a gestão global de usuários, organizações, perfis e documentos ao Administrador.
- Permitir à mesma pessoa vínculos com várias organizações, sem duplicar sua conta.
- Usar convite por e-mail para ativação da conta e definição de senha pelo próprio usuário.
- Preservar o cadastro público existente, encaminhando novos cadastros para aprovação administrativa.
- Tratar a gestão de perfis personalizados como uma segunda etapa deste módulo. A primeira entrega terá os quatro perfis padrão e seus escopos definidos.

## 3. Conceitos e relacionamentos

| Conceito | Significado | Exemplo |
|---|---|---|
| Pessoa | Identidade e dados pessoais | Nome, CPF e contato |
| Conta | Credencial de login no Supabase Auth | E-mail e senha definidos pelo titular |
| Organização | Empresa que será auditada | Empresa A |
| Unidade | Estabelecimento de uma organização | Fábrica de Campinas |
| Vínculo | Associação de uma pessoa a uma organização | Pessoa vinculada à Empresa A |
| Cargo | Qualificação ou função profissional | Engenheiro de Segurança |
| Perfil de acesso | Conjunto de ações autorizadas | Auditor Líder |
| Participação | Associação a uma auditoria específica | Auditor de apoio na auditoria 2026-014 |
| Signatário | Participante designado para confirmar ciência | Representante do auditado |

**Relacionamento proposto:** uma pessoa possui uma conta; uma organização possui unidades e vínculos; cada auditoria pertence a uma organização; os vínculos elegíveis podem ser adicionados à equipe ou ao grupo de auditados daquela auditoria.

Estar vinculado a uma empresa não concede automaticamente acesso a todas as suas auditorias. O acesso operacional depende também da participação ou autorização explícita na auditoria, do perfil e da situação do vínculo.

O Administrador global pode existir sem vínculo com uma empresa cliente. Um Auditor Líder pode trabalhar para vários clientes mediante vínculos explícitos. Cada tela deve informar claramente a organização e a auditoria que estão sendo consultadas.

## 4. Perfis e matriz inicial de permissões

Legenda: **Sim** = permitido; **Vinculadas** = somente nas auditorias autorizadas; **Designado** = somente quando incluído como signatário; **Não** = negado no servidor.

| Ação | Administrador | Auditor Líder | Auditor | Participante / Auditado |
|---|---|---|---|---|
| Abrir gestão global de usuários e organizações | Sim | Não | Não | Não |
| Criar e editar usuários e organizações | Sim | Não | Não | Não |
| Atribuir perfis e permissões | Sim | Não | Não | Não |
| Aprovar ou reprovar documentos | Sim | Não | Não | Não |
| Inativar conta ou vínculo | Sim | Não | Não | Não |
| Consultar auditorias e cronograma | Sim | Vinculadas | Vinculadas | Vinculadas |
| Consultar indicadores globais | Sim | Não | Não | Não |
| Consultar indicadores da auditoria | Sim | Vinculadas | Vinculadas | Vinculadas |
| Criar auditoria | Sim | Organizações autorizadas¹ | Não | Não |
| Planejar e alterar cronograma | Sim | Vinculadas¹ | Não | Não |
| Iniciar e finalizar auditoria | Sim | Vinculadas | Não | Não |
| Registrar e alterar avaliações do checklist | Sim | Vinculadas | Não | Não |
| Criar e editar não conformidades | Sim | Vinculadas | Não | Não |
| Enviar evidências operacionais | Sim | Vinculadas | Não | Não |
| Criar e editar planos de ação | Sim | Vinculadas¹ | Não | Não |
| Criar, revisar e finalizar relatório diário | Sim | Vinculadas | Não | Não |
| Consultar relatórios disponibilizados | Sim | Vinculadas | Vinculadas | Vinculadas |
| Consultar rascunhos de relatórios | Sim | Vinculadas | Não¹ | Não |
| Baixar PDF disponível e autorizado | Sim | Vinculadas | Vinculadas | Vinculadas |
| Selecionar equipe e signatários | Sim | Vinculadas¹ | Não | Não |
| Confirmar ciência em nome próprio | Designado | Designado | Designado | Designado |
| Alterar a própria senha | Sim | Sim | Sim | Sim |
| Enviar o próprio documento exigido | Quando exigido | Sim | Sim | Sim |
| Consultar documentos pessoais de terceiros | Sim, para gestão | Não | Não | Não |

¹ Proposta complementar para completar o fluxo; requer validação junto com o documento.

### Regras de interpretação

- O Administrador tem todas as ações administrativas e operacionais implementadas, respeitando a integridade do histórico. Seu perfil não autoriza confirmar ciência como outra pessoa nem sobrescrever um relatório congelado.
- O Auditor tem leitura operacional. A possibilidade de enviar seu próprio documento cadastral ou confirmar ciência em nome próprio não lhe concede escrita na auditoria.
- O Auditado consulta andamento, checklist, achados e relatórios publicados dentro de seu escopo. Notas internas, rascunhos e documentos pessoais de terceiros permanecem restritos.
- A publicação de informação ao auditado precisa ser explícita. Caso o schema atual não consiga distinguir conteúdo interno de conteúdo disponibilizado, essa capacidade será uma dependência de implementação; não se deve simplesmente liberar todas as linhas.
- A autorização para criar uma auditoria exige um vínculo organizacional elegível; a participação ainda não existe antes da criação. Após criá-la, o servidor deve registrar o líder e sua participação de maneira consistente.
- A gestão de equipe pelo líder deve selecionar pessoas já cadastradas, ativas e elegíveis. Ela não equivale a conceder um papel de administrador ou criar acesso global.

## 5. Estrutura de navegação

Ao clicar em **Usuários**, o Administrador abre a página **Usuários e Organizações**.

### 5.1 Página inicial do módulo

- Cabeçalho com nome do módulo e descrição curta.
- Ações principais: **Novo usuário** e **Nova organização**.
- Abas internas: **Usuários**, **Organizações** e **Documentos pendentes**.
- Acesso às configurações de cargos e perfis em etapa posterior.
- Indicadores auxiliares, calculados a partir dos dados reais: usuários ativos, cadastros aguardando liberação, documentos pendentes e organizações ativas. As categorias podem se sobrepor; não devem ser apresentadas como soma de uma única distribuição.
- Menu lateral permanece visível; a logo retorna ao Dashboard.

### 5.2 Lista de usuários

Colunas: nome, e-mail, organizações vinculadas, perfis, status da conta, situação documental e data do cadastro.

Filtros: nome ou e-mail; CPF exato quando necessário ao Administrador; organização; perfil; status; pendência documental. CPF deve aparecer mascarado na lista. Usuários com vários vínculos precisam ser identificados como tal.

Ações: **Ver detalhes**, **Editar**, **Gerenciar vínculos**, **Analisar documentos**, **Reenviar convite** quando aplicável e **Inativar/Reativar**.

Resultados com paginação no servidor, ordenação estável e preservação dos filtros ao retornar de um detalhe. Distinguir lista vazia de pesquisa sem resultados.

### 5.3 Lista de organizações

Colunas: razão social, nome fantasia, CNPJ, segmento, status e quantidade de usuários vinculados. Quantidades devem vir de agregações no banco, sem uma consulta para cada linha.

Filtros: nome, CNPJ e status. Ações: **Ver detalhes**, **Editar**, **Gerenciar unidades**, **Vincular usuário** e **Inativar/Reativar**.

### 5.4 Detalhe do usuário

Seções: dados pessoais; conta e acesso; organizações e unidades; perfis por vínculo; documentos e análises; participações em auditorias; histórico de alterações.

Cada vínculo exibe sua própria situação. Exemplo: aprovado na Empresa A e pendente na Empresa B não deve ser resumido como acesso liberado para ambas.

### 5.5 Detalhe da organização

Seções: dados cadastrais; unidades; contatos; usuários vinculados; auditorias relacionadas; histórico de alterações.

Auditorias devem abrir seu contexto real. Não usar links para páginas demonstrativas com dados fixos como se fossem registros daquela empresa.

## 6. Cadastro de usuário

### 6.1 Campos

| Campo | Regra proposta |
|---|---|
| Nome completo | Obrigatório; texto com limites definidos no servidor |
| E-mail | Obrigatório; identificador de login; normalização consistente com Auth |
| CPF | Obrigatório para concluir a liberação; validar dígitos verificadores no servidor |
| Telefone | Opcional e recomendado |
| Cargo / função profissional | Obrigatório quando houver vínculo operacional; catálogo administrável |
| Perfil de acesso | Obrigatório para liberar o vínculo; um dos quatro perfis definidos |
| Organização | Obrigatória para perfis operacionais; dispensável para administrador global |
| Unidade | Opcional; se preenchida, deve pertencer à organização selecionada |
| Status | Mantido pelo Administrador, sem conceder acesso antes das demais aprovações |
| Documento de identificação | Exigido conforme regras cadastrais, enviado pelo próprio titular |

**Proposta para convite:** nome e e-mail permitem criar um cadastro pendente; CPF e demais itens obrigatórios devem estar completos antes da ativação operacional. Isso evita o Administrador precisar coletar tudo antes de convidar a pessoa.

### 6.2 Fluxo de convite pelo Administrador

1. Clicar em **Novo usuário**.
2. Informar nome, e-mail e dados disponíveis.
3. Selecionar cargo, perfil e organização/unidade, quando aplicáveis.
4. Revisar o resumo do acesso que será concedido.
5. Confirmar o cadastro. O servidor valida dados, duplicidade e autorização do Administrador.
6. Criar a conta ou identificar que ela já existe. Para conta existente, propor o vínculo sem substituir senha ou metadados pessoais.
7. Registrar a solicitação de convite e sua situação de envio.
8. O titular segue o convite, define sua senha quando necessário e completa seu cadastro.
9. O titular envia o documento de identificação exigido.
10. O Administrador aprova ou reprova o documento, com justificativa em caso de reprovação.
11. O acesso operacional é liberado somente após todos os requisitos do vínculo serem atendidos.

Convite enviado, conta criada e acesso liberado são resultados diferentes. A interface deve apresentar cada situação corretamente. O cadastro não deve ser perdido se o envio do e-mail falhar.

### 6.3 Fluxo de cadastro público existente

- A opção **Criar conta** continua disponível na tela de login.
- O cadastro público não permite escolher Administrador nem atribuir a si próprio um vínculo autorizado.
- Nome de empresa ou CNPJ informado pelo usuário é uma solicitação de vínculo, sujeita à validação; não libera dados da organização.
- A conta fica pendente até o Administrador definir o perfil, validar o vínculo e analisar os documentos exigidos.
- O Administrador deve conseguir encontrar esses cadastros na mesma lista de usuários, sem duplicar a pessoa.

### 6.4 Duplicidade, convite e recuperação

- E-mail existente não deve gerar outra conta. O Administrador consulta a pessoa existente e adiciona ou revisa o vínculo adequado.
- CPF duplicado ou divergente deve interromper a liberação e solicitar revisão; não unir contas automaticamente.
- Reenvio de convite deve ter limite e histórico para evitar duplicação e excesso de mensagens.
- Convites expirados devem permitir nova emissão autorizada, invalidando o anterior conforme o mecanismo adotado.
- Recuperação de senha usa o fluxo de autenticação; o Administrador não visualiza nem escolhe a senha atual do titular.
- Alteração do e-mail de login deve usar um fluxo próprio, mantendo Auth e perfil sincronizados e evitando simplesmente editar uma coluna de contato.

## 7. Cadastro de organização

### Campos da organização

| Campo | Obrigatoriedade |
|---|---|
| Razão social | Obrigatória |
| CNPJ | Obrigatório e único; normalizado e validado no servidor |
| Nome fantasia | Opcional |
| Segmento / ramo de atividade | Proposto como obrigatório para concluir cadastro |
| Endereço: logradouro, número, complemento, bairro, cidade, UF, CEP | Recomendado; obrigatoriedade final a validar |
| E-mail e telefone institucionais | Opcionais |
| Contatos responsáveis | Pelo menos um recomendado, sem bloquear rascunho |
| Status | Ativa ou inativa |

Um contato da organização não é automaticamente um usuário com login. A criação de acesso deve ser uma ação explícita, vinculada à conta correta.

### Fluxo

1. Clicar em **Nova organização** e informar os dados cadastrais.
2. Validar CNPJ, campos obrigatórios e possível duplicidade no servidor.
3. Registrar unidades e contatos, quando disponíveis.
4. Revisar e salvar a organização.
5. Abrir seu detalhe, com ações para vincular usuários existentes ou convidar novos usuários.
6. Disponibilizar a organização para seleção nas futuras auditorias, de acordo com a autorização do usuário.

A aplicação deve aceitar uma organização ainda sem usuários ou auditorias e explicar esse estado. Alterar CNPJ de organização já utilizada requer revisão administrativa e histórico; nunca deve trocar silenciosamente a identidade de uma empresa auditada.

### Unidades

Cada unidade pertence a uma organização, possui nome, localização e status. O usuário pode ter vínculo organizacional geral ou uma unidade específica. A regra de restrição por unidade deve ser expressa e validada no servidor; selecionar uma unidade no formulário, por si só, não implementa isolamento.

## 8. Estados e liberação de acesso

Evitar um único status para representar cadastro, convite, documentos e autorização.

| Dimensão | Estados conceituais propostos |
|---|---|
| Conta | Cadastro pendente, ativa, inativa |
| Convite | Não solicitado, pendente de envio, enviado, aceito, expirado, falhou |
| Vínculo organizacional | Ativo, inativo |
| Documentação do vínculo | Não exigida, pendente, aprovada, reprovada |
| Documento individual | Pendente, aprovado, reprovado |
| Organização/unidade | Ativa, inativa |

Os nomes técnicos definitivos serão mapeados para os estados já existentes. Não criar novas colunas ou enumerações apenas para reproduzir rótulos de interface quando um estado puder ser derivado corretamente.

Para perfis operacionais, a autorização exige cumulativamente: sessão válida; conta habilitada; dados obrigatórios completos; vínculo ativo; documentação aprovada ou legitimamente dispensada; organização/unidade elegível; permissão da ação; participação na auditoria quando necessária.

O administrador global usa autorização própria, sem depender de vínculo com cliente. Sua habilitação e eventual inativação também precisam ser verificadas no servidor.

### Acesso antes da aprovação

Disponibilizar somente: completar cadastro, enviar/substituir documento reprovado, acompanhar análise, consultar motivo da reprovação, recuperar senha e sair. Dados de auditorias e diretório global não ficam liberados.

### Documentos

- Documento de identificação é a única exigência inicial já aprovada. Certificados técnicos adicionais ficam para configuração futura.
- Regras devem ser associadas ao cargo/configuração documental, sem transformar o perfil de acesso em prova de qualificação.
- Upload privado; validar tamanho, formato e conteúdo do arquivo no servidor. Limite proposto: PDF/JPG/PNG até 10 MB, a validar.
- Administrador revisa; reprovação exige motivo legível e possibilidade de reenvio pelo titular.
- Substituições e análises anteriores permanecem rastreáveis, sem disponibilizar documentos a outros participantes da auditoria.
- Proposta: análises são controladas por vínculo, como na estrutura atual. Reutilização de uma aprovação entre empresas exige uma decisão explícita futura.

## 9. Gestão de alterações e inativação

### Dados pessoais e vínculos

Registrar autor, data/hora do servidor, entidade, ação e alterações relevantes. O histórico de permissões deve permitir identificar qual perfil ou vínculo foi alterado e por quem, sem copiar senhas, tokens ou arquivos pessoais para logs.

Mudanças de perfil devem mostrar previamente o que será concedido e revogado. O servidor precisa aplicar a nova autorização, inclusive em sessões já abertas; apenas renovar o menu do navegador não basta.

### Inativação

- **Conta:** bloqueia o acesso de login/operacional em todos os vínculos, preservando registros históricos.
- **Vínculo:** retira o acesso daquela organização e suas auditorias, mantendo os demais vínculos elegíveis.
- **Organização:** impede novas operações cadastrais e novas auditorias. Proposta: suspender acesso operacional de seus vinculados nessa empresa; o Administrador mantém consulta histórica.
- **Unidade:** bloqueia novos vínculos e operações da unidade; exige análise de auditorias em andamento antes da conclusão.

Antes de inativar alguém, apresentar dependências: auditorias lideradas, participações ativas e confirmações pendentes. Exigir substituição ou tratamento explícito das responsabilidades para não deixar uma auditoria sem líder.

Proteger a continuidade administrativa: não permitir remover/inativar o último Administrador ativo. Mudanças críticas de privilégios devem exigir confirmação específica e verificação recente da identidade de quem executa.

### Histórico em relatórios

O Auditor de apoio deve constar na equipe e nos relatórios referentes ao período em que participou. Removê-lo da equipe atual não pode apagar sua participação anterior nem mudar relatórios finalizados.

Relatórios congelados devem preservar o nome e o papel registrados naquela versão. Mudanças posteriores de nome, cargo ou perfil afetam o cadastro atual, sem reescrever documentos históricos.

## 10. Experiência e comportamento das telas

- Manter identidade visual atual, logo oficial, azul marinho, branco e azul de destaque.
- Usar formulários com etapas claras: dados pessoais; cargo/perfil; vínculos; revisão. O titular envia os documentos em seu fluxo de primeiro acesso.
- Mostrar a diferença entre salvar um cadastro e liberar acesso operacional.
- Identificar obrigatoriedade, erros junto ao campo e resumo das pendências.
- Preservar campos preenchidos em falhas recuperáveis e avisar antes de sair com alterações não salvas.
- Bloquear envio duplicado enquanto uma requisição estiver em andamento.
- Ações sensíveis exigem confirmação com nome da pessoa/organização afetada.
- Exibir estado de carregamento, vazio, sem resultados, sem permissão, falha e sucesso confirmado.
- Oferecer nova tentativa quando apropriado; não transformar falhas de consulta em listas vazias.
- Permitir teclado, foco visível e rótulos acessíveis. Tabelas devem ter alternativa legível ou rolagem horizontal em telas menores.
- Após salvar, abrir o registro gravado e atualizar contagens/listas relacionadas. O navegador não deve anunciar sucesso antes da confirmação do servidor.

## 11. Base técnica existente e reaproveitamento

Esta seção se baseia nos arquivos e migrations locais conhecidos do projeto. Não confirma que todas as migrations estejam aplicadas no Supabase remoto.

| Estrutura atual | Uso planejado |
|---|---|
| Supabase Auth | Login, convite/ativação, recuperação e alteração de credenciais |
| `user_profiles` | Dados pessoais da pessoa vinculada à conta |
| `organizations` | Empresas auditadas |
| `organization_units` | Unidades das empresas |
| `organization_memberships` | Vínculo, cargo, perfil, status e situação documental |
| `positions` | Catálogo de cargos e exigência inicial de identificação |
| `access_profiles` | Perfis de acesso |
| `access_permissions` | Catálogo de ações |
| `access_profile_permissions` | Permissões padrão dos perfis |
| `membership_permissions` | Exceções por vínculo, a revisar antes de habilitar personalização |
| `user_documents` | Arquivos de identificação e decisões de análise |
| `audit_participants` | Papel na auditoria, participação e indicação de signatário |
| `audits` | Organização, unidade e líder da auditoria |
| `audit_events` | Histórico de mudanças |
| `organization_contacts` | Contatos; estrutura proposta em migration local do Dashboard, aplicação remota ainda precisa ser confirmada |

### Lacunas a resolver na futura implementação

1. **Perfis antigos incompatíveis:** os modelos locais concedem escrita ao perfil Auditor. Planejar conversão dos quatro perfis e revisão das exceções individuais, preservando vínculos e histórico. Não transformar silenciosamente todos os Auditores antigos em líderes.
2. **Cadastro ainda demonstrativo:** a tela local de cadastro contém empresas, documentos e permissões de exemplo. Esses elementos não constituem implementação de backend e precisarão ser conectados às estruturas reais.
3. **Administrador global:** existe verificação de `app_metadata.platform_role=admin`. A gestão desse papel deve continuar em uma operação administrativa protegida; não substituir por `user_metadata` editável.
4. **Status global de conta:** os vínculos já têm status, mas a habilitação global, inclusive do Administrador, precisa de um desenho único de controle no servidor. Não confundir status do vínculo com bloqueio total da conta.
5. **Convites:** inventariar recursos de Auth e envio já configurados. Propor persistência mínima para solicitação, envio, falha, expiração e reenvio somente se não houver estrutura equivalente. `notification_outbox` atual está ligada a confirmações de relatórios e não deve ser reutilizada com relações fictícias para convites.
6. **Primeiro acesso e upload:** revisar a regra atual que exige vínculo já aprovado para operações documentais. O usuário pendente precisa poder enviar somente o próprio documento cadastral antes da aprovação, sem acesso aos dados operacionais.
7. **Visibilidade da equipe:** as regras atuais de perfis pessoais e vínculos são restritas a titular/Administrador. Planejar consulta limitada a nome e papel de colegas da mesma auditoria; não abrir CPF, e-mail privado ou documentos para resolver a exibição da equipe.
8. **Participação histórica:** confirmar como registrar entrada/saída da equipe por período e preservar a composição em versões finalizadas de relatórios.
9. **Campos das empresas:** verificar aplicação das extensões locais de nome fantasia, segmento, endereço e contatos antes de propor novos campos.
10. **Conteúdo do Auditado:** verificar a distinção entre informação disponibilizada e informação interna em relatórios, evidências e observações.

## 12. Segurança e operações no servidor

Toda operação deve verificar identidade, autorização e escopo no servidor. A interface reflete essa autorização, mas não é sua única barreira.

- RLS deve proteger registros por conta, vínculo, organização, unidade quando aplicável e auditoria.
- Operações administrativas de Auth precisam de backend confiável, com segredo fora do navegador e da distribuição pública dos arquivos estáticos.
- Um usuário comum não pode alterar seu papel, aprovar seus documentos, ativar seu vínculo, incluir-se em auditorias ou promover a própria conta.
- Um Administrador autenticado pode conceder os perfis previstos por meio de ações explícitas e registradas, respeitando a proteção do último Administrador.
- Alteração de identificadores enviados pelo navegador não pode permitir mover vínculo, documento, unidade ou participante para outra organização indevidamente.
- Verificar revogação de acesso com sessão antiga ainda aberta. Claims de sessão podem ficar desatualizadas; ações sensíveis precisam considerar o estado administrativo vigente.
- Buckets de documentos pessoais permanecem privados. Links temporários devem ser emitidos somente após autorização e não devem compor logs permanentes.
- Dados de Auth e cadastro precisam de fluxo recuperável: criação, perfil, vínculo e convite podem falhar em etapas distintas. Definir idempotência e reconciliação para evitar contas duplicadas ou cadastros sem vínculo.
- Exclusões em cascata de perfis, vínculos e permissões devem ser avaliadas antes de expor qualquer ação de remoção. Inativação é a ação padrão para cadastros utilizados.

Nenhuma mudança de RLS, função, tabela, segredo ou conta será executada durante a elaboração deste documento.

## 13. Como esta aba alimenta os outros módulos

| Módulo | Dados consumidos | Resultado esperado |
|---|---|---|
| Auditorias | Organização, unidade, líder e participantes elegíveis | Seleção de cadastros reais, sem nomes digitados novamente |
| Cronograma | Equipe autorizada e papel operacional | Somente responsáveis aptos para conduzir e registrar atividades |
| Relatórios | Empresa, contatos, líder, equipe e signatários | Equipe completa, incluindo Auditor de apoio; preservação do histórico |
| Dashboard | Organizações, vínculos e escopo do usuário | Indicadores visíveis apenas a quem tem autorização |
| Não conformidades e planos | Auditoria e usuários autorizados | Ações habilitadas conforme perfil e contexto |
| Documentos de competência | Cargo, titular e vínculo | Pendências e aprovação administrativa |

Cadastrar uma empresa não cria uma auditoria. Vincular alguém à empresa não o torna participante automaticamente. Incluir na equipe não o torna signatário automaticamente. Esses passos têm finalidades e autorizações próprias.

No acompanhamento do Auditado, “dias restantes” deve indicar a regra usada. Proposta: dias corridos até a data prevista de término, exibindo atraso separadamente; quantidade de dias de auditoria ainda previstos é outro indicador, calculado pelo cronograma.

## 14. Critérios de aceite e validação futura

| ID | Cenário | Resultado verificável |
|---|---|---|
| U01 | Administrador abre Usuários | Consegue navegar entre pessoas, organizações e documentos pendentes |
| U02 | Pessoa sem permissão tenta gestão global por URL/API | Servidor nega a operação e não retorna o diretório global |
| U03 | Administrador cadastra usuário | Registro persiste após recarregar e fica ligado à conta correta |
| U04 | Cadastro repete e-mail existente | Não cria conta duplicada nem redefine a senha; oferece vínculo autorizado |
| U05 | CPF ou CNPJ inválido é enviado diretamente à API | Servidor rejeita com erro tratável |
| U06 | Titular recebe convite | Consegue ativar conta, definir senha e completar cadastro conforme o estado |
| U07 | Envio do convite falha | Cadastro continua identificável; falha é exibida e reenvio não duplica a conta |
| U08 | Usuário pendente entra no sistema | Vê suas pendências; não vê dados de auditorias |
| U09 | Usuário pendente envia identificação | Pode enviar somente para seu próprio vínculo; Administrador recebe a pendência |
| U10 | Documento é reprovado | Motivo obrigatório; titular pode reenviar e consultar a decisão |
| U11 | Administrador aprova documentação | Liberação depende também dos demais critérios; não concede participação automaticamente |
| U12 | Auditor Líder atua em auditoria autorizada | Consegue registrar avaliações, NCs, evidências e relatórios e conduzir seu ciclo |
| U13 | Auditor tenta alterar registros pela API | Servidor nega a escrita mesmo que ele forje uma requisição |
| U14 | Auditor participa como apoio | Nome e papel aparecem na equipe e no relatório correspondente |
| U15 | Auditado da Empresa A tenta consultar a Empresa B | Servidor nega dados, arquivos e indicadores fora de seu escopo |
| U16 | Usuário tem duas empresas e apenas uma auditoria autorizada | Não ganha acesso às demais auditorias por compartilhar a empresa |
| U17 | Perfil ou vínculo é revogado com sessão aberta | Próxima operação protegida respeita a revogação vigente |
| U18 | Conta, vínculo ou organização é inativado | Efeito corresponde ao escopo escolhido; histórico continua disponível ao Administrador |
| U19 | Último Administrador seria removido | Operação é impedida e explica como manter continuidade administrativa |
| U20 | Perfil muda depois de relatório finalizado | Relatório e composição histórica da equipe não são sobrescritos |
| U21 | Usuário não designado tenta confirmar ciência | Servidor nega; designado confirma somente em nome próprio |
| U22 | Administrador atribui unidade de outra empresa | Servidor rejeita o vínculo inconsistente |
| U23 | Usuário altera seu cadastro público para pedir papel admin | Não obtém elevação de privilégio |
| U24 | Listas possuem muitos registros | Filtros, paginação e ordenação funcionam no servidor sem carregar todo o histórico |
| U25 | Navegação em desktop, celular e teclado | Menu, formulários, erros e ações principais continuam acessíveis |

Esses cenários são o plano de testes futuro. Não foram executados nesta etapa documental.

## 15. Sequência sugerida de desenvolvimento

### Etapa 1 — Compatibilidade e autorização

Confirmar schema remoto e migrations aplicadas; definir mapeamento dos quatro perfis; revisar escrita do Auditor e escopo do Auditado; resolver acesso de primeiro login, revogação, participação histórica e dados públicos da equipe. Preparar migrations versionadas somente após essa conferência.

### Etapa 2 — Organizações e unidades

Implementar listagem, pesquisa, paginação, criação, edição, detalhe, contatos e inativação. Validar persistência e isolamento. Entregar link local para validação.

### Etapa 3 — Usuários e vínculos

Implementar listagem, cadastro/convite, tratamento de contas existentes, perfil por vínculo e detalhe do usuário. Validar criação recuperável, duplicidade e ausência de autoelevação. Entregar link local para validação.

### Etapa 4 — Documentos e liberação

Implementar primeiro acesso restrito, envio privado, análise administrativa, motivo de reprovação e reenvio. Validar a separação entre aprovação documental e autorização operacional.

### Etapa 5 — Integração com auditorias e relatórios

Conectar seleção de líder, auditores de apoio, auditados e signatários a cadastros reais; garantir nomes da equipe nos relatórios, snapshots e escopo no Dashboard.

### Etapa 6 — Gestão avançada e revisão final

Implementar histórico administrativo, revisão de dependências para inativação e configurações de cargos/perfis aprovadas. Testar matriz de permissões com contas distintas e registros de empresas diferentes antes de liberar o piloto.

Cada entrega deve informar o que foi implementado, o que foi aplicado ao Supabase, o que foi validado, pendências e o link do aplicativo para revisão. Preparar arquivos locais e aplicar ao banco remoto devem ser reportados como etapas distintas.

## 16. Pontos para validar antes de desenvolver

| Decisão | Proposta de partida |
|---|---|
| Nome do quarto perfil | Participante / Auditado; Cliente permanece como referência do perfil anterior |
| Gestão global do módulo | Somente Administrador |
| Criação de auditorias e seleção da equipe pelo líder | Permitidas em organizações autorizadas, com pessoas já cadastradas e elegíveis |
| Vínculos com várias empresas | Permitidos, com escopo independente |
| Convite e cadastro público | Ambos mantidos, convergindo para aprovação administrativa |
| Campos para enviar convite | Nome e e-mail; demais obrigatórios completos antes da liberação |
| Documento obrigatório | Identificação para Líder, Auditor e Auditado; tratamento do Administrador a confirmar |
| Reaproveitamento de aprovação documental | Controle por vínculo inicialmente; reaproveitamento futuro mediante regra explícita |
| Contatos e endereço da empresa | Recomendados; segmento obrigatório ao concluir cadastro |
| Planos de ação do Auditor Líder | Criação/edição permitidas; regra de aprovação por quem executou permanece pendente |
| Personalização de permissões | Etapa posterior; não contrariar silenciosamente o perfil Auditor observador |
| Inativação da organização | Suspender acesso operacional nessa empresa e preservar consulta administrativa |

Essas propostas permitem revisar o escopo sem confundir decisões já confirmadas com novas escolhas de produto. Após a validação, esta especificação pode orientar o backlog técnico, as migrations e a implementação navegável do módulo.
