begin;
alter table public.user_profiles add constraint user_profiles_name_required
  check (length(trim(full_name)) between 2 and 200) not valid;
create unique index if not exists user_documents_one_pending_per_membership_idx
  on public.user_documents(membership_id) where status='pending';
create unique index if not exists organization_access_requests_one_pending_idx
  on public.organization_access_requests(user_id,lower(organization_name)) where status='pending';
commit;
