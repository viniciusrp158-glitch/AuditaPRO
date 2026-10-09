import assert from 'node:assert/strict';
import fs from 'node:fs';
import {Window} from 'happy-dom';
const source=fs.readFileSync(new URL('../outputs/audita-pro-navigation.js',import.meta.url),'utf8');
for (const narrow of [false,true]) {
  const w=new Window({url:'https://test.local/audita-pro-dashboard.html'});
  let resize;
  w.matchMedia=()=>({matches:narrow,addEventListener:(_event,fn)=>{resize=fn;}});
  w.document.write('<aside class="side"><a class="brand" href="audita-pro-dashboard.html">AUDITA</a><nav><a href="audita-pro-dashboard.html">Dashboard</a><a href="audita-pro-auditorias.html">Auditorias</a><a hidden href="audita-pro-cadastro.html">Usuários</a><a href="audita-pro-historico.html">Biblioteca / histórico</a><a href="audita-pro-perfil.html">Meu Perfil</a></nav></aside>');
  w.eval(source); w.document.dispatchEvent(new w.Event('DOMContentLoaded'));
  const nav=w.document.querySelector('nav'),button=w.document.querySelector('.ap-nav-toggle');
  const users=nav.querySelector('[href="audita-pro-cadastro.html"]');
  assert.equal(nav.hidden,narrow);
  assert.equal(button.getAttribute('aria-controls'),nav.id);
  assert.equal(nav.querySelector('[aria-current="page"]').textContent,'Dashboard');
  assert.equal(users.hidden,true,'Admin link must start hidden');
  for (const profile of ['Auditor Líder','Auditor','Participante / Auditado']) {
    w.AUDITA_PRO_UPDATE_NAVIGATION({admin:false,memberships:[{profile,ready:true}]});
    assert.equal(users.hidden,true,profile);
    assert.equal(nav.querySelector('[href="audita-pro-perfil.html"]').hidden,false,'Onboarding remains reachable');
  }
  w.AUDITA_PRO_UPDATE_NAVIGATION({admin:true});assert.equal(users.hidden,false);
  w.AUDITA_PRO_UPDATE_NAVIGATION(null);assert.equal(users.hidden,true,'Failure/logout clears admin navigation');
  w.AUDITA_PRO_UPDATE_NAVIGATION({admin:'true'});assert.equal(users.hidden,true,'No truthy role coercion');
  button.click();assert.equal(nav.hidden,!narrow);
  assert.equal(button.getAttribute('aria-expanded'),String(narrow));
  resize({matches:false});assert.equal(nav.hidden,false);
  nav.querySelector('a').dispatchEvent(new w.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
  assert.equal(nav.hidden,true);assert.equal(w.document.activeElement,button);
  resize({matches:true});assert.equal(nav.hidden,true);
  assert.equal(w.document.querySelectorAll('.ap-nav-toggle').length,1);
  await w.happyDOM.close();
}
console.log('PASS: navigation server context, account change/failure, collapse, resize and keyboard (DOM simulated).');
