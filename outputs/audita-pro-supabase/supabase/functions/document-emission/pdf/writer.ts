// Montagem do arquivo PDF 1.7: objetos, fontes-padrão, imagens, páginas e tabela xref.
// Saída determinística: sem relógio interno; data e identificador vêm do pedido de emissão.
import type { PdfImage } from './images.ts';
import { deflate } from './zlib.ts';

export const FONT_NAMES: Record<string, string> = {
  F1: 'Helvetica', F2: 'Helvetica-Bold', F3: 'Helvetica-Oblique', F4: 'Helvetica-BoldOblique',
};

export type DocInfo = { title: string; subject?: string; author?: string; keywords?: string; creator: string; producer: string; created_at: string };

const enc = new TextEncoder();

function utf16Hex(s: string): string {
  let out = 'FEFF';
  for (let i = 0; i < s.length; i++) out += s.charCodeAt(i).toString(16).padStart(4, '0').toUpperCase();
  return `<${out}>`;
}

/** Data PDF (D:AAAAMMDDHHmmSS±HH'mm') no fuso informado, a partir de um ISO 8601. */
export function pdfDate(iso: string, offsetMinutes = -180): string {
  const t = Date.parse(iso);
  if (Number.isNaN(t)) throw new Error('Data de emissão inválida');
  const d = new Date(t + offsetMinutes * 60000);
  const p = (n: number, l = 2) => String(n).padStart(l, '0');
  const sign = offsetMinutes < 0 ? '-' : '+', abs = Math.abs(offsetMinutes);
  return `D:${p(d.getUTCFullYear(), 4)}${p(d.getUTCMonth() + 1)}${p(d.getUTCDate())}${p(d.getUTCHours())}${p(d.getUTCMinutes())}${p(d.getUTCSeconds())}${sign}${p(Math.floor(abs / 60))}'${p(abs % 60)}'`;
}

export async function writePdf(input: {
  pages: string[]; width: number; height: number; images: Map<string, PdfImage>; info: DocInfo; idHex: string;
}): Promise<Uint8Array> {
  const chunks: Uint8Array[] = [];
  const offsets: number[] = [];
  let pos = 0;
  const emit = (data: Uint8Array | string) => { const b = typeof data === 'string' ? enc.encode(data) : data; chunks.push(b); pos += b.length; };
  const obj = (n: number, body: string) => { offsets[n] = pos; emit(`${n} 0 obj\n${body}\nendobj\n`); };
  const stream = (n: number, dict: string, data: Uint8Array) => {
    offsets[n] = pos;
    emit(`${n} 0 obj\n<< ${dict} /Length ${data.length} >>\nstream\n`); emit(data); emit('\nendstream\nendobj\n');
  };

  emit('%PDF-1.7\n'); emit(new Uint8Array([0x25, 0xe2, 0xe3, 0xcf, 0xd3, 0x0a]));
  let next = 1;
  const catalog = next++, pagesObj = next++, infoObj = next++, resources = next++;
  const fontObjs: Record<string, number> = {};
  for (const key of Object.keys(FONT_NAMES)) fontObjs[key] = next++;
  const imageObjs = new Map<string, { obj: number; smask?: number }>();
  for (const [name, img] of input.images) imageObjs.set(name, { obj: next++, smask: img.smask ? next++ : undefined });
  const pageObjs = input.pages.map(() => ({ page: next++, content: next++ }));

  obj(catalog, `<< /Type /Catalog /Pages ${pagesObj} 0 R /Lang (pt-BR) /ViewerPreferences << /DisplayDocTitle true >> >>`);
  obj(pagesObj, `<< /Type /Pages /Count ${pageObjs.length} /Kids [${pageObjs.map(p => `${p.page} 0 R`).join(' ')}] >>`);
  const i = input.info;
  const created = pdfDate(i.created_at);
  obj(infoObj, `<< /Title ${utf16Hex(i.title)}${i.subject ? ` /Subject ${utf16Hex(i.subject)}` : ''}${i.author ? ` /Author ${utf16Hex(i.author)}` : ''}` +
    `${i.keywords ? ` /Keywords ${utf16Hex(i.keywords)}` : ''} /Creator ${utf16Hex(i.creator)} /Producer ${utf16Hex(i.producer)} /CreationDate (${created}) /ModDate (${created}) >>`);
  const fonts = Object.entries(fontObjs).map(([k, n]) => `/${k} ${n} 0 R`).join(' ');
  const xobjs = [...imageObjs].map(([k, v]) => `/${k} ${v.obj} 0 R`).join(' ');
  obj(resources, `<< /ProcSet [/PDF /Text /ImageB /ImageC /ImageI] /Font << ${fonts} >>${xobjs ? ` /XObject << ${xobjs} >>` : ''} >>`);
  for (const [key, n] of Object.entries(fontObjs)) obj(n, `<< /Type /Font /Subtype /Type1 /BaseFont /${FONT_NAMES[key]} /Encoding /WinAnsiEncoding >>`);
  for (const [name, img] of input.images) {
    const ids = imageObjs.get(name)!;
    stream(ids.obj, img.dict + (ids.smask ? ` /SMask ${ids.smask} 0 R` : ''), img.data);
    if (img.smask && ids.smask) stream(ids.smask, img.smask.dict, img.smask.data);
  }
  const box = `[0 0 ${input.width} ${input.height}]`;
  for (let k = 0; k < input.pages.length; k++) {
    const p = pageObjs[k];
    obj(p.page, `<< /Type /Page /Parent ${pagesObj} 0 R /MediaBox ${box} /Resources ${resources} 0 R /Contents ${p.content} 0 R >>`);
    stream(p.content, '/Filter /FlateDecode', await deflate(enc.encode(input.pages[k])));
  }
  const xref = pos;
  let table = `xref\n0 ${next}\n0000000000 65535 f \n`;
  for (let n = 1; n < next; n++) table += `${String(offsets[n]).padStart(10, '0')} 00000 n \n`;
  emit(table);
  emit(`trailer\n<< /Size ${next} /Root ${catalog} 0 R /Info ${infoObj} 0 R /ID [<${input.idHex}> <${input.idHex}>] >>\nstartxref\n${xref}\n%%EOF\n`);
  const out = new Uint8Array(pos);
  let o = 0; for (const c of chunks) { out.set(c, o); o += c.length; }
  return out;
}
