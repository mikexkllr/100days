// Guard for everything that spends the AI provider's key.
//
// The publishable key ships inside every app, so a request has to belong to
// a real signed-in user and is counted against that user's monthly
// allowance and per-minute window. The allowance depends on the tier, which
// only `verify-purchase` can change.

import { adminClient, HttpError, requireUser } from './supabase.ts';

/**
 * coach: the coach's daily line and nudge texts — premium only, so a free
 *        allowance is spent on what users ask for, not on decoration.
 * food:  meal estimates from text or a photo, meal ideas, targets.
 * plan:  generating a meal plan or a shopping list.
 * chat:  the planning chat.
 */
export type Purpose = 'coach' | 'food' | 'plan' | 'chat';
export type Tier = 'free' | 'premium';

export interface GuardedUser {
  userId: string;
  tier: Tier;
}

const env = (name: string, fallback: number) => {
  const parsed = Number.parseInt(Deno.env.get(name) ?? '', 10);
  return Number.isFinite(parsed) ? parsed : fallback;
};

/**
 * Monthly token allowances. Free is small on purpose; premium is "unlimited"
 * in the app, and this is the fair-use ceiling behind that word.
 */
export const limits = {
  free: env('FREE_AI_TOKENS_PER_MONTH', 50_000),
  premium: env('PREMIUM_AI_TOKENS_PER_MONTH', 3_000_000),
  requestsPerMinute: env('AI_REQUESTS_PER_MINUTE', 20),
};

export function purposeOf(header: string | null): Purpose {
  return header === 'coach' || header === 'plan' || header === 'chat' ? header : 'food';
}

/** Resolves the caller to a signed-in user and their tier. */
export async function authenticate(req: Request): Promise<GuardedUser> {
  const user = await requireUser(req);
  const { data, error } = await adminClient().rpc('tier_of', { p_user: user.id });
  if (error) throw new HttpError(500, 'tier_lookup_failed', error.message);
  return { userId: user.id, tier: data === 'premium' ? 'premium' : 'free' };
}

export const limitFor = (user: GuardedUser) => (user.tier === 'premium' ? limits.premium : limits.free);

/**
 * Tokens held against the allowance while a request runs, in the month they
 * were taken from.
 */
export interface Reservation {
  month: string;
  tokens: number;
}

/**
 * Checks tier, allowance and rate window, counts the request and reserves
 * [reserve] tokens — the most it can cost — until [recordUsage] settles it.
 */
export async function beginRequest(user: GuardedUser, purpose: Purpose, reserve = 0): Promise<Reservation> {
  if (purpose === 'coach' && user.tier !== 'premium') {
    throw new HttpError(402, 'premium_only');
  }
  const { data, error } = await adminClient().rpc('ai_begin_request', {
    p_user_id: user.userId,
    p_token_limit: limitFor(user),
    p_rpm: limits.requestsPerMinute,
    p_reserve: Math.max(0, Math.ceil(reserve)),
  });
  if (error) throw new HttpError(500, 'quota_check_failed', error.message);
  if (!data?.allowed) {
    // 402, not 429: client libraries retry 429 by themselves, which would
    // only hammer an exhausted allowance.
    throw new HttpError(402, data?.reason === 'rate_limited' ? 'rate_limited' : 'quota_exceeded');
  }
  return { month: String(data.month), tokens: Number(data.reserved) || 0 };
}

/**
 * Replaces [reservation] with the tokens actually billed — 0 when the
 * request failed. Never throws.
 */
export async function recordUsage(user: GuardedUser, tokens: number, reservation: Reservation): Promise<void> {
  const billed = Number.isFinite(tokens) && tokens > 0 ? Math.ceil(tokens) : 0;
  if (billed === 0 && reservation.tokens === 0) return;
  const { error } = await adminClient().rpc('ai_settle_usage', {
    p_user_id: user.userId,
    p_month: reservation.month,
    p_reserved: reservation.tokens,
    p_tokens: billed,
  });
  if (error) console.error('ai_settle_usage failed', error.message);
}

/** Keeps the isolate alive for work that finishes after the response. */
export function runInBackground(promise: Promise<unknown>): void {
  // deno-lint-ignore no-explicit-any
  const runtime = (globalThis as any).EdgeRuntime;
  if (runtime?.waitUntil) runtime.waitUntil(promise);
}
