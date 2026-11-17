// Normalising and hashing contact identifiers. Pure, so it can be tested.

export type Kind = 'email' | 'phone';

export function normalizeEmail(raw: string): string | null {
  const email = raw.trim().toLowerCase();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) && email.length <= 254 ? email : null;
}

/** E.164 only: the app normalises with the phone's region before sending. */
export function normalizePhone(raw: string): string | null {
  const phone = raw.replace(/[\s()\-./]/g, '');
  return /^\+[1-9]\d{6,14}$/.test(phone) ? phone : null;
}

/**
 * HMAC-SHA256 under the server's pepper. Without the pepper, the stored
 * values cannot be tested against a list of phone numbers — the space of
 * numbers is small enough that a plain hash could.
 */
export async function hmac(pepper: string, kind: Kind, value: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(pepper),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${kind}:${value}`));
  return Array.from(new Uint8Array(signature)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** The unique, valid identifiers in a request, at most [limit]. */
export function identifiersOf(
  body: { emails?: unknown; phones?: unknown },
  limit: number,
): { kind: Kind; value: string }[] {
  const out = new Map<string, { kind: Kind; value: string }>();
  const add = (kind: Kind, value: string | null) => {
    if (value && out.size < limit) out.set(`${kind}:${value}`, { kind, value });
  };
  for (const e of Array.isArray(body.emails) ? body.emails : []) {
    if (typeof e === 'string') add('email', normalizeEmail(e));
  }
  for (const p of Array.isArray(body.phones) ? body.phones : []) {
    if (typeof p === 'string') add('phone', normalizePhone(p));
  }
  return [...out.values()];
}
