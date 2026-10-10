// B06: validação do conteúdo dos arquivos de FPA (PDF/DOCX/XLSX) com arquivos reais gerados.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const { detectFormat } = await import('../outputs/audita-pro-supabase/supabase/functions/audit-fpa-files/office.ts');
const dir = mkdtempSync(join(tmpdir(), 'b06-'));
const make = (name, script) => { const p = join(dir, name); execFileSync('python3', ['-I', '-c', script, p]); return new Uint8Array(readFileSync(p)); };
const ct = main => `import sys,zipfile
with zipfile.ZipFile(sys.argv[1],'w',zipfile.ZIP_DEFLATED) as z:
  z.writestr('[Content_Types].xml','<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Override PartName="/xl/workbook.xml" ContentType="${main}"/></Types>')
  z.writestr('xl/workbook.xml','<workbook/>')`;
const cases = [
  ['XLSX válido', make('a.xlsx', ct('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml')), 'xlsx'],
  ['XLSM (macro) recusado', make('m.xlsx', ct('application/vnd.ms-excel.sheet.macroEnabled.main+xml')), null],
  ['DOTX recusado na FPA', make('t.docx', ct('application/vnd.openxmlformats-officedocument.wordprocessingml.template.main+xml')), null],
  ['DOCX válido', make('d.docx', ct('application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml')), 'docx'],
  ['PDF válido', new TextEncoder().encode('%PDF-1.7\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF\n'), 'pdf'],
  ['PDF truncado', new TextEncoder().encode('%PDF-1.7\n1 0 obj\n<<'), null],
];
let n = 0;
for (const [name, bytes, expected] of cases) {
  let got; try { got = (await detectFormat(bytes)).format; } catch { got = null; }
  assert.equal(got, expected, name); console.log(`ok  ${name}`); n++;
}
console.log(`---- ${n}/${cases.length} casos de conteúdo da FPA aprovados`);
