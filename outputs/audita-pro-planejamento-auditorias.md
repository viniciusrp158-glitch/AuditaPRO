# Audita PRO — Planejamento do módulo Auditorias

**Versão:** 1.1 — 06/10/2026  
**Situação:** proposta para validação.  
**Entrega:** documentação funcional e técnica. Nenhuma alteração no aplicativo ou no banco nesta etapa.

**Atualização 1.1:** incluídos relatórios diários automáticos, validação pelo condutor, disponibilização aos participantes de cada dia, atas de abertura/encerramento e relatório final consolidado. As regras abaixo complementam o planejamento anterior e esclarecem a diferença entre publicação do documento e confirmação de ciência.

## 1. Objetivo

Transformar a opção **Auditorias** do menu lateral em um módulo navegável para configurar, planejar, conduzir e acompanhar auditorias reais. O plano de auditoria e seu cronograma serão o centro da operação: cada participante deverá identificar o que está previsto para hoje, o que já aconteceu e o que mudou.

O Administrador poderá cadastrar tipos de auditoria e seus próprios modelos de checklist, incluindo modelos exclusivos de uma empresa. A condução será atribuída a um único responsável elegível: Administrador ou Auditor Líder. Auditor de apoio, Participante e Auditado não conduzem nem registram resultados.

## 2. Análise realizada e referências

Foram consultados o frontend atual, as migrations locais e, em modo somente leitura, as colunas e policies relevantes do Supabase conectado. Essa inspeção é dirigida ao planejamento do módulo; não constitui uma auditoria completa de segurança de toda a plataforma.

### Aproveitamento do PDF fornecido

O arquivo **PLANO DE AUDITORIA.pdf**, de três páginas, foi lido e revisado visualmente. Ele apresenta:

- Identificação do cliente, endereço, norma com edição, tipo de avaliação, equipe e comentários.
- Quatro dias de trabalho, incluindo intervalo entre datas: os dias de auditoria não precisam ser consecutivos.
- Local/modalidade, data, horário e atividades organizadas por área ou processo.
- Vários requisitos associados à mesma atividade e requisitos repetidos em processos distintos.
- Reunião de abertura, intervalos, alinhamento, preparação e reunião de encerramento.
- Escopo e notas sobre objetivos, critérios, idioma, entrevistas, amostragem e confidencialidade.

**Adaptação proposta:** incorporar esses campos ao plano digital, acrescentando acompanhamento de execução, evidências, histórico de alterações e ligação aos relatórios. Não importar dados do cliente do exemplo, identidade visual, horários ou conteúdo normativo como registros reais.

O exemplo identifica a avaliação como recertificação e contém notas sobre preparação para estágio 2. Por isso, as notas do Audita PRO serão editáveis e revisadas conforme a finalidade de cada auditoria, sem reproduzir automaticamente textos que possam não se aplicar.

### Estruturas existentes que serão reutilizadas

| Estrutura atual | Aproveitamento previsto |
|---|---|
| Organizações, unidades, vínculos e perfis | Empresa auditada, elegibilidade e equipe |
| `audits` | Identificação, empresa, responsável, escopo, datas e estado |
| `checklist_templates`, `checklist_revisions` | Modelos reutilizáveis e suas versões |
| `checklist_sections`, `checklist_requirements` | Seções, número do item, premissa e orientação |
| `audit_checklists` | Versão do modelo usada em cada auditoria |
| `audit_participants`, `audit_processes` | Equipe e processos auditados |
| `audit_days`, `schedule_items` | Dias e atividades do cronograma |
| `requirement_assessments`, `evidence_files` | Avaliação dos requisitos e anexos |
| `nonconformities`, `action_plans` | Achados e tratamento |
| Relatórios diários, versões e relatórios finais | Consolidação da execução |
| `audit_events`, histórico de participantes | Rastreabilidade |
| `in_app_notifications` | Avisos e ações pendentes |

O Dashboard já consulta auditorias, avaliações e cronogramas. A opção Auditorias atualmente direciona à seção correspondente do Dashboard; a proposta é criar uma página própria e manter os links existentes funcionando.

## 3. Conceitos que a interface deve distinguir

| Conceito | Exemplo | Finalidade |
|---|---|---|
| Tipo / referencial | ISO 9001 — Qualidade | Identificar o assunto ou base da auditoria |
| Natureza / finalidade | Interna, externa, diagnóstico, acompanhamento | Contextualizar o trabalho contratado |
| Modelo de checklist | Avaliação do processo de manutenção | Definir itens e premissas reutilizáveis |
| Auditoria | Auditoria da Empresa A, em outubro | Registrar uma execução específica |
| Plano de auditoria | Escopo, equipe, dias, horários e processos | Organizar o que será feito |
| Avaliação | Item verificado, resultado e evidência | Registrar o que foi constatado |

Na tela, **Personalizar auditoria** abrirá o cadastro de modelos. **Nova auditoria** criará uma execução baseada em um modelo, evitando confundir criação de conteúdo com início dos trabalhos.

## 4. Tela inicial de Auditorias

### Ações principais

1. **Nova auditoria** — Administrador ou Auditor Líder autorizado.
2. **Auditorias em andamento** — lista conforme os acessos do usuário.
3. **Personalizar auditoria** — somente Administrador; contém Tipos e Modelos.

Auditor e Participante/Auditado terão acesso de acompanhamento. A interface não oferecerá comandos que seu perfil não possa executar.

### Lista

Busca por código, título ou empresa; filtros por estado, tipo, responsável e período. Cada registro apresentará empresa, título, norma/tipo, responsável, datas, estado, progresso e ação **Abrir auditoria**. Outras situações — rascunhos, planejadas, finalizadas e canceladas — permanecerão acessíveis por filtro.

A lista será paginada. A opção padrão será Em andamento; na ausência de registros, explicar a situação e oferecer filtros pertinentes. Toda navegação manterá menu lateral, logo oficial, identificação e sino existentes.

## 5. Cadastro de tipos e modelos — Administrador

### 5.1 Tipos de auditoria

Catálogo inicial:

- ISO 9001 — Qualidade.
- ISO 14001 — Meio Ambiente.
- ISO 45001 — Segurança e Saúde no Trabalho.

Campos: nome, código/referência, descrição, edição quando aplicável, categoria normativa ou personalizada e situação ativa/inativa. A edição deve ser cadastrada explicitamente; não assumir automaticamente uma edição normativa.

O Administrador poderá cadastrar outros tipos, alterar descrições e inativar tipos sem excluir o histórico de auditorias. Nomes de normas não significam checklists prontos: as premissas serão cadastradas pelo usuário, conforme já acordado.

**Observação de nomenclatura:** para o futuro exemplo de gestão de riscos, a referência confirmada é **ISO 31000**, em vez de ISO 31001. A ISO a apresenta como diretrizes, não como norma certificável. Isso não impede criar uma avaliação interna baseada nela. Fonte: [ISO — Gestão de riscos](https://www.iso.org/standards/popular/iso-31000-family).

### 5.2 Modelos de checklist

Campos do modelo: nome, tipo, objetivo, descrição, versão, situação e abrangência:

- **Geral:** pode ser escolhido por responsáveis autorizados em diferentes empresas.
- **Exclusivo da empresa:** somente pode ser utilizado na organização definida.

Permitir criar do zero, duplicar um modelo autorizado, organizar seções, adicionar/reordenar itens, salvar rascunho, revisar, publicar e inativar. Um modelo exclusivo não poderá ser usado ou consultado por outra empresa.

Cada item conterá:

| Campo | Regra |
|---|---|
| Número/código | Obrigatório; texto para permitir códigos como 7.2, 7.2-a ou INT-001 |
| Premissa / pergunta | Obrigatória; o que deverá ser verificado |
| Seção | Organização lógica do checklist |
| Orientação | Opcional; instrução de avaliação |
| Ordem | Editável pelo Administrador |

Resultado, evidência e observação pertencem à execução; não serão preenchidos como resposta padrão do modelo. Para mais de uma pergunta sobre a mesma cláusula, usar códigos próprios e referência de cláusula, evitando confundir perguntas distintas.

### 5.3 Versões e isolamento

Rascunhos são editáveis. Publicar cria uma versão estável. Uma auditoria mantém a versão escolhida mesmo que o Administrador publique outra versão depois. Mudanças não sobrescrevem premissas já avaliadas.

Para adaptar um modelo a uma empresa, o Administrador cria uma versão ou cópia específica antes de iniciar a execução. Alteração de escopo após o início exige revisão explícita, justificativa e preservação das avaliações anteriores. Itens retirados do escopo não serão disfarçados como Não Aplicável para melhorar indicadores.

## 6. Assistente de nova auditoria

### Etapa 1 — Empresa e responsável

Selecionar empresa ativa e unidade quando houver. Escolher responsável dentre Administradores ou Auditores Líderes elegíveis. Confirmar vínculo com a empresa, situação ativa e competência aprovada ou dispensa formal já suportada pelo sistema.

O Administrador global pode criar e atribuir a auditoria. Quando ele próprio for o responsável, deve existir um vínculo rastreável com a organização compatível com a estrutura atual. Auditor Líder poderá criar para empresas em que possua autorização e assumir a condução; atribuir a outra pessoa será gestão administrativa.

Não promover um Auditor de apoio apenas por adicioná-lo à equipe. Validar o responsável no servidor, inclusive contra requisições manipuladas.

### Etapa 2 — Tipo, modelo e escopo

Informar título, tipo/referencial, finalidade, objetivo, escopo, processos e versão publicada do checklist. Registrar separadamente a parte da auditoria (primeira, segunda ou terceira parte) e sua finalidade (interna, diagnóstico, certificação, manutenção/acompanhamento, recertificação ou outra cadastrada). Esses campos também comporão os documentos, sem inferir um a partir do outro. O sistema gerará código único. A criação ficará em rascunho até o planejamento estar completo.

Primeiro fluxo prioriza um tipo/modelo por auditoria. A estrutura atual, que aceita mais de um checklist e referência, será preservada para auditorias integradas futuras.

### Etapa 3 — Equipe e participantes

O responsável seleciona usuários já cadastrados e vinculados à empresa:

- Auditor: apoio e observação; consta na equipe e nos relatórios.
- Participante/Auditado: acompanhamento; sem registros ou edição.
- Responsável: pessoa designada na etapa 1.

Pessoas ainda não elegíveis podem ser indicadas como pendências de preparação, mas não recebem acesso operacional antes de cumprir o fluxo de aprovação. O responsável não cria permissões administrativas ao adicionar participantes. Convites/cadastros novos continuam no módulo Usuários.

Definir os signatários de confirmação de ciência separadamente da equipe. Participar não torna automaticamente uma pessoa signatária.

### Etapa 4 — Plano e cronograma

Preencher os campos descritos na seção 7. Exibir checklist de preparação: responsável, equipe revisada, escopo, modelo publicado, atividades, cobertura dos itens e datas válidas.

### Etapa 5 — Revisar e disponibilizar

**Salvar rascunho** permite continuar depois. **Publicar plano / Agendar auditoria** disponibiliza a versão planejada. **Iniciar auditoria** muda a execução para Em andamento e registra a data real de início. Criar cadastro não inicia automaticamente a execução.

A equipe precisa ser revisada explicitamente; não será obrigatório inventar um Auditor de apoio quando o trabalho tiver apenas o responsável. Pendências reais impedem a publicação ou início conforme sua gravidade, com explicação acionável.

## 7. Plano de auditoria e cronograma

### Cabeçalho

Empresa/unidade, código/título, tipo/norma e edição, natureza, objetivo, escopo, critérios/referências, responsável, equipe, participantes, datas previstas, modalidade presencial/remota/híbrida, local/endereço, fuso horário, versão e data de publicação.

Campos complementares opcionais: idioma, orientações aos auditados, logística, pessoas/áreas a entrevistar e notas. Usar identidade Audita PRO. Download/impressão do plano poderá integrar a entrega do plano; a visualização principal será navegável dentro do sistema.

### Grade por dia

| Campo da atividade | Comportamento |
|---|---|
| Dia e data | Aceitar dias não consecutivos; exibir “Dia 3 — data” |
| Início e término previstos | Opcionais em rascunho; atividades sem horário são sinalizadas |
| Atividade e categoria | Auditoria de processo, reunião, intervalo ou outra atividade |
| Processo/área | Necessário nas atividades de verificação |
| Requisitos | Um ou vários itens do checklist; nenhum para reunião/intervalo |
| Responsável e envolvidos | Responsável pela condução e pessoas de apoio/entrevistadas |
| Local/modalidade | Herdado do plano, com ajuste por atividade |
| Situação | Planejada, Em andamento, Concluída ou Não realizada |
| Observações | Opcionais |
| Execução real | Início, conclusão, autor e eventuais alterações |

O responsável operacional das verificações é o condutor designado. Registrar pessoas de apoio não lhes concede edição. Horários conflitantes para o mesmo condutor devem produzir aviso para correção ou justificativa, sem supor equipes paralelas com poder de registro nesta primeira versão.

### Navegação do plano

Abas/filtros **Hoje**, **Todos os dias**, **Pendentes**, **Concluídas** e **Alterações**. Selecionar um dia abre sua agenda; clicar em uma atividade abre os itens relacionados. Se hoje não for dia auditado, mostrar esse fato e a próxima data prevista.

O número do dia acompanha a sequência das datas auditadas, sem contar intervalos como dias de trabalho. Se uma revisão inserir datas intermediárias, preservar a numeração e os títulos usados nas versões/relatórios anteriores; os identificadores internos permanecem estáveis.

### Quem pode consultar

Para atender ao pedido de disponibilizar o plano à empresa, a proposta é permitir que **todos os usuários ativos, aprovados e vinculados à organização** consultem o plano publicado e o andamento de suas atividades.

Esse acesso empresarial terá uma projeção específica: agenda, processos, referências dos itens, situação e alterações publicadas. Ele não concederá automaticamente acesso a evidências, resultados detalhados, dados pessoais da equipe, notas internas ou relatórios. Esses conteúdos continuam exigindo participação/autorização específica na auditoria. Rascunhos do plano permanecem restritos à preparação.

Essa é uma ampliação intencional em relação ao acesso atual por participação e deve ser validada junto com este planejamento. A empresa nunca recebe dados de outra empresa. Caso se prefira limitar também o plano aos participantes designados, essa regra pode ser ajustada antes da implementação.

## 8. Edição, antecipação e transferência de atividades

### Autoridade de edição

Após a designação, somente o **responsável que conduz aquela auditoria** edita e publica o plano: Auditor Líder ou Administrador atuando nessa função. Ser Administrador ou ter perfil Auditor Líder, isoladamente, não autoriza editar o plano de outro condutor.

O Administrador pode substituir o responsável, com motivo e histórico. O novo responsável passa a editar; o anterior perde essa atribuição. Inatividade ou perda de elegibilidade deve bloquear novas alterações até regularizar a condução. O histórico permanece consultável conforme autorização.

### Revisões do plano

Manter a primeira versão publicada como referência original. Cada revisão publicada registra autor, data, motivo e diferenças. Os usuários continuam vendo a última versão publicada enquanto o responsável prepara alterações. Cancelar uma edição não altera o plano vigente.

Não bastará atualizar a data na mesma linha. Para cada transferência, registrar atividade estável, dia/horário de origem, destino, motivo, autor e momento. Transferências repetidas preservam todos os movimentos.

### Não foi possível concluir

No fechamento do dia, listar atividades pendentes. O responsável escolhe: continuar em outra data, reagendar ou retirar justificadamente do escopo mediante revisão. O sistema sugere o próximo **dia de auditoria**, que pode não ser o dia seguinte do calendário, e pede confirmação do destino.

Uma transferência não conclui a atividade. O dia original mostra a pendência transferida; o destino mostra de onde veio. Se não houver próxima data, criar uma nova data planejada antes de concluir o reagendamento. Não transferir silenciosamente.

### Conclusão antecipada

Permitir antecipar uma atividade mediante registro do dia real e justificativa da mudança. Se houver execução parcial, manter os itens já verificados e mover somente o restante, sem duplicar avaliações ou perder o vínculo com a atividade de origem.

Terminar antes não apaga os dias originais nem transforma o previsto em realizado. Reuniões/dias dispensados são apresentados como cancelados ou retirados na revisão, com motivo; conclusão antecipada fica registrada no histórico.

## 9. Checklist de execução e evidências

Ao abrir uma atividade, apresentar **número do item, premissa, resultado, evidência e observações**, com opção de salvar e continuar.

| Informação | Regra proposta |
|---|---|
| Número e premissa | Herdados da versão do modelo; somente leitura durante a avaliação |
| Resultado | Não avaliado, Conforme, Não conforme, Parcialmente conforme ou Não aplicável |
| Evidência textual | Texto livre separado de observações |
| Anexos | Um ou vários arquivos; texto e arquivo podem ser usados juntos ou separadamente |
| Observações | Opcionais |
| Contexto | Processo, atividade, dia real, autor e horários |

**Sim/Conforme** e **Não/Não conforme** serão as opções mais diretas. Parcialmente conforme e Não aplicável preservam os estados já previstos no Dashboard; Não avaliado é o estado inicial. O valor legado de oportunidade de melhoria será preservado e tratado separadamente, sem convertê-lo automaticamente em conformidade.

Proposta para validação: exigir texto de evidência ou anexo para concluir uma avaliação aplicável; permitir rascunho sem evidência. Para Não aplicável, exigir justificativa. Não tornar o campo Observações obrigatório.

Proposta inicial para anexos: **PDF, JPEG e PNG, até 10 MB por arquivo**, aproveitando o padrão de Meu Perfil. Validar tamanho e conteúdo no servidor; arquivo fica privado. Esse limite é uma proposta para evidências de auditoria, não uma afirmação sobre a configuração atual do armazenamento.

Avaliar o mesmo requisito em Produção e Manutenção deverá gerar registros distintos. Retornar ao mesmo item/processo para corrigir uma avaliação deve preservar o histórico anterior. Um requisito previsto em mais de uma atividade não pode ser contado como várias conclusões acidentais.

Ao registrar Não conforme, oferecer criação/vinculação de NC com os dados já preenchidos. Não gerar duplicatas em cada salvamento. Ao fechar o dia, exigir NC vinculada ou justificativa para achados não conformes sem NC. Parcialmente conforme deverá permitir classificação fundamentada pelo responsável. As regras existentes de tratamento de NC continuam no módulo correspondente.

## 10. Conclusão de atividade e indicadores

**Atividade concluída não significa processo conforme.** Pode haver uma atividade totalmente auditada com várias NCs.

O responsável pode concluir a atividade quando todas as verificações previstas nela tiverem resultado final ou justificativa de não aplicabilidade, com evidências conforme as regras acordadas. Itens não avaliados impedem conclusão e devem ser mantidos pendentes ou reagendados. Reuniões e outras atividades sem checklist têm conclusão manual rastreável.

### Indicadores distintos

1. **Execução do plano:** atividades de trabalho concluídas / atividades de trabalho previstas na versão vigente. Intervalos não entram; reuniões podem entrar como trabalho, identificadas por categoria.
2. **Cobertura da avaliação:** unidades de avaliação concluídas e aplicáveis / unidades de avaliação aplicáveis. A unidade considera requisito e processo/contexto; repetições de agenda não duplicam a unidade.
3. **Conformidade:** distribuição dos resultados efetivamente registrados.
4. **Cumprimento diário:** previsto no início do dia, incluído depois, realizado, pendente, transferido e antecipado.

Não avaliado permanece no denominador até justificativa de Não aplicável. Não aplicável sai do numerador e denominador. Denominador zero mostra **Sem itens aplicáveis**, sem inventar percentual. Antes de haver planejamento, mostrar **Planejamento incompleto**.

Guardar a referência original e a versão de abertura de cada dia, além da versão vigente. Reagendar tudo para amanhã não deve apagar o descumprimento do plano de hoje. Mostrar alterações de escopo separadamente, pois elas mudam o denominador.

## 11. Estados e encerramento

Preservar os estados existentes de auditoria e seus significados: Rascunho (`draft`), Planejada (`planned`), Em andamento (`in_progress`), Aguardando encerramento (`awaiting_signoff`), Finalizada (`completed`) e Cancelada (`cancelled`).

O plano terá seu próprio ciclo de rascunho, publicação e revisão, distinto do estado da auditoria. Transferida ou Antecipada são eventos/indicadores da atividade; não substituirão seu estado de execução.

Encerrar o dia exige classificar as pendências e registrar término real; esse evento gera automaticamente o relatório diário para validação do condutor. Encerrar integralmente a execução exige verificar atividades, requisitos e pendências de documentação e é o gatilho exclusivo para gerar o relatório final. Documentos ainda em validação ou confirmações exigidas podem manter a auditoria em Aguardando encerramento. A publicação de um relatório aprovado não aguarda as confirmações de ciência: os participantes autorizados já podem consultá-lo. NCs em tratamento não precisam ser artificialmente encerradas para terminar a auditoria; devem constar como pendências nos relatórios e planos de ação.

Auditorias finalizadas ficam em consulta. Correções posteriores devem ser rastreáveis e compatíveis com o versionamento já adotado; não desbloquear relatórios congelados nem permitir exclusão de registros associados.

## 12. Matriz de permissões proposta

| Ação | Administrador | Auditor Líder | Auditor de apoio | Participante/Auditado |
|---|---|---|---|---|
| Cadastrar tipos/modelos | Sim | Não | Não | Não |
| Criar auditoria | Sim | Se autorizado na empresa | Não | Não |
| Ser responsável | Sim, designado | Sim, designado | Não | Não |
| Designar/substituir responsável | Sim, com histórico | Não | Não | Não |
| Editar/publicar plano | Se for o condutor | Se for o condutor | Não | Não |
| Registrar avaliação/evidência | Se for o condutor | Se for o condutor | Não | Não |
| Gerenciar equipe da execução | Sim | Se for o condutor | Não | Não |
| Consultar plano publicado | Global conforme acesso | Empresa autorizada | Empresa autorizada | Empresa autorizada |
| Ver resultados/evidências | Conforme acesso administrativo | Auditoria autorizada | Auditoria autorizada | Auditoria autorizada |
| Confirmar ciência de relatório | Se signatário | Se signatário | Se signatário | Se signatário |

Aplicar no backend, incluindo downloads. Permissões adicionais não devem permitir que um perfil Auditor/Participante contorne a regra de condução. Confirmar ciência continua distinto de assinatura GOV.

## 13. Integrações e prevenção de efeitos em outras abas

| Módulo | Integração e cuidado |
|---|---|
| Dashboard | Indicadores e links abrem a mesma auditoria; atualizar cálculo por processo sem manter métricas contraditórias |
| Usuários / Meu Perfil | Reutilizar vínculos e competência; bloqueio/inativação não apaga participação histórica |
| Notificações | Avisar responsável designado, preparação pendente, equipe adicionada, plano publicado/revisado e reatribuição |
| NCs / Planos de ação | Vincular achados à avaliação e processo; evitar duplicidade e divergência de prazos |
| Relatório diário | Incluir comparativo do plano, versão usada, origem das transferências e execução do dia |
| Biblioteca | Preservar relatórios finalizados e seus vínculos; revisão do plano não reescreve PDF anterior |
| Evidências | Armazenamento privado, rastreabilidade e isolamento por auditoria |

As notificações de preparação devem refletir pendências reais. Ler um aviso não conclui o planejamento. Uma revisão publicada gera aviso consolidado, sem notificar cada tecla ou item salvo. Os destinatários serão determinados pelo servidor conforme acesso ao plano, sem divulgar dados internos na mensagem.

Relatórios usarão dados e versões do momento de sua geração/finalização. Alterações posteriores originam novas versões quando necessárias; nunca sobrescrevem documento já confirmado.

### 13.1 Organização dos documentos e acesso simples

O relatório será um **documento legível**, com visualização na plataforma e ação **Baixar PDF**. O sistema prepara o conteúdo a partir dos registros existentes; o condutor não precisa montar tabelas ou copiar informações manualmente. Apresentar um resumo claro, seguido dos itens necessários, evitando formulários de emissão complexos.

Todos os documentos terão vínculo obrigatório e verificável:

**Empresa/CNPJ → Auditoria específica → Plano e versão → Dia ou evento correspondente → Documento e versão.**

O identificador interno da empresa garante o vínculo; razão social e CNPJ aparecem no cabeçalho e são preservados na versão emitida. A relação não será feita apenas pelo nome ou por um CNPJ digitado no relatório. O servidor impedirá associar dia, plano, ata ou relatório a uma auditoria de outra empresa.

Na seção **Relatórios e atas** da auditoria, mostrar:

- Ata da reunião de abertura.
- Relatórios diários, agrupados por número do dia e data.
- Ata da reunião de encerramento.
- Relatório final, após o encerramento integral.

Em cada dia do cronograma haverá um atalho **Relatório deste dia**. O cadastro da empresa e a Biblioteca apresentarão os mesmos documentos vinculados, sem criar cópias independentes. Cada cartão exibirá título, data, estado, versão, responsável, Visualizar e Baixar PDF quando o arquivo estiver pronto. Não oferecer link de download inexistente.

### 13.2 Geração automática do relatório diário

Fluxo simples:

**Encerrar dia → Sistema gera documento → Condutor confere e aprova → Sistema publica e avisa os participantes daquele dia.**

1. Ao encerrar o dia, o responsável confirma os participantes efetivos e o tratamento das atividades pendentes. A lista parte da equipe cadastrada, mas pode registrar presenças diferentes em cada data.
2. O servidor registra o encerramento e a solicitação de geração, com referência à versão do plano e aos dados do dia.
3. O relatório é produzido automaticamente e aparece como **Aguardando validação**, disponível ao condutor para revisão. Não exigir botão adicional de criação ou preenchimento manual de campos que o sistema já conhece.
4. O Auditor Líder, ou Administrador designado como condutor, abre a prévia e usa **Validar e disponibilizar**. Ele pode ajustar textos ou acrescentar observações antes de aprovar, se necessário, preservando a origem dos registros e o histórico das edições.
5. A aprovação congela a versão e libera o documento automaticamente para todos os participantes autorizados daquele dia. O sino avisa a disponibilidade; o arquivo fica acessível no dia, na auditoria e na empresa.

**Disponível automaticamente significa após encerramento do dia e aprovação do condutor.** Entre esses dois eventos, o responsável vê a pendência de validação; os demais veem que o documento aguarda aprovação, sem acesso ao rascunho.

Conteúdo gerado:

- Empresa, CNPJ, unidade, código/título da auditoria, norma/edição, finalidade e parte.
- Data, número do dia, início/término reais, condutor e participantes efetivos daquele dia.
- Objetivo e escopo pertinentes, identificação do plano e versões utilizadas.
- Processos e requisitos previstos e efetivamente verificados.
- Itens conformes, não conformes, parcialmente conformes, não aplicáveis e não avaliados, com referências às avaliações e evidências autorizadas.
- NCs identificadas e situação registrada no momento da emissão; planos de ação e prazos quando existentes.
- Atividades concluídas, pendentes, transferidas e antecipadas, com origem/destino e motivos.
- Referência à ata de reunião realizada no dia, quando houver, e observações complementares.
- Identificação de quem aprovou, data e hora, versão e identificação do documento.

O documento deve explicar ausências de dados, sem inventar avaliações, presenças ou evidências. Arquivos de evidência podem ser referenciados; não é necessário incorporar todos os anexos ao PDF. As observações opcionais continuam opcionais.

### 13.3 Participação diária, publicação e ciência

Manter participação na auditoria e presença em cada dia como informações distintas. O condutor confirma uma lista por dia; apoiadores e auditados devem aparecer conforme sua participação real, não por presunção de presença durante todos os dias.

O relatório diário aprovado fica disponível ao condutor, à administração autorizada e aos participantes registrados naquele dia, dentro da mesma empresa/auditoria. A mera possibilidade de consultar o plano da empresa não libera todos os relatórios. Autorizações adicionais permanecem explícitas e rastreáveis.

Preservar os destinatários históricos do documento, mesmo que a composição da equipe mude nos dias seguintes. A consulta ainda exige conta ativa e acesso válido: revogação legítima de acesso não apaga a presença histórica nem o nome no documento.

**Aprovação do relatório, acesso ao relatório e confirmação de ciência são eventos diferentes.** Se houver signatários designados, somente eles recebem a tarefa de confirmar ciência. A publicação aprovada permite leitura/download sem esperar que todos confirmem. A situação **Disponível — ciência pendente** evita confundir ausência de publicação com falta de confirmação.

Continuar distinguindo confirmação de ciência na plataforma de assinatura externa GOV. Não apresentar confirmação interna como assinatura digital ou certificação.

### 13.4 Atas de abertura e encerramento

As atas serão documentos próprios, relacionados às reuniões correspondentes do plano. A ata de abertura é gerada quando a reunião de abertura for registrada como realizada; a ata de encerramento, quando a reunião final for realizada. Não criar uma ata que afirme uma reunião que não aconteceu.

Preencher automaticamente empresa/CNPJ, auditoria, norma, data, horários, condutor e participantes confirmados. O responsável poderá complementar assuntos tratados, orientações, decisões e encaminhamentos; esses conteúdos não podem ser deduzidos de uma agenda vazia.

Usar a mesma experiência simples: prévia, complemento opcional ou indicação de conteúdo faltante, validação e disponibilização. A ata aprovada fica visível aos participantes autorizados da reunião, ao condutor e à administração. Quando a reunião não se aplicar ou não ocorrer, mostrar essa situação e sua justificativa.

A ata de abertura não substitui o relatório do primeiro dia. A ata de encerramento não substitui o relatório do último dia nem o relatório final.

### 13.5 Relatório final de auditoria

**Gatilho exclusivo:** o condutor confirma o encerramento integral dos trabalhos da auditoria. Encerrar um dia intermediário ou alcançar a data prevista de término não gera o relatório final.

O sistema consolida os dados da auditoria em um documento final para validação e disponibilização pelo condutor. A conclusão humana e eventuais resultados externos podem ser complementados antes da aprovação. A emissão utiliza os registros e relatórios diários aprovados; dados inconsistentes ou documentos obrigatórios ainda não aprovados aparecem como pendências, sem produzir uma conclusão silenciosamente incompleta.

Conteúdo:

- Empresa, CNPJ, unidade, identificação da auditoria e plano.
- Norma(s), edição, objetivo, escopo, finalidade, primeira/segunda/terceira parte, modalidade e datas previstas/reais.
- Responsável pela condução e equipe/participantes discriminados por dia, incluindo substituições.
- Comparativo consolidado do plano original, revisões, realizado, antecipações e transferências.
- Relação e resumo dos itens conformes, não conformes e parcialmente conformes; não aplicáveis e pendentes, com justificativas.
- NCs, situação do tratamento, planos de ação e prazos ainda em aberto.
- Referências aos relatórios diários e às atas, preservando a procedência das informações.
- Conclusão do responsável e situação de certificação, quando aplicável.
- Validação, autoria, versão e data da emissão.

O resumo final não soma cegamente os mesmos requisitos repetidos em dias diferentes: usa a unidade requisito/processo definida neste planejamento e o último resultado válido no fechamento. A evolução e os achados de cada dia continuam acessíveis nos relatórios diários.

**Situação de certificação:** prever Não se aplica, Aguardando decisão, Certificação concedida/mantida e Certificação não concedida/não mantida, conforme a finalidade. Registrar a origem, data e documento comprobatório da decisão quando informado. A recomendação/conclusão da equipe será um campo separado da decisão de certificação. O sistema não deduz que a empresa foi certificada apenas porque os itens ficaram conformes; enquanto não houver resultado registrado, o documento informa que a decisão está pendente.

O relatório final aprovado ficará disponível à administração, ao condutor e aos participantes autorizados da auditoria, considerando a participação ao longo dos dias. Ele não substitui nem apaga os documentos diários. Se o resultado externo de certificação chegar depois, anexar o registro ou emitir nova versão controlada, preservando o final anterior.

### 13.6 Exemplo de cinco dias — ISO 14001

Dentro da mesma empresa/CNPJ e da mesma auditoria:

| Momento | Documentos esperados |
|---|---|
| Abertura realizada no dia 1 | Ata de abertura validada |
| Encerramento do dia 1 | Relatório diário 1, gerado e enviado à validação |
| Encerramento dos dias 2, 3 e 4 | Respectivos relatórios diários, cada qual com seus participantes e execução |
| Encerramento do dia 5 | Relatório diário 5; ata de encerramento se a reunião ocorreu |
| Encerramento integral pelo condutor | Relatório final consolidado, gerado para validação |

Ao final, estarão organizados cinco relatórios diários, as duas atas das reuniões efetivamente realizadas e um relatório final aprovado. Cada documento permanece ligado ao contexto correto e à versão que foi disponibilizada.

### 13.7 Confiabilidade da emissão

Usar geração idempotente: repetir o comando ou tentar novamente após falha não cria dois relatórios diários para o mesmo dia nem dois relatórios finais independentes. Reutilizar o documento lógico e suas versões existentes.

Registrar estados de geração separados dos estados de aprovação: Gerando, Aguardando validação, Disponível e Falha na geração. Se houver falha, preservar o encerramento registrado e a solicitação de emissão, mostrar erro recuperável e permitir nova tentativa controlada. Não anunciar documento pronto nem notificar participantes antes da publicação efetiva.

Uma alteração nos dados de origem durante a revisão deve invalidar a prévia desatualizada ou exigir reconciliação explícita. Após aprovação, nenhuma atualização de cronograma, equipe ou checklist reescreve o documento congelado. Retificações criam nova versão com motivo e nova validação; se houver ciência vinculada, ela pertence à versão confirmada.

## 14. Lacunas técnicas identificadas e evolução proposta

| Lacuna observada | Proposta de evolução, ainda não executada |
|---|---|
| Referenciais em `audits.standards` são texto; não há catálogo dedicado nas estruturas inspecionadas | Catálogo editável de tipos, preservando compatibilidade e referências históricas |
| Modelos publicados são legíveis por usuários autenticados nas policies atuais | Acrescentar escopo geral/empresa e restringir também revisões, seções e requisitos dos modelos exclusivos |
| Cronograma admite apenas um `requirement_id` por atividade | Relação para múltiplos requisitos/contextos, preservando e migrando vínculos atuais |
| `schedule_items` guarda origem/motivo, mas não toda a cadeia de movimentos | Histórico de revisões e movimentos; valores anteriores/novos com autor e motivo |
| Não há versão formal do plano nas tabelas examinadas | Versões publicadas do plano e referência por dia/relatório, sem duplicar avaliações |
| Avaliação possui unicidade por auditoria/dia/requisito, sem processo | Rever identidade da unidade de avaliação para suportar o mesmo item em processos distintos e reavaliações |
| `requirement_assessments.notes` mistura possibilidades de texto | Campo dedicado à evidência textual; observações separadas e preservadas |
| Horários reais por atividade não constam no schema consultado | Acrescentar início/conclusão reais e autoria |
| Administração e líderes têm permissões mais amplas nas funções/policies atuais | Restrição específica ao condutor nas mutações do plano/execução; manter consulta administrativa |
| Acesso atual se baseia em participação na auditoria | Consulta restrita do plano publicado por vínculo empresarial, sem ampliar acesso ao resto dos dados |
| Notificações atuais tratam principalmente submissões de perfil | Estender tipos de evento/ações, mantendo o fluxo de Meu Perfil e a deduplicação |
| Participantes atuais representam vínculo com a auditoria, sem presença diária explícita nas estruturas examinadas | Registrar presença por dia/reunião e destinatários históricos dos documentos; não inferir presença de toda a equipe |
| Relatórios diários/finais já possuem estruturas próprias | Reutilizá-las para geração automática, validação e versões; avaliar extensão para origem no plano, processamento e publicação independente da ciência |
| Atas não foram identificadas como estrutura dedicada na inspeção anterior | Verificar novamente na implementação e representar abertura/encerramento ligados às reuniões, com versões e autorização |
| Decisão de certificação e classificação por parte precisam de dados estruturados | Registrar finalidade, parte e decisão com origem, sem inferir certificação por conformidade |

Os nomes finais das novas estruturas serão definidos na implementação, após nova inspeção do schema. Criar migrations pequenas por responsabilidade, com backfill explícito e compatibilidade durante a transição. Não criar outra tabela de auditorias, usuários ou empresas.

Revisar constraints, triggers, funções e RLS em conjunto. Ajustar somente controles necessários ao módulo; evitar alterar um helper global de permissões sem testar seus consumidores. Índices deverão acompanhar listas por empresa, auditoria, dia e estado. Paginar requisitos, histórico e anexos, evitando uma consulta por card.

## 15. Experiência de uso

Usar identidade visual atual, navegação consistente e estados de carregamento, erro com nova tentativa, sem dados e sem permissão. Cada falha de salvamento deve preservar o preenchimento recuperável e indicar o que não foi salvo.

Na auditoria aberta, sugerir seções: **Visão geral**, **Plano de auditoria**, **Checklist e evidências**, **Equipe**, **Não conformidades**, **Relatórios e atas** e **Histórico**. A abertura inicial privilegia o dia atual e suas pendências. Ao encerrar o dia, apresentar ao condutor o relatório gerado para validação; após aprovação, os participantes encontram Visualizar/Baixar PDF na própria auditoria e no atalho do dia.

Em telas menores, apresentar atividades como cartões por dia, mantendo filtros e ações essenciais. Evitar depender exclusivamente de arrastar e soltar: botões para ordenar e reagendar também devem funcionar por teclado.

Usar revisão de registro para detectar duas sessões tentando sobrescrever o mesmo planejamento. Informar conflito e permitir recarregar/comparar, sem substituir silenciosamente a alteração mais recente.

## 16. Etapas de implementação propostas

1. **Fundação e compatibilidade:** confirmar dados existentes, preparar migrations, isolamento de modelos e regra do condutor.
2. **Tipos e modelos:** interface administrativa, versões e modelos exclusivos por empresa.
3. **Criação e equipe:** página própria de Auditorias, assistente, responsável, participantes e pendências.
4. **Plano navegável:** agenda por dia, publicação, visualização empresarial autorizada e revisões.
5. **Execução:** checklist, evidências, conclusão, antecipação e transferência com histórico.
6. **Documentos e integrações:** geração automática diária/final, atas, validação, publicação, PDF, presença diária e destinatários; integração com indicadores, notificações, NCs e impressão/download do plano.
7. **Validação:** cenários completos com Administrador, Auditor Líder, Auditor e Participante; regressão das abas existentes.

Cada etapa deve produzir uma entrega funcional com link para validação. Não declarar a integração pronta enquanto apenas a tabela ou o botão existir. Implantar de forma incremental, mantendo os registros e rotas existentes utilizáveis.

## 17. Critérios de aceite

| ID | Cenário | Resultado esperado |
|---|---|---|
| AUD-01 | Abrir Auditorias | Página navegável com lista real e ações conforme perfil |
| AUD-02 | Administrador cadastrar tipo e modelo | Salvar, reabrir, editar rascunho e publicar sem intervenção técnica |
| AUD-03 | Modelo exclusivo da Empresa A | Empresa B não consulta nem usa o modelo, inclusive via API |
| AUD-04 | Tentar atribuir Auditor/Participante como condutor | Recusa no servidor e orientação na tela |
| AUD-05 | Administrador designado conduzir | Mesmo fluxo funcional de condução do Auditor Líder |
| AUD-06 | Outro Administrador/Líder tentar alterar plano | Recusa até designação legítima como responsável |
| AUD-07 | Publicar nova versão de modelo | Auditoria já criada preserva sua versão |
| AUD-08 | Criar agenda em dias não consecutivos | Dia 3 representa a terceira data auditada |
| AUD-09 | Atividade com várias cláusulas; mesma cláusula em dois processos | Avaliações independentes, sem colisão nem dupla contagem acidental |
| AUD-10 | Registrar somente texto ou somente anexo | Evidência aceita; observação pode ficar vazia |
| AUD-11 | Arquivo inválido ou fora do limite | Recusa no servidor; nenhum acesso público ao arquivo |
| AUD-12 | Concluir atividade com itens não avaliados | Exibir pendências e impedir falsa conclusão |
| AUD-13 | Concluir avaliação com NC | Atividade pode terminar sem marcar todos os itens como conformes |
| AUD-14 | Transferir a mesma atividade mais de uma vez | Preservar todos os movimentos e a execução final |
| AUD-15 | Antecipar ou executar parcialmente | Preservar previsão original e mover apenas o trabalho restante |
| AUD-16 | Participante consultar Hoje | Ver agenda publicada e andamento da sua empresa; sem edição |
| AUD-17 | Usuário da empresa sem participação explícita | Consultar apenas a projeção publicada do plano, conforme regra proposta |
| AUD-18 | Gerar relatório diário e revisar plano depois | Relatório congelado preserva a versão e os dados originais |
| AUD-19 | Contar progresso com Não aplicável e repetição por processo | Percentuais coerentes; zero aplicáveis tratado explicitamente |
| AUD-20 | Reatribuir/inativar condutor | Revogar escrita anterior e encaminhar pendência ao novo responsável |
| AUD-21 | Salvar duas revisões simultâneas | Detectar conflito sem perda silenciosa |
| AUD-22 | Navegar Dashboard, Usuários, Meu Perfil e notificações | Funcionalidades anteriores continuam funcionando |
| AUD-23 | Encerrar um dia auditado | Gerar um relatório diário automaticamente e encaminhar ao condutor para validação |
| AUD-24 | Aprovar relatório diário | Disponibilizar documento e PDF aos participantes autorizados daquele dia e emitir aviso |
| AUD-25 | Tentar acessar documento de outra empresa/dia sem autorização | Recusar no servidor, inclusive por URL de download |
| AUD-26 | Publicar relatório com signatários ainda pendentes | Permitir leitura aos destinatários; manter tarefas de ciência separadas |
| AUD-27 | Registrar abertura/encerramento | Gerar ata da reunião real com participantes, decisões registradas e validação |
| AUD-28 | Encerrar somente um dia ou atingir a data final prevista | Não gerar relatório final sem encerramento integral explícito pelo condutor |
| AUD-29 | Encerrar integralmente uma auditoria de cinco dias | Consolidar relatório final preservando cinco diários e atas vinculados à empresa/auditoria |
| AUD-30 | Certificação ainda sem decisão registrada | Mostrar Aguardando decisão; não inferir resultado dos percentuais de conformidade |
| AUD-31 | Repetir geração após erro ou duplo clique | Recuperar a emissão sem duplicar o documento lógico |
| AUD-32 | Corrigir relatório aprovado ou receber decisão externa posterior | Preservar versão anterior e registrar retificação/anexo com autoria e motivo |
| AUD-33 | Equipe variar entre dias | Listar presença real em cada diário e no final; preservar destinatários e aplicar revogações de acesso |

## 18. Decisões propostas para validação

O pedido principal está compreendido. Para tornar a futura implementação objetiva, esta versão propõe:

1. **Plano publicado visível a todos os vínculos ativos e aprovados da empresa**, com resultados/evidências restritos às autorizações da auditoria.
2. **Edição pelo condutor designado**, inclusive Administrador nessa função; outro Administrador pode reatribuir, com histórico.
3. **Evidência textual ou anexo para finalizar avaliações aplicáveis**, mantendo observações opcionais.
4. **PDF, JPEG e PNG até 10 MB por arquivo** como limite inicial de evidências.
5. **Estados completos de avaliação** para manter compatibilidade com o Dashboard, com Conforme/Não conforme em destaque.
6. **Cronograma versionado**, distinguindo previsão original, plano vigente e execução real.
7. **Documentos automáticos e simples**, publicados após validação do condutor: diários por dia, atas por reunião e final somente após encerramento integral.
8. **Destinatários por participação efetiva**, com documentos sempre vinculados à empresa/CNPJ, auditoria, plano e dia/evento; ciência separada da liberação para leitura.

Essas escolhas poderão ser ajustadas antes de programar. Estão fora deste primeiro incremento: preenchimento automático do conteúdo das normas, importação automática de qualquer PDF, operação offline, certificação automática, edição operacional por auditores de apoio e assinatura GOV integrada.

**Próximo passo:** validar este documento; somente então iniciar as etapas de implementação e seus testes.
