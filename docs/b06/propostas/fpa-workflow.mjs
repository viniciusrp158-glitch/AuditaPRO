/**
 * B06: executable domain proposal, NOT connected to the application or an API.
 * D09 and the backend adapter must be reconciled before activation.
 * `context` is server-owned: never build it from a request body's claims.
 * Real storage validation, auth, persistence, transaction/CAS and idempotency
 * belong to that adapter. This module neither uploads nor proves RLS.
 */
export const FPA_STATES = Object.freeze([
  'not_requested', 'requested', 'received', 'under_review',
  'complement_requested', 'sufficient',
]);

function required(value, field) {
  if (typeof value !== 'string' || !value.trim()) throw new Error(`${field} obrigatório`);
  return value.trim();
}
function day(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value || '')) throw new Error('Prazo inválido');
  const date = new Date(`${value}T00:00:00Z`);
  if (!Number.isFinite(+date) || date.toISOString().slice(0, 10) !== value) throw new Error('Prazo inválido');
  return value;
}
function permit(context, auditId) {
  if (!context || context.active !== true || context.can_manage_fpa !== true || context.audit_id !== auditId)
    throw new Error('Acesso ao FPA recusado');
  required(context.actor_id, 'Autor');
  if (typeof context.now !== 'string' || !Number.isFinite(Date.parse(context.now)))
    throw new Error('Instante do servidor inválido');
}

export function emptyFpa(auditId) {
  return { audit_id: required(auditId, 'Auditoria'), state: 'not_requested', lock_version: 0,
    recipient: null, due_date: null, versions: [], history: [] };
}

/** Returns a new aggregate. Persist it only with a transactional version check. */
export function transitionFpa(current, command, payload, context) {
  permit(context, current?.audit_id);
  if (!FPA_STATES.includes(current.state)) throw new Error('Estado de FPA inválido');
  if (!payload || !Number.isInteger(payload.expected_lock_version) ||
      payload.expected_lock_version !== current.lock_version) throw new Error('Conflito de versão do FPA');
  const next = structuredClone(current);
  const event = { command, actor_id: context.actor_id, at: context.now,
    from_state: current.state, version_id: null };
  const latest = next.versions.at(-1);
  if (command === 'request') {
    if (current.state !== 'not_requested') throw new Error('FPA já solicitado');
    next.recipient = required(payload.recipient, 'Destinatário');
    next.due_date = day(payload.due_date);
    next.state = 'requested';
    event.recipient = next.recipient;
    event.due_date = next.due_date;
  } else if (command === 'receive') {
    if (!['requested', 'complement_requested'].includes(current.state)) throw new Error('Recebimento não permitido neste estado');
    // Only an independently verified storage record supplied by the adapter counts.
    const file = context.verified_file;
    if (!file || file.audit_id !== current.audit_id || file.complete !== true ||
        file.private !== true || !Number.isSafeInteger(file.size_bytes) || file.size_bytes <= 0)
      throw new Error('Arquivo privado e íntegro desta auditoria obrigatório');
    const fileId = required(file.id, 'Arquivo');
    const checksum = required(file.checksum, 'Integridade');
    const versionId = required(context.new_version_id, 'Versão');
    if (next.versions.some(v => v.id === versionId || v.file_id === fileId)) throw new Error('Versão ou arquivo já registrado');
    next.versions.push({ id: versionId, number: next.versions.length + 1,
      file_id: fileId, checksum, received_by: context.actor_id, received_at: context.now,
      analysis: null });
    event.version_id = versionId;
    next.state = 'received';
  } else if (command === 'start_review') {
    if (current.state !== 'received' || !latest) throw new Error('Receba o arquivo antes da análise');
    if (payload.version_id !== latest.id) throw new Error('Selecione a versão atual do FPA');
    event.version_id = latest.id;
    next.state = 'under_review';
  } else if (command === 'request_complement' || command === 'mark_sufficient') {
    if (current.state !== 'under_review' || !latest) throw new Error('Inicie a análise da versão recebida');
    if (payload.version_id !== latest.id) throw new Error('Selecione a versão atual do FPA');
    const analysis = required(payload.analysis, 'Análise');
    latest.analysis = { text: analysis, by: context.actor_id, at: context.now,
      sufficient: command === 'mark_sufficient' };
    event.version_id = latest.id;
    event.analysis = structuredClone(latest.analysis);
    next.state = command === 'mark_sufficient' ? 'sufficient' : 'complement_requested';
    if (command === 'request_complement') {
      next.recipient = required(payload.recipient, 'Destinatário');
      next.due_date = day(payload.due_date);
      event.recipient = next.recipient;
      event.due_date = next.due_date;
    }
  } else throw new Error('Comando de FPA não reconhecido');
  next.lock_version += 1;
  event.to_state = next.state;
  event.lock_version = next.lock_version;
  next.history.push(event);
  return next;
}

/** Private reference for a future B09 snapshot, not its public PDF projection. */
export function fpaPlanReference(current, context) {
  permit(context, current?.audit_id);
  const latest = current.versions.at(-1);
  if (current.state !== 'sufficient' || latest?.analysis?.sufficient !== true)
    throw new Error('FPA ainda insuficiente para validar o plano');
  return { audit_id: current.audit_id, fpa_version_id: latest.id,
    fpa_lock_version: current.lock_version, analysis_by: latest.analysis.by,
    analysis_at: latest.analysis.at, file_checksum: latest.checksum };
}
