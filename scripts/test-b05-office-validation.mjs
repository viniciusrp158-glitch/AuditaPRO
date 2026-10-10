// B05/CA-10: validação do conteúdo real dos arquivos (Node 22+ com tsx; mesmo módulo usado pela Edge Function).
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const globalRoot = execFileSync('npm', ['root', '-g']).toString().trim();
const { PDFDocument } = require(join(globalRoot, 'pdf-lib'));
const docx = require(join(globalRoot, 'docx'));
const { detectFormat, sha256Hex, safeFilename } = await import('../outputs/audita-pro-supabase/supabase/functions/corporate-library-files/office.ts');
const dir = mkdtempSync(join(tmpdir(), 'b05-'));
const zipEdit = (src, dst, script) => { execFileSync('python3', ['-I', '-c', script, src, dst]); return new Uint8Array(readFileSync(dst)); };
const results = [];
async function check(name, bytes, expected) {
  try { const r = await detectFormat(bytes); assert.equal(r.format, expected); results.push([name, true, r.format]); }
  catch (e) { const ok = expected === null; results.push([name, ok, e.message]); if (!ok) console.error(e); }
}
const pdf = await PDFDocument.create(); pdf.addPage().drawText('Audita PRO teste');
const pdfBytes = await pdf.save();
await check('PDF válido', pdfBytes, 'pdf');
await check('PDF truncado', pdfBytes.subarray(0, Math.floor(pdfBytes.length * 0.6)), null);
const d = new docx.Document({ sections: [{ children: [new docx.Paragraph('Procedimento de teste')] }] });
const docxBytes = new Uint8Array(await docx.Packer.toBuffer(d)); writeFileSync(join(dir, 'a.docx'), docxBytes);
await check('DOCX válido', docxBytes, 'docx');
const dotx = zipEdit(join(dir, 'a.docx'), join(dir, 'a.dotx'), `import sys,zipfile
src,dst=sys.argv[1:3]
with zipfile.ZipFile(src) as z, zipfile.ZipFile(dst,'w',zipfile.ZIP_DEFLATED) as o:
  for i in z.infolist():
    data=z.read(i.filename)
    if i.filename=='[Content_Types].xml': data=data.replace(b'wordprocessingml.document.main+xml',b'wordprocessingml.template.main+xml')
    o.writestr(i,data)`);
await check('DOTX válido', dotx, 'dotx');
const macro = zipEdit(join(dir, 'a.docx'), join(dir, 'm.docx'), `import sys,zipfile
src,dst=sys.argv[1:3]
with zipfile.ZipFile(src) as z, zipfile.ZipFile(dst,'w',zipfile.ZIP_DEFLATED) as o:
  for i in z.infolist(): o.writestr(i,z.read(i.filename))
  o.writestr('word/vbaProject.bin',b'\\x00'*64)`);
await check('DOCX com macro (vbaProject.bin)', macro, null);
const docm = zipEdit(join(dir, 'a.docx'), join(dir, 'a.docm'), `import sys,zipfile
src,dst=sys.argv[1:3]
with zipfile.ZipFile(src) as z, zipfile.ZipFile(dst,'w',zipfile.ZIP_DEFLATED) as o:
  for i in z.infolist():
    data=z.read(i.filename)
    if i.filename=='[Content_Types].xml': data=data.replace(b'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml',b'application/vnd.ms-word.document.macroEnabled.main+xml')
    o.writestr(i,data)`);
await check('DOCM renomeado para .docx', docm, null);
const plainZip = zipEdit(join(dir, 'a.docx'), join(dir, 'z.zip'), `import sys,zipfile
with zipfile.ZipFile(sys.argv[2],'w') as o: o.writestr('leia.txt','oi')`);
await check('ZIP qualquer', plainZip, null);
await check('Executável renomeado', new Uint8Array([0x4d, 0x5a, 0x90, 0, 3, 0, 0, 0]), null);
await check('DOCX truncado', docxBytes.subarray(0, Math.floor(docxBytes.length / 2)), null);
await check('Vazio', new Uint8Array(), null);
await check('Acima de 20 MB', new Uint8Array(20 * 1024 * 1024 + 1), null);
assert.equal(await sha256Hex(new TextEncoder().encode('abc')), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
assert.equal(safeFilename('Proc../x:y', 'pdf'), 'Proc.._x_y.pdf');
for (const [n, ok, info] of results) console.log(`${ok ? 'ok  ' : 'FALHA'} ${n} → ${info}`);
assert.ok(results.every(r => r[1]), 'há casos de validação com falha');
console.log(`---- ${results.length}/${results.length} casos de conteúdo aprovados`);
