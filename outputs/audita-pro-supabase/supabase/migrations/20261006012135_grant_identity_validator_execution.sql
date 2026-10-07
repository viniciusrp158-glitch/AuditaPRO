-- CHECK constraints run validators with the caller's permissions.
-- These immutable functions only validate supplied digits; RLS still governs writes.
begin;
grant execute on function private.valid_cnpj(text), private.valid_cpf(text) to authenticated, service_role;
commit;
