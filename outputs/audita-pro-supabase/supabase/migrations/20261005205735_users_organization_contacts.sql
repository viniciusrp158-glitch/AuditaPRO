begin;
alter table public.organizations
  add column if not exists institutional_email text,
  add column if not exists institutional_phone text;
alter table public.organizations add constraint organizations_institutional_email_valid
  check (institutional_email is null or
    (length(institutional_email) <= 254 and institutional_email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')) not valid;
commit;
