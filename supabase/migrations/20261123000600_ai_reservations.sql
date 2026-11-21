-- The AI allowance was checked against what earlier requests had already
-- been billed, and a request was only billed once its answer was back. Ten
-- requests sent at once all saw the same, untouched allowance, so parallel
-- requests could overdraw it without bound.
--
-- Now a request reserves what it can cost at most — its input, estimated by
-- the gateway, plus its output cap — the moment it is let through, and the
-- real usage replaces the reservation afterwards. A request is let through
-- while anything is left, so the allowance is overdrawn by one request at
-- most, never by however many run in parallel.

drop function public.ai_begin_request(uuid, integer, integer);
drop function public.ai_record_usage(uuid, integer);

-- Checks the monthly allowance and the per-minute window; if both allow it,
-- counts the request and reserves [p_reserve] tokens. Returns {allowed,
-- reason?, used, limit, month, reserved}.
create or replace function public.ai_begin_request(
  p_user_id uuid,
  p_token_limit integer,
  p_rpm integer,
  p_reserve integer
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_month date := date_trunc('month', now() at time zone 'utc')::date;
  v_reserve integer := greatest(coalesce(p_reserve, 0), 0);
  v_row public.ai_usage;
begin
  insert into public.ai_usage (user_id, month) values (p_user_id, v_month)
  on conflict (user_id, month) do nothing;

  -- The row lock makes parallel requests of one user take turns here, so
  -- each sees the reservations of those before it.
  select * into v_row from public.ai_usage
  where user_id = p_user_id and month = v_month
  for update;

  update public.ai_usage set token_limit = p_token_limit
  where user_id = p_user_id and month = v_month;

  if v_row.tokens >= p_token_limit then
    return jsonb_build_object('allowed', false, 'reason', 'quota_exceeded',
                              'used', v_row.tokens, 'limit', p_token_limit);
  end if;
  if v_row.window_start >= now() - interval '1 minute' and v_row.window_requests >= p_rpm then
    return jsonb_build_object('allowed', false, 'reason', 'rate_limited',
                              'used', v_row.tokens, 'limit', p_token_limit);
  end if;

  update public.ai_usage
  set tokens = tokens + v_reserve,
      requests = requests + 1,
      window_start = case when window_start < now() - interval '1 minute' then now() else window_start end,
      window_requests = case when window_start < now() - interval '1 minute' then 1 else window_requests + 1 end,
      updated_at = now()
  where user_id = p_user_id and month = v_month;

  return jsonb_build_object('allowed', true, 'used', v_row.tokens, 'limit', p_token_limit,
                            'month', v_month, 'reserved', v_reserve);
end;
$$;

-- Replaces a reservation made in [p_month] with the tokens actually billed
-- (0 when the request failed). Returns the month's new total.
create or replace function public.ai_settle_usage(
  p_user_id uuid,
  p_month date,
  p_reserved integer,
  p_tokens integer
) returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total integer;
begin
  update public.ai_usage
  set tokens = greatest(tokens - greatest(coalesce(p_reserved, 0), 0) + greatest(coalesce(p_tokens, 0), 0), 0),
      updated_at = now()
  where user_id = p_user_id and month = p_month
  returning tokens into v_total;
  return v_total;
end;
$$;

revoke all on function public.ai_begin_request(uuid, integer, integer, integer) from public, anon, authenticated;
revoke all on function public.ai_settle_usage(uuid, date, integer, integer) from public, anon, authenticated;
grant execute on function public.ai_begin_request(uuid, integer, integer, integer) to service_role;
grant execute on function public.ai_settle_usage(uuid, date, integer, integer) to service_role;
