// B08: orquestrador da Edge Function (emit.ts) contra a máquina de estados real do banco local (psql como service_role)
// e um Storage simulado com injeção de falhas: upload, arquivo corrompido, resposta perdida, concorrência e posse perdida.
import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { processEmission, runTicket, type Deps } from '../outputs/audita-pro-supabase/supabase/functions/document-emission/emit.ts';
import { sha256Hex } from '../outputs/audita-pro-supabase/supabase/functions/document-emission/pdf/zlib.ts';

// Banco próprio (recriado a cada execução): este teste grava de verdade e não pode contaminar os testes SQL em transação.
const FLOW_DB = process.env.PGTEST_FLOW_DB ?? 'auditapro_flow';
execFileSync('bash', [new URL('./localdb/rebuild.sh', import.meta.url).pathname], { env: { ...process.env, PGTEST_DB: FLOW_DB }, stdio: 'ignore' });
const PG = ['-h', process.env.PGTEST_HOST ?? '/home/claude/.pgtest', '-p', process.env.PGTEST_PORT ?? '54329', '-U', 'postgres', '-d', FLOW_DB, '-qAt', '-v', 'ON_ERROR_STOP=1'];
const sql = (q: string, role = 'postgres') => execFileSync('psql', [...PG, '-c', `set role ${role};`, '-c', q], { encoding: 'utf8' }).trim();
const j = (v: unknown) => `$j$${JSON.stringify(v)}$j$::jsonb`;
let pass = 0, fail = 0;
const ok = (name: string, cond: boolean, detail = '') => { cond ? pass++ : fail++; console.log(`${cond ? 'ok ' : 'FALHA'} ${name}${detail ? ` — ${detail}` : ''}`); };

const ADMIN = 'a0000000-0000-4000-8000-000000000001';
function newSpecimen(rows = 60, auto = true): string {
  return sql(`select (private.b08_request('specimen', v, v, null, null, 'Rev.00', 'Prova fluxo', 'prova-fluxo.pdf', 'specimen', 1,
    jsonb_build_object('params', jsonb_build_object('rows', ${rows}, 'long_cell', true), 'code', 'PROVA-T', 'issued_at', '2026-10-10T20:00:00.123456+00:00'),
    ${auto}, '${ADMIN}')).id from (select gen_random_uuid() v) x`);
}
const row = (id: string) => JSON.parse(sql(`select to_jsonb(e) - 'content' from private.document_emissions e where id = '${id}'`));

const store = new Map<string, Uint8Array>();
type Hooks = { upload?: (path: string) => void; corrupt?: boolean; afterComplete?: () => void };
function deps(h: Hooks = {}): Deps {
  return {
    worker: async (command, payload) => {
      const out = JSON.parse(sql(`select public.document_emission_worker('${command}', ${j(payload)})`, 'service_role'));
      if (command === 'complete' && h.afterComplete) h.afterComplete();
      return out;
    },
    upload: async (bucket, path, bytes) => {
      h.upload?.(path);
      const key = `${bucket}/${path}`;
      if (store.has(key)) throw new Error('já existe');
      store.set(key, h.corrupt ? bytes.slice(0, bytes.length - 10) : bytes);
    },
    download: async (bucket, path) => { const b = store.get(`${bucket}/${path}`); if (!b) throw new Error('não encontrado'); return b; },
    remove: async (bucket, path) => { store.delete(`${bucket}/${path}`); },
    ticket: async (command, payload) => JSON.parse(sql(`select public.document_emission_ticket('${command}', ${j(payload)})`, 'service_role')),
  };
}
const objects = (id: string) => [...store.keys()].filter(k => k.includes(id));

// 1. Upload interrompido → falha retomável; nova chamada conclui a mesma revisão.
const e1 = newSpecimen(300);
let r = await processEmission(deps({ upload: () => { throw new Error('conexão encerrada durante o upload'); } }), e1, ADMIN);
ok('Upload interrompido: falha registrada, nenhum arquivo oficial', r.state === 'failed' && row(e1).status === 'failed' && objects(e1).length === 0, r.error);
const t0 = performance.now();
r = await processEmission(deps(), e1, ADMIN);
const ms = performance.now() - t0;
const d1 = row(e1);
ok('Retomada conclui a mesma revisão e publica após integridade', r.state === 'published' && d1.status === 'published' && d1.attempt_count === 2 && objects(e1).length === 1, `${d1.page_count} páginas, ${ms.toFixed(0)} ms`);
const bytes = store.get(`document-emissions/${d1.storage_path}`)!;
ok('Hash registrado = hash do arquivo armazenado', await sha256Hex(bytes) === d1.pdf_sha256 && bytes.length === Number(d1.size_bytes));
writeFileSync('/tmp/claude-0/b08/fluxo.pdf', bytes);
ok('Arquivo armazenado é PDF válido com as páginas registradas', new RegExp(`Pages:\\s+${d1.page_count}\\b`).test(execFileSync('pdfinfo', ['/tmp/claude-0/b08/fluxo.pdf'], { encoding: 'utf8' })));
ok('Manifesto registra logo embutido e imagem com hash', Array.isArray(d1.asset_manifest) && d1.asset_manifest.some((a: any) => a.id === 'builtin:logo' && /^[0-9a-f]{64}$/.test(a.sha256)), JSON.stringify(d1.asset_manifest).slice(0, 120));
ok('Medições registradas (assets, geração, upload, conferência)', ['assets_ms', 'render_ms', 'upload_ms', 'verify_ms', 'pages', 'bytes'].every(k => k in d1.metrics), JSON.stringify(d1.metrics));
r = await processEmission(deps(), e1, ADMIN);
ok('Nova chamada após emitida não gera outro arquivo', r.state === 'done' && objects(e1).length === 1);

// 2. Arquivo corrompido no armazenamento → removido, falha.
const e2 = newSpecimen(10);
r = await processEmission(deps({ corrupt: true }), e2, ADMIN);
ok('Arquivo que não confere é retirado e a emissão falha', r.state === 'failed' && objects(e2).length === 0 && row(e2).status === 'failed', r.error);

// 3. Confirmação gravada, resposta perdida → arquivo preservado; estado final pronto/publicado.
const e3 = newSpecimen(10);
r = await processEmission(deps({ afterComplete: () => { throw new Error('rede caiu após a confirmação'); } }), e3, ADMIN);
const d3 = row(e3);
ok('Resposta perdida após confirmar: arquivo preservado e documento emitido', d3.status === 'published' && objects(e3).length === 1
  && await sha256Hex(store.get(`document-emissions/${d3.storage_path}`)!) === d3.pdf_sha256, `${r.state} / ${d3.status}`);
r = await processEmission(deps(), e3, ADMIN);
ok('Retentativa depois disso retorna o documento já concluído', r.state === 'done');

// 4. Duas chamadas simultâneas → um único arquivo.
const e4 = newSpecimen(40);
const [a, b] = await Promise.all([processEmission(deps(), e4, ADMIN), processEmission(deps(), e4, ADMIN)]);
ok('Duas tentativas simultâneas criam um único documento', [a.state, b.state].sort().join(',') === 'busy,published' && objects(e4).length === 1 && row(e4).attempt_count === 1, `${a.state}, ${b.state}`);

// 5. Posse perdida no meio do upload (processo lento) → arquivo desta tentativa retirado; o outro processo continua.
const e5 = newSpecimen(10, false);
r = await processEmission(deps({ upload: () => {
  sql(`update private.document_emissions set lease_expires_at = clock_timestamp() - interval '1 second' where id = '${e5}'`);
  sql(`select public.document_emission_worker('claim', ${j({ emission_id: e5 })})`, 'service_role');
} }), e5, ADMIN);
const d5 = row(e5);
ok('Processo que perdeu a posse não publica e retira o próprio arquivo', r.state === 'lease_lost' && objects(e5).length === 0 && d5.status === 'processing' && d5.attempt_count === 2, r.state);

// 6. Modelo inexistente → falha explícita.
const e6 = sql(`select (private.b08_request('specimen', v, v, null, null, 'Rev.00', 'x', 'x.pdf', 'inexistente', 9, '{}', false, '${ADMIN}')).id from (select gen_random_uuid() v) x`);
r = await processEmission(deps(), e6, ADMIN);
ok('Modelo não disponível falha com mensagem clara', r.state === 'failed' && /Modelo inexistente v9/.test(r.error ?? ''), r.error);

// 7. Bilhetes do banco (pg_net/pg_cron): processamento sem navegador e autoteste no runtime.
const e7 = newSpecimen(20);
const t7 = sql(`select private.b08_dispatch('process', '${e7}')`);
let k = await runTicket(deps(), t7);
ok('Bilhete do banco conclui a emissão sem navegador', k.valid === true && row(e7).status === 'published' && objects(e7).length === 1, JSON.stringify(k));
k = await runTicket(deps(), t7);
ok('Bilhete reutilizado é recusado', k.valid === false);
const ts = sql(`select private.b08_dispatch('selftest', null, '{"rows": 400, "long_cell": true}')`);
k = await runTicket(deps(), ts);
const st = JSON.parse(sql(`select result from private.document_emission_tickets where ticket = '${ts}'`));
ok('Autoteste: gera, grava, confere e retira o arquivo; medições guardadas', k.valid === true && st.ok === true && st.pages > 20
  && ![...store.keys()].some(x => x.includes(ts)), `${st.pages} pág, ${st.bytes} B, geração ${st.render_ms} ms, total ${st.total_ms} ms`);

const snap = JSON.parse(execFileSync('cat', ['scripts/fixtures/b09-plan-snapshot.json'], { encoding: 'utf8' }));
const tp = sql(`select private.b08_dispatch('selftest', null, ${j({ template: 'plan', snapshot: snap })})`);
k = await runTicket(deps(), tp);
const sp = JSON.parse(sql(`select result from private.document_emission_tickets where ticket = '${tp}'`));
ok('Autoteste do modelo do Plano (prévia) no mesmo caminho do runtime', k.valid === true && sp.ok === true && sp.template === 'plan' && sp.pages >= 3, `${sp.pages} pág`);

console.log(`---- ${pass}/${pass + fail} verificações do fluxo de emissão aprovadas`);
process.exit(fail ? 1 : 0);
