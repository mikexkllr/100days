-- Blocking and reporting. An app that shows strangers' names — search, the
-- public league — has to let people shut someone out and tell the operator
-- about them (App Store guideline 1.2).
--
-- A block is one-sided and silent. It ends a friendship and any open request
-- in either direction, and from then on neither side can ask the other,
-- redeem the other's invite, or find the other by username or address book.
-- The blocked person is not told; to them the blocker is simply not there.
--
-- A report goes to the operator and nobody else: the table has no policy a
-- user could read it through.

-- ---------------------------------------------------------------------------
-- Blocks
-- ---------------------------------------------------------------------------

create table public.blocks (
  blocker uuid not null references auth.users (id) on delete cascade,
  blocked uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);
create index blocks_blocked_idx on public.blocks (blocked);

alter table public.blocks enable row level security;
-- Only the blocker sees a block: the blocked person must not learn of it.
create policy "Users see whom they blocked" on public.blocks
  for select to authenticated using (blocker = (select auth.uid()));
revoke all on public.blocks from anon, authenticated;
grant select on public.blocks to authenticated;

-- True when either of [a] and [b] blocked the other. An internal helper for
-- the functions below, which run as the owner and see every block; not
-- callable by users, so nobody can probe who blocked whom.
create or replace function public.blocked_between(a uuid, b uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.blocks k
    where (k.blocker = a and k.blocked = b) or (k.blocker = b and k.blocked = a)
  );
$$;
revoke all on function public.blocked_between(uuid, uuid) from public, anon, authenticated;

-- Blocks [p_target]: ends whatever there was between the two.
create or replace function public.block_user(p_target uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not signed in' using errcode = '28000'; end if;
  if p_target is null or p_target = v_me then
    raise exception 'cannot block yourself' using errcode = '22023';
  end if;
  if not exists (select 1 from auth.users where id = p_target) then
    raise exception 'unknown user' using errcode = 'P0002';
  end if;

  insert into public.blocks (blocker, blocked) values (v_me, p_target) on conflict do nothing;
  delete from public.friendships f
  where least(f.requester, f.addressee) = least(v_me, p_target)
    and greatest(f.requester, f.addressee) = greatest(v_me, p_target);
end;
$$;

-- Lifts a block. Nothing that the block ended comes back by itself.
create or replace function public.unblock_user(p_target uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  delete from public.blocks where blocker = auth.uid() and blocked = p_target;
end;
$$;

-- The people the caller blocked, newest first, for the settings screen.
-- Invoker rights: the policy on blocks already limits it to the caller's own.
create or replace function public.my_blocks()
returns table (user_id uuid, display_name text, emoji text, username text, blocked_at timestamptz)
language sql
stable
set search_path = ''
as $$
  select k.blocked, p.display_name, p.emoji, p.username::text, k.created_at
  from public.blocks k join public.profiles p on p.id = k.blocked
  where k.blocker = (select auth.uid())
  order by k.created_at desc;
$$;

-- ---------------------------------------------------------------------------
-- Reports
-- ---------------------------------------------------------------------------

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  -- Kept, but anonymised, when either account goes.
  reporter uuid references auth.users (id) on delete set null,
  target uuid references auth.users (id) on delete set null,
  reason text not null check (reason in ('spam', 'harassment', 'inappropriate', 'cheating', 'other')),
  details text not null default '' check (char_length(details) <= 1000),
  -- What the target showed when reported: a name can be changed afterwards.
  target_name text,
  target_username text,
  created_at timestamptz not null default now()
);
create index reports_created_idx on public.reports (created_at desc);
create index reports_reporter_idx on public.reports (reporter, created_at);

alter table public.reports enable row level security;
-- No policy at all: users only ever write through report_user(). The
-- operator reads them as the service role.
revoke all on public.reports from anon, authenticated;
grant select, delete on public.reports to service_role;

-- Reports [p_target] to the operator. At most 20 a day, so the queue cannot
-- be flooded by one script.
create or replace function public.report_user(p_target uuid, p_reason text, p_details text default '')
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not signed in' using errcode = '28000'; end if;
  if p_target is null or p_target = v_me then
    raise exception 'cannot report yourself' using errcode = '22023';
  end if;
  if not exists (select 1 from auth.users where id = p_target) then
    raise exception 'unknown user' using errcode = 'P0002';
  end if;
  if (select count(*) from public.reports r
      where r.reporter = v_me and r.created_at > now() - interval '1 day') >= 20 then
    raise exception 'too many reports' using errcode = 'PT429';
  end if;

  insert into public.reports (reporter, target, reason, details, target_name, target_username)
  select v_me, p_target, p_reason, left(coalesce(p_details, ''), 1000), p.display_name, p.username::text
  from (select 1) dummy left join public.profiles p on p.id = p_target;
end;
$$;

-- ---------------------------------------------------------------------------
-- What a block keeps out
-- ---------------------------------------------------------------------------

-- Search: neither side finds the other.
create or replace function public.search_profiles(p_query text)
returns table (user_id uuid, display_name text, emoji text, username text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.display_name, p.emoji, p.username::text
  from public.profiles p
  where p.username is not null
    and p.id <> auth.uid()
    and char_length(trim(p_query)) >= 2
    and (p.username like lower(trim(leading '@' from trim(p_query))) || '%'
         or p.display_name ilike trim(p_query) || '%')
    and not public.blocked_between(auth.uid(), p.id)
  order by p.username
  limit 20;
$$;

-- Invites: a blocked person's code looks like an invalid one.
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
    and c.expires_at > now() and c.uses < c.max_uses
    and not public.blocked_between(auth.uid(), c.owner);
$$;

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

  -- The exception also undoes the use counted above.
  if v_owner is null or public.blocked_between(v_me, v_owner) then
    raise exception 'invalid invite' using errcode = 'P0002';
  end if;
  if v_owner = v_me then return v_owner; end if;

  insert into public.friendships (requester, addressee, status, responded_at)
  values (v_owner, v_me, 'accepted', now())
  on conflict do nothing;
  update public.friendships set status = 'accepted', responded_at = now()
  where least(requester, addressee) = least(v_me, v_owner)
    and greatest(requester, addressee) = greatest(v_me, v_owner)
    and status = 'pending';
  return v_owner;
end;
$$;

-- Requests: to the blocked person, the blocker is someone who is not there.
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
  if not exists (select 1 from auth.users where id = p_target)
     or public.blocked_between(v_me, p_target) then
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

-- The public league: someone the caller blocked, or who blocked the caller,
-- is left out of the list. Ranks and the group size stay the real ones.
create or replace function public.league_standing(p_week text)
returns table (user_id uuid, display_name text, emoji text, xp integer, rank integer, division integer, group_size integer)
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select e.group_id from public.league_entries e where e.week = p_week and e.user_id = auth.uid()
  ), ranked as (
    select e.user_id, e.xp,
           rank() over (order by e.xp desc, e.updated_at asc)::integer as rank,
           count(*) over ()::integer as group_size
    from public.league_entries e
    where e.group_id = (select group_id from mine)
  )
  select r.user_id, p.display_name, p.emoji, r.xp, r.rank,
         (select g.division from public.league_groups g where g.id = (select group_id from mine)),
         r.group_size
  from ranked r join public.profiles p on p.id = r.user_id
  where not public.blocked_between(auth.uid(), r.user_id)
  order by r.rank;
$$;

revoke all on function public.block_user(uuid) from public, anon;
revoke all on function public.unblock_user(uuid) from public, anon;
revoke all on function public.my_blocks() from public, anon;
revoke all on function public.report_user(uuid, text, text) from public, anon;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
grant execute on function public.my_blocks() to authenticated;
grant execute on function public.report_user(uuid, text, text) to authenticated;
