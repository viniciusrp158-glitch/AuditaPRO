# B04 — Navegação e Meu Perfil: incremento independente

Data: 08/10/2026. Responsável: Codex 03, com revisão final do agente principal.
Estado: **preparação e implementação parcial em branch isolada; não liberado**.

## Base e coordenação

- Atribuição atual informada pelo proprietário: B00/B01 concluídos pelo Codex 01;
  B02 em execução pelo Codex 02; B03 em execução pelo Codex 01; B04 nesta sessão.
- B04 depende diretamente de B02. B03 não é pré-requisito de B04; B05 depende dele.
- Base técnica disponível: `bee387f`, `origin/feat/checklists-v01`.
  Esta é uma base provisória para preparar o diff, **não o baseline integrado
  aprovado em B00**. O fetch e a busca de PRs não localizaram entregas B00/B01/B02
  nesta consulta. Isso não contradiz o status informado pelo proprietário.
- Branch de trabalho: `feat/b04-preparacao`. Não houve aplicação de SQL,
  publicação de frontend, modificação de permissões ou implementação de B03.
- Os comandos de execução do pacote são referência de escopo, não autorização
  para aplicar migrations concorrentes ao projeto compartilhado.

## Mudança preparada

Remover somente os links laterais “Não conformidades”, “Planos de ação” e
“Indicadores” onde presentes nas oito páginas autenticadas com navegação.
Preservar os destinos e a ordem das entradas restantes, a marca, os atalhos da
conta, notificações, formulários, scripts e módulos internos. Identificar o
elemento de navegação e o link ativo com atributos de acessibilidade.

Páginas: dashboard, auditorias, cadastro de usuários, histórico, notificações,
perfil, biblioteca de checklists e execução do checklist, em `outputs/`.

Não há nova regra de visibilidade por perfil neste incremento. A navegação
existente não constitui autorização; restrições de UI e de API precisam consumir
o contrato final de B02. Não se afirma que a base antiga já atende à nova matriz.

## Trabalho que permanece condicionado

| Item | Dependência e limite |
|---|---|
| Visibilidade de Usuários/Biblioteca e nomes dos quatro perfis | Consumir B02 e decisões registradas B01. Não deduzir autorização apenas do texto de um perfil. |
| Meu Perfil, inclusive Participante aprovado | Consumir D05/B02; preservar preenchimento e envio necessários ao onboarding. Não bloquear conta pendente nem permitir troca do próprio papel/organização. |
| “Biblioteca de documentos” como entrada principal | Definir rota de documentos corporativos com B05 e autorização D07/B02. O histórico e a biblioteca de relatórios existentes não são a biblioteca corporativa. |
| Retorno do histórico à biblioteca | Compartilhado com B05. Não substituir a listagem por uma tela vazia ou destino fictício. |
| Menu recolhido, mobile e navegação completa | Homologar na aplicação realmente servida e com os quatro perfis depois de B02. |

Os rótulos atuais “Biblioteca / histórico” e “Biblioteca de relatórios” são
preservados por enquanto. Renomeá-los para o destino futuro sem implementar esse
destino produziria uma promessa incorreta. CA-02/CA-03 não estão concluídos.

## Critérios e validação

`rastreabilidade.csv` contém as 40 linhas associadas a B04 no pacote v1.0,
com texto e status originais preservados e colunas próprias deste incremento.
Não são 40 funcionalidades independentes nem 40 critérios aprovados.

- CA-01: retirada estrutural das entradas; comportamento por perfil e tela
  pequena continua pendente de homologação.
- CA-12: teste de preservação dos demais conteúdos e arquivos de domínio;
  regressão funcional completa permanece em B14.
- CA-02/CA-03: nomenclatura e entrada corporativa pendentes conforme tabela acima.
- PER-01/PER-20: integração dos perfis e Meu Perfil pendente de B02.

Teste independente: `node scripts/test-b04-navigation.mjs`.
O teste compara o diff com a base de preparação: ausência das três entradas,
preservação de links restantes e conteúdo fora da navegação, destinos locais
existentes e ausência de alterações nos arquivos de autorização e domínio.
É uma verificação estrutural, não um teste autenticado de RLS, Storage, mobile
ou navegador. Não há conta de produção simulada nem alteração de dados.

Revisão final realizada pelo agente principal em 08/10/2026:

- `node scripts/test-b04-navigation.mjs`: aprovado nas oito páginas.
- `git diff --check`: aprovado, sem erros de whitespace.
- Diff conferido: alterações de HTML limitadas aos menus; scripts, formulários,
  marca, conteúdo de auditoria e arquivos de autorização preservados.
- O teste entregue pelo subagente foi revisado pelo principal, incluindo a
  permissão explícita para os documentos de rastreabilidade em `docs/b04/`.
- Novo fetch antes da entrega manteve as referências remotas conhecidas;
  nenhuma entrega de B01/B02 foi localizada no repositório consultado.
- Não executados: testes autenticados, viewport/mobile e regressão funcional
  completa. CA-01/CA-12 têm evidência estrutural parcial; B04 não está concluído.

## Passagem para conclusão

1. Receber baseline/commit integrado de B00, decisões D05/D07 e contratos de B01,
   e handoff testado de B02: capacidades, nomes, restrições, erros e revogação.
2. Confirmar a pasta efetivamente servida e reservar os arquivos com Codex 01/02.
   `audita-pro-auth.js`, `audita-pro-header.js` e `audita-pro-profile.js` são
   interfaces compartilhadas sensíveis; ficaram sem alteração neste incremento.
3. Reaplicar/revisar este diff sobre a base integrada; se B02 já mudou o menu,
   adaptar a remoção sem sobrescrever atributos ou regras de acesso.
4. Completar a integração B04/B05 por contrato de rota; testar login/onboarding,
   quatro perfis, navegação, conta/notificações, teclado e telas pequenas.
5. Outra sessão revisa o diff e as evidências. Codex 01/C0 integra e libera.

Reversão deste incremento: reverter somente o commit de navegação sobre a base
compatível. Não reverter políticas B02, apagar dados ou restaurar o banco.
Nenhuma URL de aplicação foi declarada validada nesta entrega parcial.
