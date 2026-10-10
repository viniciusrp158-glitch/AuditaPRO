// Registro de modelos documentais versionados. O pedido fixa (modelo, versão); retentativas usam exatamente o mesmo.
// B09 acrescenta "plan", B10–B12 acrescentam "rda" — sem remover versões que ainda tenham pedidos abertos.
import { type DocModel, RenderError } from '../pdf/layout.ts';
import { specimen } from './specimen.ts';
import { planDoc } from './plan.ts';

export type AssetRef =
  | { source: 'builtin'; id: string }
  | { source: 'generated'; id: 'sample-png' }
  | { source: 'storage'; bucket: string; path: string; sha256?: string };
export type TemplateContext = { title: string; revision_label: string | null; version_id: string; requested_at: string };
export type TemplateOutput = { doc: DocModel; assets: Record<string, AssetRef> };
type Template = (content: Record<string, unknown>, ctx: TemplateContext) => TemplateOutput;

const SPECIMEN_ASSETS: Record<string, AssetRef> = {
  logo: { source: 'builtin', id: 'builtin:logo' },
  sample: { source: 'generated', id: 'sample-png' },
};

export const TEMPLATES: Record<string, Record<number, Template>> = {
  plan: {
    1: content => ({ doc: planDoc(content), assets: { logo: { source: 'builtin', id: 'builtin:logo' } } }),
  },
  specimen: {
    1: (content, ctx) => {
      const { doc, assets } = specimen((content.params ?? {}) as Record<string, never>, {
        issued_at: String(content.issued_at ?? ctx.requested_at), version_label: ctx.revision_label ?? 'Rev.00', code: String(content.code ?? 'PROVA'),
      });
      return { doc, assets: Object.fromEntries(assets.map(k => [k, SPECIMEN_ASSETS[k]])) };
    },
  },
};

export function resolveTemplate(key: string, version: number): Template {
  const t = TEMPLATES[key]?.[version];
  if (!t) throw new RenderError(`Modelo ${key} v${version} indisponível neste emissor.`);
  return t;
}
