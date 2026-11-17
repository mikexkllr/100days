// Row Level Security, checked against a real database.
//
// Everything runs inside one transaction that is rolled back at the end, so
// the test users and their rows never persist. Run against a development
// project, never production:
//
//   DATABASE_URL=postgresql://… deno test -A supabase/tests/rls_test.ts
//
// Users are impersonated the way PostgREST does it: `role authenticated`
// plus the JWT claims in `request.jwt.claims`.

import postgres from 'npm:postgres@3.4.5';
import { assert, assertEquals, assertRejects } from 'jsr:@std/assert@1';

const url = Deno.env.get('DATABASE_URL');

// deno-lint-ignore no-explicit-any
type Tx = any;

class Rollback extends Error {}

async function as(tx: Tx, userId: string | null): Promise<void> {
  await tx`reset role`;
  if (userId === null) return;
  await tx`select set_config('request.jwt.claims', ${JSON.stringify({ sub: userId, role: 'authenticated' })}, true)`;
  await tx`set local role authenticated`;
}

async function createUser(tx: Tx, name: string): Promise<string> {
  await as(tx, null);
  const [row] = await tx`
    insert into auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (gen_random_uuid(), 'authenticated', 'authenticated',
            ${name + '-' + crypto.randomUUID() + '@test.invalid'},
            ${tx.json({ given_name: name })}, now(), now())
    returning id`;
  return row.id as string;
}

/** Runs [fn] in a savepoint and expects the database to refuse it. */
async function refused(tx: Tx, fn: (sp: Tx) => Promise<unknown>): Promise<void> {
  await assertRejects(() => tx.savepoint(fn));
}

async function event(tx: Tx, author: string, visibility: string, extra: Record<string, unknown> = {}) {
  const id = crypto.randomUUID();
  await tx`insert into public.events ${
    tx({
      id,
      author,
      type: 'checkin',
      payload: tx.json({ habitId: 'gym' }),
      visibility,
      client_ts: new Date().toISOString(),
      ...extra,
    })
  }`;
  return id;
}

Deno.test({
  name: 'row level security',
  ignore: !url,
  async fn() {
    const sql = postgres(url!, { prepare: false, max: 1 });
    try {
      await sql.begin(async (tx: Tx) => {
        const alice = await createUser(tx, 'Alice');
        const bob = await createUser(tx, 'Bob');

        // A profile per account, named after the identity provider's name.
        await as(tx, bob);
        const profiles = await tx`select display_name from public.profiles where id = ${alice}`;
        assertEquals(profiles[0].display_name, 'Alice');

        // Alice writes her own feed, and only her own.
        await as(tx, alice);
        const shared = await event(tx, alice, 'friends');
        await event(tx, alice, 'private');
        await refused(tx, (sp) => event(sp, bob, 'friends'));
        // Not more than a few minutes into the future.
        await refused(
          tx,
          (sp) => event(sp, alice, 'friends', { client_ts: new Date(Date.now() + 3600e3).toISOString() }),
        );
        // The server's receipt time is the server's, whatever the client sends.
        const stamped = await event(tx, alice, 'friends', { created_at: '2020-01-01T00:00:00Z' });
        const [{ created_at }] = await tx`select created_at from public.events where id = ${stamped}`;
        assert(new Date(created_at).getFullYear() > 2020, 'created_at was taken from the client');

        // Append-only: no edits, no deletions, not even of one's own events.
        await refused(tx, (sp) => sp`update public.events set payload = '{}' where id = ${shared}`);
        await refused(tx, (sp) => sp`delete from public.events where id = ${shared}`);

        // A stranger sees nothing of Alice's feed.
        await as(tx, bob);
        assertEquals((await tx`select id from public.events where author = ${alice}`).length, 0);
        // ...and cannot make himself her friend behind her back.
        await refused(
          tx,
          (sp) =>
            sp`insert into public.friendships (requester, addressee, status) values (${bob}, ${alice}, 'accepted')`,
        );

        // Alice shares her invite code; Bob redeems it.
        await as(tx, alice);
        const [{ my_invite_code: code }] = await tx`select public.my_invite_code()`;
        await as(tx, bob);
        const [preview] = await tx`select * from public.invite_preview(${code.toLowerCase()})`;
        assertEquals(preview.display_name, 'Alice');
        await tx`select public.redeem_invite(${code})`;

        // Friends see the shared events — and never the private ones.
        const visible = await tx`select id, visibility from public.events where author = ${alice}`;
        assertEquals(visible.length, 2);
        assert(visible.every((r: { visibility: string }) => r.visibility === 'friends'));

        // Ending the friendship ends the access.
        await tx`select public.remove_friend(${alice})`;
        assertEquals((await tx`select id from public.events where author = ${alice}`).length, 0);

        // A friend request needs an answer; a mutual one is a friendship.
        await tx`select public.send_friend_request(${alice})`;
        assertEquals((await tx`select id from public.events where author = ${alice}`).length, 0);
        await as(tx, alice);
        const [{ send_friend_request: status }] = await tx`select public.send_friend_request(${bob})`;
        assertEquals(status, 'accepted');

        // Nobody can read someone else's invite codes.
        await as(tx, bob);
        assertEquals((await tx`select code from public.invite_codes where owner = ${alice}`).length, 0);

        // Nobody makes themselves premium or resets their own AI allowance.
        await as(tx, alice);
        await refused(tx, (sp) =>
          sp`insert into public.subscriptions (user_id, product_id, platform, expires_at)
             values (${alice}, 'hundred_days_premium', 'manual', now() + interval '1 year')`);
        await refused(tx, (sp) => sp`insert into public.ai_usage (user_id, month) values (${alice}, now())`);
        await refused(tx, (sp) => sp`select public.ai_record_usage(${alice}, -1000000)`);
        const [{ my_ai_allowance: allowance }] = await tx`select public.my_ai_allowance()`;
        assertEquals(allowance.tier, 'free');
        assertEquals(allowance.used, 0);

        // A subscription the server granted counts; an expired one does not.
        await as(tx, null);
        await tx`insert into public.subscriptions (user_id, product_id, platform, expires_at)
                 values (${alice}, 'hundred_days_premium', 'manual', now() + interval '1 day')`;
        await as(tx, alice);
        assertEquals((await tx`select public.my_ai_allowance() as a`)[0].a.tier, 'premium');
        await as(tx, null);
        await tx`update public.subscriptions set expires_at = now() - interval '1 second' where user_id = ${alice}`;
        await as(tx, alice);
        assertEquals((await tx`select public.my_ai_allowance() as a`)[0].a.tier, 'free');

        throw new Rollback();
      });
    } catch (e) {
      if (!(e instanceof Rollback)) throw e;
    } finally {
      await sql.end();
    }
  },
});
