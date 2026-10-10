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

## Correções de erros herdados (Codex)

| ID | Arquivo | Erro | Correção |
|---|---|---|---|
| CX-01 | `audita-pro-header.js` / `audita-pro-navigation.js` | Condição de corrida: em páginas cujo script chama a sessão antes do `defer` da navegação (ex.: Usuários), o contexto era enviado antes de a navegação existir e o Administrador ficava sem os itens restritos | O cabeçalho guarda o último contexto (`AUDITA_PRO_NAV_STATE`) e a navegação o aplica ao carregar; limpo ao sair/erro |
| CX-02 | `scripts/test-b04-navigation.mjs` | Teste comparava o diff com um commit fixo e falhava com qualquer evolução legítima | Reescrito para verificar regras: itens retirados, ordem, destinos, itens restritos ocultos, módulos preservados |
| CX-03 | `audita-pro-biblioteca.html` (novo) e páginas sem `audita-pro-profile.css` | Ícone de Meu Perfil sem dimensão fora das páginas que carregam o CSS do perfil | Regra movida para `audita-pro-navigation.css` (carregado em todas as páginas) |
| CX-04 | Testes `happy-dom` | Dependência não instalável nesta sessão | `scripts/ui/happy-dom-in-chromium.mjs` executa os testes originais, sem alteração, no Chromium real |
