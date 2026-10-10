// Texto: codificação WinAnsi, medição com as métricas das fontes-base Helvetica (PDF base-14) e quebra de linhas
// com trechos em negrito/itálico. Nada é omitido em silêncio: caracteres sem equivalente viram "?" e são contados.
import { WIDTHS, WINANSI_EXTRA } from './metrics.ts';

export type FontKey = 'regular' | 'bold' | 'italic' | 'boldItalic';
export type Inline = string | { text: string; bold?: boolean; italic?: boolean };
export type Rich = Inline | Inline[];
export type Seg = { font: FontKey; codes: number[] };
export type Line = { segs: Seg[]; width: number };

export class TextStats { unmapped = 0; }

// Substituições explícitas para caracteres fora do WinAnsi.
const SUBSTITUTE: Record<number, string> = {
  0x2264: '<=', 0x2265: '>=', 0x2260: '!=', 0x2192: '->', 0x2190: '<-', 0x2194: '<->', 0x21d2: '=>',
  0x2713: 'OK', 0x2714: 'OK', 0x2717: 'X', 0x2718: 'X', 0x2010: '-', 0x2011: '-', 0x2012: '-', 0x2212: '-',
  0x25cf: '•', 0x25aa: '•', 0x2219: '•', 0x00a0: ' ', 0x2007: ' ', 0x2009: ' ', 0x202f: ' ',
  0x200b: '', 0x200c: '', 0x200d: '', 0xfeff: '', 0x00ad: '', 0x2032: "'", 0x2033: '"', 0x2116: 'No', 0x2248: '~',
};

function codeOf(cp: number): number | null {
  if (cp >= 0x20 && cp <= 0x7e) return cp;
  if (cp >= 0xa0 && cp <= 0xff) return cp;
  const extra = WINANSI_EXTRA[cp];
  return extra === undefined ? null : extra;
}

/** Converte texto Unicode (NFC) em códigos WinAnsi. */
export function encode(text: string, stats?: TextStats): number[] {
  const codes: number[] = [];
  for (const ch of text.normalize('NFC')) {
    const cp = ch.codePointAt(0)!;
    if (cp === 0x09) { codes.push(32); continue; }
    if (cp < 0x20 || (cp >= 0x7f && cp < 0xa0)) continue; // controles; quebras de linha são tratadas em wrap()
    const direct = codeOf(cp);
    if (direct !== null) { codes.push(direct); continue; }
    const sub = SUBSTITUTE[cp];
    if (sub !== undefined) {
      for (const c of sub) { const k = codeOf(c.codePointAt(0)!); if (k !== null) codes.push(k); }
      continue;
    }
    const base = ch.normalize('NFD').charAt(0); // "ẽ" → "e"
    const baseCode = base && base !== ch ? codeOf(base.codePointAt(0)!) : null;
    codes.push(baseCode ?? 63);
    if (stats) stats.unmapped++;
  }
  return codes;
}

export function widthOfCodes(codes: number[], font: FontKey, size: number): number {
  const table = WIDTHS[font];
  let w = 0;
  for (const c of codes) w += table[c] ?? 556;
  return (w * size) / 1000;
}

export function widthOf(text: string, font: FontKey, size: number): number {
  return widthOfCodes(encode(text), font, size);
}

export function fontFor(bold?: boolean, italic?: boolean): FontKey {
  return bold ? (italic ? 'boldItalic' : 'bold') : (italic ? 'italic' : 'regular');
}

/** String hexadecimal PDF (dispensa escapes). */
export function pdfString(codes: number[]): string {
  let s = '<';
  for (const c of codes) s += c.toString(16).padStart(2, '0');
  return s + '>';
}

function inlines(rich: Rich): Inline[] {
  if (rich === null || rich === undefined) return [];
  return Array.isArray(rich) ? rich : [rich];
}

/** Texto simples de um conteúdo rico (para metadados e testes). */
export function plain(rich: Rich): string {
  return inlines(rich).map(i => (typeof i === 'string' ? i : String(i?.text ?? ''))).join('');
}

type Piece = { kind: 'word' | 'space' | 'break'; font: FontKey; codes: number[] };

function pieces(rich: Rich, base: { bold?: boolean; italic?: boolean }, stats?: TextStats): Piece[] {
  const out: Piece[] = [];
  for (const item of inlines(rich)) {
    const text = typeof item === 'string' ? item : String(item?.text ?? '');
    const font = typeof item === 'string' ? fontFor(base.bold, base.italic)
      : fontFor(item.bold ?? base.bold, item.italic ?? base.italic);
    for (const part of text.replace(/\r\n?/g, '\n').split(/(\n|[ \t   ]+)/)) {
      if (!part) continue;
      if (part === '\n') out.push({ kind: 'break', font, codes: [] });
      else if (/^[ \t   ]+$/.test(part)) out.push({ kind: 'space', font, codes: [32] });
      else {
        const codes = encode(part, stats);
        if (codes.length) out.push({ kind: 'word', font, codes });
      }
    }
  }
  return out;
}

function pushSeg(line: Line, font: FontKey, codes: number[], size: number) {
  const last = line.segs[line.segs.length - 1];
  if (last && last.font === font) last.codes.push(...codes);
  else line.segs.push({ font, codes: [...codes] });
  line.width += widthOfCodes(codes, font, size);
}

/**
 * Quebra o texto na largura informada. Palavras unidas sem espaço (mesmo com fontes diferentes) formam uma unidade;
 * unidade maior que a largura é dividida por caractere, sem truncar. Sempre devolve ao menos uma linha.
 */
export function wrap(rich: Rich, width: number, size: number, base: { bold?: boolean; italic?: boolean } = {}, stats?: TextStats): Line[] {
  const lines: Line[] = [];
  let line: Line = { segs: [], width: 0 };
  let pendingSpace: FontKey | null = null;
  const flush = () => { lines.push(line); line = { segs: [], width: 0 }; pendingSpace = null; };
  const list = pieces(rich, base, stats);
  let i = 0;
  while (i < list.length) {
    const p = list[i];
    if (p.kind === 'break') { flush(); i++; continue; }
    if (p.kind === 'space') { if (line.segs.length) pendingSpace = p.font; i++; continue; }
    const unit: Piece[] = [];
    while (i < list.length && list[i].kind === 'word') unit.push(list[i++]);
    const unitW = unit.reduce((s, u) => s + widthOfCodes(u.codes, u.font, size), 0);
    const spaceW = pendingSpace && line.segs.length ? widthOfCodes([32], pendingSpace, size) : 0;
    if (line.segs.length && line.width + spaceW + unitW > width) flush();
    if (pendingSpace && line.segs.length) pushSeg(line, pendingSpace, [32], size);
    pendingSpace = null;
    if (unitW <= width - line.width) { for (const u of unit) pushSeg(line, u.font, u.codes, size); continue; }
    // Unidade mais larga que a linha: divide por caractere.
    for (const u of unit) for (const c of u.codes) {
      const cw = widthOfCodes([c], u.font, size);
      if (line.segs.length && line.width + cw > width) flush();
      pushSeg(line, u.font, [c], size);
    }
  }
  if (line.segs.length || lines.length === 0) lines.push(line);
  return lines;
}
