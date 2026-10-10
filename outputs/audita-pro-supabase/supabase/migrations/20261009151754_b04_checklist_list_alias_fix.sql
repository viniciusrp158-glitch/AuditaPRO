-- Recuperada de supabase_migrations.schema_migrations em 2026-10-10 (B00, Claude).
-- JA APLICADA no projeto zlckcpeqcxmtrgbdquee. NAO reaplicar. md5(statements)=55efc7ff5eee57221f35d1a436f79b9a

begin;

-- A variável PL/pgSQL t (template selecionado) colidia com o alias t da listagem.
-- Corrigir apenas esse bloco; conservar autorização, assinatura e demais comandos.
do $$
declare definition text; fragment text; revised text; first_pos integer; last_pos integer;
begin
  definition:=pg_get_functiondef('private.checklist_library(text,jsonb)'::regprocedure);
  first_pos:=strpos(definition,'if cmd=''list'' then');
  last_pos:=strpos(definition,'elsif cmd=''get'' then');
  if first_pos=0 or last_pos<=first_pos then raise exception 'Bloco de listagem não reconhecido'; end if;
  fragment:=substring(definition from first_pos for last_pos-first_pos);
  if strpos(fragment,'select t.*')=0 or strpos(fragment,'from public.checklist_templates t where')=0 then
    raise exception 'Alias de listagem diferente do esperado';
  end if;
  revised:=replace(replace(fragment,'t.','list_template.'),'from public.checklist_templates t where','from public.checklist_templates list_template where');
  execute replace(definition,fragment,revised);
end $$;

commit;
