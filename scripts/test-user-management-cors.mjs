import { stripTypeScriptTypes } from 'node:module';
import fs from 'node:fs';
import assert from 'node:assert/strict';

const origin = 'https://audita-pro-validacao.vinicius-eloisa2.chatgpt.site';
let handler, authCalls = 0, lookups = 0;
const admin = {
  auth: {
    getUser: async token => { authCalls++; return { data: { user: token === 'admin' || token === 'member' ? { id: 'actor', app_metadata: { platform_role: token === 'admin' ? 'admin' : 'member' } } : null } }; },
    admin: { getUserById: async id => { lookups++; return { data: { user: { id, app_metadata: { platform_role: 'admin' } } } }; } },
  },
  from: () => { const q = { select: () => q, eq: () => q, single: async () => ({ data: { user_id: 'actor', status: 'active' } }) }; return q; },
};
const source = fs.readFileSync(new URL('../outputs/audita-pro-supabase/supabase/functions/user-management/index.ts', import.meta.url), 'utf8').replace(/^import[^\n]+\n/gm, '');
const Deno = { env: { get: key => ({ SUPABASE_URL: 'https://example.invalid', SUPABASE_SERVICE_ROLE_KEY: 'test-only', AUDITA_PRO_ALLOWED_ORIGINS: 'https://configured.example' })[key] }, serve: fn => { handler = fn; } };
new Function('createClient', 'uploadProfileDocument', 'Deno', stripTypeScriptTypes(source, { mode: 'strip' }))(() => admin, () => { throw Error('Unexpected upload'); }, Deno);
const preflight = value => handler(new Request('https://example.invalid', { method: 'OPTIONS', headers: { Origin: value, 'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'authorization,apikey,content-type' } }));
for (const allowed of [origin, 'https://configured.example']) {
  const response = await preflight(allowed);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), allowed);
  for (const header of ['authorization', 'apikey', 'content-type']) assert.ok(response.headers.get('Access-Control-Allow-Headers').includes(header));
}
for (const denied of ['https://untrusted.example', origin + '.untrusted.example', 'null']) assert.notEqual((await preflight(denied)).headers.get('Access-Control-Allow-Origin'), denied);
assert.equal(authCalls, 0, 'Preflight must not require a session');
async function detail(token) { return handler(new Request('https://example.invalid', { method: 'POST', headers: { Origin: origin, Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify({ action: 'get_user_access', user_id: '11111111-1111-4111-8111-111111111111' }) })); }
let result = await detail('invalid'); assert.equal(result.status, 401); assert.equal(result.headers.get('Access-Control-Allow-Origin'), origin);
result = await detail('member'); assert.equal(result.status, 403); assert.equal(lookups, 0);
result = await detail('admin'); assert.equal(result.status, 200); assert.equal(result.headers.get('Access-Control-Allow-Origin'), origin); assert.equal((await result.json()).administrator, true); assert.equal(lookups, 1);
console.log('PASS: published and configured origins, rejected foreign origins, unauthenticated preflight, admin-only user detail, CORS on success and error responses.');
