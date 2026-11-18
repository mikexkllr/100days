-- Anyone can now register with e-mail and password, not only the review
-- accounts in public.review_accounts. The hook stays wired up (config.toml:
-- [auth.hook.before_user_created]) as the place to refuse sign-ups again,
-- for example from throwaway domains; for now it lets every one through.
--
-- What keeps e-mail from minting fresh AI allowances is now the
-- confirmation mail (auth.email.enable_confirmations) and Auth's sign-up
-- rate limit. public.review_accounts is no longer read and stays as a note
-- of which accounts belong to the stores.

create or replace function public.hook_before_user_created(event jsonb)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select '{}'::jsonb;
$$;
