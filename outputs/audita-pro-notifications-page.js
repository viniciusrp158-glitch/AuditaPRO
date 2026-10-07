window.addEventListener('DOMContentLoaded', async () => {
 try { await window.AUDITA_PRO_REQUIRE_SESSION(); }
 catch { const root=document.querySelector('#notificationCenter');root.innerHTML='<div class="ap-notice-empty">Não foi possível carregar as notificações. <button type="button" id="retryNotifications">Tentar novamente</button></div>';document.querySelector('#retryNotifications').onclick=()=>location.reload(); }
});
