// Executa, sem alterações, os testes escritos para happy-dom dentro do Chromium real (Playwright).
// Motivo: esta sessão não instala happy-dom (sem acesso ao registro npm), mas tem Chromium.
// Cada `new Window({url})` vira um iframe real cujo endereço é o da página indicada no teste.
// Uso: node scripts/ui/happy-dom-in-chromium.mjs scripts/test-b04-profile.mjs [...]
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
const require = createRequire(import.meta.url);
const loadPlaywright = () => { try { return require('playwright'); } catch { return require(path.join(execFileSync('npm', ['root', '-g']).toString().trim(), 'playwright')); } };
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const { chromium } = loadPlaywright();
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const browserPath = fs.existsSync('/opt/pw-browsers/chromium') ? '/opt/pw-browsers/chromium' : undefined;

function snapshotFiles() {
  const files = {}, dirs = {};
  const walk = dir => {
    const names = fs.readdirSync(dir);
    dirs[dir + '/'] = names;
    for (const name of names) {
      const full = path.join(dir, name);
      const stat = fs.statSync(full);
      if (stat.isDirectory()) walk(full);
      else if (/\.(js|ts|html|css|json|md|sql)$/.test(name)) files[full] = fs.readFileSync(full, 'utf8');
    }
  };
  walk(path.join(ROOT, 'outputs'));
  return { files, dirs };
}

const BROWSER_SHIM = `
const __fs = { readFileSync(p) { const k = p instanceof URL ? decodeURIComponent(p.pathname) : String(p); if (!(k in __SNAP.files)) throw new Error('arquivo ausente no teste: ' + k); return __SNAP.files[k]; },
  readdirSync(p) { const k = String(p).endsWith('/') ? String(p) : String(p) + '/'; return __SNAP.dirs[k] || []; } };
const __canon = v => v && typeof v === 'object' ? (Array.isArray(v) ? v.map(__canon) : Object.fromEntries(Object.keys(v).sort().map(k => [k, __canon(v[k])]))) : v;
class AssertionError extends Error {}
const assert = {
  equal(a, b, m) { if (a !== b) throw new AssertionError((m || 'equal') + ': ' + JSON.stringify(a) + ' !== ' + JSON.stringify(b)); },
  notEqual(a, b, m) { if (a === b) throw new AssertionError((m || 'notEqual') + ': ' + JSON.stringify(a)); },
  deepEqual(a, b, m) { if (JSON.stringify(__canon(a)) !== JSON.stringify(__canon(b))) throw new AssertionError((m || 'deepEqual') + ': ' + JSON.stringify(a) + ' vs ' + JSON.stringify(b)); },
  ok(v, m) { if (!v) throw new AssertionError(m || 'ok'); },
  doesNotMatch(s, r, m) { if (r.test(s)) throw new AssertionError((m || 'doesNotMatch') + ': ' + JSON.stringify(String(s).slice(0, 300)) + ' ~ ' + r); },
  notDeepEqual(a, b, m) { if (JSON.stringify(__canon(a)) === JSON.stringify(__canon(b))) throw new AssertionError(m || 'notDeepEqual'); },
  async rejects(p, m) { try { await (typeof p === 'function' ? p() : p); } catch { return; } throw new AssertionError(m || 'rejects'); },
  throws(fn, m) { try { fn(); } catch { return; } throw new AssertionError(m || 'throws'); },
  match(s, r, m) { if (!r.test(s)) throw new AssertionError((m || 'match') + ': ' + JSON.stringify(String(s).slice(0, 300)) + ' !~ ' + r); },
};
class Window {
  constructor({ url } = {}) {
    if (url) { const u = new URL(url); history.replaceState(null, '', u.pathname + u.search + u.hash); }
    const frame = document.createElement('iframe'); document.body.append(frame);
    const w = frame.contentWindow, doc = w.document, write = doc.write.bind(doc);
    doc.write = html => { write(html); doc.close(); };
    w.happyDOM = { close: async () => frame.remove(), whenAsyncComplete: async () => {} };
    return w;
  }
}`;

async function run(testFile) {
  const abs = path.resolve(testFile);
  let source = fs.readFileSync(abs, 'utf8');
  source = source.replace(/^\s*import[^\n]*\n/gm, '').replace(/import\.meta\.url/g, JSON.stringify(pathToFileURL(abs).href)).replace(/\bfs\./g, '__fs.');
  const server = http.createServer((q, r) => { r.writeHead(200, { 'Content-Type': 'text/html' }); r.end('<!doctype html><html><body></body></html>'); }).listen(0, '127.0.0.1');
  await new Promise(r => server.once('listening', r));
  const browser = await chromium.launch({ executablePath: browserPath });
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto(`http://127.0.0.1:${server.address().port}/`);
  const snap = snapshotFiles();
  const outcome = await page.evaluate(async ({ shim, body, snap }) => {
    window.__SNAP = snap;
    const fn = new Function(`return (async () => { ${shim}\n return await (async () => { ${body}\n })(); })()`);
    try { await fn(); return { ok: true }; } catch (e) { return { ok: false, message: e.message, stack: e.stack }; }
  }, { shim: BROWSER_SHIM, body: source, snap });
  await browser.close(); server.close();
  return { outcome, errors };
}

let failed = 0;
for (const file of process.argv.slice(2)) {
  const { outcome, errors } = await run(file);
  if (outcome.ok) console.log(`ok    ${file}`);
  else { failed++; console.log(`FALHA ${file}: ${outcome.message}`); if (errors.length) console.log('      erros de página:', errors.slice(0, 3).join(' | ')); }
}
process.exit(failed ? 1 : 0);
