(() => {
  const $ = (selector, root = document) => root.querySelector(selector);
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const date = value => value ? new Intl.DateTimeFormat('pt-BR',{dateStyle:'short'}).format(new Date(`${String(value).slice(0,10)}T12:00:00`)) : '—';
  const count = value => new Intl.NumberFormat('pt-BR').format(Number(value || 0));
  const percent = value => `${new Intl.NumberFormat('pt-BR',{maximumFractionDigits:1}).format(Number(value || 0))}%`;
  const cnpj = value => { const digits=String(value||'').replace(/\D/g,''); return digits.length===14?digits.replace(/^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})$/,'$1.$2.$3/$4-$5'):(value||'—'); };
  const labelStatus = value => ({in_progress:'Em andamento',awaiting_signoff:'Aguardando encerramento',planned:'Agendada',completed:'Finalizada',cancelled:'Cancelada',draft:'Rascunho',review:'Em revisão',pending_acknowledgements:'Aguardando ciência',open:'Aberta',action_planned:'Plano definido',closed:'Encerrada',pending_review:'Aguardando verificação',not_done:'Não realizada',active:'Ativa',inactive:'Inativa',leader:'Auditor líder',auditor:'Auditor',client:'Cliente',observer:'Observador'})[value] || value || '—';
  const badgeClass = value => value==='completed'||value==='closed'||value==='active'?'green':value==='in_progress'||value==='planned'?'blue':value==='pending_review'||value==='awaiting_signoff'||value==='pending_acknowledgements'?'amber':value==='cancelled'||value==='inactive'?'red':'';
  const metricCard = (title,value,hint='') => `<article class="card"><div class="label">${esc(title)}</div><div class="value">${count(value)}</div>${hint?`<div class="hint">${esc(hint)}</div>`:''}</article>`;
  const statusBadge = value => `<span class="badge ${badgeClass(value)}">${esc(labelStatus(value))}</span>`;
  let client, summary, companyTimer, cachedCompanies=[];

  function showState(message,kind='') { const el=$('#pageState'); el.className=`notice ${kind}`; el.textContent=message; el.hidden=false; }
  function hideState(){ $('#pageState').hidden=true; }
  function renderKpis(){
    const a=summary.audits||{}, n=summary.nonconformities||{}, c=summary.checklist||{}, act=summary.actions||{};
    $('#auditKpis').innerHTML=[metricCard('Total de auditorias',a.total),metricCard('Em andamento',a.in_progress),metricCard('Agendadas',a.scheduled),metricCard('Finalizadas',a.completed),metricCard('Atrasadas',a.overdue),metricCard('Aguardando encerramento',a.awaiting_signoff)].join('');
    $('#ncKpis').innerHTML=[metricCard('Total de não conformidades',n.total),metricCard('Abertas',n.open),metricCard('Em tratamento',n.in_treatment),metricCard('Aguardando verificação',n.awaiting_verification),metricCard('Encerradas',n.closed),metricCard('Vencidas',n.overdue),metricCard('Ações vencidas',act.overdue),metricCard('Ações próximas (7 dias)',act.due_soon),metricCard('Ações dentro do prazo',act.on_time)].join('');
    $('#checklistKpis').innerHTML=[metricCard('Total de itens',c.total),metricCard('Conformes',c.conforming),metricCard('Não conformes',c.nonconforming),metricCard('Parcialmente conformes',c.partially_conforming),metricCard('Não avaliados',c.not_assessed),metricCard('Não aplicáveis',c.not_applicable),metricCard('Melhorias registradas',c.improvement)].join('');
  }
  function renderActiveAudits(){
    const rows=summary.active_audits||[];
    if(!rows.length){$('#activeAudits').innerHTML='<div class="notice empty">Não existem auditorias em andamento.</div>';return;}
    $('#activeAudits').innerHTML=`<div class="table-wrap"><table class="table"><thead><tr><th>Empresa</th><th>Auditoria / norma</th><th>Auditor líder</th><th>Período</th><th>Status</th><th>Progresso</th><th>NCs</th><th>Itens avaliados</th><th></th></tr></thead><tbody>${rows.map(r=>`<tr><td><strong>${esc(r.trade_name||r.legal_name)}</strong><br><span class="muted">${esc(cnpj(r.cnpj))}</span></td><td>${esc(r.title||r.code)}<br><span class="muted">${esc((r.standards||[]).join(', ')||'Norma não informada')}</span></td><td>${esc(r.leader_name)}</td><td>${date(r.start_date)} – ${date(r.end_date)}</td><td>${statusBadge(r.status)}</td><td><div class="progress-line"><div class="progress"><span style="width:${Math.max(0,Math.min(100,Number(r.progress_percent)||0))}%"></span></div><small>${percent(r.progress_percent)}</small></div></td><td>${count(r.nonconformity_count)}</td><td>${count(r.checklist_evaluated)} / ${count(Math.max(0,(r.checklist_total||0)-(r.not_applicable||0)))}</td><td><button class="button" data-company="${esc(r.organization_id)}" data-audit="${esc(r.id)}">Abrir</button></td></tr>`).join('')}</tbody></table></div>`;
    $('#activeAudits').querySelectorAll('button[data-company]').forEach(b=>b.addEventListener('click',()=>openCompany(b.dataset.company,b.dataset.audit)));
  }
  async function loadCompanies(){
    const host=$('#companyResults'); host.innerHTML='<div class="loading">Buscando empresas…</div>';
    const term=$('#companySearch').value.trim(); const status=$('#companyStatus').value;
    let q=client.from('organizations').select('id,legal_name,trade_name,cnpj,status,segment').order('legal_name').range(0,49);
    if(status) q=q.eq('status',status);
    if(term){const digits=term.replace(/\D/g,'');const safe=term.replace(/[,%()]/g,' ').trim();const filters=[`legal_name.ilike.%${safe}%`,`trade_name.ilike.%${safe}%`];if(digits)filters.push(`cnpj.ilike.%${digits}%`);q=q.or(filters.join(','));}
    const {data,error}=await q;
    if(error){host.innerHTML=`<div class="notice error">Não foi possível carregar as empresas: ${esc(error.message)}</div>`;return;}
    cachedCompanies=data||[];
    if(!cachedCompanies.length){host.innerHTML='<div class="notice empty">Nenhuma empresa corresponde à pesquisa.</div>';return;}
    host.innerHTML=`<div class="table-wrap"><table class="table"><thead><tr><th>Empresa</th><th>Nome fantasia</th><th>CNPJ</th><th>Segmento</th><th>Status</th><th></th></tr></thead><tbody>${cachedCompanies.map(o=>`<tr><td><strong>${esc(o.legal_name)}</strong></td><td>${esc(o.trade_name||'—')}</td><td>${esc(cnpj(o.cnpj))}</td><td>${esc(o.segment||'—')}</td><td>${statusBadge(o.status)}</td><td><button class="button" data-open-company="${esc(o.id)}">Ver detalhes</button></td></tr>`).join('')}</tbody></table></div>${cachedCompanies.length===50?'<p class="footer-note">Exibindo as primeiras 50 empresas. Refine a pesquisa para localizar outros registros.</p>':''}`;
    host.querySelectorAll('[data-open-company]').forEach(b=>b.addEventListener('click',()=>openCompany(b.dataset.openCompany)));
  }
  const getList = async (table, columns, key, ids, order) => {
    if(!ids?.length)return [];
    let q=client.from(table).select(columns).in(key,ids);if(order)q=q.order(order);
    const {data,error}=await q;if(error)throw error;return data||[];
  };
  async function openCompany(orgId, selectedAuditId){
    window.dispatchEvent(new CustomEvent('audita:profile-context',{detail:{organization_id:orgId}}));
    const section=$('#companyDetailSection'),host=$('#companyDetail');section.hidden=false;host.innerHTML='<div class="loading">Carregando dados e histórico da empresa…</div>';section.scrollIntoView({behavior:'smooth',block:'start'});
    try{
      const [orgRes,auditRes,contactRes]=await Promise.all([
        client.from('organizations').select('*').eq('id',orgId).single(),
        client.from('audits').select('id,organization_id,code,title,objective,scope,standards,start_date,end_date,status,leader_membership_id,created_at').eq('organization_id',orgId).order('start_date',{ascending:false,nullsFirst:false}),
        client.from('organization_contacts').select('id,full_name,role_title,email,phone,is_primary,status').eq('organization_id',orgId).eq('status','active').order('is_primary',{ascending:false})
      ]);
      if(orgRes.error)throw orgRes.error;if(auditRes.error)throw auditRes.error;
      const org=orgRes.data,audits=auditRes.data||[],contacts=contactRes.error?[]:(contactRes.data||[]),auditIds=audits.map(x=>x.id);
      const [ncRes,finalRes]=await Promise.all([
        getList('nonconformities','id,audit_id,status,code,description,audit_day_id','audit_id',auditIds),
        getList('audit_final_reports','id,audit_id,status,generated_at,completed_at,created_by,finalized_by,finalized_at','audit_id',auditIds)
      ]);
      const ncRows=ncRes, ncs=ncRows.reduce((acc,n)=>{acc.total++;acc[n.status]=(acc[n.status]||0)+1;return acc;},{total:0});
      const active=audits.filter(a=>['in_progress','awaiting_signoff'].includes(a.status));
      const chosen=selectedAuditId?audits.find(a=>a.id===selectedAuditId):active[0];
      const addr=org.address||{};
      host.innerHTML=`<div class="detail-title"><div><span class="eyebrow">VISÃO DA EMPRESA</span><h2>${esc(org.trade_name||org.legal_name)}</h2></div><button class="close" id="closeCompany" aria-label="Fechar detalhes">×</button></div>
      <div class="company-info"><div><strong>Razão social</strong>${esc(org.legal_name||'—')}</div><div><strong>Nome fantasia</strong>${esc(org.trade_name||'—')}</div><div><strong>CNPJ</strong>${esc(cnpj(org.cnpj))}</div><div><strong>Segmento</strong>${esc(org.segment||'—')}</div><div><strong>Endereço</strong>${esc([addr.street,addr.number,addr.complement,addr.neighborhood,addr.city,addr.state,addr.postal_code].filter(Boolean).join(', ')||addr.formatted||'—')}</div><div><strong>Status</strong>${statusBadge(org.status)}</div><div><strong>Contatos</strong>${contacts.length?contacts.map(c=>`${esc(c.full_name)}${c.role_title?` — ${esc(c.role_title)}`:''}${c.email?` (${esc(c.email)})`:''}`).join('<br>'):'Nenhum contato cadastrado'}</div></div>
      <div class="summary-grid"><div class="mini"><strong>${count(audits.length)}</strong><span>Total de auditorias</span></div><div class="mini"><strong>${count(active.length)}</strong><span>Em andamento</span></div><div class="mini"><strong>${count(audits.filter(a=>a.status==='completed').length)}</strong><span>Finalizadas</span></div><div class="mini"><strong>${count(ncs.total)}</strong><span>Não conformidades</span></div><div class="mini"><strong>${count((ncs.open||0)+(ncs.action_planned||0)+(ncs.in_progress||0)+(ncs.pending_review||0))}</strong><span>Não conformidades abertas</span></div><div class="mini"><strong>${count(ncs.closed||0)}</strong><span>Não conformidades encerradas</span></div></div>
      <div class="section"><div class="section-head"><div><h2>Auditorias da empresa</h2><p>Selecione para consultar equipe, checklist, cronograma e relatórios.</p></div></div><div id="companyAudits" class="audit-list"></div></div><div id="selectedAuditDetails"></div>`;
      $('#closeCompany').onclick=()=>{section.hidden=true;};
      const auditHost=$('#companyAudits');
      if(!audits.length)auditHost.innerHTML='<div class="notice empty">Esta empresa ainda não possui auditorias cadastradas.</div>';
      else auditHost.innerHTML=audits.map(a=>`<article class="audit-card"><div class="audit-card-head"><div><h3>${esc(a.title||a.code)} <span class="muted">${esc(a.code)}</span></h3><p>${esc((a.standards||[]).join(', ')||'Norma não informada')} · ${date(a.start_date)} – ${date(a.end_date)}</p></div><div class="toolbar">${statusBadge(a.status)}<button class="button" data-audit-detail="${esc(a.id)}">Detalhes</button></div></div></article>`).join('');
      auditHost.querySelectorAll('[data-audit-detail]').forEach(b=>b.onclick=()=>loadAuditDetails(org,b.dataset.auditDetail,ncRows,finalRes));
      if(chosen)await loadAuditDetails(org,chosen.id,ncRows,finalRes);else $('#selectedAuditDetails').innerHTML='<div class="notice empty">Não existem auditorias em andamento. Selecione uma auditoria acima para consultar o cronograma e os relatórios.</div>';
    }catch(error){host.innerHTML=`<div class="notice error">Não foi possível abrir a empresa: ${esc(error.message||error)}</div>`;}
  }
  async function loadAuditDetails(org,auditId,allNcs,finalReports){
    const host=$('#selectedAuditDetails');if(!host)return;host.innerHTML='<div class="loading">Carregando detalhes da auditoria…</div>';
    try{
      const auditRes=await client.from('audits').select('*').eq('id',auditId).single();if(auditRes.error)throw auditRes.error;const audit=auditRes.data;
      const auditNcs=allNcs.filter(n=>n.audit_id===auditId);const finalReport=finalReports.find(r=>r.audit_id===auditId);
      const [days,checklists,assessments,participants,reports]=await Promise.all([
        getList('audit_days','id,audit_id,day_number,audit_date,started_at,ended_at,status','audit_id',[auditId],'audit_date'),
        getList('audit_checklists','id,audit_id,revision_id','audit_id',[auditId]),
        getList('requirement_assessments','id,audit_id,audit_day_id,requirement_id,process_id,result,notes,updated_at,created_at','audit_id',[auditId]),
        getList('audit_participants','id,audit_id,membership_id,participant_type,active,is_signatory','audit_id',[auditId]),
        getList('daily_reports','id,audit_id,audit_day_id,status,content,generated_at,edited_by,finalized_by,finalized_at,completed_at','audit_id',[auditId])
      ]);
      const dayIds=days.map(d=>d.id);const schedules=await getList('schedule_items','id,audit_day_id,process_id,requirement_id,title,planned_start,planned_end,assignee_membership_id,status,origin_day_id,move_reason,notes','audit_day_id',dayIds,'planned_start');
      const revisionIds=checklists.map(x=>x.revision_id);const sections=await getList('checklist_sections','id,revision_id,title,sort_order','revision_id',revisionIds,'sort_order');const sectionIds=sections.map(s=>s.id);const requirements=await getList('checklist_requirements','id,section_id,reference,prompt,sort_order','section_id',sectionIds,'sort_order');
      const metricsResult=await client.rpc('audit_workspace_stats',{target:auditId});if(metricsResult.error)throw metricsResult.error;
      const tally=metricsResult.data;
      const evaluated=tally.conforming+tally.nonconforming+tally.partially_conforming+tally.improvement;const denom=tally.total-tally.not_applicable;const progress=denom?Math.round(1000*evaluated/denom)/10:0;
      const memberIds=[...new Set(participants.map(p=>p.membership_id).concat(audit.leader_membership_id).filter(Boolean))];const memberships=await getList('organization_memberships','id,user_id,position_id','id',memberIds);const userIds=[...new Set(memberships.map(m=>m.user_id).concat(reports.flatMap(r=>[r.edited_by,r.finalized_by]),finalReport?[finalReport.created_by,finalReport.finalized_by]:[]).filter(Boolean))];const profiles=await getList('user_profiles','user_id,full_name','user_id',userIds);const profileMap=new Map(profiles.map(p=>[p.user_id,p.full_name]));const membershipMap=new Map(memberships.map(m=>[m.id,m]));
      const processes=await getList('audit_processes','id,name','id',[...new Set(schedules.map(s=>s.process_id).filter(Boolean))]);const reqMap=new Map(requirements.map(r=>[r.id,r]));const processMap=new Map(processes.map(p=>[p.id,p.name]));
      const dayMap=new Map(days.map(d=>[d.id,d]));
      const scheduleHtml=days.length?days.map(day=>{const entries=schedules.filter(s=>s.audit_day_id===day.id);return `<div class="mini" style="margin:9px 0"><strong>Dia ${count(day.day_number)} · ${date(day.audit_date)} · ${esc(labelStatus(day.status))}</strong>${entries.length?`<ul class="detail-list">${entries.map(s=>`<li>${statusBadge(s.status)} ${esc(s.title)}${s.planned_start?` · ${new Intl.DateTimeFormat('pt-BR',{hour:'2-digit',minute:'2-digit'}).format(new Date(s.planned_start))}`:''}${s.process_id?` · Processo: ${esc(processMap.get(s.process_id)||'—')}`:''}${s.requirement_id?` · Requisito: ${esc(reqMap.get(s.requirement_id)?.reference||'—')}`:''}${s.assignee_membership_id?` · Responsável: ${esc(profileMap.get(membershipMap.get(s.assignee_membership_id)?.user_id)||'—')}`:''}${s.origin_day_id?` · Transferida do dia ${count(dayMap.get(s.origin_day_id)?.day_number)}${s.move_reason?` — ${esc(s.move_reason)}`:''}`:''}${s.notes?`<br><span class="muted">${esc(s.notes)}</span>`:''}</li>`).join('')}</ul>`:'<p class="muted">Nenhuma atividade cadastrada para este dia.</p>'}</div>`}).join(''):'<div class="notice empty">Nenhum cronograma cadastrado para esta auditoria.</div>';
      const ncRows=auditNcs.length?`<div class="table-wrap"><table class="table"><thead><tr><th>Número</th><th>Descrição</th><th>Status</th></tr></thead><tbody>${auditNcs.map(n=>`<tr><td>${esc(n.code)}</td><td>${esc(n.description)}</td><td>${statusBadge(n.status)}</td></tr>`).join('')}</tbody></table></div>`:'<div class="notice empty">Nenhuma não conformidade registrada.</div>';
      const reportRows=reports.length?`<div class="table-wrap"><table class="table"><thead><tr><th>Data</th><th>Título</th><th>Status</th><th>Gerado em</th><th>Responsável</th><th>Ações</th></tr></thead><tbody>${reports.map((r,i)=>`<tr><td>${date(dayMap.get(r.audit_day_id)?.audit_date)}</td><td>Relatório diário · Dia ${count(dayMap.get(r.audit_day_id)?.day_number)}</td><td>${statusBadge(r.status)}</td><td>${date(r.generated_at)}</td><td>${esc(profileMap.get(r.finalized_by||r.edited_by)||'Não identificado')}</td><td><button class="button" data-view-report="${esc(r.id)}">Visualizar</button> <button class="button" data-report-pdf="${esc(r.id)}">Baixar PDF</button></td></tr>`).join('')}</tbody></table></div>`:'<div class="notice empty">Nenhum relatório diário foi gerado para esta auditoria.</div>';
      const finalSection=audit.status==='completed'?`<div class="section"><div class="section-head"><div><h2>Relatório final de auditoria</h2></div></div>${finalReport?`<div class="panel"><p>${statusBadge(finalReport.status)} · Gerado em ${date(finalReport.generated_at)} · Responsável: ${esc(profileMap.get(finalReport.finalized_by||finalReport.created_by)||'Não identificado')}</p><div class="toolbar"><button class="button" data-view-final="${esc(finalReport.id)}">Visualizar</button><button class="button" data-final-pdf="${esc(finalReport.id)}">Baixar PDF</button></div></div>`:'<div class="notice empty">A auditoria foi finalizada, mas o relatório final ainda não foi gerado.</div>'}</div>`:'';
      host.innerHTML=`<div class="section"><span class="eyebrow">AUDITORIA SELECIONADA</span><p><a class="button" href="audita-pro-auditorias.html?audit=${encodeURIComponent(auditId)}">Abrir espaço da auditoria e documentos</a></p><div class="detail-title"><h2>${esc(audit.title||audit.code)}</h2>${statusBadge(audit.status)}</div><p class="muted">${esc((audit.standards||[]).join(', ')||'Norma não informada')} · ${date(audit.start_date)} – ${date(audit.end_date)}</p><p><strong>Escopo:</strong> ${esc(audit.scope||'Não informado')}</p><div class="progress-line"><div class="progress" style="max-width:420px;flex:1"><span style="width:${progress}%"></span></div><strong>${percent(progress)}</strong><span class="muted">${count(evaluated)} de ${count(denom)} itens avaliáveis</span></div></div>
      <div class="summary-grid">${[['Requisitos',tally.total],['Itens avaliados',evaluated],['Conformes',tally.conforming],['Não conformes',tally.nonconforming],['Parcialmente conformes',tally.partially_conforming],['Não avaliados',tally.not_assessed],['Não aplicáveis',tally.not_applicable]].map(([k,v])=>`<div class="mini"><strong>${count(v)}</strong><span>${k}</span></div>`).join('')}</div>
      <div class="split"><div class="section"><h2>Equipe de auditoria</h2><ul class="detail-list">${participants.filter(p=>p.active).map(p=>`<li>${esc(profileMap.get(membershipMap.get(p.membership_id)?.user_id)||'Participante')} · ${esc(labelStatus(p.participant_type))}${p.is_signatory?' · Signatário':''}</li>`).join('')||'<li>Equipe não cadastrada.</li>'}</ul><p><strong>Auditor líder:</strong> ${esc(profileMap.get(membershipMap.get(audit.leader_membership_id)?.user_id)||'Responsável não identificado')}</p></div><div class="section"><h2>Resultados do checklist</h2><div class="summary-grid">${[['Conformes',tally.conforming],['Parcialmente conformes',tally.partially_conforming],['Não conformes',tally.nonconforming],['Não avaliados',tally.not_assessed],['Não aplicáveis',tally.not_applicable],['Melhorias',tally.improvement]].map(([k,v])=>`<div class="mini"><strong>${count(v)}</strong><span>${k}</span></div>`).join('')}</div></div></div>
      <div class="section"><h2>Cronograma</h2>${scheduleHtml}</div><div class="section"><h2>Não conformidades</h2>${ncRows}</div><div class="section"><h2>Relatórios diários</h2>${reportRows}</div>${finalSection}`;
      host.querySelectorAll('[data-view-report]').forEach(b=>b.onclick=()=>audit.workspace_version?location.assign('audita-pro-auditorias.html?audit='+auditId+'&document=daily:'+b.dataset.viewReport):viewDailyReport(b.dataset.viewReport,reports,dayMap));
      host.querySelectorAll('[data-report-pdf]').forEach(b=>b.onclick=()=>audit.workspace_version?location.assign('audita-pro-auditorias.html?audit='+auditId+'&document=daily:'+b.dataset.reportPdf):downloadDailyPdf(b.dataset.reportPdf));
      host.querySelectorAll('[data-view-final]').forEach(b=>b.onclick=()=>audit.workspace_version?location.assign('audita-pro-auditorias.html?audit='+auditId+'&document=final:'+b.dataset.viewFinal):viewFinalReport(b.dataset.viewFinal));
      host.querySelectorAll('[data-final-pdf]').forEach(b=>b.onclick=()=>audit.workspace_version?location.assign('audita-pro-auditorias.html?audit='+auditId+'&document=final:'+b.dataset.finalPdf):downloadFinalPdf(b.dataset.finalPdf));
    }catch(error){host.innerHTML=`<div class="notice error">Não foi possível carregar os detalhes da auditoria: ${esc(error.message||error)}. Verifique se as migrations do Dashboard foram aplicadas.</div>`;}
  }
  async function viewDailyReport(reportId, reports, dayMap){
    const report=reports.find(r=>r.id===reportId);if(!report)return;const day=dayMap.get(report.audit_day_id);
    $('#reportModalTitle').textContent=`Relatório diário · ${date(day?.audit_date)}`;
    $('#reportBody').innerHTML=`<p>${statusBadge(report.status)}${report.finalized_at?` · Finalizado em ${date(report.finalized_at)}`:''}</p><pre>${esc(JSON.stringify(report.content||{},null,2))}</pre><div id="reportPdfStatus" class="footer-note">PDF só fica disponível quando um arquivo real tiver sido anexado à auditoria.</div>`;
    $('#reportModal').hidden=false;
    const {data,error}=await client.from('report_external_files').select('storage_path,file_type').eq('report_id',reportId);
    if(!error&&data?.length){const signed=data.filter(f=>f.file_type==='gov_signed_pdf')[0]||data[0];const {data:urlData,error:urlError}=await client.storage.from('audit-reports').createSignedUrl(signed.storage_path,300);if(!urlError&&urlData?.signedUrl)$('#reportPdfStatus').innerHTML=`<a href="${esc(urlData.signedUrl)}" target="_blank" rel="noopener">Abrir PDF real do relatório</a>`;}
  }
  async function downloadDailyPdf(reportId){
    const {data,error}=await client.from('report_external_files').select('storage_path,file_type').eq('report_id',reportId).order('uploaded_at',{ascending:false});if(error){alert(`Não foi possível consultar o PDF: ${error.message}`);return;}const file=(data||[]).find(f=>f.file_type==='gov_signed_pdf')||(data||[])[0];if(!file){alert('Ainda não existe PDF anexado a este relatório.');return;}const {data:link,error:linkError}=await client.storage.from('audit-reports').createSignedUrl(file.storage_path,300);if(linkError){alert(`Não foi possível abrir o arquivo: ${linkError.message}`);return;}window.open(link.signedUrl,'_blank','noopener');
  }
  async function viewFinalReport(reportId){
    const {data,error}=await client.from('audit_final_reports').select('id,audit_id,status,content,generated_at,completed_at').eq('id',reportId).single();if(error){alert(`Não foi possível consultar o relatório final: ${error.message}`);return;}$('#reportModalTitle').textContent='Relatório final de auditoria';$('#reportBody').innerHTML=`<p>${statusBadge(data.status)} · Gerado em ${date(data.generated_at)}</p><pre>${esc(JSON.stringify(data.content||{},null,2))}</pre><p id="reportPdfStatus" class="footer-note">PDF só fica disponível quando um arquivo real tiver sido gerado ou anexado.</p>`;$('#reportModal').hidden=false;
  }
  async function downloadFinalPdf(reportId){
    const {data,error}=await client.from('audit_final_report_files').select('storage_path,file_type').eq('report_id',reportId).order('uploaded_at',{ascending:false});if(error){alert(`Não foi possível consultar o PDF: ${error.message}`);return;}const file=(data||[]).find(f=>f.file_type==='generated_pdf'||f.file_type==='gov_signed_pdf');if(!file){alert('Ainda não existe PDF disponível para este relatório final.');return;}const {data:link,error:linkError}=await client.storage.from('audit-reports').createSignedUrl(file.storage_path,300);if(linkError){alert(`Não foi possível abrir o arquivo: ${linkError.message}`);return;}window.open(link.signedUrl,'_blank','noopener');
  }
  function explainRpcError(error){
    const msg=error?.message||'';
    if(error?.code==='PGRST202'||error?.code==='42883'||/dashboard_admin_summary/.test(msg))return 'O Dashboard ainda não está disponível no banco conectado. As migrations locais do Dashboard precisam ser aplicadas ao Supabase antes da visualização.';
    if(error?.code==='42501'||/Acesso exclusivo/.test(msg))return 'Seu usuário autenticado não possui o perfil de Administrador definido no app_metadata do Supabase. O acesso administrativo não pode ser concedido pela interface.';
    return `Não foi possível carregar os indicadores reais: ${msg||'erro não identificado'}`;
  }
  async function start(){
    try{
      const auth=await window.AUDITA_PRO_REQUIRE_SESSION();if(!auth)return;client=auth.client;
      const user=auth.session.user;$('#currentUser').textContent=user.email||'Usuário autenticado';$('#logout').onclick=async()=>{await client.auth.signOut();location.replace('audita-pro-login.html');};
      const role=user.app_metadata?.platform_role;
      if(role!=='admin'){showState('Seu usuário está autenticado, mas esta primeira versão do Dashboard está disponível apenas para o perfil Administrador. O painel do Cliente será desenvolvido em uma próxima etapa.','error');return;}
      $('#welcomeText').textContent=`Visão administrativa · ${user.email||'Administrador'}`;
      showState('Carregando indicadores dos dados reais do Supabase…');
      const {data,error}=await client.rpc('dashboard_admin_summary');
      if(error){showState(explainRpcError(error),'error');return;}
      summary=data||{};renderKpis();renderActiveAudits();hideState();$('#dashboardContent').hidden=false;await loadCompanies();
      $('#companySearch').addEventListener('input',()=>{clearTimeout(companyTimer);companyTimer=setTimeout(loadCompanies,300);});$('#companyStatus').addEventListener('change',loadCompanies);
      const params=new URLSearchParams(location.search);if(params.get('organization_id'))await openCompany(params.get('organization_id'),params.get('audit_id')||undefined);
    }catch(error){showState(`Não foi possível inicializar o Dashboard: ${error.message||error}`,'error');}
  }
  document.addEventListener('DOMContentLoaded',()=>{ $('#closeReport').onclick=()=>$('#reportModal').hidden=true;$('#reportModal').addEventListener('click',e=>{if(e.target.id==='reportModal')$('#reportModal').hidden=true;});start(); });
})();
