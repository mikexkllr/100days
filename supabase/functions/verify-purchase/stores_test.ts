// deno test supabase/functions/verify-purchase/
import { assertEquals } from 'jsr:@std/assert@1';
import { appStoreEntitlement, decodeJwsPayload, playEntitlement } from './stores.ts';

const products = new Set(['hundred_days_premium']);
const future = Date.now() + 30 * 864e5;

Deno.test('an App Store subscription for this app and product counts until it expires', () => {
  const e = appStoreEntitlement(
    {
      bundleId: 'com.hundreddays.hundredDays',
      productId: 'hundred_days_premium',
      originalTransactionId: 2000000123,
      expiresDate: future,
    },
    'com.hundreddays.hundredDays',
    products,
  );
  assertEquals(e?.originalTransactionId, '2000000123');
  assertEquals(e?.expiresAt.getTime(), future);
});

Deno.test('another app, another product or a refund grants nothing', () => {
  const base = { productId: 'hundred_days_premium', originalTransactionId: 1, expiresDate: future };
  assertEquals(appStoreEntitlement({ ...base, bundleId: 'com.other' }, 'com.hundreddays.hundredDays', products), null);
  assertEquals(
    appStoreEntitlement(
      { ...base, bundleId: 'com.hundreddays.hundredDays', productId: 'coins' },
      'com.hundreddays.hundredDays',
      products,
    ),
    null,
  );
  assertEquals(
    appStoreEntitlement(
      { ...base, bundleId: 'com.hundreddays.hundredDays', revocationDate: Date.now() },
      'com.hundreddays.hundredDays',
      products,
    ),
    null,
  );
});

Deno.test('a Play subscription counts while active or in grace, by its latest line item', () => {
  const sub = (state: string) => ({
    subscriptionState: state,
    lineItems: [
      { productId: 'hundred_days_premium', expiryTime: new Date(future - 864e5).toISOString() },
      { productId: 'hundred_days_premium', expiryTime: new Date(future).toISOString() },
    ],
  });
  assertEquals(playEntitlement(sub('SUBSCRIPTION_STATE_ACTIVE'), 'tok', products)?.expiresAt.getTime(), future);
  assertEquals(
    playEntitlement(sub('SUBSCRIPTION_STATE_IN_GRACE_PERIOD'), 'tok', products)?.originalTransactionId,
    'tok',
  );
  assertEquals(playEntitlement(sub('SUBSCRIPTION_STATE_EXPIRED'), 'tok', products), null);
  assertEquals(playEntitlement(sub('SUBSCRIPTION_STATE_CANCELED'), 'tok', products), null);
});

Deno.test('a resubscription keeps the identity of the token it replaced', () => {
  const e = playEntitlement(
    {
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      linkedPurchaseToken: 'first',
      lineItems: [{ productId: 'hundred_days_premium', expiryTime: new Date(future).toISOString() }],
    },
    'second',
    products,
  );
  assertEquals(e?.originalTransactionId, 'first');
});

Deno.test('reads the payload of a JWS', () => {
  const payload = btoa(JSON.stringify({ productId: 'x' })).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
  assertEquals(decodeJwsPayload(`h.${payload}.s`), { productId: 'x' });
});
