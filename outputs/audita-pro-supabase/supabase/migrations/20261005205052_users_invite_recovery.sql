begin;
alter table public.user_invites add column if not exists invite_payload jsonb;
alter table public.user_invites drop constraint if exists user_invites_status_check;
alter table public.user_invites add constraint user_invites_status_check
  check (status in ('pending','sent','accepted','failed','expired','existing_account','superseded'));
commit;
