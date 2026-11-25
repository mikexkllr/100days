-- The public league's week, as the phones see it.
--
-- A phone reports the ISO week of its own calendar day; the server only took
-- the current week in UTC and silently dropped everything else. So from
-- Sunday afternoon in New Zealand and on Monday morning in California, XP
-- went nowhere. Now a report counts for any week some time zone
-- (UTC−12 … UTC+14) is in right now, its cap is the days that week has had
-- in the furthest-ahead zone, and the phone hears whether it counted.
--
-- And a week is closed once it is over everywhere — Monday 12:00 UTC is
-- midnight at UTC−12 — instead of shortly after midnight UTC, while half the
-- world was still in Sunday.

drop function public.report_week_xp(text, integer);

create or replace function public.report_week_xp(p_week text, p_xp integer)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_now timestamp := now() at time zone 'utc';
  v_days integer;
  v_division integer;
  v_group uuid;
  v_closed boolean;
begin
  if v_me is null then raise exception 'not signed in' using errcode = '28000'; end if;

  -- The weeks of the furthest-behind zone, UTC and the furthest-ahead zone,
  -- and for a matching week the most days any zone has had of it.
  select max(extract(isodow from t)::integer) into v_days
  from unnest(array[v_now - interval '12 hours', v_now, v_now + interval '14 hours']) t
  where to_char(t, 'IYYY-"W"IW') = p_week;
  if v_days is null then return false; end if;
  if not (public.settings_of(v_me)).league_opt_in then return false; end if;

  insert into public.league_divisions (user_id) values (v_me) on conflict do nothing;
  select division into v_division from public.league_divisions where user_id = v_me;

  select e.group_id, g.closed into v_group, v_closed
  from public.league_entries e join public.league_groups g on g.id = e.group_id
  where e.week = p_week and e.user_id = v_me;
  -- Promotions are already decided; a late number would only confuse.
  if v_closed then return false; end if;

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
  return true;
end;
$$;

revoke all on function public.report_week_xp(text, integer) from public, anon;
grant execute on function public.report_week_xp(text, integer) to authenticated;

-- Same job name: pg_cron replaces the schedule. "Yesterday" at Monday noon
-- is still the Sunday of the week that just ended.
select cron.schedule(
  'close-league-week',
  '15 12 * * 1',
  $$select public.close_league_week(to_char((now() at time zone 'utc') - interval '1 day', 'IYYY-"W"IW'))$$
);
