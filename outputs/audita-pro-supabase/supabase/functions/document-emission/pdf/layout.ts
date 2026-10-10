// Motor de composição A4 compartilhado (B08): cabeçalho/rodapé repetidos, "Página X de Y", títulos que não ficam
// órfãos, tabelas com cabeçalho repetido e células que atravessam páginas, imagens proporcionais com legenda,
// gráficos de barras com valores em texto (legíveis em impressão monocromática) e marca d'água de prévia.
import { fontFor, type FontKey, type Line, pdfString, plain, type Rich, TextStats, widthOf, encode, wrap } from './text.ts';
import { displaySize, fmt, ImageRejected, loadImage, type PdfImage, placement } from './images.ts';
import { writePdf } from './writer.ts';
import { sha256Hex } from './zlib.ts';

export const ENGINE_VERSION = 'audita-pdf 1.0.0';
export const PAGE = { w: 595.28, h: 841.89 };
const M = { left: 48, right: 48, top: 36, bottom: 30 };
const HEADER_H = 62, FOOTER_H = 30;
const BODY_TOP = PAGE.h - M.top - HEADER_H;
const BODY_BOTTOM = M.bottom + FOOTER_H;
const CW = PAGE.w - M.left - M.right;
const MAX_PAGES = 600;
const FONT_RES: Record<FontKey, string> = { regular: 'F1', bold: 'F2', italic: 'F3', boldItalic: 'F4' };

export type Column = { label: string; width: number; align?: 'left' | 'center' | 'right' };
export type Block =
  | { type: 'heading'; text: string; level?: 1 | 2 | 3 }
  | { type: 'paragraph'; text: Rich; size?: number; italic?: boolean; bold?: boolean; align?: 'left' | 'center'; muted?: boolean }
  | { type: 'fields'; items: { label: string; value: Rich }[]; columns?: 1 | 2 }
  | { type: 'table'; title?: string; columns: Column[]; rows: Rich[][]; empty?: string; size?: number }
  | { type: 'list'; items: Rich[]; ordered?: boolean }
  | { type: 'image'; asset: string; caption?: string; max_height?: number; width_ratio?: number }
  | { type: 'bars'; title?: string; items: { label: string; value: number; display?: string }[]; max?: number; unit?: string; empty?: string }
  | { type: 'notice'; text: Rich; title?: string }
  | { type: 'spacer'; height?: number }
  | { type: 'page_break' };

export type DocModel = {
  meta: { title: string; subject?: string; author?: string; keywords?: string; issued_at: string };
  header: { title: string; subtitle?: string; right?: string[]; logo?: string };
  footer?: { left?: string };
  draft?: boolean;
  blocks: Block[];
};

export type RenderResult = { bytes: Uint8Array; pages: number; sha256: string; warnings: string[]; images: number; engine: string };

export class RenderError extends Error {}

type Cell = { lines: Line[]; align: 'left' | 'center' | 'right' };

class Composer {
  pages: string[][] = [];
  cur: string[] = [];
  y = BODY_TOP;
  stats = new TextStats();
  imageNames = new Map<string, string>();
  constructor(public images: Map<string, PdfImage>) { this.newPage(); }

  newPage() {
    if (this.pages.length >= MAX_PAGES) throw new RenderError(`Documento acima de ${MAX_PAGES} páginas.`);
    this.cur = []; this.pages.push(this.cur); this.y = BODY_TOP;
  }
  atTop() { return this.y >= BODY_TOP - 0.5; }
  room() { return this.y - BODY_BOTTOM; }
  need(h: number) { if (h > this.room() && !this.atTop()) this.newPage(); }
  gap(h: number) { if (!this.atTop()) { this.y -= h; if (this.y < BODY_BOTTOM) this.newPage(); } }

  text(line: Line, x: number, baseline: number, size: number, width: number, align: 'left' | 'center' | 'right' = 'left', gray = 0, ops = this.cur) {
    const dx = align === 'right' ? width - line.width : align === 'center' ? (width - line.width) / 2 : 0;
    let s = `${gray ? `${fmt(gray)} g ` : ''}BT 1 0 0 1 ${fmt(x + Math.max(0, dx))} ${fmt(baseline)} Tm`;
    for (const seg of line.segs) s += ` /${FONT_RES[seg.font]} ${fmt(size)} Tf ${pdfString(seg.codes)} Tj`;
    ops.push(s + ` ET${gray ? ' 0 g' : ''}`);
  }
  rect(x: number, y: number, w: number, h: number, fill?: number, stroke?: number, lw = 0.5) {
    let s = 'q ';
    if (fill !== undefined) s += `${fmt(fill)} g `;
    if (stroke !== undefined) s += `${fmt(stroke)} G ${fmt(lw)} w `;
    s += `${fmt(x)} ${fmt(y)} ${fmt(w)} ${fmt(h)} re ${fill !== undefined && stroke !== undefined ? 'B' : fill !== undefined ? 'f' : 'S'} Q`;
    this.cur.push(s);
  }
  hline(y: number, x1 = M.left, x2 = M.left + CW, gray = 0.6, lw = 0.6, ops = this.cur) {
    ops.push(`q ${fmt(gray)} G ${fmt(lw)} w ${fmt(x1)} ${fmt(y)} m ${fmt(x2)} ${fmt(y)} l S Q`);
  }
  wrap(rich: Rich, width: number, size: number, base: { bold?: boolean; italic?: boolean } = {}) { return wrap(rich, width, size, base, this.stats); }

  // ---------- blocos ----------
  paragraphLines(lines: Line[], size: number, opts: { x?: number; width?: number; align?: 'left' | 'center'; gray?: number } = {}) {
    const lh = size * 1.35, x = opts.x ?? M.left, width = opts.width ?? CW;
    if (lines.length >= 2 && this.room() < lh * 2 && !this.atTop()) this.newPage();
    for (const line of lines) {
      if (this.room() < lh) this.newPage();
      this.text(line, x, this.y - size * 0.98, size, width, opts.align ?? 'left', opts.gray ?? 0);
      this.y -= lh;
    }
  }

  heading(text: string, level: 1 | 2 | 3, keepNext = 40) {
    const size = level === 1 ? 14 : level === 2 ? 11.5 : 10;
    const lines = this.wrap(text, CW, size, { bold: true });
    const h = lines.length * size * 1.3 + (level === 1 ? 6 : 3);
    this.gap(level === 1 ? 12 : 8);
    // Mantém o título com o primeiro trecho do bloco seguinte (imagem inteira, cabeçalho de tabela ou ~3 linhas).
    this.need(h + Math.min(keepNext, BODY_TOP - BODY_BOTTOM - h - 20));
    for (const line of lines) { this.text(line, M.left, this.y - size * 0.98, size, CW); this.y -= size * 1.3; }
    if (level === 1) { this.hline(this.y + 1, M.left, M.left + CW, 0.35, 0.8); this.y -= 6; } else this.y -= 3;
  }

  table(b: { title?: string; columns: Column[]; rows: Rich[][]; empty?: string; size?: number; headless?: boolean; boldFirst?: boolean[] }) {
    const size = b.size ?? 8.6, lh = size * 1.3, pad = 3.5;
    const total = b.columns.reduce((s, c) => s + Math.max(0.01, c.width), 0);
    const widths = b.columns.map(c => (Math.max(0.01, c.width) / total) * CW);
    const xs = widths.map((_, i) => M.left + widths.slice(0, i).reduce((s, v) => s + v, 0));
    const header: Cell[] = b.columns.map((c, i) => ({ lines: this.wrap(c.label, widths[i] - 2 * pad, size, { bold: true }), align: c.align ?? 'left' }));
    const headerH = b.headless ? 0 : Math.max(...header.map(c => c.lines.length)) * lh + 2 * pad;
    const titleSize = 9.5, titleLines = b.title ? this.wrap(b.title, CW, titleSize, { bold: true }) : [];
    const titleH = titleLines.length * titleSize * 1.3 + (b.title ? 3 : 0);
    const rows: Cell[][] = b.rows.length ? b.rows.map(r => b.columns.map((c, i) => ({
      lines: this.wrap(r[i] ?? '', widths[i] - 2 * pad, size, { bold: b.boldFirst?.[i] }), align: c.align ?? 'left' })))
      : [[{ lines: this.wrap({ text: b.empty ?? 'Sem registros.', italic: true }, CW - 2 * pad, size), align: 'left' }]];
    const emptyRow = b.rows.length === 0;
    const drawTitle = (cont: boolean) => {
      if (!b.title) return;
      const lines = cont ? this.wrap(`${b.title} (continuação)`, CW, titleSize, { bold: true }) : titleLines;
      for (const line of lines) { this.text(line, M.left, this.y - titleSize * 0.98, titleSize, CW); this.y -= titleSize * 1.3; }
      this.y -= 3;
    };
    const drawHeader = () => {
      if (b.headless) return;
      this.rect(M.left, this.y - headerH, CW, headerH, 0.88, 0.45);
      header.forEach((c, i) => {
        if (i > 0) this.cur.push(`q 0.45 G 0.5 w ${fmt(xs[i])} ${fmt(this.y)} m ${fmt(xs[i])} ${fmt(this.y - headerH)} l S Q`);
        c.lines.forEach((line, k) => this.text(line, xs[i] + pad, this.y - pad - k * lh - size * 0.95, size, widths[i] - 2 * pad, c.align));
      });
      this.y -= headerH;
    };
    const drawRow = (cells: Cell[], take: number) => {
      const h = take * lh + 2 * pad;
      const spans = emptyRow ? [CW] : widths;
      const xpos = emptyRow ? [M.left] : xs;
      cells.forEach((c, i) => {
        this.rect(xpos[i], this.y - h, spans[i], h, undefined, 0.55);
        c.lines.slice(0, take).forEach((line, k) => this.text(line, xpos[i] + pad, this.y - pad - k * lh - size * 0.95, size, spans[i] - 2 * pad, c.align));
      });
      this.y -= h;
    };
    const firstH = Math.min(Math.max(...rows[0].map(c => c.lines.length)), 3) * lh + 2 * pad;
    this.gap(4);
    this.need(titleH + headerH + firstH);
    drawTitle(false); drawHeader();
    let afterHeader = true;
    for (let cells of rows) {
      for (;;) {
        const n = Math.max(1, ...cells.map(c => c.lines.length));
        const h = n * lh + 2 * pad;
        if (h <= this.room()) { drawRow(cells, n); afterHeader = false; break; }
        const freshRoom = BODY_TOP - BODY_BOTTOM - titleH - headerH;
        const fit = Math.floor((this.room() - 2 * pad) / lh);
        if ((h <= freshRoom || fit < 2) && !afterHeader) { this.newPage(); drawTitle(true); drawHeader(); afterHeader = true; continue; }
        if (fit < 1) { this.newPage(); drawTitle(true); drawHeader(); afterHeader = true; continue; }
        // Célula maior que o espaço restante: divide a linha da tabela, sem truncar texto.
        drawRow(cells, fit);
        cells = cells.map(c => ({ lines: c.lines.slice(fit), align: c.align }));
        this.newPage(); drawTitle(true); drawHeader(); afterHeader = true;
      }
    }
    this.y -= 6;
  }

  fields(items: { label: string; value: Rich }[], columns: 1 | 2) {
    if (columns === 2) {
      const rows: Rich[][] = [];
      for (let i = 0; i < items.length; i += 2) rows.push([items[i].label, items[i].value, items[i + 1]?.label ?? '', items[i + 1]?.value ?? '']);
      this.table({ headless: true, size: 8.8, columns: [{ label: '', width: 0.17 }, { label: '', width: 0.33 }, { label: '', width: 0.17 }, { label: '', width: 0.33 }], rows, boldFirst: [true, false, true, false] });
    } else {
      this.table({ headless: true, size: 8.8, columns: [{ label: '', width: 0.28 }, { label: '', width: 0.72 }], rows: items.map(i => [i.label, i.value]), boldFirst: [true, false] });
    }
  }

  list(items: Rich[], ordered: boolean) {
    const size = 9.5, lh = size * 1.35, indent = 16;
    this.gap(2);
    items.forEach((item, i) => {
      const lines = this.wrap(item, CW - indent, size);
      const marker = this.wrap(ordered ? `${i + 1}.` : '•', indent, size)[0];
      lines.forEach((line, k) => {
        if (this.room() < lh) this.newPage();
        if (k === 0) this.text(marker, M.left, this.y - size * 0.98, size, indent - 4, ordered ? 'right' : 'left');
        this.text(line, M.left + indent, this.y - size * 0.98, size, CW - indent);
        this.y -= lh;
      });
      this.y -= 1.5;
    });
    this.y -= 4;
  }

  notice(text: Rich, title?: string) {
    const size = 9, lh = size * 1.35, pad = 7;
    const lines = [...(title ? this.wrap(title, CW - 2 * pad - 3, size, { bold: true }) : []), ...this.wrap(text, CW - 2 * pad - 3, size)];
    this.gap(4);
    this.need(Math.min(lines.length, 3) * lh + 2 * pad);
    let i = 0;
    while (i < lines.length) {
      const fit = Math.max(1, Math.floor((this.room() - 2 * pad) / lh));
      const part = lines.slice(i, i + fit);
      const h = part.length * lh + 2 * pad;
      this.rect(M.left, this.y - h, CW, h, 0.94, 0.5);
      this.rect(M.left, this.y - h, 3, h, 0.3);
      part.forEach((line, k) => this.text(line, M.left + pad + 3, this.y - pad - k * lh - size * 0.95, size, CW - 2 * pad - 3));
      this.y -= h; i += part.length;
      if (i < lines.length) this.newPage();
    }
    this.y -= 6;
  }

  imageBox(asset: string, caption: string | undefined, maxHeight: number, ratio: number) {
    const img = this.images.get(asset);
    const name = this.imageNames.get(asset);
    if (!img || !name) throw new RenderError(`Recurso de imagem ausente: ${asset}`);
    const ds = displaySize(img);
    const maxW = CW * Math.min(1, Math.max(0.2, ratio));
    let scale = Math.min(maxW / ds.w, Math.min(maxHeight, BODY_TOP - BODY_BOTTOM - 60) / ds.h);
    scale = Math.min(scale, 3);
    const w = ds.w * scale, h = ds.h * scale;
    const capSize = 8.5, capLines = caption ? this.wrap({ text: caption, italic: true }, CW, capSize) : [];
    const capH = capLines.length * capSize * 1.35;
    return { img, name, w, h, capSize, capLines, capH, total: 6 + h + 6 + capH };
  }

  image(asset: string, caption: string | undefined, maxHeight: number, ratio: number) {
    const { img, name, w, h, capSize, capLines, capH } = this.imageBox(asset, caption, maxHeight, ratio);
    this.gap(6);
    this.need(h + 6 + capH);
    const x = M.left + (CW - w) / 2, y = this.y - h;
    this.cur.push(`q ${placement(img.orientation, x, y, w, h)} /${name} Do Q`);
    this.rect(x, y, w, h, undefined, 0.6, 0.4);
    this.y = y - 4;
    for (const line of capLines) { this.text(line, M.left, this.y - capSize * 0.98, capSize, CW, 'center', 0.2); this.y -= capSize * 1.35; }
    this.y -= 6;
  }

  bars(b: { title?: string; items: { label: string; value: number; display?: string }[]; max?: number; unit?: string; empty?: string }) {
    const size = 8.6, lh = size * 1.3, labelW = CW * 0.36, valueW = CW * 0.16, barX = M.left + labelW + 6, barW = CW - labelW - valueW - 12;
    const titleLines = b.title ? this.wrap(b.title, CW, 9.5, { bold: true }) : [];
    const rows = b.items.map(it => ({ it, lines: this.wrap(it.label, labelW, size) }));
    const rowH = (r: { lines: Line[] }) => Math.max(14, r.lines.length * lh + 4);
    this.gap(6);
    this.need(titleLines.length * 12.4 + (rows[0] ? rowH(rows[0]) * Math.min(rows.length, 2) : 20));
    for (const line of titleLines) { this.text(line, M.left, this.y - 9.5 * 0.98, 9.5, CW); this.y -= 9.5 * 1.3; }
    this.y -= 3;
    if (rows.length === 0) { this.paragraphLines(this.wrap({ text: b.empty ?? 'Sem dados para o gráfico.', italic: true }, CW, 9), 9); this.y -= 4; return; }
    const max = b.max && b.max > 0 ? b.max : Math.max(...rows.map(r => Math.max(0, Number(r.it.value) || 0)), 0) || 1;
    for (const r of rows) {
      const h = rowH(r);
      if (this.room() < h) this.newPage();
      r.lines.forEach((line, k) => this.text(line, M.left, this.y - 2 - k * lh - size * 0.95, size, labelW));
      const v = Math.max(0, Number(r.it.value) || 0), bh = 8, by = this.y - h / 2 - bh / 2;
      this.rect(barX, by, barW, bh, 0.93, 0.55, 0.4);
      if (v > 0) this.rect(barX, by, Math.max(0.8, Math.min(1, v / max) * barW), bh, 0.42);
      const label = r.it.display ?? `${fmtNumber(v)}${b.unit ? ` ${b.unit}` : ''}`;
      this.text(this.wrap(label, valueW, size, { bold: true })[0], barX + barW + 6, by + 1, size, valueW - 6, 'left');
      this.y -= h;
    }
    this.y -= 6;
  }
}

function fmtNumber(v: number): string {
  return Number.isInteger(v) ? String(v) : v.toFixed(1).replace('.', ',');
}

function decorate(c: Composer, doc: DocModel, logo: { name: string; img: PdfImage } | null, index: number, count: number): string[] {
  const ops: string[] = [];
  if (doc.draft) {
    const line = wrap('PRÉVIA — SEM VALIDADE', 2000, 46, { bold: true })[0];
    const cos = Math.cos(Math.PI / 4), sin = Math.sin(Math.PI / 4);
    const cx = PAGE.w / 2 - (line.width / 2) * cos, cy = PAGE.h / 2 - (line.width / 2) * sin;
    ops.push(`q 0.88 g BT /F2 46 Tf ${fmt(cos)} ${fmt(sin)} ${fmt(-sin)} ${fmt(cos)} ${fmt(cx)} ${fmt(cy)} Tm ${pdfString(line.segs[0].codes)} Tj ET Q`);
  }
  const top = PAGE.h - M.top;
  let x = M.left;
  if (logo) {
    const ds = displaySize(logo.img), h = 26, w = Math.min(110, (ds.w / ds.h) * h);
    const hh = (w / ds.w) * ds.h;
    ops.push(`q ${placement(logo.img.orientation, M.left, top - hh - 4, w, hh)} /${logo.name} Do Q`);
    x = M.left + w + 12;
  }
  const rightW = 150, titleW = M.left + CW - rightW - 8 - x;
  const titleLines = wrap(doc.header.title, titleW, 11, { bold: true }).slice(0, 2);
  let ty = top - 13;
  for (const line of titleLines) { c.text(line, x, ty, 11, titleW, 'left', 0, ops); ty -= 13; }
  if (doc.header.subtitle) for (const line of wrap(doc.header.subtitle, titleW, 8.5).slice(0, 2)) { c.text(line, x, ty, 8.5, titleW, 'left', 0.25, ops); ty -= 10.5; }
  let ry = top - 11;
  for (const r of (doc.header.right ?? []).slice(0, 4)) {
    for (const line of wrap(r, rightW, 8).slice(0, 1)) { c.text(line, M.left + CW - rightW, ry, 8, rightW, 'right', 0.15, ops); ry -= 10.5; }
  }
  if (doc.draft) { c.text(wrap('PRÉVIA', rightW, 8, { bold: true })[0], M.left + CW - rightW, ry, 8, rightW, 'right', 0, ops); }
  c.hline(PAGE.h - M.top - HEADER_H + 10, M.left, M.left + CW, 0.4, 0.8, ops);
  // Rodapé
  const fy = M.bottom + FOOTER_H - 10;
  c.hline(fy, M.left, M.left + CW, 0.5, 0.5, ops);
  const pageLabel = wrap(`Página ${index + 1} de ${count}`, 100, 8)[0];
  c.text(pageLabel, M.left + CW - 100, fy - 11, 8, 100, 'right', 0, ops);
  if (doc.footer?.left) wrap(doc.footer.left, CW - 110, 7.5).slice(0, 2).forEach((line, k) => c.text(line, M.left, fy - 10 - k * 9, 7.5, CW - 110, 'left', 0.25, ops));
  return ops;
}

function validate(doc: DocModel) {
  if (!doc || typeof doc !== 'object' || !Array.isArray(doc.blocks)) throw new RenderError('Documento sem blocos.');
  if (!doc.meta?.title || !doc.meta?.issued_at || !doc.header?.title) throw new RenderError('Documento sem título, cabeçalho ou data de emissão.');
  if (doc.blocks.length > 20000) throw new RenderError('Documento com blocos demais.');
}

/** Renderiza o documento. `assets` contém os bytes de cada recurso referenciado (logo, fotos) já verificados. */
export async function renderDocument(doc: DocModel, assets: Record<string, Uint8Array>, opts: { idSeed: string }): Promise<RenderResult> {
  validate(doc);
  const images = new Map<string, PdfImage>();
  const byName = new Map<string, PdfImage>();
  const names = new Map<string, string>();
  const needed = new Set<string>();
  if (doc.header.logo) needed.add(doc.header.logo);
  for (const b of doc.blocks) if (b.type === 'image') needed.add(b.asset);
  let k = 0;
  for (const key of needed) {
    const bytes = assets[key];
    if (!bytes) throw new RenderError(`Recurso ausente para a emissão: ${key}`);
    try { images.set(key, await loadImage(bytes)); } catch (e) {
      throw new RenderError(`Recurso ${key}: ${e instanceof ImageRejected ? e.message : 'imagem ilegível'}`);
    }
    const name = `Im${++k}`;
    names.set(key, name); byName.set(name, images.get(key)!);
  }
  const c = new Composer(images);
  c.imageNames = names;
  const keepNext = (n: Block | undefined): number => {
    if (!n) return 0;
    if (n.type === 'image') return c.imageBox(n.asset, n.caption, n.max_height ?? 330, n.width_ratio ?? 0.9).total;
    if (n.type === 'table') return (n.title ? 16 : 0) + 60;
    if (n.type === 'bars') return (n.title ? 16 : 0) + 34;
    if (n.type === 'heading' || n.type === 'page_break') return 40;
    return 40;
  };
  for (let bi = 0; bi < doc.blocks.length; bi++) {
    const b = doc.blocks[bi];
    switch (b.type) {
      case 'heading': c.heading(b.text, b.level ?? 1, keepNext(doc.blocks[bi + 1])); break;
      case 'paragraph': {
        const size = b.size ?? 9.8;
        c.paragraphLines(c.wrap(b.text, CW, size, { bold: b.bold, italic: b.italic }), size, { align: b.align, gray: b.muted ? 0.3 : 0 });
        c.y -= 5; break;
      }
      case 'fields': c.gap(3); c.fields(b.items, b.columns ?? 1); break;
      case 'table': c.table(b); break;
      case 'list': c.list(b.items, !!b.ordered); break;
      case 'image': c.image(b.asset, b.caption, b.max_height ?? 330, b.width_ratio ?? 0.9); break;
      case 'bars': c.bars(b); break;
      case 'notice': c.notice(b.text, b.title); break;
      case 'spacer': c.gap(Math.max(0, Math.min(200, b.height ?? 10))); break;
      case 'page_break': if (!c.atTop()) c.newPage(); break;
      default: throw new RenderError(`Bloco desconhecido: ${(b as { type?: string }).type}`);
    }
  }
  if (c.pages.length > 1 && c.pages[c.pages.length - 1].length === 0) c.pages.pop();
  const logo = doc.header.logo ? { name: names.get(doc.header.logo)!, img: images.get(doc.header.logo)! } : null;
  const count = c.pages.length;
  const pages = c.pages.map((ops, i) => [...decorate(c, doc, logo, i, count), ...ops].join('\n'));
  const idHex = (await sha256Hex(new TextEncoder().encode(opts.idSeed))).slice(0, 32);
  const bytes = await writePdf({
    pages, width: PAGE.w, height: PAGE.h, images: byName, idHex,
    info: { title: doc.meta.title, subject: doc.meta.subject, author: doc.meta.author, keywords: doc.meta.keywords,
      creator: 'Audita PRO', producer: ENGINE_VERSION, created_at: doc.meta.issued_at },
  });
  const warnings: string[] = [];
  if (c.stats.unmapped) warnings.push(`${c.stats.unmapped} caractere(s) sem equivalente na fonte foram substituídos por "?"`);
  return { bytes, pages: count, sha256: await sha256Hex(bytes), warnings, images: images.size, engine: ENGINE_VERSION };
}

export { encode, fontFor, plain, widthOf };
