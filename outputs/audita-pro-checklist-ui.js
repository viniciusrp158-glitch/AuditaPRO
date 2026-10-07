(() => {
'use strict';
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function form(title,body,caption='Salvar',pagination=null) {
 return new Promise(resolve=>{
 const dialog=document.createElement('dialog');dialog.className='cl-dialog';
 dialog.innerHTML=`<form><header><h2>${esc(title)}</h2><button type="button" data-cancel aria-label="Fechar">×</button></header><div class="cl-dialog-body">${body}</div><footer><button type="button" class="button secondary" data-cancel>Cancelar</button><button class="button">${esc(caption)}</button></footer></form>`;
 document.body.append(dialog);let done=false;const finish=v=>{if(done)return;done=true;dialog.close();dialog.remove();resolve(v);};
 if(pagination){const nav=document.createElement('nav');nav.className='cl-actions';nav.innerHTML=`${pagination.page?'<button type="button" class="button secondary" data-page="-1">Anterior</button>':''}<span>Página ${pagination.page+1}</span>${pagination.more?'<button type="button" class="button secondary" data-page="1">Próxima</button>':''}`;dialog.querySelector('.cl-dialog-body').append(nav);nav.querySelectorAll('[data-page]').forEach(b=>b.onclick=()=>finish({_page:pagination.page+Number(b.dataset.page)}));}
 dialog.querySelectorAll('[data-cancel]').forEach(b=>b.onclick=()=>finish(null));dialog.addEventListener('cancel',e=>{e.preventDefault();finish(null);});
 dialog.querySelector('form').onsubmit=e=>{e.preventDefault();const data=Object.fromEntries(new FormData(e.target));for(const el of e.target.querySelectorAll('input[type=checkbox][name]'))data[el.name]=el.checked;finish(data);};
 dialog.showModal();
 });
}
const field=(key,label,value='',type='text',required=false)=>`<label class="cl-field">${esc(label)}${type==='textarea'?`<textarea name="${esc(key)}" ${required?'required':''}>${esc(value)}</textarea>`:`<input name="${esc(key)}" type="${type}" value="${esc(value)}" ${required?'required':''}>`}</label>`;
const select=(key,label,items,value='',empty=true)=>`<label class="cl-field">${esc(label)}<select name="${key}">${empty?'<option value="">Selecione</option>':''}${items.map(x=>`<option value="${esc(x.id)}" ${x.id===value?'selected':''}>${esc(x.name)}</option>`).join('')}</select></label>`;
window.AUDITA_CHECKLIST_UI={esc,form,field,select};
})();
