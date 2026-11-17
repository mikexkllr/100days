// Verifies a store purchase and grants premium — the only way a
// subscription row is ever written.
//
//   POST { platform: 'app_store' | 'google_play', productId, token }
//   token: the App Store transaction id, or the Google Play purchase token.
//
// The app never decides it is premium: it hands the store's proof to this
// function, which asks the store and writes `subscriptions` with the service
// role. A restore on a new phone works the same way.
//
// Secrets:
//   PREMIUM_PRODUCT_IDS          comma-separated, default hundred_days_premium
//   App Store:   APPSTORE_ISSUER_ID, APPSTORE_KEY_ID, APPSTORE_PRIVATE_KEY, APP_BUNDLE_ID
//   Google Play: GOOGLE_SERVICE_ACCOUNT_JSON, ANDROID_PACKAGE_NAME

import { adminClient, corsHeaders, errorResponse, HttpError, json, requireUser } from '../_shared/supabase.ts';
import {
  appStoreEntitlement,
  type Entitlement,
  fetchAppStoreTransaction,
  fetchPlaySubscription,
  playEntitlement,
  type StoreDeps,
} from './stores.ts';

const deps: StoreDeps = { fetch, env: (name) => Deno.env.get(name) };

const productIds = () =>
  new Set((Deno.env.get('PREMIUM_PRODUCT_IDS') ?? 'hundred_days_premium').split(',').map((s) => s.trim()));

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  try {
    const user = await requireUser(req);
    const body = await req.json().catch(() => null);
    const platform = body?.platform;
    const token = body?.token;
    if (typeof token !== 'string' || token.length === 0 || token.length > 4096) {
      throw new HttpError(400, 'invalid_request');
    }

    let entitlement: Entitlement | null;
    if (platform === 'app_store') {
      entitlement = appStoreEntitlement(
        await fetchAppStoreTransaction(deps, token),
        Deno.env.get('APP_BUNDLE_ID') ?? '',
        productIds(),
      );
    } else if (platform === 'google_play') {
      entitlement = playEntitlement(await fetchPlaySubscription(deps, token), token, productIds());
    } else {
      throw new HttpError(400, 'unknown_platform');
    }

    if (!entitlement || entitlement.expiresAt <= new Date()) {
      return json({ premium: false });
    }

    // One store subscription belongs to one account: a token already bound
    // to someone else is not handed over by replaying it.
    const { data: owner } = await adminClient()
      .from('subscriptions')
      .select('user_id')
      .eq('platform', platform)
      .eq('original_transaction_id', entitlement.originalTransactionId)
      .maybeSingle();
    if (owner && owner.user_id !== user.id) throw new HttpError(409, 'owned_by_another_account');

    const { error } = await adminClient().from('subscriptions').upsert({
      user_id: user.id,
      product_id: entitlement.productId,
      platform,
      original_transaction_id: entitlement.originalTransactionId,
      expires_at: entitlement.expiresAt.toISOString(),
      updated_at: new Date().toISOString(),
    });
    if (error) throw error;

    return json({ premium: true, expiresAt: entitlement.expiresAt.toISOString() });
  } catch (err) {
    return errorResponse(err);
  }
});
