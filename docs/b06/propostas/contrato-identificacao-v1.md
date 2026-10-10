# B06 — proposta de contrato de identificação v1

Situação: **proposta não aplicada**. O contrato é aditivo e evita redefinir os contratos B02/B03 encontrados no ambiente conectado.

## RPC

`public.audit_identification(command text, payload jsonb)` aceita:

- `capabilities`, sem `audit_id`: anuncia `contract_version: 1`, comandos e campos;
- `detail`, com `{ "audit_id": "uuid" }`: retorna apenas ao condutor da auditoria;
- `save`, com os campos abaixo, `audit_id` e `expected_lock_version`.

O frontend deve habilitar a edição somente após `capabilities.contract_version === 1`. Ausência da função ou outra versão mantém a tela compatível em modo de leitura.

## Payload de gravação

| Campo | Tipo | Regra |
|---|---|---|
| `audit_id` | UUID | obrigatório |
| `expected_lock_version` | inteiro | obrigatório; evita sobrescrita concorrente |
| `unit_id` | UUID/null | unidade ativa da organização |
| `title` | texto | obrigatório, ao menos 2 caracteres |
| `objective` | texto/null | opcional |
| `scope` | texto/null | pode permanecer incompleto no rascunho; obrigatório na validação futura |
| `criterion_ids` | UUID[] JSON | ao menos um critério ativo; imutável por este RPC após aplicar checklist/perguntas |
| `purpose` | texto | finalidade declarada |
| `party` | texto | `first`, `second` ou `third` |
| `modality` | texto | `presential`, `remote` ou `hybrid` |
| `location`, `criteria` | texto/null | opcionais |
| `evaluation_type` | texto/null | `initial`, `certification`, `maintenance`, `recertification`, `follow_up`, `diagnostic` ou `other` |
| `evaluation_other` | texto/null | descrição de `other`; obrigatória apenas na validação futura |
| `declared_start_date`, `declared_end_date` | data/null | período informado; fim não antecede início |
| `participants_text` | texto/null | identificação textual solicitada; não concede acesso |
| `comments` | texto/null | comentários do cabeçalho |

`participants_text` é conteúdo documental. Equipe, autorização, presença e signatários continuam nos registros B02 próprios.

Nesta versão independente, `save` só aceita auditoria em rascunho sem plano publicado. Alterar o cabeçalho publicado dependerá da integração futura que congele cabeçalho e equipe em uma revisão do plano. Trocar critérios quando já há checklist aplicado ou avaliações também exige esse fluxo próprio, para não deixar o escopo inconsistente.

## Resposta

`save` retorna `{ "contract_version": 1, "audit_id": "uuid", "lock_version": 7 }`. `detail` retorna os mesmos campos sob `identification`.

## FPA fora deste contrato

Nenhum campo FPA integra a gravação de identificação. A fonte local ainda classifica como proposta as regras que exigem FPA para validar o plano. Até existir decisão aprovada, B06 não deve bloquear `plan_publish`, inventar recebimento para planos antigos ou expor FPA na projeção empresarial.

## Encapsulamento e permissões

O wrapper público é SECURITY INVOKER e precisa que authenticated tenha EXECUTE no helper privado. O helper privado repete autenticação e autorização por recurso e usa search_path vazio. Não remover esse grant isoladamente: isso impede a chamada do wrapper. O schema private não deve ser exposto na Data API. Validar os grants e seu caminho completo em ambiente isolado antes de aplicar.
