// Documento de prova do motor (B08): acentos, nomes longos, tabela extensa com célula maior que uma página,
// imagens (logo PNG e imagem RGBA gerada), gráficos (inclusive vazio), seções vazias explicadas e notas finais.
// Conteúdo sintético: nenhum dado pessoal real.
import type { Block, DocModel } from '../pdf/layout.ts';
import { deflate } from '../pdf/zlib.ts';

const PROCESSOS = ['Compras e qualificação de fornecedores', 'Produção — linha de envase', 'Manutenção preventiva', 'Gestão de documentos',
  'Treinamento e conscientização', 'Ação corretiva e análise de causa', 'Expedição e logística reversa', 'Calibração de instrumentos'];
const FRASES = ['Evidência verificada por amostragem de registros do período.', 'Procedimento revisado e disponível no ponto de uso.',
  'Não foram identificados desvios na amostra avaliada.', 'Registro de treinamento sem assinatura do responsável; ação já iniciada.',
  'Indicadores acompanhados mensalmente em reunião de análise crítica.', 'Calibração vencida em um instrumento secundário (tag INS-0042).'];

export type SpecimenParams = { rows?: number; long_cell?: boolean; photos?: boolean; draft?: boolean };

export function specimen(params: SpecimenParams, ctx: { issued_at: string; version_label: string; code: string }): { doc: DocModel; assets: string[] } {
  const rows = Math.max(0, Math.min(2000, Math.floor(params.rows ?? 120)));
  const blocks: Block[] = [];
  blocks.push({ type: 'heading', text: '1. Identificação' });
  blocks.push({ type: 'fields', columns: 2, items: [
    { label: 'Cliente', value: 'Indústria de Exemplo Ação & Cia. Ltda. — Unidade São João' }, { label: 'Código', value: 'CLI-0001' },
    { label: 'Auditoria', value: ctx.code }, { label: 'Revisão', value: ctx.version_label },
    { label: 'Período', value: '03/11/2026 a 05/11/2026 (dias não consecutivos: 03, 04 e 06)' }, { label: 'Modalidade', value: 'Presencial' },
    { label: 'Critérios', value: 'ISO 9001:2015 · ISO 14001:2015 · Requisitos do cliente (edição 2024)' }, { label: 'Natureza', value: 'Auditoria de 2ª parte' },
  ] });
  blocks.push({ type: 'paragraph', text: [{ text: 'Objetivo: ', bold: true }, 'verificar a conformidade do sistema de gestão com os critérios declarados, considerando acentuação completa — ação, coração, órgão, pôr, avô, à, ü, ç, º, ª, € e “aspas” — e nomes muito longos como ', { text: 'Responsável-Técnico-pela-Qualificação-de-Fornecedores-Estratégicos-da-Unidade-Industrial-Norte', italic: true }, '.'] });
  blocks.push({ type: 'paragraph', italic: true, muted: true, text: 'Comentários: N/A — orientação exibida em itálico, conforme a identificação da auditoria.' });

  blocks.push({ type: 'heading', text: '2. Cronograma e escopo' });
  const tableRows = [];
  for (let i = 0; i < rows; i++) {
    const p = PROCESSOS[i % PROCESSOS.length];
    const note = params.long_cell && i === 3 ? Array.from({ length: 140 }, (_, k) => `Linha ${k + 1} do trabalho restante transferido com origem e motivo preservados.`).join(' ') : FRASES[i % FRASES.length];
    tableRows.push([`${String(i + 1).padStart(3, '0')}`, `${String(3 + (i % 3)).padStart(2, '0')}/11 ${String(8 + (i % 9)).padStart(2, '0')}:00`, p, `Req. ${4 + (i % 7)}.${1 + (i % 5)}`, note]);
  }
  blocks.push({ type: 'table', title: 'Tabela 1 — Atividades programadas', columns: [
    { label: 'Nº', width: 0.07, align: 'right' }, { label: 'Data/hora', width: 0.13 }, { label: 'Processo / área', width: 0.27 },
    { label: 'Requisitos', width: 0.13 }, { label: 'Observações', width: 0.40 }], rows: tableRows });
  blocks.push({ type: 'table', title: 'Tabela 2 — Pendências registradas', columns: [{ label: 'Pendência', width: 0.6 }, { label: 'Responsável', width: 0.4 }], rows: [],
    empty: 'Nenhuma pendência registrada nesta revisão.' });

  blocks.push({ type: 'heading', text: '3. Resultados' });
  blocks.push({ type: 'bars', title: 'Gráfico 1 — Resultado das avaliações do dia', unit: 'itens', items: [
    { label: 'Conforme', value: 55 }, { label: 'Parcialmente conforme', value: 5 }, { label: 'Não conforme', value: 3 },
    { label: 'Não aplicável', value: 7 }, { label: 'Pendente', value: 30 }] });
  blocks.push({ type: 'paragraph', size: 8.8, text: 'Equivalente textual: 55 conformes, 5 parcialmente conformes, 3 não conformes, 7 não aplicáveis e 30 pendentes; execução de 70%.' });
  blocks.push({ type: 'bars', title: 'Gráfico 2 — Processados × pendentes (dia sem avaliações)', items: [], empty: 'Sem avaliações registradas no período: o gráfico não apresenta percentuais.' });

  const assets = ['logo'];
  if (params.photos !== false) {
    blocks.push({ type: 'heading', text: '4. Registros fotográficos' });
    blocks.push({ type: 'image', asset: 'sample', caption: 'Foto 1 — Imagem sintética com transparência (PNG RGBA), proporção preservada.', max_height: 220 });
    blocks.push({ type: 'image', asset: 'logo', caption: 'Foto 2 — Marca disponível no repositório (identidade provisória, D08).', max_height: 90, width_ratio: 0.5 });
    assets.push('sample');
  }
  blocks.push({ type: 'heading', text: '5. Seção sem conteúdo' });
  blocks.push({ type: 'notice', title: 'Seção vazia explicada', text: 'Não houve não conformidades neste dia. A seção permanece no documento para indicar a ausência, sem omissão.' });
  blocks.push({ type: 'page_break' });
  blocks.push({ type: 'heading', text: 'Anexo A — Notas' });
  blocks.push({ type: 'list', ordered: true, items: Array.from({ length: 9 }, (_, i) => `Nota ${i + 1}: texto integral preservado na página final dedicada, sem resumo nem reescrita pelo motor de emissão.`) });
  return {
    assets,
    doc: {
      meta: { title: `Documento de prova do emissor — ${ctx.code} ${ctx.version_label}`, subject: 'Prova do motor de emissão (B08)', author: 'Audita PRO', issued_at: ctx.issued_at },
      header: { title: 'Documento de prova do emissor', subtitle: 'AUDITA — identidade provisória (D08)', right: [ctx.code, ctx.version_label, `Emitido em ${brDate(ctx.issued_at)}`], logo: 'logo' },
      footer: { left: `Audita PRO · ${ctx.code} · ${ctx.version_label} · documento sintético para homologação; não constitui relatório de auditoria.` },
      draft: !!params.draft,
      blocks,
    },
  };
}

export function brDate(iso: string): string {
  const d = new Date(Date.parse(iso) - 3 * 3600000);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${p(d.getUTCDate())}/${p(d.getUTCMonth() + 1)}/${d.getUTCFullYear()} ${p(d.getUTCHours())}:${p(d.getUTCMinutes())}`;
}

// PNG RGBA sintético (gradiente com círculo semitransparente) para provar o caminho com SMask.
export async function samplePng(w = 320, h = 200): Promise<Uint8Array> {
  const raw = new Uint8Array(h * (w * 4 + 1));
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    for (let x = 0; x < w; x++) {
      const o = y * (w * 4 + 1) + 1 + x * 4, dx = x - w / 2, dy = y - h / 2, inside = dx * dx + dy * dy < (h * 0.4) ** 2;
      raw[o] = Math.round((x / w) * 200); raw[o + 1] = Math.round((y / h) * 160); raw[o + 2] = 140; raw[o + 3] = inside ? 140 : 255;
    }
  }
  const chunk = (type: string, data: Uint8Array) => {
    const out = new Uint8Array(12 + data.length), dv = new DataView(out.buffer);
    dv.setUint32(0, data.length); for (let i = 0; i < 4; i++) out[4 + i] = type.charCodeAt(i);
    out.set(data, 8); dv.setUint32(8 + data.length, crc32(out.subarray(4, 8 + data.length)));
    return out;
  };
  const ihdr = new Uint8Array(13); const dv = new DataView(ihdr.buffer);
  dv.setUint32(0, w); dv.setUint32(4, h); ihdr[8] = 8; ihdr[9] = 6;
  const parts = [new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk('IHDR', ihdr), chunk('IDAT', await deflate(raw)), chunk('IEND', new Uint8Array())];
  const out = new Uint8Array(parts.reduce((s, p) => s + p.length, 0)); let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
}

let CRC: Uint32Array | null = null;
function crc32(b: Uint8Array): number {
  if (!CRC) { CRC = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; CRC[n] = c >>> 0; } }
  let c = 0xffffffff; for (const v of b) c = CRC[(c ^ v) & 255] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
