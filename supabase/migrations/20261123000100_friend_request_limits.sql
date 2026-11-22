-- Limits on friend requests. Every request is a push to someone with the
-- sender's chosen name in it, so without a limit a script could message
-- every user of the app. Two rules:
--
--   1. At most 30 new requests a day per sender.
--   2. After a "no", the same person cannot ask again for 30 days — unless
--      the one who said no asks them.
--
-- Both answer with an error the app explains (PostgREST turns the PTxxx
-- codes into that HTTP status).

create table public.friend_request_log (
  requester uuid not null references auth.users (id) on delete cascade,
  addressee uuid not null references auth.users (id) on delete cascade,
  at timestamptz not null default now()
);
create index friend_request_log_requester_idx on public.friend_request_log (requester, at);
alter table public.friend_request_log enable row level security;
revoke all on public.friend_request_log from anon, authenticated;

-- Who was turned down by whom, and when. Not readable by either side: a
-- decline stays as quiet as it was.
create table public.friend_request_declines (
  requester uuid not null references auth.users (id) on delete cascade,
  addressee uuid not null references auth.users (id) on delete cascade,
  declined_at timestamptz not null default now(),
  primary key (requester, addressee)
);
alter table public.friend_request_declines enable row level security;
revoke all on public.friend_request_declines from anon, authenticated;

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

  if exists (
    select 1 from public.friend_request_declines d
    where d.requester = v_me and d.addressee = p_target
      and d.declined_at > now() - interval '30 days'
  ) then
    raise exception 'declined recently' using errcode = 'PT409';
  end if;

  -- One sender at a time, so parallel calls cannot slip past the count.
  perform pg_advisory_xact_lock(hashtextextended('friend_request:' || v_me::text, 0));
  if (select count(*) from public.friend_request_log l
      where l.requester = v_me and l.at > now() - interval '1 day') >= 30 then
    raise exception 'too many requests' using errcode = 'PT429';
  end if;

  insert into public.friendships (requester, addressee) values (v_me, p_target);
  insert into public.friend_request_log (requester, addressee) values (v_me, p_target);
  delete from public.friend_request_log where requester = v_me and at < now() - interval '2 days';
  -- Asking someone who once turned the caller down is the "unless": their
  -- own earlier no no longer stands in the way of the caller asking back.
  delete from public.friend_request_declines where requester = p_target and addressee = v_me;
  return 'pending';
end;
$$;

-- Accepts or declines a request someone sent the caller. A decline is
-- remembered, for rule 2.
create or replace function public.respond_friend_request(p_requester uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  if p_accept then
    update public.friendships set status = 'accepted', responded_at = now()
    where requester = p_requester and addressee = auth.uid() and status = 'pending';
  else
    delete from public.friendships
    where requester = p_requester and addressee = auth.uid() and status = 'pending';
    if found then
      insert into public.friend_request_declines (requester, addressee)
      values (p_requester, auth.uid())
      on conflict (requester, addressee) do update set declined_at = now();
    end if;
  end if;
end;
$$;
