-- Households: a shared meal plan and shopping list.
--
-- A household is the people who cook and shop together — a couple, a flat,
-- a family. Everyone in it may plan meals, add to the list and tick things
-- off; the rows are shared and edited in place (not events), and realtime
-- carries every change to the other phones while they are open.
--
-- Someone living alone simply has a household of one, so the app has one
-- code path.
--
-- What members see of each other: name and emoji, and — only if a member
-- switches it on — their daily calorie and protein targets, so whoever plans
-- can size the portions. The food diary is never part of a household.

-- ---------------------------------------------------------------------------
-- Households and members
-- ---------------------------------------------------------------------------

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null default '' check (char_length(name) <= 60),
  -- When the household shops; see ShoppingCadence in hundred_core.
  cadence jsonb not null default '{"kind":"weekly","weekday":6}'::jsonb,
  -- Things usually at home, left off generated lists ("salt", "oil").
  pantry text[] not null default '{}',
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.household_members (
  household_id uuid not null references public.households (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  share_targets boolean not null default false,
  kcal_target integer check (kcal_target between 800 and 8000),
  protein_g integer check (protein_g between 0 and 600),
  -- {"diet": "vegetarian", "dislikes": [...], "allergies": [...]}
  preferences jsonb not null default '{}'::jsonb check (pg_column_size(preferences) <= 4096),
  joined_at timestamptz not null default now(),
  primary key (household_id, user_id)
);

create index household_members_user_idx on public.household_members (user_id);

-- Targets are only stored while the member shares them: switching sharing
-- off removes them, rather than merely hiding them in the app.
create or replace function public.clear_unshared_targets()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not new.share_targets then
    new.kcal_target := null;
    new.protein_g := null;
  end if;
  return new;
end;
$$;

create trigger household_members_targets before insert or update on public.household_members
  for each row execute function public.clear_unshared_targets();

create or replace function public.is_household_member(p_household uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.household_members m
    where m.household_id = p_household and m.user_id = auth.uid()
  );
$$;

create or replace function public.is_household_owner(p_household uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.household_members m
    where m.household_id = p_household and m.user_id = auth.uid() and m.role = 'owner'
  );
$$;

alter table public.households enable row level security;
alter table public.household_members enable row level security;

create policy "Members see their household" on public.households
  for select to authenticated using (public.is_household_member(id));
create policy "Members change their household" on public.households
  for update to authenticated
  using (public.is_household_member(id))
  with check (public.is_household_member(id));

create policy "Members see each other" on public.household_members
  for select to authenticated using (public.is_household_member(household_id));
create policy "Members change their own membership" on public.household_members
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
-- Leaving: anyone for themselves; the owner may remove others.
create policy "Members leave, owners remove" on public.household_members
  for delete to authenticated
  using (user_id = (select auth.uid()) or public.is_household_owner(household_id));

-- Joining goes through the functions below; a member cannot change their
-- role or move to another household by editing the row.
create or replace function public.guard_membership_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.household_id <> old.household_id or new.user_id <> old.user_id or new.role <> old.role then
    raise exception 'membership fields are fixed' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger household_members_guard before update on public.household_members
  for each row execute function public.guard_membership_update();

-- ---------------------------------------------------------------------------
-- Invites
-- ---------------------------------------------------------------------------

create table public.household_invites (
  code text primary key,
  household_id uuid not null references public.households (id) on delete cascade,
  created_by uuid references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  uses integer not null default 0,
  max_uses integer not null default 10,
  revoked boolean not null default false
);

alter table public.household_invites enable row level security;
create policy "Members see their household's invites" on public.household_invites
  for select to authenticated using (public.is_household_member(household_id));

-- A household for the caller, with the caller as owner. Returns its id.
create or replace function public.create_household(p_name text default '')
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  insert into public.households (name, created_by) values (left(coalesce(p_name, ''), 60), auth.uid())
  returning id into v_id;
  insert into public.household_members (household_id, user_id, role) values (v_id, auth.uid(), 'owner');
  return v_id;
end;
$$;

-- The current invite code of a household the caller belongs to.
create or replace function public.household_invite_code(p_household uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  if not public.is_household_member(p_household) then
    raise exception 'not a member' using errcode = '42501';
  end if;
  select code into v_code from public.household_invites
  where household_id = p_household and not revoked
    and expires_at > now() + interval '1 day' and uses < max_uses
  order by created_at desc limit 1;
  if v_code is not null then return v_code; end if;
  loop
    v_code := public.random_code(8);
    begin
      insert into public.household_invites (code, household_id, created_by)
      values (v_code, p_household, auth.uid());
      return v_code;
    exception when unique_violation then
    end;
  end loop;
end;
$$;

-- Who is behind a household invite, for the confirmation screen.
create or replace function public.household_invite_preview(p_code text)
returns table (household_id uuid, name text, members jsonb)
language sql
stable
security definer
set search_path = ''
as $$
  select h.id, h.name,
         (select jsonb_agg(jsonb_build_object('name', p.display_name, 'emoji', p.emoji))
          from public.household_members m join public.profiles p on p.id = m.user_id
          where m.household_id = h.id)
  from public.household_invites i join public.households h on h.id = i.household_id
  where i.code = upper(p_code) and not i.revoked and i.expires_at > now() and i.uses < i.max_uses;
$$;

-- Joins the household behind an invite. A household the caller had alone,
-- with nothing planned in it, is removed — the usual case of someone moving
-- in with a partner who already planned.
create or replace function public.join_household(p_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_household uuid;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  update public.household_invites set uses = uses + 1
  where code = upper(p_code) and not revoked and expires_at > now() and uses < max_uses
  returning household_id into v_household;
  if v_household is null then raise exception 'invalid invite' using errcode = 'P0002'; end if;

  insert into public.household_members (household_id, user_id) values (v_household, auth.uid())
  on conflict do nothing;

  delete from public.households h
  where h.id <> v_household
    and exists (select 1 from public.household_members m where m.household_id = h.id and m.user_id = auth.uid())
    and (select count(*) from public.household_members m where m.household_id = h.id) = 1
    and not exists (select 1 from public.meal_plan_entries e where e.household_id = h.id)
    and not exists (select 1 from public.shopping_lists l where l.household_id = h.id);

  return v_household;
end;
$$;

-- ---------------------------------------------------------------------------
-- Recipes, the plan, shopping lists
-- ---------------------------------------------------------------------------

create table public.recipes (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  servings integer not null default 2 check (servings between 1 and 12),
  -- [{name, qty, unit, category}], see Recipe in hundred_core.
  ingredients jsonb not null default '[]'::jsonb check (pg_column_size(ingredients) <= 16384),
  -- One serving: {kcal, p, c, f}.
  nutrition jsonb not null default '{}'::jsonb,
  minutes integer check (minutes between 1 and 600),
  steps jsonb not null default '[]'::jsonb check (pg_column_size(steps) <= 16384),
  tags text[] not null default '{}',
  source text not null default 'manual' check (source in ('ai', 'manual')),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index recipes_household_idx on public.recipes (household_id);

create table public.meal_plan_entries (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  day date not null,
  slot text not null check (slot in ('breakfast', 'lunch', 'snack', 'dinner')),
  recipe_id uuid not null references public.recipes (id) on delete cascade,
  -- member id -> portions; empty: one each.
  portions jsonb not null default '{}'::jsonb,
  note text check (char_length(note) <= 280),
  created_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now()
);

create index meal_plan_entries_day_idx on public.meal_plan_entries (household_id, day);

create table public.shopping_lists (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  title text not null default '' check (char_length(title) <= 80),
  period_start date not null,
  period_end date not null check (period_end >= period_start),
  status text not null default 'open' check (status in ('open', 'done')),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index shopping_lists_household_idx on public.shopping_lists (household_id, created_at desc);

create table public.shopping_items (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references public.shopping_lists (id) on delete cascade,
  -- Denormalised from the list, so the policy needs no join per row.
  household_id uuid not null references public.households (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  qty numeric check (qty > 0 and qty < 100000),
  unit text check (unit in ('g', 'ml', 'piece', 'tbsp', 'tsp')),
  category text not null default 'other',
  checked boolean not null default false,
  checked_by uuid references auth.users (id) on delete set null,
  note text check (char_length(note) <= 280),
  recipe_ids uuid[] not null default '{}',
  added_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now()
);

create index shopping_items_list_idx on public.shopping_items (list_id);

-- An item's household must be its list's household.
create or replace function public.check_item_household()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (select 1 from public.shopping_lists l where l.id = new.list_id and l.household_id = new.household_id) then
    raise exception 'item and list belong to different households' using errcode = '23514';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger shopping_items_household before insert or update on public.shopping_items
  for each row execute function public.check_item_household();

create trigger meal_plan_entries_touch before update on public.meal_plan_entries
  for each row execute function public.touch_updated_at();

do $$
declare
  t text;
begin
  foreach t in array array['recipes', 'meal_plan_entries', 'shopping_lists', 'shopping_items'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format($p$create policy "Members read" on public.%I for select to authenticated
                     using (public.is_household_member(household_id))$p$, t);
    execute format($p$create policy "Members add" on public.%I for insert to authenticated
                     with check (public.is_household_member(household_id))$p$, t);
    execute format($p$create policy "Members change" on public.%I for update to authenticated
                     using (public.is_household_member(household_id))
                     with check (public.is_household_member(household_id))$p$, t);
    execute format($p$create policy "Members remove" on public.%I for delete to authenticated
                     using (public.is_household_member(household_id))$p$, t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('revoke all on public.%I from anon', t);
  end loop;
end;
$$;

revoke all on public.households, public.household_members, public.household_invites from anon;
grant select, update on public.households to authenticated;
grant select, update, delete on public.household_members to authenticated;
grant select on public.household_invites to authenticated;

revoke all on function public.is_household_member(uuid) from public, anon;
revoke all on function public.is_household_owner(uuid) from public, anon;
grant execute on function public.is_household_owner(uuid) to authenticated;
revoke all on function public.create_household(text) from public, anon;
revoke all on function public.household_invite_code(uuid) from public, anon;
revoke all on function public.household_invite_preview(text) from public, anon;
revoke all on function public.join_household(text) from public, anon;
grant execute on function public.is_household_member(uuid) to authenticated;
grant execute on function public.create_household(text) to authenticated;
grant execute on function public.household_invite_code(uuid) to authenticated;
grant execute on function public.household_invite_preview(text) to authenticated;
grant execute on function public.join_household(text) to authenticated;

alter publication supabase_realtime add table public.meal_plan_entries;
alter publication supabase_realtime add table public.shopping_lists;
alter publication supabase_realtime add table public.shopping_items;
alter publication supabase_realtime add table public.household_members;
alter publication supabase_realtime add table public.recipes;
