# Entrega B08 — Serviço comum de emissão documental

- **Responsável:** Claude (C0). **Data:** 10/10/2026. **Branch:** `feat/b08-emissao-claude` (base `feat/b07-cronograma-claude`).
- **Base:** plano mestre §B08; critérios PA-13/14/16/21 e RDA-12/17 (parte do motor; o conteúdo do Plano é do B09 e o do RDA, do B10–B12). Os rascunhos do Codex nesta pasta (`diagnostico.md`, `viabilidade.md`, `contrato-emissao.md`, `criterios-e-testes.md`) foram a referência; o contrato proposto foi seguido.

## O que existe agora

**Motor `audita-pdf 1.0.0`** (`supabase/functions/document-emission/pdf/`), sem dependências, roda igual em Node e no Deno da Supabase:
- A4 com cabeçalho (logo, título, código, revisão e data) e rodapé com "Página X de Y" em todas as páginas.
- Tabelas com cabeçalho repetido e "(continuação)"; uma célula maior que a página é dividida sem truncar.
- Títulos não ficam sozinhos no fim da página: vão junto com o primeiro trecho do bloco seguinte (a foto inteira, o cabeçalho da tabela ou cerca de 3 linhas).
- Fotos JPEG sem recompressão (orientação EXIF respeitada) e PNG com transparência. WebP é recusado com orientação para converter.
- Gráficos de barras com o valor em texto, legíveis em impressão monocromática; gráfico vazio mostra a explicação, não percentuais fictícios.
- Seção vazia explicada; marca d'água "PRÉVIA — SEM VALIDADE" quando pedida.
- Saída determinística: a mesma entrada gera os mesmos bytes.

**Pedido de emissão persistente** (`private.document_emissions`, `document_emission_attempts`, `document_emission_tickets`):
- Um pedido por (tipo, revisão), com o conteúdo congelado e SHA-256. O mesmo conteúdo reaproveita o pedido; outro conteúdo para a mesma revisão é recusado.
- Posse exclusiva com prazo (lease): uma segunda chamada simultânea recebe "ocupado". Um processo que perdeu a posse não finaliza e retira o próprio arquivo.
- "Pronto" só depois do upload e da releitura do arquivo armazenado com o mesmo hash. O caminho de cada tentativa é reservado no banco e gravado com `upsert:false`.
- "Publicado" é decisão separada do produtor (`private.b08_publish`), com ponto de extensão `private.b08_after_publish` para o B09/B12.
- Identidade, conteúdo e arquivo emitido são imutáveis, e nada é excluído (AD-15).
- **Retomada durável:** o `pg_cron` varre a cada minuto os pedidos pendentes, as posses vencidas e as falhas retomáveis; o `pg_net` aciona a função com bilhete de uso único. Até 5 tentativas automáticas; depois disso o condutor ou o Admin libera mais 3.

**Acesso:**
- `public.document_emission` para o navegador: `status`, `list`, `retry`, `authorize_download` e `request_specimen` (este só para o Admin).
- `public.document_emission_worker` e `public.document_emission_ticket` somente para service_role.
- Download por URL temporária de 60 s, sempre do arquivo persistido da revisão. Antes de publicado, só o operador (condutor ou Admin) baixa, para conferência.

**Interface:**
- `audita-pro-emission.js`: cliente comum que o B09 e o B12 vão usar.
- Aba "Emissor de documentos" na Biblioteca, só para o Administrador: gera o documento de prova, acompanha, baixa e retoma.

## Critérios

| Critério | Situação no B08 | Evidência |
|---|---|---|
| PA-14 / RDA-12 (falha, duplo clique, retomada) | Atendido no motor: interromper o upload e retomar a mesma revisão; tentativas simultâneas geram um único documento; resposta perdida após confirmar preserva o arquivo; nenhum arquivo incompleto fica oficial | SQL 33/33 · fluxo 16/16 |
| PA-16 (cadastro alterado) | Atendido no motor: conteúdo congelado no pedido; download devolve sempre os mesmos bytes; arquivo emitido não é substituído | SQL (imutabilidade, mesmo arquivo) |
| PA-21 / RDA-17 (muitas páginas) | Atendido no motor com o documento de prova: 900 linhas, 48 páginas, célula de 140 trechos atravessando páginas, cabeçalho/rodapé/numeração em todas, nove notas na última | motor 27/27 · autoteste em produção |
| PA-13 (Rev.00 com PDF, acesso único) | Base pronta (pedido, publicação, evento único); a validação e o congelamento do Plano são do **B09** | — |
| Monocromático | Conferido visualmente (`evidencias/previa-monocromatica-1.png`) | evidências |

## Medições no runtime real (Supabase Edge, 10/10/2026)

O autoteste é acionado pelo banco, gera o documento em memória, grava, relê, confere o hash e retira o arquivo.

| Documento | Páginas | Tamanho | Geração | Upload | Conferência | Total | Heap |
|---|---|---|---|---|---|---|---|
| Representativo (120 linhas) | 12 | 92 KB | 44 ms | 369 ms | 260 ms | 0,8 s | 17 MB |
| Extenso (900 linhas) | 48 | 188 KB | 136 ms | 272 ms | 453 ms | 1,0 s | 26 MB |
| Máximo (2.000 linhas) | 98 | 323 KB | 142 ms | 644 ms | 221 ms | 1,1 s | 44 MB |

Limites do runtime: 2 s de CPU por requisição, 256 MB de memória e 150 s de duração. A geração usa menos de 10% da CPU. As fotos JPEG não são recomprimidas, então pesam no tamanho, não na CPU. Um PNG grande com transparência é o caso mais caro e ainda precisa ser medido com fotos reais (B10–B12). O limite do arquivo final é de 50 MB; acima disso a emissão falha com aviso, sem reduzir nem omitir conteúdo.

## Produção

- **Migrations:**
  - `20261010205937_b08_1_emission_schema`
  - `20261010210010_b08_2_emission_commands`
  - `20261010210033_b08_3_emission_worker`
  - `20261010210520_b08_4_dispatch`

  As quatro foram conferidas byte a byte com o repositório (md5).
- **Extensões:** `pg_net 0.20.0` e `pg_cron 1.6.4`, com a tarefa `b08-document-emission-sweep` rodando a cada minuto sem erros.
- **Edge Function** `document-emission` v1 (`verify_jwt=false`; a sessão é validada no código com `getUser`, e o bilhete, no banco).
- **Estado após a prova:** nenhum pedido criado e nenhum arquivo deixado no bucket.
- **Avisos de segurança:** nenhum alerta novo; as tabelas privadas sem política são intencionais.

## Testes

| Teste | Resultado |
|---|---|
| `scripts/run-sql-test.sh scripts/test-b08-emission.sql` | 33/33 |
| `scripts/run-sql-test.sh scripts/test-b08-dispatch.sql` | 10/10 |
| `tsx scripts/test-b08-render.mts` (qpdf, pdfinfo, pdftotext, pdfimages) | 27/27 |
| `tsx scripts/test-b08-emit-flow.mts` (orquestrador contra o banco local, Storage com falhas injetadas) | 16/16 |
| `node scripts/test-b08-emitter-ui.mjs` | 11/11 |
| Regressão B04–B07 (SQL e interface) | aprovada |

## Pendente / limites

- **D08:** confirmar a marca e o template vigentes. O logo atual é provisório (fundo escuro); falta definir uma versão clara para impressão e, se desejado, uma fonte institucional embutida (AD-17/AD-20). Nenhuma menção à ABNT foi incluída.
- **B09:** modelo `plan` v1 (cabeçalho, cronograma, escopo e as nove notas do Anexo A) e publicação da revisão via `b08_request`/`b08_after_publish`.
- **B10–B12:** modelo `rda`, fotos das evidências por caminho e hash congelados no manifesto (buckets `audit-evidence*`) e regras de leitura do RDA publicado.
- **Homologação:** emitir o documento de prova pela aba "Emissor de documentos" com o Admin real, depois que o frontend for publicado.
- Não há limpeza automática de arquivos de tentativas que perderam a posse: o próprio processo retira o seu arquivo, e só sobra algo se a remoção falhar.

## Reversão

Desativar a tarefa `b08-document-emission-sweep` e ocultar a aba do emissor. O schema é aditivo; os PDFs emitidos e o histórico ficam preservados.
