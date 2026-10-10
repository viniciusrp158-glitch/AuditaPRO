/* B05 — Biblioteca de documentos corporativos.
   A interface só apresenta o que o servidor autoriza: public.corporate_library (B02/D07) e a
   Edge Function corporate-library-files decidem leitura, download e gestão. */
(() => {
  'use strict';
  const TYPES = { procedimento: 'Procedimento', modelo: 'Modelo', formulario: 'Formulário', instrucao: 'Instrução', politica: 'Política', registro: 'Registro', outro: 'Outro' };
  const STATUS = { vigente: 'Vigente', rascunho: 'Rascunho', arquivado: 'Arquivado', cancelado: 'Cancelado' };
  const REV = { current: 'Vigente', draft: 'Rascunho', superseded: 'Substituído', cancelled: 'Cancelado' };
  const EVENTS = {
    corporate_document_created: 'Documento cadastrado', corporate_revision_created: 'Nova revisão criada',
    corporate_document_updated: 'Identificação alterada', corporate_revision_updated: 'Dados da revisão alterados',
    corporate_file_added: 'Arquivo incluído', corporate_file_removed: 'Arquivo removido do rascunho',
    corporate_revision_published: 'Revisão disponibilizada como vigente', corporate_revision_cancelled: 'Rascunho cancelado',
    corporate_document_archived: 'Documento arquivado', corporate_document_restored: 'Documento restaurado',
  };
  const MAX = 20 * 1024 * 1024;
  const esc = v => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const $ = s => document.querySelector(s);
  const fmtDate = v => v ? new Intl.DateTimeFormat('pt-BR', { timeZone: 'UTC' }).format(new Date(v + (String(v).length === 10 ? 'T00:00:00Z' : ''))) : '—';
  const fmtDateTime = v => v ? new Intl.DateTimeFormat('pt-BR', { dateStyle: 'short', timeStyle: 'short' }).format(new Date(v)) : '—';
  const fmtSize = n => n >= 1048576 ? `${(n / 1048576).toFixed(1).replace('.', ',')} MB` : `${Math.max(1, Math.round(n / 1024))} KB`;
  const uuid = () => crypto.randomUUID();
  let auth, ctx, seq = 0, reportsLoaded = false;
  const filters = { search: '', doc_type: '', status: '', page: 0 };

  async function rpc(command, payload = {}) {
    const { data, error } = await auth.client.rpc('corporate_library', { command, payload });
    if (error) throw new Error(error.message || 'Falha de comunicação com o servidor.');
    return data;
  }
  async function files(body) {
    const { data: { session } } = await auth.client.auth.getSession();
    if (!session) throw new Error('Sessão encerrada. Entre novamente.');
    const form = body instanceof FormData;
    let response;
    try {
      response = await fetch(`${window.AUDITA_PRO_SUPABASE_URL}/functions/v1/corporate-library-files`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${session.access_token}`, apikey: window.AUDITA_PRO_SUPABASE_PUBLISHABLE_KEY, ...(form ? {} : { 'Content-Type': 'application/json' }) },
        body: form ? body : JSON.stringify(body),
      });
    } catch { throw new Error('Sem conexão com o serviço de arquivos. Verifique a internet e tente novamente.'); }
    let data = {};
    try { data = await response.json(); } catch { /* resposta sem corpo */ }
    if (!response.ok) throw new Error(data.error || 'O serviço de arquivos não respondeu corretamente.');
    return data;
  }
  function notice(message, kind = 'ok') {
    const n = $('#libNotice');
    n.hidden = !message; n.textContent = message || ''; n.className = `notice${kind === 'error' ? ' error' : ''}`;
    if (message) n.scrollIntoView({ block: 'nearest' });
  }

  async function download(fileId, button) {
    const label = button.textContent; button.disabled = true; button.textContent = 'Preparando…';
    try {
      const result = await files({ action: 'download', file_id: fileId });
      const a = document.createElement('a'); a.href = result.url; a.download = result.filename; a.rel = 'noopener';
      document.body.append(a); a.click(); a.remove();
    } catch (e) { notice(`Não foi possível baixar o arquivo: ${e.message}`, 'error'); }
    finally { button.disabled = false; button.textContent = label; }
  }

  // ---------- Listagem ----------
  function toolbar() {
    const types = Object.entries(TYPES).map(([v, t]) => `<option value="${v}" ${filters.doc_type === v ? 'selected' : ''}>${t}</option>`).join('');
    const statuses = ctx.can_manage ? `<label>Situação<select id="libStatus"><option value="">Todas</option>${Object.entries(STATUS).map(([v, t]) => `<option value="${v}" ${filters.status === v ? 'selected' : ''}>${t}</option>`).join('')}</select></label>` : '';
    return `<form class="lib-toolbar" id="libFilters" role="search"><label class="grow">Buscar por título ou código<input id="libSearch" type="search" maxlength="100" value="${esc(filters.search)}" placeholder="Ex.: Procedimento ou PDA-001"></label><label>Tipo<select id="libType"><option value="">Todos</option>${types}</select></label>${statuses}<button class="lib-btn secondary" type="submit">Pesquisar</button></form>`;
  }
  function row(d) {
    const cur = d.current;
    const formats = cur?.files?.length ? `<div class="lib-formats">${cur.files.map(f => `<button type="button" class="lib-btn secondary small" data-download="${esc(f.id)}" title="${esc(f.filename)} · ${fmtSize(f.size_bytes)}">⭳ ${esc(f.format.toUpperCase())}</button>`).join('')}</div>` : '<span class="lib-sub">Sem revisão vigente</span>';
    const draftNote = ctx.can_manage && d.draft ? `<div class="lib-sub">Rascunho em preparação: ${esc(d.draft.revision_label)}</div>` : '';
    return `<tr><td data-label="Código">${esc(d.code || '—')}</td><td data-label="Documento"><div class="lib-title">${esc(d.title)}</div>${d.description ? `<div class="lib-sub">${esc(d.description)}</div>` : ''}</td><td data-label="Tipo">${esc(TYPES[d.doc_type] || d.doc_type)}</td><td data-label="Revisão vigente">${cur ? `${esc(cur.revision_label)}<div class="lib-sub">Emissão ${fmtDate(cur.issued_on)} · ${esc(cur.responsible)}</div>` : '—'}${draftNote}</td><td data-label="Situação"><span class="lib-badge ${esc(d.status)}">${esc(STATUS[d.status] || d.status)}</span></td><td data-label="Baixar">${formats}</td>${ctx.can_manage ? `<td data-label="Gestão"><button type="button" class="lib-btn secondary small" data-manage="${esc(d.id)}">Gerenciar</button></td>` : ''}</tr>`;
  }
  async function loadList() {
    const panel = $('#corporatePanel'); const mine = ++seq;
    const filtered = Boolean(filters.search || filters.doc_type || filters.status);
    panel.innerHTML = `${toolbar()}<p class="lib-state" role="status">Carregando documentos…</p>`;
    bindToolbar();
    let data;
    try { data = await rpc('list', { search: filters.search, doc_type: filters.doc_type, status: filters.status, page: filters.page, page_size: 20 }); }
    catch (e) {
      if (mine !== seq) return;
      panel.querySelector('.lib-state').outerHTML = `<div class="lib-state error" role="alert"><strong>Não foi possível carregar a biblioteca</strong>${esc(e.message)}<br><br><button type="button" class="lib-btn secondary" id="libRetry">Tentar novamente</button></div>`;
      $('#libRetry').onclick = loadList; return;
    }
    if (mine !== seq) return;
    const state = panel.querySelector('.lib-state');
    if (!data.items.length) {
      state.outerHTML = filtered
        ? `<div class="lib-state" role="status"><strong>Nenhum documento encontrado</strong>Nenhum documento corresponde à busca ou aos filtros escolhidos.<br><br><button type="button" class="lib-btn secondary" id="libClear">Limpar filtros</button></div>`
        : `<div class="lib-state" role="status"><strong>A biblioteca ainda não tem documentos ${ctx.can_manage ? 'cadastrados' : 'disponíveis'}</strong>${ctx.can_manage ? 'Use “Inserir documento” para cadastrar o primeiro documento. Ele fica em Rascunho até ser disponibilizado.' : 'Quando a AUDITA disponibilizar documentos vigentes, eles aparecerão aqui.'}</div>`;
      $('#libClear')?.addEventListener('click', () => { Object.assign(filters, { search: '', doc_type: '', status: '', page: 0 }); loadList(); });
      return;
    }
    const pages = Math.ceil(data.total / data.page_size);
    state.outerHTML = `<div class="lib-table-wrap"><table class="lib-table"><caption class="ap-sr-only">Documentos corporativos</caption><thead><tr><th scope="col">Código</th><th scope="col">Documento</th><th scope="col">Tipo</th><th scope="col">Revisão vigente</th><th scope="col">Situação</th><th scope="col">Baixar</th>${ctx.can_manage ? '<th scope="col">Gestão</th>' : ''}</tr></thead><tbody>${data.items.map(row).join('')}</tbody></table></div><div class="lib-pager"><span>${data.total} documento(s) · Página ${data.page + 1} de ${pages}</span><span><button type="button" class="lib-btn secondary small" data-page="-1" ${data.page ? '' : 'disabled'}>Anterior</button> <button type="button" class="lib-btn secondary small" data-page="1" ${data.page + 1 < pages ? '' : 'disabled'}>Próxima</button></span></div>`;
    panel.onclick = e => {
      const b = e.target.closest('button'); if (!b) return;
      if (b.dataset.download) download(b.dataset.download, b);
      else if (b.dataset.manage) manage(b.dataset.manage);
      else if (b.dataset.page) { filters.page = Math.max(0, filters.page + Number(b.dataset.page)); loadList(); }
    };
  }
  function bindToolbar() {
    $('#libFilters').onsubmit = e => {
      e.preventDefault();
      filters.search = $('#libSearch').value.trim(); filters.doc_type = $('#libType').value;
      filters.status = $('#libStatus')?.value || ''; filters.page = 0; loadList();
    };
  }

  // ---------- Diálogo ----------
  function openDialog(html, onSubmit) {
    const dialog = $('#libDialog'), form = $('#libDialogForm');
    form.innerHTML = html;
    form.onsubmit = async e => {
      const submitter = e.submitter;
      if (!submitter || submitter.value === 'close') return;
      e.preventDefault();
      await onSubmit?.(submitter, form);
    };
    form.querySelector('[data-close]')?.addEventListener('click', () => dialog.close());
    if (!dialog.open) dialog.showModal();
    form.querySelector('input,select,textarea,button')?.focus();
  }
  const field = (name, label, value = '', attrs = '', help = '') => `<label class="lib-field">${label}<input name="${name}" value="${esc(value)}" ${attrs}>${help ? `<small>${help}</small>` : ''}</label>`;
  const typeSelect = value => `<label class="lib-field">Tipo *<select name="doc_type" required><option value="">Selecione</option>${Object.entries(TYPES).map(([v, t]) => `<option value="${v}" ${value === v ? 'selected' : ''}>${t}</option>`).join('')}</select></label>`;
  function checkFiles(list) {
    for (const f of list) {
      if (!/\.(pdf|docx|dotx)$/i.test(f.name)) return `“${f.name}”: envie somente PDF, DOCX ou DOTX.`;
      if (f.size > MAX) return `“${f.name}” tem ${fmtSize(f.size)}; o limite é 20 MB.`;
      if (f.size === 0) return `“${f.name}” está vazio.`;
    }
    const exts = [...list].map(f => f.name.split('.').pop().toLowerCase());
    if (new Set(exts).size !== exts.length) return 'Envie no máximo um arquivo de cada formato por revisão.';
    return '';
  }
  async function uploadAll(revisionId, list, progress) {
    const failures = [];
    for (const f of list) {
      progress?.(`Enviando ${f.name}…`);
      const form = new FormData();
      form.append('action', 'upload'); form.append('revision_id', revisionId); form.append('format', f.name.split('.').pop().toLowerCase()); form.append('file', f);
      try { await files(form); } catch (e) { failures.push(`${f.name}: ${e.message}`); }
    }
    return failures;
  }

  function insertDialog() {
    const op = uuid();
    openDialog(`<h2 id="libDialogTitle">Inserir documento</h2><p class="lib-help">O documento é salvo em <strong>Rascunho</strong>. Ele só fica disponível aos auditores depois que você confirmar responsável, emissão e escolher “Disponibilizar como vigente”.</p>
      <div class="lib-grid">${field('title', 'Título *', '', 'required minlength="2" maxlength="200"')}${typeSelect('')}
      ${field('code', 'Código documental', '', 'maxlength="60"', 'Informe somente se já atribuído. Códigos não são reutilizados.')}${field('revision_label', 'Revisão *', 'Rev.00', 'required maxlength="30"')}
      ${field('responsible', 'Responsável', '', 'maxlength="200"', 'Obrigatório para disponibilizar como vigente.')}${field('issued_on', 'Data de emissão', '', 'type="date"', 'Obrigatória para disponibilizar como vigente.')}
      <label class="lib-field full">Descrição<textarea name="description" maxlength="2000"></textarea></label>
      <label class="lib-field full">Arquivos (PDF, DOCX ou DOTX, até 20 MB cada)<input name="files" type="file" multiple accept=".pdf,.docx,.dotx,application/pdf,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.openxmlformats-officedocument.wordprocessingml.template"><small>Formatos alternativos do mesmo documento podem ser enviados juntos (ex.: Word e PDF). Não há conversão automática.</small></label></div>
      <p class="lib-error" role="alert" id="libFormError"></p><div class="lib-dialog-actions"><button class="lib-btn secondary" value="close" data-close type="button">Cancelar</button><button class="lib-btn" value="save">Salvar rascunho</button></div>`,
    async (button, form) => {
      const err = $('#libFormError'), data = Object.fromEntries(new FormData(form));
      const list = form.elements.files.files;
      if (!data.title.trim() || !data.doc_type || !data.revision_label.trim()) { err.textContent = 'Preencha título, tipo e revisão.'; return; }
      const fileProblem = checkFiles(list); if (fileProblem) { err.textContent = fileProblem; return; }
      button.disabled = true; err.textContent = '';
      try {
        const created = await rpc('create', { operation_id: op, title: data.title, doc_type: data.doc_type, code: data.code, revision_label: data.revision_label,
          responsible: data.responsible, issued_on: data.issued_on, description: data.description });
        const failures = await uploadAll(created.revision_id, list, msg => { err.textContent = msg; });
        $('#libDialog').close();
        if (failures.length) notice(`Cadastro salvo em Rascunho, mas ${failures.length} arquivo(s) não foram armazenados e nada foi publicado: ${failures.join(' · ')}. Abra “Gerenciar” para enviar novamente.`, 'error');
        else notice(`Documento salvo em Rascunho${list.length ? ` com ${list.length} arquivo(s) íntegro(s)` : ''}. Para disponibilizá-lo, abra “Gerenciar”.`);
        await loadList();
      } catch (e) { err.textContent = e.message; button.disabled = false; }
    });
  }

  function revisionBlock(rev, archived) {
    const filesHtml = rev.files.length ? rev.files.map(f => `<div class="lib-row"><button type="button" class="lib-btn secondary small" data-download="${esc(f.id)}">⭳ ${esc(f.format.toUpperCase())}</button><span class="lib-sub">${esc(f.filename)} · ${fmtSize(f.size_bytes)} · SHA-256 ${esc(f.sha256.slice(0, 12))}…</span>${rev.status === 'draft' ? `<button type="button" class="lib-btn danger small" data-remove-file="${esc(f.id)}">Remover</button>` : ''}</div>`).join('') : '<span class="lib-sub">Nenhum arquivo nesta revisão.</span>';
    const draftTools = rev.status === 'draft' ? `<div class="lib-grid">${field(`rl_${rev.id}`, 'Revisão', rev.revision_label, 'maxlength="30"')}${field(`rr_${rev.id}`, 'Responsável', rev.responsible || '', 'maxlength="200"')}${field(`ri_${rev.id}`, 'Data de emissão', rev.issued_on || '', 'type="date"')}<label class="lib-field">Resumo da alteração<input name="rs_${rev.id}" value="${esc(rev.change_summary || '')}" maxlength="2000"></label></div>
      <div class="lib-row"><button class="lib-btn secondary small" value="save_rev" data-rev="${esc(rev.id)}">Salvar dados da revisão</button><label class="lib-field">Incluir arquivo<input type="file" data-upload="${esc(rev.id)}" accept=".pdf,.docx,.dotx"></label></div>
      <div class="lib-row">${archived ? '<span class="lib-sub">Restaure o documento para disponibilizar esta revisão.</span>' : `<button class="lib-btn small" value="publish" data-rev="${esc(rev.id)}">Disponibilizar como vigente</button>`}<button class="lib-btn danger small" value="cancel_rev" data-rev="${esc(rev.id)}">Cancelar rascunho</button></div>` : '';
    return `<div class="lib-rev"><div class="lib-row"><strong>${esc(rev.revision_label)}</strong><span class="lib-badge ${esc(rev.status)}">${esc(REV[rev.status])}</span><span class="lib-sub">${rev.responsible ? `Responsável: ${esc(rev.responsible)} · ` : ''}Emissão ${fmtDate(rev.issued_on)}${rev.published_at ? ` · disponibilizada em ${fmtDateTime(rev.published_at)}` : ''}${rev.superseded_at ? ` · substituída em ${fmtDateTime(rev.superseded_at)}` : ''}</span></div>${rev.change_summary && rev.status !== 'draft' ? `<div class="lib-sub">${esc(rev.change_summary)}</div>` : ''}${filesHtml}${draftTools}</div>`;
  }

  async function manage(documentId) {
    let detail;
    try { detail = await rpc('detail', { document_id: documentId }); } catch (e) { notice(e.message, 'error'); return; }
    const d = detail.document, archived = d.status === 'arquivado', hasDraft = detail.revisions.some(r => r.status === 'draft');
    openDialog(`<h2 id="libDialogTitle">${esc(d.title)}</h2><div class="lib-row"><span class="lib-badge ${esc(d.status)}">${esc(STATUS[d.status])}</span>${d.code ? `<span class="lib-sub">Código ${esc(d.code)}</span>` : ''}</div>
      <section class="lib-section"><h3>Identificação</h3><div class="lib-grid">${field('title', 'Título *', d.title, 'required minlength="2" maxlength="200"')}${typeSelect(d.doc_type)}${field('code', 'Código documental', d.code || '', 'maxlength="60"', 'Após emissão de uma revisão, o código não pode mudar.')}<label class="lib-field full">Descrição<textarea name="description" maxlength="2000">${esc(d.description || '')}</textarea></label></div><div class="lib-row"><button class="lib-btn secondary small" value="save_doc">Salvar identificação</button></div></section>
      <section class="lib-section"><h3>Revisões</h3>${detail.revisions.map(r => revisionBlock(r, archived)).join('')}${!hasDraft && !archived ? `<div class="lib-row">${field('new_label', 'Nova revisão', '', 'maxlength="30" placeholder="Ex.: Rev.01"')}<button class="lib-btn secondary small" value="new_rev">Criar revisão em rascunho</button></div>` : ''}</section>
      <section class="lib-section"><h3>Situação</h3>${archived ? `<p class="lib-help">Arquivado: fora da consulta dos auditores. Motivo: ${esc(d.archive_reason || '—')}</p><div class="lib-row"><button class="lib-btn secondary small" value="restore">Restaurar documento</button></div>` : `<div class="lib-row">${field('archive_reason', 'Motivo do arquivamento', '', 'maxlength="1000"')}<button class="lib-btn danger small" value="archive">Arquivar</button></div><p class="lib-help">Arquivar retira o documento da consulta sem apagar revisões nem arquivos.</p>`}</section>
      <section class="lib-section"><h3>Histórico deste documento</h3><ul class="lib-events">${detail.events.map(e => `<li>${fmtDateTime(e.occurred_at)} — ${esc(EVENTS[e.event_type] || e.event_type)}${e.actor ? ` · ${esc(e.actor)}` : ''}</li>`).join('') || '<li>Sem eventos.</li>'}</ul></section>
      <p class="lib-error" role="alert" id="libFormError"></p><div class="lib-dialog-actions"><button class="lib-btn secondary" value="close" data-close type="button">Fechar</button></div>`,
    async (button, form) => {
      const err = $('#libFormError'), v = n => form.elements[n]?.value ?? '';
      const rev = button.dataset.rev;
      const actions = {
        save_doc: () => rpc('update', { document_id: d.id, expected_lock_version: d.lock_version, title: v('title'), doc_type: v('doc_type'), code: v('code'), description: v('description') }),
        save_rev: () => rpc('update_revision', { revision_id: rev, revision_label: v(`rl_${rev}`), responsible: v(`rr_${rev}`), issued_on: v(`ri_${rev}`), change_summary: v(`rs_${rev}`) }),
        publish: async () => {
          await rpc('update_revision', { revision_id: rev, revision_label: v(`rl_${rev}`), responsible: v(`rr_${rev}`), issued_on: v(`ri_${rev}`), change_summary: v(`rs_${rev}`) });
          if (!confirm('Disponibilizar esta revisão como vigente? A revisão vigente anterior passará a Substituída e seus arquivos serão preservados.')) return 'cancelled';
          return rpc('publish', { revision_id: rev });
        },
        cancel_rev: () => confirm('Cancelar este rascunho? Ele permanecerá no histórico como Cancelado.') ? rpc('cancel_revision', { revision_id: rev, reason: 'Cancelado pelo Administrador' }) : 'cancelled',
        new_rev: () => v('new_label').trim() ? rpc('new_revision', { operation_id: uuid(), document_id: d.id, revision_label: v('new_label') }) : Promise.reject(new Error('Informe a identificação da nova revisão.')),
        archive: () => v('archive_reason').trim() ? rpc('archive', { document_id: d.id, reason: v('archive_reason') }) : Promise.reject(new Error('Informe o motivo do arquivamento.')),
        restore: () => rpc('restore', { document_id: d.id }),
      };
      if (!actions[button.value]) return;
      button.disabled = true; err.textContent = '';
      try {
        const r = await actions[button.value]();
        if (r !== 'cancelled') { await manage(d.id); await loadList(); notice(button.value === 'publish' ? 'Revisão disponibilizada como vigente.' : 'Alteração registrada.'); }
        else button.disabled = false;
      } catch (e) { err.textContent = e.message; button.disabled = false; }
    });
    const form = $('#libDialogForm');
    form.onclick = async e => {
      const b = e.target.closest('button');
      if (b?.dataset.download) { e.preventDefault(); download(b.dataset.download, b); }
      if (b?.dataset.removeFile) {
        e.preventDefault();
        if (!confirm('Remover este arquivo do rascunho?')) return;
        b.disabled = true;
        try { await files({ action: 'remove_file', file_id: b.dataset.removeFile }); await manage(d.id); await loadList(); }
        catch (x) { $('#libFormError').textContent = x.message; b.disabled = false; }
      }
    };
    form.onchange = async e => {
      const input = e.target.closest('[data-upload]'); if (!input?.files.length) return;
      const problem = checkFiles(input.files); const err = $('#libFormError');
      if (problem) { err.textContent = problem; input.value = ''; return; }
      input.disabled = true;
      const failures = await uploadAll(input.dataset.upload, input.files, m => { err.textContent = m; });
      if (failures.length) { err.textContent = failures.join(' · '); input.disabled = false; input.value = ''; return; }
      await manage(d.id); await loadList();
    };
  }

  // ---------- Abas e inicialização ----------
  function selectTab(which) {
    const reports = which === 'reports';
    $('#tabCorporate').setAttribute('aria-selected', String(!reports)); $('#tabReports').setAttribute('aria-selected', String(reports));
    $('#corporatePanel').hidden = reports; $('#reportsPanel').hidden = !reports;
    if (reports && !reportsLoaded) { reportsLoaded = true; window.AUDITA_PRO_DOCUMENT_LIBRARY(auth.client, $('#reportsPanel')); }
  }
  async function start() {
    try { auth = await window.AUDITA_PRO_REQUIRE_SESSION(); } catch { $('#corporatePanel').innerHTML = '<div class="lib-state error" role="alert"><strong>Não foi possível validar a sessão</strong><a href="audita-pro-login.html">Entrar novamente</a></div>'; return; }
    if (!auth) return;
    const email = $('#accountEmail'); if (email) email.textContent = auth.session.user.email || '';
    $('#logout')?.addEventListener('click', async () => { await auth.client.auth.signOut(); location.replace('audita-pro-login.html'); });
    try { ctx = await rpc('context'); }
    catch (e) { $('#corporatePanel').innerHTML = `<div class="lib-state error" role="alert"><strong>Não foi possível carregar a biblioteca</strong>${esc(e.message)}<br><br><button type="button" class="lib-btn secondary" onclick="location.reload()">Tentar novamente</button></div>`; return; }
    if (!ctx.can_read) {
      $('#corporatePanel').innerHTML = '<div class="lib-state" role="status"><strong>Biblioteca corporativa indisponível para o seu perfil</strong>Os relatórios das auditorias autorizadas da sua organização ficam em <a href="audita-pro-auditorias.html">Auditorias</a>.</div>';
      return;
    }
    const actions = $('#headingActions');
    if (ctx.can_manage) actions.innerHTML = `<button type="button" class="lib-btn" id="libInsert">+ Inserir documento</button>`;
    if (ctx.can_history) actions.insertAdjacentHTML('beforeend', `<a class="lib-btn secondary" href="audita-pro-historico.html?origem=biblioteca">Histórico de modificações do sistema</a>`);
    $('#libInsert')?.addEventListener('click', insertDialog);
    $('#libTabs').hidden = false;
    $('#tabCorporate').onclick = () => selectTab('corporate'); $('#tabReports').onclick = () => selectTab('reports');
    selectTab('corporate'); // RS-05/CA-03: a entrada sempre abre os documentos.
    await loadList();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})();
