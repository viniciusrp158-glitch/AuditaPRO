# Audita PRO — Fontes, versão e cobertura

## Manifesto de fontes

Os quatro arquivos foram lidos e preservados integralmente em `fontes/`. O nome do documento da biblioteca contém v0.1, mas seu cabeçalho declara v0.2; a versão de conteúdo adotada é 0.2. O link interno que menciona outro nome de arquivo não muda esta referência.

| Código | Arquivo | Versão interna | Bytes | Linhas | SHA-256 |
|---|---|---|---:|---:|---|
| BIB | audita-planejamento-menu-biblioteca-documentos-v0.1.md | 0.2 | 18823 | 208 | `9bada6bebd541952c5640a4dfaf8b19da9bfcef7d2afc39b8271f482ad8c4dfe` |
| PER | audita-planejamento-perfis-permissoes-dashboards-v0.1.md | 0.1 | 32521 | 310 | `d710d560b54f39c91546f0e66d71f0270ee225c984e34409704506ad01faebd7` |
| PLA | audita-pro-planejamento-plano-auditoria-v0.1.md | 0.1 | 35844 | 444 | `d7726dc6d5b96d2f772a6de825a376012ed95f8728ddf6a4b369efbf28963615` |
| RDA | audita-pro-planejamento-rda-v0.1.md | 0.1 | 32524 | 380 | `7a3884ab4e0327ed82f34128783d3250a95f2e4cf052dfcd2e6047c5a2503254` |

## Cobertura

A matriz é uma transcrição rastreável por unidade textual: cada linha de conteúdo não vazia dos anexos, inclusive cada item de lista e cada linha de tabela, é preservada integralmente e recebe um bloco principal e, quando necessário, blocos complementares. Linhas com várias obrigações continuam integrais: todas devem ser verificadas, não apenas a primeira frase.

Títulos, separadores de tabela e sintaxe/linhas dos diagramas não são tratados como requisitos independentes; os títulos estão na cobertura de seções abaixo e os fluxos dos diagramas são cobertos pelas regras textuais e blocos. Contexto histórico, propostas e limites de escopo também estão preservados, sem convertê-los em funcionalidades obrigatórias novas.

A matriz não é uma alegação de que cada linha representa um requisito funcional atômico distinto. O objetivo é permitir conferir qualquer trecho original e localizar sua etapa sem perder conteúdo.

| Fonte | Unidades textuais mapeadas | Critérios originais |
|---|---:|---:|
| BIB | 112 | 13 |
| PER | 187 | 20 |
| PLA | 259 | 24 |
| RDA | 221 | 21 |
| **Total** | **779** | **78** |

Todos os 78 critérios originais estão no arquivo `03-criterios-de-aceite.md`, sem renumeração. A coluna situação observada representa a avaliação inicial do bloco, não uma certificação de cada frase como implementada. O detalhamento de evidências por requisito será preenchido durante execução.

## Cobertura das seções

| Fonte | Seção | Linha original | Etapas principais |
|---|---|---:|---|
| BIB | 1. Objetivo e base da proposta | 16 | B01 |
| BIB | 2. Alterações no menu lateral | 28 | B04 |
| BIB | 3. Página inicial da biblioteca | 51 | B05 B04 |
| BIB | 4. Perfis e permissões | 63 | B02 B05 |
| BIB | 5. Cadastro e manutenção dos documentos | 93 | B05 B03 |
| BIB | 6. Separação do histórico de modificações | 122 | B05 B04 |
| BIB | 7. Exemplo de organização da tela | 136 | B05 |
| BIB | 8. Critérios de aceite da implementação futura | 154 | B14 |
| BIB | 9. Decisões para validação | 176 | B01 |
| BIB | Histórico do planejamento | 203 | B01 |
| PER | 1. Objetivo e relação com os planejamentos anteriores | 9 | B01 |
| PER | 2. Perfis definitivos | 26 | B02 |
| PER | 3. Vínculos que determinam o acesso | 39 | B02 |
| PER | 4. Visão das abas por perfil | 75 | B02 B04 |
| PER | 5. Permissões dentro de Auditorias | 89 | B02 B06 B11 |
| PER | 6. Disponibilização do planejamento e dos relatórios | 120 | B09 B12 B02 |
| PER | 7. Dashboards por perfil | 134 | B13 |
| PER | 8. Definição dos indicadores e gráficos | 205 | B03 B13 |
| PER | 9. Isolamento e segurança dos dados | 226 | B02 B14 |
| PER | 10. Etapas propostas para implementação | 240 | B01 B14 B15 |
| PER | 11. Critérios de aceite | 258 | B14 |
| PER | 12. Decisões propostas para validação | 285 | B01 |
| PER | 13. Histórico do planejamento | 306 | B01 |
| PLA | 1. Objetivo e contexto | 7 | B00 B01 |
| PLA | 2. Fluxo proposto | 22 | B06 B07 B09 B10 |
| PLA | 3. Reutilização da estrutura atual | 48 | B00 B01 |
| PLA | 4. Identificação e códigos | 64 | B03 B06 |
| PLA | 5. Formulário do plano | 87 | B06 |
| PLA | 6. Auditoria integrada e checklist | 122 | B06 B03 |
| PLA | 7. Cronograma editável | 140 | B07 |
| PLA | 8. Equipe, responsabilidade e autorização | 173 | B02 B06 |
| PLA | 9. FPA — preparação necessária ao plano | 188 | B06 |
| PLA | 10. Revisão, validação e emissão | 213 | B09 B08 |
| PLA | 11. Revisões e preservação histórica | 255 | B09 B08 |
| PLA | 12. Execução e ligação com o RDA | 269 | B07 B10 B11 |
| PLA | 13. Disponibilização e notificações | 298 | B09 B02 B12 |
| PLA | 14. PDF oficial | 312 | B09 B08 |
| PLA | 15. Plano técnico de aplicação futura | 337 | B01 B06 B07 B08 B09 |
| PLA | 16. Etapas após aprovação | 367 | B01 B14 B15 |
| PLA | 17. Critérios de aceite | 378 | B14 |
| PLA | 18. Decisões propostas para validação | 407 | B01 |
| PLA | Anexo A — Notas obrigatórias da última página | 418 | B09 |
| RDA | 1. Contexto e objetivo | 8 | B00 B01 |
| RDA | 2. Decisões centrais | 24 | B01 B11 B12 |
| RDA | 3. O que será aproveitado e o que muda | 37 | B00 B01 |
| RDA | 4. Identificação e controle documental | 55 | B03 B11 |
| RDA | 5. Estrutura oficial do RDA | 69 | B10 |
| RDA | 6. Indicadores: definição única | 96 | B03 B10 |
| RDA | 7. Cronograma, desvios e trabalho restante | 140 | B07 B10 B11 |
| RDA | 8. Checklist, NC, OBS e OM | 159 | B10 |
| RDA | 9. Evidências e fotografias | 175 | B10 B12 |
| RDA | 10. Fluxo de fechamento e emissão | 189 | B11 B08 B12 |
| RDA | 11. Revisões e integridade | 240 | B11 B12 |
| RDA | 12. Consulta e permissões | 254 | B02 B12 |
| RDA | 13. Notificações e ciência | 277 | B12 |
| RDA | 14. PDF e identidade visual | 289 | B08 B12 |
| RDA | 15. Plano técnico de evolução, sem execução | 305 | B01 B03 B10 B11 B12 |
| RDA | 16. Etapas de implementação após aprovação | 333 | B01 B14 B15 |
| RDA | 17. Critérios de aceite | 344 | B14 |
| RDA | 18. Pontos destacados para sua validação | 370 | B01 |

## Evidências da análise do sistema

- Commit `main` consultado diretamente no GitHub: `0f82ba2b5414f4f4c79001650149032fd4f759e3`.
- Clone: `C:/Users/Vinicius Rocha/Documents/Codex/2026-10-05/co/work/auditapro-git`.
- Frontend: `C:/Users/Vinicius Rocha/Documents/Codex/2026-10-05/co/outputs`.
- Migrations locais: `outputs/audita-pro-supabase/supabase/migrations`, até `20261006212519`.
- Supabase original consultado em leitura: `zlckcpeqcxmtrgbdquee`; 52 migrations, última `20261007160236`.
- Catálogos consultados: migrations, tabelas/colunas, funções públicas/privadas pertinentes, policies e privilégios de leitura das tabelas PascalCase.
- Definições examinadas incluem `workspace_conductor`, `workspace_document_access`, `workspace_documents`, `workspace_snapshot`, `checklist_stats` e `checklist_day_stats`.
- Código examinado inclui auditorias, dashboard, biblioteca e estrutura de arquivos do aplicativo. Não foram lidas credenciais nem exportados documentos pessoais nesta análise.

### Dez migrations remotas a conciliar

1. `20261007032302_checklist_library_v1`
2. `20261007032929_checklist_execution_v1`
3. `20261007033311_checklist_validation_fixes`
4. `20261007033442_checklist_access_hardening`
5. `20261007033924_checklist_client_projection`
6. `20261007104406_checklist_complete_workflow`
7. `20261007105453_checklist_workflow_validation`
8. `20261007154734_checklist_context_alias`
9. `20261007155413_checklist_daily_contract`
10. `20261007160236_checklist_document_evidence`

## Limites e renovação do diagnóstico

A análise é um retrato de 07/10/2026. Consultas de código/catálogo não substituem testes de acesso por usuário. Não houve validação autenticada de interface, carga, restauração ou emissão neste trabalho. O inventário de processos local não pôde ser consultado; não se confirmou qual pasta está sendo servida atualmente. Alterações em outra sessão depois desta leitura exigem renovar B00 antes de editar código.

Não foi feita auditoria integral de segurança de todas as tabelas/funções. A família PascalCase tem ausência de SELECT para anon/authenticated nas consultas realizadas, mas sua origem, demais privilégios e consumidores permanecem item de B00. Nenhuma exclusão/reorganização dessa família está autorizada por este diagnóstico.

A biblioteca futura não deve publicar automaticamente os documentos corporativos mencionados como rascunhos; sua existência, localização e aprovação institucional precisam ser verificadas.
