// Modelo "plan" v1 — PDF oficial do Plano de Auditoria (planejamento §14). Usa somente o retrato congelado da revisão
// (private.b09_snapshot): nunca relê cadastro. Estrutura: identificação e equipe → cronograma (5 colunas) → escopo →
// comentários e controle da revisão → página final dedicada às Notas (Anexo A, texto integral).
import type { Block, DocModel } from '../pdf/layout.ts';
import type { Inline } from '../pdf/text.ts';

type Any = Record<string, any>;
const s = (v: unknown) => (v === null || v === undefined ? '' : String(v));
const dash = (v: unknown) => s(v).trim() || '—';

export function brDateOnly(v: unknown): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s(v));
  return m ? `${m[3]}/${m[2]}/${m[1]}` : '—';
}
export function brDateTime(v: unknown): string {
  const t = Date.parse(s(v));
  if (Number.isNaN(t)) return '—';
  const d = new Date(t - 3 * 3600000); // America/Sao_Paulo (UTC−3, sem horário de verão)
  const p = (n: number) => String(n).padStart(2, '0');
  return `${p(d.getUTCDate())}/${p(d.getUTCMonth() + 1)}/${d.getUTCFullYear()} ${p(d.getUTCHours())}:${p(d.getUTCMinutes())}`;
}
function cnpj(v: unknown): string {
  const d = s(v).replace(/\D/g, '');
  return d.length === 14 ? `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5, 8)}/${d.slice(8, 12)}-${d.slice(12)}` : dash(v);
}

function activityCell(r: Any): Inline[] {
  const parts: Inline[] = [{ text: dash(r.title), bold: true }];
  if (r.category && r.category !== 'assessment' && s(r.category_label).trim() !== s(r.title).trim()) parts.push(`\n${s(r.category_label)}`);
  if (s(r.process).trim() && s(r.process).trim() !== s(r.title).trim()) parts.push(`\nProcesso: ${s(r.process)}`);
  const refs = (r.requirement_refs ?? []) as Any[];
  if (refs.length) {
    const byCrit = new Map<string, string[]>();
    for (const q of refs) byCrit.set(s(q.criterion) || 'Critério', [...(byCrit.get(s(q.criterion) || 'Critério') ?? []), s(q.reference)]);
    parts.push({ text: `\nRequisitos: ${[...byCrit].map(([c, list]) => `${list.join(', ')} (${c})`).join('; ')}`, italic: true });
  }
  if (s(r.remaining_summary).trim()) parts.push({ text: `\nContinuidade: ${s(r.remaining_summary)}`, italic: true });
  if (s(r.notes).trim()) parts.push(`\nObs.: ${s(r.notes)}`);
  return parts;
}

export function planDoc(c: Any, opts: { draft?: boolean } = {}): DocModel {
  const audit = c.audit ?? {}, client = c.client ?? {}, h = c.header ?? {}, rev = c.revision ?? {};
  const code = dash(audit.code), label = dash(rev.label);
  const criteria = ((h.criteria ?? []) as Any[]).map(x => `${s(x.code)}${s(x.edition) ? `:${s(x.edition)}` : ''}`).join(' · ') || '—';
  const blocks: Block[] = [];

  blocks.push({ type: 'heading', text: '1. Identificação' });
  blocks.push({ type: 'fields', columns: 2, items: [
    { label: 'Cliente', value: dash(client.legal_name) }, { label: 'Código do cliente', value: dash(client.code) },
    { label: 'CNPJ', value: cnpj(client.cnpj) }, { label: 'Código da auditoria', value: code },
    { label: 'Endereço', value: dash(client.address) }, { label: 'Localização', value: [s(h.location), s(h.unit)].filter(Boolean).join(' — ') || '—' },
    { label: 'Período', value: `${brDateOnly(h.start_date)} a ${brDateOnly(h.end_date)}` }, { label: 'Norma / critério', value: criteria },
    { label: 'Natureza', value: dash(h.party) }, { label: 'Tipo de avaliação', value: dash(h.evaluation) },
    { label: 'Modalidade', value: dash(h.modality) }, { label: 'Revisão', value: label },
  ] });
  blocks.push({ type: 'paragraph', text: [{ text: 'Objetivo da auditoria: ', bold: true }, dash(h.objective)] });

  blocks.push({ type: 'heading', text: '2. Equipe auditora' });
  blocks.push({ type: 'table', columns: [{ label: 'Nome', width: 0.65 }, { label: 'Função na auditoria', width: 0.35 }],
    rows: ((c.team ?? []) as Any[]).map(t => [s(t.name), s(t.role)]), empty: 'Equipe não informada.' });
  blocks.push({ type: 'paragraph', text: [{ text: 'Outros participantes em nome da AUDITA: ', bold: true }, dash(h.participants_text)] });

  blocks.push({ type: 'heading', text: '3. Cronograma' });
  blocks.push({ type: 'table', title: 'Cronograma da auditoria', size: 8.2, columns: [
    { label: 'Localização', width: 0.15 }, { label: 'Data', width: 0.11 }, { label: 'Horário', width: 0.13 },
    { label: 'Área / Departamento / Funções / Processos / Aspectos / Atividades', width: 0.39 }, { label: 'Auditor', width: 0.22 }],
    rows: ((c.schedule ?? []) as Any[]).map(r => [dash(r.location), `${brDateOnly(r.date)}\nDia ${s(r.day_number) || '—'}`,
      `${s(r.start_time)}–${s(r.end_time)}`, activityCell(r), ((r.assignees ?? []) as string[]).join('\n') || '—']),
    empty: 'Nenhuma atividade programada.' });

  blocks.push({ type: 'heading', text: '4. Escopo da auditoria' });
  blocks.push({ type: 'paragraph', text: dash(h.scope) });

  blocks.push({ type: 'heading', text: '5. Comentários e controle da revisão' });
  blocks.push({ type: 'paragraph', text: [{ text: 'Comentários: ', bold: true }, dash(h.comments)] });
  const fpa = c.fpa ?? null;
  blocks.push({ type: 'fields', columns: 1, items: [
    { label: 'Revisão', value: `${label} — ${brDateTime(rev.at)} — ${dash(rev.author)}` },
    { label: 'Motivo', value: dash(rev.reason) },
    { label: 'FPA de referência', value: fpa && fpa.version_number
      ? `Versão ${s(fpa.version_number)}, recebida em ${brDateOnly(fpa.received_on)}; analisada como suficiente em ${brDateTime(fpa.analyzed_at)} por ${dash(fpa.analyzed_by)}`
      : 'Não registrado' },
  ] });
  const history = [...((c.history ?? []) as Any[]), { label: rev.label, at: rev.at, author: rev.author, reason: rev.reason }];
  blocks.push({ type: 'table', title: 'Controle de revisões', columns: [{ label: 'Revisão', width: 0.14 }, { label: 'Data/hora', width: 0.18 },
    { label: 'Responsável', width: 0.24 }, { label: 'Motivo', width: 0.44 }],
    rows: history.map(x => [dash(x.label), brDateTime(x.at), dash(x.author), dash(x.reason)]) });
  blocks.push({ type: 'paragraph', size: 8.4, muted: true, italic: true,
    text: 'O histórico completo das revisões permanece disponível no Audita PRO. Revisões anteriores são preservadas e identificadas como substituídas.' });

  blocks.push({ type: 'page_break' });
  blocks.push({ type: 'heading', text: 'Notas' });
  blocks.push({ type: 'list', items: ((c.notes ?? []) as string[]).map(n => {
    const i = n.indexOf(' - ');
    return i > 0 ? [{ text: n.slice(0, i), bold: true }, n.slice(i)] : n;
  }) });

  return {
    meta: { title: `Plano de Auditoria ${code} ${label}`, subject: `Plano de Auditoria — ${dash(client.legal_name)}`, author: 'AUDITA', issued_at: s(rev.at) || new Date().toISOString() },
    header: { title: 'PLANO DE AUDITORIA', subtitle: `AUDITA · ${dash(client.legal_name)}`, right: [code, label, `Emitido em ${brDateTime(rev.at)}`], logo: 'logo' },
    footer: { left: `AUDITA | Plano de Auditoria\n${code} | ${label}` },
    draft: !!opts.draft,
    blocks,
  };
}
