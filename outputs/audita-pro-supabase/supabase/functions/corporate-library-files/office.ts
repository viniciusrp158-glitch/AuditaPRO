// Validação do conteúdo real dos arquivos da biblioteca corporativa (PC-07).
// Sem dependências: leitura mínima de ZIP (diretório central) e DecompressionStream nativo.
// Não confia em extensão ou MIME enviados pelo navegador.

export type DetectedFormat = { format: 'pdf' | 'docx' | 'dotx'; mime: string };

export const MIME: Record<'pdf' | 'docx' | 'dotx', string> = {
  pdf: 'application/pdf',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  dotx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.template',
};

export const MAX_BYTES = 20 * 1024 * 1024;

const DOCX_MAIN = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml';
const DOTX_MAIN = 'application/vnd.openxmlformats-officedocument.wordprocessingml.template.main+xml';

export class FileRejected extends Error {}

const u16 = (b: Uint8Array, o: number) => b[o] | (b[o + 1] << 8);
const u32 = (b: Uint8Array, o: number) => (b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)) >>> 0;

type ZipEntry = { name: string; method: number; flags: number; compSize: number; size: number; localOffset: number };

function zipEntries(b: Uint8Array): ZipEntry[] {
  const min = Math.max(0, b.length - 65557);
  let eocd = -1;
  for (let i = b.length - 22; i >= min; i--) if (u32(b, i) === 0x06054b50) { eocd = i; break; }
  if (eocd < 0) throw new FileRejected('Arquivo Word corrompido ou incompleto.');
  const count = u16(b, eocd + 10), cdOffset = u32(b, eocd + 16);
  if (count === 0xffff || cdOffset === 0xffffffff) throw new FileRejected('Formato de pacote Word não suportado.');
  const entries: ZipEntry[] = [];
  let p = cdOffset;
  for (let i = 0; i < count; i++) {
    if (p + 46 > b.length || u32(b, p) !== 0x02014b50) throw new FileRejected('Arquivo Word corrompido ou incompleto.');
    const nameLen = u16(b, p + 28), extra = u16(b, p + 30), comment = u16(b, p + 32);
    entries.push({
      flags: u16(b, p + 8), method: u16(b, p + 10), compSize: u32(b, p + 20), size: u32(b, p + 24),
      localOffset: u32(b, p + 42), name: new TextDecoder().decode(b.subarray(p + 46, p + 46 + nameLen)),
    });
    p += 46 + nameLen + extra + comment;
  }
  return entries;
}

async function readEntry(b: Uint8Array, e: ZipEntry, limit: number): Promise<string> {
  if (e.flags & 1) throw new FileRejected('Arquivos Word protegidos por senha não são aceitos.');
  if (e.size > limit) throw new FileRejected('Arquivo Word com estrutura inválida.');
  const h = e.localOffset;
  if (u32(b, h) !== 0x04034b50) throw new FileRejected('Arquivo Word corrompido ou incompleto.');
  const start = h + 30 + u16(b, h + 26) + u16(b, h + 28);
  const raw = b.subarray(start, start + e.compSize);
  if (raw.length !== e.compSize) throw new FileRejected('Arquivo Word corrompido ou incompleto.');
  if (e.method === 0) return new TextDecoder().decode(raw);
  if (e.method !== 8) throw new FileRejected('Compressão de arquivo Word não suportada.');
  const stream = new Blob([raw]).stream().pipeThrough(new DecompressionStream('deflate-raw'));
  const out = new Uint8Array(await new Response(stream).arrayBuffer());
  if (out.length > limit) throw new FileRejected('Arquivo Word com estrutura inválida.');
  return new TextDecoder().decode(out);
}

export async function detectFormat(bytes: Uint8Array): Promise<DetectedFormat> {
  if (bytes.length === 0) throw new FileRejected('Arquivo vazio.');
  if (bytes.length > MAX_BYTES) throw new FileRejected('Arquivo acima do limite de 20 MB.');
  const head = new TextDecoder('latin1').decode(bytes.subarray(0, 5));
  if (head === '%PDF-') {
    const tail = new TextDecoder('latin1').decode(bytes.subarray(Math.max(0, bytes.length - 2048)));
    if (!tail.includes('%%EOF')) throw new FileRejected('Arquivo PDF incompleto ou corrompido.');
    return { format: 'pdf', mime: MIME.pdf };
  }
  if (u32(bytes, 0) === 0x04034b50) {
    const entries = zipEntries(bytes);
    if (entries.some(e => /(^|\/)vbaProject\.bin$|(^|\/)vbaData\.xml$/i.test(e.name)))
      throw new FileRejected('Arquivos com macros não são aceitos.');
    const types = entries.find(e => e.name === '[Content_Types].xml');
    if (!types) throw new FileRejected('Envie PDF, DOCX ou DOTX.');
    const xml = await readEntry(bytes, types, 1024 * 1024);
    if (/macroEnabled/i.test(xml)) throw new FileRejected('Arquivos com macros não são aceitos.');
    if (xml.includes(DOCX_MAIN)) return { format: 'docx', mime: MIME.docx };
    if (xml.includes(DOTX_MAIN)) return { format: 'dotx', mime: MIME.dotx };
    throw new FileRejected('Envie PDF, DOCX ou DOTX.');
  }
  throw new FileRejected('Formato não permitido. Envie PDF, DOCX ou DOTX.');
}

export async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes));
  return Array.from(digest, v => v.toString(16).padStart(2, '0')).join('');
}

export function safeFilename(name: string, format: string): string {
  const base = (name || 'documento').replace(/[\\/:*?"<>|\u0000-\u001f]+/g, '_').trim().slice(0, 180) || 'documento';
  return base.toLowerCase().endsWith('.' + format) ? base : `${base}.${format}`;
}
