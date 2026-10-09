# B06 — Critérios de implementação e aceite

## Escopo obrigatório

- Gerar códigos automáticos, únicos e imutáveis para cliente e auditoria, com migração controlada de clientes sem código e preservação dos códigos legados.
- Completar o cabeçalho com cliente, código e endereço/unidade; período declarado; critérios e respectivas edições; natureza; tipo de avaliação e descrição de “Outra”; objetivo; código da auditoria; equipe habilitada com o condutor; outros participantes textuais; comentários; escopo; e modalidade já existente.
- Permitir salvar rascunho incompleto. Exigir os campos obrigatórios somente na validação e indicar claramente cada pendência.
- Nos campos “Outros participantes em nome da AUDITA” e “Comentários”, aceitar `N/A` e manter visível a orientação *Caso não se aplique, informar “N/A”.*, em itálico, com contraste legível e sem depender de placeholder.
- Manter natureza, tipo de avaliação, norma/critério e modalidade como conceitos distintos. Não converter valores legados sem correspondência confiável nem antecipar resultado de certificação.
- Reutilizar `criterion_ids`, componentes e `audit_checklists` versionados. Permitir vários critérios/modelos na mesma auditoria, preservando origem, edição e identidade de requisitos homônimos.
- Não multiplicar o escopo ao copiar uma atividade. Alteração de catálogo/modelo publicado não muda o que já foi aplicado. Retirada de critério após o início exige revisão de escopo e preserva avaliações e evidências.
- Implementar FPA privado por auditoria com os estados: não solicitado; solicitado; recebido; em análise; complementação solicitada; analisado — suficiente para planejar.
- Registrar no FPA destinatário, prazo, autoria e data de cada ação, arquivo/resposta real, histórico de complementações, análise e versão usada. FPA de outra auditoria não satisfaz a atual.
- Permitir trabalho no rascunho antes da suficiência do FPA e bloquear a validação final enquanto ele não tiver sido solicitado, recebido e analisado como suficiente pelo condutor.
- No piloto, o condutor registra o recebimento externo. Não criar permissão de upload para Participante.
- Manter FPA fora do PDF e do acesso público do plano. Não inventar FPA para documentos históricos.

## Critérios de aceite originais

Todos permanecem com resultado **Pendente / não executado** até haver implementação integrada e teste.

| ID | Critério original integral | Responsabilidade em B06 |
|---|---|---|
| PA-01 | Criar duas auditorias do mesmo cliente → Código do cliente permanece; códigos de auditoria são distintos | Integração com B03 e D09 |
| PA-02 | Cadastro simultâneo/cancelamento → Nenhum código duplicado, alterado manualmente ou reutilizado | Integração com B03 e D09 |
| PA-03 | Selecionar cliente → Código e endereço aparecem automaticamente | Direta |
| PA-04 | Salvar rascunho incompleto → Permitido; validar continua bloqueado com indicação dos campos | Direta; validação final pertence a B09 |
| PA-05 | Preencher cabeçalho → Todos os campos solicitados presentes; N/A aceito nos dois campos indicados | Direta |
| PA-06 | Selecionar ISO 14001 + ISO 45001 → Uma auditoria, dois critérios e requisitos sem colisão de numeração | Direta |
| PA-11 | FPA não recebido ou insuficiente → Impedir validação final, mantendo possibilidade de trabalhar no rascunho | Direta; validação final pertence a B09 |
| PA-12 | FPA analisado → Versão usada e autoria da análise vinculadas à revisão do plano | Direta; revisão/publicação pertence a B09 |
| PA-19 | Auditor de apoio designado na linha → Nome aparece; não ganha permissão de conduzir/editar automaticamente | Integração com D06; edição de linha pertence a B07 |
| PA-24 | Operação com único Administrador/condutor → Elaboração, validação e execução possíveis sem outro aprovador | Integração; validação/publicação pertence a B09 |
| PER-03 | Auditor Líder cria auditoria, planeja, preenche checklist e valida relatórios diário e de encerramento nas auditorias sob sua responsabilidade. | Integração com B02; sem certificar fluxos posteriores |
| PER-04 | Auditor acompanha auditorias da equipe e consulta os relatórios permitidos, mas não cria, conduz, assume responsabilidade ou valida, inclusive por acesso direto. | Integração com B02 e D06 |

## Dependências e decisões

- **B02:** autorização efetiva no servidor e vínculos de equipe. B06 deve respeitar a matriz de perfis entregue por B02; a integração ainda precisa ser testada depois que o código de B02 for incorporado a esta base.
- **B03:** contratos de códigos e dados consolidados. PA-01 e PA-02 dependem da implementação de B03 incorporada e da confirmação do formato/transição de códigos em D09.
- **D06:** apoio não escreve nem mantém rascunhos; há um responsável; Admin controla concessões e transferências; Líder escolhe apoio habilitado; revogação prevalece. B06 só seleciona e exibe equipe compatível com esses vínculos.
- **D09:** FPA mínimo é o arquivo recebido pelo condutor, sem upload do cliente no piloto. Novos códigos seguem o formato confirmado; códigos antigos são preservados. FPA é exigido para novas validações, sem criar histórico fictício.

## Limites deste bloco

- **B07:** editor do cronograma, linhas, ordem, duplicação, reagendamento, continuidade e auditores por atividade. B06 fornece a equipe e os critérios; não implementa essas operações.
- **B08:** serviço compartilhado de emissão, armazenamento, integridade e retomada de PDF. B06 apenas garante que o FPA continue privado e separado.
- **B09:** validação transacional, congelamento/versionamento do plano, geração do PDF, publicação e acesso do cliente. B06 fornece dados e bloqueios prévios, sem declarar plano validado ou publicado.

## Inspeção da base atual

- Já existem seleção visual de critérios adicionais, `audits.criterion_ids`, checklists vinculados a revisões e testes de composição que verificam duas revisões e perguntas homônimas distintas. Isso é base parcial para PA-06, mas o aceite continua pendente porque B06 ainda não foi integrado nem testado ponta a ponta.
- A criação na cópia Git antiga gera código de auditoria `AUD-` com trecho aleatório e oferece organização, unidade, objetivo, escopo, critério principal/adicionais, parte e modalidade. Não foi identificado código automático de cliente, contrato de imutabilidade/transição completo nem todos os campos do cabeçalho exigido.
- Não foi identificada estrutura de FPA com estados, arquivo, análise, autoria, versão e bloqueio de validação.
- O fluxo atual contém publicação/impressão de plano e versões existentes; eles pertencem a B09/B08 e não constituem aceite de B06.
- Como B02 e B03 foram concluídos fora desta base e ainda não estão integrados, nenhum critério compartilhado foi marcado como aprovado.

## Estado inicial da inspeção (histórico)

- Implementação B06: **Pendente**.
- Testes B06: **Pendentes / não executados**.
- Aceites aprovados: **nenhum**.

## Atualização da entrega

O estado acima registra a inspeção inicial. Consulte [entrega.md](entrega.md) para o incremento implementado e os resultados locais. B03 está concluído conforme informação do usuário; não reproduzir a geração antiga de códigos desta árvore. Nenhum aceite integrado completo foi aprovado nesta sessão.
