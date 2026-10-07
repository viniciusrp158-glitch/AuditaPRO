# Audita PRO — backend MVP no Supabase

Este pacote contém migrações para a fundação de empresas/usuários e para o fluxo MVP de auditorias, checklists, cronograma, evidências, não conformidades, planos de ação e relatórios diários com confirmação de ciência.

As migrações listadas abaixo foram aplicadas ao projeto de desenvolvimento **AuditaPRO** (`zlckcpeqcxmtrgbdquee`) em 05/10/2026. As duas primeiras foram aplicadas anteriormente pelo CLI; as demais foram aplicadas pela conexão Supabase nesta sessão. Os nomes locais agora correspondem às versões registradas remotamente.

## Migrações

- `20261005000100_foundation.sql`: organizações/unidades, perfis de usuário, cargos, permissões editáveis, documentos de competência, eventos de auditoria e bucket privado de identificação.
- `20261005000200_audit_domain.sql`: requisitos/checklists versionados, auditorias e participantes, cronograma e itens remanejados, avaliações, não conformidades, planos de ação, evidências, relatórios diários, versões imutáveis, signatários, confirmação com data/hora e buckets privados.
- `20261005203144_audit_event_before_after.sql`: snapshots anteriores/novos dos campos seguros em eventos de auditoria, cobertura de planos/permissões/ciência/arquivos e leitura administrativa. Textos livres ficam representados por SHA-256 e tamanho para evitar copiar conteúdo potencialmente sensível aos logs.
- `20261005203207_dashboard_data_extensions.sql`: dados adicionais de empresas e relatórios finais.
- `20261005203219_dashboard_rls_hardening.sql`: políticas de acesso do Dashboard e relatórios finais.
- `20261005203230_dashboard_admin_queries.sql`: consultas agregadas do Dashboard.
- `20261005203244_users_foundation.sql`: CPF/CNPJ válidos, contas e vínculos, convites, perfis, documentação e histórico de participantes.
- `20261005203258_users_security.sql`: autorização dos quatro perfis, primeiro acesso restrito, upload protegido e consultas mínimas de onboarding/equipe.
- `20261005204022_users_requests_and_units.sql`: solicitação de vínculo pelo cadastro público e proteção de unidades inativas.
- `20261005204509_users_reporting_integration.sql`: contagens de vínculos por organização e fotografia da equipe na versão finalizada do relatório diário.
- `20261005204729_users_report_access.sql`: confirmação de ciência pela função protegida e leitura de relatórios publicados conforme o perfil.
- `20261005204832_users_lookup_index.sql`: índice para localizar conta existente ao enviar convite.
- `20261005205052_users_invite_recovery.sql`: histórico e recuperação de convite cujo envio falhou.
- `20261005205257_users_last_admin_guard.sql`: proteção transacional do último Administrador ativo.
- `20261005205505_users_onboarding_integrity.sql`: nome obrigatório e prevenção de envios/solicitações pendentes duplicados.
- `20261005205735_users_organization_contacts.sql`: e-mail e telefone institucionais opcionais.
- `20261005210505_users_inactivation_dependencies.sql`: impede inativar conta com liderança, participação ou ciência pendente.
- `20261005210550_users_dependency_summary.sql`: resume as responsabilidades pendentes na tela do usuário.
- `20261005210710_users_membership_dependencies.sql`: impede inativar vínculo com participação ou ciência pendente.

A Edge Function `user-management` está publicada com validação de JWT. Ela executa convite, atualização de conta, papel global, reenvio, preenchimento do próprio CPF e upload de identificação com validação do arquivo. A chave privilegiada fica no servidor, fora dos arquivos do navegador.

## Evolução posterior pelo CLI

Use o projeto Supabase de desenvolvimento e nunca cole token ou senha em chat, código ou arquivo. Gere um Personal Access Token no painel e informe-o apenas no prompt seguro do `supabase login`. Informe a senha do banco somente quando o CLI pedir no terminal.

Na pasta deste pacote:

    supabase login
    supabase link --project-ref SEU_PROJECT_REF
    supabase db push --dry-run
    supabase db push

Revise a lista do `--dry-run` e confirme que o Project Reference é o projeto de desenvolvimento correto antes do `db push`. O CLI registra as versões no histórico de migrações.

## Observações operacionais

- `finalize_daily_report(uuid)` congela uma versão do conteúdo e gera confirmações pendentes para os signatários ativos definidos na auditoria.
- `acknowledge_report(uuid)` registra usuário autenticado e horário do servidor. A confirmação na plataforma é ciência; assinatura legal continua sendo feita externamente via GOV e pode ser anexada ao relatório.
- A tabela `notification_outbox` prepara lembretes no envio, +24 h e +48 h. Um worker/Edge Function e um provedor de e-mail ainda precisam ser configurados para enviar e-mails e notificações em produção.
- O Administrador global usa `app_metadata.platform_role=admin`; o cadastro público não pode atribuir esse papel. A tela de gestão oferece atribuição protegida pelo backend para Administradores existentes.
- Os checklists normativos não foram carregados. Os requisitos fornecidos pelo proprietário do produto devem ser cadastrados, revisados e publicados como revisões.
- Antes do piloto com dados reais, valide a matriz de acesso com contas distintas de Administrador, Auditor Líder, Auditor e Auditado, incluindo tentativas diretas à API. Confira também os e-mails transacionais e redirecionamentos de convite do Supabase Auth.
- Processamento das notificações, geração final de PDF e operação do GOV seguem como módulos posteriores.
- Planeje a política de retenção de cinco anos e seus processos de exclusão/exportação antes de receber dados reais.
