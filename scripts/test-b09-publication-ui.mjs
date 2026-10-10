// B09 — interface de validação e publicação do plano (PA-13/14/15, PER-09/10), servidor simulado no Chromium.
// Regras e estados reais: scripts/test-b09-plan.sql; PDF: scripts/test-b09-plan-pdf.mts.
import assert from 'node:assert/strict';
import { start } from './ui/app-harness.mjs';

const checks = (failing = []) => Array.from({ length: 15 }, (_, i) => ({ n: i + 1, label: `Verificação ${i + 1}`, step: i + 1 === 7 ? 'team' : i + 1 >= 10 && i + 1 <= 13 ? 'schedule' : i + 1 === 15 ? 'review' : 'identification',
  ok: !failing.includes(i + 1), errors: failing.includes(i + 1) ? [`Pendência ${i + 1}`] : [] }));
const em = (o = {}) => ({ id: 'e1', status: 'published', page_count: 4, last_error: null, ...o });
const ver = (o = {}) => ({ id: 'v0', version_number: 1, revision_label: 'Rev.00', state: 'published', reason: 'Emissão inicial do plano', created_at: '2026-10-10T20:00:00Z', published_at: '2026-10-10T20:01:00Z', author: 'Lider X', emission_id: 'e1', emission: em(), ...o });
const status = (o = {}) => ({ checks: checks(), warnings: [], ok: true, lock_version: 7, status: 'draft', plan_revision: 0, next_label: 'Rev.00', requires_reason: false, can_validate: true, open: null, versions: [], ...o });
const SCRIPT = state => `window.__calls = []; window.__state = ${JSON.stringify(state)};
 window.AUDITA_PRO_SUPABASE_URL = 'https://x.supabase.co'; window.AUDITA_PRO_SUPABASE_PUBLISHABLE_KEY = 'pk';
 window.confirm = () => true; window.prompt = () => 'Dia encerrado antes da publicação';
 window.fakeClient = { auth: { getSession: async () => ({ data: { session: { access_token: 't' } } }) },
  rpc: async (fn, { command, payload }) => { window.__calls.push({ fn, command, payload: JSON.parse(JSON.stringify(payload)) }); const st = window.__state;
   if (fn === 'audit_plan' && command === 'status') return { data: st.statusSeq ? st.statusSeq.shift() : st.status };
   if (fn === 'audit_plan' && command === 'versions') return st.versionsError ? { data: null, error: { message: 'Plano indisponível para este acesso' } } : { data: { versions: st.versions } };
   if (fn === 'audit_plan' && command === 'validate') return st.validateError ? { data: null, error: { message: st.validateError } } : { data: { version_id: 'v1', revision_label: st.status.next_label, emission: { id: 'e1', status: 'pending' } } };
   if (fn === 'audit_plan' && command === 'discard') return { data: { discarded: true } };
   if (fn === 'audit_plan' && command === 'publish_ready') return { data: { published: true } };
   return { data: null, error: { message: 'não simulado' } }; } };`;
const app = await start();
const passed = [];
const ok = (n, c, i = '') => { assert.ok(c, `${n} ${i}`); passed.push(n); console.log(`ok  ${n}`); };
async function open(state, { viewport, functions, mode = 'mount' } = {}) {
  const page = await app.page({ scenario: SCRIPT(state), viewport, functions });
  await page.goto(`${app.base}/audita-pro-biblioteca.html`);
  await page.evaluate(() => { document.body.innerHTML = '<main class="main"><div id="auditPanel" class="audit-body"></div></main>'; window.__tabs = []; });
  for (const href of ['audita-pro-users.css', 'audita-pro-audits.css', 'audita-pro-plan-identification.css']) await page.addStyleTag({ url: `${app.base}/${href}` });
  await page.addScriptTag({ url: `${app.base}/audita-pro-emission.js` });
  await page.addScriptTag({ url: `${app.base}/audita-pro-plan-publication.js` });
  if (mode === 'mount') await page.evaluate(() => window.AuditaPlanPublication.mount(document.querySelector('#auditPanel'), { client: window.fakeClient, auditId: 'a1', onTab: t => window.__tabs.push(t) }));
  else await page.evaluate(() => window.AuditaPlanPublication.versions(document.querySelector('#auditPanel'), { client: window.fakeClient, auditId: 'a1' }));
  return page;
}
const txt = page => page.$eval('#auditPanel', e => e.innerText);
try {
  // Pendências: lista com atalhos; validar desabilitado; avisos separados.
  let page = await open({ status: status({ ok: false, checks: checks([7, 14]), warnings: [{ message: 'Mesmo auditor em horário sobreposto' }] }) });
  let t = await txt(page);
  ok('15 verificações com contagem e pendências explicadas', t.includes('13 de 15') && t.includes('Pendência 7') && t.includes('Pendência 14'));
  ok('Avisos separados dos bloqueios', t.includes('não impedem a validação') && t.includes('Mesmo auditor em horário sobreposto'));
  ok('Validar desabilitado com pendência', await page.$eval('#ppValidate', b => b.disabled));
  await page.click('[data-pp-step="team"]');
  ok('Atalho leva à etapa que corrige (Equipe)', (await page.evaluate(() => window.__tabs)).join() === 'team');
  ok('Rascunho indicado como não disponibilizado ao cliente', t.includes('Ainda não disponibilizado ao cliente'));
  await page.close();

  // Validação Rev.00 → acompanhamento → publicado.
  page = await open({ status: status(), statusSeq: [status(), status({ open: { version_id: 'v1', revision_label: 'Rev.00', emission: em({ status: 'pending' }) } }),
    status({ plan_revision: 1, next_label: 'Rev.01', requires_reason: true, versions: [ver()] })] },
    { functions: async b => b.action === 'status' ? [200, em()] : [400, { error: 'x' }] });
  ok('Primeira emissão sem motivo obrigatório', (await txt(page)).includes('Motivo (opcional na primeira emissão)'));
  await page.click('#ppValidate');
  try { await page.waitForFunction(() => document.querySelector('#auditPanel').innerText.includes('Publicado — Rev.00'), null, { timeout: 15000 }); }
  catch (e) { console.log(await page.evaluate(() => JSON.stringify(window.__calls.map(c => c.command))), page.functionCalls, page.errors, (await txt(page)).slice(0, 400)); throw e; }
  const call = await page.evaluate(() => window.__calls.find(c => c.command === 'validate').payload);
  ok('Validação com operation_id e versão esperada (PA-14/PA-23)', /^[0-9a-f-]{36}$/.test(call.operation_id) && call.expected_lock_version === 7);
  ok('PA-13 publicado só após o PDF; aviso com páginas', (await txt(page)).includes('Plano publicado com PDF íntegro (4 páginas)'));
  ok('Histórico mostra a revisão com download do PDF', !!(await page.$('[data-pp-download="e1"]')));
  await page.close();

  // Nova revisão exige motivo (PA-15); revisão vigente continua enquanto o PDF é gerado (PER-10).
  page = await open({ status: status({ plan_revision: 1, next_label: 'Rev.01', requires_reason: true, versions: [ver()] }) });
  await page.click('#ppValidate');
  ok('PA-15 motivo obrigatório na nova revisão', (await page.$eval('#ppNotice', n => n.textContent)).includes('motivo') && !(await page.evaluate(() => window.__calls.some(c => c.command === 'validate'))));
  await page.close();
  page = await open({ status: status({ plan_revision: 1, versions: [ver()], open: { version_id: 'v1', revision_label: 'Rev.01', emission: em({ id: 'e2', status: 'processing' }) } }) },
    { functions: async () => [200, em({ id: 'e2', status: 'processing' })] });
  t = await txt(page);
  ok('PER-10 em geração: conteúdo congelado e vigente preservado', t.includes('Validado — PDF em geração (Rev.01)') && t.includes('revisão vigente continua disponível'));
  ok('Sem segunda validação enquanto há revisão aguardando PDF', await page.$eval('#ppValidate', b => b.disabled));
  await page.close();

  // Falha do PDF: nada publicado, retomar e descartar.
  page = await open({ status: status({ plan_revision: 1, versions: [ver()], open: { version_id: 'v1', revision_label: 'Rev.01', emission: em({ id: 'e2', status: 'failed', last_error: 'Falha ao armazenar o PDF gerado.' }) } }) },
    { functions: async b => b.action === 'retry' ? [200, { state: 'published' }] : b.action === 'status' ? [200, em({ id: 'e2' })] : [400, { error: 'x' }] });
  t = await txt(page);
  ok('Falha explicada e nada publicado; sem link de download da revisão falha', t.includes('Falha na geração do PDF (Rev.01)') && t.includes('Nada foi publicado') && !(await page.$('[data-pp-download="e2"]')));
  await page.click('#ppRetry');
  await page.waitForFunction(() => window.__calls.filter(c => c.command === 'status').length >= 2);
  ok('Tentar novamente retoma a mesma emissão', true);
  await page.close();
  page = await open({ status: status({ plan_revision: 1, versions: [ver()], open: { version_id: 'v1', revision_label: 'Rev.01', emission: em({ id: 'e2', status: 'ready', last_error: 'Arquivo íntegro; publicação bloqueada: Dia 04/11 encerrado' }) } }) });
  ok('PDF íntegro com publicação bloqueada mostra o motivo', (await txt(page)).includes('publicação bloqueada'));
  await page.click('#ppDiscard');
  await page.waitForFunction(() => window.__calls.some(c => c.command === 'discard'));
  ok('Descartar registra o motivo', (await page.evaluate(() => window.__calls.find(c => c.command === 'discard').payload.reason)).length > 5);
  await page.close();

  // Prévia: PDF devolvido pelo servidor, sem gravar.
  page = await open({ status: status() }, { functions: async b => b.action === 'preview_plan' ? [200, { ok: true }] : [400, {}] });
  await page.click('#ppPreview');
  await page.waitForFunction(() => document.querySelector('#ppPreview').textContent === 'Prévia do PDF');
  ok('Prévia pede o PDF da auditoria ao emissor', page.functionCalls.some(c => c.action === 'preview_plan' && c.audit_id === 'a1'));
  await page.close();

  // Cliente: só as revisões publicadas, sem rascunho nem descartadas.
  page = await open({ versions: [ver({ id: 'v1', revision_label: 'Rev.01', emission_id: 'e2', emission: em({ id: 'e2' }) }), ver({ state: 'superseded' })] }, { mode: 'versions' });
  t = await txt(page);
  ok('Cliente vê vigente e substituída, cada uma com seu PDF', t.includes('Rev.01') && t.includes('Substituída') && !!(await page.$('[data-pp-download="e2"]')) && !!(await page.$('[data-pp-download="e1"]')));
  await page.close();
  page = await open({ versionsError: true }, { mode: 'versions' });
  ok('PER-09 sem publicação, cliente vê aviso e nenhum documento', (await txt(page)).includes('ainda não foi publicado'));
  await page.close();

  page = await open({ status: status({ ok: false, checks: checks([3, 11]), versions: [ver()] }) }, { viewport: { width: 375, height: 800 } });
  ok('Tela pequena sem rolagem horizontal', await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1));
  ok('Sem erros de script', page.errors.length === 0, page.errors.join(' | '));
  await page.close();
} finally { await app.close(); }
console.log(`---- ${passed.length}/${passed.length} verificações da validação e publicação aprovadas`);
