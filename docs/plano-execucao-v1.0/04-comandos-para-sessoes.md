# Audita PRO — Comandos para sessões do Codex

## Instruções de utilização

Estes textos são comandos para a futura execução, não autorização para aplicar agora. Abrir as sessões somente quando o usuário decidir iniciar. Anexar a pasta completa deste pacote e informar a localização do repositório, ambiente de teste e commit-base conciliado em B00. Nenhuma sessão deve operar apenas com o resumo deste arquivo.

## Papéis

- C0: coordena contratos, reserva arquivos, integra e aplica migrations sequencialmente.
- C1: dados, autorização, métricas e propostas de migrations.
- C2: navegação, biblioteca e dashboards.
- C3: experiência de auditoria, plano/RDA e emissão.
- Revisão: outra sessão que não seja autora do bloco.

## Comando comum — incluir em toda sessão

Antes de editar, leia o plano mestre, o bloco indicado, as linhas correspondentes da matriz, os critérios de aceite e os trechos dos quatro originais em fontes/. Leia também AGENTS.md e as skills aplicáveis. Confirme commit-base, pasta do app efetivamente servida, projeto Supabase e último contrato integrado. Não trate código local antigo como versão atual quando o banco tiver mudanças mais recentes.

Implemente somente o bloco designado e preserve as funcionalidades existentes. Reutilize estruturas; não troque framework, conexão ou sistema de autenticação. Respeite as decisões registradas; se faltar uma decisão que muda acesso, métricas ou publicação, explique a dependência e trabalhe apenas na parte independente. Não publique uma escolha pendente como regra aprovada.

Use branch/checkout isolado acordado com C0. Não altere arquivo reservado por outra sessão. Se precisar mudar contrato compartilhado, proponha a alteração a C0 antes de integrar; atualize todos os consumidores afetados. Não aplique migrations no banco compartilhado; entregue proposta e evidências a C0. Não apague nem sobrescreva versões emitidas. Não inclua segredos no código, logs ou entrega.

Nesta execução autorizada do bloco, implemente e execute os testes pertinentes aos critérios da matriz, incluindo negativas de autorização quando houver dados/arquivos. Dados de teste ficam no ambiente definido para validação, nunca disfarçados de dados reais no Dashboard. Uma revisão por outra sessão é necessária antes da integração.

Ao concluir, entregue IDs atendidos, arquivos e contratos alterados, migrations/grants/policies propostos, commit, testes com resultados, limitações, reversão e instruções de integração. Não declare critérios não testados como aprovados. Se houver tela entregável, forneça a C0 o endereço verificado e o roteiro para validação do usuário. Atualize a matriz sem apagar a redação original.

## Comando de início para C0

Coordene a execução do pacote audita-plano-execucao. Comece por B00 e B01. Consulte a versão atual antes de qualquer implementação, concilie as dez migrations de checklist presentes no banco e ausentes no código consultado e registre D01–D11. Produza baseline, decisões, contratos e quadro de responsabilidade. Só libere um bloco quando seus pré-requisitos estiverem concluídos. Não aplique os 16 blocos de uma vez. Solicite a decisão necessária com alternativas claras quando não houver autorização suficiente e continue o trabalho independente. Para cada entrega navegável, confirme o servidor e envie o link ao usuário.

## B00 — Baseline e conciliação

```text
Execute B00 do plano mestre Audita PRO.
Responsável: C0. Dependências: Nenhuma.
Leia integralmente a seção B00 do plano mestre e filtre a matriz pelos blocos_execucao contendo B00.
Implemente todos os itens normativos aplicáveis dessas linhas, incluindo requisitos compartilhados com outros blocos sob o contrato aprovado. Critérios marcados B14/B15 são verificados novamente na integração.
Consulte os critérios originais vinculados a B00 e preserve as propostas ainda condicionais. Referências históricas não são comandos para recriar módulos já existentes.
Entregue o resultado e os critérios de saída especificados para B00, seguindo o comando comum deste arquivo.
```

## B01 — Decisões e contratos

```text
Execute B01 do plano mestre Audita PRO.
Responsável: C0 + C1. Dependências: B00.
Leia integralmente a seção B01 do plano mestre e filtre a matriz pelos blocos_execucao contendo B01.
Implemente todos os itens normativos aplicáveis dessas linhas, incluindo requisitos compartilhados com outros blocos sob o contrato aprovado. Critérios marcados B14/B15 são verificados novamente na integração.
Consulte os critérios originais vinculados a B01 e preserve as propostas ainda condicionais. Referências históricas não são comandos para recriar módulos já existentes.
Entregue o resultado e os critérios de saída especificados para B01, seguindo o comando comum deste arquivo.
```

## B02 — Perfis e autorização

```text
Execute B02 do plano mestre Audita PRO.
Responsável: C1. Dependências: B01.
Leia integralmente a seção B02 do plano mestre e filtre a matriz pelos blocos_execucao contendo B02.
Implemente todos os itens normativos aplicáveis dessas linhas, incluindo requisitos compartilhados com outros blocos sob o contrato aprovado. Critérios marcados B14/B15 são verificados novamente na integração.
Consulte os critérios originais vinculados a B02 e preserve as propostas ainda condicionais. Referências históricas não são comandos para recriar módulos já existentes.
Entregue o resultado e os critérios de saída especificados para B02, seguindo o comando comum deste arquivo.
```

## B03 — Identidades, estados e métricas

```text
Execute B03 do plano mestre Audita PRO.
Responsável: C1. Dependências: B01; integrar após B02.
Leia integralmente a seção B03 do plano mestre e filtre a matriz pelos blocos_execucao contendo B03.
Implemente todos os itens normativos aplicáveis dessas linhas, incluindo requisitos compartilhados com outros blocos sob o contrato aprovado. Critérios marcados B14/B15 são verificados novamente na integração.
Consulte os critérios originais vinculados a B03 e preserve as propostas ainda condicionais. Referências históricas não são comandos para recriar módulos já existentes.
Entregue o resultado e os critérios de saída especificados para B03, seguindo o comando comum deste arquivo.
```

## B04 — Navegação e Meu Perfil

```text
Execute B04 do plano mestre Audita PRO.
Responsável: C2. Dependências: B02.
Leia integralmente a seção B04 do plano mestre e filtre a matriz pelos blocos_execucao contendo B04.
Implemente todos os itens normativos aplicáveis dessas linhas, incluindo requisitos compartilhados com outros blocos sob o contrato aprovado. Critérios marcados B14/B15 são verificados novamente na integração.
Consulte os critérios originais vinculados a B04 e preserve as propostas ainda condicionais. Referências históricas não são comandos para recriar módulos já existentes.
Entregue o resultado e os critérios de saída especificados para B04, seguindo o comando comum deste arquivo.
```

## B05 — Biblioteca corporativa

```text
Execute B05 do plano mestre Audita PRO.
Responsável: C2 + C1. Dependências: B02 B03 B04.
Leia integralmente a seção B05 do plano mestre e filtre a matriz pelos blocos_execucao contendo B05.
Implemente todos os itens normativos aplicáveis dessas linhas, incluindo requisitos compartilhados com outros blocos sob o contrato aprovado. Critérios marcados B14/B15 são verificados novamente na integração.
Consulte os critérios originais vinculados a B05 e preserve as propostas ainda condicionais. Referências históricas não são comandos para recriar módulos já existentes.
Entregue o resultado e os critérios de saída especificados para B05, seguindo o comando comum deste arquivo.
```

## B06 — Identificação, FPA e critérios

```text
Execute B06 do plano mestre Audita PRO.
Responsável: C3 + C1. Dependências: B02 B03.
Leia integralmente a seção B06 do plano mestre e filtre a matriz pelos blocos_execucao contendo B06.
Implemente todos os itens normativos aplicáveis dessas linhas, incluindo requisitos compartilhados com outros blocos sob o contrato aprovado. Critérios marcados B14/B15 são verificados novamente na integração.
Consulte os critérios originais vinculados a B06 e preserve as propostas ainda condicionais. Referências históricas não são comandos para recriar módulos já existentes.
Entregue o resultado e os critérios de saída especificados para B06, seguindo o comando comum deste arquivo.
```

## B07 — Cronograma e continuidade

```text
Execute B07 do plano mestre Audita PRO.
Responsável: C3 + C1. Dependências: B06.
Leia integralmente a seção B07 do plano mestre e filtre a matriz pelos blocos_execucao contendo B07.
Implemente todos os itens normativos aplicáveis dessas linhas, incluindo requisitos compartilhados com outros blocos sob o contrato aprovado. Critérios marcados B14/B15 são verificados novamente na integração.
Consulte os critérios originais vinculados a B07 e preserve as propostas ainda condicionais. Referências históricas não são comandos para recriar módulos já existentes.
Entregue o resultado e os critérios de saída especificados para B07, seguindo o comando comum deste arquivo.
```

## B08 — Emissão documental compartilhada

```text
Execute B08 do plano mestre Audita PRO.
Responsável: C3 + C1. Dependências: B02 B03; contrato B01.
Leia integralmente a seção B08 do plano mestre e filtre a matriz pelos blocos_execucao contendo B08.
Implemente todos os itens normativos aplicáveis dessas linhas, incluindo requisitos compartilhados com outros blocos sob o contrato aprovado. Critérios marcados B14/B15 são verificados novamente na integração.
Consulte os critérios originais vinculados a B08 e preserve as propostas ainda condicionais. Referências históricas não são comandos para recriar módulos já existentes.
Entregue o resultado e os critérios de saída especificados para B08, seguindo o comando comum deste arquivo.
```

## B09 — Publicação do Plano

```text
Execute B09 do plano mestre Audita PRO.
Responsável: C3. Dependências: B06 B07 B08.
Leia integralmente a seção B09 do plano mestre e filtre a matriz pelos blocos_execucao contendo B09.
Implemente todos os itens normativos aplicáveis dessas linhas, incluindo requisitos compartilhados com outros blocos sob o contrato aprovado. Critérios marcados B14/B15 são verificados novamente na integração.
Consulte os critérios originais vinculados a B09 e preserve as propostas ainda condicionais. Referências históricas não são comandos para recriar módulos já existentes.
Entregue o resultado e os critérios de saída especificados para B09, seguindo o comando comum deste arquivo.
```

## B10 — Conteúdo do RDA

```text
Execute B10 do plano mestre Audita PRO.
Responsável: C3 + C1. Dependências: B03 B07 B09.
Leia integralmente a seção B10 do plano mestre e filtre a matriz pelos blocos_execucao contendo B10.
Implemente todos os itens normativos aplicáveis dessas linhas, incluindo requisitos compartilhados com outros blocos sob o contrato aprovado. Critérios marcados B14/B15 são verificados novamente na integração.
Consulte os critérios originais vinculados a B10 e preserve as propostas ainda condicionais. Referências históricas não são comandos para recriar módulos já existentes.
Entregue o resultado e os critérios de saída especificados para B10, seguindo o comando comum deste arquivo.
```

## B11 — Fechamento e retificação do RDA

```text
Execute B11 do plano mestre Audita PRO.
Responsável: C3 + C1. Dependências: B10 B08.
Leia integralmente a seção B11 do plano mestre e filtre a matriz pelos blocos_execucao contendo B11.
Implemente todos os itens normativos aplicáveis dessas linhas, incluindo requisitos compartilhados com outros blocos sob o contrato aprovado. Critérios marcados B14/B15 são verificados novamente na integração.
Consulte os critérios originais vinculados a B11 e preserve as propostas ainda condicionais. Referências históricas não são comandos para recriar módulos já existentes.
Entregue o resultado e os critérios de saída especificados para B11, seguindo o comando comum deste arquivo.
```

## B12 — PDF e distribuição do RDA

```text
Execute B12 do plano mestre Audita PRO.
Responsável: C3 + C1. Dependências: B11 B02 B08.
Leia integralmente a seção B12 do plano mestre e filtre a matriz pelos blocos_execucao contendo B12.
Implemente todos os itens normativos aplicáveis dessas linhas, incluindo requisitos compartilhados com outros blocos sob o contrato aprovado. Critérios marcados B14/B15 são verificados novamente na integração.
Consulte os critérios originais vinculados a B12 e preserve as propostas ainda condicionais. Referências históricas não são comandos para recriar módulos já existentes.
Entregue o resultado e os critérios de saída especificados para B12, seguindo o comando comum deste arquivo.
```

## B13 — Dashboards por perfil

```text
Execute B13 do plano mestre Audita PRO.
Responsável: C2 + C1. Dependências: B02 B03 B09 B12.
Leia integralmente a seção B13 do plano mestre e filtre a matriz pelos blocos_execucao contendo B13.
Implemente todos os itens normativos aplicáveis dessas linhas, incluindo requisitos compartilhados com outros blocos sob o contrato aprovado. Critérios marcados B14/B15 são verificados novamente na integração.
Consulte os critérios originais vinculados a B13 e preserve as propostas ainda condicionais. Referências históricas não são comandos para recriar módulos já existentes.
Entregue o resultado e os critérios de saída especificados para B13, seguindo o comando comum deste arquivo.
```

## B14 — Integração e regressão

```text
Execute B14 do plano mestre Audita PRO.
Responsável: C0 + revisor. Dependências: B04 a B13.
Leia integralmente a seção B14 do plano mestre e filtre a matriz pelos blocos_execucao contendo B14.
Implemente todos os itens normativos aplicáveis dessas linhas, incluindo requisitos compartilhados com outros blocos sob o contrato aprovado. Critérios marcados B14/B15 são verificados novamente na integração.
Consulte os critérios originais vinculados a B14 e preserve as propostas ainda condicionais. Referências históricas não são comandos para recriar módulos já existentes.
Entregue o resultado e os critérios de saída especificados para B14, seguindo o comando comum deste arquivo.
```

## B15 — Liberação e validação

```text
Execute B15 do plano mestre Audita PRO.
Responsável: C0. Dependências: B14.
Leia integralmente a seção B15 do plano mestre e filtre a matriz pelos blocos_execucao contendo B15.
Implemente todos os itens normativos aplicáveis dessas linhas, incluindo requisitos compartilhados com outros blocos sob o contrato aprovado. Critérios marcados B14/B15 são verificados novamente na integração.
Consulte os critérios originais vinculados a B15 e preserve as propostas ainda condicionais. Referências históricas não são comandos para recriar módulos já existentes.
Entregue o resultado e os critérios de saída especificados para B15, seguindo o comando comum deste arquivo.
```

## Quadro de acompanhamento sugerido

| Bloco | Dono | Commit-base | Branch | Arquivos reservados | Decisões pendentes | Testado | Validado pelo usuário |
|---|---|---|---|---|---|---|
| B00 | C0 | A definir em B00 | A definir | A definir | Consultar plano | Não | Não |
| B01 | C0 + C1 | A definir em B00 | A definir | A definir | Consultar plano | Não | Não |
| B02 | C1 | A definir em B00 | A definir | A definir | Consultar plano | Não | Não |
| B03 | C1 | A definir em B00 | A definir | A definir | Consultar plano | Não | Não |
| B04 | C2 | A definir em B00 | A definir | A definir | Consultar plano | Não | Não |
| B05 | C2 + C1 | A definir em B00 | A definir | A definir | Consultar plano | Não | Não |
| B06 | C3 + C1 | A definir em B00 | A definir | A definir | Consultar plano | Não | Não |
| B07 | C3 + C1 | A definir em B00 | A definir | A definir | Consultar plano | Não | Não |
| B08 | C3 + C1 | A definir em B00 | A definir | A definir | Consultar plano | Não | Não |
| B09 | C3 | A definir em B00 | A definir | A definir | Consultar plano | Não | Não |
| B10 | C3 + C1 | A definir em B00 | A definir | A definir | Consultar plano | Não | Não |
| B11 | C3 + C1 | A definir em B00 | A definir | A definir | Consultar plano | Não | Não |
| B12 | C3 + C1 | A definir em B00 | A definir | A definir | Consultar plano | Não | Não |
| B13 | C2 + C1 | A definir em B00 | A definir | A definir | Consultar plano | Não | Não |
| B14 | C0 + revisor | A definir em B00 | A definir | A definir | Consultar plano | Não | Não |
| B15 | C0 | A definir em B00 | A definir | A definir | Consultar plano | Não | Não |

## Registro obrigatório de passagem entre sessões

```text
BLOCO:
FONTE/IDs/LINHAS COBERTOS:
COMMIT-BASE / COMMIT-ENTREGA:
BRANCH / CHECKOUT:
CONTRATOS CONSUMIDOS E ALTERADOS:
ARQUIVOS RESERVADOS/LIBERADOS:
MIGRATIONS E ORDEM PROPOSTA:
DECISÕES APLICADAS:
TESTES EXECUTADOS / RESULTADOS / EVIDÊNCIAS:
CRITÉRIOS AINDA NÃO TESTADOS:
INTEGRAÇÕES AFETADAS:
PENDÊNCIAS E PRÓXIMO RESPONSÁVEL:
REVERSÃO SEM PERDA DOCUMENTAL:
URL VERIFICADA E ROTEIRO DE VALIDAÇÃO:
```

## Regras para integração

1. C0 compara o commit-base com a versão integrada atual antes de aceitar o bloco.
2. Se outra sessão alterou contrato, função ou arquivo comum, rebase/merge deve ser revisado e os testes dependentes repetidos. Nunca usar sobrescrita automática de conflito.
3. C1 entrega migrations pequenas por responsabilidade; C0 verifica sequência e estado remoto. Não editar migration já aplicada para mudar o passado.
4. Aplicar primeiro extensões compatíveis, depois funções/backend, consumidores e liberação da interface. A etapa exata depende do contrato; registrar no bloco.
5. Nenhum participante aplica migrations concorrentes ao mesmo projeto Supabase.
6. Entrega de um bloco não equivale a validação de todos os outros; atualizar a matriz e aguardar os pré-requisitos.
7. O relatório ao usuário sempre separa implementado, testado e aguardando validação.
