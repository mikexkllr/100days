-- A limit on contact matching: without one, a script could test phone
-- numbers by the thousand to find out who uses the app.

create table public.contact_match_log (
  user_id uuid not null references auth.users (id) on delete cascade,
  at timestamptz not null default now(),
  identifiers integer not null
);
create index contact_match_log_user_idx on public.contact_match_log (user_id, at);
alter table public.contact_match_log enable row level security;
revoke all on public.contact_match_log from anon, authenticated;

-- True (and counted) when [p_user] may match [p_count] more identifiers:
-- at most 10 matches and 5000 identifiers a day.
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

revoke all on function public.contact_match_allowed(uuid, integer) from public, anon, authenticated;
grant execute on function public.contact_match_allowed(uuid, integer) to service_role;
