(() => {
  'use strict';
  const $ = (selector) => document.querySelector(selector);
  const state = { client: null, session: null, admin: false, tab: 'users', page: 0, pageSize: 15,
    filters: { search: '', status: '', organization: '', profile: '', pending: false },
    organizations: [], positions: [], profiles: [], detail: null, dialogSubmit: null };
  const html = (value) => String(value ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
  const date = (value) => value ? new Intl.DateTimeFormat('pt-BR').format(new Date(value)) : '—';
  const digits = (value) => String(value ?? '').replace(/\D/g, '');
  const cpfMasked = (value) => { const d = digits(value); return d.length === 11 ? `***.***.${d.slice(6, 9)}-**` : '—'; };
  const statusName = (value) => ({ active: 'Ativo', inactive: 'Inativo', pending: 'Pendente', approved: 'Aprovado', rejected: 'Reprovado', not_required: 'Dispensado', sent: 'Enviado', failed: 'Falhou', existing_account: 'Conta existente', superseded: 'Substituído' })[value] || value || '—';
  const badge = (value) => `<span class="badge ${html(value)}">${html(statusName(value))}</span>`;
  const setNotice = (message, error = false) => { const n = $('#notice'); n.textContent = message; n.className = `notice${error ? ' error' : ''}`; n.hidden = !message; if (message) n.scrollIntoView({ block: 'nearest' }); };
  const unwrap = (result) => { if (result.error) throw result.error; return result.data; };
  const option = (rows, label = 'name', includeBlank = true) => `${includeBlank ? '<option value="">Selecione</option>' : ''}${rows.map((r) => `<option value="${html(r.id)}">${html(r[label])}</option>`).join('')}`;
  const field = (name, label, value = '', type = 'text', required = false, extra = '') => `<label class="field">${html(label)}${required ? ' *' : ''}<input name="${html(name)}" type="${type}" value="${html(value)}" ${required ? 'required' : ''} ${extra}></label>`;
  const select = (name, label, options, required = false) => `<label class="field">${html(label)}${required ? ' *' : ''}<select name="${html(name)}" ${required ? 'required' : ''}>${options}</select></label>`;
  const row = (title, body, actions = '') => `<div class="detail-row"><strong>${html(title)}</strong><p>${body}</p>${actions}</div>`;
  const formValue = (form, name) => String(new FormData(form).get(name) ?? '').trim();
  const match = (error) => { const m = String(error?.message || error || 'Erro desconhecido');
    if (/function.*not found|schema cache|relation.*does not exist|column.*does not exist/i.test(m)) return 'O banco conectado ainda não recebeu todas as migrations deste módulo. A publicação no Supabase está pendente.';
    if (/Failed to fetch|NetworkError/i.test(m)) return 'Não foi possível conectar ao Supabase. Verifique a conexão e tente novamente.';
    return m;
  };
  const call = async (action, data = {}) => {
    const { data: sessionData, error } = await state.client.auth.getSession(); if (error || !sessionData.session) throw new Error('Sessão expirada. Entre novamente.');
    const result = await fetch(`${window.AUDITA_PRO_SUPABASE_URL}/functions/v1/user-management`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${sessionData.session.access_token}`, apikey: window.AUDITA_PRO_SUPABASE_PUBLISHABLE_KEY },
      body: JSON.stringify({ action, ...data }),
    });
    const payload = await result.json().catch(() => ({}));
    if (!result.ok) throw new Error(payload.error || `A operação falhou (${result.status}). Verifique se a função user-management foi publicada.`);
    return payload;
  };
  const dialog = (title, body, submit, label = 'Salvar') => {
    $('#dialogTitle').textContent = title; $('#dialogBody').innerHTML = `<div id="dialogError" class="notice error" hidden></div>${body}`; $('#dialogSubmit').textContent = label;
    state.dialogSubmit = submit; $('#formDialog').showModal();
  };
  const closeDialog = () => { $('#formDialog').close(); state.dialogSubmit = null; };
  const withAction = async (task, success) => {
    try { await task(); closeDialog(); setNotice(success); await reload(); }
    catch (error) { if ($('#formDialog').open) { $('#dialogError').textContent = match(error); $('#dialogError').hidden = false; } else setNotice(match(error), true); }
  };
  const reload = async () => { if (state.admin) { await Promise.all([loadSummary(), loadList()]); if (state.detail) await openDetail(state.detail.type, state.detail.id); } else location.replace('audita-pro-perfil.html'); };

  async function boot() {
    try {
      const auth = await window.AUDITA_PRO_REQUIRE_SESSION(); if (!auth) return;
      state.client = auth.client; state.session = auth.session;
      const user = unwrap(await state.client.auth.getUser()).user;
      $('#accountEmail').textContent = user.email || 'Conta autenticada';
      state.admin = user.app_metadata?.platform_role === 'admin';
      if (state.admin) {
        const granted = unwrap(await state.client.rpc('is_platform_admin'));
        state.admin = granted === true;
      }
      $('#adminWorkspace').hidden = !state.admin; $('#personalWorkspace').hidden = state.admin;
      if (state.admin) {
        await loadCatalogs(); renderFilters(); await reload();
      } else location.replace('audita-pro-perfil.html');
    } catch (error) {
      $('#adminWorkspace').hidden = true; $('#personalWorkspace').hidden = true;
      $('#fatal').hidden = false; $('#fatal').innerHTML = `<h2>Não foi possível abrir o módulo</h2><p>${html(match(error))}</p><button class="button" id="retry">Tentar novamente</button>`;
      $('#retry').addEventListener('click', () => location.reload());
    }
  }
  async function loadCatalogs() {
    const [orgs, positions, profiles] = await Promise.all([
      state.client.from('organizations').select('id,legal_name,cnpj,status').order('legal_name'),
      state.client.from('positions').select('id,name,status,requires_identity_document').eq('status', 'active').order('name'),
      state.client.from('access_profiles').select('id,name,status').eq('status', 'active').order('name'),
    ]);
    state.organizations = unwrap(orgs) || []; state.positions = unwrap(positions) || []; state.profiles = unwrap(profiles) || [];
  }
  async function loadSummary() {
    const [users, orgs, docs, pending, requests] = await Promise.all([
      state.client.from('user_profiles').select('user_id', { count: 'exact', head: true }).eq('status', 'active'),
      state.client.from('organizations').select('id', { count: 'exact', head: true }).eq('status', 'active'),
      state.client.from('user_documents').select('id,profile_submissions!inner(state)', { count: 'exact', head: true }).eq('status', 'pending').eq('profile_submissions.state', 'submitted'),
      state.client.from('organization_memberships').select('id', { count: 'exact', head: true }).eq('competence_status', 'pending').eq('status', 'active'),
      state.client.from('organization_access_requests').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
    ]);
    [users, orgs, docs, pending, requests].forEach(unwrap);
    const metrics = [['Usuários ativos', users.count], ['Vínculos em validação', pending.count], ['Documentos pendentes', docs.count], ['Organizações ativas', orgs.count], ['Solicitações de vínculo', requests.count]];
    $('#summary').innerHTML = metrics.map(([label, count]) => `<div class="metric"><span>${html(label)}</span><b>${count ?? 0}</b></div>`).join('');
  }
  function renderFilters() {
    const f = state.filters;
    const common = `<button type="button" class="button secondary small" id="applyFilters">Pesquisar</button><button type="button" class="button secondary small" id="clearFilters">Limpar</button>`;
    $('#filterPanel').innerHTML = state.tab === 'users' ?
      `<input id="search" placeholder="Nome, e-mail ou CPF exato" value="${html(f.search)}" aria-label="Pesquisar usuários">${select('organization', 'Organização', `<option value="">Todas as organizações</option>${option(state.organizations, 'legal_name', false)}`)}${select('profile', 'Perfil', `<option value="">Todos os perfis</option>${option(state.profiles, 'name', false)}`)}<select id="status" aria-label="Status"><option value="">Todos os status</option><option value="active">Ativos</option><option value="inactive">Inativos</option></select><label class="field" style="margin:7px 0"><input id="pending" type="checkbox" style="width:auto;min-height:auto"> Pendente</label>${common}` :
      state.tab === 'organizations' ? `<input id="search" placeholder="Razão social, fantasia ou CNPJ" value="${html(f.search)}" aria-label="Pesquisar organizações"><select id="status" aria-label="Status"><option value="">Todos os status</option><option value="active">Ativas</option><option value="inactive">Inativas</option></select>${common}` :
      `<span class="muted">${state.tab === 'documents' ? 'Documentos de identificação aguardando análise.' : state.tab === 'requests' ? 'Solicitações de vínculo enviadas por quem criou a própria conta.' : 'Histórico de convites e tentativas de envio.'}</span>`;
    if ($('#status')) $('#status').value = f.status;
    if ($('#pending')) $('#pending').checked = f.pending;
    const orgInput = $('[name="organization"]'); if (orgInput) orgInput.value = f.organization;
    const profileInput = $('[name="profile"]'); if (profileInput) profileInput.value = f.profile;
    $('#applyFilters')?.addEventListener('click', applyFilters);
    $('#clearFilters')?.addEventListener('click', () => { state.filters = { search: '', status: '', organization: '', profile: '', pending: false }; state.page = 0; renderFilters(); loadList().catch(showListError); });
    $('#search')?.addEventListener('keydown', (event) => { if (event.key === 'Enter') applyFilters(); });
  }
  function applyFilters() {
    state.filters.search = $('#search')?.value.trim() || ''; state.filters.status = $('#status')?.value || '';
    state.filters.organization = $('[name="organization"]')?.value || ''; state.filters.profile = $('[name="profile"]')?.value || '';
    state.filters.pending = $('#pending')?.checked || false; state.page = 0; loadList().catch(showListError);
  }
  function showListError(error) { $('#listContent').innerHTML = `<div class="empty error-text">${html(match(error))}</div>`; $('#pagination').innerHTML = ''; }
  async function loadList() {
    $('#listContent').innerHTML = '<div class="empty">Carregando dados…</div>';
    if (state.tab === 'users') return loadUsers();
    if (state.tab === 'organizations') return loadOrganizations();
    if (state.tab === 'documents') return loadDocuments();
    if (state.tab === 'requests') return loadRequests();
    return loadInvites();
  }
  async function idsForMembershipFilters() {
    const f = state.filters;
    if (!f.organization && !f.profile && !f.pending) return null;
    let query = state.client.from('organization_memberships').select('user_id', { count: 'exact' }).limit(1000);
    if (f.organization) query = query.eq('organization_id', f.organization);
    if (f.profile) query = query.eq('access_profile_id', f.profile);
    if (f.pending) query = query.eq('competence_status', 'pending');
    const result = await query; const rows = unwrap(result) || [];
    if ((result.count || 0) > rows.length) throw new Error('Há muitos vínculos para este filtro. Refine a organização ou o perfil antes de pesquisar.');
    return [...new Set(rows.map((m) => m.user_id))];
  }
  async function loadUsers() {
    const f = state.filters, ids = await idsForMembershipFilters();
    if (ids && !ids.length) return emptyList('Nenhum usuário corresponde aos filtros.');
    let query = state.client.from('user_profiles').select('user_id,full_name,email,cpf,status,created_at', { count: 'exact' });
    if (ids) query = query.in('user_id', ids);
    if (f.status) query = query.eq('status', f.status);
    if (f.search) {
      const clean = f.search.replace(/[,()*%]/g, '').trim();
      if (/^[0-9.\- ]{11,14}$/.test(clean)) query = query.eq('cpf', digits(clean));
      else query = query.or(`full_name.ilike.%${clean}%,email.ilike.%${clean}%`);
    }
    const result = await query.order('created_at', { ascending: false }).order('user_id').range(state.page * state.pageSize, (state.page + 1) * state.pageSize - 1);
    const users = unwrap(result) || [];
    if (!users.length) return emptyList(f.search || f.organization || f.profile || f.pending || f.status ? 'Nenhum usuário corresponde aos filtros.' : 'Nenhum usuário cadastrado.', result.count);
    const userIds = users.map((u) => u.user_id);
    const memberships = unwrap(await state.client.from('organization_memberships').select('id,user_id,organization_id,access_profile_id,status,competence_status').in('user_id', userIds)) || [];
    const docs = memberships.length ? (unwrap(await state.client.from('user_documents').select('membership_id,status,uploaded_at').in('membership_id', memberships.map((m) => m.id))) || []) : [];
    const orgMap = new Map(state.organizations.map((o) => [o.id, o.legal_name]));
    const profileMap = new Map(state.profiles.map((p) => [p.id, p.name]));
    $('#listContent').innerHTML = `<table class="data-table"><thead><tr><th>Pessoa</th><th>Organizações / perfis</th><th>Conta</th><th>Documentos</th><th>Cadastro</th><th></th></tr></thead><tbody>${users.map((u) => {
      const related = memberships.filter((m) => m.user_id === u.user_id);
      const pending = related.some((m) => m.competence_status === 'pending');
      const rejected = related.some((m) => m.competence_status === 'rejected');
      return `<tr><td><span class="cell-title">${html(u.full_name || 'Nome pendente')}</span><span class="cell-sub">${html(u.email || '')} · ${cpfMasked(u.cpf)}</span></td><td>${related.length ? related.map((m) => `${html(orgMap.get(m.organization_id) || 'Organização')} <span class="muted">(${html(profileMap.get(m.access_profile_id) || 'Perfil pendente')})</span>`).join('<br>') : '<span class="muted">Sem vínculo</span>'}</td><td>${badge(u.status)}</td><td>${badge(rejected ? 'rejected' : pending || !related.length ? 'pending' : 'approved')}<span class="cell-sub">${docs.filter((d) => related.some((m) => m.id === d.membership_id)).length} arquivo(s)</span></td><td>${date(u.created_at)}</td><td><button class="button secondary small" data-user="${html(u.user_id)}">Ver detalhes</button></td></tr>`;
    }).join('')}</tbody></table>`;
    paginate(result.count || 0);
  }
  async function loadOrganizations() {
    const f = state.filters;
    let query = state.client.from('organizations').select('id,legal_name,trade_name,cnpj,segment,status,created_at', { count: 'exact' });
    if (f.status) query = query.eq('status', f.status);
    if (f.search) { const clean = f.search.replace(/[,()*%]/g, '').trim(); if (/^[0-9.\-\/ ]{14,18}$/.test(clean)) query = query.eq('cnpj', digits(clean)); else query = query.or(`legal_name.ilike.%${clean}%,trade_name.ilike.%${clean}%`); }
    const result = await query.order('legal_name').order('id').range(state.page * state.pageSize, (state.page + 1) * state.pageSize - 1);
    const orgs = unwrap(result) || [];
    if (!orgs.length) return emptyList(f.search || f.status ? 'Nenhuma organização corresponde aos filtros.' : 'Nenhuma organização cadastrada.', result.count);
    const memberCounts = unwrap(await state.client.rpc('organization_member_counts', { target_organizations: orgs.map((o) => o.id) })) || [];
    const counts = new Map(memberCounts.map((m) => [m.organization_id, Number(m.member_count)]));
    $('#listContent').innerHTML = `<table class="data-table"><thead><tr><th>Organização</th><th>CNPJ</th><th>Segmento</th><th>Usuários</th><th>Status</th><th></th></tr></thead><tbody>${orgs.map((o) => `<tr><td><span class="cell-title">${html(o.legal_name)}</span><span class="cell-sub">${html(o.trade_name || '')}</span></td><td>${html(o.cnpj)}</td><td>${html(o.segment || '—')}</td><td>${counts.get(o.id) || 0}</td><td>${badge(o.status)}</td><td><button class="button secondary small" data-organization="${html(o.id)}">Ver detalhes</button></td></tr>`).join('')}</tbody></table>`;
    paginate(result.count || 0);
  }
  async function loadDocuments() {
    const r = unwrap(await state.client.rpc('profile_command', {command:'queue',payload:{mine:true,page:0}}));
    $('#listContent').innerHTML = '<div class="empty"><h3>Validação de cadastros e documentos</h3><p>'+r.items.length+' envio(s) na primeira página sob sua responsabilidade.</p><a class="button" href="audita-pro-perfil.html?review=1">Abrir fila de validação</a><p class="hint">Na fila, você pode consultar todos os envios, atribuir responsáveis e analisar os documentos.</p></div>';
    $('#pagination').innerHTML = '';
  }
  async function loadRequests() {
    const result = await state.client.from('organization_access_requests').select('id,user_id,organization_name,cnpj,note,status,created_at', { count: 'exact' }).eq('status', 'pending').order('created_at').range(state.page * state.pageSize, (state.page + 1) * state.pageSize - 1);
    const requests = unwrap(result) || [];
    if (!requests.length) return emptyList('Nenhuma solicitação aguardando análise.', result.count);
    const users = unwrap(await state.client.from('user_profiles').select('user_id,full_name,email').in('user_id', requests.map((r) => r.user_id))) || [];
    const userMap = new Map(users.map((u) => [u.user_id, u]));
    $('#listContent').innerHTML = `<table class="data-table"><thead><tr><th>Pessoa</th><th>Empresa informada</th><th>Observação</th><th>Data</th><th></th></tr></thead><tbody>${requests.map((r) => `<tr><td><span class="cell-title">${html(userMap.get(r.user_id)?.full_name || 'Pessoa')}</span><span class="cell-sub">${html(userMap.get(r.user_id)?.email || '')}</span></td><td>${html(r.organization_name)}<span class="cell-sub">${html(r.cnpj || '')}</span></td><td>${html(r.note || '—')}</td><td>${date(r.created_at)}</td><td><button class="button secondary small" data-request="${html(r.id)}">Analisar</button></td></tr>`).join('')}</tbody></table>`;
    paginate(result.count || 0);
  }
  async function loadInvites() {
    const result = await state.client.from('user_invites').select('id,user_id,email,organization_id,status,attempt_count,created_at,last_error', { count: 'exact' }).order('created_at', { ascending: false }).range(state.page * state.pageSize, (state.page + 1) * state.pageSize - 1);
    const invites = unwrap(result) || [];
    if (!invites.length) return emptyList('Nenhum convite registrado.', result.count);
    const orgMap = new Map(state.organizations.map((o) => [o.id, o.legal_name]));
    $('#listContent').innerHTML = `<table class="data-table"><thead><tr><th>E-mail</th><th>Organização</th><th>Situação</th><th>Tentativas</th><th>Data</th><th></th></tr></thead><tbody>${invites.map((i) => `<tr><td><span class="cell-title">${html(i.email)}</span><span class="cell-sub">${html(i.last_error || '')}</span></td><td>${html(orgMap.get(i.organization_id) || 'Administrador / sem vínculo')}</td><td>${badge(i.status)}</td><td>${i.attempt_count}</td><td>${date(i.created_at)}</td><td>${i.status === 'failed' || i.status === 'sent' ? `<button class="button secondary small" data-resend-invite="${html(i.id)}" data-invite-status="${html(i.status)}" ${i.attempt_count >= 5 ? 'disabled' : ''}>Reenviar</button>` : ''} ${i.user_id ? `<button class="button secondary small" data-user="${html(i.user_id)}">Abrir conta</button>` : ''}</td></tr>`).join('')}</tbody></table>`;
    paginate(result.count || 0);
  }
  async function reviewRequest(id) {
    const request = unwrap(await state.client.from('organization_access_requests').select('*').eq('id', id).single());
    const matched = state.organizations.filter((o) => o.status === 'active' && (!request.cnpj || o.cnpj === request.cnpj));
    dialog('Analisar solicitação de vínculo', `<p><strong>${html(request.organization_name)}</strong> · ${html(request.cnpj || 'CNPJ não informado')}</p><p>${html(request.note || '')}</p>${select('decision', 'Decisão', '<option value="approved">Aprovar e vincular</option><option value="rejected">Reprovar</option>', true)}${select('organization_id', 'Organização cadastrada', `<option value="">Selecione</option>${option(matched, 'legal_name', false)}`)}<div class="form-grid">${select('position_id', 'Cargo', option(state.positions))}${select('access_profile_id', 'Perfil', option(state.profiles.filter((p) => ['Auditor Líder', 'Auditor', 'Participante / Auditado'].includes(p.name))))}</div><label class="field">Motivo da reprovação<textarea name="review_note"></textarea></label><p class="hint">Se a organização não estiver cadastrada, crie-a antes de aprovar. A aprovação do vínculo não substitui a análise do documento de identificação.</p>`, async (form) => {
      const decision = formValue(form, 'decision'), orgId = formValue(form, 'organization_id'), reason = formValue(form, 'review_note');
      if (decision === 'rejected' && reason.length < 3) throw new Error('Informe o motivo da reprovação.');
      if (decision === 'approved' && (!orgId || !formValue(form, 'position_id') || !formValue(form, 'access_profile_id'))) throw new Error('Selecione organização, cargo e perfil para aprovar.');
      await withAction(async () => {
        if (decision === 'approved') {
          const existing = unwrap(await state.client.from('organization_memberships').select('id').eq('organization_id', orgId).eq('user_id', request.user_id).maybeSingle());
          if (!existing) unwrap(await state.client.from('organization_memberships').insert({ user_id: request.user_id, organization_id: orgId, position_id: formValue(form, 'position_id'), access_profile_id: formValue(form, 'access_profile_id'), created_by: state.session.user.id }).select('id').single());
        }
        unwrap(await state.client.from('organization_access_requests').update({ status: decision, reviewed_by: state.session.user.id, reviewed_at: new Date().toISOString(), review_note: decision === 'rejected' ? reason : null }).eq('id', id).eq('status', 'pending').select('id').single());
      }, decision === 'approved' ? 'Vínculo criado. Aguarde a aprovação documental para liberar o acesso.' : 'Solicitação reprovada e motivo registrado.');
    }, 'Concluir análise');
  }
  function emptyList(message, total = 0) { $('#listContent').innerHTML = `<div class="empty">${html(message)}</div>`; paginate(total || 0); }
  function paginate(total) {
    const last = Math.max(0, Math.ceil(total / state.pageSize) - 1);
    $('#pagination').innerHTML = `<span>${total} registro(s) · Página ${state.page + 1} de ${last + 1}</span><div class="actions"><button class="button secondary small" id="previousPage" ${state.page === 0 ? 'disabled' : ''}>Anterior</button><button class="button secondary small" id="nextPage" ${state.page >= last ? 'disabled' : ''}>Próxima</button></div>`;
    $('#previousPage').onclick = () => { state.page--; loadList().catch(showListError); };
    $('#nextPage').onclick = () => { state.page++; loadList().catch(showListError); };
  }
  async function openDetail(type, id) {
    state.detail = { type, id }; $('#detailPanel').hidden = false;
    $('#detailPanel').innerHTML = '<div class="empty">Carregando detalhes…</div>';
    try { if (type === 'user') await showUser(id); else await showOrganization(id); }
    catch (error) { $('#detailPanel').innerHTML = `<div class="empty error-text">${html(match(error))}</div>`; }
    $('#detailPanel').scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
  const closeDetail = () => { state.detail = null; $('#detailPanel').hidden = true; $('#detailPanel').innerHTML = ''; };
  async function showUser(id) {
    const [profileResult, memberResult, inviteResult, eventsResult, accessResult, dependenciesResult] = await Promise.all([
      state.client.from('user_profiles').select('*').eq('user_id', id).single(),
      state.client.from('organization_memberships').select('*').eq('user_id', id).order('created_at'),
      state.client.from('user_invites').select('*').eq('user_id', id).order('created_at', { ascending: false }).limit(10),
      state.client.from('audit_events').select('event_type,entity_type,occurred_at').eq('entity_id', id).order('occurred_at', { ascending: false }).limit(12),
      call('get_user_access', { user_id: id }),
      state.client.rpc('user_inactivation_dependencies', { target_user: id }),
    ]);
    const user = unwrap(profileResult), memberships = unwrap(memberResult) || [], invites = unwrap(inviteResult) || [], events = unwrap(eventsResult) || [];
    const dependencies = unwrap(dependenciesResult) || { led_audits: 0, participations: 0, pending_acknowledgements: 0 };
    const hasDependencies = Object.values(dependencies).some((value) => Number(value) > 0);
    const memberIds = memberships.map((m) => m.id);
    const [documents, participations] = memberIds.length ? await Promise.all([
      state.client.from('user_documents').select('id,membership_id,status,uploaded_at,reviewed_at,review_note,storage_path').in('membership_id', memberIds).order('uploaded_at', { ascending: false }),
      state.client.from('audit_participants').select('audit_id,membership_id,participant_type,active,is_signatory').in('membership_id', memberIds).limit(50),
    ]) : [{ data: [] }, { data: [] }];
    const docs = unwrap(documents) || [], participationRows = unwrap(participations) || [];
    const orgMap = new Map(state.organizations.map((o) => [o.id, o.legal_name]));
    const profileMap = new Map(state.profiles.map((p) => [p.id, p.name]));
    const positionMap = new Map(state.positions.map((p) => [p.id, p.name]));
    $('#detailPanel').innerHTML = `<div class="detail-head"><div><span class="eyebrow">CADASTRO DE PESSOA</span><h2>${html(user.full_name || 'Nome pendente')}</h2><span class="muted">${html(user.email || '')}</span></div><div class="actions"><button class="button secondary small" id="editUser">Editar</button><button class="button secondary small" id="addMembership">Novo vínculo</button><button class="button secondary small" id="toggleAdmin">${accessResult.administrator ? 'Remover Administrador' : 'Tornar Administrador'}</button><button class="button ${user.status === 'active' ? 'danger' : 'secondary'} small" id="toggleUser" ${user.status === 'active' && hasDependencies ? 'disabled' : ''}>${user.status === 'active' ? 'Inativar' : 'Reativar'}</button><button class="button secondary small" id="closeDetail">Fechar</button></div></div>
      <div class="detail-grid">
      <section class="detail-section"><h3>Dados pessoais e conta</h3><p><strong>CPF:</strong> ${html(user.cpf || 'Pendente')}</p><p><strong>Telefone:</strong> ${html(user.phone || '—')}</p><p><strong>Administrador global:</strong> ${accessResult.administrator ? 'Sim' : 'Não'}</p><p><strong>Status:</strong> ${badge(user.status)}</p><p><strong>Cadastro:</strong> ${date(user.created_at)}</p>${hasDependencies ? `<p class="hint">Antes de inativar: ${Number(dependencies.led_audits)} auditoria(s) liderada(s), ${Number(dependencies.participations)} participação(ões) ativa(s), ${Number(dependencies.pending_acknowledgements)} ciência(s) pendente(s).</p>` : ''}</section>
      <section class="detail-section"><h3>Organizações e vínculos</h3>${memberships.length ? memberships.map((m) => row(orgMap.get(m.organization_id) || 'Organização', `<strong>Cargo:</strong> ${html(positionMap.get(m.position_id) || '—')} · <strong>Perfil:</strong> ${html(profileMap.get(m.access_profile_id) || '—')}<br><strong>Vínculo:</strong> ${badge(m.status)} · <strong>Competência:</strong> ${badge(m.competence_status)}`, `<button class="button secondary small" data-edit-membership="${html(m.id)}">Editar vínculo</button>`)).join('') : '<p>Sem vínculo organizacional. O Administrador pode criar um vínculo para liberar acesso operacional.</p>'}</section>
      <section class="detail-section"><h3>Documentos de identificação</h3>${docs.length ? docs.map((d) => row(`Envio de ${date(d.uploaded_at)}`, `${badge(d.status)} ${d.review_note ? `· ${html(d.review_note)}` : ''}`, `<button class="button secondary small" data-view-document="${html(d.id)}">Visualizar</button> ${d.status === 'pending' ? `<button class="button small" data-document="${html(d.id)}">Analisar</button>` : ''}`)).join('') : '<p>Nenhum documento enviado.</p>'}</section>
      <section class="detail-section"><h3>Participações em auditorias</h3>${participationRows.length ? participationRows.map((p) => row(p.participant_type, `Auditoria ${html(p.audit_id)} · ${p.active ? 'Ativa' : 'Inativa'} · ${p.is_signatory ? 'Signatário' : 'Não signatário'}`)).join('') : '<p>Nenhuma participação registrada.</p>'}</section>
      <section class="detail-section"><h3>Convites e acesso</h3>${invites.length ? invites.map((i) => row(date(i.created_at), `${badge(i.status)} · ${html(i.email)} · ${i.attempt_count} tentativa(s)`, `<button class="button secondary small" data-resend="${html(i.id)}" ${i.attempt_count >= 5 ? 'disabled' : ''}>Reenviar acesso</button>`)).join('') : '<p>Nenhum convite registrado.</p>'}</section>
      <section class="detail-section"><h3>Histórico recente</h3>${events.length ? events.map((e) => row(e.event_type, `${date(e.occurred_at)} · ${html(e.entity_type)}`)).join('') : '<p>Sem eventos recentes para esta pessoa.</p>'}</section></div>`;
    $('#editUser').onclick = () => editUser(user);
    $('#addMembership').onclick = () => membershipForm(null, id);
    $('#toggleAdmin').onclick = () => dialog(accessResult.administrator ? 'Remover papel de Administrador' : 'Conceder papel de Administrador', `<p>Esta alteração modifica as permissões globais de <strong>${html(user.full_name)}</strong>. A senha e os demais metadados da conta serão preservados.</p>${field('confirmation_password', 'Confirme sua senha', '', 'password', true, 'autocomplete="current-password"')}`, async (form) => {
      await withAction(() => call('set_global_role', { user_id: id, admin: !accessResult.administrator, confirmation_password: new FormData(form).get('confirmation_password') }), 'Papel global atualizado.');
    }, 'Confirmar alteração');
    $('#toggleUser').onclick = () => confirmAction(`${user.status === 'active' ? 'Inativar' : 'Reativar'} conta`, `Esta ação altera o acesso de ${user.full_name}. O histórico será preservado.`, () => call('set_account_status', { user_id: id, status: user.status === 'active' ? 'inactive' : 'active' }));
    $('#closeDetail').onclick = closeDetail;
    $('#detailPanel').querySelectorAll('[data-edit-membership]').forEach((b) => b.onclick = () => membershipForm(memberships.find((m) => m.id === b.dataset.editMembership), id));
    $('#detailPanel').querySelectorAll('[data-document]').forEach((b) => b.onclick = () => reviewDocument(b.dataset.document));
    $('#detailPanel').querySelectorAll('[data-view-document]').forEach((b) => b.onclick = () => viewDocument(docs.find((d) => d.id === b.dataset.viewDocument)));
    $('#detailPanel').querySelectorAll('[data-resend]').forEach((b) => b.onclick = () => confirmAction('Reenviar instruções de acesso', 'O Supabase enviará um novo link para o e-mail cadastrado.', () => call('resend_invite', { invite_id: b.dataset.resend })));
  }
  async function showOrganization(id) {
    const [orgResult, unitsResult, contactsResult, membersResult, auditsResult, eventsResult] = await Promise.all([
      state.client.from('organizations').select('*').eq('id', id).single(),
      state.client.from('organization_units').select('*').eq('organization_id', id).order('name'),
      state.client.from('organization_contacts').select('*').eq('organization_id', id).order('full_name'),
      state.client.from('organization_memberships').select('*').eq('organization_id', id).order('created_at'),
      state.client.from('audits').select('id,title,status,start_date,end_date').eq('organization_id', id).order('created_at', { ascending: false }).limit(20),
      state.client.from('audit_events').select('event_type,entity_type,occurred_at').eq('organization_id', id).order('occurred_at', { ascending: false }).limit(15),
    ]);
    const org = unwrap(orgResult), units = unwrap(unitsResult) || [], contacts = unwrap(contactsResult) || [], memberships = unwrap(membersResult) || [], audits = unwrap(auditsResult) || [], events = unwrap(eventsResult) || [];
    const users = memberships.length ? (unwrap(await state.client.from('user_profiles').select('user_id,full_name,email').in('user_id', memberships.map((m) => m.user_id))) || []) : [];
    const userMap = new Map(users.map((u) => [u.user_id, u])); const profileMap = new Map(state.profiles.map((p) => [p.id, p.name]));
    const address = org.address || {};
    $('#detailPanel').innerHTML = `<div class="detail-head"><div><span class="eyebrow">ORGANIZAÇÃO AUDITADA</span><h2>${html(org.legal_name)}</h2><span class="muted">${html(org.trade_name || '')} · ${html(org.cnpj)}</span></div><div class="actions"><button class="button secondary small" id="editOrganization">Editar</button><button class="button secondary small" id="addUnit">Nova unidade</button><button class="button secondary small" id="addContact">Novo contato</button><button class="button ${org.status === 'active' ? 'danger' : 'secondary'} small" id="toggleOrganization">${org.status === 'active' ? 'Inativar' : 'Reativar'}</button><button class="button secondary small" id="closeDetail">Fechar</button></div></div>
      <div class="detail-grid"><section class="detail-section"><h3>Dados da empresa</h3><p><strong>Razão social:</strong> ${html(org.legal_name)}</p><p><strong>Nome fantasia:</strong> ${html(org.trade_name || '—')}</p><p><strong>CNPJ:</strong> ${html(org.cnpj)}</p><p><strong>Segmento:</strong> ${html(org.segment || '—')}</p><p><strong>E-mail:</strong> ${html(org.institutional_email || '—')}</p><p><strong>Telefone:</strong> ${html(org.institutional_phone || '—')}</p><p><strong>Status:</strong> ${badge(org.status)}</p><p><strong>Endereço:</strong> ${html([address.street, address.number, address.district, address.city, address.state, address.zip].filter(Boolean).join(', ') || '—')}</p></section>
      <section class="detail-section"><h3>Unidades</h3>${units.length ? units.map((u) => row(u.name, `${html(u.location || 'Local não informado')} · ${badge(u.status)}`, `<button class="button secondary small" data-edit-unit="${html(u.id)}">Editar</button>`)).join('') : '<p>Nenhuma unidade cadastrada.</p>'}</section>
      <section class="detail-section"><h3>Contatos responsáveis</h3>${contacts.length ? contacts.map((c) => row(c.full_name, `${html(c.role_title || 'Contato')} · ${html(c.email || '—')} · ${html(c.phone || '—')} · ${badge(c.status)}`, `<button class="button secondary small" data-edit-contact="${html(c.id)}">Editar</button>`)).join('') : '<p>Nenhum contato cadastrado.</p>'}</section>
      <section class="detail-section"><h3>Usuários vinculados</h3><button class="button secondary small" id="linkUser">Vincular usuário existente</button> <button class="button secondary small" id="inviteForOrganization">Convidar novo usuário</button>${memberships.length ? memberships.map((m) => row(userMap.get(m.user_id)?.full_name || 'Pessoa', `${html(userMap.get(m.user_id)?.email || '')} · ${html(profileMap.get(m.access_profile_id) || 'Perfil pendente')} · ${badge(m.status)} · ${badge(m.competence_status)}`, `<button class="button secondary small" data-open-user="${html(m.user_id)}">Abrir pessoa</button>`)).join('') : '<p>Nenhuma pessoa vinculada.</p>'}</section>
      <section class="detail-section"><h3>Auditorias</h3>${audits.length ? audits.map((a) => row(a.title || 'Auditoria', `${badge(a.status)} · ${date(a.start_date)} a ${date(a.end_date)}`, `<a class="button secondary small" href="audita-pro-dashboard.html?organization_id=${encodeURIComponent(id)}&audit_id=${encodeURIComponent(a.id)}">Abrir auditoria</a>`)).join('') : '<p>Nenhuma auditoria cadastrada.</p>'}</section>
      <section class="detail-section"><h3>Histórico recente</h3>${events.length ? events.map((e) => row(e.event_type, `${date(e.occurred_at)} · ${html(e.entity_type)}`)).join('') : '<p>Sem eventos recentes para esta organização.</p>'}</section></div>`;
    $('#editOrganization').onclick = () => organizationForm(org); $('#addUnit').onclick = () => unitForm(id);
    $('#addContact').onclick = () => contactForm(id);
    $('#linkUser').onclick = () => membershipForm(null, null, id);
    $('#inviteForOrganization').onclick = () => inviteForm(id);
    $('#toggleOrganization').onclick = () => confirmAction(`${org.status === 'active' ? 'Inativar' : 'Reativar'} organização`, 'O histórico será preservado. Organizações com auditorias ativas não podem ser inativadas.', async () => unwrap(await state.client.from('organizations').update({ status: org.status === 'active' ? 'inactive' : 'active' }).eq('id', id)));
    $('#closeDetail').onclick = closeDetail;
    $('#detailPanel').querySelectorAll('[data-edit-unit]').forEach((b) => b.onclick = () => unitForm(id, units.find((u) => u.id === b.dataset.editUnit)));
    $('#detailPanel').querySelectorAll('[data-edit-contact]').forEach((b) => b.onclick = () => contactForm(id, contacts.find((c) => c.id === b.dataset.editContact)));
    $('#detailPanel').querySelectorAll('[data-open-user]').forEach((b) => b.onclick = () => openDetail('user', b.dataset.openUser));
  }
  function confirmAction(title, description, task) {
    dialog(title, `<p>${html(description)}</p>`, async () => withAction(task, 'Alteração salva no Supabase.'), 'Confirmar');
  }
  async function viewDocument(document) {
    if (!document?.storage_path) return;
    try { const { data, error } = await state.client.storage.from('identity-documents').createSignedUrl(document.storage_path, 90); if (error) throw error; window.open(data.signedUrl, '_blank', 'noopener,noreferrer'); }
    catch (error) { if ($('#formDialog').open) { $('#dialogError').textContent = match(error); $('#dialogError').hidden = false; } else setNotice(match(error), true); }
  }
  async function reviewDocument(id) { location.href = 'audita-pro-perfil.html?review=1'; }
  function organizationForm(org = null) {
    const a = org?.address || {};
    dialog(org ? 'Editar organização' : 'Nova organização', `<div class="form-grid">${field('legal_name', 'Razão social', org?.legal_name, 'text', true, 'maxlength="200"')}${field('trade_name', 'Nome fantasia', org?.trade_name)}${field('cnpj', 'CNPJ', org?.cnpj, 'text', true, 'inputmode="numeric"')}${field('segment', 'Segmento / ramo', org?.segment, 'text', true)}${field('institutional_email', 'E-mail institucional', org?.institutional_email, 'email')}${field('institutional_phone', 'Telefone institucional', org?.institutional_phone, 'tel')}</div><p class="hint">O CNPJ é validado no banco. A alteração do CNPJ de uma empresa já auditada ficará registrada no histórico.</p><div class="form-grid">${field('street', 'Logradouro', a.street)}${field('number', 'Número', a.number)}${field('district', 'Bairro', a.district)}${field('city', 'Cidade', a.city)}${field('state', 'UF', a.state)}${field('zip', 'CEP', a.zip)}</div>`, async (form) => {
      const record = { legal_name: formValue(form, 'legal_name'), trade_name: formValue(form, 'trade_name') || null,
        cnpj: digits(formValue(form, 'cnpj')), segment: formValue(form, 'segment'),
        institutional_email: formValue(form, 'institutional_email') || null,
        institutional_phone: formValue(form, 'institutional_phone') || null,
        address: Object.fromEntries(['street', 'number', 'district', 'city', 'state', 'zip'].map((key) => [key, formValue(form, key)])) };
      if (record.cnpj.length !== 14) throw new Error('CNPJ deve conter 14 dígitos.');
      if (!org) record.created_by = state.session.user.id;
      await withAction(async () => {
        const result = org ? await state.client.from('organizations').update(record).eq('id', org.id).select('id').single()
          : await state.client.from('organizations').insert(record).select('id').single();
        const saved = unwrap(result); await loadCatalogs(); if (!org) state.detail = { type: 'organization', id: saved.id };
      }, 'Organização salva no Supabase.');
    });
  }
  function inviteForm(organizationId = '') {
    const orgOptions = `<option value="">Selecione a organização</option>${option(state.organizations.filter((o) => o.status === 'active'), 'legal_name', false)}`;
    dialog('Novo usuário', `<div class="form-grid">${field('full_name', 'Nome completo', '', 'text', true)}${field('email', 'E-mail de acesso', '', 'email', true)}${field('cpf', 'CPF, se disponível', '', 'text', false, 'inputmode="numeric"')}${field('phone', 'Telefone', '', 'tel')}</div>${select('profile_name', 'Perfil de acesso', '<option value="">Selecione</option><option>Administrador</option><option>Auditor Líder</option><option>Auditor</option><option>Participante / Auditado</option>', true)}${select('organization_id', 'Organização', orgOptions)}${select('position_id', 'Cargo / qualificação', option(state.positions))}<div id="adminConfirmation" hidden>${field('confirmation_password', 'Confirme sua senha de Administrador', '', 'password', false, 'autocomplete="current-password"')}</div><p class="hint">O Administrador global não precisa de vínculo. Para os demais perfis, selecione organização e cargo. A pessoa definirá sua própria senha; contas existentes mantêm suas credenciais.</p>`, async (form) => {
      const profileName = formValue(form, 'profile_name');
      const data = { full_name: formValue(form, 'full_name'), email: formValue(form, 'email'), cpf: digits(formValue(form, 'cpf')) || null,
        phone: formValue(form, 'phone'), profile_name: profileName, organization_id: formValue(form, 'organization_id'), position_id: formValue(form, 'position_id'),
        confirmation_password: new FormData(form).get('confirmation_password') };
      if (profileName !== 'Administrador' && (!data.organization_id || !data.position_id)) throw new Error('Selecione a organização e o cargo.');
      await withAction(async () => { const created = await call('invite', data); state.detail = { type: 'user', id: created.user_id }; setNotice(created.message); }, 'Cadastro processado no Supabase.');
    }, 'Criar e convidar');
    $('[name="organization_id"]').value = organizationId;
    $('[name="profile_name"]').addEventListener('change', (event) => { const admin = event.target.value === 'Administrador'; $('[name="organization_id"]').disabled = admin; $('[name="position_id"]').disabled = admin; $('#adminConfirmation').hidden = !admin; $('[name="confirmation_password"]').required = admin; });
  }
  function editUser(user) {
    dialog('Editar pessoa', `<div class="form-grid">${field('full_name', 'Nome completo', user.full_name, 'text', true)}${field('email', 'E-mail de acesso', user.email, 'email', true)}${field('cpf', 'CPF', user.cpf, 'text', false, 'inputmode="numeric"')}${field('phone', 'Telefone', user.phone, 'tel')}</div><p class="hint">O e-mail de login será alterado no Supabase Auth. A senha e outros metadados da conta serão preservados.</p>`, async (form) => {
      await withAction(() => call('update_user', { user_id: user.user_id, full_name: formValue(form, 'full_name'), email: formValue(form, 'email'), cpf: digits(formValue(form, 'cpf')) || null, phone: formValue(form, 'phone') }), 'Cadastro atualizado.');
    });
  }
  async function membershipForm(existing = null, userId = null, orgId = null) {
    const profileSelect = option(state.profiles.filter((p) => ['Auditor Líder', 'Auditor', 'Participante / Auditado'].includes(p.name)));
    const orgSelect = `<option value="">Selecione a organização</option>${option(state.organizations.filter((o) => o.status === 'active'), 'legal_name', false)}`;
    const needsUser = !userId && !existing;
    let userOptions = '';
    if (needsUser) { const result = await state.client.from('user_profiles').select('user_id,full_name,email').eq('status', 'active').order('full_name').limit(500); userOptions = `<option value="">Selecione a pessoa</option>${(unwrap(result) || []).map((u) => `<option value="${html(u.user_id)}">${html(u.full_name || u.email)}</option>`).join('')}`; }
    dialog(existing ? 'Editar vínculo' : 'Novo vínculo', `${needsUser ? select('user_id', 'Pessoa', userOptions, true) : ''}${select('organization_id', 'Organização', orgSelect, true)}<div class="form-grid">${select('position_id', 'Cargo / qualificação', option(state.positions), true)}${select('access_profile_id', 'Perfil de acesso', profileSelect, true)}</div>${select('unit_id', 'Unidade', '<option value="">Toda a organização</option>')}${existing ? select('status', 'Status do vínculo', '<option value="active">Ativo</option><option value="inactive">Inativo</option>', true) : ''}<p class="hint">O documento de identificação deverá ser enviado pelo titular. A alteração de cargo ou perfil reinicia a validação documental. O vínculo não concede participação automática em auditorias.</p>`, async (form) => {
      const record = { organization_id: existing?.organization_id || formValue(form, 'organization_id'), unit_id: formValue(form, 'unit_id') || null, position_id: formValue(form, 'position_id'), access_profile_id: formValue(form, 'access_profile_id') };
      if (existing) record.status = formValue(form, 'status'); else { record.user_id = userId || formValue(form, 'user_id'); record.created_by = state.session.user.id; }
      await withAction(async () => unwrap(existing ? await state.client.from('organization_memberships').update(record).eq('id', existing.id).select('id').single() : await state.client.from('organization_memberships').insert(record).select('id').single()), 'Vínculo salvo. O titular deverá completar a validação.');
    });
    $('[name="organization_id"]').value = existing?.organization_id || orgId || '';
    $('[name="position_id"]').value = existing?.position_id || '';
    $('[name="access_profile_id"]').value = existing?.access_profile_id || '';
    if (existing) $('[name="status"]').value = existing.status;
    const loadUnits = async () => {
      const selectedOrg = $('[name="organization_id"]').value;
      const units = selectedOrg ? (unwrap(await state.client.from('organization_units').select('id,name').eq('organization_id', selectedOrg).eq('status', 'active').order('name')) || []) : [];
      $('[name="unit_id"]').innerHTML = `<option value="">Toda a organização</option>${option(units, 'name', false)}`;
      $('[name="unit_id"]').value = existing?.unit_id || '';
    };
    $('[name="organization_id"]').onchange = () => loadUnits().catch((e) => setNotice(match(e), true)); loadUnits().catch((e) => setNotice(match(e), true));
    if (existing) $('[name="organization_id"]').disabled = true;
  }
  function unitForm(orgId, unit = null) {
    dialog(unit ? 'Editar unidade' : 'Nova unidade', `${field('name', 'Nome da unidade', unit?.name, 'text', true)}${field('location', 'Localização', unit?.location)}${unit ? select('status', 'Status', '<option value="active">Ativa</option><option value="inactive">Inativa</option>', true) : ''}`, async (form) => {
      const record = { name: formValue(form, 'name'), location: formValue(form, 'location') || null };
      if (unit) record.status = formValue(form, 'status'); else { record.organization_id = orgId; record.created_by = state.session.user.id; }
      await withAction(async () => unwrap(unit ? await state.client.from('organization_units').update(record).eq('id', unit.id).select('id').single() : await state.client.from('organization_units').insert(record).select('id').single()), 'Unidade salva.');
    }); if (unit) $('[name="status"]').value = unit.status;
  }
  function contactForm(orgId, contact = null) {
    dialog(contact ? 'Editar contato' : 'Novo contato', `<div class="form-grid">${field('full_name', 'Nome completo', contact?.full_name, 'text', true)}${field('role_title', 'Função', contact?.role_title)}${field('email', 'E-mail', contact?.email, 'email')}${field('phone', 'Telefone', contact?.phone, 'tel')}</div><label class="field"><input name="is_primary" type="checkbox" style="width:auto;min-height:auto" ${contact?.is_primary ? 'checked' : ''}> Contato principal</label>${contact ? select('status', 'Status', '<option value="active">Ativo</option><option value="inactive">Inativo</option>', true) : ''}`, async (form) => {
      const record = { full_name: formValue(form, 'full_name'), role_title: formValue(form, 'role_title') || null, email: formValue(form, 'email') || null, phone: formValue(form, 'phone') || null, is_primary: new FormData(form).get('is_primary') === 'on' };
      if (contact) record.status = formValue(form, 'status'); else { record.organization_id = orgId; record.created_by = state.session.user.id; }
      await withAction(async () => unwrap(contact ? await state.client.from('organization_contacts').update(record).eq('id', contact.id).select('id').single() : await state.client.from('organization_contacts').insert(record).select('id').single()), 'Contato salvo.');
    }); if (contact) $('[name="status"]').value = contact.status;
  }
  async function loadPersonal() {
    const context = unwrap(await state.client.rpc('my_onboarding_context')) || {};
    const profile = context.profile || {}, memberships = context.memberships || [], requests = context.requests || [];
    $('#personalContent').innerHTML = `<div style="padding:22px"><div class="detail-head"><div><h2>${html(profile.full_name || 'Meu cadastro')}</h2><p>${html(profile.email || '')} · ${badge(profile.status)}</p></div>${profile.status === 'active' ? '<button class="button" id="completeProfile">Editar meus dados</button>' : ''}</div>
      <div class="detail-grid"><section class="detail-section"><h3>Dados pessoais</h3><p><strong>CPF:</strong> ${html(profile.cpf || 'Pendente')}</p><p><strong>Telefone:</strong> ${html(profile.phone || '—')}</p><p class="hint">As permissões são atribuídas pelo Administrador. Você não pode escolher seu próprio perfil de acesso.</p></section>
      <section class="detail-section"><h3>Meus vínculos e documentos</h3>${memberships.length ? memberships.map((m) => row(m.organization, `<strong>Cargo:</strong> ${html(m.position || '—')} · <strong>Perfil:</strong> ${html(m.profile || '—')}<br><strong>Vínculo:</strong> ${badge(m.status)} · <strong>Documento:</strong> ${badge(m.document_status || m.competence_status)} ${m.document_note ? `<br><strong>Motivo:</strong> ${html(m.document_note)}` : ''}`, profile.status === 'active' && m.status === 'active' && m.organization_status === 'active' && (!m.document_status || m.document_status === 'rejected') ? `<button class="button secondary small" data-upload="${html(m.id)}">${m.document_status === 'rejected' ? 'Reenviar' : 'Enviar'} documento de identificação</button>` : '')).join('') : '<p>Sua conta ainda não está vinculada a uma organização. Você pode informar a empresa para análise do Administrador.</p>'}</section>
      <section class="detail-section"><h3>Solicitações de vínculo</h3>${profile.status === 'active' ? '<button class="button secondary small" id="requestOrganization">Informar minha organização</button>' : ''}${requests.length ? requests.map((r) => row(r.organization_name, `${badge(r.status)} · ${date(r.created_at)} ${r.review_note ? `· ${html(r.review_note)}` : ''}`)).join('') : '<p>Nenhuma solicitação registrada.</p>'}</section></div>
      <p class="hint">O acesso às auditorias depende de CPF válido, vínculo ativo, documento aprovado e participação autorizada na auditoria.</p></div>`;
    if ($('#completeProfile')) $('#completeProfile').onclick = () => dialog('Completar meus dados', `<div class="form-grid">${field('full_name', 'Nome completo', profile.full_name, 'text', true)}${field('cpf', 'CPF', profile.cpf, 'text', true, 'inputmode="numeric"')}${field('phone', 'Telefone', profile.phone, 'tel')}</div><p class="hint">Após registrar o CPF, sua correção deverá ser solicitada ao Administrador.</p>`, async (form) => {
      await withAction(() => call('complete_self_profile', { full_name: formValue(form, 'full_name'), cpf: digits(formValue(form, 'cpf')), phone: formValue(form, 'phone') }), 'Dados pessoais salvos.');
    });
    $('#personalContent').querySelectorAll('[data-upload]').forEach((b) => b.onclick = () => uploadForm(b.dataset.upload));
    if ($('#requestOrganization')) $('#requestOrganization').onclick = () => dialog('Informar organização', `${field('organization_name', 'Nome da organização', '', 'text', true)}${field('cnpj', 'CNPJ, se disponível', '', 'text', false, 'inputmode="numeric"')}<label class="field">Observação<textarea name="note" placeholder="Unidade ou contato para conferência"></textarea></label><p class="hint">Esta solicitação não libera o acesso. O Administrador validará a empresa e definirá seu perfil.</p>`, async (form) => {
      const record = { user_id: state.session.user.id, organization_name: formValue(form, 'organization_name'), cnpj: digits(formValue(form, 'cnpj')) || null, note: formValue(form, 'note') || null };
      await withAction(async () => unwrap(await state.client.from('organization_access_requests').insert(record).select('id').single()), 'Solicitação enviada ao Administrador.');
    }, 'Enviar solicitação');
  }
  function uploadForm(membershipId) {
    dialog('Enviar documento de identificação', `<p>Escolha um PDF, JPG ou PNG de até 10 MB. O arquivo será analisado pelo Administrador.</p><label class="field">Arquivo *<input name="file" type="file" accept="application/pdf,image/jpeg,image/png" required></label>`, async (form) => {
      const file = new FormData(form).get('file'); if (!(file instanceof File) || !file.size) throw new Error('Selecione um arquivo.');
      const { data: sessionData, error } = await state.client.auth.getSession(); if (error || !sessionData.session) throw new Error('Sessão expirada.');
      const body = new FormData(); body.set('action', 'upload_identity'); body.set('membership_id', membershipId); body.set('file', file);
      await withAction(async () => { const response = await fetch(`${window.AUDITA_PRO_SUPABASE_URL}/functions/v1/user-management`, { method: 'POST', headers: { Authorization: `Bearer ${sessionData.session.access_token}`, apikey: window.AUDITA_PRO_SUPABASE_PUBLISHABLE_KEY }, body }); const payload = await response.json().catch(() => ({})); if (!response.ok) throw new Error(payload.error || 'Falha ao enviar documento.'); }, 'Documento enviado para análise.');
    }, 'Enviar documento');
  }
  $('#logout').addEventListener('click', async () => { if (state.client) await state.client.auth.signOut(); location.replace('audita-pro-login.html'); });
  $('#dialogClose').onclick = closeDialog; $('#dialogCancel').onclick = closeDialog;
  $('#dialogForm').addEventListener('submit', async (event) => {
    event.preventDefault(); if (!state.dialogSubmit) return;
    $('#dialogSubmit').disabled = true;
    try { await state.dialogSubmit(event.currentTarget); }
    catch (error) { $('#dialogError').textContent = match(error); $('#dialogError').hidden = false; }
    finally { $('#dialogSubmit').disabled = false; }
  });
  document.querySelectorAll('[data-tab]').forEach((button) => button.addEventListener('click', () => {
    state.tab = button.dataset.tab; state.page = 0; state.filters = { search: '', status: '', organization: '', profile: '', pending: false };
    document.querySelectorAll('[data-tab]').forEach((b) => b.classList.toggle('selected', b === button));
    closeDetail(); renderFilters(); loadList().catch(showListError);
  }));
  $('#newUser').onclick = () => inviteForm(); $('#newOrganization').onclick = () => organizationForm();
  $('#listContent').addEventListener('click', (event) => {
    const target = event.target.closest('button'); if (!target) return;
    if (target.dataset.user) openDetail('user', target.dataset.user);
    if (target.dataset.organization) openDetail('organization', target.dataset.organization);
    if (target.dataset.document) reviewDocument(target.dataset.document).catch((e) => setNotice(match(e), true));
    if (target.dataset.request) reviewRequest(target.dataset.request).catch((e) => setNotice(match(e), true));
    if (target.dataset.resendInvite) dialog('Reenviar convite', `<p>O sistema tentará enviar novas instruções de acesso e registrará a tentativa.</p>${target.dataset.inviteStatus === 'failed' ? field('confirmation_password', 'Senha de Administrador, se o convite era para esse perfil', '', 'password', false, 'autocomplete="current-password"') : ''}`, async (form) => {
      await withAction(() => call('resend_invite', { invite_id: target.dataset.resendInvite, confirmation_password: new FormData(form).get('confirmation_password') }), 'Tentativa de convite registrada.');
    }, 'Reenviar');
  });
  boot();
})();
