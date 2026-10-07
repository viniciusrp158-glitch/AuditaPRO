# Audita PRO — planejamento e checklists v0.1

Atualização de 07/10/2026, após leitura dos dois anexos e da imagem do menu.
Este documento substitui a lista de pendências do incremento 1. Distingue
implementação, testes automatizados e homologação visual pelo proprietário.

## Fluxo entregue

- **Auditorias** abre a lista real de auditorias, incluindo rascunhos. O antigo
  relatório demonstrativo ACME foi retirado desse caminho; seu endereço redireciona
  para a lista. Relatórios reais continuam vinculados à respectiva auditoria.
- Administrador cria auditorias e mantém a Biblioteca de Checklists. Auditor Líder
  com vínculo ativo e perfil habilitado cria e conduz auditorias da organização
  autorizada, sem aprovação administrativa a cada auditoria. As regras existentes
  de habilitação da conta e de isolamento empresarial foram preservadas.
- Biblioteca genérica por critério/edição, seção, requisito e pergunta: editor em
  tabela, inserção acima/abaixo, ordenação, duplicação, revisões, composição integrada,
  modelos exclusivos, arquivamento e carregamento de seções sob demanda.
- Execução com filtros, páginas, amostragem, conclusão explícita, autosave serializado,
  conflito recuperável, NC/OBS/OM, complementos, histórico e vínculos de evidências.
- Inclusão/antecipação e retirada de perguntas com motivo; complemento permanece
  aprofundamento até conversão explícita em item independente. Administração pode
  incorporar texto revisado à próxima revisão da biblioteca, sem respostas de cliente.
- Arquivos múltiplos com progresso de envio, metadados, seleção para RDA, idempotência
  e pendências de upload. Reutilização preserva a origem. Documento publicado protege
  seus arquivos contra remoção e autoriza ao cliente somente os arquivos selecionados.
- Indicadores por pergunta/processo, com N/A concluído incluído; requisitos aparecem
  separadamente. RDA usa estatística diária e snapshot; consolidado usa a última
  avaliação por unidade, sem somar repetidamente os dias. PDF inclui fotos selecionadas.

## Evidência de validação

Os sete scripts SQL foram executados no Supabase em transações com rollback:
`test-checklist-library.sql`, `test-checklist-execution.sql`, `test-checklist-v2.sql`,
`test-checklist-permissions.sql`, `test-checklist-continuity.sql`,
`test-checklist-composition.sql` e `test-checklist-documents.sql`.
Não permaneceram organizações, usuários, auditorias ou evidências fictícias desses testes.

Os três testes JavaScript passaram com `npm test --prefix scripts`:
`test-checklist-ui.mjs`, `test-checklist-ui-resilience.mjs`, `test-edge-evidence.mjs`.
O DOM é simulado; Storage e autenticação do teste Edge são simulados. Os testes SQL
exercitam as funções instaladas com identidades sintéticas e verificações de RLS.

| Critério | Implementação e verificação |
|---|---|
| CHK-01 | Criação/publicação administrativa genérica; SQL library e UI |
| CHK-02 | Três perguntas no mesmo requisito com IDs próprios; SQL library/execution |
| CHK-03 | Mestre separado dos registros de execução; projeção explícita ao incorporar |
| CHK-04 | Nova revisão não altera a auditoria anterior; SQL continuity |
| CHK-05 | Duplicação independente e arquivo preservando vínculos; library/composition |
| CHK-06 | Exclusivo de outra empresa oculto e recusado por API; permissions |
| CHK-07 | Composição herda critérios sem fundir referências iguais; composition |
| CHK-08 | Ausência de modelo mostra pendência; nenhum conteúdo ISO fictício |
| CHK-09 | Rascunho não conta como concluído; execution/continuity |
| CHK-10 | N/A validado conforme configuração e justificativa; execução no servidor |
| CHK-11 | Amostragem Sim sem descrição bloqueia conclusão; execution |
| CHK-12 | Texto/arquivo vinculado a avaliação, autor e dia; execution/documents |
| CHK-13 | MIME/tamanho, falha e repetição; Edge simulado e upload pendente em v2 |
| CHK-14 | NC/OBS/OM e ligações; execution/v2; notas ausentes nos documentos |
| CHK-15 | Falha mantém texto e operação para nova tentativa; UI resilience |
| CHK-16 | Revisão otimista e duas sessões simuladas; SQL execution e UI resilience |
| CHK-17 | Apoio/cliente não gravam; permissions |
| CHK-18 | Projeção cliente sem notas, arquivo interno recusado; permissions/documents |
| CHK-19 | Complemento e resposta preservam mestre/denominador; v2 |
| CHK-20 | Incorporação exige revisão de conteúdo e cria rascunho futuro; v2 |
| CHK-21 | Mesma pergunta em dois processos mantém duas unidades; continuity |
| CHK-22 | Repetição e múltiplos arquivos não criam perguntas; execution/documents |
| CHK-23 | Alteração de escopo com contexto, motivo e histórico; v2 |
| CHK-24 | Pendências de salvamento/upload bloqueiam conclusão/saída; v2/UI resilience |
| CHK-25 | RDA anterior preservado, consolidado sem duplicação; continuity |
| CHK-26 | Seções sob demanda e 55 perguntas paginadas; UI resilience. Tela menor requer homologação visual |
| CHK-27 | Snapshot com autor/amostra/fotos selecionadas; documents/continuity. PDF visual requer homologação |
| CHK-28 | Migrações aditivas preservam referências e snapshots. Não havia dados legados populados para exercitar conversão |

Esta matriz não equivale a homologação integral dos 28 critérios: alguns foram
verificados por código/DOM simulado; os limites abaixo continuam explícitos.

## Limites da validação

- Não foi possível realizar a sessão visual autenticada em navegador real neste
  ambiente. Testar disposição em celular, contas reais de cada perfil, envio real
  de fotos ao Storage e aparência do PDF antes de usar em uma auditoria oficial.
- O inventário inicial tinha zero auditorias/modelos/avaliações. A preservação de
  versões geradas foi testada; migração sobre uma base legada populada não foi.
- Permanecem fora do escopo documentado: funcionamento offline/PWA, colunas
  arbitrárias, fusão semântica automática de normas, escrita pelo apoio e redesign
  completo do relatório final. O consolidado reutiliza os dados registrados.

## Segurança e implantação

Cinco migrações desta atualização foram aplicadas após as cinco do incremento 1;
função Edge `audit-evidence` versão 3 publicada. Funções privadas validam sessão,
papel e organização. Novas tabelas de escrita via RPC têm RLS e acesso direto
revogado para anon/authenticated. Nenhuma chave administrativa foi inserida no cliente.

O advisor de segurança ainda apresenta avisos: tabelas RLS sem políticas (acesso
direto negado por desenho), objetos existentes visíveis no esquema GraphQL, sete
funções públicas SECURITY DEFINER anteriores e proteção de senhas vazadas desativada.
Esses avisos não foram apresentados como uma auditoria de segurança global aprovada.
Referências para revisão:

- [RLS sem políticas](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
- [Visibilidade GraphQL](https://supabase.com/docs/guides/database/database-linter?lint=0027_pg_graphql_authenticated_table_exposed)
- [Funções privilegiadas](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
- [Proteção de senhas](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)

## Roteiro de validação pelo proprietário

1. Entrar como administrador, abrir Auditorias e conferir a lista e Nova auditoria.
2. Em Biblioteca de Checklists, criar critério/modelo com três perguntas, publicar
   e conferir histórico; criar modelo integrado quando aplicável.
3. Entrar como Auditor Líder habilitado e criar auditoria para sua organização.
   Confirmar modelos, preencher equipe/plano e publicar sem aprovação por auditoria.
4. Iniciar dia/atividade, preencher perguntas e amostras, enviar fotos, vincular
   NC/OBS/OM, incluir complemento e concluir avaliações.
5. Encerrar dia, conferir RDA e PDF com fotos selecionadas. Reavaliar no dia seguinte
   e confirmar que o relatório anterior e a quantidade de unidades foram preservados.
6. Conferir apoio em consulta e cliente somente nos documentos autorizados.

A hospedagem de validação utiliza o banco real. Os registros do teste manual são
persistentes; identifique cliente e auditoria de teste de forma clara.
