-- Sign-in is Google or Apple. App review cannot use either: Google Play's
-- reviewers do not sign in with personal accounts, and both stores want a
-- demo account they can be handed. So e-mail and password exist as a
-- provider, but only for addresses listed here — accounts the operator sets
-- up for the stores. Anyone else trying to sign up by e-mail is refused
-- before the account exists, so e-mail cannot be used to mint accounts with
-- fresh AI allowances.
--
-- Add a review account (as the service role, then create the user with the
-- Auth admin API and a strong password):
--   insert into public.review_accounts (email, note) values ('…', 'App Store review');

create table public.review_accounts (
  email extensions.citext primary key,
  note text not null default '',
  created_at timestamptz not null default now()
);
alter table public.review_accounts enable row level security;
revoke all on public.review_accounts from public, anon, authenticated;

-- Runs inside Auth before every new user (config.toml:
-- [auth.hook.before_user_created]). OAuth sign-ups pass; e-mail sign-ups
-- pass only for listed addresses.
create or replace function public.hook_before_user_created(event jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_provider text := coalesce(event -> 'user' -> 'app_metadata' ->> 'provider', '');
  v_email text := event -> 'user' ->> 'email';
begin
  if v_provider in ('google', 'apple') then
    return '{}'::jsonb;
  end if;
  if v_email is not null
     and exists (
       -- lower() on both sides: with an empty search_path, citext's own
       -- case-insensitive operator is not the one = finds.
       select 1 from public.review_accounts r where lower(r.email::text) = lower(v_email)
     ) then
    return '{}'::jsonb;
  end if;
  return jsonb_build_object('error', jsonb_build_object(
    'http_code', 403,
    'message', 'Sign up with Google or Apple.'
  ));
end;
$$;

revoke execute on function public.hook_before_user_created(jsonb) from public, anon, authenticated;
grant usage on schema public to supabase_auth_admin;
grant execute on function public.hook_before_user_created(jsonb) to supabase_auth_admin;
grant select on public.review_accounts to supabase_auth_admin;
create policy "Auth reads the review accounts" on public.review_accounts
  for select to supabase_auth_admin using (true);
