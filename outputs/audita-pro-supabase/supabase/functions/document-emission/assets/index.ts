// Recursos embutidos no emissor (não dependem de CDN nem de Storage). Cada um tem hash registrado no manifesto.
import { LOGO_BASE64, LOGO_SHA256 } from './logo.ts';

export function fromBase64(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export const BUILTIN_ASSETS: Record<string, { sha256: string; load: () => Uint8Array }> = {
  'builtin:logo': { sha256: LOGO_SHA256, load: () => fromBase64(LOGO_BASE64) },
};
