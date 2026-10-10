/* Presentation only. Server-side B02 authorization remains authoritative. */
(() => {
  'use strict';
  let sidebar, nav, toggle;
  const page = () => location.pathname.split('/').pop();
  function setOpen(open) {
    if (!nav || !toggle) return;
    nav.hidden = !open;
    toggle.setAttribute('aria-expanded', String(open));
    toggle.textContent = open ? 'Recolher menu' : 'Abrir menu';
  }
  function mount() {
    sidebar = document.querySelector('aside.side, aside.sidebar');
    nav = sidebar?.querySelector('nav');
    if (!nav || toggle) return;
    sidebar.classList.add('ap-navigation');
    nav.id ||= 'apPrimaryNavigation';
    nav.setAttribute('aria-label', 'Navegação principal');
    toggle = document.createElement('button');
    toggle.type = 'button';
    toggle.className = 'ap-nav-toggle';
    toggle.setAttribute('aria-controls', nav.id);
    sidebar.insertBefore(toggle, nav);
    toggle.addEventListener('click', () => setOpen(nav.hidden));
    sidebar.addEventListener('keydown', event => {
      if (event.key === 'Escape' && !nav.hidden && nav.contains(event.target)) {
        setOpen(false); toggle.focus();
      }
    });
    const narrow = window.matchMedia('(max-width: 700px)');
    setOpen(!narrow.matches);
    narrow.addEventListener('change', event => setOpen(!event.matches));
    for (const link of nav.querySelectorAll('a')) {
      const target = new URL(link.getAttribute('href'), location.href).pathname.split('/').pop();
      if (target === page()) link.setAttribute('aria-current', 'page');
      else link.removeAttribute('aria-current');
      // Never display restricted navigation before the server responds.
      if (RESTRICTED.has(target)) link.hidden = true;
      // The system history lives inside the library (B05/RS-07): highlight the library entry there.
      if (page() === 'audita-pro-historico.html' && target === 'audita-pro-biblioteca.html') link.setAttribute('aria-current', 'page');
    }
  }
  const RESTRICTED = new Set(['audita-pro-cadastro.html', 'audita-pro-biblioteca.html']);
  let navigationRequest = 0;
  const setLink = (target, visible) => {
    for (const link of nav?.querySelectorAll('a') || []) {
      if (new URL(link.getAttribute('href'), location.href).pathname.split('/').pop() === target) link.hidden = !visible;
    }
  };
  // context: profile_command('context') do servidor; client: cliente Supabase autenticado.
  window.AUDITA_PRO_UPDATE_NAVIGATION = async (context, client) => {
    mount();
    const request = ++navigationRequest;
    setLink('audita-pro-cadastro.html', context?.admin === true);
    if (!context || !client) { setLink('audita-pro-biblioteca.html', false); return; }
    try {
      const { data, error } = await client.rpc('corporate_library', { command: 'context', payload: {} });
      if (request !== navigationRequest) return;
      // D07/V-07: Admin, Auditor Líder e Auditor; Participante não recebe a biblioteca corporativa.
      setLink('audita-pro-biblioteca.html', !error && data?.can_read === true);
    } catch {
      if (request === navigationRequest) setLink('audita-pro-biblioteca.html', false);
    }
  };
  // O cabeçalho pode ter recebido o contexto antes deste módulo (script defer): aplicar o último estado.
  const init = () => { mount(); const last = window.AUDITA_PRO_NAV_STATE; if (last) window.AUDITA_PRO_UPDATE_NAVIGATION(last.context, last.client); };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
