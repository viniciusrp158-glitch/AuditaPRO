// B06 — interface Identificação e FPA (PA-03/04/05/06/11/12, PA-19) no Chromium, servidor simulado.
import assert from 'node:assert/strict';
import { start } from './ui/app-harness.mjs';

const ident = (over = {}) => ({ contract_version: 1, can_edit: true, identification: { audit_id: 'a1', code: 'AUD-2026-0007', status: 'draft', lock_version: 3,
  title: 'Auditoria — Cliente', unit_id: null, criterion_ids: ['t1'], standards: ['ISO 14001:2015'], party: 'first', modality: 'presential',
  location: null, objective: null, scope: null, evaluation_type: null, declared_start_date: null, declared_end_date: null, participants_text: null, comments: null,
  client: { id: 'o1', code: 'CLI-0001', name: 'TESTE Organização X', cnpj: '11222333000181', address: { street: 'Rua Teste', number: '100', city: 'Curitiba', state: 'PR' } },
  criteria_items: [{ id: 't1', code: 'ISO 14001', edition: '2015', name: 'Gestão ambiental' }], team: [{ membership_id: 'm1', name: 'Lider X', role: 'leader', conductor: true }],
  units: [{ id: 'u1', name: 'Matriz' }], criteria_locked: false, ...over } });
const SCRIPT = (state, canEdit = true) => `
  window.__calls = []; window.__state = ${JSON.stringify(state)};
  window.fakeClient = { auth: { getSession: async () => ({ data: { session: { access_token: 't' } } }) },
    rpc: async (fn, { command, payload }) => {
      window.__calls.push({ fn, command, payload });
      const st = window.__state;
      if (st.fail === fn + ':' + command) return { data: null, error: { message: 'Identificação alterada em outra sessão. Recarregue antes de salvar' } };
      if (fn === 'audit_identification' && command === 'detail') return { data: st.ident };
      if (fn === 'audit_identification' && command === 'save') { st.ident.identification = { ...st.ident.identification, ...payload, lock_version: payload.expected_lock_version + 1 }; return { data: { lock_version: 4 } }; }
      if (fn === 'audit_fpa' && command === 'detail') return { data: { ...st.fpa, can_edit: ${canEdit} } };
      const next = { request: 'requested', start_analysis: 'in_analysis', mark_sufficient: 'sufficient', request_complement: 'complement_requested' }[command];
      if (fn === 'audit_fpa' && next) { st.fpa = { ...st.fpa, ...payload, status: next, lock_version: st.fpa.lock_version + 1, sufficient_version_id: command === 'mark_sufficient' ? payload.version_id : st.fpa.sufficient_version_id,
        analyzed_by: 'Lider X', analyzed_at: new Date().toISOString(), events: [{ action: command, at: new Date().toISOString(), actor: 'Lider X' }, ...st.fpa.events] }; return { data: st.fpa }; }
      return { data: null, error: { message: 'não simulado ' + fn + '/' + command } };
    } };`;
const fpa0 = { status: 'not_requested', lock_version: 0, versions: [], events: [] };
const app = await start();
const passed = [];
const ok = (name, cond, info = '') => { assert.ok(cond, `${name} ${info}`); passed.push(name); };
async function open(state, { canEdit = true, viewport, functions } = {}) {
  const page = await app.page({ scenario: SCRIPT(state, canEdit), viewport, functions });
  await page.goto(`${app.base}/audita-pro-biblioteca.html`); // página qualquer servida; o teste monta o módulo isolado
  await page.evaluate(() => { document.body.innerHTML = '<main><div id="auditPanel"></div></main>'; });
  for (const href of ['audita-pro-users.css', 'audita-pro-audits.css', 'audita-pro-plan-identification.css']) await page.addStyleTag({ url: `${app.base}/${href}` });
  await page.addScriptTag({ url: `${app.base}/audita-pro-plan-identification.js` });
  await page.addScriptTag({ url: `${app.base}/audita-pro-plan-workspace.js` });
  await page.evaluate(() => window.AuditaPlanWorkspace.mount(document.querySelector('#auditPanel'), { client: window.fakeClient, auditId: 'a1',
    types: [{ id: 't1', code: 'ISO 14001', edition: '2015', name: 'Gestão ambiental', active: true }, { id: 't2', code: 'ISO 45001', edition: '2018', name: 'SST', active: true }] }));
  return page;
}
const panel = page => page.$eval('#auditPanel', e => e.innerText);
try {
  // Identificação: dados automáticos e pendências (PA-03/04)
  let page = await open({ ident: ident(), fpa: fpa0 });
  let t = await panel(page);
  ok('PA-03 código e endereço do cliente exibidos', t.includes('CLI-0001') && t.includes('Rua Teste, 100') && t.includes('Curitiba'));
  ok('PA-04 rascunho incompleto mostra pendências', (t.match(/Pendente/g) || []).length >= 7, String((t.match(/Pendente/g) || []).length));
  ok('Equipe com condutor identificado', t.includes('Lider X') && t.includes('Condutor'));
  // Edição (PA-05/06)
  await page.click('[data-pw=edit]'); await page.waitForSelector('#pwDialog[open]');
  const hint = await page.$$eval('#pwDialog .field-hint', hs => hs.filter(h => h.textContent.includes('Caso não se aplique, informar “N/A”.')).map(h => getComputedStyle(h).fontStyle));
  ok('PA-05 orientação N/A em itálico nos dois campos', hint.length === 2 && hint.every(s => s === 'italic'), JSON.stringify(hint));
  await page.fill('#pwDialog [name=participants_text]', 'N/A');
  ok('PA-05 orientação permanece após digitar', (await page.$$eval('#pwDialog .field-hint', hs => hs.filter(h => h.textContent.includes('N/A')).length)) === 2);
  await page.fill('#pwDialog [name=comments]', 'N/A'); await page.fill('#pwDialog [name=scope]', 'Processos produtivos');
  await page.selectOption('#pwDialog [name=evaluation_type]', 'certification'); await page.selectOption('#pwDialog [name=party]', 'third');
  await page.check('#pwDialog [name=criterion_ids][value=t2]');
  await page.fill('#pwDialog [name=declared_start_date]', '2026-10-20'); await page.fill('#pwDialog [name=declared_end_date]', '2026-10-23');
  await page.click('#pwDialog button:not([type=button])'); await page.waitForSelector('#pwDialog', { state: 'detached' });
  const save = await page.evaluate(() => window.__calls.find(c => c.command === 'save').payload);
  ok('PA-23 envia versão esperada', save.expected_lock_version === 3);
  ok('PA-06 dois critérios enviados', JSON.stringify(save.criterion_ids) === '["t1","t2"]');
  ok('PA-05 campos do cabeçalho enviados', save.participants_text === 'N/A' && save.comments === 'N/A' && save.evaluation_type === 'certification' && save.party === 'third' && save.declared_end_date === '2026-10-23');
  ok('Confirmação após salvar', (await page.$eval('#pwNotice', n => n.textContent)).includes('Identificação salva'));
  await page.close();
  // Conflito de edição aparece no diálogo (PA-23)
  page = await open({ ident: ident(), fpa: fpa0, fail: 'audit_identification:save' });
  await page.click('[data-pw=edit]'); await page.click('#pwDialog button:not([type=button])');
  await page.waitForFunction(() => document.querySelector('#pwDialogError')?.textContent.includes('outra sessão'));
  ok('PA-23 conflito exibido sem fechar o formulário', !!(await page.$('#pwDialog[open]')));
  await page.close();
  // Critérios travados após aplicação ao checklist
  page = await open({ ident: ident({ criteria_locked: true }), fpa: fpa0 });
  await page.click('[data-pw=edit]');
  ok('Critérios aplicados ficam bloqueados', await page.$$eval('#pwDialog [name=criterion_ids]', bs => bs.length > 0 && bs.every(b => b.disabled)));
  await page.close();

  // FPA: fluxo completo (PA-11/12)
  page = await open({ ident: ident(), fpa: fpa0 }, { functions: async b => b.multipart ? [200, {}] : b.action === 'download' ? [200, { url: 'https://download.test/fpa.pdf', filename: 'fpa.pdf' }] : [400, { error: 'x' }] });
  t = await panel(page);
  ok('PA-11 aviso de bloqueio da validação sem FPA suficiente', t.includes('validação final fica bloqueada'));
  ok('D09 sem recebimento antes da solicitação', !(await page.$('[data-pw-form=upload]')) && !!(await page.$('[data-pw-form=request]')));
  await page.fill('[data-pw-form=request] [name=recipient_name]', 'Gestora da Qualidade'); await page.fill('[data-pw-form=request] [name=due_date]', '2026-10-15');
  await page.click('[data-pw-form=request] button'); await page.waitForSelector('[data-pw-form=upload]');
  ok('Solicitação registrada com destinatário', (await panel(page)).includes('Gestora da Qualidade'));
  await page.setInputFiles('[data-pw-form=upload] [name=file]', { name: 'fpa.exe', mimeType: 'application/octet-stream', buffer: Buffer.from('MZ') });
  await page.click('[data-pw-form=upload] button'); await page.waitForSelector('#pwNotice.error:not([hidden])');
  ok('Formato inválido recusado sem envio', (await page.$eval('#pwNotice', n => n.textContent)).includes('PDF, DOCX ou XLSX') && !(page.functionCalls || []).length);
  await page.evaluate(() => { window.__state.fpa = { ...window.__state.fpa, status: 'received', versions: [{ id: 'v1', version_number: 1, format: 'xlsx', filename: 'fpa.xlsx', size_bytes: 2048, received_on: '2026-10-09', registered_at: new Date().toISOString(), registered_by: 'Lider X' }] }; });
  await page.setInputFiles('[data-pw-form=upload] [name=file]', { name: 'fpa.xlsx', mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', buffer: Buffer.from('PK') });
  await page.click('[data-pw-form=upload] button'); await page.waitForSelector('[data-pw=start_analysis]');
  ok('Recebimento enviado ao serviço de arquivos (multipart)', page.functionCalls.some(c => c.multipart));
  await page.click('[data-pw=start_analysis]'); await page.waitForSelector('[data-pw-form=sufficient]');
  ok('Análise oferece suficiência ou complementação', !!(await page.$('[data-pw-form=complement]')));
  await page.fill('[data-pw-form=sufficient] [name=note]', 'Suficiente');
  await page.click('[data-pw-form=sufficient] button'); await page.waitForFunction(() => document.querySelector('.badge.approved'));
  const suf = await page.evaluate(() => window.__calls.find(c => c.command === 'mark_sufficient').payload);
  ok('PA-12 suficiência vinculada à versão analisada', suf.version_id === 'v1');
  ok('PA-12 autoria da análise exibida', (await panel(page)).includes('considerada suficiente') && (await panel(page)).includes('Lider X'));
  const [dl] = await Promise.all([page.waitForEvent('request', r => r.url().startsWith('https://download.test/')), page.click('[data-pw-download=v1]')]);
  ok('Download da versão da FPA', !!dl && page.functionCalls.some(c => c.action === 'download' && c.version_id === 'v1'));
  ok('Sem erros de script', page.errors.length === 0, page.errors.join(' | '));
  await page.close();

  // Auditor de apoio: somente consulta (PA-19)
  page = await open({ ident: ident({ team: [{ name: 'Lider X', role: 'leader', conductor: true }, { name: 'Auditor X', role: 'auditor', conductor: false }] }), fpa: { ...fpa0, status: 'requested', recipient_name: 'Gestora' } }, { canEdit: false });
  await page.evaluate(() => { window.__state.ident.can_edit = false; });
  await page.evaluate(() => window.AuditaPlanWorkspace.mount(document.querySelector('#auditPanel'), { client: window.fakeClient, auditId: 'a1' }));
  t = await panel(page);
  ok('PA-19 apoio aparece na equipe', t.includes('Auditor X') && t.includes('Auditor de apoio'));
  ok('PA-19 apoio sem ações de edição', !(await page.$('[data-pw=edit]')) && !(await page.$('[data-pw-form]')));
  await page.close();

  // Erro de carregamento com nova tentativa; celular sem rolagem horizontal
  page = await open({ ident: ident(), fpa: fpa0, fail: 'audit_identification:detail' });
  ok('Erro de carregamento com nova tentativa', (await panel(page)).includes('Não foi possível carregar') && !!(await page.$('[data-pw=reload]')));
  await page.close();
  page = await open({ ident: ident(), fpa: { ...fpa0, status: 'in_analysis', versions: [{ id: 'v1', version_number: 1, format: 'pdf', filename: 'formulario-de-preparacao-com-nome-longo.pdf', size_bytes: 99999, received_on: '2026-10-09', registered_at: new Date().toISOString() }] } }, { viewport: { width: 390, height: 844 } });
  const w = await page.evaluate(() => document.documentElement.scrollWidth);
  ok('Tela pequena sem rolagem horizontal', w <= 391, `${w}px`);
  await page.close();
  console.log(passed.map(p => `ok  ${p}`).join('\n'));
  console.log(`---- ${passed.length}/${passed.length} verificações de Identificação e FPA aprovadas`);
} finally { await app.close(); }
