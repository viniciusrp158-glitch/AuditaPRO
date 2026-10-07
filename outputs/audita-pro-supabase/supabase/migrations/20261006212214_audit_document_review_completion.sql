begin;
do $patch$ declare def text; begin
 def:=pg_get_functiondef('private.workspace_command(text,jsonb)'::regprocedure);
 def:=replace(def,'for item in select value from jsonb_array_elements(a.plan_draft) loop','for item in select value from jsonb_array_elements(a.plan_draft) order by value->>''date'',value->>''start'' loop');
 execute def;
 def:=pg_get_functiondef('private.workspace_documents(text,jsonb)'::regprocedure);
 def:=replace(def,'content:=content||jsonb_build_object(''revision_reason'',p->>''reason'');','content:=(content-''approval'')||jsonb_build_object(''revision_reason'',p->>''reason'');');
 def:=replace(def,'content:=content||jsonb_build_object(''additional_notes'',coalesce(p->>''notes'',''''));', $code$
  if kind='minutes' and p ? 'meeting_members' then
   if jsonb_typeof(p->'meeting_members')<>'array' or jsonb_array_length(p->'meeting_members')=0 then raise exception 'Informe os presentes na reunião'; end if;
   if exists(select 1 from jsonb_array_elements_text(p->'meeting_members') m where not exists(select 1 from public.audit_day_attendance at where at.audit_day_id=(content->'meeting'->>'audit_day_id')::uuid and at.membership_id=m::uuid)) then raise exception 'A reunião exige participantes presentes no dia'; end if;
   content:=content||jsonb_build_object('meeting_participants',(select jsonb_agg(jsonb_build_object('membership_id',m.id,'name',up.full_name)) from public.organization_memberships m join public.user_profiles up on up.user_id=m.user_id where m.id in(select value::uuid from jsonb_array_elements_text(p->'meeting_members'))),'meeting_attendance_confirmed',true);
   delete from public.audit_document_recipients where document_id=did and document_kind='minutes';
   insert into public.audit_document_recipients select aid,did,'minutes',value::uuid from jsonb_array_elements_text(p->'meeting_members') on conflict do nothing;
  end if;
  if kind='final' and p ? 'certification' then
   if coalesce(p->'certification'->>'status','') not in ('not_applicable','pending','granted','not_granted') then raise exception 'Situação de certificação inválida'; end if;
   if p->'certification'->>'status' in ('granted','not_granted') and (nullif(trim(p->'certification'->>'source'),'') is null or nullif(p->'certification'->>'date','') is null or nullif(trim(p->'certification'->>'reference'),'') is null) then raise exception 'Informe origem, data e referência da decisão'; end if;
   content:=jsonb_set(content,'{audit,certification}',p->'certification');
  end if;
  content:=content||jsonb_build_object('additional_notes',coalesce(p->>'notes',''));
 $code$);
 def:=replace(def,'if st<>''review'' then raise exception ''Documento já aprovado''; end if;', $code$
  if st<>'review' then raise exception 'Documento já aprovado'; end if;
  if kind='minutes' and not coalesce((content->>'meeting_attendance_confirmed')::boolean,false) then raise exception 'Confirme os presentes na reunião antes de aprovar'; end if;
 $code$);
 def:=replace(def,'elsif kind=''final'' then update public.audits set status=''completed'' where id=aid;', 'elsif kind=''final'' then update public.audits set status=''completed'',certification=content->''audit''->''certification'' where id=aid;');
 execute def;
end $patch$;
commit;
