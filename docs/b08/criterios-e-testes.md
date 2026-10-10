# B08 — critérios de aceite e roteiro de testes

## Estado desta preparação

Este documento prepara o aceite do B08, sem executar implementação, banco, migração ou teste. O B08 depende de B02, B03 e do contrato de snapshot de B01 segundo `01-plano-mestre.md`. Não foi localizado neste repositório um registro final de B01 para esse contrato nem a decisão final D08 sobre marca, template e normas aplicáveis. Portanto, todos os resultados abaixo permanecem **Não executados** e nenhum cenário constitui evidência de aceite.

A rastreabilidade integral está em `docs/b08/rastreabilidade.csv`: 100 linhas originais cujo campo `blocos_execucao` contém B08, preservadas nas 16 colunas da matriz mestre e acrescidas somente de `status_implementacao_b08` e `status_teste_b08`.

## Critérios originais atribuídos ao B08

Os textos são reproduzidos integralmente de `03-criterios-de-aceite.md` e das seções 17 das fontes Plano/RDA.

| ID | Critério original integral | Blocos na matriz mestre | Responsável principal na matriz | Resultado B08 |
|---|---|---|---|---|
| PA-13 | Validar plano → Rev.00 congelada, PDF gerado e acesso disponibilizado uma única vez | B09 B08 | B09 | Não executado |
| PA-14 | Erro na geração/duplo clique → Retomar a mesma emissão, sem PDF quebrado nem revisão duplicada | B08 B09 | B08 | Não executado |
| PA-16 | Alterar cadastro do cliente → PDF antigo mantém cabeçalho original | B09 B08 | B09 | Não executado |
| PA-21 | Plano com muitas linhas → Tabela legível, rodapé/paginação em todas as páginas e notas completas na última | B09 B08 | B09 | Não executado |
| RDA-12 | Falha de PDF ou duplo clique → Preservar fechamento, permitir retomada e não duplicar documento/aviso | B08 B11 B12 | B08 | Não executado |
| RDA-17 | RDA com várias páginas → Cabeçalho, rodapé, numeração, gráficos e tabelas legíveis em todas | B08 B12 | B08 | Não executado |

## Fronteiras e decisões pendentes

- **B08** fornece o serviço comum: pedido persistido, idempotência, snapshot consumido sem mutação, versão de template, geração, armazenamento privado, checksum, retry e confirmação de integridade. Também comprova capacidade de imagens, fontes, gráficos e documentos extensos.
- **B09** valida e publica o Plano, define seu conteúdo e template específico, controla revisões e acesso e integra o motor. PA-13, PA-16 e PA-21 permanecem de responsabilidade principal B09.
- **B11** fecha/retifica o RDA e cria o snapshot/pedido correspondente. B08 não define se o RDA pode fechar nem reabre o dia após falha.
- **B12** integra o template específico do RDA, publicação, distribuição, autorização de download e notificações. B08 não amplia acesso nem envia avisos ao cliente.
- **Registro final D08 não localizado nesta cópia:** não presumir logo corporativa da Audita, template/PDA vigente ou conformidade ABNT. O ensaio visual usa apenas uma identidade explicitamente aprovada; enquanto isso, pode validar estrutura com marcador neutro, sem declarar documento oficial.
- **Contrato final B01 não localizado nesta cópia:** o formato final e a autoridade de criação do snapshot não foram localizados. Antes da implementação, registrar campos congelados, canonicalização, versão, identidade da revisão, vínculo ao arquivo, tratamento de legados e regra de concorrência. Não inventar esse contrato dentro de B08.

## Premissas e evidências mínimas

Executar os testes futuros em ambiente isolado com um Plano e um RDA representativos, cada qual com identidade documental e revisão próprias. Usar armazenamento privado. Registrar para cada tentativa: `document_id`, `revision_id`, `snapshot_id`/hash, chave idempotente, versão do template, estado técnico, caminho privado, tamanho, checksum, timestamps, erro, número de tentativas e evento de publicação. Guardar logs e consulta persistida antes/depois, além do PDF renderizado página a página.

O gerador deve consumir exatamente o snapshot já congelado pelo fluxo dono. O teste não pode alterar o snapshot para fazer o retry passar. Publicação só ocorre depois de upload completo, leitura/validação do arquivo e atualização condicional da mesma revisão.

## Cenários obrigatórios do plano mestre

### CT-B08-01 — falha antes da geração

1. Persista pedido e snapshot e provoque falha determinística antes de criar bytes.
2. Confirme estado técnico `falhou`, revisão documental preservada e ausência de arquivo/link publicado.
3. Retome o mesmo pedido após remover a falha.

**Esperado:** mesma revisão, snapshot e chave lógica; uma única saída íntegra; erro anterior auditável. **Estado:** Não executado.

### CT-B08-02 — falha durante geração e processo interrompido

Interrompa o processo após produzir parte do PDF e antes do upload. Reinicie o worker e reprocesse o mesmo pedido.

**Esperado:** artefato parcial não é público nem tratado como concluído; a retomada usa o snapshot e a versão de template originais e termina em um único arquivo válido. **Estado:** Não executado.

### CT-B08-03 — falha de upload e integridade

Force timeout/desconexão no meio do upload e, separadamente, faça a verificação devolver tamanho/checksum divergente. Tente consultar o caminho por UI, API e URL direta; depois execute retry.

**Esperado:** nenhum link publicado, estado não concluído, objeto incompleto inacessível e removido ou isolado; retry gera/confirma um único objeto íntegro antes da publicação condicional. **Estado:** Não executado.

### CT-B08-04 — duplo clique e emissão concorrente

Dispare duas requisições simultâneas com a mesma revisão e chave idempotente; mantenha dois workers concorrendo pelo mesmo pedido. Repita após refresh e após timeout do cliente.

**Esperado:** uma identidade de pedido, uma revisão, um arquivo por formato e no máximo um evento de conclusão; a tentativa perdedora retorna/reconsulta o resultado existente, sem sobrescrever estado válido. **Estado:** Não executado.

### CT-B08-05 — retry com entradas congeladas e reconciliação do artefato

Congele snapshot e versão do template, gere o arquivo, simule falha antes da confirmação final e repita. Compare snapshot/hash, versão do template, checksum e bytes. Repita após alterar cadastro do cliente, logo disponível e dados operacionais de origem.

**Esperado:** o retry não lê dados atuais e mantém conteúdo, identidade e versão fixados. Se os bytes íntegros já foram armazenados, a retentativa deve reconciliar e reutilizar esse objeto. O PDF oficial nunca é regenerado no download. Igualdade de bytes entre duas renderizações independentes só será exigida se o contrato adotar determinismo e o runtime for comprovado; isso é distinto da imutabilidade dos bytes emitidos. **Estado:** Não executado.

### CT-B08-06 — imutabilidade posterior

Depois da emissão, altere nome/endereço do cliente, usuário, cronograma, evidência de origem e identidade visual. Baixe novamente a revisão emitida e tente substituir/excluir seu objeto pela rotina comum.

**Esperado:** mesmos bytes/checksum e snapshot; mutações comuns são recusadas; mudanças só aparecem em nova revisão conforme B09/B11/B12. **Estado:** Não executado.

### CT-B08-07 — imagens e gráficos

Gere Plano e RDA com PNG e JPEG em retrato/paisagem, transparência, EXIF de rotação, WebP aceito pelo bucket (com conversão validada quando necessária), resoluções alta/baixa e proporções extremas; inclua gráficos claros e escuros e duas de doze fotos selecionadas no snapshot.

**Esperado:** apenas conteúdo selecionado é renderizado; orientação corrigida, proporção preservada, sem corte/distorção, legenda/referência legíveis e resolução suficiente em tela e impressão. Ausência/corrupção de imagem produz erro controlado, nunca publicação parcial. **Estado:** Não executado.

### CT-B08-08 — fontes, português e fallback

Renderize acentos, cedilha, símbolos, nomes longos e caracteres previstos pelo produto com a fonte aprovada incorporada. Repita indisponibilizando a fonte e inspecione fontes do PDF.

**Esperado:** nenhuma troca silenciosa que altere ou corte conteúdo; fonte incorporada/licenciada ou fallback versionado e comprovado; busca/cópia preserva o texto; nenhuma dependência de fonte apenas instalada na máquina do worker. **Estado:** Não executado.

### CT-B08-09 — Plano extenso

Use Plano com muitas linhas, descrições longas, múltiplos critérios/equipe e conteúdo suficiente para várias páginas e as nove notas finais integrais do Anexo A.

**Esperado:** PA-21 integral: tabela legível, cabeçalho/rodapé e paginação corretos, títulos repetidos, linhas sem sobreposição/corte e notas completas na última página. O conteúdo é responsabilidade de B09; B08 comprova a capacidade do motor. **Estado:** Não executado.

### CT-B08-10 — RDA extenso

Use RDA com todas as seções, tabelas e gráficos longos, imagens variadas e seções vazias, até produzir várias páginas.

**Esperado:** RDA-17 integral: cabeçalho, rodapé, “Página X de Y”, gráficos, tabelas e títulos legíveis em todas as páginas; seções não desaparecem nem são comprimidas para um limite arbitrário. O template final depende de B12/D08. **Estado:** Não executado.

### CT-B08-11 — contraste e impressão monocromática

Renderize ambos os templates em cor, tons de cinza e impressão monocromática; examine texto, linhas, estados e gráficos.

**Esperado:** informação não depende apenas de cor; contraste, padrões/rótulos e hierarquia continuam distinguíveis; nenhuma área essencial fica invisível. **Estado:** Não executado.

### CT-B08-12 — limites mensurados

Execute cargas graduais e um documento grande representativo, registrando quantidade de páginas/imagens/linhas, tamanho de entrada/saída, memória máxima, CPU, duração de geração/upload, timeout e resultado. Repita próximo do limite configurado e acima dele.

**Esperado:** limite real e comportamento de recusa/retry documentados, sem arquivo publicado em falha e sem promessa de desempenho não medida. O PDF gerado não herda indevidamente o limite de 10 MB das evidências. **Estado:** Não executado.

### CT-B08-13 — templates separados no motor comum

Emita Plano e RDA pelo mesmo contrato operacional, com tipos e versões de template distintos; tente usar template/tipo incompatível.

**Esperado:** estados, idempotência, armazenamento e integridade são comuns; conteúdo e layout não se misturam; combinação incompatível é recusada antes de publicar. **Estado:** Não executado.

### CT-B08-14 — revisão anterior durante substituição

Mantenha Rev.00 publicada, crie Rev.01 e force falha/retry da nova emissão.

**Esperado:** Rev.00 e seu arquivo continuam vigentes e imutáveis até a publicação íntegra de Rev.01; B08 não altera a regra de vigência definida por B09/B12. **Estado:** Não executado.

### CT-B08-15 — arquivo privado e autorização delegada

Antes e depois da conclusão, tente acessar caminho/URL com conta anônima, conta de outra organização e usuário sem autorização; confirme que o motor não gera URL pública permanente.

**Esperado:** arquivo incompleto permanece privado; autorização final é aplicada pelo fluxo B09/B12 e não é ampliada pelo serviço comum. **Estado:** Não executado.

### CT-B08-16 — identidade e normas

Execute somente após registrar D08 com data, responsável, marca/template aprovado e normas efetivamente aplicáveis. Compare cabeçalho, rodapé, nomenclatura e versão contra essa decisão.

**Esperado:** identidade aprovada reproduzida; nenhuma logo presumida e nenhuma declaração genérica de conformidade ABNT. Enquanto D08 estiver pendente, este cenário permanece bloqueado. **Estado:** Não executado.

## Cobertura das 100 linhas da matriz

- Plano: 67 linhas; RDA: 33 linhas.
- Responsável principal: B01 em 12 linhas, B08 em 15, B09 em 53 e B11 em 20.
- Critérios originais com B08: PA-13, PA-14, PA-16, PA-21, RDA-12 e RDA-17.
- As linhas de B01 cobrem congelamento/snapshots e imutabilidade; as de B09 cobrem conteúdo, validação e publicação do Plano; as de B11 cobrem fechamento/snapshot do RDA. Elas permanecem no CSV porque B08 participa da execução, mas este roteiro não transfere sua responsabilidade principal.

## Divergência de atribuição

Não há divergência textual entre a matriz e `03-criterios-de-aceite.md` nos seis critérios: ambos atribuem B08 aos mesmos IDs. Há uma diferença de participação e responsabilidade: PA-13, PA-16 e PA-21 incluem B08, mas a matriz mantém B09 como responsável principal; PA-14, RDA-12 e RDA-17 têm B08 como responsável principal. O plano mestre descreve ainda aceites técnicos sem IDs próprios (interrupção/retomada, concorrência, privacidade do incompleto, checksum e medição de documento grande), cobertos por CT-B08-01 a CT-B08-05 e CT-B08-12.

## Condição de saída futura

B08 somente poderá ser considerado aceito após: decisões/contratos de B01 localizados ou aprovados; D08 registrada; implementação integrada disponível; biblioteca/runtime comprovada no backend real; todos os cenários aplicáveis executados; medições anexadas; estados e arquivos consultados diretamente; e evidências ligadas aos IDs da matriz sem apagar textos originais ou atribuições de B09/B11/B12.
