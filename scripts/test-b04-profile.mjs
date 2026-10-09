import assert from 'node:assert/strict';
import fs from 'node:fs';
import {Window} from 'happy-dom';

const source=fs.readFileSync(new URL('../outputs/audita-pro-profile.js',import.meta.url),'utf8');
const tick=()=>new Promise(resolve=>setTimeout(resolve,25));
const professional={unit_id:'unit-1',position_id:'position-1',function:'Qualidade',department:'Operações',manager:'Gestora',manager_contact:'gestora@example.test'};

function submission(state='approved',readonly=true,requiredTypes=[]){return {id:'submission-1',membership_id:'member-1',user_id:'user-1',state,version:1,updated_at:'2026-10-09T00:00:00Z',reviewed_at:'2026-10-09T00:00:00Z',reviewer_name:'Admin',organization:'Cliente',profile_name:'Participante / Auditado',email:'pessoa@example.test',...(readonly===undefined?{}:{participant_functional_readonly:readonly}),personal:{full_name:'Pessoa Teste',cpf:'000.000.000-00',phone:'1111'},professional:{...professional},units:[{id:'unit-1',name:'Matriz'},{id:'unit-2',name:'Filial'}],required_types:requiredTypes,documents:[],history:[]};}

function accountSubmission(){return {...submission('draft',false),id:'account-submission',membership_id:null,organization:null,profile_name:null,professional:{},units:[],required_types:[]};}

function context(readonly=true){return {admin:false,profile:{email:'pessoa@example.test',phone:'1111'},positions:[{id:'position-1',name:'Analista'},{id:'position-2',name:'Gerente'}],memberships:[{id:'member-1',organization_id:'org-1',organization:'Cliente',profile:'Participante / Auditado',ready:true,participant_functional_readonly:readonly,professional_data:{...professional}}],requests:[]};}

async function setup({readonly=true,currentFlag=readonly,state='approved',requiredTypes=[]}={}){
  const calls=[];
  let ctx=context(readonly), current=submission(state,currentFlag,requiredTypes);
  const rpc=async(_name,{command,payload})=>{
    calls.push({command,payload:structuredClone(payload)});
    if(command==='context')return {data:structuredClone(ctx)};
    if(command==='open')return {data:structuredClone(payload.membership_id?current:accountSubmission())};
    if(command==='new_revision'){
      current={...submission('draft',readonly,requiredTypes),version:2};
      return {data:structuredClone(current)};
    }
    if(command==='save'){
      current={...current,personal:structuredClone(payload.personal),professional:structuredClone(payload.professional),updated_at:'2026-10-09T00:01:00Z'};
      return {data:structuredClone(current)};
    }
    if(command==='update_contacts'){
      ctx={...ctx,profile:{...ctx.profile,phone:payload.phone}};
      return {data:{message:'Contatos salvos.'}};
    }
    if(command==='search_organizations')return {data:[]};
    throw new Error(`Comando inesperado: ${command}`);
  };
  const window=new Window({url:'https://test.local/audita-pro-perfil.html'});
  window.document.write('<div id="profileTitle"></div><div id="profileIntro"></div><div id="notice" hidden></div><div id="profileContent"></div><span id="accountEmail"></span><button id="logout"></button>');
  window.AUDITA_PRO_REQUIRE_SESSION=async()=>({client:{rpc,auth:{signOut:async()=>{}},storage:{from:()=>({createSignedUrl:async()=>({data:{signedUrl:'https://test.local/file'}})})}},session:{user:{id:'user-1'}}});
  window.eval(source);
  await tick();
  return {window,calls};
}

async function click(window,selector){const element=window.document.querySelector(selector);assert.ok(element,`Elemento ausente: ${selector}`);element.click();await tick();}

const approved=await setup({currentFlag:undefined});
assert.equal(approved.window.document.querySelector('#searchOrg'),null,'participante aprovado não deve pesquisar organizações');
assert.match(approved.window.document.body.textContent,/procure o Administrador/i);
for(const key of ['function','department','manager','manager_contact'])assert.equal(approved.window.document.querySelector(`#contactFields [data-key="${key}"]`).readOnly,true,`${key} deve ser somente leitura`);
approved.window.document.querySelector('#contactFields [data-key="phone"]').value='2222';
approved.window.document.querySelector('#contactFields [data-key="function"]').value='Valor adulterado';
await click(approved.window,'#saveContacts');
const contacts=approved.calls.find(call=>call.command==='update_contacts').payload;
assert.deepEqual(contacts,{phone:'2222',...Object.fromEntries(['function','department','manager','manager_contact'].map(key=>[key,professional[key]])),membership_id:'member-1'},'update_contacts deve preservar os valores funcionais gerenciados');

await click(approved.window,'#revision');
await click(approved.window,'[data-step="1"]');
assert.equal(approved.window.document.querySelector('#professionalFields [data-key="unit_id"]').disabled,true);
assert.equal(approved.window.document.querySelector('#professionalFields [data-key="position_id"]').disabled,true);
for(const key of ['function','department','manager','manager_contact'])assert.equal(approved.window.document.querySelector(`#professionalFields [data-key="${key}"]`).readOnly,true);
approved.window.document.querySelector('#professionalFields [data-key="unit_id"]').value='unit-2';
approved.window.document.querySelector('#professionalFields [data-key="position_id"]').value='position-2';
approved.window.document.querySelector('#professionalFields [data-key="function"]').value='Valor adulterado';
approved.window.document.querySelector('#personalFields [data-key="phone"]').value='3333';
await click(approved.window,'#save');
const save=[...approved.calls].reverse().find(call=>call.command==='save').payload;
assert.deepEqual(save.professional,professional,'save deve reenviar integralmente os valores profissionais originais');
assert.equal(save.personal.phone,'3333','telefone pessoal continua editável');

approved.window.document.querySelector('#memberSelect').value='';
approved.window.document.querySelector('#memberSelect').dispatchEvent(new approved.window.Event('change',{bubbles:true}));
await tick();
await click(approved.window,'[data-step="1"]');
assert.equal(approved.window.document.querySelector('#searchOrg'),null,'Dados da conta também deve bloquear nova busca se qualquer vínculo participante estiver aprovado');
assert.match(approved.window.document.querySelector('[data-organization-request-readonly]').textContent,/procure o Administrador/i);
assert.equal(approved.calls.filter(call=>call.command==='search_organizations'||call.command==='request_organization').length,0);

const onboarding=await setup({readonly:false,state:'draft',requiredTypes:['identity']});
await click(onboarding.window,'[data-step="1"]');
assert.ok(onboarding.window.document.querySelector('#searchOrg'),'onboarding ainda deve permitir pesquisa de organização');
assert.equal(onboarding.window.document.querySelector('#professionalFields [data-key="unit_id"]').disabled,false);
assert.equal(onboarding.window.document.querySelector('#professionalFields [data-key="function"]').readOnly,false);
await click(onboarding.window,'[data-step="2"]');
assert.ok(onboarding.window.document.querySelector('[data-doc-type="identity"] [data-key="file"]'),'upload de identidade deve permanecer no onboarding');
assert.ok(onboarding.window.document.querySelector('[data-upload="identity"]'),'ação de salvar documento deve permanecer no onboarding');

await approved.window.happyDOM.close();
await onboarding.window.happyDOM.close();
console.log('PASS: participante aprovado preserva dados funcionais; telefone, onboarding e revisões pessoais continuam disponíveis.');
