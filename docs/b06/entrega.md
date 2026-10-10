# B06 — Entrega incremental para integração

Data: 09/10/2026. Autor: Codex 03 com subagentes GPT-5.6 Sol / esforço leve e revisão final do agente principal.
Branch: `feat/b06-identificacao-fpa`. Base: `566b569f2e70e0582cd49154225d31c2a3161286`.
**Situação: incremento implementado e testado localmente; B06 não concluído.**

## Base e autorização

O usuário confirmou B00/B01/B02/B03 implementados e validados; B04/B05 estão com Codex 01. A consulta de leitura confirmou B02/B03 no Supabase `zlckcpeqcxmtrgbdquee`. O Git remoto consultado ainda só oferece `main` (0f82ba2), checklists (bee387f) e B04 (566b569). Não substituir o trabalho integrado do Codex 01 por esta árvore.

Não foi localizado o registro final D09 nos materiais disponíveis. O plano determina recuperar essa decisão e trabalhar nas partes independentes enquanto ela não estiver acessível. Isso não invalida a conclusão de B01 informada pelo usuário nem exige aprovar novamente uma decisão já tomada.

O comando comum do plano proíbe migrations no banco compartilhado por esta sessão e reserva sua aplicação coordenada ao Codex 01. Nenhuma mutation, migration, upload, mensagem ou publicação foi executada no Supabase. Não foram redefinidos os contratos B02/B03.

## Implementação conectada ao fluxo existente

- Formulário de criação modular com cliente, unidade, condutor, natureza, modalidade, local, objetivo, escopo e critérios.
- Critério principal não se repete como adicional; IDs e edições continuam separados. Reutiliza `audit_workspace/create` e `criterion_ids` existentes; não inventa norma ou requisito.
- Endereço estruturado apresentado com escape; sugestão preenche apenas local vazio. Código/endereço do cliente são mostrados quando o contexto efetivamente os fornece, sem fabricar códigos ausentes. O resumo não exibe unidade sem a projeção de seu nome.
- Troca de organização limpa unidade/condutor/modelo, desabilita criação durante a carga e descarta respostas antigas. Erro não deixa dependências anteriores reutilizáveis.
- Resumo de identificação prioriza `audit.standards` salvo; alteração posterior do catálogo não substitui a edição registrada.
- Novos JS/CSS carregados somente na página de auditorias. Cabeçalho, autenticação, perfil, navegação compartilhada B04 e demais páginas não foram editados.

Arquivos: `outputs/audita-pro-audits.js`, `outputs/audita-pro-auditorias.html`, `outputs/audita-pro-plan-identification.js` e `.css`.

## Componentes preparados, sem ativação no sistema

1. O módulo de identificação contém formulário completo de edição: período declarado, tipo de avaliação, descrição de Outra, participantes textuais, comentários e orientação N/A persistente. Não há botão ativo nem gravação fictícia desses campos. A integração requer RPC aprovado, disponibilidade anunciada e autorização de escrita por auditoria.
2. [Proposta SQL](propostas/identificacao-v1.sql) e [contrato](propostas/contrato-identificacao-v1.md) acrescentam campos e RPC independente, com autoria, controle de concorrência e limites de alteração de rascunho. **Não aplicados, não compilados nem executados em Postgres.** Não é migration pronta para produção.
3. [Regras executáveis de FPA](propostas/fpa-workflow.mjs) exercitam estados, complementações, versões e referência privada para B09. São proposta de domínio sem endpoint, tela, persistência ou upload. Contexto/autoria/arquivo verificado devem vir de adaptador servidor; os testes não comprovam autenticação, RLS ou Storage reais.

O FPA exige ainda adapter autenticado, armazenamento privado, validação de bytes, operações idempotentes, persistência transacional com comparação de versão e integração do bloqueio à validação do plano. O fluxo de publicação atual não foi alterado. Não há FPA fictício para auditorias antigas.

## Testes e limites

Executados localmente:

```sh
npm ci --ignore-scripts --prefix scripts
node scripts/test-b06-identificacao.mjs
node scripts/test-b06-fpa-workflow.mjs
npm test --prefix scripts
node scripts/test-b04-navigation-ui.mjs
node scripts/test-b04-profile.mjs
node --check outputs/audita-pro-audits.js
node --check outputs/audita-pro-plan-identification.js
git diff --check
```

Os dois scripts B06 e os cinco scripts de regressão passaram. A revisão independente apontou a unidade sem projeção no resumo (corrigida pela omissão até existir dado), e confirmou como pendentes rascunho incompleto, edição persistente e FPA. O teste de identificação usa DOM simulado, incluindo chamadas assíncronas fora de ordem, erro de contexto, escape, critérios integrados, edição registrada e hints. O teste de FPA cobre regras de domínio: versão incorreta, arquivo de outra auditoria, complementação, autoria e preservação da versão anterior. Os testes de evidência existentes usam mocks de Storage/Auth.

Não foram executados testes autenticados contra banco nem teste visual de navegador. O teste histórico `test-b04-navigation.mjs` restringe toda a árvore ao escopo B04 e por isso não serve como gate global de uma branch B06; seu arquivo foi preservado. Os testes funcionais de navegação/perfil foram executados.

Servidor local temporário iniciado com `AUDITA_PRO_PORT=4176 node outputs/audita-pro-dev-server.js`; página e novo JS responderam HTTP 200 em `http://127.0.0.1:4176/audita-pro-auditorias.html`. O servidor temporário foi encerrado após a verificação. É endereço do ambiente local, não publicação acessível ao usuário em outro computador. A página requer sessão e ainda aponta ao Supabase compartilhado: não criar dados de teste ali. Codex 01 deverá homologar em ambiente de teste separado, com URL própria.

## Rastreabilidade e conclusão

[Matriz](rastreabilidade.csv): 122 linhas B06, mantendo as 16 colunas originais. [Critérios](criterios.md) mantêm redação original. Colunas novas distinguem incremento local e validação integrada pendente. Nenhum aceite completo foi marcado aprovado.

| Critério | Situação desta entrega |
|---|---|
| PA-01/02 | Reutilizar códigos de B03; nenhuma nova sequência criada. Teste integrado pendente |
| PA-03 | Exibição dos dados disponíveis preparada/testada com contexto simulado; contrato completo de código/endereço ainda precisa ser conciliado |
| PA-04 | Edição de rascunho incompleto proposta. A criação existente ainda exige título/escopo; validação final B09 permanece pendente |
| PA-05 | Formulário completo preparado; persistência do cabeçalho e homologação pendentes |
| PA-06 | Seleção e resumo de critérios testados; composição de várias versões/consumidores e teste real ainda pendentes |
| PA-11/12 | Regras de FPA testadas isoladamente; D09, upload/persistência e snapshot B09 pendentes |
| PA-19/24 e PER-03/04 | Permissões existentes preservadas; homologação real de equipe e operação individual pendente |

## Próximos passos do Codex 01

1. Incorporar o diff independente sobre a base integrada atual, sem copiar o checkout inteiro. Conferir reserva de arquivos em B04/B05.
2. Disponibilizar registro D09 e contratos B01/B02/B03. Conferir D06 e o retorno real de código/endereço/unidade no contexto antes de fechar PA-03.
3. Revisar a proposta de identificação em banco isolado, incluindo RLS/grants, conta inativa, Admin/condutor, apoio, Participante, unidade de outra empresa, duas sessões e rascunho publicado. Gerar migration oficial pelo fluxo do projeto somente depois dessa validação.
4. Conectar o formulário de edição ao contrato aprovado, com erro visível e sem fallback que informe sucesso sem persistir. Concluir criação de rascunho incompleto conforme PA-04 e consumo do cabeçalho pelos blocos posteriores.
5. Implementar adaptador FPA e confirmar preservação de arquivos/versões, ausência de acesso do Participante no piloto conforme D09 e bloqueio de validação por auditoria. Snapshot privado não deve aparecer automaticamente no PDF ou projeção do cliente.
6. Executar os critérios originais na base integrada, registrar evidências e só então fechar B06.

Reversão deste incremento: reverter seu commit de frontend/documentação. A proposta SQL não foi aplicada e não exige rollback no ambiente. Não reverter B02/B03 nem apagar arquivos/versões históricas como parte de B06.
