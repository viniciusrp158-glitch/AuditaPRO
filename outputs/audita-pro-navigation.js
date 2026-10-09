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
      // Never display administrative navigation before the server responds.
      if (target === 'audita-pro-cadastro.html') link.hidden = true;
    }
  }
  window.AUDITA_PRO_UPDATE_NAVIGATION = context => {
    mount();
    for (const link of nav?.querySelectorAll('a') || []) {
      const target = new URL(link.getAttribute('href'), location.href).pathname.split('/').pop();
      if (target === 'audita-pro-cadastro.html') {
        link.hidden = context?.admin !== true;
      }
    }
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', mount);
  else mount();
})();
