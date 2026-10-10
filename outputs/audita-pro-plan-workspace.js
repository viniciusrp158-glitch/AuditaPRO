/* B06 — Plano de Auditoria: Identificação e FPA.
   Lê/grava pelo contrato public.audit_identification e public.audit_fpa; arquivos de FPA pela
   Edge Function audit-fpa-files. A interface apenas apresenta: o servidor decide quem edita. */
(() => {
  'use strict';
  const esc = v => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const L = { first: '1ª parte', second: '2ª parte', third: '3ª parte', presential: 'Presencial', remote: 'Remota', hybrid: 'Híbrida',
    initial: 'Inicial', certification: 'Certificação', maintenance: 'Manutenção', recertification: 'Recertificação', follow_up: 'Follow-up',
    diagnostic: 'Diagnóstico', other: 'Outra', leader: 'Condutor', auditor: 'Auditor de apoio' };
  const FPA = { not_requested: 'Não solicitado', requested: 'Solicitado', received: 'Recebido', in_analysis: 'Em análise',
    complement_requested: 'Complementação solicitada', sufficient: 'Suficiente para planejar' };
  const STEPS = ['not_requested', 'requested', 'received', 'in_analysis', 'sufficient'];
  const ACTIONS = { request: 'Solicitação registrada', register_file: 'Recebimento registrado', start_analysis: 'Análise iniciada',
    request_complement: 'Complementação solicitada', mark_sufficient: 'Considerada suficiente' };
  const day = v => v ? new Date(v + 'T12:00:00').toLocaleDateString('pt-BR') : '—';
  const when = v => v ? new Date(v).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) : '—';
  const size = n => n >= 1048576 ? `${(n / 1048576).toFixed(1).replace('.', ',')} MB` : `${Math.max(1, Math.round(n / 1024))} KB`;
  const pending = v => v ? esc(v) : '<span class="pw-missing">Pendente</span>';

  function addressText(a) { return window.AuditaPlanIdentification?.formatAddress?.(a) || ''; }

  function identificationHtml(d, canEdit) {
    const i = d.identification, c = i.client || {};
    const period = i.declared_start_date || i.declared_end_date ? `${day(i.declared_start_date)} a ${day(i.declared_end_date)}` : null;
    const evaluation = i.evaluation_type ? (i.evaluation_type === 'other' ? `Outra — ${i.evaluation_other || 'descrição pendente'}` : L[i.evaluation_type]) : null;
    const team = (i.team || []).map(t => `${esc(t.name)} <span class="badge">${esc(t.conductor ? 'Condutor' : L[t.role] || t.role)}</span>`).join('<br>');
    const rows = [
      ['Cliente', esc(c.name), true], ['Código do cliente', pending(c.code)], ['CNPJ', esc(c.cnpj || '—')],
      ['Código da auditoria', esc(i.code)], ['Endereço cadastrado do cliente', esc(addressText(c.address) || '—'), true],
      ['Unidade / local cadastrado', esc(i.unit?.name || '—')], ['Localização da auditoria', pending(i.location)],
      ['Período da auditoria', pending(period)], ['Natureza', pending(L[i.party])], ['Tipo de avaliação', pending(evaluation)],
      ['Modalidade', esc(L[i.modality] || '—')],
      ['Norma / critério de auditoria', (i.criteria_items || []).length ? i.criteria_items.map(t => `${esc(t.code)}${t.edition ? ' · ' + esc(t.edition) : ''} — ${esc(t.name)}`).join('<br>') : pending(null), true],
      ['Objetivo da auditoria', pending(i.objective), true], ['Equipe auditora', team || pending(null), true],
      ['Outros participantes em nome da AUDITA', pending(i.participants_text), true], ['Comentários', pending(i.comments), true],
      ['Escopo da auditoria', pending(i.scope), true],
    ];
    return `<section class="identification-summary pw-section" aria-labelledby="pwIdTitle"><div class="pw-heading"><div><span class="eyebrow">PLANO DE AUDITORIA · ETAPA 1</span><h2 id="pwIdTitle">Identificação</h2></div>
      ${canEdit ? '<button type="button" class="button" data-pw="edit">Editar identificação</button>' : ''}</div>
      <p class="hint">O rascunho pode ficar incompleto. Itens marcados como <strong>Pendente</strong> impedirão a validação do plano.</p>
      <dl>${rows.map(([t, v, wide]) => `<div class="${wide ? 'wide' : ''}"><dt>${t}</dt><dd>${v}</dd></div>`).join('')}</dl></section>`;
  }

  function fpaHtml(f, canEdit) {
    const status = f.status, idx = STEPS.indexOf(status === 'complement_requested' ? 'in_analysis' : status);
    const steps = STEPS.map((s, n) => `<li class="${n < idx ? 'done' : n === idx ? 'current' : ''}" ${n === idx ? 'aria-current="step"' : ''}>${esc(FPA[s])}</li>`).join('');
    const latest = f.versions[0];
    const info = [
      f.recipient_name ? `<div><dt>Destinatário</dt><dd>${esc(f.recipient_name)}${f.recipient_contact ? ' · ' + esc(f.recipient_contact) : ''}</dd></div>` : '',
      f.due_date ? `<div><dt>Prazo combinado</dt><dd>${day(f.due_date)}</dd></div>` : '',
      f.requested_at ? `<div><dt>Solicitado em</dt><dd>${when(f.requested_at)} · ${esc(f.requested_by || '')}</dd></div>` : '',
      f.complement_questions && status === 'complement_requested' ? `<div class="wide"><dt>Complementação pendente</dt><dd>${esc(f.complement_questions)}${f.complement_due_date ? ` (prazo ${day(f.complement_due_date)})` : ''}</dd></div>` : '',
      status === 'sufficient' ? `<div class="wide"><dt>Análise</dt><dd>Versão ${esc(f.versions.find(v => v.id === f.sufficient_version_id)?.version_number)} considerada suficiente em ${when(f.analyzed_at)} por ${esc(f.analyzed_by)}${f.analysis_note ? ' — ' + esc(f.analysis_note) : ''}</dd></div>` : '',
    ].join('');
    const today = new Date().toISOString().slice(0, 10);
    let actions = '';
    if (canEdit) {
      if (status === 'not_requested' || status === 'requested') actions += `<form class="pw-form" data-pw-form="request"><h3>${status === 'requested' ? 'Atualizar solicitação' : 'Registrar solicitação da FPA'}</h3><div class="form-grid"><label class="field">Destinatário *<input name="recipient_name" required minlength="2" maxlength="200" value="${esc(f.recipient_name || '')}"></label><label class="field">Contato<input name="recipient_contact" maxlength="200" value="${esc(f.recipient_contact || '')}"></label><label class="field">Prazo combinado<input name="due_date" type="date" value="${esc(f.due_date || '')}"></label></div><button class="button">Salvar solicitação</button></form>`;
      if (status !== 'not_requested') actions += `<form class="pw-form" data-pw-form="upload"><h3>Registrar recebimento ${f.versions.length ? '(nova versão)' : ''}</h3><p class="hint">Anexe o arquivo efetivamente recebido (PDF, DOCX ou XLSX, até 20 MB). Uma nova versão exige nova análise; as anteriores são preservadas.</p><div class="form-grid"><label class="field">Arquivo *<input name="file" type="file" required accept=".pdf,.docx,.xlsx"></label><label class="field">Recebido em *<input name="received_on" type="date" required max="${today}" value="${today}"></label><label class="field">Observação<input name="source_note" maxlength="1000" placeholder="Ex.: recebido por e-mail"></label></div><button class="button">Registrar recebimento</button></form>`;
      if (status === 'received') actions += `<div class="pw-form"><button type="button" class="button" data-pw="start_analysis">Iniciar análise da versão ${esc(latest?.version_number)}</button></div>`;
      if (status === 'in_analysis') actions += `<form class="pw-form" data-pw-form="sufficient"><h3>Concluir análise da versão ${esc(latest?.version_number)}</h3><label class="field">Parecer<textarea name="note" maxlength="5000" placeholder="Ex.: informações suficientes para planejar"></textarea></label><button class="button">Considerar suficiente</button></form>
        <form class="pw-form" data-pw-form="complement"><h3>Solicitar complementação</h3><div class="form-grid"><label class="field">Informações pendentes *<textarea name="questions" required minlength="3" maxlength="5000"></textarea></label><label class="field">Novo prazo<input name="due_date" type="date"></label></div><button class="button secondary">Solicitar complementação</button></form>`;
    }
    const versions = f.versions.length ? `<div class="pw-table-wrap"><table class="data-table pw-table"><caption class="ap-sr-only">Versões recebidas da FPA</caption><thead><tr><th>Versão</th><th>Arquivo</th><th>Recebido em</th><th>Registrado</th><th></th></tr></thead><tbody>${f.versions.map(v => `<tr><td>${esc(v.version_number)}${v.id === f.sufficient_version_id ? ' <span class="badge approved">Analisada · suficiente</span>' : ''}</td><td>${esc(v.filename)}<span class="cell-sub">${esc(v.format.toUpperCase())} · ${size(v.size_bytes)}${v.source_note ? ' · ' + esc(v.source_note) : ''}</span></td><td>${day(v.received_on)}</td><td>${when(v.registered_at)}<span class="cell-sub">${esc(v.registered_by || '')}</span></td><td><button type="button" class="button secondary" data-pw-download="${esc(v.id)}">Baixar</button></td></tr>`).join('')}</tbody></table></div>` : '<p class="muted">Nenhum arquivo de FPA recebido para esta auditoria.</p>';
    const events = f.events.length ? `<details class="pw-events"><summary>Histórico da FPA (${f.events.length})</summary><ul>${f.events.map(e => `<li>${when(e.at)} — ${esc(ACTIONS[e.action] || e.action)}${e.actor ? ' · ' + esc(e.actor) : ''}</li>`).join('')}</ul></details>` : '';
    return `<section class="identification-summary pw-section" aria-labelledby="pwFpaTitle"><div class="pw-heading"><div><span class="eyebrow">PREPARAÇÃO</span><h2 id="pwFpaTitle">FPA — Formulário de Preparação para Auditoria</h2></div><span class="badge ${status === 'sufficient' ? 'approved' : 'pending'}">${esc(FPA[status])}</span></div>
      <ol class="pw-steps" aria-label="Etapas da FPA">${steps}</ol>
      ${status !== 'sufficient' ? '<p class="hint">Você pode continuar o rascunho do plano. A validação final fica bloqueada até a FPA ser considerada suficiente.</p>' : ''}
      ${info ? `<dl>${info}</dl>` : ''}${actions}<h3>Versões recebidas</h3>${versions}${events}
      <p class="hint">A FPA é restrita à equipe interna da auditoria e não integra automaticamente o PDF do plano nem a consulta do cliente.</p></section>`;
  }

  async function mount(container, { client, auditId, types = [], onChanged }) {
    const rpc = async (fn, command, payload) => { const r = await client.rpc(fn, { command, payload: { audit_id: auditId, ...payload } }); if (r.error) throw new Error(r.error.message); return r.data; };
    const files = async body => {
      const { data: { session } } = await client.auth.getSession();
      let res;
      try {
        res = await fetch(`${window.AUDITA_PRO_SUPABASE_URL}/functions/v1/audit-fpa-files`, { method: 'POST',
          headers: { Authorization: `Bearer ${session?.access_token}`, apikey: window.AUDITA_PRO_SUPABASE_PUBLISHABLE_KEY, ...(body instanceof FormData ? {} : { 'Content-Type': 'application/json' }) },
          body: body instanceof FormData ? body : JSON.stringify(body) });
      } catch { throw new Error('Sem conexão com o serviço de arquivos.'); }
      let data = {}; try { data = await res.json(); } catch { /* sem corpo */ }
      if (!res.ok) throw new Error(data.error || 'O serviço de arquivos não respondeu corretamente.');
      return data;
    };
    let ident, fpa, busy = false;
    const notice = (msg, kind = 'ok') => { const n = container.querySelector('#pwNotice'); if (n) { n.hidden = !msg; n.className = `notice ${kind === 'error' ? 'error' : ''}`; n.textContent = msg || ''; } };
    async function load() {
      container.innerHTML = '<p class="muted">Carregando identificação e FPA…</p>';
      try { [ident, fpa] = await Promise.all([rpc('audit_identification', 'detail', {}), rpc('audit_fpa', 'detail', {})]); }
      catch (e) { container.innerHTML = `<div class="notice error" role="alert">Não foi possível carregar a identificação do plano: ${esc(e.message)} <button type="button" class="button secondary" data-pw="reload">Tentar novamente</button></div>`; return; }
      container.innerHTML = `<div id="pwNotice" class="notice" role="status" aria-live="polite" hidden></div>${identificationHtml(ident, ident.can_edit)}${fpaHtml(fpa, fpa.can_edit)}`;
    }
    async function act(task, okMessage) {
      if (busy) return; busy = true;
      try { await task(); await load(); notice(okMessage); onChanged?.(); }
      catch (e) { notice(e.message, 'error'); }
      finally { busy = false; }
    }
    function editDialog() {
      const helper = window.AuditaPlanIdentification;
      const data = { ...ident.identification, lock_version: ident.identification.lock_version };
      const dialog = document.createElement('dialog'); dialog.className = 'audit-dialog'; dialog.id = 'pwDialog';
      dialog.innerHTML = `<form><div class="dialog-header"><h2>Editar identificação</h2><button type="button" class="icon-button" aria-label="Fechar" data-close>×</button></div><p class="error-text" role="alert" id="pwDialogError"></p>
        ${ident.identification.criteria_locked ? '<p class="hint">Os critérios já foram aplicados ao checklist e só mudam por revisão de escopo própria.</p>' : ''}
        ${helper.editingForm(data, types, ident.identification.units || [])}
        <div class="dialog-actions"><button type="button" class="button secondary" data-close>Cancelar</button><button class="button">Salvar rascunho</button></div></form>`;
      document.body.append(dialog); dialog.showModal();
      if (ident.identification.criteria_locked) dialog.querySelectorAll('[name=criterion_ids]').forEach(b => { b.disabled = true; });
      dialog.querySelectorAll('[data-close]').forEach(b => b.onclick = () => dialog.remove());
      dialog.querySelector('form').onsubmit = async e => {
        e.preventDefault();
        const form = e.target, payload = helper.editingPayload(form, { ...data, audit_id: auditId });
        if (ident.identification.criteria_locked) payload.criterion_ids = ident.identification.criterion_ids;
        if (payload.evaluation_type === 'other' && !String(payload.evaluation_other || '').trim()) { dialog.querySelector('#pwDialogError').textContent = 'Descreva o tipo de avaliação “Outra” (pode completar depois, mas a validação exigirá).'; }
        const submit = form.querySelector('button:not([type=button])'); submit.disabled = true;
        try { await rpc('audit_identification', 'save', payload); dialog.remove(); await load(); notice('Identificação salva no rascunho.'); onChanged?.(); }
        catch (x) { dialog.querySelector('#pwDialogError').textContent = x.message; submit.disabled = false; }
      };
    }
    container.onclick = async e => {
      const b = e.target.closest('button'); if (!b) return;
      if (b.dataset.pw === 'reload') load();
      else if (b.dataset.pw === 'edit') editDialog();
      else if (b.dataset.pw === 'start_analysis') act(() => rpc('audit_fpa', 'start_analysis', { expected_lock_version: fpa.lock_version }), 'Análise iniciada.');
      else if (b.dataset.pwDownload) {
        b.disabled = true;
        try { const r = await files({ action: 'download', audit_id: auditId, version_id: b.dataset.pwDownload }); const a = document.createElement('a'); a.href = r.url; a.download = r.filename; document.body.append(a); a.click(); a.remove(); }
        catch (x) { notice(`Não foi possível baixar a FPA: ${x.message}`, 'error'); }
        finally { b.disabled = false; }
      }
    };
    container.onsubmit = e => {
      const form = e.target.closest('[data-pw-form]'); if (!form) return;
      e.preventDefault();
      const v = Object.fromEntries(new FormData(form)), kind = form.dataset.pwForm;
      if (kind === 'request') act(() => rpc('audit_fpa', 'request', { ...v, expected_lock_version: fpa.lock_version }), 'Solicitação da FPA registrada.');
      if (kind === 'complement') act(() => rpc('audit_fpa', 'request_complement', { ...v, expected_lock_version: fpa.lock_version }), 'Complementação solicitada.');
      if (kind === 'sufficient') act(() => rpc('audit_fpa', 'mark_sufficient', { note: v.note, version_id: fpa.versions[0]?.id, expected_lock_version: fpa.lock_version }), 'FPA considerada suficiente para planejar.');
      if (kind === 'upload') {
        const file = form.elements.file.files[0];
        if (!file) return notice('Selecione o arquivo recebido.', 'error');
        if (!/\.(pdf|docx|xlsx)$/i.test(file.name)) return notice('Envie PDF, DOCX ou XLSX.', 'error');
        if (file.size > 20 * 1024 * 1024) return notice('Arquivo acima de 20 MB.', 'error');
        const body = new FormData();
        body.append('action', 'upload'); body.append('audit_id', auditId); body.append('expected_lock_version', String(fpa.lock_version));
        body.append('format', file.name.split('.').pop().toLowerCase()); body.append('received_on', v.received_on); body.append('source_note', v.source_note || ''); body.append('file', file);
        act(() => files(body), 'Recebimento registrado. Inicie a análise desta versão.');
      }
    };
    await load();
  }
  window.AuditaPlanWorkspace = { mount };
})();
