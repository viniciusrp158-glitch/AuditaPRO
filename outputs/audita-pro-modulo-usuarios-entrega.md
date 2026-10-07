# Audita PRO — Usuários e Organizações

**Implementação:** 05/10/2026  
**Projeto Supabase:** `zlckcpeqcxmtrgbdquee`  
**Tela local:** `http://127.0.0.1:5181/audita-pro-cadastro.html`  
**Entrada:** `http://127.0.0.1:5181/audita-pro-login.html`

## Funcionalidades entregues

- Navegação permanente pelo menu lateral e logo oficial com retorno ao Dashboard.
- Área administrativa com indicadores reais, listas paginadas de usuários, organizações, documentos, solicitações de vínculo e convites.
- Filtros de usuários por nome, e-mail, CPF, organização, perfil, status e pendência; filtro de organizações por nome, CNPJ e status.
- Criação e edição de organizações, endereço, contato institucional, unidades e contatos responsáveis.
- Convite e cadastro de usuários, aproveitamento de conta existente sem alterar senha, vínculo por empresa/unidade, cargo e perfil, inativação e reativação.
- Atribuição protegida do papel global Administrador, com confirmação da senha do Administrador executor e preservação dos metadados da conta. Inativação de contas e vínculos verifica responsabilidades em auditorias e ciências pendentes.
- Primeiro acesso do próprio usuário para completar dados, solicitar vínculo e enviar documento de identificação. O Administrador aprova ou reprova com motivo obrigatório.
- Estados separados de conta, vínculo, documento e convite. O acesso operacional depende de CPF, vínculo, perfil, aprovação documental e participação na auditoria.
- Perfis iniciais: Administrador, Auditor Líder, Auditor de apoio em leitura e Participante / Auditado em leitura.
- Registro histórico da equipe e fotografia de seus nomes e papéis em novas versões finalizadas dos relatórios diários.

## Banco e segurança

Foram reaproveitadas as tabelas `user_profiles`, `organizations`, `organization_units`, `organization_memberships`, `positions`, `access_profiles`, `user_documents`, `audits`, `audit_participants`, `daily_reports` e `audit_events`. Foram acrescentadas `user_invites`, `organization_access_requests` e `audit_participant_history`.

As migrations versionadas ficam em `audita-pro-supabase/supabase/migrations/` e foram aplicadas ao projeto remoto. As policies RLS e funções de autorização foram atualizadas para os quatro perfis. O envio do documento usa a Edge Function `user-management` com validação do conteúdo do arquivo e bucket privado. O último Administrador ativo está protegido no banco.

## Como validar

1. Entre pela página de login com sua conta Administrador e abra **Usuários** no menu lateral.
2. Confira a lista inicial. O projeto tinha um Administrador ativo, uma pessoa cadastrada e nenhuma organização no momento da entrega.
3. Crie uma organização com CNPJ válido e segmento. Recarregue a página e confira a persistência.
4. Abra a organização, cadastre uma unidade e um contato; depois convide uma pessoa para o perfil desejado.
5. Entre com a conta convidada em outro navegador ou janela privada, complete CPF e envie o documento.
6. Retorne como Administrador, abra **Documentos pendentes**, visualize o arquivo e aprove ou reprove com motivo.
7. Confira a situação do vínculo na pessoa e confirme que outros usuários não recebem acesso global por cadastro público.

## Validações realizadas e limites

- As migrations constam no histórico remoto do Supabase; a Edge Function está ativa na versão 7 com validação de JWT.
- A sintaxe do JavaScript passou em `node --check`; login, cadastro, script, CSS e logo responderam HTTP 200 na visualização local.
- Não foi possível executar um ciclo completo com contas de cada perfil nesta sessão, porque isso exige credenciais e interação dos titulares. O envio real de e-mail de convite também precisa ser conferido no ambiente Auth do projeto.
- A tela de gestão e a autorização no banco estão prontas para alimentar auditorias. O Dashboard específico do Auditado e os formulários operacionais de criação de auditorias/equipe continuam como módulos posteriores já previstos no planejamento do produto.
- O aplicativo ainda depende de um servidor local em execução. Se o link parar após fechar a sessão, abra um terminal PowerShell na pasta `outputs` e execute `./iniciar-audita-pro.ps1`.
- A proteção contra senhas vazadas aparece desabilitada no aviso de segurança do Supabase Auth e deve ser ativada nas configurações do projeto antes do piloto com usuários externos.
