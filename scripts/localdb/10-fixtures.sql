-- Dados de teste identificados (somente banco local). Duas organizações (X/Y) e contas por perfil.
-- UUIDs fixos com prefixo de teste para leitura dos resultados.
do $$
declare
 orgx uuid := '0000000a-0000-4000-8000-00000000000a'; orgy uuid := '0000000b-0000-4000-8000-00000000000b';
 pos uuid := (select id from public.positions where status = 'active' order by name limit 1);
 p_leader uuid := (select id from public.access_profiles where name = 'Auditor Líder');
 p_auditor uuid := (select id from public.access_profiles where name = 'Auditor');
 p_part uuid := (select id from public.access_profiles where name = 'Participante / Auditado');
 u record; mid uuid; sid uuid; t text;
begin
 insert into public.organizations (id, legal_name, cnpj, status, segment) values
  (orgx, 'TESTE Organização X', '11222333000181', 'active', 'Teste'), (orgy, 'TESTE Organização Y', '11444777000161', 'active', 'Teste');
 for u in select * from (values
  ('a0000000-0000-4000-8000-000000000001'::uuid, 'Admin Teste', 'admin', null::uuid, null::uuid, '11123114161'),
  ('a0000000-0000-4000-8000-000000000002'::uuid, 'Lider X Teste', 'member', orgx, p_leader, '22234225272'),
  ('a0000000-0000-4000-8000-000000000003'::uuid, 'Auditor X Teste', 'member', orgx, p_auditor, '33345336383'),
  ('a0000000-0000-4000-8000-000000000004'::uuid, 'Participante X Teste', 'member', orgx, p_part, '44456447494'),
  ('a0000000-0000-4000-8000-000000000005'::uuid, 'Lider Y Teste', 'member', orgy, p_leader, '55567558503'),
  ('a0000000-0000-4000-8000-000000000006'::uuid, 'Participante Y Teste', 'member', orgy, p_part, '66678669606'),
  ('a0000000-0000-4000-8000-000000000007'::uuid, 'Pendente X Teste', 'pending', orgx, p_auditor, '77789771094'),
  ('a0000000-0000-4000-8000-000000000008'::uuid, 'Inativo X Teste', 'member', orgx, p_auditor, '88891088196'),
  ('a0000000-0000-4000-8000-000000000009'::uuid, 'Lider2 X Teste', 'member', orgx, p_leader, '99910119943'),
  ('a0000000-0000-4000-8000-000000000010'::uuid, 'Admin2 Teste', 'admin', null::uuid, null::uuid, '10020030088')
 ) v(id, name, kind, org, prof, cpf) loop
  insert into auth.users (id, email, raw_user_meta_data, raw_app_meta_data) values (u.id, lower(replace(u.name, ' ', '.')) || '@teste.invalid', jsonb_build_object('full_name', u.name),
   case when u.kind = 'admin' then '{"platform_role":"admin"}'::jsonb else '{}'::jsonb end);
  insert into public.user_profiles (user_id, full_name, cpf, email, status) values (u.id, u.name, u.cpf,
   lower(replace(u.name, ' ', '.')) || '@teste.invalid', 'active')
  on conflict (user_id) do update set full_name = excluded.full_name, cpf = excluded.cpf, status = 'active';
  if u.org is not null then
   insert into public.organization_memberships (organization_id, user_id, position_id, access_profile_id, status, competence_status)
   values (u.org, u.id, pos, u.prof, 'active', case when u.kind = 'pending' then 'pending' else 'approved' end) returning id into mid;
   if u.kind <> 'pending' then
    insert into public.profile_submissions (user_id, membership_id, state, version, personal, professional, access_profile_id, required_types, submitted_at, reviewed_at)
    values (u.id, mid, 'approved', 1, jsonb_build_object('cpf', u.cpf, 'full_name', u.name), jsonb_build_object('position_id', pos, 'unit_id', ''),
     u.prof, private.profile_required(u.prof), now(), now()) returning id into sid;
    foreach t in array private.profile_required(u.prof) loop
     insert into public.user_documents (membership_id, document_type, storage_path, status, submission_id, is_current, filename, no_expiry, size_bytes, reviewed_by, reviewed_at)
     values (mid, t, 'identity/' || mid || '/' || t || '.pdf', 'approved', sid, true, t || '.pdf', true, 1000, 'a0000000-0000-4000-8000-000000000001', now());
    end loop;
   end if;
  end if;
 end loop;
 -- Equivale à revisão administrativa concluída (o gatilho de documentos reabre a competência como pendente).
 update public.organization_memberships m set competence_status = 'approved'
  where m.user_id <> 'a0000000-0000-4000-8000-000000000007' and m.user_id::text like 'a0000000-%';
 update public.user_profiles set status = 'inactive' where user_id = 'a0000000-0000-4000-8000-000000000008';
end $$;
