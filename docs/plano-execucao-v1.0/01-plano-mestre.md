# Audita PRO — Plano único de execução

**Versão:** 1.0 · **Data da análise:** 07/10/2026 · **Situação:** planejamento para validação.

## 1. Como usar esta entrega

Este plano organiza os **quatro documentos do último envio** em 16 blocos executáveis, B00 a B15. Cada bloco tem responsável, dependências, resultado e validação. O objetivo é entregar funcionalidades navegáveis com dados reais, preservando os módulos existentes.

Arquivos deste pacote:

- `01-plano-mestre.md`: ordem, diagnóstico, decisões e entregas.
- `02-matriz-requisitos.csv`: rastreabilidade detalhada do conteúdo dos quatro documentos, com localização original, bloco e situação.
- `03-criterios-de-aceite.md`: os 78 critérios originais, ligados aos blocos de execução e validação.
- `04-comandos-para-sessoes.md`: instruções reutilizáveis para cada sessão do Codex e cada bloco.
- `05-fontes-e-cobertura.md`: versões, hashes, estatísticas e limites da análise.
- `fontes/`: cópias integrais dos quatro anexos, preservadas como referência.

**Nesta entrega foram feitas somente leituras do código, do GitHub e dos catálogos do Supabase, além da criação destes documentos. Não foram alteradas telas, dados operacionais, permissões, migrations ou a conexão do aplicativo.** Não foram realizados testes funcionais autenticados do aplicativo nesta etapa de planejamento.

Os planejamentos de checklist e padrão documental mencionados nos anexos são dependências. Seus requisitos necessários à integração estão incluídos aqui; a implementação integral desses dois outros documentos não é presumida como parte dos quatro arquivos deste envio.

## 2. Verificação da versão atual

### 2.1 Bases verificadas

| Base | Resultado observado em 07/10/2026 |
|---|---|
| GitHub `viniciusrp158-glitch/AuditaPRO`, branch `main` | Referência remota consultada: `0f82ba2b5414f4f4c79001650149032fd4f759e3` |
| Cópia Git local `work/auditapro-git` | Mesmo commit; árvore limpa na consulta |
| Frontend em `outputs/` | HTML, CSS e JavaScript próprios; comparação dos arquivos de primeiro nível com o clone não encontrou diferenças nesses formatos |
| Backend versionado local | Migrations até `20261006212519_audit_document_locking.sql` |
| Supabase `zlckcpeqcxmtrgbdquee` | 52 migrations registradas; última `20261007160236_checklist_document_evidence` |
| Diferença relevante | Dez migrations de checklist de 07/10 existem no banco e não constam na sequência local consultada |

**Não existe, nas bases verificadas, uma versão única sincronizada de frontend, código das migrations e banco.** O GitHub está atualizado em relação ao clone consultado, mas não representa sozinho toda a estrutura que já funciona no Supabase. A primeira implementação deve recuperar e conciliar as alterações do checklist antes de avançar. Não reaplicar migrations antigas sobre as funções novas.

Não foi identificada neste workspace uma interface nova correspondente a todas essas migrations. Isso não prova que ela inexista em outra sessão ou diretório. B00 deve localizar a entrega de origem e confirmar qual pasta o servidor efetivamente serve. Acesso ao inventário de processos do Windows não estava disponível; nenhum endereço local foi validado como aplicação em funcionamento nesta análise.

### 2.2 Inventário e aproveitamento

| Área | Evidência atual | Situação para este plano | Modificação necessária |
|---|---|---|---|
| Login, perfis, organizações, aprovação cadastral | `audita-pro-auth.js`, `audita-pro-users.js`, `audita-pro-profile.js`; tabelas de perfis, vínculos e documentos | Base existente; não substituí-la | Harmonizar os quatro nomes e novas permissões sem bloquear onboarding |
| Menu, conta e notificações | Páginas HTML, `audita-pro-header.js`, sino e páginas de notificações | Base existente | Atualizar navegação em todas as páginas e papéis |
| Dashboard | `audita-pro-dashboard.js`, RPC `dashboard_admin_summary` e consultas existentes | Parcial para o novo escopo | Quatro visões, filtros, gráficos navegáveis e novas regras de contagem |
| Auditorias e equipe | `audita-pro-audits.js`, RPC `audit_workspace`, `audits`, `audit_participants`, histórico de participantes | Base existente | Ampliar poderes operacionais do Administrador; manter escopo do Líder/Auditor |
| Cronograma e revisões | `audit_days`, `schedule_items`, `schedule_movements`, `audit_plan_versions` | Parcial | Local/equipe por linha, período declarado, cópias, revisão completa e PDF persistido |
| Critérios integrados | Banco contém `criterion_ids`, `audit_checklists`, `checklist_components`; frontend consultado ainda apresenta tipo/modelo principal | Implementação no banco a integrar/verificar | Reutilizar composição; conferir versões e consumidores antes de acrescentar relações |
| Checklist | RPCs `checklist_library`, `checklist_execution`, perguntas, complementos e histórico | Estrutura nova presente no banco | Recuperar código correspondente; integrar plano/RDA e validar, sem criar outro checklist |
| OBS/OM e evidências selecionadas | `assessment_findings`, vínculos de achados; `evidence_files.include_in_rda`, `caption`, `display_order` | Campos/estruturas presentes | Completar o consumo no RDA, preservação das imagens e critérios editoriais |
| Indicadores do checklist | `private.checklist_stats` e `checklist_day_stats`, contrato 3 | Base real existente | Fixar unidade de contagem e corte temporal; não confundir pergunta, requisito e atividade |
| RDA, atas e final | `daily_reports`, versões, atas/finais e RPC `audit_documents` | Fluxo anterior existente | Prévia antes de fechar, 14 seções, emissão automática e distribuição aprovada |
| PDF no frontend consultado | `downloadPdf` usa jsPDF no navegador; impressão dinâmica | Não atende ao PDF oficial persistido por revisão | Gerar no backend, armazenar, validar arquivo e publicar com recuperação de falha |
| Biblioteca atual | `audita-pro-document-library.js` lista documentos de auditorias; `audita-pro-historico.html` contém histórico | Não equivale à nova biblioteca corporativa | Separar documentos institucionais, relatórios por auditoria e histórico do sistema |
| FPA | Nenhuma estrutura dedicada identificada nas tabelas/funções examinadas | Lacuna identificada | Fluxo mínimo de solicitação, anexo recebido, análise e versão vinculada |
| Código permanente do cliente | `organizations` não contém campo equivalente entre as colunas consultadas | Lacuna identificada | Geração controlada e preenchimento de legados sem mudar IDs |

### 2.3 Pontos técnicos que mudam o planejamento

1. **Permissão operacional do Administrador:** `private.workspace_conductor` exige ser o responsável designado. `workspace_documents` ainda bloqueia geração/aprovação por outro administrador. A nova especificação exige acesso operacional global com autoria real. Alterar contratos e verificações dependentes; não basta liberar botões.
2. **Leitura dos documentos:** `workspace_document_access` usa Administrador, condutor ou destinatários explícitos. Isso não implementa automaticamente a proposta de todos os vínculos aprovados da organização. Resolver D01 antes de alterar esse helper compartilhado.
3. **Fechamento diário:** `workspace_documents` cria RDA em `review` após fechar o dia e bloqueia atividades não concluídas. A nova regra aprova antes do fechamento e admite pendência documentada/encaminhada. Preservar bloqueios de uploads incompletos e separar pendência legítima de avaliação inválida.
4. **Snapshot atual:** já inclui contrato 3, evidências selecionadas, estatísticas diárias e acumuladas. Entretanto, o acumulado chama `checklist_stats(aid)` sem parâmetro de corte; retificar um dia anterior exige impedir incorporação de dias posteriores.
5. **Unidade de contagem:** contrato 3 trabalha com pergunta/pergunta extra + processo, enquanto o texto anterior do RDA fala em requisito + processo. A solução precisa distinguir indicadores de perguntas e cobertura de requisitos, com regra versionada e decisão D03.
6. **RLS:** as policies consultadas combinam regras permissivas e restritivas. Não avaliar uma regra isolada como se fosse a autorização inteira. Há tabelas novas com RLS sem policies diretas, utilizadas por funções controladas; isso não justifica liberar acesso irrestrito.
7. **Outra família de tabelas:** existem `Audit`, `Company`, `User` e outras em PascalCase, além do domínio em snake_case utilizado pelo código consultado. Essas tabelas estão sem RLS; a consulta confirmou ausência de `SELECT` para `anon` e `authenticated`. Não se concluiu vazamento nem uso pelo aplicativo. B00 deve identificar a origem, consumidores e demais privilégios. Não excluir nem expor essas tabelas por conveniência.

Este levantamento comprova presença de código/estrutura, não conclusão de fluxos de ponta a ponta. As classificações “existente” e “parcial” exigem validação nos blocos correspondentes.

## 3. Decisões que precisam de registro antes do bloco dependente

As propostas dos anexos continuam propostas até validação. Nenhuma divergência será resolvida por omissão. A execução futura poderá avançar em tarefas independentes enquanto uma decisão estiver pendente.

| ID | Divergência ou definição pendente | Proposta para validação | Bloqueia |
|---|---|---|---|
| D01 | RDA/Plano: todos da organização; Perfis V-03: organização + auditoria explicitamente autorizada | Adotar organização aprovada + autorização por auditoria. Leitor autorizado não precisa estar presente no dia. Permitir conceder acesso a auditorias históricas, sem inventar presença. Se escolhida consulta por organização inteira, documentar a exceção por tipo documental e não abrir todo o detalhe operacional | B02, B09, B12, B13 |
| D02 | Download do Participante proposto como pendente em V-06; RDA/Plano já o preveem | Permitir visualização e download dos PDFs publicados das auditorias autorizadas; manter biblioteca corporativa e evidências originais restritas | B02, B09, B12 |
| D03 | RDA conta requisito/processo; contrato 3 conta pergunta/processo; Dashboard público usa cronograma | Versionar três medidas: execução do checklist por unidade de pergunta/processo; cobertura de requisitos separada; progresso público por atividades divulgadas. Validar a adaptação do texto do RDA e o tratamento de perguntas opcionais antes de publicar cálculos | B03, B10, B11, B13 |
| D04 | Administrador global definido no documento de Perfis versus condutor exclusivo nos anteriores | Aplicar o requisito mais recente: Administrador opera globalmente, registrando o autor real, sem trocar automaticamente o responsável. Emissão continua imutável | B02 |
| D05 | Meu Perfil do Participante só leitura versus cadastro/competência existente | Preservar preenchimento e envio necessários ao onboarding; após aprovação, dados funcionais/empresa somente consulta, com correção por fluxo administrativo. Nunca permitir autoelevação de perfil/vínculo | B02, B04 |
| D06 | V-01/V-02/V-04/V-08/V-09/V-10 | Apoio sem escrita e sem rascunhos; um responsável; Admin controla concessões e transferências; Líder escolhe apoio habilitado; uma organização por Participante; acesso histórico explícito e revogação prevalente. Definir reabertura pelo Admin sem desbloquear PDFs emitidos | B02, B06, B12 |
| D07 | PC-01 a PC-08 e V-07 da biblioteca | Aprovar pacote: navegação apenas, busca/filtros, histórico Admin, auditores só vigente, arquivos privados, upload íntegro, PDF/DOCX/DOTX até 20 MB, formatos alternativos sem conversão. Participante sem biblioteca corporativa | B04, B05 |
| D08 | Identidade corporativa/PDA e menção à ABNT no RDA | Confirmar marca/template vigente e normas efetivamente aplicáveis à apresentação. Até lá, prévia com identidade disponível e indicação textual AUDITA, se aprovada; não declarar conformidade normativa não verificada | B08, B09, B12 |
| D09 | FPA, códigos e transição de legados | FPA mínimo por arquivo recebido pelo condutor; sem upload do cliente neste piloto. Confirmar formato dos novos códigos, preservar antigos; exigir FPA nas novas validações, sem inventar histórico | B06, B09 |
| D10 | Revisões históricas disponíveis ao cliente | Exibir versão vigente por padrão e anteriores claramente substituídas, somente para leitores autorizados. Disponibilização não depende de ciência/assinaturas; resolver conflito com Participante sem mutações mantendo ciência como fluxo separado, sem novo bloqueio do RDA | B02, B12 |
| D11 | V-12: quatro cartões/dois gráficos, filtro temporal e progresso divulgado | Adotar limite como composição inicial; filtrar por início planejado, com opções de histórico e ativos. Datas de eventos explicitadas. Incluir todos os indicadores exigidos em detalhes/listas sem eliminar informação existente | B03, B13 |

As decisões devem ser registradas com data, responsável, alternativa aprovada e impacto nos critérios originais. Se D01 alterar a regra literal de RDA-13/RDA-15, a matriz conservará o texto original e acrescentará o aceite revisado; não marcar o original como aprovado sem explicação.

## 4. Contratos comuns a todas as sessões

### 4.1 Autorização

- Autenticação Supabase existente; autorização no servidor por conta ativa, aprovação documental, perfil, organização e auditoria autorizada. Não confiar em campos de perfil editáveis pelo usuário.
- Administrador global; Líder opera auditorias sob responsabilidade; Auditor acompanha apenas atribuições; Participante lê projeções publicadas autorizadas.
- Separar concessão de acesso, integrante da equipe, presente no dia e signatário. Nenhum deles deve ser inferido automaticamente dos demais.
- Rascunhos, FPA, evidências originais, documentos de competência e documentos corporativos têm regras próprias. Uma liberação de RDA não libera todos os recursos.
- Verificar RPCs, consultas diretas, RLS, views, funções privilegiadas, Storage, notificações, buscas, totais e exportações. Testar revogação inclusive com sessão existente e links válidos, documentando o prazo efetivo de expiração; arquivo já baixado não pode ser recolhido.

### 4.2 Identidades e estados

- Preservar IDs e códigos existentes; cliente permanente, auditoria única, dia estável, documento lógico e revisão separados. Sequências no servidor, sem reutilização e seguras sob concorrência.
- Natureza = 1ª/2ª/3ª parte; tipo de avaliação = Inicial/Certificação/Manutenção/Recertificação/Follow-up/Diagnóstico/Outra; critérios = normas/referências versionadas; modalidade = presencial/remota/híbrida. Não converter finalidade textual legada sem correspondência comprovada.
- Manter estados operacionais existentes e mapear estados documentais. RDA: elaboração → fechado → emitido. Plano: rascunho → validado → publicado. Emissão técnica: pendente/processando/concluída/falhou. Revisão anterior continua vigente até publicação da substituta.
- Contrato de operação inclui identidade, versão esperada de edição e identificador idempotente. Conflito de edição informa o usuário; não sobrescreve silenciosamente.

### 4.3 Métricas e histórico

- Uma função/contrato de domínio compartilhado calcula as métricas; evitar fórmulas independentes no Dashboard, checklist e PDF.
- Progresso de execução proposto = `(C + PC + NC + N/A justificado) / total do escopo`. Zero itens: sem base; todos N/A: 100% processados e nenhum aplicável, sem alegar conformidade/certificação.
- Conjunto diário = previsto no início do dia, com movimentos preservados, mais trabalhado naquele dia; deduplicar pela identidade aprovada em D03. Transferência não apaga o item da comparação histórica.
- Acumulado é calculado na data de corte da revisão, sem somar reavaliações diárias e sem incorporar dias futuros em retificações.
- Progresso público do cronograma = atividades válidas divulgadas concluídas / atividades válidas divulgadas. Não expor detalhes internos do checklist por meio dos totais.
- Congelar versão de fórmula, template, dados, fontes, presenças e referências de evidência. Alterações futuras não reescrevem documentos emitidos.

### 4.4 Publicação e armazenamento

- Reutilizar Supabase, autenticação, notificações e backend. Não trocar framework, criar outro cadastro de empresas/auditorias ou contratar infraestrutura nova por padrão.
- Fechamento/validação e pedido de emissão gravados juntos; geração e upload fora da transação; publicação somente após integridade do arquivo confirmada, com atualização condicional.
- Um arquivo por revisão/formato, imutável; checksum e versão do template; retentativa usa o mesmo snapshot. Falha não publica link quebrado nem duplica versão/aviso.
- Arquivos privados com autorização específica. Evidências: PDF/JPEG/PNG até 10 MB. Biblioteca: PDF/DOCX/DOTX até 20 MB se D07 aprovada. Não aplicar o limite de anexo ao PDF gerado automaticamente.
- Preservar retenção de cinco anos; não implantar limpeza automática nem inventar o marco inicial ainda não definido. Backup/restauração são operações separadas.

## 5. Divisão entre sessões do Codex

| Sessão | Responsabilidade | Limite de atuação |
|---|---|---|
| C0 — Coordenação e integração | Baseline, decisões, contratos, matriz, ordem de integração, revisão de mudanças e entrega ao usuário | Única sessão autorizada pelo plano a aplicar migrations ao ambiente compartilhado; não executa publicação sem ambiente/escopo confirmado |
| C1 — Dados e permissões | Propostas de migrations, funções, RLS/Storage, transações, cálculos e compatibilidade | Desenvolve em branch/checkout isolado; entrega scripts e evidências a C0; não altera banco compartilhado em paralelo |
| C2 — Navegação e telas gerais | Menu, biblioteca, perfis e dashboards | Consome contratos aprovados; não redefine regras de acesso nem fórmulas no JavaScript |
| C3 — Auditoria e documentos | Plano, FPA, cronograma, revisão diária, templates e emissão PDF | Usa funções/contratos de C1; alterações no mesmo arquivo/função exigem divisão prévia |
| Revisão por outra sessão | Critérios, segurança e regressão | Em cada bloco, uma sessão diferente do autor revisa o diff e os testes; não é obrigatório manter cinco sessões simultâneas |

Pode-se começar com apenas C0+C1 e depois C2+C3. Mais sessões não reduzem dependências de dados. O código atual concentra muita lógica em `audita-pro-audits.js` e nas funções `workspace_*`; esses arquivos têm um único editor por vez. Separações pontuais em módulos são permitidas quando necessárias e preservam as rotas/contratos.

Branches por bloco, derivadas de um commit integrado conhecido, por exemplo `feat/b07-cronograma`. Checkouts separados; nunca duas sessões modificando os mesmos arquivos da mesma pasta. Registrar quem está trabalhando em cada bloco. C0 integra sequencialmente, revisa conflitos sem aceitar automaticamente uma das versões e atualiza o commit-base das demais sessões.

## 6. Sequência e dependências

| Bloco | Entrega | Responsável principal | Dependências concluídas |
|---|---|---|---|
| B00 | Conciliar versão real, inventário e ambiente | C0 | Nenhuma |
| B01 | Decisões, contratos e mapa de compatibilidade | C0 + C1 | B00 |
| B02 | Perfis e autorização por recurso | C1 | B01, decisões de acesso |
| B03 | Identidades, estados e métricas comuns | C1 | B01; integração após B02 |
| B04 | Menu, rotas e preservação do Meu Perfil | C2 | B02 |
| B05 | Biblioteca corporativa e histórico secundário | C2 + C1 | B02, B03, B04, D07 |
| B06 | Cabeçalho, códigos, FPA e critérios integrados | C3 + C1 | B02, B03, D09 |
| B07 | Editor de cronograma e continuidade | C3 + C1 | B06 |
| B08 | Emissão documental compartilhada | C3 + C1 | B02, B03, contrato de snapshot de B01 |
| B09 | Validação, PDF e publicação do Plano | C3 | B06, B07, B08, D01/D02/D08 |
| B10 | Dados e composição do RDA | C3 + C1 | B03, B07, B09; checklist conciliado em B00 |
| B11 | Prévia, fechamento e retificação do RDA | C3 + C1 | B10, B08 |
| B12 | PDF do RDA, distribuição e notificações | C3 + C1 | B11, B02, B08, decisões documentais |
| B13 | Quatro dashboards e navegação por indicadores | C2 + C1 | B02, B03, B09, B12, D11 |
| B14 | Integração completa, regressão e isolamento | C0 + revisor | B04 a B13 |
| B15 | Liberação controlada e validação do usuário | C0 | B14 e critérios sem pendências impeditivas |

Ordem simples, se preferir uma sessão por vez: **B00 → B01 → B02 → B03 → B04 → B05 → B06 → B07 → B08 → B09 → B10 → B11 → B12 → B13 → B14 → B15.**

Paralelismo seguro: depois de B03, biblioteca (B04/B05), identificação/cronograma (B06/B07) e infraestrutura documental (B08) podem ser desenvolvidos em branches distintas, com contratos estáveis. C1 serializa as mudanças de banco e C3 não executa B06/B07 e B08 simultaneamente no mesmo arquivo. C2 pode preparar o layout de B13 antes, mas a entrega funcional depende dos dados integrados, sem mocks em produção.

## 7. Especificação dos blocos

### B00 — Baseline e conciliação da versão mais recente

**Trabalho:** repetir a consulta da referência Git e migrations no início da execução; localizar entrega/código das dez migrations remotas; comparar funções implantadas com arquivos versionados; verificar qual pasta é servida e como publicar seus assets. Inventariar grants, RLS, funções, buckets, Edge Functions, rotas e consumidores. Identificar uso da família PascalCase sem tocar seus dados. Registrar versões das dependências e instruções de inicialização.

**Saída:** `baseline.md`, commit-base, manifesto de migrations e diferenças resolvidas ou explicitamente bloqueadas, mapa de arquivos/rotas e ambiente de validação. Recuperação do histórico remoto não significa executar novamente suas migrations. Preparar backup e procedimento de restauração do banco **e arquivos** antes das futuras mudanças.

**Aceite:** código que será alterado representa o contrato implantado; nenhuma migration remota desaparece; projeto Supabase confirmado; nenhum segredo no repositório/relatório. Se não for possível recuperar o código do checklist, bloquear somente a integração dependente e explicar precisamente o que falta.

### B01 — Decisões e contratos de integração

**Trabalho:** registrar D01–D11 e todas PC/V dos anexos; converter pendências em escolhas explícitas. Publicar contratos de autorização, projeção pública, checklist, período/dia, snapshot, revisão, emissão, métricas e erros. Definir campos novos somente após conferir equivalentes reais. Fixar estratégia para legados e leitores históricos.

**Saída:** contratos com exemplos de formato sem dados pessoais reais; tabela de transições, mapa de consumidores e proposta de migrations por responsabilidade. Nomes de tabelas complementares permanecem propostas até inspeção final.

**Aceite:** nenhuma tela/backend usa significado diferente para perfil, status, item, revisão ou progresso; todos os requisitos da matriz têm dono. Uma decisão ainda pendente mantém visível o bloqueio do bloco afetado.

### B02 — Perfis, vínculos e autorização efetiva

**Trabalho:** aplicar os quatro perfis sem quinto “Administrativo”. Admin global com autoria; Líder responsável; apoio somente leitura; Participante em escopo aprovado. Distinguir equipe, presença, destinatário e signatário. Consolidar permissões de criar/conduzir/validar/encerrar/reabrir, atribuir equipe e transferir responsabilidade. Proteger alteração de perfil/organização no Meu Perfil.

**Reuso:** `user_profiles`, `organization_memberships`, `access_profiles`, permissões, `audit_participants`, histórico, helpers e políticas existentes. Revisar `workspace_conductor`, funções de documentos, grants de execução, policies permissivas/restritivas e acesso aos arquivos em conjunto. Não adicionar `SECURITY DEFINER` como remendo de erro de permissão.

**Aceite:** PER-01–10, PER-13–15, PER-18–20 e testes diretos de API/Storage. Administrador diferente do responsável opera sem falsificar autor; apoio não consegue operar mesmo manipulando requests; conta desativada e acesso revogado deixam de obter novos dados. Preservar cadastro/aprovação documental e proteção do último administrador.

### B03 — Identidades, estados e cálculos compartilhados

**Trabalho:** mapear dados legados; códigos estáveis cliente/auditoria/RDA/achados sem renumeração; estados separados; compatibilidade do contrato 3 com indicadores e PDFs. Definir chave de unidade do checklist, tratamento de opcionalidade, conjunto diário, acumulado por corte temporal, referência do plano no início do dia e revisão de fórmula. Queries filtram autorização antes da agregação, usam paginação e índices justificados.

**Aceite:** códigos simultâneos únicos; 55 C + 5 PC + 3 NC + 7 N/A + 30 pendentes = 70% de execução; exemplo diário 28 unidades = 27 processadas e 26 aplicáveis avaliadas; regravar item não duplica; reavaliação conta uma unidade no acumulado; perguntas diferentes e processos distintos mantêm identidades; nenhum item e todos N/A tratados corretamente. Relatório legado mantém cálculo original.

### B04 — Navegação e Meu Perfil

**Trabalho:** menu Dashboard → Auditorias → Usuários → Biblioteca de documentos → Meu Perfil, condicionado às permissões. Retirar NC, Planos de ação e Indicadores somente do menu. Aplicar também a páginas antigas, menu recolhido e mobile. Preservar logo oficial, retorno à home, atalhos de conta, notificações e histórico de navegação. Entrada na biblioteca sempre abre documentos. Separar restrição funcional de Meu Perfil e fluxo obrigatório de onboarding conforme D05.

**Aceite:** CA-01–03/12; PER-20; percorrer todas as páginas autenticadas em desktop e tela pequena. Módulos internos, relatórios e dados não são apagados. URLs antigas continuam sujeitas à autorização.

### B05 — Biblioteca corporativa

**Trabalho:** confirmar ausência de estrutura equivalente e acrescentar apenas metadados/revisões/arquivos que faltam. Admin cadastra título, tipo, código quando atribuído, revisão, descrição e arquivo; emissão/responsável obrigatórios para vigente. Upload não publica automaticamente. Revisão suporta formatos alternativos equivalentes; DOTX mestre separado do PDA. Sem conversão automática e sem carga inicial dos rascunhos mencionados no anexo.

Busca por título/código; filtros de tipo/situação; paginação; formatos disponíveis; download exato e privado. Auditores só revisão vigente se D07 aprovada. Admin revisa e arquiva, preservando original; sem exclusão definitiva/reutilização de código. Validar tamanho/tipo real no servidor, inclusive pacote Office e ausência de macros, sem confiar somente em extensão/MIME enviado pelo navegador.

Histórico do sistema em acesso secundário, reutilizando a fonte existente, com Voltar à biblioteca; revisões documentais são uma visão diferente. Se o histórico encontrado tiver natureza distinta, relatar e adaptar apresentação sem inventar eventos.

**Aceite:** CA-04–11/13 e PER-19. Falha de upload não libera registro incompleto; download não é público; edição local de Word não altera original; biblioteca vazia, filtro sem resultado e erro distintos; participante continua acessando relatórios pela auditoria autorizada.

### B06 — Identificação, FPA e integração de critérios

**Trabalho:** códigos automáticos e imutáveis com migração controlada de clientes sem código; preservar auditorias antigas. Cabeçalho completo: cliente/endereço/unidade, período declarado, critérios e edições, natureza, tipo de avaliação e descrição de Outra, objetivo, códigos, equipe habilitada incluindo condutor, outros participantes textuais e comentários com opção N/A, escopo e modalidade existente. Orientação N/A persistente, legível e em itálico. Rascunho pode ficar incompleto.

Reutilizar `criterion_ids`, componentes e checklists versionados implantados. Completar seleção de vários critérios/modelos no frontend e consumidores; cláusulas iguais de normas diferentes não se mesclam; cópia de atividade não duplica escopo. Alterar catálogo não altera modelo já aplicado. Retirada de critério em execução exige revisão preservando registros.

FPA por auditoria: não solicitado → solicitado → recebido → em análise → complementação solicitada → suficiente. Registrar destinatário, prazo, autor/data, arquivo real, versão e análise. Rascunho do plano permitido antes da análise; validação bloqueada enquanto insuficiente. Recebimento externo pelo condutor; sem nova permissão de envio ao Participante. FPA não integra automaticamente PDF nem acesso público do plano.

**Aceite:** PA-01–06/11–12/19/24, PER-03/04. Auditoria integrada real, unidade não vira novo cliente, nome textual não cria conta/acesso; FPA de outra auditoria não satisfaz esta; não inventar FPA para legado.

### B07 — Cronograma editável e continuidade

**Trabalho:** local, data, início/fim, área/processo/atividade e múltiplos auditores habilitados por linha. Detalhe com categoria, requisitos e observações. Adicionar/remover/duplicar/reordenar por botões; arrastar complementar. Copiar próximo horário com duração e escolher próximo dia real. Nova linha não copia execução, presenças/evidências/resultados. Remoção após publicação vira retirada controlada.

Validar duração, período e meia-noite dividida; avisar sobreposição do mesmo auditor sem impedir equipes distintas. Ordem visual separada de data cronológica; não renumerar dias/documentos emitidos. Reuniões/intervalos sem requisito artificial.

Guardar plano original, vigente ao abrir o dia e mudanças posteriores; presença efetiva separada da equipe. Executado antecipadamente registra horário real. Parcial mantém realizado/restante; transferências encadeadas preservam identidade, origem/destino, motivo e autor. Não realizada sem destino exige motivo e encaminhamento, sem conclusão fictícia.

**Aceite:** PA-07–10/17–19/22–23, RDA-08. Exercitar dias não consecutivos, transferência repetida, parcial, antecipação, exclusão controlada e duas sessões concorrentes. Pendência livre não muda cronograma sem confirmação da operação correspondente.

### B08 — Serviço comum de emissão documental

**Trabalho:** escolher e comprovar biblioteca/runtime compatível com backend existente, fotos, fontes, gráficos e páginas extensas; consultar documentação atual durante implementação. Não contratar serviço novo por padrão. Construir motor compartilhado com templates distintos para Plano/RDA; persistência do pedido de emissão, idempotência, versão do template, checksum, retry e publicação condicionada à integridade.

Definir template/identidade validados; cabeçalho/rodapé repetidos, paginação, títulos de tabelas, imagens proporcionais, português, contraste e impressão monocromática. Revisar referências ABNT somente quando identificadas e aprovadas como aplicáveis. Não emitir declaração genérica de conformidade.

**Aceite:** interromper geração/upload e retomar mesma revisão; duas tentativas não criam dois documentos; arquivo incompleto privado; checksum estável após alterações de cadastro. Validar limites de execução com documento grande e registrar medições, sem promessa de desempenho sem evidência.

### B09 — Plano validado, versionado e publicado

**Trabalho:** assistente Identificação/FPA → Equipe → Cronograma → Escopo/comentários → Prévia/validação. Implementar integralmente as **15 verificações da seção 10 do Plano**, com atalhos para correção e avisos separados de bloqueios. Validar versão esperada de edição; congelar cabeçalho, critérios, equipe, cronograma, escopo, comentários, notas e FPA de referência.

Gerar Rev.00 e seguintes com motivo, autor e data; PDF persistido antes de publicação. Escopo após tabela. **As nove notas do Anexo A devem ser preservadas integralmente em página final dedicada**, legível e versionada. Cabeçalhos, rodapés e Página X de Y em todas as páginas. Não trocar empresa de auditoria publicada como simples edição.

Cliente consulta projeção publicada conforme decisão, sem acesso ao FPA por consequência. Iniciar execução após primeira publicação; anterior vigente enquanto nova revisão processa. Notificar publicação/revisão no sino com evento único; não alegar e-mail enviado sem integração.

**Aceite:** PA-13–16/18/20–24, PER-09/10. Nova revisão e mudança de cadastro não alteram PDFs/RDAs anteriores; falha não libera link; um único Admin/condutor valida e executa sem aprovador fictício.

### B10 — Conteúdo e dados do RDA

**Trabalho:** reaproveitar achados/evidências já implantados; completar resumo executivo obrigatório, sínteses editáveis rastreáveis, pendências/considerações ou declaração explícita de ausência, amostragem, códigos e autoria. NC vinculada obrigatória para resultado não conforme; parcial exige decisão técnica/NC quando houver descumprimento, conforme metodologia; maior/menor só quando aplicável. Não converter notas antigas em OBS ou OM automaticamente.

Implementar as **14 seções**, nesta ordem: identificação; resumo executivo; planejado × realizado; indicadores diários; progresso acumulado; requisitos avaliados; NC; OBS; OM; evidências selecionadas; pendências; alterações do plano; considerações; controle documental.

Dia e acumulado separados; classificação realizada/parcial/reprogramada/não realizada; movimentos e base do início do dia preservados. Fotos escolhidas com legenda/ordem/referência; PDFs referenciados com síntese, sem anexar todas as páginas; texto/fotos/documentos contados separadamente. Excluir documentos de competência/identificação. Congelar conteúdo publicado das imagens, não apenas link mutável.

**Aceite:** RDA-04–10/18/20; duas fotos selecionadas de doze aparecem e as outras não; dados e autor corrigidos na origem/retificação, nunca somente no PDF; RDA não decide certificação nem cria final antecipado.

### B11 — Prévia, fechamento diário e revisões do RDA

**Trabalho:** revisão antes de fechar; mostrar conteúdo completo, gráficos, fotos, pendências e rascunho. Aplicar todas as verificações da seção 10 do RDA. Presenças reais, plano publicado, evidência disponível, N/A justificado, NC/parciais tratados, resumo/considerações, pendências encaminhadas e prévia atualizada.

Uma confirmação “Finalizar dia e emitir RDA” aprova/congela/pede emissão; não exigir nova aprovação depois. Permitir trabalho pendente legítimo documentado; não permitir upload falho, resultado inválido ou informação inconsistente. Duas sessões/duplo clique detectados. Data auditada, horário real, fechamento e emissão separados no fuso correto.

Retificar exige motivo, cria nova revisão e preserva vigente; corte temporal impede dados futuros. Retificação da fonte ligada à nova revisão com autoria. Código RDA atribuído uma vez no primeiro fechamento, sem renumeração ao editar cronograma.

**Aceite:** RDA-01–03/08–09/11–12/21. Falha no PDF não reabre dia automaticamente; retomada não duplica fechamento; um único profissional consegue concluir o fluxo.

### B12 — Emissão e distribuição do RDA

**Trabalho:** gerar PDF A4 com 14 seções, gráficos de resultados diários e processados × pendentes, textos equivalentes, tabelas extensas, fotos legíveis, cabeçalho/rodapé completos e seções vazias explicadas. Publicar após geração verificada; mesmo download retorna o mesmo arquivo da revisão. Histórico marca substituídas; nova revisão não esconde a vigente enquanto incompleta.

Listagem por empresa/auditoria/dia e acesso direto ao documento autorizado sem obrigar acesso a detalhe operacional interno. Manter biblioteca corporativa separada. Se D01 aprovar alcance organizacional amplo, implementar rota de consulta específica ao RDA sem liberar a auditoria inteira.

Notificar publicação/revisão aos elegíveis com chave versão/usuário/evento; falha só ao condutor/Admin responsável pela ação; novo vínculo não recebe avalanche de avisos passados. Ciência, leitura e notificação lida são fatos diferentes; nenhuma assinatura bloqueia disponibilidade do RDA. Sem integração GOV nova.

**Aceite:** RDA-10–21, PER-05–10/14/15. Novo leitor autorizado vê histórico sem virar presente; revogado/outro cliente não baixa por URL/API; não ampliar atas/finais/evidências ao mudar acesso do RDA; PDF antigo idêntico.

### B13 — Dashboards funcionais dos quatro perfis

**Trabalho:** reusar consultas e telas, aplicar escopo antes de agregações e filtros; não carregar todo histórico para calcular cartões. Paginação, índices e consultas consolidadas com medidas reais. Filtrar período com data-base explícita, organização/tipo/responsável/etapa conforme papel. Canceladas separadas de concluídas, tipo ausente identificado, empresas contadas distintamente, relatório lógico sem duplicar revisões, atraso somente com data válida. Gráficos agrupados: até cinco categorias + Outros e lista completa filtrada.

| Perfil | Composição a implementar |
|---|---|
| Administrador | Cartões empresas com auditorias, planejadas, em andamento, encerradas; distribuição por etapa; auditorias por organização/tipo; atrasadas, próximas e pendências reais de validação; criação, usuários e documentos conforme permissão |
| Auditor Líder | Empresas de sua carteira autorizada, em andamento, encerradas, pendências; auditorias por empresa/etapa e por tipo; próximas atividades, lista e ações das auditorias sob responsabilidade |
| Auditor | Empresas em que participou, em andamento, encerradas e relatórios disponíveis; distribuição por empresa e tipo; responsável, próxima atividade e acesso somente leitura |
| Participante | Empresa autorizada; situação da auditoria, próxima atividade, RDAs disponíveis e final; cronograma divulgado/timeline e progresso público; documentos publicados, sem checklist interno/dados administrativos |

Click em cartão/gráfico abre lista real com mesmos filtros e escopo, inclusive Outros. Progresso do checklist e do cronograma não recebem o mesmo rótulo. Usar estados carregando, vazio, filtro vazio, erro, sem permissão e sem base; data de atualização; mobile, teclado, rótulos e alternativas textuais aos gráficos. Preservar indicadores operacionais existentes em área autorizada de detalhe quando não couberem na composição inicial.

**Aceite:** PER-11–18; totais coincidem com listas sob filtros iguais, nenhuma informação da empresa Y para X, cache limpo ao trocar usuário, erro não vira zero, data nula não vira atraso. Dashboard recebe alterações reais do plano/RDA/checklist sem cadastro duplicado de indicadores.

### B14 — Integração e regressão

**Trabalho:** executar os 78 critérios originais e as linhas normativas da matriz, com adaptações aprovadas documentadas. Validar onboarding, login, usuários/organizações, competência, notificações, menu/home, catálogo/checklist, NC/ações, evidências, atas, relatórios finais, ciência e PDFs legados. Auditoria integrada de vários dias com equipe, antecipação, transferência parcial, correção e encerramento final. Verificar final sem somar reavaliações diárias.

**Dados de validação:** ambiente separado ou fixtures identificadas e autorizadas; organizações X/Y, Admin, Líder responsável e não responsável, apoio vinculado/não vinculado, participante liberado e não liberado para duas auditorias da mesma empresa, pendente/inativo, novo leitor histórico e revogado. Nunca inserir mocks para representar indicadores de produção.

**Aceite:** revisão independente do autor; testes positivos e negativos em navegador e API/Storage; concorrência, retentativa e falha de rede/PDF; hashes de legados preservados; restauração ensaiada no ambiente apropriado; medição de consultas e documentos grandes; nenhuma pendência crítica omitida.

### B15 — Liberação e validação da Audita

**Trabalho:** C0 confere baseline novamente; integra commits, backup, sequência de migrations, backend e frontend compatíveis. Preferir expansão de campos/contratos antes de trocar consumidores. Sem reset de banco e sem apagar documentos para rollback. Liberar bloco funcional somente após testes e critérios; manter recursos novos indisponíveis se backend necessário ainda não estiver implantado, com mensagem clara.

**Entrega por atualização:** resumo do que mudou, arquivos/tabelas/policies/migrations, commit, pendências, como testar cada perfil e **link de acesso realmente verificado**. Se servidor local: iniciar corretamente, confirmar resposta e tela antes de enviar localhost; informar como reiniciar. Não inventar URL nem prometer que servidor parado continuará acessível.

**Reversão:** desativar entrada/ação nova e retornar consumidor compatível quando necessário; preservar schema aditivo, snapshots e arquivos; corrigir banco por nova migration rastreada. Não voltar a policy que reabra acesso indevido. A restauração de backup é último recurso com avaliação de dados novos.

**Aceite final:** usuário recebe pacote navegável, resultados por requisito e roteiro; correções pedidas viram itens identificados. “Implementado”, “testado” e “validado pelo usuário” permanecem estados separados.

## 8. Controle de qualidade e conclusão

Cada requisito percorre: **mapeado → decisão resolvida → em execução → implementado → testado → validado pelo usuário**. “Já existe” somente dispensa recriação; não dispensa prova de compatibilidade. A matriz começa sem declaração de implementação concluída neste trabalho.

Para encerrar um bloco, preencher:

1. IDs e linhas-fonte atendidos; mudanças de interpretação aprovadas.
2. Arquivos/contratos modificados e commit-base/commit-entrega.
3. Migrations propostas/aplicadas e ambiente, sem segredos.
4. Testes realizados, resultado e evidência; critérios não testados explícitos.
5. Compatibilidade, limitações e reversão.
6. Link e roteiro curto para validação do usuário quando houver interface entregável.

Nenhum item opcional ou futuro desaparece: permanece na matriz com seu motivo e fronteira. E-mail novo, GOV, FPA online completo, edição pelo apoio, novos perfis, conversão de Word/PDF e substituição de arquitetura não são adicionados por inferência. As referências normativas fornecidas pelo usuário são conteúdo de negócio; não inventar textos de normas nem resultado de certificação.

**Próximo passo recomendado:** validar as decisões D01–D11 e autorizar B00/B01. Depois iniciar B02/B03. O desenvolvimento de biblioteca, plano e emissão pode então ser distribuído entre sessões com os contratos comuns já definidos.
