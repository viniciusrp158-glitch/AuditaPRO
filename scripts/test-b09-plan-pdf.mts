// B09 — PDF do Plano (modelo plan v1): retrato real do banco local e plano extenso sintético (PA-21).
// Valida estrutura (qpdf), páginas (pdfinfo) e texto (pdftotext): cabeçalho, rodapé "AUDITA | Plano de Auditoria", código|revisão,
// Página X de Y, 5 colunas, escopo após a tabela, controle de revisões e as nove notas integrais na página final.
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { renderDocument } from '../outputs/audita-pro-supabase/supabase/functions/document-emission/pdf/layout.ts';
import { resolveTemplate } from '../outputs/audita-pro-supabase/supabase/functions/document-emission/templates/index.ts';
import { planDoc } from '../outputs/audita-pro-supabase/supabase/functions/document-emission/templates/plan.ts';
import { BUILTIN_ASSETS } from '../outputs/audita-pro-supabase/supabase/functions/document-emission/assets/index.ts';

const out = '/tmp/claude-0/b09'; mkdirSync(out, { recursive: true });
let pass = 0, fail = 0;
const ok = (name: string, cond: boolean, detail = '') => { cond ? pass++ : fail++; console.log(`${cond ? 'ok ' : 'FALHA'} ${name}${detail ? ` — ${detail}` : ''}`); };
const run = (cmd: string, args: string[]) => execFileSync(cmd, args, { encoding: 'utf8' });
const logo = BUILTIN_ASSETS['builtin:logo'].load();
const real = JSON.parse(readFileSync(new URL('./fixtures/b09-plan-snapshot.json', import.meta.url), 'utf8'));

async function render(name: string, snap: Record<string, any>, draft = false) {
  const t = resolveTemplate('plan', 1)(snap, { title: 'x', revision_label: snap.revision.label, version_id: 'v', requested_at: snap.revision.at });
  const doc = draft ? planDoc(snap, { draft: true }) : t.doc;
  const r = await renderDocument(doc, { logo }, { idSeed: name });
  const file = `${out}/${name}.pdf`; writeFileSync(file, r.bytes);
  const text = run('pdftotext', ['-layout', file, '-']);
  return { r, file, text, pages: text.split('\f').filter(p => p.trim()), assets: Object.keys(t.assets) };
}

const a = await render('plano-real', real);
ok('Modelo pede apenas o logo embutido', a.assets.join() === 'logo');
ok('Estrutura PDF válida', /No syntax or stream encoding errors/.test(run('qpdf', ['--check', a.file])));
ok('Cabeçalho PLANO DE AUDITORIA e identidade textual AUDITA em todas as páginas', a.pages.every(p => p.includes('PLANO DE AUDITORIA') && p.includes('AUDITA ·')));
ok('Rodapé AUDITA | Plano de Auditoria, código | revisão e Página X de Y', a.pages.every((p, i) => p.includes('AUDITA | Plano de Auditoria') && p.includes(`${real.audit.code} | Rev.01`) && p.includes(`Página ${i + 1} de ${a.r.pages}`)));
const flat = a.text.replace(/\s+/g, ' ');
const raw = run('pdftotext', [a.file, '-']).replace(/\s+/g, ' ');
ok('Identificação: cliente, código, CNPJ formatado, endereço, período, critério, natureza e tipo',
  ['TESTE Organização X', 'CLI-0001', '11.222.333/0001-81', 'Rua das Indústrias, 100', '03/11/2026 a 06/11/2026', 'ISO 9001', '2ª parte', 'Certificação'].every(t => flat.includes(t)));
ok('Cinco colunas do cronograma', ['Localização', 'Data', 'Horário', 'Área / Departamento / Funções / Processos / Aspectos / Atividades', 'Auditor'].every(t => raw.includes(t)));
ok('Linha com dia real, horário, requisitos e auditor', raw.includes('04/11/2026') && raw.includes('Dia 2') && raw.includes('09:00–10:30') && raw.includes('Requisitos: 4.1 (ISO 9001)') && raw.includes('Lider X Teste'));
ok('Escopo apresentado após a tabela do cronograma', flat.indexOf('4. Escopo da auditoria') > flat.indexOf('Cronograma da auditoria'));
ok('Controle de revisões com Rev.00 e Rev.01 e motivo', flat.includes('Controle de revisões') && flat.includes('Rev.00') && flat.includes('Compras transferida para 04/11 a pedido do cliente'));
ok('FPA de referência sem caminho de arquivo', flat.includes('Versão 1, recebida em 20/10/2026') && !flat.includes('fpa.pdf'));
const last = a.pages[a.pages.length - 1].replace(/\s+/g, ' ');
ok('Página final dedicada às Notas com o texto integral do Anexo A', last.includes('Notas') && !last.includes('Cronograma da auditoria')
  && (real.notes as string[]).every(n => last.includes(n.replace(/\s+/g, ' '))), `${(real.notes as string[]).length} notas`);

// PA-21: plano extenso (150 atividades, textos longos, vários auditores).
const big = structuredClone(real);
big.schedule = Array.from({ length: 150 }, (_, i) => ({ ...real.schedule[i % real.schedule.length], key: `k${i}`, title: `Atividade ${i + 1} — ${'avaliação do processo de compras e qualificação de fornecedores '.repeat(1 + (i % 3))}`,
  date: `2026-11-0${3 + (i % 4)}`, day_number: 1 + (i % 4), start_time: `${String(8 + (i % 9)).padStart(2, '0')}:00`, end_time: `${String(9 + (i % 9)).padStart(2, '0')}:00`,
  assignees: ['Lider X Teste', 'Auditor X Teste', 'Auditora de Apoio com Nome Bastante Longo'].slice(0, 1 + (i % 3)) }));
const b = await render('plano-extenso', big);
ok('PA-21 plano extenso: PDF válido com várias páginas', /No syntax or stream encoding errors/.test(run('qpdf', ['--check', b.file])) && b.r.pages > 8, `${b.r.pages} páginas`);
ok('PA-21 rodapé e paginação em todas as páginas', b.pages.every((p, i) => p.includes('AUDITA | Plano de Auditoria') && p.includes(`Página ${i + 1} de ${b.r.pages}`)));
ok('PA-21 cabeçalho da tabela repetido nas continuações', (b.text.match(/Cronograma da auditoria \(continuação\)/g) ?? []).length >= 5);
const bflat = run('pdftotext', [b.file, '-']).replace(/\s+/g, ' ');
ok('PA-21 nenhuma atividade cortada (150 presentes)', Array.from({ length: 150 }, (_, i) => `Atividade ${i + 1} —`).every(t => bflat.includes(t)));
const blast = b.pages[b.pages.length - 1].replace(/\s+/g, ' ');
ok('PA-21 notas completas na última página', (real.notes as string[]).every(n => blast.includes(n.replace(/\s+/g, ' '))));
const p = await render('plano-previa', real, true);
ok('Prévia marcada em todas as páginas', p.pages.every(x => x.includes('PRÉVIA')));
run('pdftoppm', ['-r', '70', '-png', '-f', '1', '-l', '2', a.file, `${out}/plano`]);
run('pdftoppm', ['-r', '70', '-png', '-f', String(a.r.pages), '-l', String(a.r.pages), a.file, `${out}/plano-notas`]);
console.log(`---- ${pass}/${pass + fail} verificações do PDF do Plano aprovadas`);
process.exit(fail ? 1 : 0);
