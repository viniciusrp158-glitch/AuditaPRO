-- B09 Parte 6a: a publicação do PDF do Plano aplica a revisão ao cronograma executável.
create or replace function private.b08_after_publish(e private.document_emissions) returns void
 language plpgsql security definer set search_path = '' as $$
begin
 if e.document_kind = 'plan' then perform private.b09_apply(e); end if;
end;$$;
