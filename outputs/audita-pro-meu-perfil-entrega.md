# Audita PRO — Entrega da aba Meu Perfil

**Data:** 05/10/2026, horário de Brasília.  
**Situação:** implementação disponibilizada para validação do usuário.  
**Acesso local:** http://127.0.0.1:5181/audita-pro-perfil.html

## Funcionalidades

- Meu Perfil como última opção do menu lateral, com ícone de pessoa, nas páginas autenticadas existentes.
- Cinco etapas: dados pessoais, profissionais, documentos, confirmação e concluído. A conclusão operacional depende da aprovação administrativa.
- Salvamento de rascunhos, retorno entre etapas, aviso de alterações não salvas e proteção contra envio duplicado.
- Nome, CPF, e-mail autenticado somente para leitura, telefone, empresa/unidade, cargo, função, área e gestor.
- Seleção entre vínculos existentes e pesquisa limitada por nome/CNPJ para solicitar vínculo com empresa cadastrada. A solicitação não concede acesso à empresa.
- Exigências por perfil: identificação e certificado de Auditor Líder; identificação e certificado de Auditor; somente identificação para Participante/Auditado.
- Upload privado de PDF, JPEG e PNG até 10.000.000 bytes, com progresso, validação no servidor, emissão, validade ou ausência de validade, número e instituição emissora.
- Novas versões preservam arquivos e decisões anteriores. Retirada de envio para correção e reenvio em nova versão.
- Fila administrativa paginada, filtro por responsável, reatribuição com motivo, análise de cada documento, reprovação justificada e aprovação final do cadastro.
- Administrador criador do vínculo/convite como responsável inicial. Cadastros sem responsável ativo podem ser atribuídos pela administração.
- Bloqueio de autoaprovação, análise por pessoa não designada, aprovação incompleta, revisão de versão retirada e acesso a documentos de terceiros.
- Acesso operacional dependente da aprovação e da validade documental, além das regras existentes de empresa e participação na auditoria.
- Atualização posterior de telefone e dados de contato profissionais sem nova análise documental. Mudanças de identificação e documentos usam nova versão.
- Encaminhamento de cadastros pendentes para Meu Perfil e integração com a fila de Usuários.

O Administrador global continua com acesso administrativo sem depender de vínculo com empresa cliente. Para avaliar o fluxo documental, use uma conta com perfil operacional e vínculo atribuído.

## Como validar

1. Entre com sua conta Administrador e abra **Meu Perfil**, no final do menu. Confira dados pessoais e salvamento.
2. Em **Usuários**, cadastre uma organização e convide uma pessoa como Auditor Líder, Auditor ou Participante/Auditado, atribuindo cargo e organização.
3. Entre com a conta convidada em outra sessão do navegador. Complete os dados e confira os documentos exigidos pelo perfil.
4. Anexe os arquivos, revise o resumo e clique em **Enviar para validação**. A situação deve ficar aguardando análise.
5. Como Administrador criador, abra **Usuários → Validação de perfis → Abrir fila de validação**.
6. Abra o cadastro, visualize os documentos e registre uma decisão para cada um. Para reprovação, informe o motivo.
7. Confira os dados e aprove o cadastro integralmente. O titular deverá ver a etapa Concluído e acessar somente as auditorias autorizadas.
8. Valide também reprovação, correção e reenvio. Para consultar cadastros sem responsável, desmarque o filtro **Pendentes sob minha responsabilidade**.

## Arquivos principais

Criados: `audita-pro-perfil.html`, `audita-pro-profile.js`, `audita-pro-profile.css` e `supabase/functions/user-management/profile-documents.ts`.

Alterados: `audita-pro-auth.js`, `audita-pro-login.html`, `audita-pro-users.js`, `audita-pro-cadastro.html`, `audita-pro-dashboard.html`, `audita-pro-historico.html`, `audita-pro-relatorio-diario.html` e `supabase/functions/user-management/index.ts`. As cópias estáticas em `audita-pro-deploy` foram sincronizadas.

## Banco e publicação

Reutilizados: Auth, `user_profiles`, `organizations`, `organization_units`, `organization_memberships`, `positions`, `access_profiles`, `organization_access_requests`, `user_invites`, `user_documents`, `audit_events` e o bucket privado `identity-documents`.

Nova tabela: `profile_submissions`, para rascunhos e submissões versionadas, responsável designado e decisões. O vínculo recebeu dados profissionais; documentos receberam tipo ampliado, versão, metadados e validade.

Migrations aplicadas ao projeto Supabase e registradas localmente:

- `20261006003927_my_profile_workflow.sql`
- `20261006004558_my_profile_workflow_validation.sql`
- `20261006004806_my_profile_contact_and_integrity.sql`
- `20261006005347_my_profile_final_guards.sql`

As políticas de documentos e arquivos foram ajustadas ao titular e ao responsável designado. Submissões possuem RLS, e as escritas do fluxo são autorizadas no servidor. A função de registro de upload é exclusiva do serviço que valida o arquivo. As funções existentes de autorização operacional passaram a conferir a aprovação integral e a validade dos documentos.

A Edge Function `user-management` foi publicada na **versão 9**, com autenticação exigida. Não houve publicação na Vercel.

## Verificações realizadas

- Sintaxe dos scripts JavaScript modificados: aprovada.
- Página Meu Perfil respondendo HTTP 200 no servidor local.
- Testes transacionais no banco remoto: rascunho, salvamento, documentos faltantes, envio, fila do criador, aprovação integral, registro de upload com papel de serviço, isolamento de terceiros, recusa de autoaprovação, versões, retirada e recusa de decisão sobre envio retirado.
- Certificado vencido: conferido o bloqueio pela função de elegibilidade operacional.
- Privilégios: usuário autenticado não pode chamar a função reservada de registro de arquivos; usuário anônimo não pode usar o fluxo de perfil.
- Validação da função de upload em isolamento: conteúdo inválido, MIME divergente, outro titular, tamanho excedido, limite exato de 10 MB e limpeza do arquivo quando o registro é recusado.
- Testes do banco executados em transações revertidas. Não ficaram contas, empresas ou documentos fictícios no projeto.

## Limites e acompanhamento

O navegador de automação não conseguiu iniciar neste ambiente. Por isso, a aparência em desktop/celular e o ciclo real de login, upload e aprovação pela interface ainda precisam da validação manual acima. Os testes de upload usaram armazenamento simulado em isolamento; não substituem essa conferência pelo navegador.

Os avisos de segurança do Supabase foram consultados. Não houve alerta de tabela nova sem RLS; continuam avisos de descoberta do schema GraphQL por usuários autenticados e funções públicas preexistentes com privilégios elevados, que dependem das autorizações de cada objeto. Referências: [schema GraphQL autenticado](https://supabase.com/docs/guides/database/database-linter?lint=0027_pg_graphql_authenticated_table_exposed) e [funções com privilégios elevados](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable). A proteção contra senhas vazadas permanece desabilitada no Auth, conforme aviso preexistente: [configuração no Supabase](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

As notificações desta entrega são a fila administrativa e os estados/motivos em Meu Perfil. E-mails automáticos, lembretes e registro profissional por cargo continuam como evoluções, conforme o planejamento aprovado. A política completa de descarte/retensão permanece uma definição do produto; esta entrega preserva as versões e não implementa exclusão automática.
