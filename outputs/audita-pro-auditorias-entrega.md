# Audita PRO — entrega do módulo Auditorias

Data: 06/10/2026. Referência: planejamento de Auditorias v1.1.

## Acessar

[Abrir Auditorias no computador](http://127.0.0.1:5181/audita-pro-auditorias.html)

Faça login com sua conta habitual. O servidor local precisa permanecer em execução. As informações do módulo são consultadas e gravadas no projeto Supabase existente; os testes não deixaram auditorias fictícias no banco.

## Funcionalidades disponíveis

- Lista de auditorias com pesquisa por empresa, CNPJ, código ou título, filtro por situação e paginação.
- Administração de tipos de auditoria e modelos de checklist: premissas, seções, orientações, ordenação, duplicação, publicação, novas versões e modelos exclusivos por empresa.
- Tipos iniciais ISO 9001, ISO 14001 e ISO 45001. O conteúdo dos requisitos deve ser cadastrado pelo Administrador.
- Criação vinculada a empresa, unidade, responsável habilitado, modelo publicado, escopo, objetivo, finalidade, parte, modalidade e critérios.
- Equipe com participantes, auditores de apoio e signatários de ciência. Somente o condutor designado executa a auditoria; a Administração pode substituí-lo com justificativa.
- Plano por datas, horários, processos e múltiplos requisitos; publicação versionada, revisão com controle de concorrência, reagendamento e histórico.
- Presença diária, início/conclusão das atividades e avaliações por requisito e processo, com evidência textual ou arquivo. Não aplicabilidade exige justificativa.
- Anexos PDF, JPEG e PNG de até 10 MB em armazenamento privado, com autorização no servidor, validação de conteúdo e links temporários.
- Criação de NC vinculada à avaliação, com responsável, prazo e plano de ação inicial. Consulta das NCs na auditoria.
- Indicadores calculados dos dados registrados, excluindo itens não aplicáveis do denominador de progresso.
- Relatório diário automático ao encerrar o dia; ata automática ao concluir reunião; relatório final mediante encerramento integral explícito.
- Revisão, complementos, validação, publicação, destinatários históricos e versões congeladas dos documentos. A ata exige confirmação dos presentes na reunião.
- Decisão de certificação informada pelo condutor, com origem, data e referência quando concedida/não concedida. Uma decisão posterior pode ser registrada por retificação do relatório final.
- Visualização e geração de PDF com a logo oficial; alternativa de impressão/salvar PDF pelo navegador.
- Documentos acessíveis na própria auditoria e na Biblioteca, mantendo empresa/CNPJ e auditoria de origem.
- Notificações de responsabilidade atribuída, plano publicado, documento aguardando validação e documento disponibilizado.

## Roteiro de validação — Administrador/condutor

1. Em **Auditorias → Personalizar auditoria**, confira os tipos e crie um modelo.
2. Cadastre suas premissas e publique o modelo. Não há requisitos normativos fictícios pré-preenchidos.
3. Em **Nova auditoria**, selecione empresa, tipo, modelo e responsável. Preencha título e escopo.
4. Abra **Equipe**, revise os participantes e confirme. Para sua própria condução, use sua conta Administrador como responsável.
5. Em **Plano de auditoria**, distribua os requisitos entre processos e datas; inclua abertura/encerramento quando aplicável e publique.
6. Inicie a auditoria, confirme a presença do dia e registre os resultados em **Checklist e evidências**.
7. Salve uma avaliação não conforme e reabra o item para criar a NC, informando responsável e prazo.
8. Conclua as atividades realizadas. Se restar trabalho, edite o plano, reagende e justifique a revisão.
9. Encerre o dia e abra **Relatórios e atas**. Revise, complemente e valide os documentos. Nas atas, confirme os presentes da reunião.
10. Após encerrar os dias e aprovar os documentos, use **Encerrar auditoria**, informe a conclusão/decisão e valide o relatório final.
11. Confira os documentos na Biblioteca e os avisos no sino. Abra uma retificação para verificar que a versão anterior permanece acessível.

## Roteiro — Participante/Auditor de apoio

Use uma conta ativa e aprovada, vinculada à empresa. Inclua-a na equipe para consultar dados da auditoria. A presença no dia determina os destinatários do relatório diário; a presença na reunião determina os destinatários da ata.

- Confira plano, atividades e andamento, sem controles de edição.
- Após validação do condutor, abra os documentos autorizados.
- Uma conta empresarial sem participação explícita recebe somente a projeção do plano publicado, sem resultados/evidências internos.
- Uma conta de outra empresa não deve obter esses registros por URL ou API.

## Arquivos

Criados na pasta `outputs`: `audita-pro-auditorias.html`, `audita-pro-audits.js`, `audita-pro-audits.css` e `audita-pro-document-library.js`.

Integrações alteradas: `audita-pro-auth.js`, `audita-pro-header.js`, `audita-pro-dashboard.js`, `audita-pro-historico.html` e links de Auditorias nas páginas do painel. Cópia estática sincronizada em `audita-pro-deploy`.

Backend: migrations em `audita-pro-supabase/supabase/migrations` e função `audit-evidence` em `audita-pro-supabase/supabase/functions/audit-evidence/index.ts`, publicada no Supabase.

## Banco e segurança

Foram reutilizadas as estruturas de empresas, unidades, usuários/vínculos, auditorias, checklists/modelos/revisões/requisitos, participantes, dias, processos, cronograma, avaliações, evidências, NCs, planos de ação, relatórios diários/finais, versões, ciência e notificações.

Extensões específicas: `audit_types`, `audit_plan_versions`, `audit_day_attendance`, `schedule_requirements`, `schedule_movements`, `audit_minutes`, `audit_minutes_versions` e `audit_document_recipients`.

As novas tabelas têm RLS habilitada e acesso direto revogado para usuários comuns. O acesso ocorre pelas funções autenticadas, com verificações no servidor. Policies existentes receberam restrições para escopo de modelos, documentos e mutações das novas auditorias; o frontend não é a barreira de segurança. Auditorias anteriores preservam a compatibilidade por versão do fluxo.

Migrations aplicadas, com histórico local alinhado ao remoto:

| Versão | Nome |
|---|---|
| 20261006151927 | audit_workspace_foundation |
| 20261006152249 | audit_workspace_commands |
| 20261006152457 | audit_workspace_documents |
| 20261006152617 | audit_workspace_evidence |
| 20261006153325 | audit_workspace_validation |
| 20261006153513 | audit_workspace_integrity |
| 20261006153700 | audit_workspace_metrics |
| 20261006154026 | audit_workspace_lifecycle |
| 20261006154217 | audit_workspace_projection_fix |
| 20261006154428 | audit_document_library |
| 20261006211312 | audit_plan_revision_safety |
| 20261006211412 | audit_document_publication_metadata |
| 20261006212214 | audit_document_review_completion |
| 20261006212437 | audit_findings_summary |
| 20261006212519 | audit_document_locking |

## Verificações realizadas e seus limites

- Fluxo completo no Supabase: catálogo → auditoria → equipe → plano → avaliação → diário → final. Transações revertidas ao final.
- Reagendamento, datas não consecutivas, mesmo requisito em dois processos, não aplicabilidade, ata automática e documentos: aprovados em testes SQL com rollback.
- Isolamento entre empresas, condutor exclusivo, projeção restrita do plano, permissões de participante e destinatários por dia: aprovados nos cenários SQL exercitados.
- Regressão do fluxo anterior de notificações/Meu Perfil: aprovada.
- Interface no Chrome: catálogo, criação, checklist, plano e largura móvel verificados com respostas isoladas de teste. Isso não substitui a validação completa pelo navegador com contas reais.
- PDF de três páginas gerado pelo código real e inspecionado. O download automático foi cancelado pelo Chrome no ambiente de teste; o arquivo foi capturado para verificar geração e conteúdo. A opção **Imprimir / Salvar PDF** está disponível como alternativa. O download direto deve ser validado no navegador habitual.
- Páginas principais e novos arquivos retornaram HTTP 200 no servidor local.

## Pontos ainda não concluídos / limites deste incremento

- Ainda falta a validação ponta a ponta de upload/download autenticado de evidência pelo navegador com contas reais.
- A geração dos documentos é síncrona e transacional: falha na geração impede o encerramento daquela operação e permite nova tentativa. Não há fila persistente de processamento/retentativas em segundo plano.
- Os filtros da lista são pesquisa e situação; filtros avançados por responsável, norma e intervalo de datas não foram incluídos nesta etapa.
- Grandes checklists e históricos da auditoria ainda são carregados integralmente ao abrir o detalhe; a paginação interna e medição com grande volume precisam ser concluídas.
- A numeração inicial dos dias segue a ordem das datas. Revisões que inserem novas datas anteriores exigem revisão adicional da regra de renumeração, preservando os documentos já emitidos.
- As tarefas de ciência usam a estrutura existente; a nova tela de documentos ainda não oferece um fluxo próprio de confirmação por senha. Ciência não impede a leitura do documento publicado.
- GOV, operação offline e preenchimento automático de textos das normas permanecem fora do escopo aprovado deste incremento.

Esta entrega disponibiliza o fluxo principal para validação, mas não representa aprovação integral de todos os critérios do planejamento. Os pontos acima ficam registrados para continuação, sem substituir dados reais por demonstrações.
