// Orquestração de uma tentativa de emissão (B08). Independente do runtime: as dependências (RPC do processador e Storage)
// são injetadas, o que permite testar falhas de geração, upload, conferência e confirmação fora do Supabase.
import { BUILTIN_ASSETS } from './assets/index.ts';
import { ENGINE_VERSION, renderDocument } from './pdf/layout.ts';
import { sha256Hex } from './pdf/zlib.ts';
import { type AssetRef, resolveTemplate } from './templates/index.ts';
import { samplePng } from './templates/specimen.ts';
import { planDoc } from './templates/plan.ts';

export const MAX_PDF_BYTES = 50 * 1024 * 1024;
const ASSET_BUCKETS = new Set(['audit-evidence', 'audit-evidence-workspace']);

export type Deps = {
  worker: (command: 'claim' | 'complete' | 'fail', payload: Record<string, unknown>) => Promise<Record<string, any>>;
  upload: (bucket: string, path: string, bytes: Uint8Array) => Promise<void>;     // upsert:false
  download: (bucket: string, path: string) => Promise<Uint8Array>;
  remove: (bucket: string, path: string) => Promise<void>;
  ticket?: (command: 'consume' | 'result', payload: Record<string, unknown>) => Promise<Record<string, any>>;
  now?: () => number;
};

export type ProcessResult = { state: string; emission?: Record<string, unknown>; error?: string };

export class EmissionFailure extends Error {}

export function sanitize(error: unknown): string {
  const msg = error instanceof Error ? error.message : String(error ?? 'Falha desconhecida');
  return msg.replace(/eyJ[\w-]+\.[\w-]+\.[\w-]+/g, '[token]').replace(/https?:\/\/\S+/g, '[url]').replace(/\s+/g, ' ').slice(0, 300);
}

async function loadAsset(d: Deps, ref: AssetRef): Promise<Uint8Array> {
  if (ref.source === 'builtin') {
    const a = BUILTIN_ASSETS[ref.id];
    if (!a) throw new EmissionFailure(`Recurso embutido desconhecido: ${ref.id}`);
    const bytes = a.load();
    if (await sha256Hex(bytes) !== a.sha256) throw new EmissionFailure(`Recurso embutido alterado: ${ref.id}`);
    return bytes;
  }
  if (ref.source === 'generated') return await samplePng();
  if (!ASSET_BUCKETS.has(ref.bucket)) throw new EmissionFailure('Recurso fora dos repositórios autorizados para emissão.');
  const bytes = await d.download(ref.bucket, ref.path);
  if (ref.sha256 && await sha256Hex(bytes) !== ref.sha256) throw new EmissionFailure('Imagem selecionada foi alterada depois do congelamento da revisão.');
  return bytes;
}

/** Executa uma tentativa. Nunca deixa um arquivo não confirmado como oficial; remove só o que esta tentativa criou. */
export async function processEmission(d: Deps, emissionId: string, actor: string | null): Promise<ProcessResult> {
  const now = d.now ?? (() => performance.now());
  const claim = await d.worker('claim', { emission_id: emissionId, triggered_by: actor, lease_seconds: 180 });
  if (claim.state !== 'claimed') return { state: claim.state, emission: claim.emission };
  const bucket = String(claim.storage_bucket), path = String(claim.storage_path), lease = String(claim.lease_token);
  const metrics: Record<string, number> = {};
  let uploaded = false, completeSent = false;
  try {
    let t = now();
    const template = resolveTemplate(String(claim.template_key), Number(claim.template_version));
    const { doc, assets } = template(claim.content ?? {}, {
      title: String(claim.title), revision_label: claim.revision_label ?? null, version_id: String(claim.version_id), requested_at: String(claim.requested_at),
    });
    const bytesByKey: Record<string, Uint8Array> = {};
    const manifest: Record<string, unknown>[] = [];
    for (const [key, ref] of Object.entries(assets)) {
      const bytes = await loadAsset(d, ref);
      bytesByKey[key] = bytes;
      manifest.push({ key, ...ref, sha256: await sha256Hex(bytes), size: bytes.length });
    }
    metrics.assets_ms = Math.round(now() - t); t = now();
    const r = await renderDocument(doc, bytesByKey, { idSeed: `${emissionId}:${claim.content_sha256}` });
    metrics.render_ms = Math.round(now() - t); t = now();
    if (r.bytes.length > MAX_PDF_BYTES) throw new EmissionFailure(`PDF com ${(r.bytes.length / 1048576).toFixed(1)} MB excede o limite de 50 MB; nada foi omitido nem reduzido.`);
    await d.upload(bucket, path, r.bytes);
    uploaded = true;
    metrics.upload_ms = Math.round(now() - t); t = now();
    const stored = await d.download(bucket, path);
    const verified = await sha256Hex(stored);
    metrics.verify_ms = Math.round(now() - t);
    if (stored.length !== r.bytes.length || verified !== r.sha256) throw new EmissionFailure('Arquivo armazenado não confere com o gerado.');
    metrics.pages = r.pages; metrics.bytes = r.bytes.length; metrics.images = r.images;
    completeSent = true;
    const done = await d.worker('complete', {
      emission_id: emissionId, lease_token: lease, storage_path: path, pdf_sha256: r.sha256, verified_sha256: verified,
      size_bytes: r.bytes.length, page_count: r.pages, engine_version: ENGINE_VERSION, asset_manifest: manifest,
      metrics: { ...metrics, warnings: r.warnings }, triggered_by: actor,
    });
    if (!done.accepted) {
      // Outra tentativa assumiu a posse: este arquivo não é oficial e é retirado.
      await d.remove(bucket, path).catch(() => {});
      return { state: 'lease_lost', emission: done.emission };
    }
    return { state: done.emission?.status === 'published' ? 'published' : 'ready', emission: done.emission };
  } catch (error) {
    const message = sanitize(error);
    // Se a confirmação foi enviada, o resultado é incerto (pode ter sido gravada): o arquivo é preservado.
    if (uploaded && !completeSent) await d.remove(bucket, path).catch(() => {});
    const failed = await d.worker('fail', { emission_id: emissionId, lease_token: lease, error: message, metrics, triggered_by: actor }).catch(() => null);
    return { state: 'failed', error: message, emission: failed?.emission };
  }
}

function memory(): Record<string, number> {
  const d = (globalThis as { Deno?: { memoryUsage?: () => { rss: number; heapUsed: number } } }).Deno;
  const m = d?.memoryUsage?.();
  return m ? { rss_mb: Math.round(m.rss / 1048576), heap_mb: Math.round(m.heapUsed / 1048576) } : {};
}

/** Autoteste no runtime: gera o documento de prova em memória, grava, confere e retira o arquivo; devolve medições. */
export async function selfTest(d: Deps, ticket: string, params: Record<string, unknown>): Promise<Record<string, unknown>> {
  const now = d.now ?? (() => performance.now());
  const t0 = now();
  const isPlan = params.template === 'plan' && typeof params.snapshot === 'object' && params.snapshot !== null;
  const { doc, assets } = isPlan
    ? { doc: planDoc(params.snapshot as Record<string, unknown>, { draft: true }), assets: { logo: { source: 'builtin', id: 'builtin:logo' } as AssetRef } }
    : resolveTemplate('specimen', 1)({ params, code: 'AUTOTESTE', issued_at: new Date().toISOString() },
      { title: 'Autoteste', revision_label: 'Rev.00', version_id: ticket, requested_at: new Date().toISOString() });
  const bytesByKey: Record<string, Uint8Array> = {};
  for (const [key, ref] of Object.entries(assets)) bytesByKey[key] = await loadAsset(d, ref);
  const t1 = now();
  const r = await renderDocument(doc, bytesByKey, { idSeed: `selftest:${ticket}` });
  const t2 = now();
  const path = `selftest/${ticket}.pdf`;
  await d.upload('document-emissions', path, r.bytes);
  const t3 = now();
  const stored = await d.download('document-emissions', path);
  const verified = await sha256Hex(stored);
  const t4 = now();
  await d.remove('document-emissions', path);
  return { ok: verified === r.sha256 && stored.length === r.bytes.length, engine: ENGINE_VERSION, template: isPlan ? 'plan' : 'specimen', params: isPlan ? { template: 'plan' } : params, pages: r.pages, bytes: r.bytes.length,
    images: r.images, sha256: r.sha256, assets_ms: Math.round(t1 - t0), render_ms: Math.round(t2 - t1), upload_ms: Math.round(t3 - t2),
    verify_ms: Math.round(t4 - t3), total_ms: Math.round(now() - t0), warnings: r.warnings, ...memory() };
}

/** Bilhete de uso único emitido pelo banco (pg_net/pg_cron): processa um pedido ou executa o autoteste. */
export async function runTicket(d: Deps, ticket: string): Promise<Record<string, unknown>> {
  if (!d.ticket) throw new EmissionFailure('Bilhetes indisponíveis.');
  const k = await d.ticket('consume', { ticket });
  if (!k.valid) return { valid: false };
  let result: Record<string, unknown>;
  try {
    result = k.purpose === 'selftest' ? await selfTest(d, ticket, k.params ?? {}) : { ...(await processEmission(d, String(k.emission_id), null)) };
  } catch (error) {
    result = { ok: false, error: sanitize(error) };
  }
  await d.ticket('result', { ticket, result }).catch(() => {});
  return { valid: true, purpose: k.purpose, state: (result as { state?: string }).state ?? (result.ok ? 'ok' : 'failed') };
}
