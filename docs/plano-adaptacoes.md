# Registro de adaptações do plano mestre e correções

Autorização do proprietário (10/10/2026, 13h31): corrigir erros do Codex e ajustar o plano mestre quando necessário.
O texto original do plano (`docs/plano-execucao-v1.0/`), os 78 critérios e as 779 linhas da matriz **não são editados**;
cada mudança é registrada aqui com motivo e impacto.

## Adaptações do plano

| ID | Data | Bloco | Original | Adaptação | Motivo |
|---|---|---|---|---|---|
| AD-01 | 10/10 | B00/B14 | Testes com contas reais "em ambiente adequado" | Banco de testes local recriado a partir das mesmas migrations da produção (`scripts/localdb/`), com dados de teste identificados (2 organizações, Admin ×2, Líder ×3, Auditor, Participante ×2, pendente, inativo) | Testar autorização real sem tocar dados de produção; a produção recebe só migrations já aprovadas localmente |
| AD-02 | 10/10 | B04/B05 | "Histórico do sistema como acesso secundário" | A página `audita-pro-historico.html` foi preservada (URL antiga válida) e passou a ser a área "Histórico de modificações do sistema", aberta pelo botão da biblioteca, com "Voltar à biblioteca" e restrita ao Administrador (PC-03) | RS-07/CA-07/CA-08 sem criar tela duplicada |
| AD-03 | 10/10 | B05 | Biblioteca de relatórios de auditoria estava dentro do histórico | Os relatórios de auditoria foram para uma aba própria "Relatórios de auditorias" na Biblioteca, carregada só quando escolhida; a entrada padrão é sempre "Documentos corporativos" | Separar biblioteca corporativa, relatórios e histórico (regra 6 do prompt) sem perder o acesso existente |
| AD-04 | 10/10 | B05 | — | Migrations divididas em partes de até ~8 KB | Limite do conector Supabase para aplicação; sem efeito funcional |
| AD-05 | 10/10 | B05 | — | Funções de comando separadas: leitura (`corporate_library`), cadastro/revisões (`corporate_library_manage`) e ciclo de arquivos/publicação (`corporate_library_lifecycle`), todas revalidando o Administrador | Consequência de AD-04; reforça a separação de responsabilidades |
| AD-06 | 10/10 | B04 | Dashboard atual redireciona não administradores para Auditorias | Mantido até o B13 (quatro dashboards) | Não antecipar escopo de B13 |
| AD-07 | 10/10 | B06 | Proposta Codex: cabeçalho editável só antes da 1ª publicação | Editável em rascunho e em "revisão em elaboração" (planned/in_progress); a versão publicada fica congelada em `audit_plan_versions` (B09) | Plano §10/§11: revisão em elaboração com a anterior vigente |
| AD-08 | 10/10 | B06 | Coluna legada `purpose` obrigatória | Rascunhos novos gravam "A definir"; o campo oficial passa a ser `evaluation_type` (Inicial…Outra). Valores legados ("Interna") preservados, sem conversão | §5 "Vocabulário consolidado" |
| AD-09 | 10/10 | B06 | Criação exigia título, escopo e modelo de checklist | `create_draft`: só cliente obrigatório (PA-04), idempotente; modelos escolhidos depois em "Confirmar checklists" (composição versionada existente) | PA-04 |
| AD-10 | 10/10 | B06 | FPA (Codex: regras em JS, sem persistência) | FPA persistente: `private.audit_fpa*`, bucket `audit-fpa` (PDF/DOCX/XLSX), Edge Function `audit-fpa-files`; versões e eventos imutáveis | PA-11/12, D09 |
| AD-11 | 10/10 | B05/B06 | — | O limite do conector é a aprovação de comandos `delete`, não o tamanho; partes com `delete` aguardam aprovação do proprietário | Diagnóstico corrigido |
| AD-12 | 10/10 | B07 | Múltiplos auditores por linha (legado: um só `assignee_membership_id`) | Auditores em `schedule_items.assignee_ids uuid[]`, com backfill a partir de `assignee_membership_id` e validação contra a equipe no servidor | Evita `delete` em cada salvamento (aprovação do conector) e mantém a linha como uma unidade versionável |
| AD-13 | 10/10 | B07/B09 | Editor salva e publica o cronograma | B07 salva só o rascunho (`audits.plan_draft`, formato canônico). A materialização em `schedule_items`/`schedule_requirements` e o snapshot ficam na publicação do B09, que vai substituir o `plan_publish` legado (ele descarta os campos novos e sorteia IDs) | Publicação única e auditável; não renumera dias iniciados |
| AD-14 | 10/10 | B07 | Transferência do restante | Continuidade por `schedule_items.continuation_of` (cadeia origem→destino) + `schedule_movements` (antes/depois, motivo, autor); `record_outcome` aceita só parcial/não realizada | PA-17/RDA-08 sem conclusão fictícia |

## Correções de erros herdados (Codex)

| ID | Arquivo | Erro | Correção |
|---|---|---|---|
| CX-01 | `audita-pro-header.js` / `audita-pro-navigation.js` | Condição de corrida: em páginas cujo script chama a sessão antes do `defer` da navegação (ex.: Usuários), o contexto era enviado antes de a navegação existir e o Administrador ficava sem os itens restritos | O cabeçalho guarda o último contexto (`AUDITA_PRO_NAV_STATE`) e a navegação o aplica ao carregar; limpo ao sair/erro |
| CX-02 | `scripts/test-b04-navigation.mjs` | Teste comparava o diff com um commit fixo e falhava com qualquer evolução legítima | Reescrito para verificar regras: itens retirados, ordem, destinos, itens restritos ocultos, módulos preservados |
| CX-03 | `audita-pro-biblioteca.html` (novo) e páginas sem `audita-pro-profile.css` | Ícone de Meu Perfil sem dimensão fora das páginas que carregam o CSS do perfil | Regra movida para `audita-pro-navigation.css` (carregado em todas as páginas) |
| CX-04 | Testes `happy-dom` | Dependência não instalável nesta sessão | `scripts/ui/happy-dom-in-chromium.mjs` executa os testes originais, sem alteração, no Chromium real |
| CX-05 | `docs/b06/propostas/identificacao-v1.sql` | Proposta não cobria rascunho incompleto (criação ainda exigia título/escopo) nem FPA persistente | Implementados `create_draft` e FPA (AD-09/AD-10); o restante da proposta foi adotado |
