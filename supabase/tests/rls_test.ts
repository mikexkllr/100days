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
        await refused(tx, (sp) => sp`select public.ai_settle_usage(${alice}, current_date, 1000000, 0)`);
        await refused(tx, (sp) => sp`select public.ai_begin_request(${alice}, 1000000, 100, 0)`);
        const [{ my_ai_allowance: allowance }] = await tx`select public.my_ai_allowance()`;
        assertEquals(allowance.tier, 'free');
        assertEquals(allowance.used, 0);

        // A request reserves its worst case as it starts, so the next one
        // sees it; settling replaces the reservation with what it cost.
        await as(tx, null);
        const begin = async (reserve: number) =>
          (await tx`select public.ai_begin_request(${bob}, 1000, 100, ${reserve}) as r`)[0].r;
        const first = await begin(1200);
        assert(first.allowed, 'a request with something left goes through');
        assertEquals((await begin(10)).reason, 'quota_exceeded');
        await tx`select public.ai_settle_usage(${bob}, ${first.month}::date, ${first.reserved}, 300)`;
        const third = await begin(10);
        assert(third.allowed, 'the settled request freed the rest');
        assertEquals(third.used, 300);

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

        // --- Households -------------------------------------------------------
        const carol = await createUser(tx, 'Carol');
        await as(tx, alice);
        const [{ create_household: home }] = await tx`select public.create_household('Zuhause')`;
        const [recipe] = await tx`
          insert into public.recipes (household_id, title, servings)
          values (${home}, 'Curry', 2) returning id`;
        await tx`insert into public.meal_plan_entries (household_id, day, slot, recipe_id)
                 values (${home}, current_date, 'dinner', ${recipe.id})`;
        const [list] = await tx`
          insert into public.shopping_lists (household_id, period_start, period_end)
          values (${home}, current_date, current_date + 6) returning id`;
        await tx`insert into public.shopping_items (list_id, household_id, name) values (${list.id}, ${home}, 'Reis')`;

        // Someone outside sees nothing and cannot write into it.
        await as(tx, carol);
        assertEquals((await tx`select id from public.households where id = ${home}`).length, 0);
        assertEquals((await tx`select id from public.shopping_items where household_id = ${home}`).length, 0);
        await refused(tx, (sp) =>
          sp`insert into public.shopping_items (list_id, household_id, name) values (${list.id}, ${home}, 'Bier')`);
        await refused(tx, (sp) =>
          sp`insert into public.household_members (household_id, user_id) values (${home}, ${carol})`);

        // An invite makes Carol a member; her own empty household goes.
        const [{ create_household: carolsOwn }] = await tx`select public.create_household('')`;
        await as(tx, alice);
        const [{ household_invite_code: homeCode }] = await tx`select public.household_invite_code(${home})`;
        await as(tx, carol);
        const [homePreview] = await tx`select * from public.household_invite_preview(${homeCode})`;
        assertEquals(homePreview.name, 'Zuhause');
        await tx`select public.join_household(${homeCode})`;
        assertEquals((await tx`select id from public.households where id = ${carolsOwn}`).length, 0);
        assertEquals((await tx`select name from public.shopping_items where household_id = ${home}`).length, 1);
        await tx`update public.shopping_items set checked = true where household_id = ${home}`;

        // Targets are only stored while shared.
        await tx`update public.household_members set share_targets = true, kcal_target = 2100
                 where household_id = ${home} and user_id = ${carol}`;
        await as(tx, alice);
        const [sharedTargets] = await tx`select kcal_target from public.household_members where user_id = ${carol}`;
        assertEquals(sharedTargets.kcal_target, 2100);
        await as(tx, carol);
        await tx`update public.household_members set share_targets = false
                 where household_id = ${home} and user_id = ${carol}`;
        const [unshared] = await tx`select kcal_target from public.household_members where user_id = ${carol}`;
        assertEquals(unshared.kcal_target, null);

        // Nobody promotes themselves, and an item cannot be moved to another
        // household's list.
        await refused(tx, (sp) =>
          sp`update public.household_members set role = 'owner' where user_id = ${carol} and household_id = ${home}`);
        await as(tx, bob);
        const [{ create_household: bobs }] = await tx`select public.create_household('')`;
        await refused(tx, (sp) =>
          sp`insert into public.shopping_items (list_id, household_id, name) values (${list.id}, ${bobs}, 'x')`);

        // The owner may remove a member; then she sees nothing any more.
        await as(tx, alice);
        await tx`delete from public.household_members where household_id = ${home} and user_id = ${carol}`;
        await as(tx, carol);
        assertEquals((await tx`select id from public.recipes where household_id = ${home}`).length, 0);
        // ...and the code she came in with no longer opens the door.
        await refused(tx, (sp) => sp`select public.join_household(${homeCode})`);

        // The last member leaving takes the household with them, so a deleted
        // account leaves no plan or list behind.
        await as(tx, bob);
        await tx`delete from public.household_members where household_id = ${bobs} and user_id = ${bob}`;
        await as(tx, null);
        assertEquals((await tx`select id from public.households where id = ${bobs}`).length, 0);
        assertEquals((await tx`select id from public.households where id = ${home}`).length, 1);

        // An owner who leaves hands the household to whoever has been there
        // longest; the last one out turns off the lights.
        const dave = await createUser(tx, 'Dave');
        const erin = await createUser(tx, 'Erin');
        await as(tx, alice);
        const [{ household_invite_code: freshCode }] = await tx`select public.household_invite_code(${home})`;
        assert(freshCode !== homeCode, 'a fresh code after the old one was revoked');
        for (const member of [dave, erin]) {
          await as(tx, member);
          await tx`select public.join_household(${freshCode})`;
        }
        await as(tx, null);
        await tx`update public.household_members set joined_at = now() - interval '1 day'
                 where household_id = ${home} and user_id = ${erin}`;
        // Every change of membership reaches the household's own row, which
        // is what the phones listen to now.
        const [{ ctid: before }] = await tx`select ctid::text from public.households where id = ${home}`;
        await as(tx, alice);
        await refused(tx, (sp) => sp`select public.leave_household(${bobs})`);
        await tx`select public.leave_household(${home})`;
        await as(tx, null);
        const [{ ctid: after }] = await tx`select ctid::text from public.households where id = ${home}`;
        assert(before !== after, 'leaving touched the household row');
        const owners = await tx`select user_id from public.household_members
                                where household_id = ${home} and role = 'owner'`;
        assertEquals(owners.map((r: { user_id: string }) => r.user_id), [erin]);
        await as(tx, erin);
        await tx`select public.revoke_household_invites(${home})`;
        await as(tx, carol);
        await refused(tx, (sp) => sp`select public.join_household(${freshCode})`);
        for (const member of [erin, dave]) {
          await as(tx, member);
          await tx`select public.leave_household(${home})`;
        }
        await as(tx, null);
        assertEquals((await tx`select id from public.households where id = ${home}`).length, 0);

        // --- Sign-up hook ------------------------------------------------------
        // Google, Apple and e-mail all pass; only Auth itself may call it.
        await as(tx, null);
        const hook = async (provider: string, email: string) =>
          (await tx`select public.hook_before_user_created(${
            { user: { email, app_metadata: { provider } } }
          }::jsonb) as r`)[0].r;
        assertEquals(await hook('google', 'someone@example.com'), {});
        assertEquals(await hook('apple', 'relay@privaterelay.appleid.com'), {});
        assertEquals(await hook('email', 'new@example.com'), {});
        await as(tx, alice);
        await refused(tx, (sp) => sp`select * from public.review_accounts`);
        await refused(tx, (sp) => sp`select public.hook_before_user_created('{}'::jsonb)`);

        // --- Social ---------------------------------------------------------
        await as(tx, alice);
        await tx`update public.profiles set username = 'alice_runs' where id = ${alice}`;
        await refused(tx, (sp) => sp`update public.profiles set username = 'Bad Name!' where id = ${alice}`);
        await tx`insert into public.user_settings (user_id, discoverable) values (${alice}, true)`;
        await tx`insert into public.push_tokens (token, user_id, platform) values ('tok-alice', ${alice}, 'ios')`;

        await as(tx, bob);
        // Only people with a username are found, by its start or their name.
        const found = await tx`select * from public.search_profiles('ali')`;
        assertEquals(found.map((r: { username: string }) => r.username), ['alice_runs']);
        assertEquals((await tx`select * from public.search_profiles('carol')`).length, 0);
        // Settings, tokens and contact hashes are nobody else's business.
        assertEquals((await tx`select * from public.user_settings where user_id = ${alice}`).length, 0);
        assertEquals((await tx`select * from public.push_tokens where user_id = ${alice}`).length, 0);
        await refused(tx, (sp) => sp`select * from public.contact_identifiers`);
        await refused(tx, (sp) => sp`select public.contact_match_allowed(${bob}, 1)`);
        await refused(tx, (sp) =>
          sp`insert into public.push_tokens (token, user_id, platform) values ('x', ${alice}, 'ios')`);

        // A week's XP is capped at what the days so far can earn, and a
        // reporter lands in a group with others of the division.
        const [{ current_week: week }] = await tx`select public.current_week()`;
        await tx`select public.report_week_xp(${week}, 999999)`;
        await as(tx, alice);
        await tx`select public.report_week_xp(${week}, 120)`;
        const standing = await tx`select * from public.league_standing(${week})`;
        assertEquals(standing.length, 2);
        assertEquals(standing[0].user_id, bob);
        assert(standing[0].xp <= 7000, 'the cap holds');
        assertEquals(standing[1].xp, 120);
        await refused(tx, (sp) => sp`select * from public.league_entries`);
        await refused(tx, (sp) => sp`select public.close_league_week(${week})`);
        // An old week cannot be rewritten, and the phone hears so.
        assertEquals((await tx`select public.report_week_xp('2020-W01', 50) as ok`)[0].ok, false);
        assertEquals((await tx`select public.report_week_xp(${week}, 130) as ok`)[0].ok, true);
        // The week some time zone is already (or still) in counts too.
        const [{ ahead, behind }] = await tx`
          select to_char((now() at time zone 'utc') + interval '14 hours', 'IYYY-"W"IW') as ahead,
                 to_char((now() at time zone 'utc') - interval '12 hours', 'IYYY-"W"IW') as behind`;
        assertEquals((await tx`select public.report_week_xp(${ahead}, 10) as ok`)[0].ok, true);
        assertEquals((await tx`select public.report_week_xp(${behind}, 10) as ok`)[0].ok, true);
        assertEquals((await tx`select public.report_week_xp(${week}, 120) as ok`)[0].ok, true);
        await as(tx, null);
        assertEquals((await tx`select * from public.league_entries where week = '2020-W01'`).length, 0);

        // Who is friends with whom is nobody else's question.
        await as(tx, carol);
        await refused(tx, (sp) => sp`select public.are_friends(${alice}, ${bob})`);

        // Realtime carries no pairs of people: friendships and memberships
        // are out of the publication, and each user's ping is their own.
        await as(tx, null);
        const published = (await tx`
          select tablename from pg_publication_tables
          where pubname = 'supabase_realtime' and schemaname = 'public'`)
          .map((r: { tablename: string }) => r.tablename);
        assert(!published.includes('friendships'), 'friendships are not broadcast');
        assert(!published.includes('household_members'), 'memberships are not broadcast');
        assert(published.includes('social_pings') && published.includes('households'));
        await as(tx, bob);
        const pings = await tx`select user_id from public.social_pings`;
        assertEquals(pings.map((r: { user_id: string }) => r.user_id), [bob]);

        // --- Friend requests: a daily cap, and a no means no for a while ----
        await as(tx, carol);
        await tx`select public.send_friend_request(${dave})`;
        await as(tx, dave);
        await tx`select public.respond_friend_request(${carol}, false)`;
        await as(tx, carol);
        await refused(tx, (sp) => sp`select public.send_friend_request(${dave})`);
        await refused(tx, (sp) => sp`select * from public.friend_request_declines`);
        // Unless the one who said no asks.
        await as(tx, dave);
        await tx`select public.send_friend_request(${carol})`;
        await as(tx, carol);
        assertEquals((await tx`select public.send_friend_request(${dave}) as s`)[0].s, 'accepted');

        const strangers: string[] = [];
        for (let i = 0; i < 31; i++) strangers.push(await createUser(tx, `Stranger${i}`));
        await as(tx, erin);
        for (const stranger of strangers.slice(0, 30)) await tx`select public.send_friend_request(${stranger})`;
        await refused(tx, (sp) => sp`select public.send_friend_request(${strangers[30]})`);

        // Ending a friendship revokes the ender's codes: the old link cannot
        // bring the other one back.
        await as(tx, carol);
        const [{ my_invite_code: carolsCode }] = await tx`select public.my_invite_code()`;
        await tx`select public.remove_friend(${dave})`;
        await as(tx, dave);
        await refused(tx, (sp) => sp`select public.redeem_invite(${carolsCode})`);

        // --- Blocking and reporting ------------------------------------------
        // Alice and Bob are friends and share a league group.
        await as(tx, alice);
        const [{ my_invite_code: alicesCode }] = await tx`select public.my_invite_code()`;
        await tx`select public.block_user(${bob})`;
        assertEquals((await tx`select * from public.friendships where ${bob} in (requester, addressee)`).length, 0);
        const blocks = await tx`select * from public.my_blocks()`;
        assertEquals(blocks.map((r: { user_id: string }) => r.user_id), [bob]);
        // Alice's own view of the league leaves Bob out; the ranks stay real.
        const blockedStanding = await tx`select * from public.league_standing(${week})`;
        assertEquals(blockedStanding.map((r: { user_id: string }) => r.user_id), [alice]);
        assertEquals(blockedStanding[0].rank, 2);
        assertEquals(blockedStanding[0].group_size, 2);

        // To Bob, Alice is simply not there — and he cannot tell why.
        await as(tx, bob);
        assertEquals((await tx`select * from public.blocks`).length, 0);
        assertEquals((await tx`select * from public.search_profiles('ali')`).length, 0);
        await refused(tx, (sp) => sp`select public.send_friend_request(${alice})`);
        assertEquals((await tx`select * from public.invite_preview(${alicesCode})`).length, 0);
        await refused(tx, (sp) => sp`select public.redeem_invite(${alicesCode})`);
        assertEquals((await tx`select * from public.friendships where ${alice} in (requester, addressee)`).length, 0);
        await refused(tx, (sp) => sp`insert into public.blocks (blocker, blocked) values (${bob}, ${carol})`);

        // Nor does the address book find her.
        await as(tx, null);
        await tx`insert into public.contact_identifiers (kind, hmac, user_id) values ('email', 'h-alice', ${alice})`;
        const matchFor = async (user: string) =>
          (await tx`select user_id from public.match_contact_hashes(${user}, array['h-alice'], null)`)
            .map((r: { user_id: string }) => r.user_id);
        assertEquals(await matchFor(carol), [alice]);
        assertEquals(await matchFor(bob), []);
        await as(tx, carol);
        await refused(tx, (sp) => sp`select * from public.match_contact_hashes(${carol}, array['h-alice'], null)`);

        // A report reaches the operator and nobody else.
        await as(tx, bob);
        await tx`select public.report_user(${alice}, 'harassment', 'Mean nudges')`;
        await refused(tx, (sp) => sp`select * from public.reports`);
        await refused(tx, (sp) => sp`select public.report_user(${alice}, 'because', '')`);
        await refused(tx, (sp) => sp`select public.report_user(${bob}, 'spam', '')`);
        await as(tx, alice);
        await refused(tx, (sp) => sp`select * from public.reports`);
        await as(tx, null);
        const [report] = await tx`select * from public.reports where target = ${alice}`;
        assertEquals([report.reporter, report.reason, report.target_username], [bob, 'harassment', 'alice_runs']);

        // Unblocking lets them find each other again; nothing comes back by itself.
        await as(tx, alice);
        await tx`select public.unblock_user(${bob})`;
        await as(tx, bob);
        assertEquals((await tx`select * from public.search_profiles('ali')`).length, 1);
        assertEquals((await tx`select * from public.friendships where ${alice} in (requester, addressee)`).length, 0);

        // A deleted account takes the push log it caused with it.
        await as(tx, null);
        await tx`insert into public.push_log (recipient, kind, sender) values (${alice}, 'nudge', ${strangers[0]})`;
        await tx`delete from auth.users where id = ${strangers[0]}`;
        assertEquals((await tx`select * from public.push_log where sender = ${strangers[0]}`).length, 0);

        throw new Rollback();
      });
    } catch (e) {
      if (!(e instanceof Rollback)) throw e;
    } finally {
      await sql.end();
    }
  },
});
