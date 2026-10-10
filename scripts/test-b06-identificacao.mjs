import assert from 'node:assert/strict';
import fs from 'node:fs';
import {Window} from 'happy-dom';

const window=new Window({url:'https://audita.test/audita-pro-auditorias.html'});
window.eval(fs.readFileSync(new URL('../outputs/audita-pro-plan-identification.js',import.meta.url),'utf8'));
const ui=window.AuditaPlanIdentification;
const context={admin:false,user_id:'user-1',organizations:[{id:'org-1',name:'Empresa <Teste>',code:'CLI-0001',cnpj:'00.000.000/0001-00',address:{street:'Rua Um',number:'10',city:'Recife',state:'PE'},can_create:true},{id:'org-2',name:'Empresa Dois',address:{street:'Rua Dois'},can_create:true}],types:[{id:'iso14',code:'ISO 14001',edition:'2015',name:'Ambiental',active:true},{id:'iso45',code:'ISO 45001',edition:'2018',name:'SST',active:true}],templates:[]};

const host=window.document.createElement('form');
host.innerHTML=ui.creationForm(context);
window.document.body.append(host);
let organization='';
ui.bindCreation(host,{context,onOrganization:id=>organization=id});
host.querySelector('[name=organization_id]').value='org-1';
host.querySelector('[name=organization_id]').dispatchEvent(new window.Event('change'));
assert.equal(organization,'org-1');
assert.match(host.querySelector('#newOrgSummary').textContent,/CLI-0001/);
assert.doesNotMatch(host.querySelector('#newOrgSummary').innerHTML,/<Teste>/,'dados do cliente devem ser escapados');
assert.equal(host.querySelector('[name=location]').value,'Rua Um, 10 · Recife · PE');
host.querySelector('[name=organization_id]').value='org-2';host.querySelector('[name=organization_id]').dispatchEvent(new window.Event('change'));
assert.equal(host.querySelector('[name=location]').value,'Rua Dois','nova sugestão deve substituir apenas a sugestão anterior');
host.querySelector('[name=organization_id]').value='org-1';host.querySelector('[name=organization_id]').dispatchEvent(new window.Event('change'));
host.querySelector('[name=location]').value='Local informado pelo condutor';
host.querySelector('[name=organization_id]').dispatchEvent(new window.Event('change'));
assert.equal(host.querySelector('[name=location]').value,'Local informado pelo condutor','troca não deve sobrescrever local digitado');

host.querySelector('[name=type_id]').value='iso14';
host.querySelector('[name=type_id]').dispatchEvent(new window.Event('change'));
const primaryDuplicate=host.querySelector('[name=additional_criteria][value=iso14]');
assert.equal(primaryDuplicate.disabled,true,'critério principal não pode ser duplicado como adicional');
host.querySelector('[name=additional_criteria][value=iso45]').checked=true;
host.querySelector('[name=title]').value='Auditoria integrada';
host.querySelector('[name=scope]').value='Duas normas';
assert.equal(JSON.stringify(ui.creationPayload(host).criterion_ids),JSON.stringify(['iso14','iso45']));

const edit=window.document.createElement('form');
const record={audit_id:'audit-1',lock_version:7,title:'Plano',party:'first',modality:'hybrid',evaluation_type:'other',evaluation_other:'Avaliação especial',criterion_ids:['iso14'],participants_text:'N/A',comments:'N/A'};
edit.innerHTML=ui.editingForm(record,context.types,[]);
assert.equal(edit.querySelectorAll('.field-hint').length,2);
assert.match(edit.textContent,/Caso não se aplique, informar “N\/A”\./);
const edited=ui.editingPayload(edit,record);
assert.equal(edited.expected_lock_version,7);
assert.equal(edited.evaluation_other,'Avaliação especial');
assert.equal(JSON.stringify(edited.criterion_ids),JSON.stringify(['iso14']));
assert.equal('lock_version' in edited,false);

const summary=ui.summary({audit:{code:'AUD-2026-0001',party:'first',modality:'remote',location:'Rua Um',objective:'Objetivo',scope:'Escopo',criteria:'Legal',standards:['ISO 14001:2004']},company:{name:'Cliente'},criteria:context.types});
assert.match(summary,/ISO 14001:2004/);
assert.doesNotMatch(summary,/ISO 14001 · 2015/,'resumo deve preservar edição congelada');
assert.match(summary,/1ª parte/);

const requests=ui.latestRequest();
const first=requests.start(),second=requests.start();
assert.equal(requests.isCurrent(first),false,'resposta antiga deve ser descartada');
assert.equal(requests.isCurrent(second),true);

const pending=new Map(),applied=[],errors=[];
const sequence=ui.latestRequest();
const fetcher=id=>new Promise((resolve,reject)=>pending.set(id,{resolve,reject}));
const hooks={success:value=>applied.push(value),error:value=>errors.push(value.message)};
const oldLoad=ui.loadLatestOrganization(sequence,'org-antiga',fetcher,hooks);
const newLoad=ui.loadLatestOrganization(sequence,'org-nova',fetcher,hooks);
pending.get('org-nova').resolve('nova');await newLoad;
pending.get('org-antiga').resolve('antiga');await oldLoad;
assert.deepEqual(applied,['nova'],'resposta atrasada da organização antiga não pode trocar unidade/condutor');
const failed=ui.loadLatestOrganization(sequence,'org-erro',fetcher,hooks);
pending.get('org-erro').reject(new Error('Falha de contexto'));await failed;
assert.deepEqual(errors,['Falha de contexto']);

// Integração do diálogo real de audits.js: concorrência, erro e nova tentativa.
window.document.body.innerHTML='<h1 id="auditTitle"></h1><p id="auditIntro"></p><div id="auditActions"></div><div id="auditNotice"></div><section id="auditContent"></section>';
window.HTMLDialogElement.prototype.showModal=function(){this.open=true;};
window.HTMLDialogElement.prototype.close=function(){this.open=false;};
const orgCalls=[];
window.AUDITA_PRO_REQUIRE_SESSION=async()=>({client:{rpc:async(name,args)=>{
 if(name==='audit_workspace'&&args.command==='context'&&!args.payload?.organization_id)return {data:context,error:null};
 if(name==='audit_workspace'&&args.command==='list')return {data:{items:[],total:0},error:null};
 if(name==='audit_workspace'&&args.command==='context')return await new Promise(resolve=>orgCalls.push({org:args.payload.organization_id,resolve}));
 throw new Error(`RPC inesperado: ${name}/${args.command}`);
}}});
window.eval(fs.readFileSync(new URL('../outputs/audita-pro-audits.js',import.meta.url),'utf8'));
window.document.dispatchEvent(new window.Event('DOMContentLoaded'));
await new Promise(resolve=>setTimeout(resolve,0));
window.document.querySelector('[data-action=new]').click();
await new Promise(resolve=>setTimeout(resolve,0));
const dialog=window.document.querySelector('#auditDialog'),orgSelect=dialog.querySelector('[name=organization_id]'),submit=dialog.querySelector('[type=submit]');
orgSelect.value='org-1';orgSelect.dispatchEvent(new window.Event('change'));
orgSelect.value='org-2';orgSelect.dispatchEvent(new window.Event('change'));
assert.equal(submit.disabled,true);assert.equal(dialog.querySelector('#newTemplate').textContent,'');
orgCalls[1].resolve({data:{members:[{id:'member-2',user_id:'user-1',name:'Líder 2',eligible:true}],units:[{id:'unit-2',name:'Unidade 2'}]},error:null});
await new Promise(resolve=>setTimeout(resolve,0));
assert.match(dialog.querySelector('#newOrgFields').textContent,/Líder 2/);assert.equal(submit.disabled,false);
orgCalls[0].resolve({data:{members:[{id:'stale',user_id:'user-1',name:'Antigo',eligible:true}],units:[]},error:null});
await new Promise(resolve=>setTimeout(resolve,0));
assert.doesNotMatch(dialog.querySelector('#newOrgFields').textContent,/Antigo/);
orgSelect.value='org-1';orgSelect.dispatchEvent(new window.Event('change'));
orgCalls[2].resolve({data:null,error:{message:'Contexto indisponível'}});await new Promise(resolve=>setTimeout(resolve,0));
assert.equal(submit.disabled,true);assert.match(dialog.querySelector('#auditDialogError').textContent,/Contexto indisponível/);assert.equal(dialog.querySelector('#newTemplate').textContent,'');
orgSelect.dispatchEvent(new window.Event('change'));
orgCalls[3].resolve({data:{members:[{id:'member-1',user_id:'user-1',name:'Líder 1',eligible:true}],units:[]},error:null});await new Promise(resolve=>setTimeout(resolve,0));
assert.equal(submit.disabled,false);assert.match(dialog.querySelector('#newOrgFields').textContent,/Líder 1/);

console.log('B06 identificação: criação integrada, hints N/A, lock otimista e resumo validados.');
