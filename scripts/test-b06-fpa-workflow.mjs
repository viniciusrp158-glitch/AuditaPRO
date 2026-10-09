import assert from 'node:assert/strict';
import { emptyFpa, transitionFpa, fpaPlanReference } from '../docs/b06/propostas/fpa-workflow.mjs';

const context = { audit_id: 'audit-a', actor_id: 'leader-a', active: true,
  can_manage_fpa: true, now: '2026-10-09T14:00:00Z' };
const apply = (s, cmd, p = {}, c = context) => transitionFpa(s, cmd, { expected_lock_version: s.lock_version, ...p }, c);
let state = emptyFpa('audit-a');
const blank = structuredClone(state);
assert.throws(() => fpaPlanReference(state, context), /insuficiente/);
for (const invalid of [{ ...context, active: false }, { ...context, can_manage_fpa: false }, { ...context, audit_id: 'audit-b' }])
  assert.throws(() => apply(state, 'request', {}, invalid), /recusado/);
assert.throws(() => apply(state, 'request', { recipient: 'Cliente', due_date: '2026-02-30' }), /Prazo/);
state = apply(state, 'request', { recipient: 'Contato autorizado', due_date: '2026-10-15' });
assert.deepEqual(blank, emptyFpa('audit-a')); // no mutation of original aggregate
assert.throws(() => apply(state, 'receive', { file: { complete: true } }), /Arquivo/); // browser claim ignored
const file1 = { audit_id: 'audit-a', id: 'file-v1', complete: true, private: true, size_bytes: 120, checksum: 'digest-v1' };
assert.throws(() => apply(state, 'receive', {}, { ...context, verified_file: { ...file1, audit_id: 'audit-b' }, new_version_id: 'v1' }), /Arquivo/);
state = apply(state, 'receive', {}, { ...context, verified_file: file1, new_version_id: 'v1' });
assert.throws(() => apply(state, 'mark_sufficient', { version_id: 'v1', analysis: 'Completo' }), /Inicie/);
state = apply(state, 'start_review', { version_id: 'v1' });
state = apply(state, 'request_complement', { version_id: 'v1', analysis: 'Falta escopo', recipient: 'Contato autorizado', due_date: '2026-10-20' });
const firstVersion = structuredClone(state.versions[0]);
assert.throws(() => fpaPlanReference(state, context), /insuficiente/);
assert.throws(() => apply(state, 'receive', {}, { ...context, verified_file: file1, new_version_id: 'v2' }), /já registrado/);
state = apply(state, 'receive', {}, { ...context, verified_file: { ...file1, id: 'file-v2', checksum: 'digest-v2' }, new_version_id: 'v2' });
assert.throws(() => apply(state, 'start_review', { version_id: 'v1' }), /versão atual/);
state = apply(state, 'start_review', { version_id: 'v2' });
assert.throws(() => apply(state, 'mark_sufficient', { version_id: 'v2', analysis: '' }), /Análise/);
assert.throws(() => apply(state, 'mark_sufficient', { expected_lock_version: 0, version_id: 'v2', analysis: 'Completo' }), /Conflito/);
const before = structuredClone(state);
state = apply(state, 'mark_sufficient', { version_id: 'v2', analysis: 'Informações suficientes para planejar' });
assert.equal(before.state, 'under_review');
assert.deepEqual(state.versions[0], firstVersion);
const ref = fpaPlanReference(state, context);
assert.equal(ref.fpa_version_id, 'v2');
assert.equal(ref.analysis_by, context.actor_id);
assert.ok(!('file_id' in ref) && !('analysis' in ref));
assert.equal(state.history.length, 7);
assert.throws(() => apply(state, 'receive', {}, { ...context, verified_file: file1 }), /não permitido/);
console.log('PASS B06 FPA domain proposal: transitions, incomplete/wrong-audit files, authorization input, stale version, immutable history and private reference. No API/RLS/Storage execution.');
