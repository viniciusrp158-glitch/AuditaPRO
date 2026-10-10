// B06 — Arquivos da FPA (D09: arquivo recebido e registrado pelo condutor; sem upload do cliente).
// Autoriza cada operação chamando public.audit_fpa com o token do usuário e usa a service role
// somente para o Storage privado audit-fpa. A service role nunca vai ao navegador.
import { createClient } from 'npm:@supabase/supabase-js@2.57.0';
import { detectFormat, FileRejected, MAX_BYTES, safeFilename, sha256Hex } from './office.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const secret = Deno.env.get('SUPABASE_SECRET_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const publicKey = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY')!;
const admin = createClient(url, secret, { auth: { persistSession: false, autoRefreshToken: false } });
const BUCKET = 'audit-fpa';
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

Deno.serve(async request => {
  const origin = request.headers.get('Origin') ?? '';
  if (request.method === 'OPTIONS') return reply({}, 200, origin);
  if (request.method !== 'POST') return reply({ error: 'Método não permitido.' }, 405, origin);
  const authorization = request.headers.get('Authorization') ?? '';
  if (!/^Bearer\s+\S+$/i.test(authorization)) return reply({ error: 'Sessão inválida.' }, 401, origin);
  const { data: who, error: authError } = await admin.auth.getUser(authorization.replace(/^Bearer\s+/i, ''));
  if (authError || !who.user) return reply({ error: 'Sessão inválida.' }, 401, origin);
  const caller = createClient(url, publicKey, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } });
  const rpc = async (command: string, payload: Record<string, unknown>) => {
    const { data, error } = await caller.rpc('audit_fpa', { command, payload });
    if (error) throw Object.assign(new Error(error.message), { code: error.code });
    return data;
  };
  try {
    const type = request.headers.get('Content-Type') ?? '';
    if (type.includes('multipart/form-data')) {
      const declared = Number(request.headers.get('Content-Length') ?? '0');
      if (declared > MAX_BYTES + 64 * 1024) throw new FileRejected('Arquivo acima do limite de 20 MB.');
      const form = await request.formData();
      if (form.get('action') !== 'upload') throw new Error('Ação inválida.');
      const file = form.get('file');
      if (!(file instanceof File)) throw new FileRejected('Selecione um arquivo.');
      if (file.size > MAX_BYTES) throw new FileRejected('Arquivo acima do limite de 20 MB.');
      const bytes = new Uint8Array(await file.arrayBuffer());
      const detected = await detectFormat(bytes);
      const requested = String(form.get('format') ?? '');
      if (requested && requested !== detected.format)
        throw new FileRejected(`O conteúdo do arquivo é ${detected.format.toUpperCase()}, não ${requested.toUpperCase()}.`);
      const auditId = String(form.get('audit_id') ?? '');
      const authorized = await rpc('authorize_upload', { audit_id: auditId, format: detected.format });
      const sha256 = await sha256Hex(bytes);
      const uploaded = await admin.storage.from(BUCKET).upload(authorized.path, bytes, { contentType: detected.mime, upsert: false });
      if (uploaded.error) throw new Error('Não foi possível armazenar o arquivo. Nada foi registrado; tente novamente.');
      try {
        const registered = await rpc('register_file', {
          audit_id: auditId, expected_lock_version: Number(form.get('expected_lock_version')), format: detected.format, path: authorized.path,
          filename: safeFilename(file.name, detected.format), size_bytes: bytes.length, sha256, mime_type: detected.mime,
          received_on: String(form.get('received_on') ?? ''), source_note: String(form.get('source_note') ?? ''),
        });
        return reply(registered, 200, origin);
      } catch (error) {
        // Registro não confirmado: o objeto órfão é removido para não deixar arquivo sem cadastro.
        await admin.storage.from(BUCKET).remove([authorized.path]);
        throw error;
      }
    }
    const body = await request.json() as Record<string, unknown>;
    if (body.action === 'download') {
      const file = await rpc('download', { audit_id: body.audit_id, version_id: body.version_id });
      const signed = await admin.storage.from(BUCKET).createSignedUrl(file.path, 60, { download: file.filename });
      if (signed.error) throw new Error('Falha ao preparar o download. Tente novamente.');
      return reply({ url: signed.data.signedUrl, filename: file.filename, sha256: file.sha256 }, 200, origin);
    }
    return reply({ error: 'Ação desconhecida.' }, 400, origin);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Falha ao processar a solicitação.';
    const code = (error as { code?: string }).code;
    const status = error instanceof FileRejected ? 422 : code === '42501' ? 403 : 400;
    return reply({ error: message }, status, origin);
  }
});
