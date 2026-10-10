/* B07 — Editor do cronograma (rascunho do Plano de Auditoria) e registro de continuidade.
   Contrato: public.audit_schedule (draft/save/record_outcome). O servidor normaliza horários no fuso da
   auditoria, valida e devolve erros (bloqueiam a validação do plano) e avisos (revisão). Publicação: B09. */
(() => {
  'use strict';
  const esc = v => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const CAT = { assessment: 'Avaliação', opening: 'Reunião de abertura', closing: 'Reunião de encerramento', meeting: 'Reunião', break: 'Intervalo', other: 'Outra atividade' };
  const OUT = { partial: 'Parcial', not_performed: 'Não realizada', completed: 'Concluída', rescheduled: 'Reprogramada' };
  const day = v => v ? new Date(v + 'T12:00:00').toLocaleDateString('pt-BR', { weekday: 'short', day: '2-digit', month: '2-digit' }) : '—';
  const hm = v => v ? new Date(v).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) : '—';
  const uuid = () => crypto.randomUUID();
  const toMin = t => t ? Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5)) : null;
  const toHm = m => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;

  async function mount(container, { client, auditId }) {
    let data, rows = [], issues = [], dirty = false, busy = false;
    const rpc = async (command, payload = {}) => {
      const r = await client.rpc('audit_schedule', { command, payload: { audit_id: auditId, ...payload } });
      if (r.error) throw Object.assign(new Error(r.error.message), { code: r.error.code });
      return r.data;
    };
    const say = (msg, kind = 'ok') => { const n = container.querySelector('#seNotice'); if (n) { n.hidden = !msg; n.className = `notice ${kind === 'error' ? 'error' : kind === 'warn' ? 'warn' : ''}`; n.innerHTML = msg || ''; } };
    window.addEventListener('beforeunload', e => { if (dirty) { e.preventDefault(); e.returnValue = ''; } });

    async function load(message) {
      container.innerHTML = '<p class="muted">Carregando cronograma…</p>';
      try { data = await rpc('draft'); }
      catch (e) { container.innerHTML = `<div class="notice error" role="alert">Não foi possível carregar o cronograma: ${esc(e.message)} <button type="button" class="button secondary" data-se="reload">Tentar novamente</button></div>`; return; }
      rows = data.items.map(r => ({ ...r })); issues = data.issues; dirty = false;
      render(); if (message) say(message);
    }
    const rowIssues = key => issues.filter(i => i.key === key);
    const teamName = id => data.team.find(t => t.membership_id === id)?.name || 'Fora da equipe';
    const reqLabel = id => { const q = data.requirements.find(x => x.id === id); return q ? `${q.criterion ? q.criterion + ' · ' : ''}${q.reference}` : 'Requisito fora do checklist'; };

    function rowHtml(r, n) {
      const own = rowIssues(r.key), errs = own.filter(i => i.level === 'error'), warns = own.filter(i => i.level === 'warning');
      const ro = !data.can_edit;
      const field = (name, label, value, attrs = '') => `<label class="field">${label}<input data-f="${name}" value="${esc(value ?? '')}" ${attrs} ${ro ? 'disabled' : ''}></label>`;
      const reqGroups = {};
      for (const q of data.requirements) (reqGroups[q.criterion || 'Checklist'] ||= []).push(q);
      const reqs = data.requirements.length ? Object.entries(reqGroups).map(([g, qs]) => `<fieldset class="se-reqs"><legend>${esc(g)}</legend>${qs.map(q => `<label><input type="checkbox" data-req="${esc(q.id)}" ${r.requirements.includes(q.id) ? 'checked' : ''} ${ro ? 'disabled' : ''}> ${esc(q.reference)} <span class="muted">${esc(q.section || '')}</span></label>`).join('')}</fieldset>`).join('')
        : '<p class="muted">Confirme os checklists da auditoria para vincular requisitos.</p>';
      const published = r.id ? data.published.find(p => p.id === r.id) : null;
      return `<article class="se-row ${errs.length ? 'has-error' : ''}" data-key="${esc(r.key)}" aria-labelledby="se-t-${n}">
        <header class="se-row-head"><h3 id="se-t-${n}">${n + 1}. ${esc(r.title || 'Nova atividade')}</h3>
          <span class="se-tags">${r.id ? `<span class="badge">Publicada${published?.status === 'completed' ? ' · concluída' : ''}</span>` : '<span class="badge pending">Nova</span>'}${r.continuation_of ? '<span class="badge">Trabalho restante</span>' : ''}</span>
          ${ro ? '' : `<span class="se-actions" role="group" aria-label="Ações da linha ${n + 1}">
            <button type="button" class="button secondary small" data-act="up" ${n === 0 ? 'disabled' : ''} aria-label="Subir linha ${n + 1}">↑ Subir</button>
            <button type="button" class="button secondary small" data-act="down" ${n === rows.length - 1 ? 'disabled' : ''} aria-label="Descer linha ${n + 1}">↓ Descer</button>
            <button type="button" class="button secondary small" data-act="dup">Duplicar</button>
            <button type="button" class="button secondary small" data-act="next">Copiar p/ próximo horário</button>
            <button type="button" class="button secondary small" data-act="otherday">Copiar p/ outro dia</button>
            <button type="button" class="button danger small" data-act="remove">${r.id ? 'Retirar' : 'Remover'}</button></span>`}
        </header>
        ${r.continuation_of ? `<p class="hint">Continuação de “${esc(data.published.find(p => p.id === r.continuation_of)?.title || 'atividade publicada')}”. Restante: ${esc(r.remaining_summary || '—')}</p>` : ''}
        <div class="se-grid">${field('location', 'Localização *', r.location, 'maxlength="300"')}${field('date', 'Data *', r.date, 'type="date"')}
          ${field('start_time', 'Início *', r.start_time, 'type="time"')}${field('end_time', 'Término *', r.end_time, 'type="time"')}
          ${field('title', 'Área / Departamento / Processo / Atividade *', r.title, 'maxlength="300"')}
          <label class="field">Categoria<select data-f="category" ${ro ? 'disabled' : ''}>${Object.entries(CAT).map(([v, t]) => `<option value="${v}" ${r.category === v ? 'selected' : ''}>${t}</option>`).join('')}</select></label>
          ${r.category === 'assessment' ? field('process', 'Processo *', r.process, 'maxlength="200"') : ''}</div>
        <fieldset class="se-team"><legend>Auditor(es) *</legend>${data.team.map(t => `<label><input type="checkbox" data-assignee="${esc(t.membership_id)}" ${r.assignee_ids.includes(t.membership_id) ? 'checked' : ''} ${ro ? 'disabled' : ''}> ${esc(t.name)}${t.conductor ? ' (condutor)' : ''}</label>`).join('')}
          ${r.assignee_ids.filter(id => !data.team.some(t => t.membership_id === id)).map(id => `<span class="badge inactive">${esc(teamName(id))}</span>`).join('')}</fieldset>
        <details class="se-detail" ${r.category === 'assessment' && !r.requirements.length ? 'open' : ''}><summary>Requisitos (${r.requirements.length}) e observações</summary>
          ${r.category === 'assessment' ? reqs : '<p class="muted">Reuniões e intervalos não exigem requisito.</p>'}
          <label class="field">Observações<textarea data-f="notes" maxlength="2000" ${ro ? 'disabled' : ''}>${esc(r.notes || '')}</textarea></label></details>
        ${errs.length || warns.length ? `<ul class="se-issues">${errs.map(i => `<li class="error">⛔ ${esc(i.message)}</li>`).join('')}${warns.map(i => `<li class="warning">⚠ ${esc(i.message)}</li>`).join('')}</ul>` : ''}
      </article>`;
    }
    function publishedHtml() {
      const live = data.published.filter(p => !p.withdrawn);
      if (!live.length) return '';
      return `<section class="identification-summary se-published" aria-labelledby="sePubTitle"><h2 id="sePubTitle">Execução das atividades publicadas</h2>
        <p class="hint">Registre aqui atividades parciais ou não realizadas. O trabalho restante é transferido como nova atividade do rascunho e passa a valer na próxima publicação do plano.</p>
        <div class="se-table-wrap"><table class="data-table"><thead><tr><th>Dia</th><th>Atividade</th><th>Previsto / real</th><th>Situação</th><th></th></tr></thead><tbody>
        ${live.map(p => { const transferred = rows.some(r => r.continuation_of === p.id) || (p.continued_by || []).length; return `<tr><td>Dia ${esc(p.day_number)} · ${day(p.date)}</td><td><strong>${esc(p.title)}</strong><span class="cell-sub">${esc(p.location || '')}</span>${p.continuation_of ? '<span class="cell-sub">Continuação de atividade anterior</span>' : ''}</td>
          <td>${hm(p.planned_start)}–${hm(p.planned_end)}${p.actual_start ? `<span class="cell-sub">Real: ${hm(p.actual_start)}${p.actual_end ? '–' + hm(p.actual_end) : ''}</span>` : ''}</td>
          <td>${p.outcome ? `<span class="badge pending">${esc(OUT[p.outcome])}</span>${p.performed_summary ? `<span class="cell-sub">Realizado: ${esc(p.performed_summary)}</span>` : ''}${p.remaining_summary ? `<span class="cell-sub">Restante: ${esc(p.remaining_summary)}</span>` : ''}${p.outcome_note ? `<span class="cell-sub">${esc(p.outcome_note)}</span>` : ''}` : esc({ planned: 'Planejada', in_progress: 'Em execução', completed: 'Concluída', not_done: 'Não realizada' }[p.status] || p.status)}</td>
          <td>${data.can_edit && p.day_status !== 'completed' && p.status !== 'completed' && !p.outcome ? `<button type="button" class="button secondary small" data-outcome="${esc(p.id)}">Registrar parcial / não realizada</button>` : ''}
            ${data.can_edit && ['partial', 'not_performed'].includes(p.outcome) && !transferred ? `<button type="button" class="button small" data-transfer="${esc(p.id)}">Transferir restante</button>` : ''}${transferred ? '<span class="cell-sub">Restante já encaminhado</span>' : ''}</td></tr>`; }).join('')}
        </tbody></table></div></section>`;
    }
    function render() {
      const errs = issues.filter(i => i.level === 'error'), warns = issues.filter(i => i.level === 'warning'), planErr = issues.filter(i => !i.key);
      container.innerHTML = `<section class="identification-summary se-editor" aria-labelledby="seTitle">
        <div class="pw-heading"><div><span class="eyebrow">PLANO DE AUDITORIA · ETAPA 3</span><h2 id="seTitle">Cronograma</h2>
          <p class="muted">Período declarado: ${data.declared_start_date ? `${day(data.declared_start_date)} a ${day(data.declared_end_date)}` : '<strong>não definido</strong> (Identificação)'} · Horários no fuso ${esc(data.timezone)}</p></div>
          ${data.can_edit ? '<span><button type="button" class="button secondary" data-se="add">+ Adicionar atividade</button> <button type="button" class="button" data-se="save">Salvar rascunho</button></span>' : ''}</div>
        <div id="seNotice" class="notice" role="status" aria-live="polite" hidden></div>
        <p class="se-summary" aria-live="polite"><strong>${rows.length}</strong> atividade(s) · <span class="${errs.length ? 'se-err' : 'se-ok'}">${errs.length} pendência(s) que impedem validar</span> · <span class="${warns.length ? 'se-warn' : ''}">${warns.length} aviso(s)</span>${dirty ? ' · <strong class="se-warn">alterações não salvas</strong>' : ''}</p>
        ${planErr.length ? `<ul class="se-issues">${planErr.map(i => `<li class="error">⛔ ${esc(i.message)}</li>`).join('')}</ul>` : ''}
        <p class="hint">A publicação do cronograma acontece na etapa “Prévia e validação” do plano, com motivo e nova revisão. Dias são criados somente para as datas efetivamente planejadas.</p>
        <div class="se-rows">${rows.map(rowHtml).join('') || '<p class="muted">Nenhuma atividade no rascunho.</p>'}</div></section>${publishedHtml()}`;
    }
    function mark() { dirty = true; const s = container.querySelector('.se-summary'); if (s && !s.innerHTML.includes('não salvas')) s.insertAdjacentHTML('beforeend', ' · <strong class="se-warn">alterações não salvas</strong>'); }
    const blank = () => { const last = rows[rows.length - 1]; return { key: uuid(), id: null, continuation_of: null, title: '', process: null, category: 'assessment',
      date: last?.date || data.declared_start_date || null, start_time: last?.end_time || '08:00', end_time: last?.end_time ? toHm(Math.min(toMin(last.end_time) + 60, 23 * 60 + 59)) : '09:00',
      location: last?.location || data.location || '', assignee_ids: last?.assignee_ids?.slice() || [], requirements: [], notes: null }; };
    const copyOf = r => ({ ...r, key: uuid(), id: null, continuation_of: null, remaining_summary: null, requirements: r.requirements.slice(), assignee_ids: r.assignee_ids.slice() });
    function action(act, idx) {
      const r = rows[idx];
      if (act === 'up' && idx > 0) [rows[idx - 1], rows[idx]] = [rows[idx], rows[idx - 1]];
      else if (act === 'down' && idx < rows.length - 1) [rows[idx + 1], rows[idx]] = [rows[idx], rows[idx + 1]];
      else if (act === 'dup') rows.splice(idx + 1, 0, copyOf(r));
      else if (act === 'next') {
        const dur = toMin(r.end_time) - toMin(r.start_time), start = toMin(r.end_time);
        if (start == null || !(dur > 0)) return say('Defina início e término válidos antes de copiar para o próximo horário.', 'error');
        if (start + dur > 24 * 60) return say('A cópia atravessaria a meia-noite. Use “Copiar p/ outro dia” e ajuste os horários.', 'error');
        rows.splice(idx + 1, 0, { ...copyOf(r), start_time: toHm(start), end_time: toHm(Math.min(start + dur, 23 * 60 + 59)) });
      } else if (act === 'otherday') return otherDay(idx);
      else if (act === 'remove') {
        if (r.id && !confirm('Retirar esta atividade publicada? A retirada vale na próxima revisão publicada; registros e avaliações são preservados.')) return;
        rows.splice(idx, 1);
      }
      dirty = true; render();
    }
    function otherDay(idx) {
      const r = rows[idx], dates = [...new Set(rows.map(x => x.date).filter(Boolean))].sort();
      const next = dates.find(d => d > (r.date || '')) || '';
      const dlg = document.createElement('dialog'); dlg.className = 'audit-dialog se-dialog';
      dlg.innerHTML = `<form><div class="dialog-header"><h2>Copiar para outro dia</h2><button type="button" class="icon-button" data-close aria-label="Fechar">×</button></div>
        <p class="hint">A cópia é uma nova atividade, sem execução, presença ou evidências. Não se presume o dia corrido seguinte.</p>
        <label class="field">Data de destino *<input type="date" name="date" required value="${esc(next)}" ${data.declared_start_date ? `min="${esc(data.declared_start_date)}" max="${esc(data.declared_end_date)}"` : ''}></label>
        ${dates.length ? `<p class="muted">Dias já planejados: ${dates.map(d => `<button type="button" class="button secondary small" data-pick="${esc(d)}">${day(d)}</button>`).join(' ')}</p>` : ''}
        <div class="dialog-actions"><button type="button" class="button secondary" data-close>Cancelar</button><button class="button">Copiar</button></div></form>`;
      document.body.append(dlg); dlg.showModal();
      dlg.querySelectorAll('[data-close]').forEach(b => b.onclick = () => dlg.remove());
      dlg.querySelectorAll('[data-pick]').forEach(b => b.onclick = () => { dlg.querySelector('[name=date]').value = b.dataset.pick; });
      dlg.querySelector('form').onsubmit = e => { e.preventDefault(); const d = dlg.querySelector('[name=date]').value; if (!d) return; rows.splice(idx + 1, 0, { ...copyOf(r), date: d }); dlg.remove(); dirty = true; render(); };
    }
    async function save() {
      if (busy) return; busy = true;
      const btn = container.querySelector('[data-se=save]'); if (btn) { btn.disabled = true; btn.textContent = 'Salvando…'; }
      try {
        const r = await rpc('save', { expected_lock_version: data.lock_version, operation_id: uuid(), items: rows });
        data.lock_version = r.lock_version; rows = r.items.map(x => ({ ...x })); issues = r.issues; dirty = false; render();
        const e = issues.filter(i => i.level === 'error').length;
        say(e ? `Rascunho salvo. Ainda há ${e} pendência(s) que impedem a validação do plano.` : 'Rascunho salvo, sem pendências no cronograma.', e ? 'warn' : 'ok');
      } catch (x) {
        render();
        say(x.code === '40001' ? `Outra sessão alterou o cronograma. Suas alterações locais foram mantidas nesta tela e <strong>não foram salvas</strong>. <button type="button" class="button secondary small" data-se="reload">Recarregar a versão atual (descarta as alterações locais)</button>` : `Não foi possível salvar: ${esc(x.message)}`, 'error');
      } finally { busy = false; }
    }
    async function outcomeDialog(id) {
      const p = data.published.find(x => x.id === id);
      const dlg = document.createElement('dialog'); dlg.className = 'audit-dialog se-dialog';
      dlg.innerHTML = `<form><div class="dialog-header"><h2>Registrar execução: ${esc(p.title)}</h2><button type="button" class="icon-button" data-close aria-label="Fechar">×</button></div><p class="error-text" role="alert" id="seOutErr"></p>
        <fieldset class="se-team"><legend>Situação *</legend><label><input type="radio" name="outcome" value="partial" checked> Executada parcialmente</label><label><input type="radio" name="outcome" value="not_performed"> Não realizada</label></fieldset>
        <label class="field">Parcela realizada<textarea name="performed_summary" maxlength="2000"></textarea></label>
        <label class="field">Trabalho restante<textarea name="remaining_summary" maxlength="2000"></textarea></label>
        <label class="field">Motivo e encaminhamento<textarea name="outcome_note" maxlength="2000"></textarea></label>
        <div class="dialog-actions"><button type="button" class="button secondary" data-close>Cancelar</button><button class="button">Registrar</button></div></form>`;
      document.body.append(dlg); dlg.showModal();
      dlg.querySelectorAll('[data-close]').forEach(b => b.onclick = () => dlg.remove());
      dlg.querySelector('form').onsubmit = async e => {
        e.preventDefault(); const v = Object.fromEntries(new FormData(e.target)); const b = e.target.querySelector('button:not([type=button])'); b.disabled = true;
        try { const r = await rpc('record_outcome', { ...v, schedule_id: id, expected_lock_version: data.lock_version, operation_id: uuid() }); data.lock_version = r.lock_version; data.published = r.published; dlg.remove(); render(); say('Execução registrada no histórico da atividade.'); }
        catch (x) { dlg.querySelector('#seOutErr').textContent = x.code === '40001' ? 'O cronograma mudou em outra sessão. Feche e recarregue.' : x.message; b.disabled = false; }
      };
    }
    function transfer(id) {
      const p = data.published.find(x => x.id === id);
      rows.push({ key: uuid(), id: null, continuation_of: p.id, remaining_summary: p.remaining_summary || p.outcome_note || '', title: `${p.title} (restante)`, process: p.process,
        category: p.category, date: null, start_time: null, end_time: null, location: p.location || '', assignee_ids: (p.assignee_ids || []).slice(), requirements: (p.requirements || []).slice(), notes: null });
      dirty = true; render(); say('Trabalho restante incluído no rascunho como nova atividade vinculada à origem. Defina data e horários e salve.', 'warn');
      container.querySelector(`[data-key="${rows[rows.length - 1].key}"] [data-f=date]`)?.focus();
    }
    container.addEventListener('click', e => {
      const b = e.target.closest('button'); if (!b) return;
      if (b.dataset.se === 'reload') return load();
      if (b.dataset.se === 'add') { rows.push(blank()); dirty = true; render(); container.querySelector(`[data-key="${rows[rows.length - 1].key}"] [data-f=title]`)?.focus(); return; }
      if (b.dataset.se === 'save') return save();
      if (b.dataset.outcome) return outcomeDialog(b.dataset.outcome);
      if (b.dataset.transfer) return transfer(b.dataset.transfer);
      const card = b.closest('[data-key]'); if (card && b.dataset.act) action(b.dataset.act, rows.findIndex(r => r.key === card.dataset.key));
    });
    container.addEventListener('change', e => {
      const card = e.target.closest('[data-key]'); if (!card) return;
      const r = rows.find(x => x.key === card.dataset.key), t = e.target;
      if (t.dataset.f) { r[t.dataset.f] = t.value || null; if (t.dataset.f === 'title' && !r.title) r.title = ''; if (t.dataset.f === 'category') { render(); dirty = true; return; } }
      if (t.dataset.assignee) r.assignee_ids = t.checked ? [...new Set([...r.assignee_ids, t.dataset.assignee])] : r.assignee_ids.filter(x => x !== t.dataset.assignee);
      if (t.dataset.req) r.requirements = t.checked ? [...new Set([...r.requirements, t.dataset.req])] : r.requirements.filter(x => x !== t.dataset.req);
      mark();
    });
    await load();
  }
  window.AuditaScheduleEditor = { mount };
})();
