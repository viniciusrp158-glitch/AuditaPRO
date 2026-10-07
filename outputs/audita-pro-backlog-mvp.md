# Audita PRO — Backlog do MVP

**Versão:** 0.1 — ordenação inicial  
**Base:** Escopo técnico v0.2 e desenho técnico v0.1

## Prioridade

- **P0 — fundação:** necessário antes de inserir dados reais.
- **P1 — piloto:** necessário para conduzir a primeira auditoria.
- **P2 — melhoria:** importante, mas pode vir depois do primeiro piloto.

## Épicos e histórias

### EPIC 0 — Ambientes, identidade e segurança (P0)

| ID | História | Critérios principais | Dependências |
|---|---|---|---|
| FND-01 | Como administrador técnico, quero ambientes separados de desenvolvimento, homologação e produção. | Credenciais e dados separados; nenhum segredo privilegiado no cliente. | Projeto Supabase |
| FND-02 | Como usuário, quero criar/ativar minha conta e recuperar o acesso. | E-mail verificado; recuperação segura; sessão encerrável. | Auth |
| FND-03 | Como Administrador da plataforma, quero conceder papel global de forma controlada. | Papel não pode ser concedido por autoinscrição nem por perfil editável pelo usuário. | Auth e operação administrativa |
| FND-04 | Como responsável técnico, quero que o acesso aos dados seja validado no banco. | RLS habilitada em tabelas de negócio; acesso entre empresas negado por padrão. | Esquema inicial |
| FND-05 | Como usuário, quero enviar documento de identificação em área privada. | Arquivo privado; acesso do próprio usuário e Administrador; envio não libera acesso automaticamente. | Membership e Storage |
| FND-06 | Como Administrador, quero aprovar ou recusar identificação. | Registrar decisor, data e motivo; bloquear módulos até aprovação; usuário vê o estado. | FND-05 |
| FND-07 | Como operador, quero backup e recuperação documentados antes de dados reais. | Procedimento de backup/restore registrado e ambiente não produtivo verificado. | Supabase |
| FND-08 | Como Administrador da plataforma, quero consultar o histórico detalhado de alterações. | Registrar valores anteriores e novos dos campos seguros em operações relevantes; registrar hashes para textos livres; filtrar por módulo; manter leitura protegida. | FND-04 |

### EPIC 1 — Empresas e usuários (P0)

| ID | História | Critérios principais | Dependências |
|---|---|---|---|
| ORG-01 | Como Administrador, quero cadastrar empresa com nome e CNPJ. | Validar formato e unicidade; pesquisar por nome/CNPJ; inativar sem apagar histórico. | FND-04 |
| ORG-02 | Como Administrador, quero manter unidades da empresa. | Unidade ligada a uma empresa; status ativo/inativo. | ORG-01 |
| ORG-03 | Como Administrador, quero consultar a ficha de empresa. | Mostrar dados, unidades, usuários vinculados e auditorias/histórico disponíveis. | ORG-01, ORG-02 |
| USR-01 | Como Administrador, quero cadastrar um usuário e vinculá-lo a empresa/unidade, cargo e perfil. | Campos obrigatórios validados; status ativo/inativo; vínculo rastreável. | ORG-01 |
| USR-02 | Como usuário, quero entrar no onboarding e enviar minha identificação. | Usuário só acessa onboarding até a aprovação exigida; upload privado. | FND-02, FND-05 |
| USR-03 | Como Administrador, quero analisar identificação. | Aprovar/recusar com motivo; decisão aparece ao usuário e fica no histórico. | USR-02 |
| ACL-01 | Como Administrador, quero configurar cargos e perfis-base. | Perfis iniciais Auditor, Gestor, Consulta, Personalizado; mudanças não apagam histórico. | FND-04 |
| ACL-02 | Como Administrador, quero personalizar permissões individuais. | Sobrescritas permitidas por usuário e registradas; validação no servidor/banco. | ACL-01 |
| ACL-03 | Como Administrador, quero buscar usuários por empresa. | Busca e filtros por unidade, cargo, estado de acesso e aprovação documental. | USR-01 |

### EPIC 2 — Modelos e planejamento da auditoria (P1)

| ID | História | Critérios principais | Dependências |
|---|---|---|---|
| AUD-01 | Como Administrador, quero criar modelos de checklist. | Seções e requisitos editáveis; responsável do Audita PRO fornece conteúdo. | ACL-01 |
| AUD-02 | Como Administrador, quero publicar revisões de checklist. | Revisões anteriores preservadas; nova auditoria seleciona revisão específica. | AUD-01 |
| AUD-03 | Como Auditor Líder, quero criar uma auditoria para empresa/unidade. | Código único, escopo, data, modelos e status; equipe/participantes atribuídos. | ORG-03, USR-01, AUD-02 |
| AUD-04 | Como Auditor Líder, quero definir signatários da auditoria. | Somente selecionados são obrigatórios para confirmação de ciência. | AUD-03 |
| SCH-01 | Como Auditor Líder, quero montar cronograma por dia. | Horários, processo, atividade, requisito e responsável editáveis antes da execução. | AUD-03 |
| SCH-02 | Como Auditor, quero ver meu cronograma do dia. | Só auditorias atribuídas; visão clara de planejado e estado. | SCH-01 |

### EPIC 3 — Execução, achados e transferência (P1)

| ID | História | Critérios principais | Dependências |
|---|---|---|---|
| EXE-01 | Como Auditor, quero registrar resultado por requisito. | Resultado, observação, processo, autor e horário; alteração fica registrada. | AUD-03 |
| EXE-02 | Como Auditor, quero anexar evidências. | Arquivos privados ligados a auditoria e requisito/achado; auditoria do upload. | EXE-01 |
| NC-01 | Como Auditor, quero criar não conformidade. | Identificador, requisito, processo, descrição, classificação e estado. | EXE-01 |
| ACT-01 | Como Auditor, quero registrar plano de ação. | Ação, responsável, prazo e estado ligados ao achado. | NC-01 |
| SCH-03 | Como Auditor Líder, quero transferir etapa pendente a outro dia. | Preservar origem, destino, motivo, autor e horário; refletir nos dois relatórios diários. | SCH-01 |
| EXE-03 | Como Auditor Líder, quero revisar atividade do dia. | Horários, etapas concluídas e pendências consistentes; trilha por evento. | EXE-01, SCH-03 |

### EPIC 4 — Relatório, ciência e arquivo GOV (P1)

| ID | História | Critérios principais | Dependências |
|---|---|---|---|
| REP-01 | Como Auditor Líder, quero gerar relatório diário dos dados registrados. | Cabeçalho, processos, requisitos, cronograma, achados, observações e ações. | EXE-03 |
| REP-02 | Como Auditor Líder, quero editar texto e observações antes de finalizar. | Campos automáticos editáveis; salvar rascunho; mostrar dados ausentes. | REP-01 |
| REP-03 | Como Auditor Líder, quero finalizar uma versão. | Congelar versão e PDF; avisar sobre etapa pendente; nova correção cria outra versão. | REP-02 |
| REP-04 | Como signatário selecionado, quero confirmar ciência da versão. | Autenticação; versão, usuário e horário registrados; não chamar de assinatura legal. | AUD-04, REP-03 |
| REP-05 | Como Auditor Líder, quero anexar cópia assinada via GOV. | Guardar em Storage privado; registrar autor e data; permitir baixar arquivo. | REP-03 |
| REP-06 | Como Administrador/Auditor Líder, quero arquivar relatório. | Estados de ciência/GOV distintos; arquivo disponível na biblioteca. | REP-04, REP-05 |
| REP-07 | Como participante autorizado, quero localizar relatórios. | Filtros por empresa, auditoria, data e estado; autorização por empresa/auditoria. | REP-06 |
| NOT-01 | Como signatário, quero receber aviso e lembretes de ciência. | E-mail inicial e lembretes em 24/48h; parar após confirmação; registrar falha/envio. | REP-04 |

### EPIC 5 — Piloto e operação (P1)

| ID | História | Critérios principais | Dependências |
|---|---|---|---|
| PIL-01 | Como Administrador, quero preparar dados e checklist do piloto. | Empresa/unidade, usuários aprovados, auditoria e revisão do checklist cadastrados. | EPIC 1–3 |
| PIL-02 | Como equipe do produto, quero revisar permissões e arquivos. | Testes de isolamento entre empresas, storage e acesso móvel antes de dados reais. | FND-04, EPIC 1–4 |
| PIL-03 | Como Auditor Líder, quero conduzir a primeira auditoria na aplicação. | Fluxo completo concluído; problemas anotados; exportação e arquivo revisados. | EPIC 1–4 |
| PIL-04 | Como responsável do produto, quero priorizar feedback do piloto. | Lista de mudanças classificada por bloqueio, importância e esforço. | PIL-03 |

### Depois do MVP (P2)

- Assinatura GOV automatizada ou validação criptográfica, se serviço e requisito forem definidos.
- Requisitos adicionais de competência por cargo.
- Treinamentos SSMA e controle temporário de acesso a cursos.
- Templates de PGR, AET, laudos e outros documentos.
- Operação offline e sincronização.
- Painéis avançados, integrações e identidade visual por cliente.

## Sequência recomendada

1. Fundação e segurança (EPIC 0).
2. Empresas, usuários e aprovação documental (EPIC 1).
3. Checklist, auditoria e cronograma (EPIC 2).
4. Execução e transferência de pendências (EPIC 3).
5. Relatório diário, confirmação e arquivo GOV (EPIC 4).
6. Piloto controlado (EPIC 5).

A assinatura GOV externa, a classificação exata do documento de identificação e o início da retenção de cinco anos ficam como parâmetros/processo operacional até serem definidos.

## Definição de pronto comum

Uma história só estará pronta quando as permissões forem verificadas no backend/banco, os estados de erro e vazio tiverem tratamento, a ação relevante aparecer na trilha de auditoria quando aplicável e os critérios específicos da história forem demonstrados no ambiente de homologação. Nenhuma história libera dados reais antes de revisão do isolamento entre empresas e dos acessos a arquivos.
