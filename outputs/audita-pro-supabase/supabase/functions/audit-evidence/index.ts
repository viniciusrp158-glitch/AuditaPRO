import { createClient } from 'npm:@supabase/supabase-js@2.57.0';
const url=Deno.env.get('SUPABASE_URL')!, secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const admin=createClient(url,secret,{auth:{persistSession:false}});
const headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS','Content-Type':'application/json'};
Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers});
 try {
  if(request.method!=='POST')throw new Error('Método inválido');
  const authorization=request.headers.get('Authorization')||'';
  const token=authorization.replace(/^Bearer\s+/i,'');
  const {data:user,error:authError}=await admin.auth.getUser(token);
  if(authError||!user.user) return new Response(JSON.stringify({error:'Sessão inválida'}),{status:401,headers});
  const caller=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:authorization}},auth:{persistSession:false}});
  if((request.headers.get('content-type')||'').includes('application/json')){
   const p=await request.json();const {data,error}=await caller.rpc('audit_evidence',{command:'view',payload:{id:p.id}});if(error)throw error;
   const signed=await admin.storage.from('audit-evidence-workspace').createSignedUrl(data.path,60);if(signed.error)throw signed.error;
   return new Response(JSON.stringify({url:signed.data.signedUrl}),{headers});
  }
  const form=await request.formData(),file=form.get('file');if(!(file instanceof File)||file.size===0||file.size>10485760)throw new Error('Arquivo deve ter até 10 MB');
  const bytes=new Uint8Array(await file.arrayBuffer());
  const mime=bytes[0]===0x25&&bytes[1]===0x50&&bytes[2]===0x44&&bytes[3]===0x46&&bytes[4]===0x2d?'application/pdf':bytes[0]===0xff&&bytes[1]===0xd8&&bytes[2]===0xff?'image/jpeg':bytes.slice(0,8).join(',')==='137,80,78,71,13,10,26,10'?'image/png':null;
  if(!mime||mime!==file.type)throw new Error('Conteúdo inválido: envie PDF, JPEG ou PNG');
  const payload={assessment_id:form.get('assessment_id')};
  const {data,error}=await caller.rpc('audit_evidence',{command:'authorize',payload});if(error)throw error;
  const path=`${data.audit_id}/${crypto.randomUUID()}.${mime==='application/pdf'?'pdf':mime==='image/png'?'png':'jpg'}`;
  const uploaded=await admin.storage.from('audit-evidence-workspace').upload(path,bytes,{contentType:mime,upsert:false});if(uploaded.error)throw uploaded.error;
  const recheck=await caller.rpc('audit_evidence',{command:'authorize',payload});
  if(recheck.error){await admin.storage.from('audit-evidence-workspace').remove([path]);throw recheck.error;}
  const saved=await admin.from('evidence_files').insert({audit_id:data.audit_id,assessment_id:data.assessment_id,storage_path:path,uploaded_by:user.user.id,filename:file.name.slice(0,200),mime_type:mime,size_bytes:file.size}).select('id').single();
  if(saved.error){await admin.storage.from('audit-evidence-workspace').remove([path]);throw saved.error;}
  return new Response(JSON.stringify(saved.data),{headers});
 }catch(e){return new Response(JSON.stringify({error:e instanceof Error?e.message:String((e as {message?:string}).message||'Falha ao processar arquivo')}),{status:400,headers});}
});
