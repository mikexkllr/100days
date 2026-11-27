-- One household per person, and a plan that comes along.
--
-- Joining a household used to add a membership and nothing else: whatever
-- the joiner had planned stayed behind in the household of one they came
-- from, which the app no longer showed. It was neither shared nor gone, and
-- two people who had each planned could not get their plans into one.
--
-- Now someone who joins says what happens to what they had:
--
--   bring   their recipes, planned meals and shopping lists move into the
--           household they join;
--   drop    they go, with the household of one they were in.
--
-- Either way the joiner ends up in one household. One they shared with
-- others is left, and its plan stays with the others.
--
-- `keep` is what an app from before this migration asks for by not asking:
-- the old household stays, hidden, as it always did. settle_households() is
-- how the app clears that up afterwards, once the user has been asked.

-- ---------------------------------------------------------------------------
-- What a household holds, for whoever is about to join or leave it
-- ---------------------------------------------------------------------------

-- Meals planned from [p_today] on, recipes, and open lists with something on
-- them: the numbers the app shows before anything is moved or deleted.
create or replace function public.household_contents(p_household uuid, p_today date)
returns table (planned integer, recipes integer, lists integer)
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select count(*)::integer from public.meal_plan_entries e
     where e.household_id = p_household and e.day >= p_today),
    (select count(*)::integer from public.recipes r where r.household_id = p_household),
    (select count(*)::integer from public.shopping_lists l
     where l.household_id = p_household and l.status = 'open'
       and exists (select 1 from public.shopping_items i where i.list_id = l.id));
$$;
revoke all on function public.household_contents(uuid, date) from public, anon, authenticated;

-- Who is behind a household invite and what they have planned, for the
-- screen that asks before joining. `member` says the caller is in it already.
-- [p_today] is the caller's own day, so "planned" means the same on the
-- phone as here.
drop function public.household_invite_preview(text);
create function public.household_invite_preview(p_code text, p_today date default current_date)
returns table (
  household_id uuid,
  name text,
  members jsonb,
  planned integer,
  recipes integer,
  lists integer,
  member boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select h.id, h.name,
         (select jsonb_agg(jsonb_build_object('name', p.display_name, 'emoji', p.emoji) order by m.joined_at)
          from public.household_members m join public.profiles p on p.id = m.user_id
          where m.household_id = h.id),
         c.planned, c.recipes, c.lists,
         exists (select 1 from public.household_members m
                 where m.household_id = h.id and m.user_id = auth.uid())
  from public.household_invites i
    join public.households h on h.id = i.household_id
    cross join lateral public.household_contents(h.id, p_today) c
  where i.code = upper(p_code) and not i.revoked and i.expires_at > now() and i.uses < i.max_uses;
$$;

-- The caller's households other than [p_household]: what joining it would
-- take them out of, or what an earlier join left behind. `others` is who
-- else is in each; empty means it is the caller's alone, and its contents
-- theirs to bring or drop.
create function public.households_besides(p_household uuid, p_today date default current_date)
returns table (
  household_id uuid,
  name text,
  others jsonb,
  planned integer,
  recipes integer,
  lists integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select h.id, h.name,
         coalesce(
           (select jsonb_agg(jsonb_build_object('name', p.display_name, 'emoji', p.emoji) order by o.joined_at)
            from public.household_members o join public.profiles p on p.id = o.user_id
            where o.household_id = h.id and o.user_id <> auth.uid()),
           '[]'::jsonb),
         c.planned, c.recipes, c.lists
  from public.household_members m
    join public.households h on h.id = m.household_id
    cross join lateral public.household_contents(h.id, p_today) c
  where m.user_id = auth.uid() and m.household_id is distinct from p_household
  order by m.joined_at;
$$;

-- ---------------------------------------------------------------------------
-- Moving a plan
-- ---------------------------------------------------------------------------

-- What makes two dish names the same dish — `recipeKey` in hundred_core.
create or replace function public.recipe_key(p_title text)
returns text
language sql
immutable
set search_path = ''
as $$
  select lower(regexp_replace(btrim(p_title, E' \t\n\r'), '\s+', ' ', 'g'));
$$;
revoke all on function public.recipe_key(text) from public, anon, authenticated;

-- Moves what [p_from] holds into [p_into]. Whoever calls this has checked
-- that the caller may: it is not reachable from the API.
--
--   * Recipes all come along. A dish [p_into] already has by name stays the
--     one it has, and what was planned with the other is planned with it.
--   * Planned meals land on free slots. Where [p_into] has something on that
--     day and meal already, that stays and the other is not moved — its
--     recipe still is.
--   * Open lists with something on them come along, lines and ticks as they
--     are.
--
-- Settings — when the household shops, what is usually at home — stay
-- [p_into]'s. What is not moved goes when [p_from] is deleted.
create or replace function public.move_household_contents(p_from uuid, p_into uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_mine uuid;
  v_theirs uuid;
begin
  for v_mine, v_theirs in
    select r.id, t.id
    from public.recipes r
      cross join lateral (
        select x.id from public.recipes x
        where x.household_id = p_into
          and public.recipe_key(x.title) = public.recipe_key(r.title)
        order by x.created_at, x.id
        limit 1
      ) t
    where r.household_id = p_from and public.recipe_key(r.title) <> ''
  loop
    update public.meal_plan_entries set recipe_id = v_theirs
    where household_id = p_from and recipe_id = v_mine;
    update public.shopping_items set recipe_ids = array_replace(recipe_ids, v_mine, v_theirs)
    where household_id = p_from and v_mine = any (recipe_ids);
    delete from public.recipes where id = v_mine;
  end loop;

  update public.recipes set household_id = p_into where household_id = p_from;

  update public.meal_plan_entries e set household_id = p_into
  where e.household_id = p_from
    and not exists (
      select 1 from public.meal_plan_entries t
      where t.household_id = p_into and t.day = e.day and t.slot = e.slot
    );

  update public.shopping_lists l set household_id = p_into
  where l.household_id = p_from and l.status = 'open'
    and exists (select 1 from public.shopping_items i where i.list_id = l.id);
  update public.shopping_items i set household_id = p_into
  from public.shopping_lists l
  where l.id = i.list_id and l.household_id = p_into and i.household_id = p_from;
end;
$$;
revoke all on function public.move_household_contents(uuid, uuid) from public, anon, authenticated;

-- Makes [p_household], which the caller is in, the only household they are
-- in. A household they share with others is left and stays the others'. One
-- they are alone in goes — after its contents moved into [p_household], if
-- [p_bring].
create function public.settle_households(p_household uuid, p_bring boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_from uuid;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  if not public.is_household_member(p_household) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  for v_from in
    select m.household_id from public.household_members m
    where m.user_id = auth.uid() and m.household_id <> p_household
    order by m.joined_at
  loop
    if exists (
      select 1 from public.household_members o
      where o.household_id = v_from and o.user_id <> auth.uid()
    ) then
      delete from public.household_members
      where household_id = v_from and user_id = auth.uid();
    else
      if coalesce(p_bring, false) then
        perform public.move_household_contents(v_from, p_household);
      end if;
      delete from public.households where id = v_from;
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Joining
-- ---------------------------------------------------------------------------

-- Joins the household behind an invite. [p_mine] is what becomes of the
-- household the caller comes from: 'bring' or 'drop' (see the top of this
-- file), or 'keep' — the answer of an app that does not ask yet, which
-- leaves it where it is unless it is an empty household of one.
drop function public.join_household(text);
create function public.join_household(p_code text, p_mine text default 'keep')
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_household uuid;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  if p_mine is null or p_mine not in ('keep', 'bring', 'drop') then
    raise exception 'unknown choice for the old household' using errcode = '22023';
  end if;
  update public.household_invites set uses = uses + 1
  where code = upper(p_code) and not revoked and expires_at > now() and uses < max_uses
  returning household_id into v_household;
  if v_household is null then raise exception 'invalid invite' using errcode = 'P0002'; end if;

  insert into public.household_members (household_id, user_id) values (v_household, auth.uid())
  on conflict do nothing;

  if p_mine = 'keep' then
    delete from public.households h
    where h.id <> v_household
      and exists (select 1 from public.household_members m where m.household_id = h.id and m.user_id = auth.uid())
      and (select count(*) from public.household_members m where m.household_id = h.id) = 1
      and not exists (select 1 from public.meal_plan_entries e where e.household_id = h.id)
      and not exists (select 1 from public.shopping_lists l where l.household_id = h.id);
  else
    perform public.settle_households(v_household, p_mine = 'bring');
  end if;

  return v_household;
end;
$$;

revoke all on function public.household_invite_preview(text, date) from public, anon;
revoke all on function public.households_besides(uuid, date) from public, anon;
revoke all on function public.settle_households(uuid, boolean) from public, anon;
revoke all on function public.join_household(text, text) from public, anon;
grant execute on function public.household_invite_preview(text, date) to authenticated;
grant execute on function public.households_besides(uuid, date) to authenticated;
grant execute on function public.settle_households(uuid, boolean) to authenticated;
grant execute on function public.join_household(text, text) to authenticated;
