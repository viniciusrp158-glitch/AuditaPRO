begin;
create function private.workspace_document_access(doc uuid,kind text,aid uuid,published boolean) returns boolean language sql stable security definer set search_path='' as $$
 select private.profile_admin(auth.uid()) or private.workspace_conductor(aid) or (published and exists(select 1 from public.audit_document_recipients dr join public.organization_memberships m on m.id=dr.membership_id join public.audits a on a.id=dr.audit_id where dr.document_id=doc and dr.document_kind=kind and dr.audit_id=aid and m.user_id=auth.uid() and m.organization_id=a.organization_id and private.workspace_member(m.organization_id)));
$$;
create function private.workspace_snapshot(aid uuid,dayid uuid default null) returns jsonb language sql security definer set search_path='' as $$
 select jsonb_build_object('audit',jsonb_build_object('id',a.id,'code',a.code,'title',a.title,'scope',a.scope,'objective',a.objective,'standards',a.standards,'purpose',a.purpose,'party',a.party,'modality',a.modality,'location',a.location,'criteria',a.criteria,'start_date',a.start_date,'end_date',a.end_date,'execution_started_at',a.execution_started_at,'execution_ended_at',a.execution_ended_at,'certification',a.certification),
 'company',(select jsonb_build_object('name',legal_name,'cnpj',cnpj,'address',address) from public.organizations where id=a.organization_id),
 'leader',(select u.full_name from public.organization_memberships m join public.user_profiles u on u.user_id=m.user_id where m.id=a.leader_membership_id),
 'generated_at',clock_timestamp(),'plan_version',a.plan_revision,
 'days',coalesce((select jsonb_agg(to_jsonb(d)||jsonb_build_object('participants',(select coalesce(jsonb_agg(jsonb_build_object('membership_id',m.id,'name',u.full_name,'role',ap.participant_type)),'[]') from public.audit_day_attendance at join public.organization_memberships m on m.id=at.membership_id join public.user_profiles u on u.user_id=m.user_id left join public.audit_participants ap on ap.membership_id=m.id and ap.audit_id=aid where at.audit_day_id=d.id)) order by d.audit_date) from public.audit_days d where d.audit_id=aid and (dayid is null or d.id=dayid)),'[]'),
 'schedule',coalesce((select jsonb_agg(to_jsonb(si)||jsonb_build_object('process',pr.name,'date',d.audit_date)) from public.schedule_items si join public.audit_days d on d.id=si.audit_day_id left join public.audit_processes pr on pr.id=si.process_id where d.audit_id=aid and (dayid is null or d.id=dayid or si.origin_day_id=dayid)),'[]'),
 'movements',coalesce((select jsonb_agg(to_jsonb(m)) from public.schedule_movements m where m.audit_id=aid and (dayid is null or m.previous_data->>'audit_day_id'=dayid::text or m.new_data->>'audit_day_id'=dayid::text)),'[]'),
 'assessments',coalesce((select jsonb_agg(to_jsonb(x)) from (select distinct on(ra.requirement_id,ra.process_id,case when dayid is not null then ra.audit_day_id end) ra.*,q.reference,q.prompt,pr.name process from public.requirement_assessments ra join public.checklist_requirements q on q.id=ra.requirement_id left join public.audit_processes pr on pr.id=ra.process_id where ra.audit_id=aid and (dayid is null or ra.audit_day_id=dayid) order by ra.requirement_id,ra.process_id,case when dayid is not null then ra.audit_day_id end,ra.updated_at desc) x),'[]'),
 'nonconformities',coalesce((select jsonb_agg(to_jsonb(n)||jsonb_build_object('actions',(select coalesce(jsonb_agg(to_jsonb(ac)),'[]') from public.action_plans ac where ac.nonconformity_id=n.id))) from public.nonconformities n where n.audit_id=aid and (dayid is null or n.audit_day_id=dayid)),'[]'),
 'daily_reports',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'day_id',r.audit_day_id,'status',r.status,'finalized_at',r.finalized_at)) from public.daily_reports r where r.audit_id=aid),'[]'),
 'minutes',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'kind',m.kind,'status',m.status)) from public.audit_minutes m where m.audit_id=aid),'[]'),
 'plan',(select content from public.audit_plan_versions where audit_id=aid order by version_number desc limit 1),
 'original_plan',(select content from public.audit_plan_versions where audit_id=aid order by version_number limit 1),
 'additional_notes','') from public.audits a where a.id=aid;
$$;
create function private.workspace_documents(cmd text,p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare aid uuid:=nullif(p->>'audit_id','')::uuid; did uuid:=nullif(p->>'document_id','')::uuid; kind text:=p->>'kind'; a public.audits%rowtype; dayid uuid; s public.schedule_items%rowtype; content jsonb; tbl text; vt text; st text; v int; vid uuid; members uuid[]; result jsonb;
begin
 if auth.uid() is null or not private.is_active_account(auth.uid()) then raise exception 'Sessão ativa necessária'; end if;
 select * into a from public.audits where id=aid;
 if a.id is null then raise exception 'Auditoria inexistente'; end if;
 if cmd='list' then
  if not private.is_audit_participant(aid) and not private.workspace_member(a.organization_id) then raise exception 'Sem acesso'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(x) order by x.generated_at),'[]') from (
   select r.id,'daily' kind,'Relatório diário — Dia '||d.day_number||' — '||d.audit_date title,r.status,r.generated_at,r.finalized_at from public.daily_reports r join public.audit_days d on d.id=r.audit_day_id where r.audit_id=aid and private.workspace_document_access(r.id,'daily',aid,r.finalized_at is not null)
   union all select r.id,'final','Relatório final',r.status,r.generated_at,r.finalized_at from public.audit_final_reports r where r.audit_id=aid and private.workspace_document_access(r.id,'final',aid,r.finalized_at is not null)
   union all select r.id,'minutes',case when r.kind='opening' then 'Ata de abertura' when r.kind='closing' then 'Ata de encerramento' else 'Ata de reunião' end,r.status,r.generated_at,r.finalized_at from public.audit_minutes r where r.audit_id=aid and private.workspace_document_access(r.id,'minutes',aid,r.finalized_at is not null)
  ) x);
 end if;
 if cmd in ('get','approve','revise','notes') then
  tbl:=case kind when 'daily' then 'daily_reports' when 'final' then 'audit_final_reports' when 'minutes' then 'audit_minutes' end;
  vt:=case kind when 'daily' then 'daily_report_versions' when 'final' then 'audit_final_report_versions' when 'minutes' then 'audit_minutes_versions' end;
  if tbl is null then raise exception 'Tipo documental inválido'; end if;
  execute format('select content,status from public.%I where id=$1 and audit_id=$2',tbl) into content,st using did,aid;
  if content is null or not private.workspace_document_access(did,kind,aid,st in ('completed','pending_acknowledgements')) then raise exception 'Documento indisponível'; end if;
  if cmd='get' then
   execute format('select coalesce(jsonb_agg(jsonb_build_object(''number'',version_number,''content'',content,''frozen_at'',frozen_at) order by version_number desc),''[]'') from public.%I where report_id=$1',vt) into result using did;
   return jsonb_build_object('content',content,'status',st,'versions',result,'can_approve',private.workspace_conductor(aid),'kind',kind);
  end if;
 end if;
 perform 1 from public.audits where id=aid for update;
 if not private.workspace_conductor(aid) then raise exception 'Somente o condutor pode gerar ou aprovar documentos'; end if;
 if cmd='close_day' then
  dayid:=(p->>'day_id')::uuid;
  if not exists(select 1 from public.audit_days where id=dayid and audit_id=aid and attendance_confirmed) then raise exception 'Confirme a presença do dia antes de encerrar'; end if;
  select id into did from public.daily_reports where audit_day_id=dayid;
  if did is not null then return jsonb_build_object('id',did); end if;
  if a.status<>'in_progress' then raise exception 'Auditoria não está em execução'; end if;
  if exists(select 1 from public.schedule_items where audit_day_id=dayid and not withdrawn and category<>'break' and status<>'completed') then raise exception 'Conclua ou reagende as atividades pendentes antes de encerrar o dia'; end if;
  if exists(select 1 from public.requirement_assessments ra where ra.audit_day_id=dayid and ra.result='nonconforming' and nullif(trim(ra.nc_justification),'') is null and not exists(select 1 from public.nonconformities n where n.audit_id=aid and n.requirement_id=ra.requirement_id and n.process_id is not distinct from ra.process_id)) then raise exception 'Vincule NC ou justifique os itens não conformes'; end if;
  update public.audit_days set status='completed',ended_at=now(),started_at=coalesce(started_at,now()),opening_plan_version=coalesce(opening_plan_version,a.plan_revision) where id=dayid;
  content:=private.workspace_snapshot(aid,dayid);
  insert into public.daily_reports(audit_id,audit_day_id,status,content) values(aid,dayid,'review',content) returning id into did;
  insert into public.audit_document_recipients select aid,did,'daily',membership_id from public.audit_day_attendance where audit_day_id=dayid;
  return jsonb_build_object('id',did);
 elsif cmd='minutes' then
  select si.* into s from public.schedule_items si join public.audit_days d on d.id=si.audit_day_id where si.id=(p->>'schedule_id')::uuid and d.audit_id=aid and si.status='completed' and si.category in ('opening','closing','meeting');
  if s.id is null then raise exception 'Registre a reunião como realizada'; end if;
  select id into did from public.audit_minutes where schedule_item_id=s.id;
  if did is not null then return jsonb_build_object('id',did); end if;
  if not exists(select 1 from public.audit_day_attendance where audit_day_id=s.audit_day_id) then raise exception 'Registre os participantes do dia'; end if;
  content:=private.workspace_snapshot(aid,s.audit_day_id)||jsonb_build_object('meeting',to_jsonb(s),'additional_notes',coalesce(p->>'notes',''));
  insert into public.audit_minutes(audit_id,schedule_item_id,kind,content) values(aid,s.id,s.category,content) returning id into did;
  insert into public.audit_document_recipients select aid,did,'minutes',membership_id from public.audit_day_attendance where audit_day_id=s.audit_day_id;
  return jsonb_build_object('id',did);
 elsif cmd='finish' then
  select id into did from public.audit_final_reports where audit_id=aid;
  if did is not null then return jsonb_build_object('id',did); end if;
  if a.status<>'in_progress' then raise exception 'Auditoria não está em execução'; end if;
  if exists(select 1 from public.audit_days d where d.audit_id=aid and d.status<>'completed' and exists(select 1 from public.schedule_items si where si.audit_day_id=d.id and not si.withdrawn and si.category<>'break')) then raise exception 'Encerre todos os dias auditados'; end if;
  if not exists(select 1 from public.daily_reports where audit_id=aid) or exists(select 1 from public.daily_reports where audit_id=aid and finalized_at is null) or exists(select 1 from public.audit_minutes where audit_id=aid and finalized_at is null) then raise exception 'Valide os relatórios diários e atas antes de finalizar'; end if;
  update public.audits set status='awaiting_signoff',execution_ended_at=now(),certification=coalesce(p->'certification',certification) where id=aid;
  content:=private.workspace_snapshot(aid)||jsonb_build_object('additional_notes',coalesce(p->>'notes',''));
  insert into public.audit_final_reports(audit_id,status,content,created_by) values(aid,'review',content,auth.uid()) returning id into did;
  insert into public.audit_document_recipients select distinct aid,did,'final',at.membership_id from public.audit_day_attendance at join public.audit_days d on d.id=at.audit_day_id where d.audit_id=aid;
  return jsonb_build_object('id',did);
 elsif cmd='notes' then
  if st<>'review' then raise exception 'Crie uma retificação para alterar documento aprovado'; end if;
  content:=content||jsonb_build_object('additional_notes',coalesce(p->>'notes',''));
  execute format('update public.%I set content=$1 where id=$2',tbl) using content,did;
  return '{}';
 elsif cmd='revise' then
  if nullif(trim(p->>'reason'),'') is null then raise exception 'Justifique a retificação'; end if;
  content:=content||jsonb_build_object('revision_reason',p->>'reason');
  execute format('update public.%I set status=''review'',content=$1 where id=$2',tbl) using content,did;
  return '{}';
 elsif cmd='approve' then
  if st<>'review' then raise exception 'Documento já aprovado'; end if;
  execute format('select coalesce(max(version_number),0)+1 from public.%I where report_id=$1',vt) into v using did;
  execute format('insert into public.%I(report_id,version_number,content,checksum,created_by) values($1,$2,$3,$4,$5) returning id',vt) into vid using did,v,content,encode(extensions.digest(convert_to(content::text,'UTF8'),'sha256'),'hex'),auth.uid();
  execute format('update public.%I set status=''completed'',finalized_at=now(),finalized_by=$1 where id=$2',tbl) using auth.uid(),did;
  if kind='daily' then
   insert into public.report_acknowledgements(report_version_id,membership_id) select vid,ap.membership_id from public.audit_participants ap join public.audit_document_recipients dr on dr.membership_id=ap.membership_id and dr.document_id=did and dr.document_kind='daily' where ap.audit_id=aid and ap.active and ap.is_signatory;
   if found then update public.daily_reports set status='pending_acknowledgements' where id=did; end if;
  elsif kind='final' then update public.audits set status='completed' where id=aid; end if;
  insert into public.in_app_notifications(recipient_id,event_key,event_type,entity_type,entity_id,title,message)
   select m.user_id,'audit-document:'||vid::text||':'||m.user_id,'audit_document','audit',aid,'Documento de auditoria disponível','Um documento foi aprovado. Consulte Relatórios e atas na auditoria.' from public.audit_document_recipients dr join public.organization_memberships m on m.id=dr.membership_id where dr.document_id=did and dr.document_kind=kind on conflict do nothing;
  return jsonb_build_object('version_id',vid);
 end if;
 raise exception 'Comando documental inválido';
end $$;
create function public.audit_documents(command text,payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$select private.workspace_documents(command,payload);$$;
revoke all on function private.workspace_snapshot(uuid,uuid),private.workspace_document_access(uuid,text,uuid,boolean),private.workspace_documents(text,jsonb),public.audit_documents(text,jsonb) from public;
grant execute on function private.workspace_documents(text,jsonb),public.audit_documents(text,jsonb),private.workspace_document_access(uuid,text,uuid,boolean) to authenticated;
-- Published daily access is scoped to historical recipients; draft is restricted.
create policy workspace_daily_read on public.daily_reports as restrictive for select to authenticated using(not exists(select 1 from public.audits a where a.id=audit_id and a.workspace_version>0) or private.workspace_document_access(id,'daily',audit_id,finalized_at is not null));
create policy workspace_final_read on public.audit_final_reports as restrictive for select to authenticated using(not exists(select 1 from public.audits a where a.id=audit_id and a.workspace_version>0) or private.workspace_document_access(id,'final',audit_id,finalized_at is not null));
commit;
