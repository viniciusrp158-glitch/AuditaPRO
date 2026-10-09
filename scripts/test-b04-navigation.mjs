import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const BASE = process.env.B04_BASE_REF || 'bee387f';
const PAGES = [
  'outputs/audita-pro-auditorias.html',
  'outputs/audita-pro-cadastro.html',
  'outputs/audita-pro-checklists.html',
  'outputs/audita-pro-dashboard.html',
  'outputs/audita-pro-execution.html',
  'outputs/audita-pro-historico.html',
  'outputs/audita-pro-notificacoes.html',
  'outputs/audita-pro-perfil.html',
];
const THIS_TEST = 'scripts/test-b04-navigation.mjs';
const REMOVED_LABELS = new Set(['Não conformidades', 'Planos de ação', 'Indicadores']);

function git(...args) {
  return execFileSync('git', args, { cwd: ROOT, encoding: 'utf8' });
}

function fromBase(path) {
  return git('show', `${BASE}:${path}`);
}

function navFrom(html, path) {
  const matches = [...html.matchAll(/<nav\b[^>]*>[\s\S]*?<\/nav>/gi)];
  assert.equal(matches.length, 1, `${path}: deve ter exatamente uma navegação lateral conhecida`);
  const match = matches[0];
  return { html: match[0], start: match.index, end: match.index + match[0].length };
}

function linksFrom(nav, path) {
  const links = [...nav.matchAll(/<a\b([^>]*)>([\s\S]*?)<\/a>/gi)].map((match) => {
    const href = match[1].match(/\bhref\s*=\s*(["'])(.*?)\1/i)?.[2];
    assert.ok(href, `${path}: todo link da navegação deve manter href explícito`);
    const id = match[1].match(/\bid\s*=\s*(["'])(.*?)\1/i)?.[2] ?? null;
    const label = match[2]
      .replace(/<svg\b[\s\S]*?<\/svg>/gi, '')
      .replace(/<[^>]+>/g, ' ')
      .replace(/&nbsp;/gi, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .replace(/^[^\p{L}\p{N}]+/u, '')
      .trim();
    return { href, id, label };
  });
  assert.ok(links.length > 0, `${path}: navegação deve conter links`);
  return links;
}

function withoutNav(html, nav) {
  return `${html.slice(0, nav.start)}<NAV_PRESERVADA>${html.slice(nav.end)}`;
}

function validateLocalDestination(link, path) {
  if (/^(?:[a-z]+:|\/\/|#)/i.test(link.href)) return;
  const [targetPath, fragment] = link.href.split('#', 2);
  const target = resolve(ROOT, 'outputs', targetPath);
  assert.ok(existsSync(target), `${path}: destino local ausente: ${link.href}`);
  if (fragment) {
    const targetHtml = readFileSync(target, 'utf8');
    const escaped = fragment.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    assert.match(targetHtml, new RegExp(`\\bid=["']${escaped}["']`), `${path}: âncora ausente: ${link.href}`);
  }
}

const changed = new Set(git('diff', '--name-only', BASE, '--').trim().split('\n').filter(Boolean));
for (const line of git('status', '--porcelain', '--untracked-files=all').split('\n').filter(Boolean)) {
  changed.add(line.slice(3));
}
const allowedChanges = new Set([...PAGES, THIS_TEST, 'outputs/audita-pro-navigation.js', 'outputs/audita-pro-navigation.css', 'outputs/audita-pro-header.js', 'outputs/audita-pro-profile.js', 'scripts/test-b04-profile.mjs', 'scripts/test-b04-navigation-ui.mjs']);
assert.deepEqual(
  [...changed].filter((path) => !allowedChanges.has(path) && !path.startsWith('docs/b04/')).sort(),
  [],
  'B04 altera somente navegação, integração de cabeçalho/perfil, testes e documentos explicitamente listados',
);

for (const path of PAGES) {
  const baseHtml = fromBase(path);
  const rawHtml = readFileSync(resolve(ROOT, path), 'utf8');
  assert.equal((rawHtml.match(/src="audita-pro-navigation.js"/g) || []).length, 1);
  assert.equal((rawHtml.match(/href="audita-pro-navigation.css"/g) || []).length, 1);
  const currentHtml = rawHtml.replace('<link rel="stylesheet" href="audita-pro-navigation.css">\n<script src="audita-pro-navigation.js" defer></script>\n', '');
  const baseNav = navFrom(baseHtml, `${path} (${BASE})`);
  const currentNav = navFrom(currentHtml, path);
  const baseLinks = linksFrom(baseNav.html, `${path} (${BASE})`);
  const currentLinks = linksFrom(currentNav.html, path);
  const expected = baseLinks.filter((link) => !REMOVED_LABELS.has(link.label));

  assert.deepEqual(
    baseLinks.filter((link) => REMOVED_LABELS.has(link.label)).map((link) => link.label),
    [...REMOVED_LABELS],
    `${path}: a base deve conter, uma vez e na ordem, os três links removidos`,
  );
  assert.deepEqual(
    currentLinks.map(({ href, id, label }) => ({ href, id, label })),
    expected.map(({ href, id, label }) => ({ href, id, label })),
    `${path}: somente os três links previstos podem sair; href, id, rótulo e ordem dos demais devem ser preservados`,
  );
  assert.deepEqual(
    currentLinks.filter((link) => REMOVED_LABELS.has(link.label)),
    [],
    `${path}: os links retirados não podem permanecer na navegação`,
  );
  assert.equal(
    withoutNav(currentHtml, currentNav),
    withoutNav(baseHtml, baseNav),
    `${path}: o conteúdo fora de <nav> deve permanecer byte a byte igual à base`,
  );
  assert.match(currentHtml, /<a\b[^>]*class=["'][^"']*brand[^"']*["'][^>]*>[\s\S]*?<img\b[^>]*src=["']audita-pro-logo\.png["']/i,
    `${path}: logo e retorno pelo link da marca devem ser preservados`);
  assert.deepEqual(
    [...currentHtml.matchAll(/<script\b[^>]*\bsrc=(["'])(.*?)\1/gi)].map((match) => match[2]),
    [...baseHtml.matchAll(/<script\b[^>]*\bsrc=(["'])(.*?)\1/gi)].map((match) => match[2]),
    `${path}: scripts carregados devem permanecer iguais e na mesma ordem`,
  );
  currentLinks.forEach((link) => validateLocalDestination(link, path));
}

console.log(`B04: ${PAGES.length} navegações preservam escopo, destinos e conteúdo externo (${BASE}).`);
console.log('Limite: teste estático; não valida perfis, RLS, Storage nem comportamento em navegador.');
