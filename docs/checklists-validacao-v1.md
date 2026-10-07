# Audita PRO — entrega de checklists, incremento 1

Registro histórico do primeiro incremento. Para a implementação atual e a matriz
CHK-01 a CHK-28, consulte [Validação v2](checklists-validacao-v2.md).

Data: 07/10/2026. Base do repositório: 0f82ba2.

## Implementado

- Biblioteca administrativa: código permanente CHK, categorias, filtros, cliente
  exclusivo, seções, requisitos e múltiplas perguntas com IDs estáveis.
- Rascunho, publicação imutável, nova revisão, duplicação e arquivamento.
- Composição de revisões publicadas, com restrição de cliente no servidor.
- Seleção confirmada pelo condutor antes da publicação do plano.
- Execução em tela própria, paginação, resultado separado de conclusão, amostragem,
  notas internas, autosave, revisão otimista e repetição idempotente.
- NC/OBS/OM e complementos vinculados à avaliação; NC cria o plano de ação.
- Upload com legenda e opção de inclusão no RDA; proteção contra repetição de upload.
- Progresso por pergunta e processo, incluindo N/A concluído; contagem separada de requisitos.
- Snapshot diário com avaliações concluídas, amostragem e constatações, sem notas internas.
- RLS e comandos autorizados para equipe interna; projeção limitada para cliente.

## Validação executada

`scripts/test-checklist-library.sql` e `scripts/test-checklist-execution.sql`
executados no Supabase com rollback: publicação, imutabilidade, duplicação,
três perguntas no mesmo requisito, confirmação de modelos, plano e execução,
idempotência, conflito de revisão, validação de amostragem, NC obrigatória,
N/A, complemento, progresso, usuário sem acesso, RLS, fechamento diário,
exclusão de notas internas do snapshot e bloqueio de edição após encerramento.

`scripts/test-checklist-ui.mjs`: DOM simulado com happy-dom, editor hierárquico
preservando perguntas/configurações e fluxo de rascunho/conclusão.
Executar com `npm install --prefix scripts && npm test --prefix scripts`.
Os testes de DOM usam RPC simulado; não substituem teste autenticado no navegador.
Todos os JavaScripts alterados passaram por checagem de sintaxe.

## Limites e próximos incrementos

- O cronograma ainda seleciona requisitos e inclui todas as perguntas ativas;
  seleção/exclusão individual de perguntas com motivo e escopo independente pendentes.
- Pergunta complementar existe; promoção para uma futura revisão da biblioteca pendente.
- Filtros avançados por autor/NC/dia e carregamento gradual do construtor pendentes.
- Vínculo de evidência existente tem comando no servidor, mas ainda não tem interface.
- Histórico dedicado das respostas complementares e edição de constatações pendentes.
- Fotografias não são incorporadas visualmente ao PDF; metadados selecionados
  são preservados no snapshot.
- A matriz completa CHK-01 a CHK-28 não foi homologada. Permanecem testes de
  duas organizações exclusivas, apoio/condutor/cliente real, dois navegadores,
  falhas de rede em upload e PDFs com dados reais.
- Migração de dados legados não foi exercitada com produção populada: não havia
  auditorias/modelos/avaliações no inventário inicial.

## Roteiro para homologação

1. Entrar com a conta administrativa existente.
2. Em Auditorias, abrir Checklists, cadastrar um critério e criar um modelo.
3. Adicionar seção, requisito e perguntas; salvar e publicar a revisão.
4. Criar auditoria, definir condutor, confirmar os modelos e configurar o plano.
5. Publicar e iniciar auditoria/dia/atividade conforme o fluxo existente.
6. Avaliar perguntas, registrar amostragem e constatações e concluir cada avaliação.
7. Concluir atividade e dia; conferir o relatório e a ausência de notas internas.

A hospedagem de validação usa o banco real do projeto. Registros criados no teste
manual serão persistentes; prefira cliente e auditoria identificados como teste.
