// B08 — painel "Emissor de documentos" (Administrador) na biblioteca: geração, acompanhamento, download e retomada.
// O servidor é simulado; autorização e máquina de estados reais estão em test-b08-emission.sql e test-b08-emit-flow.mts.
import assert from 'node:assert/strict';
import { start, scenario, settle } from './ui/app-harness.mjs';

const app = await start();
const results = [];
const ok = (name, cond, info = '') => { assert.ok(cond, `${name} ${info}`); results.push(name); console.log(`ok  ${name}`); };
const em = (over = {}) => ({ id: 'e1', title: 'Documento de prova do emissor 001', status: 'published', page_count: 48, size_bytes: 192636,
  pdf_sha256: '14be43ab489dd7b1439de89070cdbc93223be3d4ff9127433078e8e707e61aaa', template: 'specimen v1', engine_version: 'audita-pdf 1.0.0', requested_at: '2026-10-10T21:00:00Z', ...over });
const listMock = items => `const b0 = window.__mock.rpc; window.__mock.rpc = (n, c, p) => n === 'document_emission' && c === 'list' ? (window.__emList ?? ${JSON.stringify(items)}) : b0(n, c, p);`;
try {
  // Não Administrador: aba oculta.
  let page = await app.page({ scenario: scenario('leader') });
  await page.goto(`${app.base}/audita-pro-biblioteca.html`);
  await settle(page, () => window.__calls?.some(c => c.name === 'corporate_library' && c.command === 'list'));
  ok('Aba do emissor oculta para quem não é Administrador', await page.$eval('#tabEmitter', b => b.hidden));
  await page.close();

  page = await app.page({ scenario: scenario('admin', listMock([em(), em({ id: 'e2', title: 'Documento de prova do emissor 002', status: 'failed', last_error: 'Falha ao armazenar o PDF gerado.', page_count: null, size_bytes: null, pdf_sha256: null })])),
    functions: async b => {
      if (b.action === 'download') return [200, { url: 'https://download.test/prova.pdf', filename: 'prova-emissor-001.pdf', sha256: em().pdf_sha256 }];
      if (b.action === 'retry') return [200, { state: 'published', emission: em({ id: 'e2' }) }];
      if (b.action === 'request_specimen') return [200, { state: 'published', emission: em({ id: 'e3', page_count: 12 }) }];
      return [400, { error: 'x' }];
    } });
  await page.route('https://download.test/**', r => r.fulfill({ status: 200, contentType: 'application/pdf', headers: { 'Content-Disposition': 'attachment; filename="prova-emissor-001.pdf"' }, body: '%PDF-1.7' }));
  await page.goto(`${app.base}/audita-pro-biblioteca.html`);
  await settle(page, () => !document.querySelector('#tabEmitter')?.hidden);
  ok('Administrador vê a aba Emissor de documentos', true);
  ok('Entrada continua em Documentos corporativos', await page.$eval('#emitterPanel', p => p.hidden) && !(await page.evaluate(() => window.__calls.some(c => c.name === 'document_emission'))));
  await page.click('#tabEmitter');
  await settle(page, () => !!document.querySelector('#emList table'));
  const txt = await page.$eval('#emitterPanel', e => e.innerText);
  ok('Lista mostra situação, páginas, tamanho e hash', txt.includes('Emitido') && txt.includes('48') && txt.includes('188 KB') && txt.includes('14be43ab489dd7b1'));
  ok('Falha explicada com opção de retomar', txt.includes('Falha ao armazenar o PDF gerado.') && !!(await page.$('[data-retry="e2"]')));
  const [dl] = await Promise.all([page.waitForEvent('download'), page.click('[data-down="e1"]')]);
  ok('Download usa a URL temporária do arquivo persistido', page.functionCalls.at(-1).action === 'download' && page.functionCalls.at(-1).emission_id === 'e1' && dl.suggestedFilename() === 'prova-emissor-001.pdf');
  await page.click('[data-retry="e2"]');
  await settle(page, () => window.__calls.filter(c => c.name === 'document_emission' && c.command === 'list').length >= 2);
  ok('Retomar chama o emissor para o mesmo pedido', page.functionCalls.some(c => c.action === 'retry' && c.emission_id === 'e2'));
  await page.selectOption('#emRows', '900'); await page.check('#emDraft');
  await page.click('#emGo');
  await page.waitForFunction(() => document.querySelector('#emNotice')?.textContent.includes('Documento emitido'));
  const call = page.functionCalls.at(-1);
  ok('Pedido com operation_id e parâmetros escolhidos', call.action === 'request_specimen' && /^[0-9a-f-]{36}$/.test(call.operation_id) && call.params.rows === 900 && call.params.draft === true);
  ok('Confirmação só após o servidor emitir e conferir', (await page.$eval('#emNotice', n => n.textContent)).includes('12 páginas, conferido no servidor'));
  ok('Sem erros de script', page.errors.length === 0, page.errors.join(' | '));
  await page.close();

  // Celular: sem rolagem horizontal.
  page = await app.page({ scenario: scenario('admin', listMock([em()])), viewport: { width: 375, height: 800 } });
  await page.goto(`${app.base}/audita-pro-biblioteca.html`);
  await settle(page, () => !document.querySelector('#tabEmitter')?.hidden);
  await page.click('#tabEmitter'); await settle(page, () => !!document.querySelector('#emList table'));
  ok('Tela pequena sem rolagem horizontal', await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1));
  await page.close();
} finally { await app.close(); }
console.log(`---- ${results.length}/${results.length} verificações do painel do emissor aprovadas`);
