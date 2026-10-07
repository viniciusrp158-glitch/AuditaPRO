begin;
create table public.in_app_notifications (
 id uuid primary key default gen_random_uuid(), recipient_id uuid not null references auth.users(id) on delete restrict,
 event_key text not null, event_type text not null, entity_type text not null default 'profile_submission',
 entity_id uuid not null, submission_id uuid references public.profile_submissions(id) on delete restrict,
 title text not null, message text not null, admin_only boolean not null default false,
 created_at timestamptz not null default clock_timestamp(), read_at timestamptz,
 unique(recipient_id,event_key)
);
create index notifications_recipient_time on public.in_app_notifications(recipient_id,created_at desc,id desc);
create index notifications_unread on public.in_app_notifications(recipient_id,created_at desc) where read_at is null;
create index notifications_submission on public.in_app_notifications(submission_id);
alter table public.in_app_notifications enable row level security;
revoke all on public.in_app_notifications from anon,authenticated;
grant select on public.in_app_notifications to authenticated;
grant all on public.in_app_notifications to service_role;
create policy notifications_owner_read on public.in_app_notifications for select to authenticated
 using(recipient_id=(select auth.uid()) and private.is_active_account((select auth.uid())) and (not admin_only or public.is_platform_admin()));

alter table public.profile_submissions add column notification_revision bigint not null default 0;
create function private.notification_revision() returns trigger language plpgsql set search_path='' as $$
begin
 if new.state is distinct from old.state or new.reviewer_id is distinct from old.reviewer_id then
  new.notification_revision:=old.notification_revision+1;
  new.updated_at:=clock_timestamp();
 end if;
 return new;
end; $$;
create trigger profile_notification_revision before update on public.profile_submissions for each row execute function private.notification_revision();

create function private.emit_profile_notifications(s public.profile_submissions,previous_reviewer uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare kind text; caption text; body text; recipient uuid; prefix text; display_name text;
begin
 prefix:=s.id::text||':'||s.notification_revision::text||':';
 display_name:=left(coalesce(nullif(s.personal->>'full_name',''),'Um usuário'),200);
 if s.state='submitted' then
  if s.reviewer_id is not null and s.reviewer_id<>s.user_id and private.profile_admin(s.reviewer_id) then
   kind:=case when previous_reviewer is not null and previous_reviewer<>s.reviewer_id then 'profile_assigned' when s.version>1 then 'profile_resubmitted' else 'profile_submitted' end;
   caption:=case when kind='profile_assigned' then 'Cadastro atribuído a você' when kind='profile_resubmitted' then 'Cadastro reenviado para validação' else 'Novo cadastro para validação' end;
   body:=display_name||' · Versão '||s.version::text||'. Revise os dados e os documentos enviados.';
   insert into public.in_app_notifications(recipient_id,event_key,event_type,entity_id,submission_id,title,message,admin_only)
    values(s.reviewer_id,prefix||kind,kind,s.id,s.id,caption,body,true) on conflict(recipient_id,event_key) do nothing;
  else
   insert into public.in_app_notifications(recipient_id,event_key,event_type,entity_id,submission_id,title,message,admin_only)
    select p.user_id,prefix||'profile_assignment_needed','profile_assignment_needed',s.id,s.id,'Cadastro sem responsável',display_name||' aguarda definição do responsável pela análise.',true
    from public.user_profiles p where p.user_id<>s.user_id and private.profile_admin(p.user_id) on conflict(recipient_id,event_key) do nothing;
  end if;
 elsif s.state in ('approved','rejected') then
  kind:='profile_'||s.state;
  insert into public.in_app_notifications(recipient_id,event_key,event_type,entity_id,submission_id,title,message)
   values(s.user_id,prefix||kind,kind,s.id,s.id,
    case when s.state='approved' then 'Seu cadastro foi aprovado' else 'Seu cadastro precisa de correção' end,
    case when s.state='approved' then 'A análise da versão '||s.version::text||' foi concluída. Confira o resultado em Meu Perfil.' else 'Consulte os itens indicados em Meu Perfil e envie uma nova versão.' end)
   on conflict(recipient_id,event_key) do nothing;
 elsif s.state='withdrawn' and previous_reviewer is not null and private.profile_admin(previous_reviewer) and previous_reviewer<>s.user_id then
  insert into public.in_app_notifications(recipient_id,event_key,event_type,entity_id,submission_id,title,message,admin_only)
   values(previous_reviewer,prefix||'profile_withdrawn','profile_withdrawn',s.id,s.id,'Envio retirado para correção',display_name||' retirou o envio. Esta versão não pode mais ser aprovada.',true)
   on conflict(recipient_id,event_key) do nothing;
 end if;
end; $$;
create function private.profile_notification_event() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  if new.state='submitted' then perform private.emit_profile_notifications(new); end if;
 elsif new.state is distinct from old.state or (new.state='submitted' and new.reviewer_id is distinct from old.reviewer_id) then
  perform private.emit_profile_notifications(new,old.reviewer_id);
 end if;
 return new;
end; $$;
create trigger profile_notification_event after insert or update on public.profile_submissions for each row execute function private.profile_notification_event();

-- An unavailable reviewer returns pending work to the assignment queue immediately.
create function private.notification_reviewer_changed() returns trigger language plpgsql security definer set search_path='' as $$
declare target uuid;
begin
 target:=case when tg_table_schema='auth' then (to_jsonb(new)->>'id')::uuid else (to_jsonb(new)->>'user_id')::uuid end;
 if not private.profile_admin(target) then
  update public.profile_submissions set reviewer_id=null where reviewer_id=target and state='submitted';
 end if;
 return new;
end; $$;
create trigger profile_reviewer_account_changed after update of status on public.user_profiles for each row execute function private.notification_reviewer_changed();
create trigger profile_reviewer_role_changed after update of raw_app_meta_data on auth.users for each row execute function private.notification_reviewer_changed();

create function private.notification_is_pending(n public.in_app_notifications) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select case
 when n.event_type in ('profile_submitted','profile_resubmitted','profile_assigned') then s.state='submitted' and s.reviewer_id=n.recipient_id and private.profile_admin(n.recipient_id)
 when n.event_type='profile_assignment_needed' then s.state='submitted' and (s.reviewer_id is null or s.reviewer_id=s.user_id or not private.profile_admin(s.reviewer_id)) and private.profile_admin(n.recipient_id)
 when n.event_type='profile_rejected' then s.state='rejected' and s.user_id=n.recipient_id and not exists(select 1 from public.profile_submissions next_s where next_s.user_id=s.user_id and next_s.membership_id is not distinct from s.membership_id and next_s.version>s.version and next_s.state in ('submitted','approved','rejected','withdrawn'))
 else false end from public.profile_submissions s where s.id=n.submission_id),false);
$$;

create function private.notification_command(command text,payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); n public.in_app_notifications%rowtype; s public.profile_submissions%rowtype; result jsonb; page_number int:=greatest(0,least(coalesce((payload->>'page')::int,0),10000)); page_size int:=greatest(1,least(coalesce((payload->>'page_size')::int,10),30)); filter_value text:=coalesce(payload->>'filter','all'); dest text; detail text;
begin
 if not private.is_active_account(actor) then raise exception 'Sessão ausente ou conta inativa' using errcode='42501'; end if;
 if command in ('read','open') then
  select * into n from public.in_app_notifications where id=(payload->>'id')::uuid and recipient_id=actor and (not admin_only or private.profile_admin(actor)) for update;
  if not found then raise exception 'Notificação indisponível' using errcode='42501'; end if;
  update public.in_app_notifications set read_at=coalesce(read_at,clock_timestamp()) where id=n.id;
  if command='open' then
   select * into s from public.profile_submissions where id=n.submission_id;
   if s.id is null then return jsonb_build_object('action',null,'message','O registro relacionado não está disponível.'); end if;
   if n.admin_only then
    if s.state='submitted' and private.profile_admin(actor) and (s.reviewer_id=actor or (n.event_type='profile_assignment_needed' and (s.reviewer_id is null or not private.profile_admin(s.reviewer_id)))) then dest:='review_profile';
    else detail:=case when s.state='withdrawn' then 'Este envio foi retirado para correção.' when s.state in ('approved','rejected') then 'A análise desta versão já foi concluída.' else 'A demanda foi reatribuída ou não exige mais sua ação.' end; end if;
   elsif s.user_id=actor then dest:='view_profile_result';
   end if;
   return jsonb_build_object('action',dest,'submission_id',case when dest is not null then s.id end,'membership_id',case when dest is not null then s.membership_id end,'message',coalesce(detail,'Abra o cadastro para consultar o resultado.'));
  end if;
 elsif command='read_all' then
  if payload->>'before' is null then raise exception 'Atualize a lista antes de marcar como lida'; end if;
  update public.in_app_notifications set read_at=clock_timestamp() where recipient_id=actor and read_at is null and created_at<=least((payload->>'before')::timestamptz,clock_timestamp()) and (not admin_only or private.profile_admin(actor));
 elsif command<>'list' then raise exception 'Ação inválida'; end if;
 if filter_value not in ('all','unread','pending') then raise exception 'Filtro inválido'; end if;
 with visible as materialized (
  select nt.*, private.notification_is_pending(nt) pending from public.in_app_notifications nt
  where nt.recipient_id=actor and (not nt.admin_only or private.profile_admin(actor))
 ), filtered as (
  select * from visible where filter_value='all' or (filter_value='unread' and read_at is null) or (filter_value='pending' and pending)
 ), paged as (
  select * from filtered order by created_at desc,id desc limit page_size offset page_number*page_size
 ) select jsonb_build_object('unread_count',(select count(*) from visible where read_at is null),'pending_count',(select count(*) from visible where pending),'total',(select count(*) from filtered),'as_of',clock_timestamp(),
  'items',coalesce((select jsonb_agg(jsonb_build_object('id',id,'title',title,'message',message,'event_type',event_type,'created_at',created_at,'read_at',read_at,'pending',pending,'action_label',case when pending and admin_only and event_type='profile_assignment_needed' then 'Atribuir responsável' when pending and admin_only then 'Analisar cadastro' when pending then 'Corrigir Meu Perfil' else 'Ver situação' end,'action_state',case when pending then 'pending' when event_type in ('profile_submitted','profile_resubmitted','profile_assigned','profile_assignment_needed','profile_rejected') then 'resolved' else 'information' end) order by created_at desc,id desc) from paged),'[]'::jsonb)) into result;
 return result;
end; $$;
create function public.notification_command(command text,payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$ select private.notification_command(command,payload); $$;
revoke all on function private.notification_revision(),private.emit_profile_notifications(public.profile_submissions,uuid),private.profile_notification_event(),private.notification_reviewer_changed(),private.notification_is_pending(public.in_app_notifications),private.notification_command(text,jsonb),public.notification_command(text,jsonb) from public;
grant execute on function private.notification_command(text,jsonb),public.notification_command(text,jsonb) to authenticated;

-- Existing pending submissions receive their initial notice; completed history is not broadcast.
do $$ declare s public.profile_submissions%rowtype; begin
 for s in select * from public.profile_submissions where state='submitted' loop perform private.emit_profile_notifications(s); end loop;
end $$;
commit;
