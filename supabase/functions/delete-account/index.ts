// Deletes the caller's account and everything in it.
//
// Every table keys its rows to auth.users with ON DELETE CASCADE, so deleting
// the auth user removes the feed, friendships, invite codes, households the
// user owned alone, subscriptions and AI usage in one statement. The app
// cannot do this itself: it needs the service role.
//
// Sign in with Apple: the App Store requires revoking the app's access to the
// user's Apple ID as well (guideline 5.1.1(v)). The app asks Apple for a
// fresh authorization code and sends it along; without the secrets below the
// revocation is skipped and logged, the deletion still happens.
//
// Secrets (optional):
//   APPLE_TEAM_ID      10-character Apple Developer Team ID
//   APPLE_KEY_ID       Key ID of a "Sign in with Apple" key
//   APPLE_PRIVATE_KEY  contents of that key's .p8 file (newlines may be \n)
//   APPLE_CLIENT_ID    the app's bundle id

import { importPKCS8, SignJWT } from 'npm:jose@5.9.6';
import { adminClient, corsHeaders, errorResponse, json, requireUser } from '../_shared/supabase.ts';

async function revokeAppleAccess(authorizationCode: string): Promise<void> {
  const teamId = Deno.env.get('APPLE_TEAM_ID');
  const keyId = Deno.env.get('APPLE_KEY_ID');
  const privateKey = Deno.env.get('APPLE_PRIVATE_KEY');
  const clientId = Deno.env.get('APPLE_CLIENT_ID');
  if (!teamId || !keyId || !privateKey || !clientId) {
    console.warn('delete-account: Apple secrets not configured, skipping revocation');
    return;
  }

  const key = await importPKCS8(privateKey.replace(/\\n/g, '\n'), 'ES256');
  const clientSecret = await new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: keyId })
    .setIssuer(teamId)
    .setSubject(clientId)
    .setAudience('https://appleid.apple.com')
    .setIssuedAt()
    .setExpirationTime('5m')
    .sign(key);

  const form = (params: Record<string, string>) => ({
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(params).toString(),
  });

  const tokenRes = await fetch('https://appleid.apple.com/auth/token', form({
    client_id: clientId,
    client_secret: clientSecret,
    code: authorizationCode,
    grant_type: 'authorization_code',
  }));
  if (!tokenRes.ok) throw new Error(`Apple token exchange failed (${tokenRes.status})`);
  const { refresh_token: refreshToken } = await tokenRes.json();
  if (!refreshToken) throw new Error('Apple returned no refresh token');

  const revokeRes = await fetch('https://appleid.apple.com/auth/revoke', form({
    client_id: clientId,
    client_secret: clientSecret,
    token: refreshToken,
    token_type_hint: 'refresh_token',
  }));
  if (!revokeRes.ok) throw new Error(`Apple revocation failed (${revokeRes.status})`);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  try {
    const user = await requireUser(req);

    let appleCode: string | undefined;
    try {
      const body = await req.json();
      if (typeof body?.appleAuthorizationCode === 'string') appleCode = body.appleAuthorizationCode;
    } catch {
      // No body: a Google account.
    }
    if (appleCode) {
      try {
        await revokeAppleAccess(appleCode);
      } catch (e) {
        // The user asked for the deletion; a failed revocation must not stop it.
        console.error('delete-account: Apple revocation failed', e);
      }
    }

    const { error } = await adminClient().auth.admin.deleteUser(user.id);
    if (error) throw error;
    return json({ deleted: true });
  } catch (err) {
    return errorResponse(err);
  }
});
