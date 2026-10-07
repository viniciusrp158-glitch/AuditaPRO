/* Public browser configuration: only the Supabase URL and publishable key belong here. */
window.AUDITA_PRO_SUPABASE_URL = 'https://zlckcpeqcxmtrgbdquee.supabase.co';
window.AUDITA_PRO_SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_anLb76sxpU4c1o3pvdLXfw_lrMDduJB';

window.createAuditaProClient = function () {
  if (!window.supabase?.createClient) throw new Error('Biblioteca Supabase não carregada.');
  if (!window.AUDITA_PRO_SUPABASE_PUBLISHABLE_KEY.startsWith('sb_publishable_')) {
    throw new Error('Chave publishable do Supabase ainda não configurada.');
  }
  return window.supabase.createClient(
    window.AUDITA_PRO_SUPABASE_URL,
    window.AUDITA_PRO_SUPABASE_PUBLISHABLE_KEY,
    { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } }
  );
};

window.AUDITA_PRO_SAFE_NEXT = function () {
  const requested = new URLSearchParams(location.search).get('next') || 'audita-pro-dashboard.html';
  const allowed = new Set(['audita-pro-execution.html', 'audita-pro-checklists.html', 'audita-pro-auditorias.html', 'audita-pro-notificacoes.html', 'audita-pro-perfil.html', 'audita-pro-dashboard.html', 'audita-pro-relatorio-diario.html', 'audita-pro-cadastro.html', 'audita-pro-historico.html']);
  return allowed.has(requested) ? requested : 'audita-pro-dashboard.html';
};

window.AUDITA_PRO_REQUIRE_SESSION = async function () {
  const client = window.createAuditaProClient();
  const { data, error } = await client.auth.getSession();
  if (error || !data.session) {
    const next = encodeURIComponent(location.pathname.split('/').pop() || 'audita-pro-relatorio-diario.html');
    location.replace(`audita-pro-login.html?next=${next}`);
    return null;
  }
  const page = location.pathname.split('/').pop();
  if (!['audita-pro-perfil.html','audita-pro-notificacoes.html','audita-pro-login.html'].includes(page)) {
    const result = await client.rpc('profile_command', { command: 'context', payload: {} });
    if (result.error) throw result.error;
    if (!result.data.admin && !result.data.memberships.some(member => member.ready)) {
      location.replace('audita-pro-perfil.html'); return null;
    }
  }
  const sessionContext = { client, session: data.session };
  if (window.AUDITA_PRO_MOUNT_HEADER) await window.AUDITA_PRO_MOUNT_HEADER(sessionContext);
  return sessionContext;
};

window.AUDITA_PRO_PROTECT_PAGE = async function () {
  document.documentElement.style.visibility = 'hidden';
  try {
    const auth = await window.AUDITA_PRO_REQUIRE_SESSION();
    if (!auth) return;
    document.documentElement.style.visibility = '';
  } catch (error) {
    document.documentElement.style.visibility = '';
    document.body.innerHTML = `<main style="font:16px Segoe UI,Arial,sans-serif;max-width:620px;margin:12vh auto;padding:28px;color:#183047"><h1>Não foi possível validar a sessão</h1><p>Confira a configuração do projeto Supabase e tente novamente.</p><a href="audita-pro-login.html">Ir para o login</a></main>`;
  }
};
