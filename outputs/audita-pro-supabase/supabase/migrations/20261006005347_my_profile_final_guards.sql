begin;
do $$ declare definition text; begin
 definition:=pg_get_functiondef('private.profile_command(text,jsonb)'::regprocedure);
 definition:=replace(definition,'reviewer:=m.created_by;','reviewer:=coalesce(s.reviewer_id,m.created_by);');
 definition:=replace(definition,'cnpj like ''%''||left(payload->>''search'',100)||''%''','(length(regexp_replace(payload->>''search'',''[^0-9]'','''',''g''))>=3 and cnpj like ''%''||regexp_replace(left(payload->>''search'',100),''[^0-9]'','''',''g'')||''%'')');
 execute definition;
 definition:=pg_get_functiondef('public.profile_register_document(uuid,uuid,jsonb)'::regprocedure);
 definition:=replace(definition,'return doc;', 'update public.profile_submissions set updated_at=clock_timestamp() where id=s.id; return doc;');
 execute definition;
end $$;
comment on table public.profile_submissions is 'Versioned self-service profile drafts and submissions. Reviewed by the assigned administrator. Files are private in user_documents.';
commit;
