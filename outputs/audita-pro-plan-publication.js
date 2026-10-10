/* B09 — Validação e publicação do Plano de Auditoria.
   Mostra as 15 verificações da seção 10 com atalho para a etapa que corrige cada uma, avisos separados dos bloqueios,
   prévia do PDF, validação (Rev.00 ou nova revisão com motivo) e o acompanhamento do PDF gerado no servidor.
   A publicação só acontece com o PDF íntegro; enquanto isso a revisão anterior continua vigente. */
(() => {
  'use strict';
  const esc = v => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const fmt = v => v ? new Intl.DateTimeFormat('pt-BR', { dateStyle: 'short', timeStyle: 'short', timeZone: 'America/Sao_Paulo' }).format(new Date(v)) : '—';
  const STEP = { identification: ['identification', 'Identificação e FPA'], team: ['team', 'Equipe'], schedule: ['schedule', 'Cronograma'], review: [null, 'Recarregar'] };
  const STATE = { published: 'Publicada (vigente)', superseded: 'Substituída', validated: 'Validada — PDF em geração', discarded: 'Descartada', legacy: 'Versão anterior (sem PDF persistido)' };

  async function rpc(client, command, payload) {
    const { data, error } = await client.rpc('audit_plan', { command, payload });
    if (error) throw new Error(error.message || 'Falha de comunicação com o servidor.');
    return data;
  }

  function versionsTable(list, client) {
    if (!list.length) return '<p class="muted">Nenhuma revisão publicada ainda.</p>';
    return `<div class="pp-table-wrap"><table class="pp-table"><caption class="ap-sr-only">Revisões do plano</caption><thead><tr><th scope="col">Revisão</th><th scope="col">Situação</th><th scope="col">Data/hora</th><th scope="col">Responsável</th><th scope="col">Motivo</th><th scope="col">PDF</th></tr></thead><tbody>${list.map(v => {
      const e = v.emission;
      const pdf = e && ['ready', 'published'].includes(e.status) && ['published', 'superseded'].includes(v.state)
        ? `<button type="button" class="button secondary small" data-pp-download="${esc(e.id)}">Baixar PDF</button>`
        : v.state === 'legacy' ? '<span class="muted">Sem PDF persistido</span>' : '<span class="muted">—</span>';
      return `<tr class="pp-${esc(v.state)}"><td data-label="Revisão"><b>${esc(v.revision_label)}</b></td><td data-label="Situação">${esc(STATE[v.state] || v.state)}${v.discarded_reason ? `<div class="muted">${esc(v.discarded_reason)}</div>` : ''}</td><td data-label="Data/hora">${fmt(v.published_at || v.created_at)}</td><td data-label="Responsável">${esc(v.author)}</td><td data-label="Motivo">${esc(v.reason)}</td><td data-label="PDF">${pdf}</td></tr>`;
    }).join('')}</tbody></table></div>`;
  }

  function bindDownloads(root, client, notice) {
    root.querySelectorAll('[data-pp-download]').forEach(b => b.onclick = async () => {
      b.disabled = true;
      try { await window.AuditaEmission.download(client, b.dataset.ppDownload); } catch (e) { notice(`Não foi possível baixar o PDF: ${e.message}`, true); }
      b.disabled = false;
    });
  }

  /** Bloco de revisões publicadas (equipe e cliente autorizado). */
  async function versions(root, { client, auditId }) {
    root.innerHTML = '<p class="muted">Carregando revisões…</p>';
    try {
      const r = await rpc(client, 'versions', { audit_id: auditId });
      const list = (r.versions || []).filter(v => ['published', 'superseded', 'legacy'].includes(v.state));
      root.innerHTML = `<section class="pp-versions"><h2>Plano publicado</h2>${versionsTable(list, client)}<p class="pp-msg" role="status" hidden></p></section>`;
      bindDownloads(root, client, (m, err) => { const n = root.querySelector('.pp-msg'); n.hidden = false; n.textContent = m; n.classList.toggle('error', !!err); });
    } catch (e) {
      root.innerHTML = `<p class="muted">${/indisponível/.test(e.message) ? 'O plano ainda não foi publicado.' : esc(e.message)}</p>`;
    }
  }

  async function mount(root, { client, auditId, onTab }) {
    let opId = null;
    const notice = (m, err) => { const n = root.querySelector('#ppNotice'); if (!n) return; n.hidden = !m; n.textContent = m || ''; n.className = `notice${err ? ' error' : ''}`; };
    async function load(message, isError) {
      root.innerHTML = '<p class="muted">Carregando verificações…</p>';
      const s = await rpc(client, 'status', { audit_id: auditId });
      const open = s.open, e = open?.emission;
      let banner;
      if (open && e && ['pending', 'processing'].includes(e.status)) banner = `<div class="pp-banner busy"><b>Validado — PDF em geração (${esc(open.revision_label)})</b><span>O conteúdo está congelado. A revisão vigente continua disponível até o PDF ficar pronto.</span></div>`;
      else if (open && e && e.status === 'failed') banner = `<div class="pp-banner error"><b>Falha na geração do PDF (${esc(open.revision_label)})</b><span>${esc(e.last_error || 'Erro de processamento')}. Nada foi publicado.</span><span>${s.can_validate ? `<button type="button" class="button" id="ppRetry">Tentar novamente</button> <button type="button" class="button secondary" id="ppDiscard">Descartar revisão</button>` : ''}</span></div>`;
      else if (open && e && e.status === 'ready') banner = `<div class="pp-banner error"><b>PDF íntegro, publicação bloqueada (${esc(open.revision_label)})</b><span>${esc(e.last_error || '')}</span><span>${s.can_validate ? `<button type="button" class="button" id="ppPublish">Publicar novamente</button> <button type="button" class="button secondary" id="ppDiscard">Descartar revisão</button>` : ''}</span></div>`;
      else if (s.plan_revision > 0) banner = `<div class="pp-banner ok"><b>Publicado — ${esc((s.versions.find(v => v.state === 'published') || {}).revision_label || 'versão vigente')}</b><span>Alterações no cronograma ou na identificação geram uma nova revisão, com motivo.</span></div>`;
      else banner = '<div class="pp-banner"><b>Rascunho</b><span>Ainda não disponibilizado ao cliente. Valide para gerar o PDF Rev.00.</span></div>';
      const failing = s.checks.filter(c => !c.ok).length;
      root.innerHTML = `<div class="pp-wrap"><h2>Validação e publicação do plano</h2>${banner}<div id="ppNotice" class="notice" role="status" aria-live="polite" hidden></div>
        <section class="pp-section"><h3>Verificações obrigatórias <span class="badge">${15 - failing} de 15</span></h3><ol class="pp-checks">${s.checks.map(c => `<li class="${c.ok ? 'ok' : 'fail'}"><span class="pp-mark" aria-hidden="true">${c.ok ? '✓' : '✗'}</span><div><b>${c.n}. ${esc(c.label)}</b><span class="ap-sr-only">${c.ok ? 'atendida' : 'pendente'}</span>${c.ok ? '' : `<ul>${c.errors.map(m => `<li>${esc(m)}</li>`).join('')}</ul>${STEP[c.step]?.[0] ? `<button type="button" class="button secondary small" data-pp-step="${esc(STEP[c.step][0])}">Corrigir em ${esc(STEP[c.step][1])}</button>` : '<button type="button" class="button secondary small" data-pp-reload>Recarregar</button>'}`}</div></li>`).join('')}</ol></section>
        <section class="pp-section"><h3>Avisos <span class="muted">(não impedem a validação)</span></h3>${s.warnings.length ? `<ul class="pp-warnings">${s.warnings.map(w => `<li>${esc(w.message)}</li>`).join('')}</ul>` : '<p class="muted">Nenhum aviso.</p>'}</section>
        <section class="pp-section"><h3>Prévia e validação</h3><p class="muted">A prévia mostra o PDF com a marca "PRÉVIA — SEM VALIDADE"; nada é gravado.</p>
          <div class="pp-actions"><button type="button" class="button secondary" id="ppPreview">Prévia do PDF</button></div>
          ${s.can_validate ? `<label class="pp-reason">${s.requires_reason ? 'Motivo da nova revisão (obrigatório)' : 'Motivo (opcional na primeira emissão)'}<textarea id="ppReason" rows="2" maxlength="1000" placeholder="${s.requires_reason ? 'Ex.: transferência de Compras para 04/11 a pedido do cliente' : 'Emissão inicial do plano'}"></textarea></label>
          <div class="pp-actions"><button type="button" class="button" id="ppValidate" ${s.ok && !open ? '' : 'disabled'}>Validar plano e gerar PDF ${esc(s.next_label)}</button>${open ? '<span class="muted">Há uma revisão aguardando o PDF.</span>' : !s.ok ? `<span class="muted">Resolva ${failing} verificação(ões) pendente(s).</span>` : ''}</div>` : '<p class="muted">Somente o condutor ou o Administrador valida o plano.</p>'}
        </section>
        <section class="pp-section"><h3>Revisões</h3>${versionsTable(s.versions, client)}</section></div>`;
      if (message) notice(message, isError);
      root.querySelectorAll('[data-pp-step]').forEach(b => b.onclick = () => onTab?.(b.dataset.ppStep));
      root.querySelectorAll('[data-pp-reload]').forEach(b => b.onclick = () => load());
      bindDownloads(root, client, notice);
      root.querySelector('#ppPreview').onclick = preview;
      const val = root.querySelector('#ppValidate');
      if (val) val.onclick = () => validate(s);
      const retry = root.querySelector('#ppRetry');
      if (retry) retry.onclick = async () => { retry.disabled = true; try { await window.AuditaEmission.call(client, { action: 'retry', emission_id: e.id }); await follow(e.id); } catch (x) { notice(x.message, true); retry.disabled = false; } };
      const pub = root.querySelector('#ppPublish');
      if (pub) pub.onclick = async () => { pub.disabled = true; try { await rpc(client, 'publish_ready', { version_id: open.version_id }); await load('Revisão publicada.'); } catch (x) { notice(x.message, true); pub.disabled = false; } };
      const dis = root.querySelector('#ppDiscard');
      if (dis) dis.onclick = async () => {
        const reason = window.prompt('Motivo do descarte desta revisão (fica no histórico):');
        if (!reason) return;
        try { await rpc(client, 'discard', { version_id: open.version_id, reason }); await load('Revisão descartada. A versão vigente continua disponível.'); } catch (x) { notice(x.message, true); }
      };
      if (open && e && ['pending', 'processing'].includes(e.status)) follow(e.id);
    }
    async function follow(emissionId) {
      try {
        const final = await window.AuditaEmission.watch(client, emissionId, null);
        await load(final.status === 'published' ? `Plano publicado com PDF íntegro (${final.page_count} páginas).` : final.status === 'failed' ? 'A geração do PDF falhou; nada foi publicado.' : undefined, final.status === 'failed');
      } catch (x) { notice(`${x.message} O servidor continuará a emissão.`, true); }
    }
    async function preview() {
      const b = root.querySelector('#ppPreview'); b.disabled = true; b.textContent = 'Gerando prévia…';
      try {
        const { data: { session } } = await client.auth.getSession();
        const res = await fetch(`${window.AUDITA_PRO_SUPABASE_URL}/functions/v1/document-emission`, { method: 'POST',
          headers: { Authorization: `Bearer ${session.access_token}`, apikey: window.AUDITA_PRO_SUPABASE_PUBLISHABLE_KEY, 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'preview_plan', audit_id: auditId }) });
        if (!res.ok) { let m = 'Falha ao gerar a prévia.'; try { m = (await res.json()).error || m; } catch { /* sem corpo */ } throw new Error(m); }
        const url = URL.createObjectURL(await res.blob());
        const a = document.createElement('a'); a.href = url; a.target = '_blank'; a.rel = 'noopener'; a.download = 'previa-plano.pdf'; document.body.append(a); a.click(); a.remove();
        setTimeout(() => URL.revokeObjectURL(url), 60000);
      } catch (x) { notice(x.message, true); }
      b.disabled = false; b.textContent = 'Prévia do PDF';
    }
    async function validate(s) {
      const reason = root.querySelector('#ppReason')?.value.trim() || '';
      if (s.requires_reason && reason.length < 5) { notice('Informe o motivo da nova revisão (mínimo 5 caracteres).', true); root.querySelector('#ppReason').focus(); return; }
      if (!window.confirm(`Validar o plano como ${s.next_label}? O conteúdo será congelado e o PDF gerado no servidor. ${s.plan_revision > 0 ? 'A revisão atual continua vigente até o novo PDF ficar pronto.' : ''}`)) return;
      opId = opId || crypto.randomUUID();
      const b = root.querySelector('#ppValidate'); b.disabled = true; b.textContent = 'Validando…';
      try {
        const r = await rpc(client, 'validate', { audit_id: auditId, operation_id: opId, expected_lock_version: s.lock_version, reason });
        opId = null;
        await load(`${r.revision_label} validada. Gerando o PDF no servidor…`);
      } catch (x) { b.disabled = false; b.textContent = `Validar plano e gerar PDF ${s.next_label}`; notice(x.message, true); }
    }
    await load();
  }
  window.AuditaPlanPublication = { mount, versions };
})();
