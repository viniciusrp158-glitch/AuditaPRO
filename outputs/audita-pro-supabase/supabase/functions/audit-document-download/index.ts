import { createClient } from 'npm:@supabase/supabase-js@2.57.0';
const url=Deno.env.get('SUPABASE_URL')!,secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,anon=Deno.env.get('SUPABASE_ANON_KEY')!;
const admin=createClient(url,secret,{auth:{persistSession:false}});
const headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS','Content-Type':'application/json','Cache-Control':'no-store'};

Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers});
 try{
  if(request.method!=='POST')throw new Error('Método inválido');
  const authorization=request.headers.get('Authorization')||'';
  if(!/^Bearer\s+\S+$/i.test(authorization))return new Response(JSON.stringify({error:'Sessão inválida'}),{status:401,headers});
  const token=authorization.replace(/^Bearer\s+/i,'');
  const {data:user,error:authError}=await admin.auth.getUser(token);
  if(authError||!user.user)return new Response(JSON.stringify({error:'Sessão inválida'}),{status:401,headers});
  if(!(request.headers.get('content-type')||'').includes('application/json'))throw new Error('Conteúdo inválido');
  const payload=await request.json();
  if(typeof payload?.file_id!=='string'||!payload.file_id||!['daily','final'].includes(payload.kind))throw new Error('Arquivo ou tipo de documento inválido');
  const caller=createClient(url,anon,{global:{headers:{Authorization:authorization}},auth:{persistSession:false}});
  const {data,error}=await caller.rpc('audit_document_file_access',{target_file:payload.file_id,document_kind:payload.kind});
  if(error)throw error;
  if(!data||data.bucket!=='audit-reports'||typeof data.path!=='string'||!data.path)throw new Error('Arquivo autorizado inválido');
  const signed=await admin.storage.from('audit-reports').createSignedUrl(data.path,60);
  if(signed.error)throw signed.error;
  return new Response(JSON.stringify({url:signed.data.signedUrl}),{headers});
 }catch(e){return new Response(JSON.stringify({error:e instanceof Error?e.message:String((e as {message?:string}).message||'Falha ao emitir acesso ao documento')}),{status:400,headers});}
});
