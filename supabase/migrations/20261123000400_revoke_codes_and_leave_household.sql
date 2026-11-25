-- Codes that outlive the relationship they were for, and leaving a
-- household.
--
-- An invite code is good for days and several uses. Someone removed from a
-- household, or unfriended, could otherwise use the old code to walk straight
-- back in. So:
--
--   * Removing a member revokes the household's open codes. Leaving on one's
--     own does not: whoever leaves is not being kept out.
--   * Ending a friendship revokes the open friend codes of whoever ended it.
--
-- And a household no longer depends on its owner staying: when the owner
-- leaves or deletes their account, the member who has been there longest
-- takes over. A household nobody is left in is dropped
-- (20261121000000_drop_empty_households.sql).

-- ---------------------------------------------------------------------------
-- Ownership passes on
-- ---------------------------------------------------------------------------

-- The role is still fixed for members editing their own row; the database's
-- own functions (running as their owner) may hand it on.
create or replace function public.guard_membership_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.household_id <> old.household_id or new.user_id <> old.user_id then
    raise exception 'membership fields are fixed' using errcode = '42501';
  end if;
  if new.role <> old.role and current_user in ('anon', 'authenticated') then
    raise exception 'membership fields are fixed' using errcode = '42501';
  end if;
  return new;
end;
$$;

create or replace function public.pass_household_ownership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.role = 'owner' and not exists (
    select 1 from public.household_members m
    where m.household_id = old.household_id and m.role = 'owner'
  ) then
    update public.household_members set role = 'owner'
    where household_id = old.household_id
      and user_id = (
        select m.user_id from public.household_members m
        where m.household_id = old.household_id
        order by m.joined_at, m.user_id
        limit 1
      );
  end if;
  return null;
end;
$$;
revoke all on function public.pass_household_ownership() from public, anon, authenticated;

create trigger household_members_pass_ownership
  after delete on public.household_members
  for each row execute function public.pass_household_ownership();

-- ---------------------------------------------------------------------------
-- Household codes
-- ---------------------------------------------------------------------------

create or replace function public.revoke_household_invites_on_removal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Removed by someone else (the owner). Not on leaving, and not on an
  -- account deletion, where there is no caller.
  if auth.uid() is not null and auth.uid() <> old.user_id then
    update public.household_invites set revoked = true
    where household_id = old.household_id and not revoked;
  end if;
  return null;
end;
$$;
revoke all on function public.revoke_household_invites_on_removal() from public, anon, authenticated;

create trigger household_members_revoke_invites
  after delete on public.household_members
  for each row execute function public.revoke_household_invites_on_removal();

-- Revokes every open code of a household the caller belongs to, e.g. after a
-- link went too far. The next household_invite_code() mints a fresh one.
create or replace function public.revoke_household_invites(p_household uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  if not public.is_household_member(p_household) then
    raise exception 'not a member' using errcode = '42501';
  end if;
  update public.household_invites set revoked = true
  where household_id = p_household and not revoked;
end;
$$;

-- Leaves a household. If the caller owned it, the longest-standing member
-- takes over; if nobody is left, it goes.
create or replace function public.leave_household(p_household uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  delete from public.household_members
  where household_id = p_household and user_id = auth.uid();
  if not found then raise exception 'not a member' using errcode = '42501'; end if;
end;
$$;

revoke all on function public.revoke_household_invites(uuid) from public, anon;
revoke all on function public.leave_household(uuid) from public, anon;
grant execute on function public.revoke_household_invites(uuid) to authenticated;
grant execute on function public.leave_household(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Friend codes
-- ---------------------------------------------------------------------------

-- Ends a friendship, or withdraws or turns down a request, from either side.
-- Ending an accepted friendship also revokes the caller's open invite codes,
-- so the code the other one once used cannot make them friends again.
create or replace function public.remove_friend(p_other uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  delete from public.friendships f
  where least(f.requester, f.addressee) = least(auth.uid(), p_other)
    and greatest(f.requester, f.addressee) = greatest(auth.uid(), p_other)
    and auth.uid() in (f.requester, f.addressee)
  returning f.status into v_status;
  if v_status = 'accepted' then
    update public.invite_codes set revoked = true
    where owner = auth.uid() and not revoked;
  end if;
end;
$$;
