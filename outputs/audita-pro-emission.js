/* B08 — Cliente do emissor documental (Edge Function document-emission).
   O navegador só pede, acompanha e baixa: o PDF é gerado, conferido e guardado no servidor.
   Fechar a página não perde a emissão: a varredura do servidor retoma pedidos pendentes. */
(() => {
  'use strict';
  const STATUS = { pending: 'Na fila', processing: 'Gerando', failed: 'Falhou', ready: 'Pronto para conferência', published: 'Emitido' };

  async function call(client, body) {
    const { data: { session } } = await client.auth.getSession();
    if (!session) throw new Error('Sessão encerrada. Entre novamente.');
    let response;
    try {
      response = await fetch(`${window.AUDITA_PRO_SUPABASE_URL}/functions/v1/document-emission`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${session.access_token}`, apikey: window.AUDITA_PRO_SUPABASE_PUBLISHABLE_KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
    } catch { throw new Error('Sem conexão com o emissor. O pedido continua registrado e será retomado pelo servidor.'); }
    let data = {};
    try { data = await response.json(); } catch { /* sem corpo */ }
    if (!response.ok) throw new Error(data.error || 'O emissor não respondeu corretamente.');
    return data;
  }

  async function list(client, auditId) {
    const { data, error } = await client.rpc('document_emission', { command: 'list', payload: auditId ? { audit_id: auditId } : {} });
    if (error) throw new Error(error.message || 'Falha ao listar documentos emitidos.');
    return data || [];
  }

  async function download(client, emissionId) {
    const r = await call(client, { action: 'download', emission_id: emissionId });
    const a = document.createElement('a'); a.href = r.url; a.download = r.filename; a.rel = 'noopener';
    document.body.append(a); a.click(); a.remove();
    return r;
  }

  /** Acompanha um pedido até sair da fila (até ~2 min); depois disso a varredura do servidor continua. */
  async function watch(client, emissionId, onUpdate, { interval = 3000, timeout = 120000 } = {}) {
    const end = Date.now() + timeout;
    for (;;) {
      const s = await call(client, { action: 'status', emission_id: emissionId });
      onUpdate?.(s);
      if (!['pending', 'processing'].includes(s.status) || Date.now() > end) return s;
      await new Promise(r => setTimeout(r, interval));
    }
  }

  const label = s => STATUS[s] || s;
  window.AuditaEmission = { call, list, download, watch, label, STATUS };
})();
