// Imagens para PDF sem dependências: JPEG (DCTDecode, sem recompressão; orientação EXIF respeitada)
// e PNG (FlateDecode com preditor; transparência por SMask). Formato não suportado gera erro explícito.
import { deflate, inflate } from './zlib.ts';

export class ImageRejected extends Error {}

export type PdfImage = {
  width: number; height: number;          // pixels do arquivo
  orientation: number;                    // EXIF 1..8 (JPEG); 1 para PNG
  dict: string;                           // entradas do dicionário (sem << >>, sem /Length)
  data: Uint8Array;
  smask?: { dict: string; data: Uint8Array };
};

export function sniff(bytes: Uint8Array): 'jpeg' | 'png' | 'webp' | 'unknown' {
  if (bytes[0] === 0xff && bytes[1] === 0xd8) return 'jpeg';
  if (bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) return 'png';
  if (bytes.length > 12 && String.fromCharCode(...bytes.subarray(0, 4)) === 'RIFF' && String.fromCharCode(...bytes.subarray(8, 12)) === 'WEBP') return 'webp';
  return 'unknown';
}

export async function loadImage(bytes: Uint8Array): Promise<PdfImage> {
  const kind = sniff(bytes);
  if (kind === 'jpeg') return jpeg(bytes);
  if (kind === 'png') return await png(bytes);
  if (kind === 'webp') throw new ImageRejected('Imagem WebP não é incorporada diretamente; converta para JPEG ou PNG antes da emissão.');
  throw new ImageRejected('Formato de imagem não suportado (use JPEG ou PNG).');
}

// ---------- JPEG ----------
function jpeg(b: Uint8Array): PdfImage {
  let p = 2, width = 0, height = 0, comps = 0, orientation = 1, adobe = false;
  while (p + 4 <= b.length) {
    if (b[p] !== 0xff) throw new ImageRejected('JPEG corrompido.');
    const marker = b[p + 1];
    if (marker === 0xd8 || (marker >= 0xd0 && marker <= 0xd7) || marker === 0x01) { p += 2; continue; }
    if (marker === 0xff) { p += 1; continue; }
    const len = (b[p + 2] << 8) | b[p + 3];
    const seg = p + 4;
    if (marker === 0xe1 && String.fromCharCode(...b.subarray(seg, seg + 4)) === 'Exif') orientation = exifOrientation(b, seg + 6, len - 8) || 1;
    if (marker === 0xee && String.fromCharCode(...b.subarray(seg, seg + 5)) === 'Adobe') adobe = true;
    if ((marker >= 0xc0 && marker <= 0xcf) && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) {
      height = (b[seg + 1] << 8) | b[seg + 2];
      width = (b[seg + 3] << 8) | b[seg + 4];
      comps = b[seg + 5];
      break;
    }
    if (marker === 0xda) break;
    p += 2 + len;
  }
  if (!width || !height) throw new ImageRejected('JPEG sem dimensões legíveis.');
  const cs = comps === 1 ? '/DeviceGray' : comps === 3 ? '/DeviceRGB' : comps === 4 ? '/DeviceCMYK' : '';
  if (!cs) throw new ImageRejected('JPEG com espaço de cor não suportado.');
  const decode = comps === 4 && adobe ? ' /Decode [1 0 1 0 1 0 1 0]' : '';
  return {
    width, height, orientation: orientation >= 1 && orientation <= 8 ? orientation : 1, data: b,
    dict: `/Type /XObject /Subtype /Image /Width ${width} /Height ${height} /ColorSpace ${cs} /BitsPerComponent 8 /Filter /DCTDecode${decode}`,
  };
}

function exifOrientation(b: Uint8Array, start: number, length: number): number {
  const end = Math.min(b.length, start + Math.max(0, length));
  if (start + 8 > end) return 1;
  const le = b[start] === 0x49;
  const u16 = (o: number) => le ? b[o] | (b[o + 1] << 8) : (b[o] << 8) | b[o + 1];
  const u32 = (o: number) => le ? (b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)) >>> 0 : ((b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]) >>> 0;
  const ifd = start + u32(start + 4);
  if (ifd + 2 > end) return 1;
  const n = u16(ifd);
  for (let i = 0; i < n; i++) {
    const e = ifd + 2 + i * 12;
    if (e + 12 > end) break;
    if (u16(e) === 0x0112) return u16(e + 8);
  }
  return 1;
}

// ---------- PNG ----------
async function png(b: Uint8Array): Promise<PdfImage> {
  const u32 = (o: number) => ((b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]) >>> 0;
  let p = 8, width = 0, height = 0, depth = 0, color = 0, interlace = 0;
  let palette: Uint8Array | null = null, trns: Uint8Array | null = null;
  const idat: Uint8Array[] = [];
  while (p + 8 <= b.length) {
    const len = u32(p), type = String.fromCharCode(b[p + 4], b[p + 5], b[p + 6], b[p + 7]);
    const data = b.subarray(p + 8, p + 8 + len);
    if (data.length !== len) throw new ImageRejected('PNG incompleto.');
    if (type === 'IHDR') { width = u32(p + 8); height = u32(p + 12); depth = b[p + 16]; color = b[p + 17]; interlace = b[p + 20]; }
    else if (type === 'PLTE') palette = data;
    else if (type === 'tRNS') trns = data;
    else if (type === 'IDAT') idat.push(data);
    else if (type === 'IEND') break;
    p += 12 + len;
  }
  if (!width || !height || idat.length === 0) throw new ImageRejected('PNG sem imagem legível.');
  if (interlace) throw new ImageRejected('PNG entrelaçado não suportado; salve a imagem sem entrelaçamento.');
  const zdata = concat(idat);
  const channels = ({ 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 } as Record<number, number>)[color];
  if (!channels) throw new ImageRejected('PNG com tipo de cor inválido.');
  const base = `/Type /XObject /Subtype /Image /Width ${width} /Height ${height}`;
  const hasAlpha = color === 4 || color === 6 || (color === 3 && trns !== null);
  if (!hasAlpha && (color === 0 || color === 2 || color === 3)) {
    // Sem transparência: os dados comprimidos do PNG vão direto, com o preditor PNG.
    let cs = color === 0 ? '/DeviceGray' : '/DeviceRGB';
    if (color === 3) {
      if (!palette) throw new ImageRejected('PNG indexado sem paleta.');
      cs = `[/Indexed /DeviceRGB ${palette.length / 3 - 1} <${hex(palette)}>]`;
    }
    let mask = '';
    if (trns && color === 0 && depth <= 8) { const v = (trns[0] << 8) | trns[1]; mask = ` /Mask [${v} ${v}]`; }
    if (trns && color === 2 && depth === 8) { const r = trns[1], g = trns[3], bl = trns[5]; mask = ` /Mask [${r} ${r} ${g} ${g} ${bl} ${bl}]`; }
    return {
      width, height, orientation: 1, data: zdata,
      dict: `${base} /ColorSpace ${cs} /BitsPerComponent ${depth} /Filter /FlateDecode /DecodeParms << /Predictor 15 /Colors ${channels} /BitsPerComponent ${depth} /Columns ${width} >>${mask}`,
    };
  }
  // Transparência: decodifica, separa cor e alfa (SMask) e recomprime.
  const raw = unfilter(await inflate(zdata), width, height, channels, depth);
  const n = width * height;
  const rgbChannels = color === 4 ? 1 : 3;
  const colorOut = new Uint8Array(n * rgbChannels), alpha = new Uint8Array(n);
  if (color === 3) {
    if (!palette) throw new ImageRejected('PNG indexado sem paleta.');
    const idx = unpackBits(raw, width, height, depth);
    for (let i = 0; i < n; i++) {
      const k = idx[i];
      colorOut[i * 3] = palette[k * 3] ?? 0; colorOut[i * 3 + 1] = palette[k * 3 + 1] ?? 0; colorOut[i * 3 + 2] = palette[k * 3 + 2] ?? 0;
      alpha[i] = trns && k < trns.length ? trns[k] : 255;
    }
  } else {
    if (depth !== 8 && depth !== 16) throw new ImageRejected('PNG com transparência e profundidade não suportada.');
    const step = depth / 8, px = channels * step;
    for (let i = 0; i < n; i++) {
      const o = i * px;
      for (let c = 0; c < rgbChannels; c++) colorOut[i * rgbChannels + c] = raw[o + c * step];
      alpha[i] = raw[o + rgbChannels * step];
    }
  }
  return {
    width, height, orientation: 1, data: await deflate(colorOut),
    dict: `${base} /ColorSpace ${rgbChannels === 1 ? '/DeviceGray' : '/DeviceRGB'} /BitsPerComponent 8 /Filter /FlateDecode`,
    smask: { data: await deflate(alpha), dict: `/Type /XObject /Subtype /Image /Width ${width} /Height ${height} /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode` },
  };
}

function unfilter(data: Uint8Array, width: number, height: number, channels: number, depth: number): Uint8Array {
  const bpp = Math.max(1, Math.ceil((channels * depth) / 8));
  const stride = Math.ceil((width * channels * depth) / 8);
  if (data.length < height * (stride + 1)) throw new ImageRejected('PNG incompleto.');
  const out = new Uint8Array(height * stride);
  for (let y = 0; y < height; y++) {
    const f = data[y * (stride + 1)];
    const src = y * (stride + 1) + 1, dst = y * stride, prev = dst - stride;
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? out[dst + x - bpp] : 0;
      const up = y > 0 ? out[prev + x] : 0;
      const c = y > 0 && x >= bpp ? out[prev + x - bpp] : 0;
      let v = data[src + x];
      if (f === 1) v += a;
      else if (f === 2) v += up;
      else if (f === 3) v += (a + up) >> 1;
      else if (f === 4) { const pp = a + up - c, pa = Math.abs(pp - a), pb = Math.abs(pp - up), pc = Math.abs(pp - c); v += pa <= pb && pa <= pc ? a : pb <= pc ? up : c; }
      else if (f !== 0) throw new ImageRejected('PNG com filtro inválido.');
      out[dst + x] = v & 255;
    }
  }
  return out;
}

function unpackBits(raw: Uint8Array, width: number, height: number, depth: number): Uint8Array {
  if (depth === 8) return raw;
  const stride = Math.ceil((width * depth) / 8), out = new Uint8Array(width * height), mask = (1 << depth) - 1;
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const bit = x * depth, byte = raw[y * stride + (bit >> 3)];
    out[y * width + x] = (byte >> (8 - depth - (bit & 7))) & mask;
  }
  return out;
}

function concat(parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((s, x) => s + x.length, 0));
  let o = 0; for (const x of parts) { out.set(x, o); o += x.length; }
  return out;
}

function hex(b: Uint8Array): string { return Array.from(b, v => v.toString(16).padStart(2, '0')).join(''); }

/** Matriz de desenho (cm) que posiciona a imagem em (x, y, w, h) aplicando a orientação EXIF. */
export function placement(orientation: number, x: number, y: number, w: number, h: number): string {
  const f = (n: number) => fmt(n);
  switch (orientation) {
    case 2: return `${f(-w)} 0 0 ${f(h)} ${f(x + w)} ${f(y)} cm`;
    case 3: return `${f(-w)} 0 0 ${f(-h)} ${f(x + w)} ${f(y + h)} cm`;
    case 4: return `${f(w)} 0 0 ${f(-h)} ${f(x)} ${f(y + h)} cm`;
    case 5: return `0 ${f(-h)} ${f(-w)} 0 ${f(x + w)} ${f(y + h)} cm`;
    case 6: return `0 ${f(-h)} ${f(w)} 0 ${f(x)} ${f(y + h)} cm`;
    case 7: return `0 ${f(h)} ${f(w)} 0 ${f(x)} ${f(y)} cm`;
    case 8: return `0 ${f(h)} ${f(-w)} 0 ${f(x + w)} ${f(y)} cm`;
    default: return `${f(w)} 0 0 ${f(h)} ${f(x)} ${f(y)} cm`;
  }
}

/** Dimensões exibidas (após a orientação EXIF). */
export function displaySize(img: PdfImage): { w: number; h: number } {
  return img.orientation >= 5 ? { w: img.height, h: img.width } : { w: img.width, h: img.height };
}

export function fmt(n: number): string {
  const r = Math.round(n * 100) / 100;
  return Object.is(r, -0) ? '0' : String(r);
}
