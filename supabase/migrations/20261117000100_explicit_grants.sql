-- Explicit table privileges.
--
-- Newer Supabase projects no longer grant every public table to `anon` and
-- `authenticated` by default, and relying on that default was never a good
-- idea for a project that others self-host. Each table gets exactly the
-- statements its policies are written for; RLS then decides which rows.

revoke all on public.profiles, public.friendships, public.invite_codes, public.events
  from anon;

grant select, update on public.profiles to authenticated;
grant select on public.friendships to authenticated;
grant select on public.invite_codes to authenticated;
grant select, insert on public.events to authenticated;

-- The identity column behind events.server_seq.
grant usage on all sequences in schema public to authenticated;
