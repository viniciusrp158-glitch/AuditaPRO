# B08 — diagnóstico local para emissão compartilhada de PDF

## Escopo e limite da leitura

Este diagnóstico prepara o B08 a partir do código e das migrations presentes neste checkout. Ele **não é inventário do banco Supabase remoto** e não deve ser usado para afirmar que o schema hoje implantado coincide com esta história local. A própria migration antiga do Dashboard registra que a CLI não estava disponível e que seria necessário comparar a história remota antes de aplicar mudanças (`outputs/audita-pro-supabase/supabase/migrations/20261005203207_dashboard_data_extensions.sql:1-3`). Assim, referências a tabelas, funções e policies abaixo descrevem peças locais históricas, inclusive bases B02/B03, que precisam ser confirmadas pelo inventário remoto antes de uma migration B08.

O plano local do RDA também se declara proposta sem execução (`outputs/audita-pro-planejamento-rda-v0.1.md:1-6`) e explicita que não houve nova inspeção remota (`outputs/audita-pro-planejamento-rda-v0.1.md:16-22`). Ele é a melhor especificação local para orientar B08, não evidência de implantação.

### Evidência remota recebida do inventário do bloco pai (09/10/2026)

O inventário remoto executado pelo bloco pai, e não por esta análise local, confirmou `daily_report_versions`, `audit_final_report_versions` e `audit_minutes_versions` com `report_id`, `version_number`, `content jsonb`, `checksum`, `frozen_at`, `created_by` e `revision_label`. `audit_plan_versions` apareceu com conteúdo, motivo, autoria e data, mas sem coluna de checksum observada. Essa consulta confirma a presença dos campos, mas não demonstra o algoritmo atualmente usado para preencher `checksum`, nem que todos os registros o obedecem; SHA-256 abaixo é evidência apenas da função local histórica.

O mesmo inventário confirmou `audit_final_report_files.version_id` e a ausência de `version_id` em `report_external_files`. Os buckets observados eram privados: `audit-reports`, somente PDF e limite de 20 MiB; `audit-evidence-workspace`, 10 MiB; `audit-evidence`, 20 MiB e incluindo WebP; além de `identity-documents`, que é de documentos pessoais e não deve ser reutilizado pelo emissor. Nenhuma tabela correspondeu ao filtro nominal de emissão/render/job. Essa última evidência é **limitada ao filtro por nomes** e não prova ausência semântica de todo mecanismo equivalente em funções, triggers ou tabelas com outro nome.

## Conclusão técnica

Há uma base reaproveitável para um emissor compartilhado: o domínio já sabe montar uma projeção documental JSON, congelar versões aprovadas com SHA-256, autorizar documentos e evidências, selecionar anexos, usar buckets privados e notificar destinatários. Falta, porém, a própria emissão persistente e comum. No fluxo atual do workspace, aprovação significa congelar **JSON** e liberar o documento; o PDF é recriado no navegador em cada download. Não foi localizado neste checkout worker/Edge Function de renderização, estado técnico de emissão, arquivo PDF associado a cada versão, hash/tamanho do binário nem publicação condicionada ao upload verificado.

A separação é essencial:

- as linhas de versão atuais são snapshots imutáveis do **conteúdo JSON aprovado**;
- o arquivo produzido por `jsPDF` ou pela impressão do navegador é efêmero e pode variar com navegador, versão da biblioteca, fonte disponível, timezone/formatação e disponibilidade das imagens;
- os metadados de fotos são congelados no JSON, mas os bytes são buscados mais tarde no caminho vivo da evidência por URL assinada. Portanto, hoje uma versão não prova que os mesmos bytes fotográficos serão incorporados numa geração futura.

O B08 deve criar um contrato único de emissão no servidor, consumido pelo RDA e reutilizável por relatório final, ata e plano, sem misturar os contratos editoriais desses documentos.

## Peças locais que podem ser reutilizadas

| Peça | Evidência local | Reuso no emissor |
|---|---|---|
| Projeção documental | `private.workspace_snapshot(aid, dayid)` monta auditoria, empresa, condutor, dias/presenças, cronograma, movimentações, avaliações, NCs, atas, plano, pendências, estatísticas e achados (`.../20261007104406_checklist_complete_workflow.sql:761-784`) | Usar uma projeção versionada como entrada canônica. Não fazer o renderizador consultar tabelas operacionais livremente. |
| Snapshot diário | `close_day` bloqueia concorrência da auditoria, valida pendências, presença e uploads, fecha o dia e grava `daily_reports.content` (`.../20261007104406_checklist_complete_workflow.sql:630-675`) | Reaproveitar a transação de fechamento/idempotência, mas separar “conteúdo fechado” de “PDF publicado”. |
| Versões e integridade do conteúdo | Na história local, `approve` calcula a próxima versão, injeta autoria/data, grava `content` e SHA-256 e finaliza o documento (`.../20261007104406_checklist_complete_workflow.sql:723-738`) | Manter versão monotônica e autoria. Criar integridade adicional para o binário PDF. O remoto confirma uma coluna `checksum`, mas a consulta recebida não prova seu algoritmo nem que cubra PDF. |
| Retificação sem sobrescrita da versão | `revise` exige motivo, remove `approval` do conteúdo corrente e volta a revisão (`.../20261007104406_checklist_complete_workflow.sql:718-722`); a consulta lista todas as versões (`:644-656`) | Preservar versões emitidas; cada retificação gera nova revisão e novo artefato. O emissor recebe um `version_id`, nunca apenas o relatório corrente. |
| Seleção de evidência | `evidence_files` ganhou `caption`, `include_in_rda` e `display_order` (`.../20261007032929_checklist_execution_v1.sql:126`); o snapshot inclui somente arquivos selecionados e congela id, nome, legenda, ordem, MIME, autor e data (`.../20261007104406_checklist_complete_workflow.sql:774`) | Usar seleção/ordem/legenda já existentes. Antes do render, resolver e fixar os bytes ou uma identidade imutável do objeto. |
| Upload validado | A Edge Function identifica PDF/JPEG/PNG pelos bytes, limita 10 MiB, cria path por auditoria/avaliação/operação e usa `upsert:false` (`outputs/audita-pro-supabase/supabase/functions/audit-evidence/index.ts:19-33`) | Reutilizar o padrão de autenticação, idempotency key, path não sobrescrito, validação de MIME e limpeza após falha. O limite de evidência não deve ser copiado para o PDF final. |
| Bucket privado e links temporários | `audit-evidence-workspace` é privado (`.../20261006152617_audit_workspace_evidence.sql:1-2`) e a Edge Function emite URL de 60 segundos (`audit-evidence/index.ts:14-17`) | Manter acesso privado, mas o emissor deve ler bytes diretamente com credencial de serviço; URLs assinadas são transporte temporário, não referência persistida. |
| Autorização contextual da evidência | Leitor externo só vê arquivo que consta no snapshot de documento concluído (`.../20261007160236_checklist_document_evidence.sql:14-22`) | É um bom padrão de autorização por artefato publicado. A rota de PDF deve validar a versão e o leitor, em vez de expor paths. |
| Biblioteca | `private.workspace_library` unifica diário/final/ata, filtra por `workspace_document_access` e pagina (`.../20261006154428_audit_document_library.sql:2-15`); a UI abre o documento no workspace (`outputs/audita-pro-document-library.js:1-8`) | Manter a listagem e trocar a ação de PDF para o artefato persistido da versão vigente. A autorização do RDA por organização precisa ser específica, como alerta o plano (`outputs/audita-pro-planejamento-rda-v0.1.md:327-331`). |
| Notificações deduplicáveis | A aprovação cria chave com `version_id` e usuário, com `on conflict do nothing` (`.../20261007104406_checklist_complete_workflow.sql:736-737`) | Disparar somente após o arquivo estar pronto e publicado, mantendo a versão na chave. |
| Estruturas legadas de arquivos | A base histórica tem bucket privado `audit-reports` (`.../20261005000200_audit_domain.sql:449-456`), `report_external_files` para diário (`:172-179`) e `audit_final_report_files`, que já admite `version_id` e `generated_pdf` (`.../20261005203207_dashboard_data_extensions.sql:64-74`). O inventário remoto recebido confirma a assimetria de `version_id`. | Podem orientar compatibilidade/migração. Não são ainda um contrato compartilhado: o diário não liga arquivo à versão e o fluxo workspace local não escreve nessas tabelas. |
| Logo | `outputs/audita-pro-logo.png` é PNG RGB de 2172 × 724; a UI e o jsPDF já o carregam (`outputs/audita-pro-audits.js:66,76`) | Empacotar uma cópia versionada como asset do template. É a marca **Audita PRO**, não uma logo corporativa Audita validada, conforme `outputs/audita-pro-planejamento-rda-v0.1.md:301-303`. |

## O PDF atual e por que ele não atende à emissão

Existem duas saídas locais no navegador:

1. `printDocument` abre uma janela, injeta HTML/CSS mínimo e chama `window.print()` (`outputs/audita-pro-audits.js:75`). Usa Arial solicitada ao sistema, depende do motor de impressão e delega “Salvar PDF” ao usuário.
2. `downloadPdf` usa `jsPDF` carregado do CDN (`outputs/audita-pro-auditorias.html:1-3`) e desenha texto/rodapé/fotos de forma imperativa (`outputs/audita-pro-audits.js:76`). O projeto local não declara jsPDF como dependência empacotada; `scripts/package.json` possui apenas `happy-dom` para testes.

As duas implementações divergem. A prévia HTML tem tabelas; a saída jsPDF é sobretudo uma sequência textual. A impressão não incorpora necessariamente as fotografias autorizadas, enquanto jsPDF as busca uma a uma. Nenhuma contém as 14 seções, gráficos, cabeçalho/rodapé completo e identidade RDA exigidos no plano (`outputs/audita-pro-planejamento-rda-v0.1.md:289-303`). Não há teste de paginação/render visual no repositório.

Também não há fontes embarcadas: não existem `.ttf`, `.otf`, `.woff` ou `.woff2` no checkout. A UI declara stacks como Inter/Segoe UI/Arial, mas não fornece Inter; a impressão usa Arial e o jsPDF usa sua fonte padrão. Um servidor precisa de fontes licenciadas e empacotadas, com fallback explícito e hash/versionamento do asset, para produzir o mesmo resultado em toda emissão.

## Imutabilidade: o que existe e o que falta

O código local protege bem parte do conteúdo lógico. `daily_report_versions`, `audit_final_report_versions` e `audit_minutes_versions` têm unicidade por relatório/versão e `on delete restrict` nos vínculos relevantes (`outputs/audita-pro-supabase/supabase/migrations/20261005000200_audit_domain.sql:151-160`, `.../20261005203207_dashboard_data_extensions.sql:51-62`, `.../20261006151927_audit_workspace_foundation.sql:43-53`). A função local de aprovação persiste SHA-256 de `content::text`, o que permite detectar alteração do snapshot sob aquele algoritmo. A presença remota da coluna `checksum` não comprova que o ambiente atual execute essa mesma função ou esse algoritmo.

Não há a mesma garantia para o resultado visual. A geração atual relê a logo estática e, para cada foto, chama `audit-evidence`, recebe URL assinada, baixa o objeto atual e o insere (`outputs/audita-pro-audits.js:76`). A URL expira em 60 segundos e não é congelada — corretamente —, mas o snapshot guarda apenas o id/metadados, não hash, geração/version ID do Storage ou cópia de publicação. Mesmo com paths que hoje são criados sem sobrescrita, o contrato local não demonstra retenção imutável dos objetos nem impede toda remoção administrativa. Se o objeto desaparecer, uma revisão aprovada deixa de ser reproduzível; se houver substituição fora do fluxo esperado, os bytes podem mudar sem alterar o checksum JSON.

Para uma emissão real, a versão deve apontar para um PDF privado persistente e registrar, no mínimo, `storage_path`, SHA-256 do PDF, tamanho, MIME, template/layout version, engine version, status, tentativas e timestamps. As imagens incorporadas devem ser lidas uma vez e o PDF resultante passar a ser a evidência imutável publicada. Para reprodução forense, convém ainda congelar hash/tamanho de cada asset incorporado ou copiar os selecionados para namespace imutável da revisão.

## Lacunas funcionais em relação ao RDA

- **Estados incorretos:** hoje `approve` muda o documento para `completed` antes de existir PDF (`.../20261007104406_checklist_complete_workflow.sql:728-738`). O requisito distingue Em elaboração, Fechado e Emitido, mais o estado técnico pendente/processando/concluído/falhou (`outputs/audita-pro-planejamento-rda-v0.1.md:196-224`).
- **Fluxo invertido:** atualmente o dia é fechado, o relatório entra em `review` e depois é aprovado. O plano do RDA pede revisar/pré-visualizar, confirmar fechamento e então emitir automaticamente (`outputs/audita-pro-planejamento-rda-v0.1.md:181-195`).
- **Sem idempotência de emissão:** existe idempotência para criar um único relatório por dia (`close_day` retorna o existente), mas não há job único por `version_id`, lease, contador de tentativas ou compare-and-set de publicação.
- **Sem arquivo diário por versão:** `report_external_files` se liga ao relatório, não à `daily_report_versions`; já a estrutura de final aceita `version_id`, porém o workspace não a alimenta. Uma revisão pode, portanto, não ter correspondência inequívoca com um PDF.
- **Acesso do RDA ainda baseado em destinatários/presença:** `close_day` copia `audit_day_attendance` para `audit_document_recipients` (`.../20261007104406_checklist_complete_workflow.sql:671-675`). O requisito libera RDA emitido a vínculos autorizados da organização, mesmo sem presença (`outputs/audita-pro-planejamento-rda-v0.1.md:254-275`), sem ampliar atas, finais ou evidências originais.
- **Conteúdo editorial incompleto:** o snapshot só oferece `additional_notes` genérico; faltam resumo executivo, considerações, declaração/estrutura de pendências, identidade RDA, revisão apresentada, versão do template e regra de indicadores.
- **Indicadores não congelados no formato necessário:** há `statistics`, mas o contrato não registra explicitamente contagens diárias e acumuladas, denominador/algoritmo versionado e corte exigidos pela fórmula do RDA.
- **Atividades parciais:** o fechamento atual bloqueia qualquer atividade não concluída e não retirada (`.../20261007104406_checklist_complete_workflow.sql:668-670`), enquanto o RDA deve admitir parcial/não realizada devidamente encaminhada.
- **NC:** o código aceita justificativa sem NC para não conformidade (`:670`), mas o requisito do novo RDA exige NC vinculada antes da emissão.
- **Evidência documental:** jsPDF incorpora imagens, mas para PDFs selecionados apenas lista o anexo; é compatível com a proposta inicial, desde que título, referência e síntese sejam congelados.
- **Certificação:** `documentHtml` e `downloadPdf` sempre apresentam certificação (`outputs/audita-pro-audits.js:66,76`), embora o RDA não deva contê-la (`outputs/audita-pro-planejamento-rda-v0.1.md:24-35`). O template compartilhado precisa receber um tipo documental e permitir seções próprias, não imprimir todos os campos para todos os tipos.

## Contrato recomendado para o emissor compartilhado

O núcleo deve ser uma função/serviço com entrada fechada, por exemplo `emit_document(version_id, operation_id)`, que:

1. autentica a chamada interna e carrega exatamente uma versão documental;
2. adquire a emissão de forma atômica (`unique(document_kind, document_id, version_id)` conceitual e mudança condicional de `pending/failed` para `processing`);
3. valida o `content_hash`, o `document_kind`, a versão do template e a lista de assets;
4. lê logo, fontes e evidências privadas diretamente do Storage, verificando hashes/tamanhos quando registrados;
5. renderiza o PDF em runtime e dependências fixados;
6. calcula SHA-256 e tamanho do PDF, envia com `upsert:false` para path derivado da versão/operação;
7. revalida a emissão e publica com compare-and-set, tornando a versão “emitida” apenas depois do upload íntegro;
8. cria notificações uma única vez; e
9. em falha, preserva snapshot/fechamento, registra erro sanitizado e permite repetir a mesma emissão.

Uma tabela/registro comum de artefato pode conter `id`, `document_kind`, `document_id`, `version_id`, `status`, `operation_id`, `storage_path`, `pdf_sha256`, `size_bytes`, `template_version`, `engine_version`, `attempt_count`, `last_error`, `requested_at`, `started_at`, `completed_at` e `published_at`, com unicidade por tipo documental, documento e versão. Os nomes definitivos dependem da inspeção remota; a recomendação é o contrato, não uma migration pronta.

O renderizador deve receber componentes comuns — A4, margens, cabeçalho/rodapé, numeração, tabelas repetíveis, blocos, barras/gráficos, imagens com contenção e metadados de controle — e templates editoriais por tipo. Logo/fontes devem ser assets empacotados no backend, não recursos de CDN. O front-end fica responsável por prévia e acompanhamento de estado; o download sempre resolve o mesmo artefato persistido daquela revisão.

## Ordem de integração B08 e blocos consumidores

As etapas de fechamento, publicação, biblioteca e notificações pertencem aos respectivos blocos B09/B11/B12. B08 fornece o motor; esta sequência não transfere essas responsabilidades. O contrato consolidado de estados e identidade está em `contrato-emissao.md` e prevalece sobre nomes ilustrativos deste diagnóstico.

1. Comparar o schema remoto com as migrations locais e identificar quais tabelas/policies/functions realmente existem; preservar compatibilidade B02/B03 e documentos legados.
2. Definir o contrato canônico de snapshot RDA, incluindo identidade, textos, indicadores, versão de regra/layout e manifesto de assets.
3. Introduzir artefato/estado técnico por versão e um bucket/path privado sem sobrescrita; não mudar ainda a autorização compartilhada de atas/finais.
4. Implementar o emissor com fixtures extensas, fotos, acentos, páginas múltiplas e fontes empacotadas; testar hash e repetição idempotente.
5. Alterar fechamento/publicação para que “Emitido” só ocorra após arquivo íntegro; manter falha retomável.
6. Servir download autorizado do artefato persistido e adaptar Biblioteca/notificação especificamente para RDA.
7. Migrar outros documentos para o emissor comum gradualmente, mantendo seus snapshots, permissões e arquivos históricos originais.

Nenhum PDF legado deve ser regenerado silenciosamente. Onde já houver arquivo real em `audit-reports`, ele precisa continuar sendo a fonte daquela emissão. Onde existir apenas JSON e geração no navegador, a interface deve tratar isso como legado sem artefato persistido, em vez de declarar retrospectivamente a mesma garantia de imutabilidade do novo B08.
