// Finding friends in the address book.
//
//   POST { action: 'register' }    be findable by one's verified e-mail and phone
//   POST { action: 'unregister' }  stop being findable
//   POST { action: 'match', emails: [...], phones: [...] }
//                                  who of these uses the app and is findable
//
// The uploaded contacts are hashed in memory and compared; they are never
// stored. Only identifiers the identity provider or an SMS code verified are
// registered, so nobody can claim someone else's number.
//
// Secret: CONTACT_PEPPER (required, any long random string; changing it
// makes everyone re-register).

import { adminClient, corsHeaders, errorResponse, HttpError, json, requireUser } from '../_shared/supabase.ts';
import { hmac, identifiersOf, type Kind, normalizeEmail, normalizePhone } from './contacts.ts';

const MAX_PER_REQUEST = 2000;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  try {
    const pepper = Deno.env.get('CONTACT_PEPPER');
    if (!pepper) throw new HttpError(500, 'server_misconfigured');
    const user = await requireUser(req);
    const body = await req.json().catch(() => ({}));
    const db = adminClient();

    if (body.action === 'register' || body.action === 'unregister') {
      await db.from('contact_identifiers').delete().eq('user_id', user.id);
      const findable = body.action === 'register';
      if (findable) {
        const rows: { kind: Kind; hmac: string; user_id: string }[] = [];
        const email = user.email && user.email_confirmed_at ? normalizeEmail(user.email) : null;
        const phone = user.phone && user.phone_confirmed_at
          ? normalizePhone(`+${user.phone.replace(/^\+/, '')}`)
          : null;
        if (email) rows.push({ kind: 'email', hmac: await hmac(pepper, 'email', email), user_id: user.id });
        if (phone) rows.push({ kind: 'phone', hmac: await hmac(pepper, 'phone', phone), user_id: user.id });
        if (rows.length > 0) {
          const { error } = await db.from('contact_identifiers').upsert(rows);
          if (error) throw error;
        }
      }
      const { error } = await db.from('user_settings').upsert({
        user_id: user.id,
        discoverable: findable,
        updated_at: new Date().toISOString(),
      });
      if (error) throw error;
      return json({ findable });
    }

    if (body.action !== 'match') throw new HttpError(400, 'unknown_action');
    const identifiers = identifiersOf(body, MAX_PER_REQUEST);
    if (identifiers.length === 0) return json({ matches: [] });

    const { data: allowed, error: limitError } = await db.rpc('contact_match_allowed', {
      p_user: user.id,
      p_count: identifiers.length,
    });
    if (limitError) throw limitError;
    if (!allowed) throw new HttpError(429, 'rate_limited');

    const hashes = await Promise.all(identifiers.map(({ kind, value }) => hmac(pepper, kind, value)));
    const { data: found, error } = await db
      .from('contact_identifiers')
      .select('user_id')
      .in('hmac', hashes);
    if (error) throw error;
    const ids = [...new Set((found ?? []).map((r) => r.user_id as string))].filter((id) => id !== user.id);
    if (ids.length === 0) return json({ matches: [] });

    const { data: settings } = await db.from('user_settings').select('user_id').in('user_id', ids).eq(
      'discoverable',
      true,
    );
    const findable = new Set((settings ?? []).map((s) => s.user_id as string));
    const { data: profiles } = await db
      .from('profiles')
      .select('id, display_name, emoji, username')
      .in('id', ids.filter((id) => findable.has(id)));

    return json({
      matches: (profiles ?? []).map((p) => ({
        userId: p.id,
        displayName: p.display_name,
        emoji: p.emoji,
        username: p.username,
      })),
    });
  } catch (err) {
    return errorResponse(err);
  }
});
