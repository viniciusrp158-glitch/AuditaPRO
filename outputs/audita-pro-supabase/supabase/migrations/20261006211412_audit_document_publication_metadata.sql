begin;
do $$ declare def text; begin
 def:=pg_get_functiondef('private.workspace_documents(text,jsonb)'::regprocedure);
 def:=replace(def,'execute format(''insert into public.%I(report_id,version_number,content,checksum,created_by)', 'content:=content||jsonb_build_object(''approval'',jsonb_build_object(''by'',(select full_name from public.user_profiles where user_id=auth.uid()),''at'',clock_timestamp(),''version'',v));
  execute format(''insert into public.%I(report_id,version_number,content,checksum,created_by)');
 def:=replace(def,'set status=''completed'',finalized_at=now(),finalized_by=$1 where id=$2'',tbl) using auth.uid(),did;', 'set status=''completed'',finalized_at=now(),finalized_by=$1,content=$3 where id=$2'',tbl) using auth.uid(),did,content;');
 -- pg_get_functiondef retains doubled quotes inside the dynamic SQL expression.
 def:=replace(def,'set status=''''completed'''',finalized_at=now(),finalized_by=$1 where id=$2'',tbl) using auth.uid(),did;', 'set status=''''completed'''',finalized_at=now(),finalized_by=$1,content=$3 where id=$2'',tbl) using auth.uid(),did,content;');
 execute def;
 def:=pg_get_functiondef('private.workspace_snapshot(uuid,uuid)'::regprocedure);
 def:=replace(def,'ra.*,q.reference', 'ra.*,(select coalesce(jsonb_agg(jsonb_build_object(''id'',ef.id,''filename'',ef.filename)),''[]'') from public.evidence_files ef where ef.assessment_id=ra.id) evidence_files,q.reference');
 execute def;
end $$;
commit;
