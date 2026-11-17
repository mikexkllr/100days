-- A household nobody belongs to is nobody's: when its last member leaves —
-- or deletes their account, which removes their membership by cascade — it
-- goes, and with it its plan, recipes, lists and invites. Without this, a
-- deleted account would leave its meal plan and shopping lists behind,
-- unreachable but stored.
create or replace function public.drop_empty_household()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.households h
  where h.id = old.household_id
    and not exists (
      select 1 from public.household_members m where m.household_id = old.household_id
    );
  return null;
end;
$$;

revoke all on function public.drop_empty_household() from public, anon, authenticated;

create trigger household_members_drop_empty
  after delete on public.household_members
  for each row execute function public.drop_empty_household();
