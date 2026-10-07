do $patch$
declare f record; d text; n integer:=0;
begin
 for f in select p.oid from pg_proc p join pg_namespace s on s.oid=p.pronamespace where s.nspname='private' and p.proname='workspace_detail' loop
 d:=pg_get_functiondef(f.oid);
 if position('''assessments'',''[]''::jsonb,''evidence'',''[]''::jsonb' in d)=0 then raise exception 'Unexpected workspace_detail definition'; end if;
 d:=replace(d,'''assessments'',''[]''::jsonb,''evidence'',''[]''::jsonb','''full_access'',false,''assessments'',''[]''::jsonb,''evidence'',''[]''::jsonb');
 execute d;n:=n+1;
 end loop;
 if n<>1 then raise exception 'Unexpected workspace_detail overload count'; end if;
end $patch$;
