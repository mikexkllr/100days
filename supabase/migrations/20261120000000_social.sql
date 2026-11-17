-- Social, the Duolingo way: usernames, contact matching, weekly leagues with
-- divisions, push tokens.

create extension if not exists pg_cron;

-- ---------------------------------------------------------------------------
-- Usernames: choosing one is choosing to be found by it.
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column username extensions.citext unique
    check (username ~ '^[a-z0-9_]{3,20}$');

-- Settings nobody else reads (profiles are readable by every signed-in user).
create table public.user_settings (
  user_id uuid primary key references auth.users (id) on delete cascade,
  -- Whether people who have this user's e-mail or phone in their contacts
  -- may find them. Off until the user turns it on.
  discoverable boolean not null default false,
  -- Weekly league with people beyond one's friends.
  league_opt_in boolean not null default true,
  -- For server-sent texts such as push notifications.
  language text not null default 'de' check (language in ('de', 'en')),
  notify jsonb not null default
    '{"nudge":true,"cheer":true,"friend_request":true,"friend_activity":true}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.user_settings enable row level security;
create policy "Users read their settings" on public.user_settings
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Users create their settings" on public.user_settings
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Users change their settings" on public.user_settings
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
revoke all on public.user_settings from anon;
grant select, insert, update on public.user_settings to authenticated;

create or replace function public.settings_of(p_user uuid)
returns public.user_settings
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select s from public.user_settings s where s.user_id = p_user),
    row(p_user, false, true, 'de',
        '{"nudge":true,"cheer":true,"friend_request":true,"friend_activity":true}'::jsonb,
        now())::public.user_settings
  );
$$;
revoke all on function public.settings_of(uuid) from public, anon, authenticated;
grant execute on function public.settings_of(uuid) to service_role;

-- People by username or name prefix — only those who chose a username.
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
  order by p.username
  limit 20;
$$;
revoke all on function public.search_profiles(text) from public, anon;
grant execute on function public.search_profiles(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Contact matching: HMACs of verified e-mail addresses and phone numbers,
-- written and read only by the `match-contacts` function. The pepper lives
-- in that function's secrets, so the table alone gives nothing away.
-- ---------------------------------------------------------------------------

create table public.contact_identifiers (
  kind text not null check (kind in ('email', 'phone')),
  hmac text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  primary key (kind, hmac)
);
create index contact_identifiers_user_idx on public.contact_identifiers (user_id);
alter table public.contact_identifiers enable row level security;
revoke all on public.contact_identifiers from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Weekly leagues: groups of up to 30 in a division, top ones up, bottom
-- ones down every Monday. Divisions are hundred_core's League enum:
-- 0 wood … 6 obsidian; everyone starts in bronze.
--
-- Honest limit: a stranger's weekly XP is what their phone reports, capped
-- per day. Among friends every phone recomputes XP from the events.
-- ---------------------------------------------------------------------------

create table public.league_divisions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  division integer not null default 1 check (division between 0 and 6)
);

create table public.league_groups (
  id uuid primary key default gen_random_uuid(),
  week text not null check (week ~ '^\d{4}-W\d{2}$'),
  division integer not null check (division between 0 and 6),
  closed boolean not null default false,
  created_at timestamptz not null default now()
);
create index league_groups_week_idx on public.league_groups (week, division);

create table public.league_entries (
  week text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  group_id uuid not null references public.league_groups (id) on delete cascade,
  xp integer not null default 0 check (xp >= 0),
  updated_at timestamptz not null default now(),
  primary key (week, user_id)
);
create index league_entries_group_idx on public.league_entries (group_id);

alter table public.league_divisions enable row level security;
alter table public.league_groups enable row level security;
alter table public.league_entries enable row level security;
revoke all on public.league_divisions, public.league_groups, public.league_entries from anon, authenticated;

create or replace function public.current_week()
returns text
language sql
stable
set search_path = ''
as $$
  select to_char(now() at time zone 'utc', 'IYYY-"W"IW');
$$;

-- Reports the caller's XP for the current week and puts them into a group
-- of their division if they have none yet. Capped at what the days so far
-- can plausibly earn (hundred_core's kMaxDailyXp per day).
create or replace function public.report_week_xp(p_week text, p_xp integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_division integer;
  v_group uuid;
  v_days integer := extract(isodow from now() at time zone 'utc')::integer;
begin
  if v_me is null then raise exception 'not signed in' using errcode = '28000'; end if;
  if p_week <> public.current_week() then return; end if;
  if not (public.settings_of(v_me)).league_opt_in then return; end if;

  insert into public.league_divisions (user_id) values (v_me) on conflict do nothing;
  select division into v_division from public.league_divisions where user_id = v_me;

  select group_id into v_group from public.league_entries where week = p_week and user_id = v_me;
  if v_group is null then
    select g.id into v_group
    from public.league_groups g
    where g.week = p_week and g.division = v_division and not g.closed
      and (select count(*) from public.league_entries e where e.group_id = g.id) < 30
    order by (select count(*) from public.league_entries e where e.group_id = g.id) desc
    limit 1
    for update skip locked;
    if v_group is null then
      insert into public.league_groups (week, division) values (p_week, v_division) returning id into v_group;
    end if;
  end if;

  insert into public.league_entries (week, user_id, group_id, xp, updated_at)
  values (p_week, v_me, v_group, least(greatest(p_xp, 0), 1000 * v_days), now())
  on conflict (week, user_id) do update
    set xp = least(greatest(p_xp, 0), 1000 * v_days), updated_at = now();
end;
$$;

-- The caller's group this week, ranked.
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
  order by r.rank;
$$;

-- Closes a week: promotion and demotion by rank, mirroring hundred_core's
-- promotionSlots / demotionSlots. Run by cron early on Monday.
create or replace function public.close_league_week(p_week text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  g record;
  v_size integer;
  v_up integer;
  v_down integer;
begin
  for g in select * from public.league_groups where week = p_week and not closed for update loop
    select count(*) into v_size from public.league_entries where group_id = g.id;
    v_up := case when v_size < 2 then 0 when v_size < 5 then 1 when v_size < 10 then 2 when v_size < 20 then 4 else 7 end;
    v_down := case when v_size < 5 then 0 when v_size < 10 then 1 when v_size < 20 then 3 else 5 end;

    update public.league_divisions d set division = least(d.division + 1, 6)
    where d.user_id in (
      select e.user_id from public.league_entries e where e.group_id = g.id and e.xp > 0
      order by e.xp desc, e.updated_at asc limit v_up
    );
    update public.league_divisions d set division = greatest(d.division - 1, 0)
    where d.user_id in (
      select e.user_id from public.league_entries e where e.group_id = g.id
      order by e.xp asc, e.updated_at desc limit v_down
    );
    update public.league_groups set closed = true where id = g.id;
  end loop;
end;
$$;

revoke all on function public.current_week() from public, anon;
revoke all on function public.report_week_xp(text, integer) from public, anon;
revoke all on function public.league_standing(text) from public, anon;
revoke all on function public.close_league_week(text) from public, anon, authenticated;
grant execute on function public.current_week() to authenticated;
grant execute on function public.report_week_xp(text, integer) to authenticated;
grant execute on function public.league_standing(text) to authenticated;
grant execute on function public.close_league_week(text) to service_role;

select cron.schedule(
  'close-league-week',
  '15 0 * * 1',
  $$select public.close_league_week(to_char((now() at time zone 'utc') - interval '1 day', 'IYYY-"W"IW'))$$
);

-- ---------------------------------------------------------------------------
-- Push: device tokens, and a log so nobody gets the same kind of push twice
-- a day.
-- ---------------------------------------------------------------------------

create table public.push_tokens (
  token text primary key check (char_length(token) <= 4096),
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);
create index push_tokens_user_idx on public.push_tokens (user_id);
alter table public.push_tokens enable row level security;
create policy "Users manage their tokens" on public.push_tokens
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
revoke all on public.push_tokens from anon;
grant select, insert, update, delete on public.push_tokens to authenticated;

create table public.push_log (
  recipient uuid not null references auth.users (id) on delete cascade,
  kind text not null,
  day date not null default (now() at time zone 'utc')::date,
  -- Who caused it; the recipient themselves for once-a-day kinds.
  sender uuid not null,
  primary key (recipient, kind, day, sender)
);
alter table public.push_log enable row level security;
revoke all on public.push_log from anon, authenticated;
