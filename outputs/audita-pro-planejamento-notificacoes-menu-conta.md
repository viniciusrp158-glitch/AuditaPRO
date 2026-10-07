# Audita PRO — Planejamento de notificações e menu da conta

**Versão:** 1.0  
**Situação:** proposta para validação.  
**Entrega atual:** somente documentação. Nenhuma alteração no aplicativo, no banco ou nas permissões nesta etapa.

## 1. Objetivo

Adicionar ao canto superior direito das páginas autenticadas um cabeçalho comum com sino de notificações, identificação do usuário e menu da conta. O usuário deverá perceber quando recebeu uma demanda, abrir o registro correspondente e acompanhar o resultado da ação.

A primeira entrega terá como prioridade o fluxo de Meu Perfil: avisar o Administrador responsável sobre cadastros enviados e avisar o titular sobre aprovação ou necessidade de correção. A estrutura deverá permitir incluir posteriormente eventos de auditorias, cronogramas, não conformidades, planos de ação e relatórios.

## 2. Aparência do cabeçalho

Seguir a disposição da imagem de referência:

**Sino com contador → separador visual → ícone de pessoa → nome do usuário / perfil de acesso → seta para baixo.**

| Elemento | Apresentação e comportamento |
|---|---|
| Sino | Ícone simples, com contador de notificações não lidas; abre o painel de notificações |
| Contador | Oculto quando for zero; exibir número até 99 e “99+” acima disso |
| Ícone de pessoa | Avatar genérico ou iniciais; envio de foto fica para uma evolução |
| Nome | Nome do usuário autenticado, obtido do cadastro; nomes longos podem ser abreviados visualmente, com nome completo acessível |
| Perfil | Abaixo do nome, em tamanho menor: Administrador, Auditor Líder, Auditor ou Participante / Auditado |
| Seta | Abre o menu da conta; o bloco de nome/avatar também pode abrir o mesmo menu |

Manter azul marinho, branco e azul de destaque, com ícones legíveis e boa separação entre o sino e o menu. O cabeçalho será um componente compartilhado para manter comportamento consistente entre as abas. A logo e o menu lateral continuarão seguindo a navegação existente.

### Identificação correta do perfil

- Administrador global: exibir **Administrador**.
- Usuário com vínculo operacional: exibir o perfil autorizado no contexto da empresa selecionada.
- Usuário com vários vínculos e sem contexto selecionado: exibir **Múltiplos vínculos** e permitir consultar os perfis em Meu Perfil, evitando indicar um perfil global incorreto.
- Usuário sem perfil atribuído: exibir **Cadastro em validação** ou **Perfil a definir**, conforme a situação real.
- A indicação visual não concede permissões. A autorização permanece no servidor.

## 3. Menu da conta

Ao clicar na seta, no nome ou no avatar, abrir um menu ancorado no canto superior direito.

| Opção | Comportamento planejado |
|---|---|
| Meu Perfil | Abrir a aba Meu Perfil existente |
| Configurações | Exibir a opção com indicação “Em breve”, sem aparentar uma função já disponível |
| Ajuda | Exibir a opção com indicação “Em breve”, até existir conteúdo de ajuda aprovado |
| Sair | Encerrar a sessão e encaminhar à tela de login |

Configurações e Ajuda deverão ficar visíveis, conforme solicitado, com explicação de indisponibilidade e sem links quebrados. Como alternativa futura, poderão abrir um pequeno painel explicativo; isso não exige criar agora módulos completos de configurações ou atendimento.

Fechar o menu ao clicar fora, selecionar uma opção ou pressionar Escape. Permitir abertura e navegação por teclado, foco visível e rótulos acessíveis. Somente um dos dois painéis — conta ou notificações — permanecerá aberto de cada vez.

## 4. Painel do sino

O sino abrirá um painel com título **Notificações**, contador de não lidas e acesso às mensagens mais recentes.

Cada item apresentará:

- Ícone da categoria e título curto.
- Mensagem objetiva: o que ocorreu e o que o destinatário precisa fazer.
- Data/hora ou tempo decorrido, com data completa disponível.
- Indicação de não lida.
- Indicação separada de **Ação pendente**, **Resolvida** ou **Sem ação necessária**.
- Ação contextual, como **Analisar cadastro**, **Corrigir Meu Perfil** ou **Ver resultado**.

O painel terá filtros **Todas**, **Não lidas** e **Ação pendente**, além de **Marcar todas como lidas**. Exibir uma quantidade limitada de itens e **Ver todas as notificações**, abrindo uma central com paginação. A central poderá existir como página acessível pelo sino, sem acrescentar outra opção ao menu lateral.

### Leitura e resolução são estados diferentes

- Abrir o sino não marcará automaticamente todas as notificações como lidas.
- Abrir um item ou usar **Marcar como lida** altera somente o estado de leitura daquele destinatário.
- Uma demanda continua em **Ação pendente** até que a ação seja concluída no módulo correspondente.
- O contador do sino representa não lidas. O filtro **Ação pendente** continua mostrando tarefas que já foram lidas.
- A resolução deverá ser derivada do registro real do processo, e não de um botão que apenas esconda a notificação.
- Nesta primeira versão, não haverá exclusão manual de notificações nem arquivamento de demandas pendentes.

## 5. Momento correto do aviso de cadastro

No fluxo atual, anexar um arquivo é uma ação de rascunho. O cadastro pode ainda estar incompleto ou precisar de outro documento.

**Proposta principal:** criar a notificação administrativa quando o titular clicar em **Enviar para validação** e o servidor confirmar o envio completo. Não disparar uma demanda de análise a cada arquivo anexado ou substituído durante o preenchimento.

Após anexar um arquivo, informar ao titular: **“Documento salvo. Revise o cadastro e clique em Enviar para validação para avisar o Administrador.”**

Após o envio confirmado: **“Cadastro enviado para validação. A pendência foi disponibilizada ao responsável.”** Essa mensagem somente deve aparecer quando a submissão e sua notificação tiverem sido registradas com sucesso.

## 6. Eventos da primeira entrega

| Evento real | Destinatário | Exemplo de mensagem | Ação |
|---|---|---|---|
| Primeiro envio para validação | Administrador designado, normalmente quem criou o vínculo/convite | “João Silva enviou o cadastro para validação.” | Analisar cadastro |
| Nova versão após correção | Administrador responsável pela nova versão | “João Silva reenviou o cadastro com correções.” | Analisar nova versão |
| Cadastro sem responsável ativo | Administradores ativos autorizados a atribuir responsáveis | “Um cadastro aguarda definição do responsável pela análise.” | Atribuir responsável |
| Reatribuição da análise | Novo responsável | “Você foi designado para analisar este cadastro.” | Analisar cadastro |
| Correção solicitada ao concluir a análise | Titular | “Seu cadastro precisa de correção. Consulte os itens indicados.” | Corrigir Meu Perfil |
| Cadastro integralmente aprovado | Titular | “Seu cadastro foi aprovado.” | Ver resultado |
| Envio retirado pelo titular | Responsável que possuía a demanda | “O cadastro foi retirado para correção.” | Consultar situação |

### Regras para evitar avisos excessivos

- Um envio com identificação e certificado gera uma demanda de cadastro, e não duas notificações de tarefa.
- Aprovar um documento isolado não significa aprovar o cadastro completo. O resultado principal enviado ao titular será a decisão final do cadastro.
- Reprovações de documentos aparecerão na análise. O aviso de correção ao titular será gerado quando o Administrador concluir a decisão de solicitar correção.
- Cliques repetidos, reprocessamento ou reconexão não podem criar notificações duplicadas para o mesmo evento e destinatário.
- Uma nova versão gera uma nova notificação; o aviso da versão anterior conserva o histórico e deixa de apontar uma ação pendente.
- Ao reatribuir, a demanda anterior deixa de exigir ação do antigo responsável. O novo responsável recebe sua própria notificação.
- Retirada do envio encerra a demanda daquela versão. A interface deverá explicar a retirada caso alguém abra o aviso antigo.

Para envios sem responsável, a proposta é disponibilizar o aviso de atribuição aos Administradores globais ativos. Assim que um deles atribuir o responsável, os avisos de atribuição ficam resolvidos para todos, e somente o responsável designado recebe a demanda de análise.

## 7. Exemplo do fluxo completo

1. O Administrador cria ou convida João, com perfil Participante / Auditado e vínculo com a empresa.
2. João entra, completa Meu Perfil e anexa a identificação. O sistema salva o rascunho e orienta a enviar para validação.
3. João confirma o envio. O banco registra a versão submetida e a notificação destinada ao Administrador responsável.
4. O sino do Administrador passa a indicar uma nova mensagem. Ao abrir o item, ele vê o nome, o contexto autorizado e a ação **Analisar cadastro**.
5. A ação abre diretamente o cadastro e a versão corretos na área de validação.
6. O Administrador analisa os documentos e conclui pela aprovação ou pela solicitação de correção.
7. A demanda administrativa é resolvida. João recebe a notificação correspondente.
8. Se houver correção, João abre o aviso, consulta os motivos em Meu Perfil, corrige e envia nova versão.

O motivo detalhado de reprovação ficará dentro da página protegida de análise. O resumo do sino evitará CPF, número de documento e outras informações pessoais desnecessárias.

## 8. Destinos e permissões

Os links devem levar ao registro real: submissão, versão, organização e usuário correspondentes. Atualmente, a fila de revisão possui um endereço geral; a implementação deverá acrescentar abertura direta por identificador e validar esse acesso no servidor.

- Cada usuário lê e marca somente as próprias notificações.
- Ser Administrador não implica consultar a caixa pessoal de notificações de outros usuários. A gestão global de pendências continuará no módulo Usuários.
- Receber um aviso não concede acesso ao cadastro ou aos documentos. A ação precisa verificar as permissões atuais novamente.
- Caso a responsabilidade tenha mudado, o aviso deverá informar que a demanda foi reatribuída; não abrir documentos sem autorização.
- Usuários ainda pendentes de aprovação poderão acessar seus próprios avisos, Meu Perfil e o menu da conta.
- Nenhum destinatário será determinado por dados manipuláveis enviados pelo navegador. O servidor identifica titular e responsável a partir do fluxo existente.
- Mensagens não incluirão senhas, tokens, arquivos, CPF completo nem URLs permanentes de documentos privados.
- Na saída ou troca de conta, limpar os dados de notificações em memória e encerrar eventuais assinaturas de atualização.

## 9. Atualização das notificações

As notificações serão persistentes. Se o destinatário estiver desconectado, encontrará os avisos no próximo acesso.

Proposta inicial de atualização:

- Consultar contador e lista ao entrar no aplicativo.
- Atualizar ao abrir o sino e ao retornar à janela.
- Enquanto a aplicação estiver visível, consultar mudanças a cada 30 segundos; suspender essa consulta em segundo plano.
- Após uma ação na própria tela, atualizar imediatamente sua situação local confirmada pelo servidor.
- Se a conexão falhar, preservar a última visualização e informar **“Não foi possível atualizar as notificações”**, com **Tentar novamente**. Não substituir uma falha por contador zero.

O intervalo de 30 segundos é uma proposta operacional, não uma garantia de entrega instantânea. Supabase Realtime poderá substituir ou complementar a consulta periódica após avaliação de permissões, consumo e reconexão. Não será requisito obrigatório para o primeiro incremento.

Não solicitar permissão de notificações do navegador nesta fase. E-mail, push, som e WhatsApp ficam fora desta primeira entrega.

## 10. Aproveitamento da arquitetura atual

Este planejamento consultou os arquivos locais do projeto e o registro de entrega de Meu Perfil. Não foi realizada uma nova inspeção do banco remoto.

### Estruturas existentes relevantes

| Estrutura | Papel no planejamento |
|---|---|
| `user_profiles` | Nome e identificação da conta |
| Auth, `access_profiles` e `organization_memberships` | Papel global, perfil operacional e contexto de empresa |
| `profile_submissions` | Versão, titular, responsável, envio e decisão do cadastro |
| `user_documents` | Documentos vinculados à análise; os arquivos continuam privados |
| `audit_events` | Histórico de eventos do processo; não substitui a caixa individual de notificações |
| `notification_outbox` | Fila existente para notificações ligadas às confirmações de ciência de relatórios |

Nas migrations locais, `notification_outbox` exige `acknowledgement_id` e possui canal, agendamento, envio e tentativas. Ela está vinculada às confirmações de relatórios e não representa, sozinha, uma caixa genérica com destinatário e estado de leitura.

### Evolução técnica proposta

Criar uma estrutura de notificações individuais no aplicativo, após confirmar o schema remoto. Essa estrutura representa uma necessidade diferente da fila de entrega: evento, destinatário, contexto, leitura e demanda associada. A fila existente de relatórios deverá ser preservada e integrada quando esses eventos forem incluídos.

Campos conceituais previstos:

- Identificador da notificação e destinatário.
- Tipo de evento e chave única para impedir duplicidade por destinatário.
- Tipo e identificador do registro relacionado, incluindo versão quando houver.
- Organização e auditoria, apenas quando aplicáveis.
- Título, resumo mínimo e data de criação.
- Data de leitura.
- Referência à ação necessária e situação de resolução, derivada do processo ou sincronizada de forma controlada.

A ação será um tipo conhecido pela aplicação, como `review_profile`, com identificadores validados. Não aceitar uma URL arbitrária fornecida por outro usuário.

Registrar a notificação de envio na mesma transação que confirma a submissão. A fila da caixa pessoal não deverá depender de o destinatário estar online. Respostas repetidas devem reutilizar o mesmo evento, respeitando a chave de deduplicação.

O frontend compartilhará um único componente de cabeçalho, menu e sino entre as páginas atuais, sem exigir migração geral de framework. Consultas serão limitadas e paginadas, com índices por destinatário, leitura e data, conforme o plano de consulta real.

## 11. Experiência e estados da interface

| Situação | Resposta esperada |
|---|---|
| Carregando | Indicador discreto, sem contador inventado |
| Nenhuma notificação | “Você não tem notificações no momento.” |
| Nenhuma não lida | “Você está em dia com suas notificações.” |
| Nenhuma ação pendente | “Nenhuma ação pendente para você.” |
| Falha de conexão | Explicação e opção de tentar novamente, preservando dados anteriores |
| Aviso antigo | Informar resultado, retirada ou reatribuição da demanda |
| Acesso revogado | Informar indisponibilidade sem revelar dados do registro |

No celular, reduzir o texto do cabeçalho sem perder o acesso ao nome e ao perfil no menu. O painel do sino poderá ocupar quase toda a largura da tela. Contadores e situações terão rótulos para leitores de tela; cor não será o único sinal de leitura ou pendência.

## 12. Histórico, lembretes e retenção

A primeira versão manterá os avisos de resultado e a associação às versões do processo. A retenção da caixa de notificações não será confundida com a retenção dos documentos e do histórico de auditoria. O prazo de limpeza das mensagens deve ser definido antes de qualquer exclusão automática.

Lembretes de tarefas antigas são uma melhoria sugerida para uma etapa posterior. Poderão considerar prazo e responsável, com frequência configurável e interrupção quando a demanda for resolvida, retirada ou reatribuída. Não classificar uma análise como “atrasada” enquanto não houver prazo de atendimento definido.

## 13. Critérios de aceite

| ID | Verificação | Resultado esperado |
|---|---|---|
| N-01 | Navegar entre páginas autenticadas | Mesmo cabeçalho, sino e menu da conta |
| N-02 | Entrar com cada perfil | Nome e título corretos, incluindo pendente e múltiplos vínculos |
| N-03 | Abrir menu por mouse ou teclado | Meu Perfil, Configurações, Ajuda e Sair visíveis; opções futuras identificadas |
| N-04 | Apenas anexar arquivo em rascunho | Orientar o envio; não criar demanda prematura de análise |
| N-05 | Enviar cadastro completo | Criar uma notificação para o responsável correto |
| N-06 | Repetir o envio ou reprocessar evento | Não duplicar o aviso da mesma versão |
| N-07 | Abrir uma notificação | Abrir registro/versão corretos e marcar apenas aquele aviso como lido |
| N-08 | Ler demanda sem concluí-la | Continuar no filtro Ação pendente |
| N-09 | Aprovar integralmente ou solicitar correção | Resolver demanda administrativa e notificar o titular |
| N-10 | Reatribuir ou retirar envio | Atualizar a pendência anterior e respeitar a nova autorização |
| N-11 | Envio sem responsável ativo | Permitir atribuição pela administração, com resolução dos avisos correspondentes |
| N-12 | Reenviar após correção | Nova notificação vinculada à nova versão |
| N-13 | Tentar consultar/marcar aviso de outra pessoa | Operação recusada no servidor |
| N-14 | Desconectar e entrar novamente | Manter avisos e estados de leitura |
| N-15 | Falha de rede | Exibir erro recuperável sem indicar falsamente que não há notificações |
| N-16 | Testar celular, teclado e leitor de tela | Menu e painel utilizáveis sem perda das ações essenciais |
| N-17 | Ter muitas mensagens | Paginação e contador correto, sem carregar todo o histórico |
| N-18 | Sair ou trocar de conta | Não exibir mensagens da sessão anterior |

## 14. Etapas de desenvolvimento após aprovação

1. Conferir o schema remoto e os eventos existentes de Meu Perfil, incluindo atribuição, retirada e decisão.
2. Definir a estrutura da caixa individual, migrations, políticas RLS, deduplicação e criação transacional dos eventos.
3. Implementar o cabeçalho compartilhado e o menu de conta.
4. Implementar sino, contador, painel e central paginada.
5. Integrar os eventos de Meu Perfil e a abertura direta do cadastro correto na fila de validação.
6. Verificar permissões, leitura versus resolução, reconexão e comportamento responsivo.
7. Disponibilizar o link do aplicativo para validação com as contas de Administrador e Participante/Auditado.

## 15. Decisões propostas para validar

1. Avisar o Administrador após **Enviar para validação**, e não a cada anexo em rascunho.
2. Usar o contador do sino para não lidas e um filtro separado para ações pendentes.
3. Mostrar Configurações e Ajuda com indicação **Em breve**.
4. Começar com notificações dentro do aplicativo e consulta periódica de 30 segundos enquanto a janela estiver visível.
5. Notificar inicialmente os eventos de cadastro/competência; incluir outros módulos conforme os fluxos reais forem desenvolvidos.
6. Distribuir avisos de falta de responsável aos Administradores globais ativos, resolvendo-os assim que ocorrer uma atribuição.
7. Usar avatar genérico ou iniciais nesta fase, com foto pessoal como evolução.

**A implementação permanece aguardando a validação deste documento.**
