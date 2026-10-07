import {stripTypeScriptTypes} from 'node:module';import fs from 'node:fs';import assert from 'node:assert/strict';
let handler,prior=null,uploadCount=0,insertCount=0,deny=false,uploadFailure=false;const context={audit_id:'a',assessment_id:'r'};
const admin={auth:{getUser:async token=>({data:{user:token==='valid'?{id:'u'}:null}})},from:table=>{const q={select:()=>q,eq:()=>q,maybeSingle:async()=>({data:prior}),update:()=>q,insert:()=>{insertCount++;return q;},single:async()=>({data:{id:'e'}}),then:resolve=>resolve({})};return q;},storage:{from:()=>({upload:async()=>{uploadCount++;return uploadFailure?{error:{message:'Upload interrompido'}}:{};},remove:async()=>({}),createSignedUrl:async()=>({data:{signedUrl:'https://example.invalid/file'}})})}};
const caller={rpc:async()=>deny?{error:{message:'Acesso recusado'}}:{data:context}};
const createClient=(url,key)=>key==='secret'?admin:caller;
const Deno={env:{get:n=>n==='SUPABASE_SERVICE_ROLE_KEY'?'secret':'public'},serve:fn=>{handler=fn;}};
const source=fs.readFileSync(new URL('../outputs/audita-pro-supabase/supabase/functions/audit-evidence/index.ts',import.meta.url),'utf8').replace(/^import[^\n]+\n/,'');
new Function('createClient','Deno',stripTypeScriptTypes(source,{mode:'strip'}))(createClient,Deno);
async function send(bytes,type,token='valid',op='11111111-1111-4111-8111-111111111111'){const fd=new FormData();fd.append('file',new File([bytes],'teste.png',{type}));fd.append('assessment_id','r');fd.append('operation_id',op);fd.append('caption','Contexto');return handler(new Request('https://example.invalid',{method:'POST',headers:{Authorization:'Bearer '+token},body:fd}));}
let r=await send(new Uint8Array([1]),'image/png','invalid');assert.equal(r.status,401);
r=await send(new Uint8Array([1,2]),'image/png');assert.equal(r.status,400);assert.equal(uploadCount,0);
r=await send(new Uint8Array(10485761),'image/png');assert.equal(r.status,400);
const png=new Uint8Array([137,80,78,71,13,10,26,10,0]);deny=true;r=await send(png,'image/png');assert.equal(r.status,400);assert.equal(uploadCount,0);deny=false;
prior={id:'already'};r=await send(png,'image/png');assert.equal(r.status,200);assert.deepEqual(await r.json(),{id:'already'});assert.equal(uploadCount,0);assert.equal(insertCount,0);
prior=null;uploadFailure=true;r=await send(png,'image/png');assert.equal(r.status,400);assert.equal(insertCount,0);uploadFailure=false;
r=await send(png,'image/png');assert.equal(r.status,200);assert.equal(insertCount,1);
console.log('PASS: Edge invalid authentication, size, MIME, denied context, retry idempotence, interrupted upload, successful link. Storage and auth are isolated mocks.');
