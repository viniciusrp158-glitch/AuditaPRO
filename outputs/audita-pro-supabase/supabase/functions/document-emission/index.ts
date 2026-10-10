// B08 — Emissor documental compartilhado. Autoriza cada ação chamando public.document_emission com o token do usuário;
// usa a service role só para o processador (public.document_emission_worker) e para o bucket privado document-emissions.
// A service role nunca vai ao navegador; o download é uma URL temporária de 60 s do arquivo persistido da revisão.
import { createClient } from 'npm:@supabase/supabase-js@2.57.0';
import { type Deps, processEmission, runTicket } from './emit.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const secret = Deno.env.get('SUPABASE_SECRET_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const publicKey = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY')!;
const admin = createClient(url, secret, { auth: { persistSession: false, autoRefreshToken: false } });
const origins = new Set((Deno.env.get('AUDITA_PRO_ALLOWED_ORIGINS') ??
  'https://auditapro.app.br,https://www.auditapro.app.br,https://audita-pro-validacao.vinicius-eloisa2.chatgpt.site,http://localhost:4173,http://127.0.0.1:4173')
  .split(',').map(v => v.trim()).filter(Boolean));

function reply(body: unknown, status: number, origin: string): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'Vary': 'Origin',
      'Access-Control-Allow-Origin': origins.has(origin) ? origin : '',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
    },
  });
}

const deps: Deps = {
  worker: async (command, payload) => {
    const { data, error } = await admin.rpc('document_emission_worker', { command, payload });
    if (error) throw new Error(error.message);
    return data;
  },
  upload: async (bucket, path, bytes) => {
    const { error } = await admin.storage.from(bucket).upload(path, bytes, { contentType: 'application/pdf', upsert: false });
    if (error) throw new Error('Falha ao armazenar o PDF gerado.');
  },
  download: async (bucket, path) => {
    const { data, error } = await admin.storage.from(bucket).download(path);
    if (error || !data) throw new Error('Falha ao ler o arquivo armazenado.');
    return new Uint8Array(await data.arrayBuffer());
  },
  remove: async (bucket, path) => { await admin.storage.from(bucket).remove([path]); },
  ticket: async (command, payload) => {
    const { data, error } = await admin.rpc('document_emission_ticket', { command, payload });
    if (error) throw new Error(error.message);
    return data;
  },
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async request => {
  const origin = request.headers.get('Origin') ?? '';
  if (request.method === 'OPTIONS') return reply({}, 200, origin);
  if (request.method !== 'POST') return reply({ error: 'Método não permitido.' }, 405, origin);
  // Acionamento pelo próprio banco (pg_net): o bilhete de uso único é a credencial e é validado no banco.
  if (!request.headers.get('Authorization') && (request.headers.get('Content-Type') ?? '').includes('application/json')) {
    const body = await request.clone().json().catch(() => ({})) as Record<string, unknown>;
    if (body.action === 'ticket') {
      if (!UUID.test(String(body.ticket ?? ''))) return reply({ error: 'Bilhete inválido.' }, 400, origin);
      try {
        const out = await runTicket(deps, String(body.ticket));
        return reply(out, out.valid ? 200 : 403, origin);
      } catch {
        return reply({ error: 'Falha ao processar o bilhete.' }, 500, origin);
      }
    }
  }
  const authorization = request.headers.get('Authorization') ?? '';
  if (!/^Bearer\s+\S+$/i.test(authorization)) return reply({ error: 'Sessão inválida.' }, 401, origin);
  const { data: who, error: authError } = await admin.auth.getUser(authorization.replace(/^Bearer\s+/i, ''));
  if (authError || !who.user) return reply({ error: 'Sessão inválida.' }, 401, origin);
  const caller = createClient(url, publicKey, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } });
  const rpc = async (command: string, payload: Record<string, unknown>) => {
    const { data, error } = await caller.rpc('document_emission', { command, payload });
    if (error) throw Object.assign(new Error(error.message), { code: error.code });
    return data;
  };
  try {
    const body = await request.json() as Record<string, unknown>;
    const action = String(body.action ?? '');
    if (action === 'status') return reply(await rpc('status', { emission_id: body.emission_id }), 200, origin);
    if (action === 'download') {
      const file = await rpc('authorize_download', { emission_id: body.emission_id });
      const signed = await admin.storage.from(file.bucket).createSignedUrl(file.path, 60, { download: file.filename });
      if (signed.error) throw new Error('Falha ao preparar o download. Tente novamente.');
      return reply({ url: signed.data.signedUrl, filename: file.filename, sha256: file.sha256, size_bytes: file.size_bytes }, 200, origin);
    }
    let emissionId = String(body.emission_id ?? '');
    if (action === 'request_specimen') {
      const created = await rpc('request_specimen', { operation_id: body.operation_id, params: body.params ?? {} });
      emissionId = created.id;
    } else if (action === 'retry') {
      await rpc('retry', { emission_id: emissionId });
    } else if (action !== 'process') {
      return reply({ error: 'Ação desconhecida.' }, 400, origin);
    }
    await rpc('status', { emission_id: emissionId }); // autorização do usuário antes de processar
    const result = await processEmission(deps, emissionId, who.user.id);
    const status = await rpc('status', { emission_id: emissionId });
    return reply({ ...result, emission: status }, 200, origin);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Falha ao processar a solicitação.';
    const code = (error as { code?: string }).code;
    return reply({ error: message }, code === '42501' ? 403 : code === 'P0002' ? 409 : 400, origin);
  }
});
