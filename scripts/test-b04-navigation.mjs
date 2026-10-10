// B04 — verificação estrutural do menu (CA-01/CA-02/CA-12) em todas as páginas autenticadas.
// Substitui a versão anterior, que comparava o diff com um commit fixo e falhava a qualquer evolução
// legítima (ex.: B05). Agora verifica as regras: itens retirados, ordem, destinos e itens restritos ocultos.
import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const OUT = resolve(dirname(fileURLToPath(import.meta.url)), '../outputs');
const PUBLIC = new Set(['audita-pro-login.html', 'audita-pro-relatorio-diario.html']);
const ORDER = ['Dashboard', 'Auditorias', 'Usuários', 'Biblioteca de documentos', 'Meu Perfil'];
const TARGET = { Dashboard: 'audita-pro-dashboard.html', Auditorias: 'audita-pro-auditorias.html', 'Usuários': 'audita-pro-cadastro.html',
  'Biblioteca de documentos': 'audita-pro-biblioteca.html', 'Meu Perfil': 'audita-pro-perfil.html' };
const RESTRICTED = new Set(['Usuários', 'Biblioteca de documentos']);
const REMOVED = /Não conformidades|Planos de ação|Indicadores|Biblioteca de relatórios|Biblioteca \/ histórico/;
const pages = readdirSync(OUT).filter(f => f.startsWith('audita-pro-') && f.endsWith('.html') && !PUBLIC.has(f));
let checked = 0;
for (const page of pages) {
  const html = readFileSync(resolve(OUT, page), 'utf8');
  const navs = [...html.matchAll(/<nav\b[^>]*aria-label="Navegação principal"[^>]*>([\s\S]*?)<\/nav>/g)];
  assert.equal(navs.length, 1, `${page}: uma navegação principal`);
  const nav = navs[0][1];
  assert.doesNotMatch(nav, REMOVED, `${page}: entradas retiradas ou renomeadas não podem permanecer`);
  const links = [...nav.matchAll(/<a\b([^>]*)>([\s\S]*?)<\/a>/g)].map(m => ({
    attrs: m[1], href: m[1].match(/href="([^"]+)"/)?.[1], label: m[2].replace(/<[^>]+>/g, '').replace(/&nbsp;|[▦▤♟♙▣]/g, '').trim() }));
  assert.deepEqual(links.map(l => l.label), ORDER, `${page}: ordem do menu`);
  for (const l of links) {
    assert.equal(l.href, TARGET[l.label], `${page}: destino de ${l.label}`);
    assert.ok(existsSync(resolve(OUT, l.href)), `${page}: destino existe (${l.href})`);
    if (RESTRICTED.has(l.label)) assert.match(l.attrs, /\shidden\b/, `${page}: ${l.label} começa oculto até o servidor autorizar`);
  }
  assert.match(html, /audita-pro-navigation\.js/, `${page}: carrega o módulo de navegação`);
  assert.match(html, /audita-pro-navigation\.css/, `${page}: carrega o estilo de navegação`);
  checked++;
}
// CA-12: rotas e módulos internos preservados (arquivos continuam presentes).
for (const kept of ['audita-pro-historico.html', 'audita-pro-execution.html', 'audita-pro-checklists.html', 'audita-pro-relatorio-diario.html', 'audita-pro-document-library.js'])
  assert.ok(existsSync(resolve(OUT, kept)), `CA-12: ${kept} preservado`);
console.log(`---- menu verificado em ${checked} páginas autenticadas`);
