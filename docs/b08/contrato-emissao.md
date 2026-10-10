# B08 — Proposta do serviço compartilhado de emissão

Data: 09/10/2026. Proposta para Codex 01. Nenhuma RPC, migration, política ou emissão oficial é criada por este documento.

## Fronteiras e dependências

B08 depende de B02, B03 e do contrato de snapshot de B01; não depende diretamente de B04/B05/B06/B07. O motor pode ser desenvolvido em paralelo com essas frentes, sem editar seus arquivos reservados. Os conteúdos reais do Plano e RDA dependem dos respectivos produtores B09 e B10/B11, e a distribuição integra B12.

Recuperar o contrato final B01 e a decisão D08 sobre identidade/template e referências normativas. A marca disponível no repositório não prova aprovação do modelo documental. Não tratar a ausência desses registros nesta cópia como ausência de decisão pelo usuário nem exigir nova aprovação do que já foi aprovado.

O motor recebe conteúdo congelado e autorizado. Não calcula indicadores do zero, não busca nomes/endereço atuais para substituir os do snapshot, não altera metodologia, não valida FPA e não decide sozinho publicar um relatório. Não emitir declaração genérica de conformidade ABNT ou certificação.

## Modelo conceitual mínimo

Reaproveitar as tabelas de versões e arquivos existentes. Só acrescentar persistência do pedido/tentativas se não houver equivalente na base integrada.

| Registro | Conteúdo necessário | Invariante |
|---|---|---|
| Pedido de emissão | ID, auditoria, tipo Plano/RDA, documento, revisão/snapshot, operação idempotente, template/versão, versão do motor, autor e data, estado | Uma revisão documental tem um único artefato oficial; retentativa não cria revisão nova |
| Snapshot de entrada | Referência e digest do conteúdo congelado, versão do schema/fórmula, data/fuso e metadados documentais | Não consultar tabelas mutáveis para recompor conteúdo após falha |
| Manifesto de recursos | IDs/versões/hash de imagens, logo e fontes; legenda, ordem e tamanho relevante | Recurso incorporado não é apenas URL temporária ou caminho mutável |
| Tentativa | Sequência, início/fim, concessão temporária de execução, erro sanitizado e métricas | Tentativa expirada pode ser retomada; processo antigo não finaliza depois de perder a posse |
| Artefato | Caminho privado único, versão de origem, tamanho real, páginas e SHA-256 dos bytes | Bytes publicados não são sobrescritos; checksum do JSON não substitui checksum do PDF |

Identidade do pedido: unicidade de tipo + documento + revisão a emitir, conciliada com B03. Template/engine/hash são dados fixados no pedido, não uma forma de criar outro PDF silenciosamente para a mesma revisão. Repetir uma chave de operação com conteúdo diferente retorna conflito. Trocar conteúdo/template após emissão exige a revisão/retificação prevista no fluxo documental.

## Entrada e saída propostas

Operações conceituais (nomes de API a conciliar): solicitar emissão, consultar estado, retomar tentativa e obter arquivo autorizado. Entrada pública mínima: IDs do documento/revisão, versão esperada e chave de operação. O backend resolve o snapshot e recursos autorizados; não aceitar JSON arbitrário do navegador como documento oficial aprovado, caminho livre de Storage ou URL externa fornecida pelo usuário.

Resposta de solicitação: ID do pedido, revisão e estado, ou referência ao pedido idempotente existente. Nunca devolver link público antecipado. Consulta de estado diferencia aguardando, processando, falha recuperável, falha definitiva e arquivo íntegro pronto. O estado de publicação do documento é separado do estado técnico de geração.

O arquivo pronto continua privado até o produtor documental confirmar os requisitos de publicação. Acesso de prévia pelo operador e acesso de cliente ao documento publicado devem ser rotas/capacidades distintas. Confirmar autorização também ao consultar estado, retentar e baixar; não revelar título, metadados ou erro de outra organização.

## Fluxo transacional e recuperação

1. Autorizar conta ativa e recurso por B02; verificar versão esperada, requisitos do produtor B09/B11 e existência do snapshot congelado. Criar/reutilizar o pedido com unicidade e fixar template/motor/manifesto.
2. Assumir uma tentativa com exclusão concorrente e identificação de posse. Registrar prazo de retomada. Não confiar em uma Promise após o término da resposta como garantia de execução durável.
3. Carregar somente recursos do manifesto, verificar hashes, formato, dimensões e limites. Gerar PDF no backend compatível, com orçamento de tempo/memória. Recurso ausente deve gerar falha explícita; não omitir evidência selecionada silenciosamente.
4. Verificar que os bytes representam PDF legível e não vazio; conferir páginas, tamanho e digest. Armazenar em caminho privado não sobrescrevível associado à tentativa e revisão.
5. Confirmar tamanho/digest do objeto armazenado e, em transação, vincular o artefato ao pedido se a tentativa ainda for a titular e a revisão/snapshot continuarem coerentes. Se houver dois uploads, apenas um pode tornar-se oficial; o outro continua privado e elegível à limpeza controlada.
6. Somente o fluxo documental autorizado publica a revisão pronta. A vigente anterior continua disponível enquanto a nova falha ou processa. Evento/notificação tem chave única; distribuição é integração B12, não efeito repetido de cada retentativa.

Banco e Storage não formam uma transação única. Por isso, tratar explicitamente estes pontos:

| Falha | Recuperação exigida |
|---|---|
| Antes de gerar | Retomar pedido existente e snapshot original |
| Durante renderização | Registrar tentativa falha; repetir com a mesma revisão, sem falso link |
| Durante upload | Objeto incompleto/órfão não aparece como emitido; limpar apenas recursos não referenciados |
| Upload concluído, confirmação no banco falhou | Reconciliar objeto existente por caminho/digest; não criar outra revisão nem presumir integridade pelo nome |
| Commit de arquivo pronto feito, resposta perdida | Retentativa retorna pedido/artefato já concluído |
| Duas tentativas concorrentes | A transação escolhe um artefato canônico; processo sem posse não publica |
| Revogação de acesso durante tentativa | Revalidar capacidade antes de finalizar a operação documental e impedir divulgação indevida; política de retomada pelo operador autorizado é explícita |

Não exigir bytes idênticos de duas renderizações independentes sem controlar datas/metadados/ordem da biblioteca. O requisito de checksum estável após mudanças de cadastro é atendido preservando os bytes já emitidos; download não regenera PDF. Se byte determinístico for adotado, fixar timestamp da emissão e demais entradas e comprová-lo separadamente.

## Recursos, privacidade e isolamento

- Fotos selecionadas devem ser referenciadas por versão imutável ou copiadas para recurso imutável da emissão; digest detecta mudança, mas sozinho não permite recuperação se o original foi sobrescrito. Planejar retenção dos bytes.
- Fontes e logo devem ter versão/hash e licença verificada. Não usar CDN em tempo de emissão oficial. Textos portugueses precisam manter acentos, símbolos usados e extração legível.
- Somente recursos autorizados da auditoria; documentos de identificação/competência não entram no PDF por serem anexos da conta. FPA permanece fora do PDF/projeção cliente por padrão do plano.
- URLs assinadas expiram e são credenciais portadoras: não congelá-las no snapshot como única referência nem gravá-las em logs. Autorizar download por revisão e contrato B02/D01/D02/D10 vigente.
- Bucket privado existente pode ser reutilizado se políticas, paths e vínculos realmente comportarem o novo artefato. Não ampliar permissões legadas para rascunhos ou outras organizações.
- Verificar permissões das tabelas, RPCs e Storage em conjunto. Não oferecer `service_role` ao navegador nem usar privilégio de servidor sem autorização prévia por recurso.

## Layout e templates

Um motor compartilhado, dois templates versionados: Plano e RDA. Componentes comuns de paginação, cabeçalho, rodapé, tabelas, imagens e gráficos. Não duplicar toda a geração para cada documento.

- A4, margens e zonas reservadas conforme identidade D08; cabeçalho/rodapé repetidos, código/revisão/data e Página X de Y. Nenhum texto pode invadir essas zonas.
- Tabelas repetem cabeçalhos e quebram linhas longas de modo legível. Sem reduzir fonte arbitrariamente para caber; limitar e testar células extensas, títulos órfãos e grandes tabelas.
- Plano preserva escopo após cronograma e as nove notas integrais do Anexo A em página final dedicada, conforme B09. Recuperar texto da fonte, não reescrever ou resumir dentro do motor.
- RDA respeita as 14 seções de B10; fotos mantêm proporção, legenda e ordem, PDFs anexos têm referência/síntese, não incorporação automática de todas as páginas.
- Gráficos usam métricas/fórmulas congeladas e incluem valores textuais; devem ser legíveis em monocromático e não apresentar porcentagens fictícias para conjunto vazio.
- Prévia se identifica como rascunho. Somente emissão validada recebe identificação oficial da revisão. Não acrescentar assinaturas/selos que o fluxo não implementa.

## Critérios para escolher biblioteca e runtime

A comparação e a prova local, quando disponível, estão em `viabilidade.md`. Uma execução local em Node não prova execução no Supabase Edge. Antes de escolher definitivamente, usar o runtime e os limites reais de homologação, com fontes/imagens e volume representativo; medir geração, upload, confirmação, memória e tamanho. Sem esse ensaio, a escolha permanece candidata.

Não contratar serviço novo por padrão. Se o runtime existente não suportar o volume, registrar o limite medido e apresentar alternativa ao Codex 01; não entregar uma arquitetura distribuída ou novo provedor como requisito presumido. Usar o próprio pedido de emissão para retomada simples e durável.

## Incrementos de implementação

1. Recuperar contrato de snapshot B01 e template D08; mapear tabelas/arquivos existentes na base integrada.
2. Provar candidato no runtime de homologação com Plano e RDA extensos, fotos/fontes/gráficos. Registrar versões e resultados.
3. Implementar pedido/estado/idempotência e autorização, sem publicar arquivo incompleto.
4. Implementar motor comum e templates, manifesto imutável, upload e confirmação de integridade.
5. Integrar produtores B09/B11 e consumidor B12; preservar versões anteriores e eventos únicos.
6. Executar injeção de falhas, testes negativos e revisão visual de todas as páginas; liberar somente com evidências.

Esta entrega não define schema definitivo nem aplica SQL. Nomes, grants, índices, funções e policies devem ser revisados com a versão atual de B02/B03 pelo Codex 01.
