-- B09 Parte 6b: cliente com vínculo aprovado consulta o PDF do plano publicado (D02); FPA e rascunhos continuam restritos.
create or replace function private.b08_can_view(e private.document_emissions, actor uuid) returns boolean
 language sql stable security definer set search_path = '' as $$
 select private.b08_can_operate(e, actor)
  or (e.document_kind <> 'specimen' and e.audit_id is not null and private.checklist_internal(e.audit_id))
  or (e.document_kind = 'plan' and e.status = 'published' and e.organization_id is not null and private.workspace_member(e.organization_id));
$$;
