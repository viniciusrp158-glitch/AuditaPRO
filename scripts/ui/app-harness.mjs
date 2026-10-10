// Harness de interface: serve outputs/ e substitui o supabase-js por um cliente simulado no navegador.
// Serve para validar apresentação/fluxo da tela. Autorização real é testada no banco (scripts/test-*.sql).
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { chromium } = (() => { try { return require('playwright'); } catch { return require(path.join(execFileSync('npm', ['root', '-g']).toString().trim(), 'playwright')); } })();
export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const OUT = path.join(ROOT, 'outputs');
const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.png': 'image/png', '.svg': 'image/svg+xml' };

// Cliente Supabase simulado. window.__mock (definido por cenário) responde rpc/from/functions.
const MOCK_SUPABASE = `
window.__calls = [];
window.supabase = { createClient() {
  const m = window.__mock;
  const result = async v => { const r = await v; return r && ('data' in r || 'error' in r) ? r : { data: r, error: null }; };
  const builder = (table) => { const ops = []; const b = new Proxy({}, { get(_, k) {
    if (k === 'then') return (res, rej) => result(m.from ? m.from(table, ops) : { data: [], error: null }).then(res, rej);
    return (...args) => { ops.push([k, args]); return b; }; } }); return b; };
  return {
    auth: {
      getSession: async () => ({ data: { session: m.user ? { access_token: 'token-teste', user: m.user } : null }, error: null }),
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }),
      signOut: async () => ({ error: null }),
    },
    rpc: (name, args) => { window.__calls.push({ name, command: args?.command, payload: args?.payload }); return result(m.rpc(name, args?.command, args?.payload || {})); },
    from: table => { window.__calls.push({ from: table }); return builder(table); },
    storage: { from: () => ({ createSignedUrl: async () => ({ data: { signedUrl: 'about:blank' }, error: null }) }) },
  };
} };`;

export async function start() {
  const server = http.createServer((q, r) => {
    const u = new URL(q.url, 'http://x');
    const file = path.resolve(OUT, '.' + decodeURIComponent(u.pathname));
    if (!file.startsWith(OUT)) { r.writeHead(403).end(); return; }
    fs.readFile(file, (e, d) => { if (e) { r.writeHead(404).end('nf'); return; } r.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' }); r.end(d); });
  }).listen(0, '127.0.0.1');
  await new Promise(r => server.once('listening', r));
  const browser = await chromium.launch({ executablePath: fs.existsSync('/opt/pw-browsers/chromium') ? '/opt/pw-browsers/chromium' : undefined });
  const base = `http://127.0.0.1:${server.address().port}`;
  return {
    base,
    async page({ scenario, viewport = { width: 1280, height: 900 }, functions } = {}) {
      const context = await browser.newContext({ viewport });
      const page = await context.newPage();
      page.errors = [];
      page.on('pageerror', e => page.errors.push(e.message));
      await page.route('https://cdn.jsdelivr.net/**', route => route.fulfill({ contentType: 'text/javascript', body: MOCK_SUPABASE }));
      await page.route('**/functions/v1/**', async route => {
        const req = route.request();
        const body = req.headers()['content-type']?.includes('application/json') ? JSON.parse(req.postData() || '{}') : { multipart: true, size: (req.postDataBuffer() || Buffer.alloc(0)).length };
        page.functionCalls = [...(page.functionCalls || []), body];
        const [status, json] = functions ? await functions(body) : [500, { error: 'não simulado' }];
        await route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(json) });
      });
      await page.route('https://download.test/**', route => route.fulfill({ status: 200, body: 'arquivo' }));
      await page.addInitScript(scenario);
      return page;
    },
    async close() { await browser.close(); server.close(); },
  };
}

// Cenário base por perfil. `extra` é um trecho JS que pode sobrescrever window.__mock.rpc.
export function scenario(role, extra = '') {
  return `(() => {
  const role = ${JSON.stringify(role)};
  const ready = role !== 'pending';
  const profileName = { leader: 'Auditor Líder', auditor: 'Auditor', participant: 'Participante / Auditado', pending: 'Auditor' }[role];
  window.__mock = {
    user: { id: 'u-' + role, email: role + '@teste.invalid', app_metadata: role === 'admin' ? { platform_role: 'admin' } : {} },
    library: { items: [], total: 0 },
    rpc(name, command, payload) {
      if (name === 'profile_command' && command === 'context') return { admin: role === 'admin', profile: { full_name: 'Teste ' + role, email: role + '@teste.invalid' }, positions: [], requests: [],
        memberships: role === 'admin' ? [] : [{ id: 'm1', organization: 'TESTE X', profile: profileName, ready, participant_functional_readonly: role === 'participant' }] };
      if (name === 'notification_command') return { items: [], unread_count: 0, pending_count: 0, total: 0, as_of: new Date().toISOString() };
      if (name === 'corporate_library' && command === 'context') return { can_read: ['admin', 'leader', 'auditor'].includes(role), can_manage: role === 'admin', can_history: role === 'admin', formats: ['pdf', 'docx', 'dotx'], max_bytes: 20971520, types: [] };
      if (name === 'corporate_library' && command === 'list') return { items: window.__mock.library.items, total: window.__mock.library.total, page: 0, page_size: 20, as_of: new Date().toISOString() };
      return { data: null, error: { message: 'não simulado: ' + name + '/' + command } };
    },
  };
  ${extra}
})();`;
}

export async function settle(page, predicate = () => window.__calls?.some(c => c.name === 'corporate_library' && c.command === 'context')) {
  for (let i = 0; i < 3; i++) {
    await page.waitForLoadState('load'); await page.waitForTimeout(250);
    try { await page.waitForFunction(predicate, null, { timeout: 5000 }); await page.waitForTimeout(150); return; } catch (e) { if (i === 2) throw e; }
  }
}
export const visibleNav = page => page.$$eval('aside nav a', links => links.filter(a => !a.hidden && getComputedStyle(a).display !== 'none' && a.offsetParent !== null).map(a => a.textContent.replace(/[▦▤♟♙▣]| /g, '').trim()));
