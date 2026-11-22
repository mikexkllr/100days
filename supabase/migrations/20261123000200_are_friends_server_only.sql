-- are_friends(a, b) answers for any two people, so a signed-in user could
-- call it to test who is friends with whom. No policy and no function with
-- the caller's rights uses it — the events policy goes through friend_ids(),
-- which only ever looks at the caller — and its one caller is the `push`
-- function, as the service role. So that is the only one left who may.

revoke execute on function public.are_friends(uuid, uuid) from public, anon, authenticated;
grant execute on function public.are_friends(uuid, uuid) to service_role;

comment on function public.are_friends(uuid, uuid) is
  'True when a and b are accepted friends. Service role only (the push function).';
