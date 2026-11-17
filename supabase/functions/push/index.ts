// Push notifications between friends.
//
//   POST { eventId }                   after the app sent a nudge, a cheer or a
//                                      check-in: tells the friends it concerns
//   POST { friendRequestTo: userId }   after a friend request
//
// The function only pushes what really happened: the event must exist, be
// the caller's own and be fresh; a nudge must go to a friend; a request must
// be pending. Each recipient gets at most one push of a kind per sender and
// day, and one "a friend was active" a day — and none they switched off.
//
// Secret: FCM_SERVICE_ACCOUNT_JSON (a Firebase service account with the
// Cloud Messaging API). Without it the function does nothing and says so.

import { importPKCS8, SignJWT } from 'npm:jose@5.9.6';
import { adminClient, corsHeaders, errorResponse, HttpError, json, requireUser } from '../_shared/supabase.ts';
import { fcmBody, type Kind, type Language, messageFor } from './messages.ts';

interface Recipient {
  userId: string;
  kind: Kind;
  text?: string;
  // The once-a-day key: the sender, or the recipient for friend activity.
  logSender: string;
}

let accessToken: { value: string; expires: number } | null = null;

async function fcmAccessToken(account: { client_email: string; private_key: string }): Promise<string> {
  if (accessToken && accessToken.expires > Date.now() + 60_000) return accessToken.value;
  const key = await importPKCS8(account.private_key, 'RS256');
  const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(account.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key);
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  const { access_token: value, expires_in: expiresIn } = await res.json();
  if (!value) throw new Error('FCM token exchange failed');
  accessToken = { value, expires: Date.now() + (Number(expiresIn) || 3600) * 1000 };
  return value;
}

async function recipientsFor(userId: string, body: Record<string, unknown>): Promise<Recipient[]> {
  const db = adminClient();
  if (typeof body.friendRequestTo === 'string') {
    const { data } = await db.from('friendships').select('status')
      .eq('requester', userId).eq('addressee', body.friendRequestTo).maybeSingle();
    if (data?.status !== 'pending') return [];
    return [{ userId: body.friendRequestTo, kind: 'friend_request', logSender: userId }];
  }

  if (typeof body.eventId !== 'string') throw new HttpError(400, 'invalid_request');
  const { data: event } = await db.from('events').select('author, type, payload, created_at, visibility')
    .eq('id', body.eventId).maybeSingle();
  if (!event || event.author !== userId || event.visibility !== 'friends') return [];
  if (Date.now() - new Date(event.created_at).getTime() > 15 * 60_000) return [];

  if (event.type === 'nudge' || event.type === 'cheer') {
    const target = event.payload?.target;
    if (typeof target !== 'string') return [];
    const { data: friends } = await db.rpc('are_friends', { a: userId, b: target });
    if (!friends) return [];
    return [{ userId: target, kind: event.type, text: event.payload?.text, logSender: userId }];
  }

  if (event.type === 'checkin' && !event.payload?.relapse) {
    const day = event.payload?.day;
    const { data: links } = await db.from('friendships').select('requester, addressee')
      .eq('status', 'accepted').or(`requester.eq.${userId},addressee.eq.${userId}`);
    const friendIds = (links ?? []).map((l) => (l.requester === userId ? l.addressee : l.requester) as string);
    if (friendIds.length === 0 || typeof day !== 'string') return [];
    // Friends who already showed up that day need no reminder.
    const { data: active } = await db.from('events').select('author')
      .in('author', friendIds).eq('type', 'checkin').eq('payload->>day', day);
    const done = new Set((active ?? []).map((a) => a.author as string));
    return friendIds.filter((id) => !done.has(id))
      .map((id) => ({ userId: id, kind: 'friend_activity' as Kind, logSender: id }));
  }
  return [];
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  try {
    const user = await requireUser(req);
    const serviceAccount = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
    if (!serviceAccount) return json({ sent: 0, reason: 'push_not_configured' });
    const account = JSON.parse(serviceAccount) as { client_email: string; private_key: string; project_id: string };

    const body = await req.json().catch(() => ({}));
    const recipients = await recipientsFor(user.id, body);
    if (recipients.length === 0) return json({ sent: 0 });

    const db = adminClient();
    const { data: me } = await db.from('profiles').select('display_name').eq('id', user.id).single();
    const token = await fcmAccessToken(account);
    let sent = 0;

    for (const r of recipients) {
      const { data: settings } = await db.rpc('settings_of', { p_user: r.userId });
      if (settings?.notify?.[r.kind] === false) continue;
      // Once per kind, sender and day.
      const { error: logged } = await db.from('push_log').insert({
        recipient: r.userId,
        kind: r.kind,
        sender: r.logSender,
      });
      if (logged) continue;

      const message = messageFor(r.kind, (settings?.language ?? 'de') as Language, me?.display_name ?? '', r.text);
      const { data: tokens } = await db.from('push_tokens').select('token').eq('user_id', r.userId);
      for (const { token: device } of tokens ?? []) {
        const res = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify(fcmBody(device, message, r.kind)),
        });
        if (res.ok) {
          sent++;
        } else if (res.status === 404 || res.status === 400) {
          // An uninstalled app or a stale token: forget it.
          await db.from('push_tokens').delete().eq('token', device);
        }
      }
    }
    return json({ sent });
  } catch (err) {
    return errorResponse(err);
  }
});
