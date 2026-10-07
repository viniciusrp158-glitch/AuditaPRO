do $$declare body text;begin
 body:=pg_get_functiondef('private.checklist_execution(text,jsonb)'::regprocedure);
 if position('to_jsonb(d) order by audit_date' in body)=0 then raise exception 'Definição inesperada';end if;
 body:=replace(body,'to_jsonb(d) order by audit_date) from public.audit_days d where audit_id=aid','to_jsonb(days_row) order by days_row.audit_date) from public.audit_days days_row where days_row.audit_id=aid');
 execute body;
end $$;
