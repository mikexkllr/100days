-- Foundation: profiles, the event feed, friendships and invite codes.
--
-- The app is event-sourced. Every action a user takes (a check-in, a logged
-- meal, a nudge) is one row in `events`, and everything on screen is a fold
-- over those rows, computed on the device by `hundred_core`. Postgres is the
-- source of truth; Row Level Security decides who may read which event.
--
-- Two rules hold the design together:
--   1. Events are append-only. There are no UPDATE or DELETE policies, so a
--      streak cannot be rewritten after the fact. A correction is a new event
--      (`food.removed`, `challenge.updated`).
--   2. `created_at` is the server's clock and cannot be set by a client. A day
--      logged later than it happened is visible as a backfill on every device.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create extension if not exists citext with schema extensions;

-- Random, unambiguous code for invite links: no 0/O, no 1/l/I.
create or replace function public.random_code(p_length integer default 10)
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_alphabet constant text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  v_bytes bytea := extensions.gen_random_bytes(p_length);
  v_code text := '';
begin
  for i in 0 .. p_length - 1 loop
    v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % 32) + 1, 1);
  end loop;
  return v_code;
end;
$$;

-- ---------------------------------------------------------------------------
-- Profiles: the name and emoji people see. Readable by every signed-in user,
-- like a profile in any social app: friend search, invites and leagues need
-- it. Nothing else about a person lives here.
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 40),
  emoji text not null default '🙂' check (char_length(emoji) <= 16),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Signed-in users can read profiles" on public.profiles
  for select to authenticated using (true);

create policy "Users can update their own profile" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- A profile row for every new account, named after the first word of the
-- name the identity provider reports (Google sends it, Apple only once).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := coalesce(
    new.raw_user_meta_data ->> 'given_name',
    split_part(coalesce(new.raw_user_meta_data ->> 'full_name',
                        new.raw_user_meta_data ->> 'name', ''), ' ', 1),
    ''
  );
begin
  insert into public.profiles (id, display_name)
  values (new.id, left(v_name, 40))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Friendships: one row per pair. `requester` asked, `addressee` answers.
-- ---------------------------------------------------------------------------

create table public.friendships (
  requester uuid not null references auth.users (id) on delete cascade,
  addressee uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  primary key (requester, addressee),
  check (requester <> addressee)
);

-- One row per pair, whichever way round it was asked.
create unique index friendships_pair_idx on public.friendships (
  least(requester, addressee), greatest(requester, addressee)
);
create index friendships_addressee_idx on public.friendships (addressee);

alter table public.friendships enable row level security;

create policy "Users see their own friendships" on public.friendships
  for select to authenticated
  using ((select auth.uid()) in (requester, addressee));

-- Writes go through the functions below, which enforce who may do what.
revoke insert, update, delete on public.friendships from anon, authenticated;

-- True when [a] and [b] are accepted friends. Used by RLS on events, so it is
-- SECURITY DEFINER (it must see rows the caller's own policy would hide) and
-- STABLE (Postgres may evaluate it once per statement and pair).
create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and least(f.requester, f.addressee) = least(a, b)
      and greatest(f.requester, f.addressee) = greatest(a, b)
  );
$$;

-- The caller's accepted friends.
create or replace function public.friend_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select case when f.requester = auth.uid() then f.addressee else f.requester end
  from public.friendships f
  where f.status = 'accepted' and auth.uid() in (f.requester, f.addressee);
$$;

-- Asks [p_target] to be friends. If they already asked the caller, this
-- accepts instead: two people adding each other are friends.
create or replace function public.send_friend_request(p_target uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_existing public.friendships;
begin
  if v_me is null then raise exception 'not signed in' using errcode = '28000'; end if;
  if p_target = v_me then raise exception 'cannot befriend yourself' using errcode = '22023'; end if;
  if not exists (select 1 from auth.users where id = p_target) then
    raise exception 'unknown user' using errcode = 'P0002';
  end if;

  select * into v_existing from public.friendships f
  where least(f.requester, f.addressee) = least(v_me, p_target)
    and greatest(f.requester, f.addressee) = greatest(v_me, p_target);

  if found then
    if v_existing.status = 'accepted' then return 'accepted'; end if;
    if v_existing.requester = p_target then
      update public.friendships set status = 'accepted', responded_at = now()
      where requester = p_target and addressee = v_me;
      return 'accepted';
    end if;
    return 'pending';
  end if;

  insert into public.friendships (requester, addressee) values (v_me, p_target);
  return 'pending';
end;
$$;

-- Accepts or declines a request someone sent the caller.
create or replace function public.respond_friend_request(p_requester uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_accept then
    update public.friendships set status = 'accepted', responded_at = now()
    where requester = p_requester and addressee = auth.uid() and status = 'pending';
  else
    delete from public.friendships
    where requester = p_requester and addressee = auth.uid() and status = 'pending';
  end if;
end;
$$;

-- Ends a friendship, or withdraws a request, from either side.
create or replace function public.remove_friend(p_other uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.friendships f
  where least(f.requester, f.addressee) = least(auth.uid(), p_other)
    and greatest(f.requester, f.addressee) = greatest(auth.uid(), p_other)
    and auth.uid() in (f.requester, f.addressee);
$$;

-- ---------------------------------------------------------------------------
-- Invite codes: what a QR code or a shared link carries. Whoever shares one
-- has already said yes, so redeeming it makes both friends straight away.
-- Codes expire and can be revoked, because a link can travel further than
-- intended.
-- ---------------------------------------------------------------------------

create table public.invite_codes (
  code text primary key,
  owner uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '14 days',
  uses integer not null default 0,
  max_uses integer not null default 25,
  revoked boolean not null default false
);

create index invite_codes_owner_idx on public.invite_codes (owner);

alter table public.invite_codes enable row level security;

create policy "Users see their own invite codes" on public.invite_codes
  for select to authenticated using (owner = (select auth.uid()));

revoke insert, update, delete on public.invite_codes from anon, authenticated;

-- The caller's current invite code, minted if none is valid any more.
create or replace function public.my_invite_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  select code into v_code from public.invite_codes
  where owner = auth.uid() and not revoked and expires_at > now() + interval '1 day'
    and uses < max_uses
  order by created_at desc limit 1;
  if v_code is not null then return v_code; end if;

  loop
    v_code := public.random_code(10);
    begin
      insert into public.invite_codes (code, owner) values (v_code, auth.uid());
      return v_code;
    exception when unique_violation then
      -- 32^10 codes; a collision is astronomically rare, but retry anyway.
    end;
  end loop;
end;
$$;

-- Revokes every open code of the caller, e.g. after a link went too far.
create or replace function public.revoke_invite_codes()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.invite_codes set revoked = true
  where owner = auth.uid() and not revoked;
$$;

-- Who an invite code belongs to, for the confirmation screen.
create or replace function public.invite_preview(p_code text)
returns table (user_id uuid, display_name text, emoji text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.display_name, p.emoji
  from public.invite_codes c join public.profiles p on p.id = c.owner
  where c.code = upper(p_code) and not c.revoked
    and c.expires_at > now() and c.uses < c.max_uses;
$$;

-- Redeems an invite: caller and owner become friends. Returns the owner.
create or replace function public.redeem_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_owner uuid;
begin
  if v_me is null then raise exception 'not signed in' using errcode = '28000'; end if;

  update public.invite_codes set uses = uses + 1
  where code = upper(p_code) and not revoked and expires_at > now() and uses < max_uses
  returning owner into v_owner;

  if v_owner is null then raise exception 'invalid invite' using errcode = 'P0002'; end if;
  if v_owner = v_me then return v_owner; end if;

  insert into public.friendships (requester, addressee, status, responded_at)
  values (v_owner, v_me, 'accepted', now())
  on conflict do nothing;
  -- Turn a pending request in either direction into a friendship.
  update public.friendships set status = 'accepted', responded_at = now()
  where least(requester, addressee) = least(v_me, v_owner)
    and greatest(requester, addressee) = greatest(v_me, v_owner)
    and status = 'pending';
  return v_owner;
end;
$$;

-- ---------------------------------------------------------------------------
-- Events: the feed.
-- ---------------------------------------------------------------------------

create table public.events (
  -- Generated on the device, so an event written offline keeps its identity
  -- when it is pushed later, and a retried push is a no-op.
  id uuid primary key,
  author uuid not null default auth.uid() references auth.users (id) on delete cascade,
  type text not null check (char_length(type) between 1 and 40),
  payload jsonb not null default '{}'::jsonb check (pg_column_size(payload) <= 65536),
  -- private: only the author. friends: the author's accepted friends too.
  visibility text not null check (visibility in ('private', 'friends')),
  -- When the device says it happened. Up to 10 minutes of clock skew ahead.
  client_ts timestamptz not null,
  -- When the server received it. Set by a trigger; a client cannot choose it.
  created_at timestamptz not null default now(),
  -- Pull cursor: strictly increasing in commit order of inserts.
  server_seq bigint generated always as identity unique
);

create index events_author_seq_idx on public.events (author, server_seq);

alter table public.events enable row level security;

create policy "Authors and their friends read events" on public.events
  for select to authenticated
  using (
    author = (select auth.uid())
    or (visibility = 'friends' and author in (select public.friend_ids()))
  );

create policy "Users append to their own feed" on public.events
  for insert to authenticated
  with check (
    author = (select auth.uid())
    and client_ts <= now() + interval '10 minutes'
  );

-- Append-only: nobody rewrites history. Account deletion cascades from
-- auth.users, which runs as the service role.
revoke update, delete, truncate on public.events from anon, authenticated;

create or replace function public.stamp_event()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.created_at := now();
  return new;
end;
$$;

create trigger events_stamp before insert on public.events
  for each row execute function public.stamp_event();

-- ---------------------------------------------------------------------------
-- Realtime: friends' check-ins and nudges arrive while the app is open.
-- Realtime applies the SELECT policy above to every subscriber.
-- ---------------------------------------------------------------------------

alter publication supabase_realtime add table public.events;
alter publication supabase_realtime add table public.friendships;

-- ---------------------------------------------------------------------------
-- Grants for the RPCs above: signed-in users only.
-- ---------------------------------------------------------------------------

revoke all on function public.are_friends(uuid, uuid) from public, anon;
revoke all on function public.friend_ids() from public, anon;
revoke all on function public.send_friend_request(uuid) from public, anon;
revoke all on function public.respond_friend_request(uuid, boolean) from public, anon;
revoke all on function public.remove_friend(uuid) from public, anon;
revoke all on function public.my_invite_code() from public, anon;
revoke all on function public.revoke_invite_codes() from public, anon;
revoke all on function public.invite_preview(text) from public, anon;
revoke all on function public.redeem_invite(text) from public, anon;
revoke all on function public.random_code(integer) from public, anon, authenticated;

grant execute on function public.are_friends(uuid, uuid) to authenticated;
grant execute on function public.friend_ids() to authenticated;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.respond_friend_request(uuid, boolean) to authenticated;
grant execute on function public.remove_friend(uuid) to authenticated;
grant execute on function public.my_invite_code() to authenticated;
grant execute on function public.revoke_invite_codes() to authenticated;
grant execute on function public.invite_preview(text) to authenticated;
grant execute on function public.redeem_invite(text) to authenticated;
