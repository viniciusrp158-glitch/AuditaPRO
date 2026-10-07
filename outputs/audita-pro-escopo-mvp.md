# Audita PRO — Escopo técnico do MVP

**Versão:** 0.2 — decisões incorporadas; fluxo GOV a confirmar  
**Data:** 5 de outubro de 2026  
**Objetivo:** delimitar a primeira versão funcional do Audita PRO com foco no ciclo de auditoria e no relatório diário.

## 1. Resumo executivo

O MVP será uma aplicação web responsiva para planejar e conduzir auditorias de Segurança do Trabalho e Meio Ambiente, registrar o que ocorreu, acompanhar o cronograma, documentar achados e emitir relatórios diários para revisão, confirmação de ciência e assinatura externa via GOV.

O fluxo principal será:

**Empresa e equipe → auditoria e cronograma → execução e evidências → relatório diário → revisão do Auditor Líder → confirmação de ciência → assinatura externa via GOV → biblioteca de relatórios**

A primeira versão deve permitir cadastrar requisitos de auditoria por modelos configuráveis. O sistema não deve incluir textos integrais de normas protegidas nem presumir que um checklist substitui a avaliação profissional do auditor.

## 2. Objetivos do MVP

- Apoiar o Auditor Líder no planejamento e na execução de uma auditoria.
- Registrar quem fez cada alteração, quando e em qual auditoria.
- Comparar as etapas previstas no cronograma com as realizadas.
- Transferir etapas não concluídas para outro dia, preservando a origem.
- Gerar um relatório diário a partir dos registros do sistema e permitir revisão humana.
- Coletar confirmações de ciência dos signatários escolhidos e arquivar a cópia assinada via GOV junto à versão identificada do relatório.
- Guardar auditorias e relatórios com acesso controlado por empresa e função.
- Dar ao Administrador da plataforma uma visão global de empresas, usuários vinculados e histórico de auditorias.

### Indicadores de sucesso sugeridos para o piloto

- Uma auditoria pode ser planejada, executada e encerrada sem manter um segundo registro paralelo para os mesmos dados.
- O relatório diário apresenta os processos, requisitos, achados, observações e planos de ação registrados naquele dia.
- Etapas pendentes ficam visíveis, com transferência rastreável para o próximo dia.
- O Auditor Líder consegue identificar confirmações pendentes e localizar a cópia assinada via GOV.
- Usuários de uma empresa não conseguem consultar dados de outra empresa sem autorização.

## 3. Usuários e permissões

O sistema terá permissões atribuídas por usuário e por empresa/unidade. Um perfil pode preencher permissões iniciais, mas o administrador autorizado poderá personalizar as permissões de cada usuário.

| Papel inicial | Capacidades típicas |
|---|---|
| Administrador da plataforma | Consultar empresas por nome/CNPJ, visualizar usuários e histórico de auditorias; configurar usuários, cargos, perfis e modelos de checklist |
| Auditor Líder | Planejar auditorias, atribuir equipe, revisar registros, editar e finalizar relatórios, acompanhar assinaturas |
| Auditor | Executar etapas autorizadas, avaliar requisitos, registrar evidências, observações e não conformidades |
| Cliente | Visualizar auditorias e confirmar ciência quando selecionado como signatário; sem editar achados ou enviar evidências |
| Participante / Consulta | Visualizar conteúdo autorizado; só confirma ciência quando selecionado como signatário pelo Auditor Líder |

Permissões individuais previstas como configuráveis: visualizar, criar, editar, aprovar, finalizar, confirmar ciência e exportar. O acesso a uma auditoria deve depender também da empresa, unidade e participação do usuário naquela auditoria.

**Regra de competência:** Auditor Líder, Auditor e Cliente devem enviar um documento de identificação ao acessar o cadastro em seu dispositivo. O Administrador da plataforma valida o documento. No MVP, não serão exigidos outros comprovantes técnicos; funções restritas ficam bloqueadas até a aprovação. O tipo de documento aceito será definido antes do piloto.

## 4. Escopo funcional

### 4.1 Organizações, unidades e usuários

- Cadastrar empresa (incluindo nome e CNPJ) e uma ou mais unidades.
- Dar ao Administrador da plataforma uma visão global de empresas com busca por nome ou CNPJ e acesso aos dados da empresa, usuários vinculados e histórico de auditorias. Gestão de usuários pelo próprio cliente fica fora do MVP.
- Cadastrar usuário com nome, CPF, e-mail, telefone opcional, empresa/unidade e status.
- Definir cargo, perfil-base e permissões individuais.
- Configurar cargos e permissões; exigir documento de identificação para Auditor Líder, Auditor e Cliente.
- Permitir que o usuário envie o documento de identificação a partir de seu dispositivo; o Administrador analisa e registra estado enviado, pendente, aprovado ou recusado, responsável, data e motivo.
- Impedir o acesso às funções restritas enquanto a aprovação exigida estiver pendente ou recusada.
- Desativar usuário sem apagar o histórico de ações já realizadas.

### 4.2 Planejamento da auditoria

- Criar auditoria vinculada à empresa/unidade, com identificador, objetivo, escopo, normas/modelos selecionados, período e equipe.
- Definir Auditor Líder, auditores, contatos do cliente e participantes.
- Criar cronograma por dia, com horário, processo/área, atividade, requisito associado e responsável.
- Reordenar e editar etapas enquanto a auditoria estiver em planejamento.
- Usar checklist configurável: seções, requisitos, referência/cláusula, orientação e resultado esperado.
- Permitir duplicar um modelo de checklist para uma auditoria e registrar a versão utilizada.

**Estados da auditoria:** rascunho, planejada, em andamento, aguardando confirmações/assinatura GOV, concluída e cancelada. Mudanças de estado ficam registradas.

### 4.3 Execução da auditoria

- Registrar início e término da auditoria e dos dias auditados.
- Marcar cada etapa planejada como não iniciada, em andamento, realizada ou não realizada.
- Registrar resultado do requisito, observação, processo, responsável pelo registro e horário.
- Permitir resultados configuráveis, com opções iniciais: conforme, não conforme, oportunidade de melhoria, não aplicável e não avaliado.
- Anexar evidências aos requisitos e achados, com descrição, autor e data.
- Criar não conformidade com identificador, descrição, processo, requisito relacionado, classificação configurável e situação.
- Criar plano de ação relacionado a um achado, com ação, responsável e prazo.
- Registrar alterações importantes em uma trilha de auditoria: autor, horário, tipo de operação e objeto afetado.

**Transferência de etapa:** uma etapa não realizada pode ser movida para outro dia da mesma auditoria. O sistema preserva dia de origem, motivo, usuário que transferiu e dia de destino; a etapa permanece pendente até sua conclusão. O relatório de origem exibe a pendência e o relatório do destino identifica que ela veio de dia anterior. Requisitos, achados e evidências já registrados permanecem associados aos registros originais.

### 4.4 Relatório diário

- Gerar um rascunho por dia de auditoria a partir dos dados registrados, incluindo:
  - empresa, normas/modelos, Auditor Líder, equipe, data, número do dia e horários;
  - processos e requisitos avaliados;
  - comparação entre etapas planejadas, realizadas, pendentes e transferidas;
  - não conformidades e situação;
  - observações do auditor;
  - planos de ação, responsáveis e prazos.
- Permitir ao Auditor Líder acrescentar observações e revisar os textos gerados.
- Mostrar a origem dos dados e os itens que ainda estão incompletos.
- Salvar rascunhos e registrar autor e horário das alterações.
- Ao finalizar, criar uma versão identificada e bloquear edição daquela versão.
- Permitir ao Auditor Líder selecionar explicitamente os signatários obrigatórios; os demais participantes não precisam confirmar ciência.
- Registrar confirmação de ciência na plataforma para a versão exata do relatório, com usuário autenticado e data/hora. Essa confirmação não será apresentada como assinatura legal.
- Para respaldo legal, o relatório será assinado fora do Audita PRO via GOV. A integração automática com GOV fica fora do MVP; a proposta é baixar o PDF, assiná-lo via GOV e anexar a cópia assinada ao relatório para arquivamento.
- Exibir o estado de cada confirmação e etapa externa, com linha do tempo, data/hora, usuário e evento.
- Arquivar o relatório quando as confirmações obrigatórias forem concluídas e a cópia assinada via GOV for anexada.
- Disponibilizar relatórios concluídos na biblioteca da auditoria, com busca e filtros básicos.

**Correção após finalização:** a versão finalizada ou assinada não deve ser sobrescrita. Se for necessário corrigir, o Auditor Líder cria uma nova versão, informa o motivo e solicita novamente as confirmações de ciência e assinatura GOV. A versão anterior e seu histórico permanecem disponíveis conforme a política de retenção.

### 4.5 Notificações

- Aviso dentro da aplicação quando houver relatório aguardando confirmação de ciência.
- E-mail de solicitação de confirmação e lembretes configuráveis, inicialmente após 24 e 48 horas.
- Registrar envio e resultado do envio; permitir reenvio autorizado.
- Não enviar notificações duplicadas para uma confirmação concluída.

### 4.6 Biblioteca e exportação

- Listar relatórios por empresa, auditoria, data, estado e confirmação pendente.
- Consultar o relatório arquivado e sua linha do tempo.
- Exportar relatório final em PDF com identificador da auditoria, versão, estado das confirmações e participantes.
- Baixar anexos apenas para usuários com permissão.

## 5. Regras de negócio essenciais

1. Uma auditoria pertence a uma empresa/unidade e tem equipe e participantes definidos.
2. Os registros da execução ficam associados a um dia de auditoria e, quando aplicável, a processo, requisito e etapa do cronograma.
3. O relatório mostra o estado do cronograma no momento da geração e identifica pendências transferidas.
4. Antes de finalizar, o Auditor Líder é alertado sobre etapas pendentes. Deve transferi-las ou registrar justificativa/dispensa autorizada.
5. Finalizar cria uma versão imutável. Não se altera o documento finalizado.
6. Apenas os signatários definidos pelo Auditor Líder precisam confirmar ciência; cada confirmação fica vinculada à versão e registra usuário e data/hora.
7. O estado “assinado via GOV” só é exibido quando a cópia assinada externamente tiver sido anexada e registrada; a confirmação de ciência na plataforma é exibida separadamente.
8. Alterações relevantes e decisões de aprovação deixam trilha de auditoria.
9. A remoção de usuários ou registros não deve apagar evidências necessárias à rastreabilidade; usar inativação ou cancelamento com motivo.
10. A disponibilidade de conteúdo e funções deve respeitar empresa, unidade, participação e permissões.

## 6. Proposta técnica inicial

Arquitetura sugerida para estimativa, sujeita à decisão de implementação:

- **Interface:** aplicação web responsiva, utilizável em computador, tablet e celular; português como idioma inicial.
- **Plataforma de dados e backend:** Supabase em nuvem: PostgreSQL para os dados do produto, Supabase Auth para contas e sessões, Supabase Storage para arquivos privados e políticas de autorização no banco (RLS), além de funções de servidor para operações privilegiadas.
- **Arquivos:** armazenamento privado de evidências, documentos de identificação e PDFs, com acesso temporário autorizado e controle de permissão.
- **Autenticação:** conta individual por e-mail, recuperação de acesso, controle de sessão e autenticação recente antes de confirmar ciência ou finalizar relatório.
- **Notificações:** serviço de e-mail transacional; notificações internas no produto. SMS/WhatsApp ficam fora do primeiro escopo.
- **PDF:** geração no servidor a partir de uma versão congelada do relatório.
- **Ambientes:** desenvolvimento, homologação e produção separados; cópias de segurança automáticas e procedimento de restauração.

A infraestrutura principal escolhida para o MVP é Supabase. Região de hospedagem, plano e custos devem ser definidos antes da implantação.

## 7. Confirmação de ciência e assinatura via GOV

No Audita PRO, o participante realizará uma **confirmação de ciência**, registrada para a versão exata do relatório com usuário autenticado e data/hora. A interface não deve chamar essa ação de assinatura legal nem sugerir que substitui a assinatura via GOV.

No MVP, a proposta é um fluxo manual: o Auditor Líder finaliza e bloqueia o relatório, os signatários escolhidos confirmam ciência, o PDF é assinado fora do Audita PRO via GOV e a cópia assinada é anexada à biblioteca. O sistema registra quem anexou o arquivo e quando. A integração automática com GOV fica fora do escopo e o Audita PRO nunca solicita nem armazena credenciais GOV.

**Ponto a confirmar:** se esse fluxo manual (baixar o PDF, assinar via GOV e anexar a cópia assinada) atende ao processo pretendido, e se basta anexar o PDF assinado ou também é necessário guardar um comprovante separado. O tipo de documento de identificação e os formatos/tamanhos aceitos também precisam ser definidos antes do piloto. A validade e modalidade jurídica devem ser confirmadas com os clientes e assessoria jurídica.

## 8. Requisitos não funcionais e proteção de dados

- Isolamento de dados por organização e verificações de autorização no servidor.
- Tráfego e arquivos protegidos por criptografia em trânsito; criptografia em repouso conforme os serviços escolhidos.
- Senhas armazenadas somente por mecanismo seguro de autenticação; nunca registradas em logs.
- Trilha de auditoria protegida contra edição por usuários comuns.
- Limites configuráveis de tamanho e tipos de arquivo; verificação de uploads.
- Backup automático, monitoramento de falhas e procedimento de recuperação.
- Manter relatórios, evidências e documentos pessoais por cinco anos, com política de expiração e descarte seguro a ser definida para o piloto.
- Coleta mínima de dados pessoais, política de retenção e processo de exportação/exclusão conforme base legal e orientação especializada.
- Tratamento de dados alinhado à LGPD, com papéis de controlador/operador definidos em contrato e política de privacidade.
- Acessibilidade básica: navegação por teclado, rótulos de campos, mensagens claras e contraste adequado.

## 9. Fora do escopo do MVP

- Plataforma de cursos, videoaulas, provas e certificados.
- Geração de PGR, laudos, AET e outros documentos técnicos por templates.
- Aplicativo móvel nativo.
- Funcionamento offline e sincronização posterior.
- Integrações com ERP, RH, integração automática com GOV, WhatsApp ou sistemas de clientes.
- Painéis analíticos avançados e benchmarking entre empresas.
- Importação automática do texto integral de normas ou atualização jurídica automática.
- Aprovação completa de planos de ação pelo cliente; no MVP, será possível registrar ações, responsáveis, prazo e situação básica.
- Personalização visual por cliente.

## 10. Critérios de aceite do MVP

O MVP estará pronto para piloto quando:

1. Um administrador puder criar empresa, unidade, usuário, cargo, perfil e requisitos documentais.
2. Um usuário sujeito à aprovação não acessar funções restritas antes da aprovação dos documentos exigidos.
3. Um Auditor Líder puder criar auditoria, associar equipe e participantes e definir cronograma para vários dias.
4. Um auditor puder registrar resultados, observações, evidências, não conformidades e planos de ação.
5. O sistema mostrar execução do cronograma por dia e permitir transferir etapa pendente preservando origem e destino.
6. O relatório diário refletir registros e estado do cronograma daquele dia e permitir edição pelo Auditor Líder antes da finalização.
7. Finalizar gerar uma versão congelada e permitir ao Auditor Líder definir os signatários obrigatórios.
8. O sistema registrar confirmação de ciência por versão e distinguir essa confirmação da assinatura legal via GOV.
9. O sistema permitir anexar a cópia assinada via GOV, registrar quem fez o upload e quando, e arquivar o relatório junto a essa cópia.
10. O PDF arquivado incluir conteúdo aprovado, versão e indicação clara das confirmações registradas e da cópia GOV anexada.
11. Um usuário não autorizado não conseguir consultar ou baixar dados e arquivos de outra empresa.
12. Alterações, finalizações, transferências, aprovações e confirmações aparecerem na trilha de auditoria.

## 11. Premissas para estimativa

- Uso inicial no Brasil e interface em português.
- Um cliente poderá ter múltiplas unidades e múltiplos usuários.
- A aplicação será online-first; conexão confiável será necessária para registrar e assinar.
- Os requisitos e checklists do piloto serão fornecidos pelo responsável pelo Audita PRO; não haverá importação automática de normas.
- O Administrador terá busca global de empresas por nome ou CNPJ, acesso aos usuários vinculados e histórico de auditorias.
- Os participantes que assinam terão contas individuais.
- A assinatura ocorrerá após autenticação individual; credenciais não serão compartilhadas.
- O primeiro piloto usará um grupo pequeno de auditores e uma ou poucas empresas cliente.

## 12. Decisões recebidas

| Tema | Decisão |
|---|---|
| Assinatura | Confirmação de ciência no Audita PRO; assinatura legal via GOV. |
| Signatários | Apenas os selecionados pelo Auditor Líder. |
| Acesso do cliente | Somente leitura e confirmação de ciência quando selecionado; sem inclusão de evidências ou resposta a achados. |
| Documentos | Documento de identificação obrigatório para Auditor Líder, Auditor e Cliente; validação pelo Administrador. Outros comprovantes ficam para depois. |
| Checklist piloto | Requisitos fornecidos pelo responsável pelo Audita PRO. |
| Empresas | Administrador consulta por nome/CNPJ, usuários vinculados e histórico; sem gestão de usuários pelo cliente no MVP. |
| Nuvem | Supabase. |
| PDF | Layout padrão Audita PRO. |
| Conectividade | Internet exigida no piloto. |
| Retenção | Cinco anos para relatórios, evidências e documentos pessoais. |

### Confirmações finais ainda necessárias

1. Confirmar o fluxo manual de baixar o PDF, assiná-lo via GOV e anexar a cópia assinada ao Audita PRO; definir se é necessário guardar comprovante de assinatura separado.
2. Definir qual documento de identificação será aceito e os formatos/tamanho máximo do arquivo.
3. Definir de qual evento começa a contagem dos cinco anos e como tratar pedidos de exclusão ou retenção legal.

## 13. Recomendação para a primeira entrega

Após validar este documento, preparar o desenho técnico detalhado e estimativa da primeira fase, incluindo telas definitivas, modelo de dados, permissões, Supabase, fluxo de arquivo GOV e plano de piloto. As confirmações restantes sobre GOV, identificação e retenção podem alterar o fluxo e os requisitos de armazenamento.
