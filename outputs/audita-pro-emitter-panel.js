/* B08 — Painel do Administrador: documento de prova do emissor (identidade provisória D08, paginação, tabelas,
   imagens e gráficos). Permite conferir o PDF gerado no servidor antes do uso em Plano (B09) e RDA (B12). */
(() => {
  'use strict';
  const esc = v => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const fmtDateTime = v => v ? new Intl.DateTimeFormat('pt-BR', { dateStyle: 'short', timeStyle: 'short' }).format(new Date(v)) : '—';
  const fmtSize = n => !n ? '—' : n >= 1048576 ? `${(n / 1048576).toFixed(1).replace('.', ',')} MB` : `${Math.max(1, Math.round(n / 1024))} KB`;

  function mount(client, root) {
    const E = window.AuditaEmission;
    root.innerHTML = `<div class="workspace-card lib-card em-card">
      <h2>Documento de prova do emissor</h2>
      <p class="lib-sub">Gera no servidor um PDF sintético com cabeçalho e rodapé repetidos, "Página X de Y", tabela extensa com célula maior que uma página,
      imagens, gráficos com valores em texto, seção vazia explicada e notas finais. Serve para conferir a identidade visual provisória (D08) e a impressão,
      antes da emissão de Planos e RDAs. Não contém dados de clientes.</p>
      <form id="emForm" class="em-form">
        <label>Tamanho<select id="emRows"><option value="120">Representativo (~12 páginas)</option><option value="900">Extenso (~48 páginas)</option><option value="2000">Máximo (~98 páginas)</option></select></label>
        <label class="em-check"><input type="checkbox" id="emDraft"> Marcar como prévia</label>
        <button type="submit" class="lib-btn" id="emGo">Gerar documento de prova</button>
      </form>
      <div id="emNotice" class="notice" role="status" aria-live="polite" hidden></div>
      <div id="emList"><p class="lib-state">Carregando…</p></div></div>`;
    const notice = (m, kind) => { const n = root.querySelector('#emNotice'); n.hidden = !m; n.textContent = m || ''; n.className = `notice${kind === 'error' ? ' error' : ''}`; };
    async function refresh() {
      const box = root.querySelector('#emList');
      try {
        const items = await E.list(client);
        if (!items.length) { box.innerHTML = '<p class="lib-state">Nenhum documento de prova gerado ainda.</p>'; return; }
        box.innerHTML = `<div class="lib-table-wrap"><table class="lib-table"><caption class="ap-sr-only">Documentos de prova emitidos</caption><thead><tr><th scope="col">Documento</th><th scope="col">Situação</th><th scope="col">Páginas</th><th scope="col">Tamanho</th><th scope="col">Integridade (SHA-256)</th><th scope="col">Ação</th></tr></thead><tbody>${items.map(x => `<tr>
          <td data-label="Documento"><div class="lib-title">${esc(x.title)}</div><div class="lib-sub">Pedido em ${fmtDateTime(x.requested_at)} · ${esc(x.template)}${x.engine_version ? ` · ${esc(x.engine_version)}` : ''}</div></td>
          <td data-label="Situação"><span class="lib-badge ${x.status === 'published' ? 'vigente' : x.status === 'failed' ? 'cancelado' : 'rascunho'}">${esc(E.label(x.status))}</span>${x.last_error ? `<div class="lib-sub">${esc(x.last_error)}</div>` : ''}</td>
          <td data-label="Páginas">${x.page_count ?? '—'}</td><td data-label="Tamanho">${fmtSize(x.size_bytes)}</td>
          <td data-label="Integridade"><code class="em-hash" title="${esc(x.pdf_sha256 || '')}">${x.pdf_sha256 ? esc(x.pdf_sha256.slice(0, 16)) + '…' : '—'}</code></td>
          <td data-label="Ação">${['ready', 'published'].includes(x.status) ? `<button type="button" class="lib-btn secondary small" data-down="${esc(x.id)}">Baixar PDF</button>`
            : x.status === 'failed' ? `<button type="button" class="lib-btn secondary small" data-retry="${esc(x.id)}">Tentar novamente</button>` : '<span class="lib-sub">Aguarde…</span>'}</td></tr>`).join('')}</tbody></table></div>`;
      } catch (e) { box.innerHTML = `<div class="lib-state error" role="alert"><strong>Não foi possível listar</strong>${esc(e.message)}</div>`; }
    }
    root.addEventListener('click', async ev => {
      const down = ev.target.closest('[data-down]'), retry = ev.target.closest('[data-retry]');
      if (down) {
        down.disabled = true;
        try { await E.download(client, down.dataset.down); } catch (e) { notice(`Não foi possível baixar: ${e.message}`, 'error'); }
        down.disabled = false;
      }
      if (retry) {
        retry.disabled = true; notice('Retomando a emissão…');
        try { await E.call(client, { action: 'retry', emission_id: retry.dataset.retry }); notice('Emissão retomada.'); } catch (e) { notice(e.message, 'error'); }
        await refresh();
      }
    });
    root.querySelector('#emForm').addEventListener('submit', async ev => {
      ev.preventDefault();
      const go = root.querySelector('#emGo'); go.disabled = true; notice('Gerando no servidor…');
      try {
        const r = await E.call(client, { action: 'request_specimen', operation_id: crypto.randomUUID(),
          params: { rows: Number(root.querySelector('#emRows').value), draft: root.querySelector('#emDraft').checked } });
        const s = r.emission || {};
        notice(s.status === 'published' ? `Documento emitido: ${s.page_count} páginas, conferido no servidor.` : r.error ? `A emissão falhou: ${r.error}` : `Situação: ${E.label(s.status)}.`, r.error ? 'error' : 'ok');
      } catch (e) { notice(e.message, 'error'); }
      go.disabled = false; await refresh();
    });
    refresh();
  }
  window.AuditaEmitterPanel = { mount };
})();
