-- Realtime applies row level security to inserts and updates, but not to
-- deletes: every subscriber to a table gets the primary key of every deleted
-- row. For `friendships` that key is the pair of people — anyone listening
-- would see every unfriending in the app — and for `household_members` it is
-- a household and a person. Both leave the publication; what the phones
-- listened for arrives another way.
--
--   Friends:    `social_pings`, one row per user, touched for both people
--               whenever a friendship of theirs is asked, accepted or ended.
--   Households: the `households` row itself, which now receives an UPDATE
--               whenever its settings or its membership change.

alter publication supabase_realtime drop table public.friendships;
alter publication supabase_realtime drop table public.household_members;

-- ---------------------------------------------------------------------------
-- Friends
-- ---------------------------------------------------------------------------

create table public.social_pings (
  -- A random key rather than the user's id, because the key of a deleted
  -- row (an account going) is what Realtime hands to every subscriber.
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  at timestamptz not null default now()
);

alter table public.social_pings enable row level security;
create policy "Users see their own pings" on public.social_pings
  for select to authenticated using (user_id = (select auth.uid()));
revoke all on public.social_pings from anon, authenticated;
grant select on public.social_pings to authenticated;

create or replace function public.ping_friendship_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_people uuid[];
begin
  v_people := case when tg_op = 'DELETE'
    then array[old.requester, old.addressee]
    else array[new.requester, new.addressee] end;
  insert into public.social_pings (user_id, at)
  select u, now() from unnest(v_people) u
  -- An account being deleted takes its friendships with it; it needs no
  -- ping, and could not hold one.
  where exists (select 1 from auth.users where id = u)
  on conflict (user_id) do update set at = excluded.at;
  return null;
end;
$$;
revoke all on function public.ping_friendship_change() from public, anon, authenticated;

create trigger friendships_ping
  after insert or update or delete on public.friendships
  for each row execute function public.ping_friendship_change();

alter publication supabase_realtime add table public.social_pings;

-- ---------------------------------------------------------------------------
-- Households
-- ---------------------------------------------------------------------------

alter table public.households add column updated_at timestamptz not null default now();

create trigger households_touch before update on public.households
  for each row execute function public.touch_updated_at();

-- A member joining, leaving, or changing what they share touches their
-- household, so the others hear about it through the household's own row —
-- which only members can read.
create or replace function public.touch_household()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.households set updated_at = now()
  where id = case when tg_op = 'DELETE' then old.household_id else new.household_id end;
  return null;
end;
$$;
revoke all on function public.touch_household() from public, anon, authenticated;

create trigger household_members_touch_household
  after insert or update or delete on public.household_members
  for each row execute function public.touch_household();

alter publication supabase_realtime add table public.households;
