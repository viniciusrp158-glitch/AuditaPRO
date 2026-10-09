# B04 — Integração com B02 e navegação

Data: 09/10/2026. Autor: Codex 03. Estado: implementação em branch de revisão,
sem publicação na aplicação e sem conclusão integral de B04.

## Base verificada

O proprietário confirmou B00/B01/B02 concluídos. Consulta de leitura ao Supabase
`zlckcpeqcxmtrgbdquee` confirmou as migrations `b02_authorization_core`,
`b02_access_adapters`, `b02_rls_storage`, `b02_profile_guards` e
`b02_reassign_cmd1_guard` (última versão `20261008191655`).

O GitHub consultado ainda contém a main original, a branch de checklists e a
preparação B04. Não foi localizada a entrega versionada B01/B02 nem PR integrado.
Por isso este incremento parte de `72c1e2f` e consome apenas contratos efetivamente
inspecionados no backend. Codex 01 deverá conciliar o diff com seus arquivos atuais
antes da publicação. Não copiar o diretório inteiro sobre o trabalho de B02/B03.

## Contratos consumidos e implementação

- `profile_command('context')`: `admin` booleano emitido pelo servidor; cada
  vínculo inclui `participant_functional_readonly`.
- Respostas com `membership_id`, inclusive `open`/`new_revision`: indicador
  `participant_functional_readonly` também presente.
- O wrapper B02 bloqueia alteração dos campos funcionais aprovados e impede
  pesquisa/solicitação de organização se qualquer vínculo da conta for de
  Participante aprovado. Nenhum comando de escrita foi executado nesta leitura.

Meu Perfil usa esse indicador, sem inferir o papel por metadados editáveis ou
nome de usuário. Unidade, cargo, função, área, gestor e contato do gestor ficam
consultivos, com orientação para correção administrativa. Telefone pessoal e
revisões/documentos continuam disponíveis. Os payloads preservam os valores
funcionais recebidos do servidor; se houver correção concorrente, a proteção de
B02 permanece autoritativa. Mesmo na opção “Dados da conta”, a solicitação de
empresa continua oculta quando existir vínculo aprovado protegido.

A navegação compartilhada acrescenta controle de recolher/abrir, identificação
da página atual, Escape com retorno do foco e composição vertical em telas
pequenas. “Usuários” começa oculto no HTML e só aparece com `context.admin === true`.
Falha de atualização de contexto ou encerramento de sessão oculta-o novamente.
Links restantes são preservados; esconder um link não substitui autorização da API.
O cabeçalho existente repassa o contexto e sua invalidação à navegação, sem
alterar login, notificações, permissões do banco ou suas RPCs.

## Fronteira da Biblioteca e critérios ainda abertos

O destino atual `audita-pro-historico.html` contém histórico e relatórios de
auditoria, não a biblioteca corporativa exigida pelo plano. A navegação não foi
renomeada para prometer uma listagem inexistente, nem foram criadas tabelas,
uploads ou documentos fictícios de B05.

| Critério | Estado neste incremento |
|---|---|
| CA-01 | Três entradas retiradas; oito páginas cobertas por verificação estrutural. Menu recolhível e eventos de teclado/resize exercitados em DOM simulado. |
| CA-02 | Ordem dos links preservada e Usuários condicionado ao contexto; nome/destino corporativo ainda pendente. |
| CA-03 | Pendente da rota/listagem corporativa B05 e retorno explícito do histórico. |
| CA-12 | Conteúdo de domínio preservado; testes existentes de checklist executados como regressão. |
| PER-01 | Não foram criados papéis novos; nomes recebidos do servidor preservados. Homologação dos quatro perfis depende da base integrada. |
| PER-20 | Consumidor frontend da proteção B02 implementado e testado em DOM simulado; teste autenticado de integração ainda não executado por esta sessão. |

## Testes reproduzíveis

Instalar dependências existentes com `npm ci --ignore-scripts --prefix scripts`.
Não houve inclusão de dependência nem mudança de lockfile.

```sh
node scripts/test-b04-navigation.mjs
node scripts/test-b04-navigation-ui.mjs
node scripts/test-b04-profile.mjs
npm test --prefix scripts
git diff --check
```

Execução local de 09/10: os três testes B04 e os três testes de regressão do
comando npm acima passaram. A verificação de whitespace e sintaxe passou.

Os testes B04 verificam preservação estrutural, destino dos links, controle de
menu, contexto administrativo/erro/troca, participante protegido, payload
adulterado no DOM, telefone editável, troca para Dados da conta, revisão pessoal
e documentos do onboarding. São testes locais com respostas simuladas; não
comprovam layout renderizado, autenticação real, RLS ou Storage em produção.

## Handoff para Codex 01

1. Conciliar os arquivos alterados sobre o commit integrado B02/B03 vigente,
   especialmente `audita-pro-header.js` e `audita-pro-profile.js`.
2. Reexecutar os testes sobre essa base e revisar as decisões B01 D05/D07.
3. Homologar no navegador com Admin, Líder, Auditor, Participante aprovado e
   cadastro pendente; verificar telas pequenas, teclado, notificações e saída.
4. Acordar com B05 o destino corporativo para concluir CA-02/CA-03. B03 não é
   dependência direta da navegação/perfil; a funcionalidade corporativa pertence
   ao bloco B05, que tem seus próprios pré-requisitos.
5. Publicação e declaração de conclusão somente após fechar essas pendências.

Nenhuma migration foi criada/aplicada. Nenhum dado real foi alterado. Reversão:
reverter o incremento de frontend compatível, mantendo as proteções B02 do banco.
