(() => {
 'use strict';
 const esc=value=>String(value??'').replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
 const option=(value,text,selected=false)=>`<option value="${esc(value)}" ${selected?'selected':''}>${esc(text)}</option>`;
 const field=(name,label,value='',type='text',required=false)=>`<label class="field">${label}<input name="${name}" type="${type}" value="${esc(value)}" ${required?'required':''}></label>`;
 const textarea=(name,label,value='',required=false,hint='')=>`<label class="field">${label}<textarea name="${name}" ${required?'required':''}>${esc(value)}</textarea>${hint?`<small class="field-hint">${esc(hint)}</small>`:''}</label>`;
 const select=(name,label,items,value='',required=false)=>`<label class="field">${label}<select name="${name}" ${required?'required':''}><option value="">Selecione</option>${items.map(item=>option(item.id,item.name,item.id===value)).join('')}</select></label>`;
 const labels={first:'1ª parte',second:'2ª parte',third:'3ª parte',presential:'Presencial',remote:'Remota',hybrid:'Híbrida',initial:'Inicial',certification:'Certificação',maintenance:'Manutenção',recertification:'Recertificação',follow_up:'Follow-up',diagnostic:'Diagnóstico',other:'Outra'};
 const enums=values=>values.map(id=>({id,name:labels[id]}));
 const criterionName=item=>`${item.code}${item.edition?` · ${item.edition}`:''} — ${item.name}`;
 const formatAddress=value=>{
  if(!value)return '';
  if(typeof value==='string')return value;
  if(typeof value!=='object')return String(value);
  const street=value.street||value.address||value.logradouro||'';
  const number=value.number||value.numero||'';
  const first=[street,number].filter(Boolean).join(', ');
  return [first,value.complement||value.complemento,value.district||value.bairro,value.city||value.cidade,value.state||value.uf,value.postal_code||value.cep].filter(Boolean).join(' · ');
 };
 const latestRequest=()=>{let sequence=0;return {start(){return ++sequence;},isCurrent(token){return token===sequence;}};};
 async function loadLatestOrganization(requests,organizationId,fetcher,hooks={}){
  const token=requests.start();hooks.loading?.(Boolean(organizationId));
  if(!organizationId){hooks.clear?.();return;}
  try{const data=await fetcher(organizationId);if(requests.isCurrent(token)){hooks.success?.(data);hooks.done?.('success');}}
  catch(error){if(requests.isCurrent(token)){hooks.error?.(error);hooks.done?.('error');}}
 }

 function creationForm(context){
  const organizations=(context.organizations||[]).filter(item=>item.can_create);
  const criteria=(context.types||[]).filter(item=>item.active);
  return `<p class="hint">O rascunho pode ser completado depois. Selecione a empresa e todos os critérios desta auditoria.</p>
   <section class="identification-section" aria-labelledby="new-audit-identification"><h3 id="new-audit-identification">Identificação</h3>
   <div class="form-grid">${select('organization_id','Cliente *',organizations.map(item=>({id:item.id,name:item.code?`${item.name} · ${item.code}`:item.name})),'',true)}<div id="newOrgFields" class="identification-dependent"></div></div>
   <div id="newOrgSummary" class="client-summary" aria-live="polite"></div>
   ${field('title','Título *','','text',true)}
   <div class="form-grid">${select('party','Natureza',enums(['first','second','third']),'first',true)}${select('modality','Modalidade',enums(['presential','remote','hybrid']),'presential',true)}${field('location','Local / endereço')}</div>
   ${textarea('objective','Objetivo da auditoria')}${textarea('scope','Escopo *','',true)}
   </section>
   <section class="identification-section" aria-labelledby="new-audit-criteria"><h3 id="new-audit-criteria">Normas e critérios</h3>
   ${select('type_id','Critério principal *',criteria.map(item=>({id:item.id,name:criterionName(item)})),'',true)}
   <fieldset class="criteria-fieldset"><legend>Critérios adicionais para auditoria integrada</legend><p class="field-hint">Cada critério mantém sua própria edição e identidade.</p><div class="criteria-options">${criteria.map(item=>`<label><input type="checkbox" name="additional_criteria" value="${esc(item.id)}"> <span>${esc(criterionName(item))}</span></label>`).join('')||'<p class="muted">Nenhum critério ativo disponível.</p>'}</div></fieldset>
   <div id="newTemplate"></div>${field('purpose','Finalidade','Interna')}${textarea('criteria','Referências complementares')}</section>`;
 }

 function bindCreation(form,{context,onOrganization,onCriteria}={}){
  const organization=form.querySelector('[name=organization_id]');
  const primary=form.querySelector('[name=type_id]');
  let suggestedLocation='';
  const syncCriteria=()=>{
   const selected=primary?.value||'';
   form.querySelectorAll('[name=additional_criteria]').forEach(box=>{box.disabled=box.value===selected;if(box.disabled)box.checked=false;});
   onCriteria?.(selected);
  };
  organization?.addEventListener('change',()=>{
   const item=(context.organizations||[]).find(candidate=>candidate.id===organization.value);
   const summary=form.querySelector('#newOrgSummary');
   const address=formatAddress(item?.address);
   if(summary)summary.innerHTML=item?`<strong>${esc(item.name)}</strong>${item.code?`<span>Código do cliente: ${esc(item.code)}</span>`:''}${item.cnpj?`<span>CNPJ: ${esc(item.cnpj)}</span>`:''}${address?`<span>Endereço cadastrado: ${esc(address)}</span>`:''}`:'';
   const location=form.querySelector('[name=location]');
   if(location&&(!location.value.trim()||location.value===suggestedLocation)){location.value=address;suggestedLocation=address;}
   onOrganization?.(organization.value,item);
  });
  primary?.addEventListener('change',syncCriteria);
  syncCriteria();
 }

 function creationPayload(form){
  const data=Object.fromEntries(new FormData(form));
  const selected=[data.type_id,...[...form.querySelectorAll('[name=additional_criteria]:checked')].map(box=>box.value)].filter(Boolean);
  data.criterion_ids=[...new Set(selected)];
  delete data.additional_criteria;
  return data;
 }

 function editingForm(data,types=[],units=[]){
  const criteria=types.filter(item=>item.active||data.criterion_ids?.includes(item.id));
  const checked=new Set(data.criterion_ids||[]);
  return `<section class="identification-section"><div class="form-grid">${field('title','Título',data.title)}${select('unit_id','Unidade / local cadastrado',units,data.unit_id||'')}</div>
   <div class="form-grid">${field('declared_start_date','Início declarado',data.declared_start_date||'','date')}${field('declared_end_date','Fim declarado',data.declared_end_date||'','date')}</div>
   <div class="form-grid">${select('party','Natureza',enums(['first','second','third']),data.party,true)}${select('modality','Modalidade',enums(['presential','remote','hybrid']),data.modality,true)}${select('evaluation_type','Tipo de avaliação',enums(['initial','certification','maintenance','recertification','follow_up','diagnostic','other']),data.evaluation_type||'')}${field('evaluation_other','Descrição de “Outra”',data.evaluation_other||'')}${field('location','Local / endereço',data.location||'')}</div>
   ${textarea('objective','Objetivo da auditoria',data.objective||'')}${textarea('scope','Escopo da auditoria',data.scope||'')}
   <fieldset class="criteria-fieldset"><legend>Critérios e edições</legend><div class="criteria-options">${criteria.map(item=>`<label><input type="checkbox" name="criterion_ids" value="${esc(item.id)}" ${checked.has(item.id)?'checked':''}> <span>${esc(criterionName(item))}</span></label>`).join('')}</div></fieldset>
   ${field('purpose','Finalidade',data.purpose||'')}${textarea('criteria','Referências complementares',data.criteria||'')}
   ${textarea('participants_text','Outros participantes em nome da AUDITA',data.participants_text||'',false,'Caso não se aplique, informar “N/A”.')}
   ${textarea('comments','Comentários',data.comments||'',false,'Caso não se aplique, informar “N/A”.')}</section>`;
 }

 function editingPayload(form,data){
  const payload={...data,...Object.fromEntries(new FormData(form))};
  payload.criterion_ids=[...form.querySelectorAll('[name=criterion_ids]:checked')].map(box=>box.value);
  payload.audit_id=data.audit_id;
  payload.expected_lock_version=data.lock_version;
  delete payload.lock_version;
  return payload;
 }

 function summary({audit,company,unit,criteria=[]}){
  const standards=audit.standards?.length?audit.standards:(criteria.length?criteria.map(criterionName):[]);
  return `<section class="identification-summary" aria-labelledby="audit-identification-title"><div class="section-heading"><div><span class="eyebrow">Plano de auditoria</span><h2 id="audit-identification-title">Identificação</h2></div></div><dl>
   <div><dt>Cliente</dt><dd>${esc(company?.name||company||'—')}</dd></div><div><dt>Código da auditoria</dt><dd>${esc(audit.code)}</dd></div>
   ${unit?.name?`<div><dt>Unidade</dt><dd>${esc(unit.name)}</dd></div>`:''}<div><dt>Local / endereço</dt><dd>${esc(audit.location||'—')}</dd></div>
   <div><dt>Natureza</dt><dd>${esc(labels[audit.party]||audit.party||'—')}</dd></div><div><dt>Modalidade</dt><dd>${esc(labels[audit.modality]||audit.modality||'—')}</dd></div>
   <div class="wide"><dt>Critérios e edições</dt><dd>${standards.map(esc).join('<br>')||'—'}</dd></div><div class="wide"><dt>Objetivo</dt><dd>${esc(audit.objective||'—')}</dd></div>
   <div class="wide"><dt>Escopo</dt><dd>${esc(audit.scope||'—')}</dd></div><div class="wide"><dt>Referências complementares</dt><dd>${esc(audit.criteria||'—')}</dd></div>
  </dl></section>`;
 }

 window.AuditaPlanIdentification={creationForm,bindCreation,creationPayload,editingForm,editingPayload,summary,criterionName,formatAddress,latestRequest,loadLatestOrganization};
})();
