-- AI allowance and subscriptions.
--
-- The AI features run through the `llm-gateway` edge function, which holds
-- the provider's API key. Every request is counted against the user's
-- monthly token allowance here; the size of that allowance depends on
-- whether the user has an active subscription.
--
-- Both tables are written only by edge functions (service role). A client
-- that could write `subscriptions` could make itself premium, and one that
-- could write `ai_usage` could reset its own allowance.

-- ---------------------------------------------------------------------------
-- Subscriptions: set by `verify-purchase` after the store confirmed a
-- purchase, never by the app.
-- ---------------------------------------------------------------------------

create table public.subscriptions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  product_id text not null,
  platform text not null check (platform in ('app_store', 'google_play', 'manual')),
  -- The store's id for the subscription, so a renewal or a restore on a new
  -- phone updates the same row instead of granting a second one.
  original_transaction_id text,
  expires_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create unique index subscriptions_original_transaction_idx
  on public.subscriptions (platform, original_transaction_id)
  where original_transaction_id is not null;

alter table public.subscriptions enable row level security;

create policy "Users see their own subscription" on public.subscriptions
  for select to authenticated using (user_id = (select auth.uid()));

revoke all on public.subscriptions from anon, authenticated;
grant select on public.subscriptions to authenticated;

-- 'premium' while a subscription runs, 'free' otherwise.
create or replace function public.tier_of(p_user uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case when exists (
    select 1 from public.subscriptions s
    where s.user_id = p_user and s.expires_at > now()
  ) then 'premium' else 'free' end;
$$;

-- ---------------------------------------------------------------------------
-- AI usage per user and month.
-- ---------------------------------------------------------------------------

create table public.ai_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  month date not null,
  tokens integer not null default 0,
  -- The allowance the gateway last enforced, so the app shows exactly what
  -- the server enforces.
  token_limit integer,
  requests integer not null default 0,
  window_start timestamptz not null default now(),
  window_requests integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, month)
);

alter table public.ai_usage enable row level security;

create policy "Users see their own AI usage" on public.ai_usage
  for select to authenticated using (user_id = (select auth.uid()));

revoke all on public.ai_usage from anon, authenticated;
grant select on public.ai_usage to authenticated;

-- Checks the monthly allowance and the per-minute window, and counts the
-- request. Returns {allowed, reason?, used, limit}.
create or replace function public.ai_begin_request(
  p_user_id uuid,
  p_token_limit integer,
  p_rpm integer
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_month date := date_trunc('month', now() at time zone 'utc')::date;
  v_row public.ai_usage;
begin
  insert into public.ai_usage (user_id, month) values (p_user_id, v_month)
  on conflict (user_id, month) do nothing;

  select * into v_row from public.ai_usage
  where user_id = p_user_id and month = v_month
  for update;

  update public.ai_usage set token_limit = p_token_limit
  where user_id = p_user_id and month = v_month;

  if v_row.tokens >= p_token_limit then
    return jsonb_build_object('allowed', false, 'reason', 'quota_exceeded',
                              'used', v_row.tokens, 'limit', p_token_limit);
  end if;

  if v_row.window_start < now() - interval '1 minute' then
    update public.ai_usage
    set window_start = now(), window_requests = 1, requests = requests + 1, updated_at = now()
    where user_id = p_user_id and month = v_month;
  elsif v_row.window_requests >= p_rpm then
    return jsonb_build_object('allowed', false, 'reason', 'rate_limited',
                              'used', v_row.tokens, 'limit', p_token_limit);
  else
    update public.ai_usage
    set window_requests = window_requests + 1, requests = requests + 1, updated_at = now()
    where user_id = p_user_id and month = v_month;
  end if;

  return jsonb_build_object('allowed', true, 'used', v_row.tokens, 'limit', p_token_limit);
end;
$$;

-- Adds billed tokens to this month. Returns the new total.
create or replace function public.ai_record_usage(p_user_id uuid, p_tokens integer)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_month date := date_trunc('month', now() at time zone 'utc')::date;
  v_total integer;
begin
  insert into public.ai_usage (user_id, month, tokens)
  values (p_user_id, v_month, greatest(p_tokens, 0))
  on conflict (user_id, month) do update
    set tokens = public.ai_usage.tokens + excluded.tokens, updated_at = now()
  returning tokens into v_total;
  return v_total;
end;
$$;

revoke all on function public.tier_of(uuid) from public, anon, authenticated;
revoke all on function public.ai_begin_request(uuid, integer, integer) from public, anon, authenticated;
revoke all on function public.ai_record_usage(uuid, integer) from public, anon, authenticated;
grant execute on function public.tier_of(uuid) to service_role;
grant execute on function public.ai_begin_request(uuid, integer, integer) to service_role;
grant execute on function public.ai_record_usage(uuid, integer) to service_role;

-- What the app shows: the tier, this month's usage and the allowance.
create or replace function public.my_ai_allowance()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'tier', public.tier_of(auth.uid()),
    'used', coalesce(u.tokens, 0),
    'limit', u.token_limit,
    'expires_at', (select s.expires_at from public.subscriptions s where s.user_id = auth.uid())
  )
  from (select 1) dummy
  left join public.ai_usage u
    on u.user_id = auth.uid()
   and u.month = date_trunc('month', now() at time zone 'utc')::date;
$$;

revoke all on function public.my_ai_allowance() from public, anon;
grant execute on function public.my_ai_allowance() to authenticated;
