// B07 — editor de cronograma no Chromium (PA-07/08/10/17/19/23), servidor simulado.
import assert from 'node:assert/strict';
import { start } from './ui/app-harness.mjs';

const team = [{ membership_id: 'm-l', name: 'Lider X', role: 'leader', conductor: true }, { membership_id: 'm-a', name: 'Auditor X', role: 'auditor', conductor: false }];
const reqs = [{ id: 'q1', reference: '4.1', section: 'Contexto', criterion: 'ISO 14001 · 2015' }, { id: 'q2', reference: '6.1', section: 'Riscos', criterion: 'ISO 45001 · 2018' }];
const row = (o = {}) => ({ key: 'k1', id: null, continuation_of: null, title: 'Compras', process: 'Compras', category: 'assessment', date: '2026-10-20', start_time: '08:30', end_time: '10:00',
  location: 'Almoxarifado', assignee_ids: ['m-l'], requirements: ['q1'], notes: null, ...o });
const base = (o = {}) => ({ lock_version: 5, timezone: 'America/Sao_Paulo', status: 'draft', declared_start_date: '2026-10-20', declared_end_date: '2026-10-23', location: 'Rua Teste',
  items: [row(), row({ key: 'k2', id: 'pub-1', title: 'Produção', start_time: '10:00', end_time: '11:00', date: '2026-10-21' })], issues: [], published: [], can_edit: true, team, requirements: reqs, days: [], ...o });
const SCRIPT = state => `window.__calls = []; window.__state = ${JSON.stringify(state)};
 window.confirm = () => true;
 window.fakeClient = { rpc: async (fn, { command, payload }) => { window.__calls.push({ command, payload: JSON.parse(JSON.stringify(payload)) }); const st = window.__state;
  if (st.conflict && command === 'save') return { data: null, error: { code: '40001', message: 'Cronograma alterado em outra sessão' } };
  if (command === 'draft') return { data: st.draft };
  if (command === 'save') return { data: { lock_version: payload.expected_lock_version + 1, items: payload.items, issues: st.issues || [] } };
  if (command === 'record_outcome') { const p = st.draft.published.find(x => x.id === payload.schedule_id); Object.assign(p, { outcome: payload.outcome, performed_summary: payload.performed_summary, remaining_summary: payload.remaining_summary }); return { data: { lock_version: 9, published: st.draft.published } }; }
  return { data: null, error: { message: 'não simulado' } }; } };`;
const app = await start();
const passed = [];
const ok = (n, c, i = '') => { assert.ok(c, `${n} ${i}`); passed.push(n); };
async function open(state, viewport) {
  const page = await app.page({ scenario: SCRIPT(state), viewport });
  await page.goto(`${app.base}/audita-pro-biblioteca.html`);
  await page.evaluate(() => { document.body.innerHTML = '<main class="main"><div id="auditPanel" class="audit-body"></div></main>'; });
  for (const href of ['audita-pro-users.css', 'audita-pro-audits.css', 'audita-pro-plan-identification.css']) await page.addStyleTag({ url: `${app.base}/${href}` });
  await page.addScriptTag({ url: `${app.base}/audita-pro-schedule-editor.js` });
  await page.evaluate(() => window.AuditaScheduleEditor.mount(document.querySelector('#auditPanel'), { client: window.fakeClient, auditId: 'a1' }));
  return page;
}
const keys = page => page.$$eval('.se-row', rs => rs.map(r => r.dataset.key));
const lastSave = page => page.evaluate(() => window.__calls.filter(c => c.command === 'save').at(-1)?.payload);
try {
  let page = await open({ draft: base() });
  ok('PA-07 colunas: local, data, início, término, atividade e auditores', await page.$$eval('.se-row:first-child [data-f]', fs => ['location', 'date', 'start_time', 'end_time', 'title'].every(f => fs.some(x => x.dataset.f === f)))
    && !!(await page.$('.se-row:first-child [data-assignee="m-a"]')));
  // Duplicar: nova identidade, sem id publicado
  await page.click('.se-row[data-key=k2] [data-act=dup]');
  let ks = await keys(page);
  ok('PA-08 duplicar cria nova linha logo abaixo', ks.length === 3 && ks[1] === 'k2' && ks[2] !== 'k2');
  await page.click('[data-se=save]'); await page.waitForFunction(() => window.__calls.some(c => c.command === 'save'));
  let s = await lastSave(page);
  ok('PA-08 cópia não herda identidade publicada nem continuação', s.items[2].id === null && s.items[2].continuation_of === null && s.items[1].id === 'pub-1');
  ok('PA-08 cópia mantém requisitos como referência, sem multiplicar', JSON.stringify(s.items[2].requirements) === JSON.stringify(s.items[1].requirements));
  ok('PA-23 salva com versão esperada e operation_id', s.expected_lock_version === 5 && /^[0-9a-f-]{36}$/.test(s.operation_id));
  // Copiar para o próximo horário
  await page.click('.se-row[data-key=k1] [data-act=next]');
  await page.click('[data-se=save]'); await page.waitForFunction(() => window.__calls.filter(c => c.command === 'save').length === 2);
  s = await lastSave(page);
  ok('Copiar p/ próximo horário começa no término e preserva a duração', s.items[1].start_time === '10:00' && s.items[1].end_time === '11:30' && s.items[1].date === '2026-10-20');
  ok('Lock atualizado pelo servidor entre salvamentos', s.expected_lock_version === 6);
  // Reordenar
  ks = await keys(page);
  await page.click(`.se-row[data-key="${ks[1]}"] [data-act=up]`);
  ok('Subir altera somente a ordem visual', (await keys(page))[0] === ks[1] && (await keys(page))[1] === ks[0]);
  await page.click(`.se-row[data-key="${ks[1]}"] [data-act=down]`);
  ok('Descer devolve a posição', (await keys(page))[0] === ks[0]);
  // Copiar para outro dia: diálogo com dias planejados, sem presumir dia corrido
  await page.click('.se-row[data-key=k1] [data-act=otherday]'); await page.waitForSelector('.se-dialog[open]');
  ok('Copiar p/ outro dia sugere o próximo dia realmente planejado', (await page.$eval('.se-dialog [name=date]', i => i.value)) === '2026-10-21');
  await page.click('.se-dialog [data-pick="2026-10-21"]'); await page.fill('.se-dialog [name=date]', '2026-10-23'); await page.click('.se-dialog button:not([type=button])');
  ok('Cópia criada na data escolhida', await page.$$eval('.se-row [data-f=date]', is => is.some(i => i.value === '2026-10-23')));
  await page.close();

  // Copiar p/ próximo horário não atravessa a meia-noite
  page = await open({ draft: base({ items: [row({ start_time: '22:30', end_time: '23:30' })] }) });
  await page.click('.se-row [data-act=next]');
  ok('Cópia que atravessaria meia-noite é recusada com orientação', (await keys(page)).length === 1 && (await page.$eval('#seNotice', n => n.textContent)).includes('meia-noite'));
  await page.close();

  // Erros e avisos do servidor por linha (PA-09/10)
  page = await open({ draft: base({ issues: [{ key: 'k1', level: 'error', field: 'date', message: 'Data posterior ao período declarado' },
    { key: 'k2', level: 'warning', field: 'assignees', message: 'Mesmo auditor em horário sobreposto com "Compras" (08:30–10:00)' }, { key: null, level: 'error', field: 'requirements', message: '1 requisito(s) dos checklists ainda não distribuído(s) no cronograma' }] }) });
  ok('PA-09 erro exibido na linha correspondente', (await page.$eval('.se-row[data-key=k1] .se-issues', e => e.textContent)).includes('período declarado'));
  ok('PA-10 aviso de sobreposição distinto de erro', (await page.$eval('.se-row[data-key=k2] .se-issues .warning', e => e.textContent)).includes('sobreposto') && !(await page.$('.se-row[data-key=k2] .se-issues .error')));
  ok('Pendências do plano (requisitos não distribuídos) exibidas', (await page.$eval('.se-editor > .se-issues', e => e.textContent)).includes('não distribuído'));
  ok('Resumo conta pendências e avisos', (await page.$eval('.se-summary', e => e.textContent)).includes('2 pendência(s)'));
  // Edição de campos e auditores
  await page.fill('.se-row[data-key=k1] [data-f=location]', 'Sala 2'); await page.check('.se-row[data-key=k1] [data-assignee="m-a"]');
  await page.click('.se-row[data-key=k1] summary'); await page.check('.se-row[data-key=k1] [data-req=q2]');
  await page.click('[data-se=save]'); await page.waitForFunction(() => window.__calls.some(c => c.command === 'save'));
  s = await lastSave(page);
  ok('PA-19 vários auditores por linha', JSON.stringify(s.items[0].assignee_ids) === '["m-l","m-a"]');
  ok('PA-06/07 requisitos de critérios diferentes na mesma linha', JSON.stringify(s.items[0].requirements) === '["q1","q2"]' && s.items[0].location === 'Sala 2');
  await page.close();

  // Conflito de edição mantém o rascunho local (PA-23)
  page = await open({ draft: base(), conflict: true });
  await page.fill('.se-row[data-key=k1] [data-f=title]', 'Compras e contratos');
  await page.click('[data-se=save]'); await page.waitForSelector('#seNotice.error:not([hidden])');
  ok('PA-23 conflito informa e mantém as alterações locais', (await page.$eval('#seNotice', n => n.textContent)).includes('não foram salvas')
    && (await page.$eval('.se-row[data-key=k1] [data-f=title]', i => i.value)) === 'Compras e contratos' && !!(await page.$('#seNotice [data-se=reload]')));
  await page.close();

  // Apoio somente leitura (PA-19)
  page = await open({ draft: base({ can_edit: false }) });
  ok('PA-19 apoio sem ações e campos desabilitados', !(await page.$('[data-act]')) && !(await page.$('[data-se=save]')) && await page.$$eval('.se-row input', is => is.every(i => i.disabled)));
  await page.close();

  // Continuidade: parcial e transferência do restante (PA-17)
  const published = [{ id: 'pub-1', title: 'Produção', date: '2026-10-21', day_number: 2, day_status: 'in_progress', status: 'in_progress', withdrawn: false, outcome: null,
    planned_start: '2026-10-21T13:00:00Z', planned_end: '2026-10-21T14:00:00Z', actual_start: '2026-10-21T13:05:00Z', location: 'Fábrica', assignee_ids: ['m-a'], category: 'assessment', process: 'Produção', requirements: ['q1', 'q2'], continued_by: [] }];
  page = await open({ draft: base({ published }) });
  ok('Execução publicada listada com previsto e real', (await page.$eval('.se-published', e => e.textContent)).includes('Real:'));
  await page.click('[data-outcome="pub-1"]'); await page.waitForSelector('.se-dialog[open]');
  await page.fill('.se-dialog [name=performed_summary]', 'Linha 1 avaliada'); await page.fill('.se-dialog [name=remaining_summary]', 'Linha 2 pendente'); await page.fill('.se-dialog [name=outcome_note]', 'Parada de máquina');
  await page.click('.se-dialog button:not([type=button])'); await page.waitForSelector('[data-transfer="pub-1"]');
  const oc = await page.evaluate(() => window.__calls.find(c => c.command === 'record_outcome').payload);
  ok('RDA-08 parcial registra realizado, restante e motivo', oc.outcome === 'partial' && oc.performed_summary === 'Linha 1 avaliada' && oc.remaining_summary === 'Linha 2 pendente' && oc.expected_lock_version === 5);
  await page.click('[data-transfer="pub-1"]');
  await page.fill('.se-row:last-child [data-f=date]', '2026-10-23'); await page.fill('.se-row:last-child [data-f=start_time]', '09:00'); await page.fill('.se-row:last-child [data-f=end_time]', '10:00');
  await page.click('[data-se=save]'); await page.waitForFunction(() => window.__calls.some(c => c.command === 'save'));
  s = await lastSave(page); const cont = s.items.at(-1);
  ok('PA-17 restante vira nova atividade vinculada à origem', cont.continuation_of === 'pub-1' && cont.id === null && cont.remaining_summary === 'Linha 2 pendente' && cont.date === '2026-10-23');
  ok('PA-17 restante mantém auditores e requisitos, sem copiar execução', JSON.stringify(cont.assignee_ids) === '["m-a"]' && cont.requirements.length === 2 && !('actual_start' in cont));
  ok('Restante encaminhado não pode ser transferido duas vezes pela tela', !(await page.$('[data-transfer="pub-1"]')));
  ok('Sem erros de script', page.errors.length === 0, page.errors.join(' | '));
  await page.close();

  // Celular
  page = await open({ draft: base({ published }) }, { width: 390, height: 844 });
  const w = await page.evaluate(() => document.documentElement.scrollWidth);
  ok('Tela pequena sem rolagem horizontal', w <= 391, `${w}px`);
  await page.close();
  console.log(passed.map(p => `ok  ${p}`).join('\n'));
  console.log(`---- ${passed.length}/${passed.length} verificações do editor de cronograma aprovadas`);
} finally { await app.close(); }
