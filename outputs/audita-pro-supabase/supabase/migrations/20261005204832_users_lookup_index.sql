begin;
create index if not exists user_profiles_email_lookup_idx on public.user_profiles(email);
commit;
