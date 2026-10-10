// B05 — interface da biblioteca: CA-03/04/05/06/07/08/10/11/13 no navegador (regras reais testadas em SQL).
import assert from 'node:assert/strict';
import { start, scenario, settle } from './ui/app-harness.mjs';

const doc = (over = {}) => ({ id: 'd1', title: 'Procedimento de Auditoria', doc_type: 'procedimento', code: 'PDA-001', description: 'Uso interno', status: 'vigente', lock_version: 2,
  current: { id: 'r1', revision_label: 'Rev.00', status: 'current', responsible: 'Responsável Técnico', issued_on: '2026-10-10', files: [{ id: 'f-pdf', format: 'pdf', filename: 'pda.pdf', size_bytes: 120000, sha256: 'a'.repeat(64) }, { id: 'f-docx', format: 'docx', filename: 'pda.docx', size_bytes: 80000, sha256: 'b'.repeat(64) }] },
  draft: null, ...over });
const withDocs = items => `window.__mock.library = { items: ${JSON.stringify(items)}, total: ${items.length} };`;
const app = await start();
const results = [];
const ok = (name, cond, info = '') => { assert.ok(cond, `${name} ${info}`); results.push(name); };
const text = page => page.$eval('#corporatePanel', e => e.innerText);
const ready = page => settle(page, () => window.__calls?.some(c => c.name === 'corporate_library' && c.command === 'list') && !document.querySelector('#corporatePanel .lib-state[role=status]')?.textContent.includes('Carregando'));
try {
  // Auditor: consulta e download, sem gestão (CA-05/CA-06).
  let page = await app.page({ scenario: scenario('auditor', withDocs([doc()])), functions: async b => b.action === 'download' ? [200, { url: 'https://download.test/pda.pdf', filename: 'pda.pdf' }] : [400, { error: 'x' }] });
  await page.goto(`${app.base}/audita-pro-biblioteca.html`); await ready(page);
  ok('CA-05 auditor vê documento', (await text(page)).includes('Procedimento de Auditoria'));
  ok('CA-05 auditor sem Inserir/Gerenciar/Histórico', !(await page.$('#libInsert')) && !(await page.$('[data-manage]')) && !(await page.$('a[href*="historico"]')));
  ok('CA-05 sem filtro de situação para auditor', !(await page.$('#libStatus')));
  const [download] = await Promise.all([page.waitForEvent('request', r => r.url().startsWith('https://download.test/')), page.click('[data-download="f-pdf"]')]);
  ok('CA-06 download pede o arquivo escolhido', page.functionCalls.at(-1).file_id === 'f-pdf' && download.url().endsWith('pda.pdf'));
  await page.close();

  // Falha de download tem mensagem própria (CA-11).
  page = await app.page({ scenario: scenario('leader', withDocs([doc()])), functions: async () => [403, { error: 'Arquivo indisponível' }] });
  await page.goto(`${app.base}/audita-pro-biblioteca.html`); await ready(page);
  await page.click('[data-download="f-docx"]'); await page.waitForSelector('#libNotice:not([hidden])');
  ok('CA-11 falha de download explicada', (await page.$eval('#libNotice', n => n.textContent)).includes('Não foi possível baixar'));
  await page.close();

  // Estados distintos: vazia, busca sem resultado, erro (CA-11).
  page = await app.page({ scenario: scenario('auditor') });
  await page.goto(`${app.base}/audita-pro-biblioteca.html`); await ready(page);
  ok('CA-11 biblioteca vazia', (await text(page)).includes('ainda não tem documentos disponíveis'));
  await page.fill('#libSearch', 'inexistente'); await page.click('#libFilters button[type=submit]'); await ready(page); await page.waitForTimeout(100);
  ok('CA-11 busca sem resultado', (await text(page)).includes('Nenhum documento encontrado') && !!(await page.$('#libClear')));
  ok('PC-02 busca enviada ao servidor', JSON.stringify(await page.evaluate(() => window.__calls.filter(c => c.name === 'corporate_library' && c.command === 'list').at(-1).payload)).includes('inexistente'));
  await page.close();
  page = await app.page({ scenario: scenario('auditor', `const b = window.__mock.rpc; window.__mock.rpc = (n, c, p) => n === 'corporate_library' && c === 'list' ? { data: null, error: { message: 'Falha temporária' } } : b(n, c, p);`) });
  await page.goto(`${app.base}/audita-pro-biblioteca.html`); await settle(page, () => !!document.querySelector('#libRetry'));
  ok('CA-11 erro não aparece como vazio', (await text(page)).includes('Não foi possível carregar') && !(await text(page)).includes('ainda não tem'));
  await page.close();

  // Participante: sem biblioteca, mesmo por endereço direto (CA-13).
  page = await app.page({ scenario: scenario('participant', withDocs([doc()])) });
  await page.goto(`${app.base}/audita-pro-biblioteca.html`); await settle(page, () => window.__calls?.some(c => c.name === 'corporate_library'));
  await page.waitForTimeout(200);
  const ptext = await text(page);
  ok('CA-13 participante não vê a biblioteca', ptext.includes('indisponível para o seu perfil') && !ptext.includes('Procedimento de Auditoria'));
  ok('CA-13 participante não consulta a lista', !(await page.evaluate(() => window.__calls.some(c => c.name === 'corporate_library' && c.command === 'list'))));
  ok('CA-13 relatórios continuam em Auditorias', !!(await page.$('#corporatePanel a[href="audita-pro-auditorias.html"]')));
  await page.close();

  // Administrador: inserir com validação local e confirmação somente após envio (CA-04/CA-10).
  const adminRpc = `const b = window.__mock.rpc; window.__mock.rpc = (n, c, p) => { if (n === 'corporate_library' && c === 'create') { window.__created = p; return { document_id: 'd9', revision_id: 'r9' }; } return b(n, c, p); };`;
  page = await app.page({ scenario: scenario('admin', withDocs([doc({ draft: { id: 'r2', revision_label: 'Rev.01', status: 'draft', files: [] } })]) + adminRpc),
    functions: async b => b.multipart ? [200, { file_id: 'f9' }] : [400, { error: 'x' }] });
  await page.goto(`${app.base}/audita-pro-biblioteca.html`); await ready(page);
  ok('CA-04 admin vê Inserir e Histórico', !!(await page.$('#libInsert')) && !!(await page.$('a[href="audita-pro-historico.html?origem=biblioteca"]')));
  ok('PC-04 admin vê rascunho em preparação', (await text(page)).includes('Rascunho em preparação: Rev.01'));
  await page.click('#libInsert');
  await page.click('#libDialogForm button[value=save]');
  ok('CA-04 campos obrigatórios', (await page.$eval('#libFormError', e => e.textContent)).length > 0 || await page.$eval('#libDialogForm [name=title]', e => !e.checkValidity()));
  await page.fill('#libDialogForm [name=title]', 'Modelo mestre'); await page.selectOption('#libDialogForm [name=doc_type]', 'modelo');
  await page.setInputFiles('#libDialogForm [name=files]', { name: 'macro.exe', mimeType: 'application/octet-stream', buffer: Buffer.from('MZ') });
  await page.click('#libDialogForm button[value=save]');
  ok('CA-10 formato fora da regra recusado', (await page.$eval('#libFormError', e => e.textContent)).includes('somente PDF, DOCX ou DOTX'));
  ok('CA-10 nada criado com arquivo inválido', !(await page.evaluate(() => window.__created)));
  await page.setInputFiles('#libDialogForm [name=files]', { name: 'grande.pdf', mimeType: 'application/pdf', buffer: Buffer.alloc(20 * 1024 * 1024 + 10) });
  await page.click('#libDialogForm button[value=save]');
  ok('CA-10 tamanho acima de 20 MB recusado', (await page.$eval('#libFormError', e => e.textContent)).includes('limite é 20 MB'));
  await page.setInputFiles('#libDialogForm [name=files]', { name: 'modelo.dotx', mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.template', buffer: Buffer.from('PK') });
  await page.click('#libDialogForm button[value=save]');
  await page.waitForSelector('#libNotice:not([hidden])');
  ok('CA-04 confirmação após envio concluído', (await page.$eval('#libNotice', n => n.textContent)).includes('salvo em Rascunho com 1 arquivo'));
  ok('PC-06 cadastro idempotente com operation_id', /^[0-9a-f-]{36}$/.test(await page.evaluate(() => window.__created.operation_id)));
  await page.close();

  // Falha no envio do arquivo: cadastro fica em Rascunho, sem publicação, com aviso (CA-04).
  page = await app.page({ scenario: scenario('admin', adminRpc), functions: async () => [422, { error: 'Arquivo PDF incompleto ou corrompido.' }] });
  await page.goto(`${app.base}/audita-pro-biblioteca.html`); await ready(page);
  await page.click('#libInsert');
  await page.fill('#libDialogForm [name=title]', 'Procedimento'); await page.selectOption('#libDialogForm [name=doc_type]', 'procedimento');
  await page.setInputFiles('#libDialogForm [name=files]', { name: 'p.pdf', mimeType: 'application/pdf', buffer: Buffer.from('%PDF-1.7') });
  await page.click('#libDialogForm button[value=save]'); await page.waitForSelector('#libNotice.error:not([hidden])');
  ok('CA-04 falha de envio não publica', (await page.$eval('#libNotice', n => n.textContent)).includes('nada foi publicado'));
  await page.close();

  // CA-03/CA-07/CA-08: histórico só por ação explícita, com retorno; menu sempre volta aos documentos.
  page = await app.page({ scenario: scenario('admin', withDocs([doc()])) });
  await page.goto(`${app.base}/audita-pro-biblioteca.html`); await ready(page);
  ok('CA-03 entrada abre documentos', await page.$eval('#tabCorporate', t => t.getAttribute('aria-selected') === 'true') && await page.$eval('#reportsPanel', p => p.hidden));
  await page.click('a[href="audita-pro-historico.html?origem=biblioteca"]'); await page.waitForURL(/historico/);
  await settle(page, () => window.__calls?.some(c => c.name === 'corporate_library'));
  ok('CA-07 histórico com Voltar à biblioteca', !!(await page.$('#backToLibrary')));
  ok('CA-07 histórico consultado pelo Admin', await page.evaluate(() => window.__calls.some(c => c.from === 'audit_events')));
  await page.click('aside nav a[href="audita-pro-biblioteca.html"]'); await page.waitForURL(/biblioteca/); await ready(page);
  ok('CA-03 após visitar histórico, menu abre documentos', (await text(page)).includes('Procedimento de Auditoria') && !(await page.$('#rows')));
  await page.close();
  page = await app.page({ scenario: scenario('leader') });
  await page.goto(`${app.base}/audita-pro-historico.html`); await settle(page, () => window.__calls?.some(c => c.name === 'corporate_library'));
  await page.waitForTimeout(200);
  ok('CA-08 histórico restrito a não administradores', (await page.$eval('#empty', e => e.textContent)).includes('restrito ao Administrador'));
  ok('CA-08 sem consulta ao histórico por não administradores', !(await page.evaluate(() => window.__calls.some(c => c.from === 'audit_events'))));
  await page.close();

  // Aba Relatórios de auditorias carrega a fonte existente só quando escolhida.
  page = await app.page({ scenario: scenario('auditor', withDocs([doc()]) + `const b = window.__mock.rpc; window.__mock.rpc = (n, c, p) => n === 'audit_document_library' ? { items: [], total: 0 } : b(n, c, p);`) });
  await page.goto(`${app.base}/audita-pro-biblioteca.html`); await ready(page);
  ok('Relatórios não carregados na entrada', !(await page.evaluate(() => window.__calls.some(c => c.name === 'audit_document_library'))));
  await page.click('#tabReports'); await page.waitForTimeout(200);
  ok('Relatórios de auditorias em aba própria', await page.evaluate(() => window.__calls.some(c => c.name === 'audit_document_library')) && (await page.$eval('#reportsPanel', p => p.innerText)).includes('Documentos de auditorias'));
  ok('Sem erros de script', page.errors.length === 0, page.errors.join(' | '));
  await page.close();

  // Celular: sem rolagem horizontal.
  page = await app.page({ scenario: scenario('admin', withDocs([doc(), doc({ id: 'd2', code: 'FOR-002', title: 'Formulário com título bem longo para verificar quebra de linha em tela pequena' })])), viewport: { width: 390, height: 844 } });
  await page.goto(`${app.base}/audita-pro-biblioteca.html`); await ready(page);
  const w = await page.evaluate(() => document.documentElement.scrollWidth);
  ok('Tela pequena sem rolagem horizontal', w <= 391, `${w}px`);
  await page.close();
  console.log(results.map(r => `ok  ${r}`).join('\n'));
  console.log(`---- ${results.length}/${results.length} verificações da biblioteca aprovadas`);
} finally { await app.close(); }
