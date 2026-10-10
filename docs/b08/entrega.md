# B08 — Preparação da emissão documental compartilhada

Revisão final: 10/10/2026. Responsável: Codex 03, com subagentes GPT-5.6 Sol em esforço leve e revisão final pelo agente principal.
Base: `20f0dec9de3764b5107010d835f7e28dc6781e67` (preparação B07). Branch: `feat/b08-preparacao`.
**Status: preparação para implementação pelo Codex 01; B08 não concluído.**

## Escopo e dependências

Preparar um serviço comum de PDF para Plano/RDA, com snapshots, templates versionados, pedido persistente, idempotência, integridade, retomada de falhas e publicação controlada.

As dependências diretas são B02, B03 e contrato de snapshot de B01. B04/B05/B06/B07 não bloqueiam diretamente o motor; os produtores documentais B09/B10/B11 ainda precisam integrar seus conteúdos. A decisão D08 e o padrão visual final devem ser recuperados para homologar o template. Esta preparação não presume que o arquivo de marca disponível seja o padrão aprovado nem declara conformidade ABNT.

## Ordem de leitura

1. [Diagnóstico](diagnostico.md): o que o produto já faz e o que falta.
2. [Viabilidade](viabilidade.md): candidatos, documentação e limites da comprovação técnica.
3. [Contrato de emissão](contrato-emissao.md): estados, idempotência, integridade, recursos e responsabilidades.
4. [Critérios e testes](criterios-e-testes.md): cenários de aceite futuro e tratamento de falhas.
5. [Rastreabilidade](rastreabilidade.csv): 100 linhas originais B08 preservadas e status real; 16 cenários de teste planejados.

O diff desta branch deve ser revisto a partir de `20f0dec`; não importar todos os commits ancestrais sobre a base integrada do Codex 01. Nenhum arquivo do produto ou contrato B02/B03 foi modificado por esta preparação.

## Evidência e limites

Foram examinados o código local, fontes do plano e metadados do Supabase `zlckcpeqcxmtrgbdquee` em leitura. O catálogo confirma tabelas de versões com conteúdo/checksum e estruturas de arquivos. Não assumir que o checksum já existente representa bytes do PDF: isso depende da implementação efetiva. `audit_plan_versions` não tinha coluna de checksum no inventário consultado. O bucket `audit-reports` é privado, aceita PDF e tem limite observado de 20.971.520 bytes.

Não houve gravação no banco, upload de documento real, emissão oficial, mudança de RLS, deploy ou publicação. Não acompanha código de renderização nem ensaio validado. A biblioteca é candidata; comprovação no runtime real e homologação do template AUDITA continuam pendentes.

Verificações concluídas: comparação automática das 100 linhas e 16 colunas originais com a matriz mestre; seis critérios originais preservados integralmente; 16 cenários; links internos válidos; revisão do contrato e diff restrito a `docs/b08`. Os testes funcionais da emissão e os critérios de aceite integrados continuam não executados. Não reutilizar resultados de B06/B07 como evidência de B08.

## Instruções de implementação

1. Recuperar contrato final de snapshot B01, decisões documentais e baseline integrada B02/B03. Conferir reserva de arquivos com as frentes B06/B07.
2. Provar biblioteca/runtime no ambiente real de homologação, sem adotar serviço pago por padrão.
3. Reutilizar registros de versões/arquivos e acrescentar apenas o controle de emissão faltante. Implementar transações, idempotência e recuperação do intervalo entre Storage e banco.
4. Integrar dados congelados e manifesto de recursos imutáveis. Não gerar o PDF oficial a cada download nem buscar cadastros atuais para recompor uma revisão emitida.
5. Separar arquivo íntegro pronto de documento publicado. Uma falha não substitui a revisão vigente nem libera link incompleto.
6. Homologar Plano e RDA extensos, todas as páginas, tabelas, notas, fotos, gráficos, fontes e impressão monocromática; executar falhas/repetições/concorrência e autorização negativa.
7. Entregar commit, migrations, versão do motor/template, medições, critérios atendidos, evidências, pendências e URL para homologação.

Reversão da preparação: reverter apenas seu commit. Na implementação futura, suspender novas emissões sem apagar PDFs, snapshots ou histórico de revisões emitidas.
