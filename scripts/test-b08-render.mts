// B08: prova local do motor de PDF (Node 22 + tsx). Gera documentos de prova, valida estrutura (qpdf), texto (pdftotext),
// páginas (pdfinfo) e imagens das páginas (pdftoppm) para inspeção visual. Uso: tsx scripts/test-b08-render.mts [saida]
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { renderDocument } from '../outputs/audita-pro-supabase/supabase/functions/document-emission/pdf/layout.ts';
import { specimen, samplePng } from '../outputs/audita-pro-supabase/supabase/functions/document-emission/templates/specimen.ts';
import { BUILTIN_ASSETS } from '../outputs/audita-pro-supabase/supabase/functions/document-emission/assets/index.ts';
import { sha256Hex } from '../outputs/audita-pro-supabase/supabase/functions/document-emission/pdf/zlib.ts';

const out = process.argv[2] ?? '/tmp/claude-0/b08';
mkdirSync(out, { recursive: true });
let pass = 0, fail = 0;
const ok = (name: string, cond: boolean, detail = '') => { cond ? pass++ : fail++; console.log(`${cond ? 'ok ' : 'FALHA'} ${name}${detail ? ` — ${detail}` : ''}`); };
const run = (cmd: string, args: string[]) => execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });

const logo = BUILTIN_ASSETS['builtin:logo'].load();
ok('Logo embutido confere com o hash registrado', await sha256Hex(logo) === BUILTIN_ASSETS['builtin:logo'].sha256);
const assets = { logo, sample: await samplePng() };
const ctx = { issued_at: '2026-10-10T17:00:00Z', version_label: 'Rev.00', code: 'AUD-2026-0001' };

async function render(name: string, params: Parameters<typeof specimen>[0]) {
  const { doc } = specimen(params, ctx);
  const t0 = performance.now();
  const r = await renderDocument(doc, assets, { idSeed: `specimen:${name}` });
  const ms = performance.now() - t0;
  const file = `${out}/${name}.pdf`;
  writeFileSync(file, r.bytes);
  return { r, ms, file };
}

const small = await render('pequeno', { rows: 12 });
const big = await render('extenso', { rows: 900, long_cell: true });
const draft = await render('previa', { rows: 30, draft: true });
console.log(`medições: pequeno ${small.r.pages} pág ${small.r.bytes.length} B ${small.ms.toFixed(0)} ms; extenso ${big.r.pages} pág ${big.r.bytes.length} B ${big.ms.toFixed(0)} ms`);

for (const d of [small, big, draft]) {
  let check = '';
  try { check = run('qpdf', ['--check', d.file]); } catch (e) { check = String((e as { stdout?: string }).stdout ?? e); }
  ok(`${d.file.split('/').pop()}: estrutura PDF válida (qpdf)`, /No syntax or stream encoding errors/.test(check), check.split('\n').find(l => /error|warning/i.test(l)) ?? '');
  const info = run('pdfinfo', [d.file]);
  ok(`${d.file.split('/').pop()}: páginas declaradas = motor`, new RegExp(`Pages:\\s+${d.r.pages}\\b`).test(info), `${d.r.pages}`);
  ok(`${d.file.split('/').pop()}: A4`, /Page size:\s+595\.28 x 841\.89/.test(info));
}

const text = run('pdftotext', ['-layout', big.file, '-']);
const pages = text.split('\f').filter(p => p.trim());
ok('Acentuação extraível', /ação, coração, órgão, pôr, avô, à, ü, ç, º, ª, € e “aspas”/.test(text.replace(/\s+/g, ' ')));
ok('Página X de Y em todas as páginas', pages.every((p, i) => p.includes(`Página ${i + 1} de ${big.r.pages}`)), `${pages.length} páginas com texto`);
ok('Cabeçalho repetido em todas as páginas', pages.every(p => p.includes('Documento de prova do emissor') && p.includes('AUD-2026-0001')));
ok('Tabela extensa: cabeçalho repetido nas continuações', (text.match(/Tabela 1 — Atividades programadas \(continuação\)/g) ?? []).length >= 10);
const flat = text.replace(/\s+/g, ' ');
const rawFlat = run('pdftotext', [big.file, '-']).replace(/\s+/g, ' ');
const order = [...rawFlat.matchAll(/Linha (\d+) do/g)].map(m => Number(m[1]));
const long = order.length === 140 && order.every((v, k) => v === k + 1);
ok('Célula maior que uma página dividida sem truncar (140 trechos presentes)', long);
ok('Última linha da tabela presente (900)', /\b900\b/.test(text) && flat.includes('Req.'));
ok('Tabela vazia explicada', flat.includes('Nenhuma pendência registrada nesta revisão.'));
ok('Gráfico vazio sem percentual fictício', flat.includes('Sem avaliações registradas no período: o gráfico não apresenta percentuais.'));
ok('Valores do gráfico em texto', /55 itens/.test(flat) && /30 itens/.test(flat));
ok('Nove notas do anexo na página final', pages[pages.length - 1].includes('Anexo A') && (pages[pages.length - 1].match(/Nota \d:/g) ?? []).length === 9);
const headings = specimen({ rows: 900, long_cell: true }, ctx).doc.blocks.filter(b => b.type === 'heading').map(b => (b as { text: string }).text);
ok('Título nunca é o último conteúdo da página', pages.every(p => { const ls = p.trimEnd().split('\n').filter(l => l.trim()); const last = (ls[ls.length - 2] ?? '').trim(); return !headings.includes(last); }), `${headings.length} títulos`);
ok('Prévia marcada em todas as páginas', run('pdftotext', [draft.file, '-']).split('\f').filter(p => p.trim()).every(p => p.includes('PRÉVIA')));
ok('Documento oficial sem marca de prévia', !text.includes('PRÉVIA'));
const again = await renderDocument(specimen({ rows: 12 }, ctx).doc, assets, { idSeed: 'specimen:pequeno' });
ok('Mesma entrada → mesmos bytes (determinístico)', again.sha256 === small.r.sha256, again.sha256.slice(0, 16));
const imgs = run('pdfimages', ['-list', small.file]);
ok('Imagens incorporadas (logo JPEG + PNG com transparência/SMask)', /jpeg/.test(imgs) && /smask/.test(imgs), imgs.split('\n').length - 3 + ' imagens');
let rejected = '';
try { await renderDocument({ ...specimen({ rows: 1 }, ctx).doc }, { logo }, { idSeed: 'x' }); } catch (e) { rejected = (e as Error).message; }
ok('Recurso ausente falha explicitamente (sem omitir a foto)', /Recurso ausente.*sample/.test(rejected), rejected);
const webp = new Uint8Array([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0, 0, 0, 0]);
try { await renderDocument(specimen({ rows: 1 }, ctx).doc, { logo, sample: webp }, { idSeed: 'x' }); rejected = ''; } catch (e) { rejected = (e as Error).message; }
ok('WebP recusado com orientação de conversão', /WebP/.test(rejected), rejected);
run('pdftoppm', ['-r', '60', '-png', '-f', '1', '-l', '3', big.file, `${out}/extenso`]);
run('pdftoppm', ['-r', '60', '-png', '-f', String(big.r.pages), '-l', String(big.r.pages), big.file, `${out}/extenso-fim`]);
run('pdftoppm', ['-r', '60', '-png', '-gray', '-f', '1', '-l', '1', draft.file, `${out}/previa-mono`]);
console.log(`---- ${pass}/${pass + fail} verificações do motor de PDF aprovadas`);
process.exit(fail ? 1 : 0);
