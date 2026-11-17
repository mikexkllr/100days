// Asking the stores whether a purchase is real, and until when it runs.
// Pure parsing is separated from I/O so it can be tested without the stores.

import { importPKCS8, SignJWT } from 'npm:jose@5.9.6';

export interface Entitlement {
  productId: string;
  originalTransactionId: string;
  expiresAt: Date;
}

// deno-lint-ignore no-explicit-any
type Json = any;

/** The payload of a JWS from Apple. Fetched from Apple over TLS, so not re-verified here. */
export function decodeJwsPayload(jws: string): Json {
  const [, payload] = jws.split('.');
  if (!payload) throw new Error('not a JWS');
  const base64 = payload.replace(/-/g, '+').replace(/_/g, '/');
  return JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(base64), (c) => c.charCodeAt(0))));
}

/** A transaction from the App Store Server API, or null if it grants nothing. */
export function appStoreEntitlement(transaction: Json, bundleId: string, productIds: Set<string>): Entitlement | null {
  if (transaction?.bundleId !== bundleId) return null;
  if (!productIds.has(transaction?.productId)) return null;
  if (transaction?.revocationDate) return null;
  const expires = Number(transaction?.expiresDate);
  if (!Number.isFinite(expires)) return null;
  return {
    productId: transaction.productId,
    originalTransactionId: String(transaction.originalTransactionId),
    expiresAt: new Date(expires),
  };
}

const PLAY_ACTIVE = new Set(['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD']);

/** A Play `subscriptionsv2` resource, or null if it grants nothing. */
export function playEntitlement(
  subscription: Json,
  purchaseToken: string,
  productIds: Set<string>,
): Entitlement | null {
  if (!PLAY_ACTIVE.has(subscription?.subscriptionState)) return null;
  const items: Json[] = Array.isArray(subscription?.lineItems) ? subscription.lineItems : [];
  let best: Entitlement | null = null;
  for (const item of items) {
    if (!productIds.has(item?.productId)) continue;
    const expiresAt = new Date(item?.expiryTime);
    if (Number.isNaN(expiresAt.getTime())) continue;
    if (!best || expiresAt > best.expiresAt) {
      // A resubscription links to the token it replaced; the first token in
      // the chain identifies the subscription across renewals.
      best = {
        productId: item.productId,
        originalTransactionId: subscription.linkedPurchaseToken ?? purchaseToken,
        expiresAt,
      };
    }
  }
  return best;
}

// --- I/O -------------------------------------------------------------------

export interface StoreDeps {
  fetch: typeof fetch;
  env: (name: string) => string | undefined;
}

/** App Store Server API: looks a transaction up by id (production, then sandbox). */
export async function fetchAppStoreTransaction(deps: StoreDeps, transactionId: string): Promise<Json | null> {
  const issuer = deps.env('APPSTORE_ISSUER_ID');
  const keyId = deps.env('APPSTORE_KEY_ID');
  const privateKey = deps.env('APPSTORE_PRIVATE_KEY');
  const bundleId = deps.env('APP_BUNDLE_ID');
  if (!issuer || !keyId || !privateKey || !bundleId) throw new Error('App Store secrets not configured');

  const key = await importPKCS8(privateKey.replace(/\\n/g, '\n'), 'ES256');
  const token = await new SignJWT({ bid: bundleId })
    .setProtectedHeader({ alg: 'ES256', kid: keyId, typ: 'JWT' })
    .setIssuer(issuer)
    .setAudience('appstoreconnect-v1')
    .setIssuedAt()
    .setExpirationTime('5m')
    .sign(key);

  for (const host of ['api.storekit.itunes.apple.com', 'api.storekit-sandbox.itunes.apple.com']) {
    const res = await deps.fetch(`https://${host}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status === 404) continue;
    if (!res.ok) throw new Error(`App Store ${res.status}`);
    const { signedTransactionInfo } = await res.json();
    return decodeJwsPayload(signedTransactionInfo);
  }
  return null;
}

/** Play Developer API: the subscription behind a purchase token. */
export async function fetchPlaySubscription(deps: StoreDeps, purchaseToken: string): Promise<Json | null> {
  const serviceAccountJson = deps.env('GOOGLE_SERVICE_ACCOUNT_JSON');
  const packageName = deps.env('ANDROID_PACKAGE_NAME');
  if (!serviceAccountJson || !packageName) throw new Error('Google Play secrets not configured');
  const account = JSON.parse(serviceAccountJson) as { client_email: string; private_key: string };

  const key = await importPKCS8(account.private_key, 'RS256');
  const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/androidpublisher' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(account.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key);
  const tokenRes = await deps.fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  const { access_token: accessToken } = await tokenRes.json();
  if (!accessToken) throw new Error('Google token exchange failed');

  const res = await deps.fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}` +
      `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );
  if (res.status === 404 || res.status === 410) return null;
  if (!res.ok) throw new Error(`Google Play ${res.status}`);
  return await res.json();
}
