-- Contact matching, fixed in two places.
--
-- The limit counted the day's calls and then logged the new one in two
-- steps, so parallel calls all saw the old count and all got through. It now
-- takes a lock per user first.
--
-- The lookup itself ran as a GET with up to 2000 hashes in the URL — about
-- 130 KB, far beyond what proxies accept. It is now one call with arrays in
-- the body, and it leaves out people who are not findable or have a block
-- with the caller in either direction.

create or replace function public.contact_match_allowed(p_user uuid, p_count integer)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_calls integer;
  v_identifiers integer;
begin
  -- Held until the calling transaction ends: one check-and-count per user at
  -- a time.
  perform pg_advisory_xact_lock(hashtextextended('contact_match:' || p_user::text, 0));
  select count(*), coalesce(sum(identifiers), 0) into v_calls, v_identifiers
  from public.contact_match_log
  where user_id = p_user and at > now() - interval '1 day';
  if v_calls >= 10 or v_identifiers + p_count > 5000 then
    return false;
  end if;
  insert into public.contact_match_log (user_id, identifiers) values (p_user, p_count);
  delete from public.contact_match_log where at < now() - interval '2 days';
  return true;
end;
$$;

-- Who of these hashed contacts [p_user] may find: registered, findable, and
-- no block between them. Service role only — the hashes mean nothing without
-- the function's pepper, but the answer does.
create or replace function public.match_contact_hashes(
  p_user uuid,
  p_emails text[],
  p_phones text[]
)
returns table (user_id uuid, display_name text, emoji text, username text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.display_name, p.emoji, p.username::text
  from public.profiles p
  where p.id in (
      select c.user_id from public.contact_identifiers c
      where (c.kind = 'email' and c.hmac = any (coalesce(p_emails, '{}')))
         or (c.kind = 'phone' and c.hmac = any (coalesce(p_phones, '{}')))
    )
    and p.id <> p_user
    and exists (select 1 from public.user_settings s where s.user_id = p.id and s.discoverable)
    and not public.blocked_between(p_user, p.id)
  limit 200;
$$;

revoke all on function public.match_contact_hashes(uuid, text[], text[]) from public, anon, authenticated;
grant execute on function public.match_contact_hashes(uuid, text[], text[]) to service_role;
