# Audita PRO — Entrega de notificações e menu da conta

**Data:** 06/10/2026. Implementação do planejamento aprovado, disponível para validação pelo usuário.

## Funcionalidades entregues

- Cabeçalho compartilhado nas páginas autenticadas, com sino, contador de não lidas, iniciais, nome e perfil autorizado.
- Menu com Meu Perfil e Sair; Configurações e Ajuda identificadas como **Em breve**.
- Painel de notificações e central paginada, com filtros Todas, Não lidas e Ação pendente.
- Marcação individual ou conjunta como lida. Ler uma mensagem não conclui a tarefa.
- Avisos de envio, reenvio, atribuição de responsável, falta de responsável, aprovação, solicitação de correção e retirada de cadastro.
- Abertura da submissão e versão correspondentes, com nova verificação de autorização no servidor.
- Atualização ao abrir o sino e consulta periódica a cada 30 segundos enquanto a página está visível.
- Estados de carregamento, lista vazia e falha recuperável; layout adaptado a telas pequenas e controles por teclado.

**O aviso é gerado ao clicar em Enviar para validação.** Apenas anexar um documento salva o rascunho e não envia a demanda ao administrador. O titular recebe orientação na própria tela.

## Backend e segurança

As migrations foram aplicadas ao projeto Supabase conectado `zlckcpeqcxmtrgbdquee`:

1. `20261006100935_in_app_notifications.sql`: caixa individual, índices, RLS, comandos e integração transacional com o fluxo de Meu Perfil.
2. `20261006101448_notification_assignment_integrity.sql`: controle de revisão da responsabilidade, evitando que avisos antigos voltem a exigir ação após reatribuições.

Nova tabela: `public.in_app_notifications`. A tabela `profile_submissions` ganhou `notification_revision`. Foram reutilizados Auth, `user_profiles`, vínculos e permissões existentes. `notification_outbox`, já vinculada aos relatórios, foi preservada.

Cada destinatário consulta apenas seus avisos. Escritas são controladas por comandos autorizados no servidor. As mensagens não contêm documentos, CPF, senhas ou tokens. Avisos administrativos deixam de ser acessíveis quando o destinatário perde o perfil correspondente. A troca de conta limpa o estado local.

## Arquivos da aplicação

Criados: `audita-pro-header.js`, `audita-pro-header.css`, `audita-pro-notificacoes.html` e `audita-pro-notifications-page.js`.

Integrados: `audita-pro-auth.js`, `audita-pro-profile.js`, `audita-pro-dashboard.js` e as páginas de Dashboard, Usuários, Meu Perfil, Biblioteca e Relatório Diário. A cópia estática em `audita-pro-deploy` acompanha as alterações; isso não representa publicação no Vercel.

## Verificações realizadas

- Teste transacional no banco conectado, encerrado com ROLLBACK: envio, deduplicação, leitura independente da pendência, isolamento entre destinatários, bloqueio de escrita forjada, reatribuição, correção, reenvio, retirada, responsável inativo, aprovação e leitura conjunta.
- Verificação no Chrome com sessões e respostas simuladas exclusivamente no teste: cabeçalho, identificação, menu, Escape, sino, leitura, central, filtros e largura de celular. A aplicação não contém dados fictícios introduzidos por este teste.
- Revisão visual das capturas de desktop e celular e verificação de sintaxe dos scripts.
- O percurso completo com as contas reais do usuário fica disponível para a validação abaixo; o teste de navegador não substitui essa validação.

O diagnóstico de segurança do Supabase mantém alertas de descoberta de schema GraphQL por usuários autenticados, incluindo a nova tabela protegida por RLS; funções SECURITY DEFINER públicas preexistentes; e proteção contra senhas vazadas desabilitada. Esses alertas não equivalem a acesso irrestrito aos registros. Referências: [descoberta de schema](https://supabase.com/docs/guides/database/database-linter?lint=0027_pg_graphql_authenticated_table_exposed), [funções privilegiadas](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) e [proteção de senhas](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

## Como validar com suas contas

1. Abra o aplicativo como participante, complete Meu Perfil, anexe os documentos e clique em **Enviar para validação**.
2. Em outro navegador ou sessão, entre como administrador responsável pelo cadastro.
3. Abra o sino. O aviso deve aparecer ao atualizar ou em até um ciclo de consulta, com a janela ativa.
4. Clique em **Analisar cadastro** e confira titular e documentos.
5. Marque um aviso como lido e confirme que a tarefa continua em **Ação pendente** enquanto a análise não for concluída.
6. Conclua a aprovação ou solicite correção. No participante, confira o resultado no sino e abra Meu Perfil pelo aviso.
7. Abra **Ver todas as notificações**, experimente os filtros e o menu da conta.

Se o cadastro não tiver responsável ativo, os administradores globais ativos recebem a pendência de atribuição. Resultados antigos já concluídos não foram enviados retroativamente. Rascunhos não geram notificações.

## Limites deste incremento

Notificações somente dentro do aplicativo. E-mail, push, WhatsApp, lembretes automáticos e eventos de outros módulos ficam para evoluções posteriores, conforme o planejamento. Configurações e Ajuda ainda não possuem módulos funcionais. Não foi criada rotina de exclusão automática do histórico.
