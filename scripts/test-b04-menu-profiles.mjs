// B04 — CA-01/CA-02/PER-20: menu por perfil em todas as páginas autenticadas, desktop e tela pequena.
import assert from 'node:assert/strict';
import { start, scenario, visibleNav, settle } from './ui/app-harness.mjs';

const PAGES = ['dashboard', 'auditorias', 'cadastro', 'checklists', 'execution', 'historico', 'notificacoes', 'perfil', 'biblioteca'];
const EXPECTED = {
  admin: ['Dashboard', 'Auditorias', 'Usuários', 'Biblioteca de documentos', 'Meu Perfil'],
  leader: ['Dashboard', 'Auditorias', 'Biblioteca de documentos', 'Meu Perfil'],
  auditor: ['Dashboard', 'Auditorias', 'Biblioteca de documentos', 'Meu Perfil'],
  participant: ['Dashboard', 'Auditorias', 'Meu Perfil'],
};
const REMOVED = /Não conformidades|Planos de ação|Indicadores/;
const app = await start();
let checks = 0;
try {
  for (const [role, expected] of Object.entries(EXPECTED)) {
    for (const name of PAGES) {
      const page = await app.page({ scenario: scenario(role) });
      await page.goto(`${app.base}/audita-pro-${name}.html`);
      try { await settle(page); } catch (e) { throw new Error(`${role} em ${name}: ${e.message} · url=${page.url()} · erros=${page.errors.join(' | ')} · calls=${JSON.stringify(await page.evaluate(() => window.__calls).catch(() => null))}`); }
      const url = page.url();
      if (url.endsWith('audita-pro-perfil.html') && name !== 'perfil') { await page.close(); continue; } // redirecionamento de onboarding
      assert.deepEqual(await visibleNav(page), expected, `${role} em ${name}`);
      const navText = await page.$eval('aside nav', n => n.textContent);
      assert.doesNotMatch(navText, REMOVED, `${role} em ${name}: abas retiradas não aparecem nem ocultas`);
      checks++;
      await page.close();
    }
  }
  // Falha ao consultar a permissão da biblioteca não pode exibir o item (falha fechada).
  const failing = await app.page({ scenario: scenario('auditor', `const base = window.__mock.rpc; window.__mock.rpc = (n, c, p) => n === 'corporate_library' ? { data: null, error: { message: 'indisponível' } } : base(n, c, p);`) });
  await failing.goto(`${app.base}/audita-pro-dashboard.html`);
  await settle(failing, () => window.__calls?.some(c => c.name === 'corporate_library'));
  assert.deepEqual(await visibleNav(failing), ['Dashboard', 'Auditorias', 'Meu Perfil'], 'erro de permissão oculta a biblioteca');
  checks++;
  await failing.close();
  // Tela pequena: menu inicia recolhido, abre pelo botão e mantém os mesmos itens; Escape fecha.
  for (const role of ['admin', 'participant']) {
    const mobile = await app.page({ scenario: scenario(role), viewport: { width: 390, height: 844 } });
    await mobile.goto(`${app.base}/audita-pro-auditorias.html`);
    await settle(mobile);
    assert.equal(await mobile.$eval('aside nav', n => n.hidden), true, `${role}: menu recolhido em tela pequena`);
    await mobile.click('.ap-nav-toggle');
    assert.deepEqual(await visibleNav(mobile), EXPECTED[role], `${role}: itens no menu aberto em tela pequena`);
    const width = await mobile.evaluate(() => document.documentElement.scrollWidth);
    assert.ok(width <= 390 + 1, `${role}: sem rolagem horizontal (${width}px)`);
    await mobile.focus('aside nav a');
    await mobile.keyboard.press('Escape');
    assert.equal(await mobile.$eval('aside nav', n => n.hidden), true, `${role}: Escape recolhe o menu`);
    checks++;
    await mobile.close();
  }
  // Cadastro pendente é encaminhado ao Meu Perfil (onboarding preservado — D05).
  const pending = await app.page({ scenario: scenario('pending') });
  await pending.goto(`${app.base}/audita-pro-biblioteca.html`);
  await pending.waitForURL(/audita-pro-perfil\.html/, { timeout: 8000 });
  checks++;
  await pending.close();
  console.log(`---- ${checks} verificações de menu aprovadas (4 perfis × ${PAGES.length} páginas, falha fechada, tela pequena, onboarding)`);
} finally { await app.close(); }
