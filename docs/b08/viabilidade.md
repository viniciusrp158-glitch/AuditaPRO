# B08 — Viabilidade técnica e prova exigida

Revisão: 10/10/2026. **Estudo documental; biblioteca candidata, sem homologação de runtime.** Não acompanha renderer, PDF de demonstração, benchmark ou migration. Nenhum teste funcional de emissão foi executado nesta preparação.

## Escolha recomendada para o primeiro ensaio

Avaliar **pdf-lib** primeiro no runtime de homologação já utilizado pelo projeto. A documentação oficial declara JavaScript sem dependências nativas, suporte a Deno/Node, desenho de texto/imagens/vetores e incorporação de fontes. Isso torna a biblioteca uma candidata plausível; não comprova desempenho nem compatibilidade de todo o pipeline no Supabase Edge. A paginação de tabelas extensas e o fluxo de texto exigem um componente de layout próprio e testes específicos. Evitar assumir que desenhar texto em coordenadas resolve quebra de células ou títulos órfãos.

Como alternativa, avaliar **pdfmake**, cuja documentação oficial descreve execução no servidor com Node e configuração de fontes. O exemplo em Node não comprova execução em Edge/Deno. Se a alternativa for necessária, validar a versão escolhida, suas dependências e o custo de integração antes de mudar runtime.

| Candidato | Benefício a investigar | Risco a resolver no ensaio |
|---|---|---|
| pdf-lib no runtime existente | Controle de desenho e recursos, sem exigir navegador de impressão | Implementar e verificar layout, imagens e orçamento de CPU/memória |
| pdfmake no servidor compatível | Alternativa para composição documental | Demonstrar compatibilidade real e manutenção de fontes/dependências |
| Geração atual no navegador | Referência visual e diagnóstico do legado | Não oferece, por si só, emissão durável no servidor nem artefato oficial persistido |

Não adotar serviço pago ou novo provedor por padrão. A decisão definitiva exige evidência do ensaio, versão fixa das dependências, lockfile, licença das fontes e registro da versão do motor. Este estudo não escolhe uma versão de biblioteca como homologada.

## Limites e recursos

Consultar os limites atuais do ambiente/plano em uso: memória, CPU, duração máxima, tamanho e concorrência. CPU e tempo total de execução são medidas diferentes; aguardar Storage não elimina o orçamento de renderização. Trabalhos retomáveis precisam de pedido persistente e posse de tentativa conforme o contrato; ampliar espera de uma requisição não substitui esse controle.

O inventário de 09/10/2026 encontrou `audit-reports` privado, PDF, limite de **20.971.520 bytes (20 MiB)**. Confirmar novamente antes da implementação. Não copiar para o PDF final o limite de anexos de evidência. Definir comportamento explícito para arquivos acima do limite, sem reduzir qualidade ou omitir conteúdo silenciosamente.

O bucket de evidências aceita formatos além de PNG/JPEG, incluindo WebP. O pipeline precisa testar cada formato permitido, orientar conversão validada quando necessária e fixar o recurso derivado no manifesto. Testar orientação EXIF, transparência, imagens descomprimidas grandes e proporções extremas. Não presumir que todos os formatos do bucket são aceitos diretamente pelo renderer.

## Protocolo reproduzível para Codex 01

1. Recuperar B01/D08 e a baseline integrada. Registrar runtime, plano/limites, versões de biblioteca, fontes licenciadas e template.
2. Construir fixtures sintéticas de Plano/RDA pequeno, representativo e extenso: acentos, nomes longos, tabelas com células maiores que uma página, fotos selecionadas, gráficos, seções vazias e notas finais completas. Registrar volume de cada fixture; não usar dados pessoais reais.
3. Executar no ambiente de homologação de destino. Medir separadamente geração, upload e confirmação; registrar páginas, bytes, duração, CPU e pico de memória quando observável. Identificar métricas indisponíveis; memória ao final do processo não equivale a pico.
4. Inspecionar visualmente todas as páginas e extrair texto para detectar omissões. Conferir fontes incorporadas, paginação, margens, tabelas e leitura monocromática. Recusar truncamento de texto como solução de layout.
5. Repetir com falhas de recurso, renderização, upload e confirmação; duas tentativas concorrentes; acesso de outra organização. Aplicar os 16 cenários de `criterios-e-testes.md`.
6. Preservar o PDF íntegro confirmado e conferir seu hash em downloads posteriores. Alterar cadastros de origem para demonstrar preservação dos bytes emitidos. Não confundir isso com igualdade entre duas renderizações independentes.
7. Anexar resultados, logs sanitizados, PDFs sintéticos e decisão fundamentada. Se exceder orçamento, registrar o limite medido e avaliar alternativa com Codex 01 antes de ampliar infraestrutura.

## Resultado desta preparação

| Evidência | Situação |
|---|---|
| Documentação primária dos candidatos consultada | Concluída |
| Diagnóstico do código e inventário limitado de metadados | Documentado em `diagnostico.md` |
| Geração local ou no runtime Supabase | Não executada como prova validada |
| Desempenho, compatibilidade completa e layout final | Pendentes de ensaio |
| Templates AUDITA aprovados e integração B09/B11/B12 | Dependem dos contratos/decisões e implementação dos blocos donos |

**Conclusão:** é possível iniciar a implementação experimental do motor, mas não declarar sua viabilidade operacional comprovada ou B08 concluído. O primeiro marco técnico do Codex 01 deve ser o ensaio acima.

## Fontes primárias consultadas em 10/10/2026

- PDF-LIB — recursos e runtimes: https://pdf-lib.js.org/
- pdfmake — execução no servidor: https://pdfmake.github.io/docs/0.3/getting-started/server-side/
- Supabase — limites de Edge Functions: https://supabase.com/docs/guides/functions/limits

As recomendações de arquitetura e os ensaios propostos são análise aplicada ao Audita PRO; não são garantias dos fornecedores.
