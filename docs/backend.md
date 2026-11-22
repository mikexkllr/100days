# Backend

The app runs on [Supabase](https://supabase.com): Postgres with Row Level
Security, Auth (Apple, Google, e-mail and password), Realtime and a few edge functions.
Everything that makes up the backend is in [`supabase/`](../supabase):

```
supabase/
  config.toml           auth providers, function settings (secrets via env())
  .env.example          every secret the backend knows of, without values
  migrations/           the schema, its policies and functions, in order
  functions/            edge functions (Deno), with tests next to them
  tests/rls_test.ts     the policies, checked against a real database
```

The project's own instance is the app's default; anyone can run their own
(see [`self-hosting.md`](self-hosting.md)).

## What the server knows, and who may read it

| Data | Table | Who reads it |
| --- | --- | --- |
| Name, emoji, username | `profiles` | every signed-in user — like a profile in any social app |
| Check-ins, workouts, challenge, nudges | `events`, visibility `friends` | the author and their accepted friends |
| Body stats, targets, food diary, private habits | `events`, visibility `private` | the author only |
| Friendships, invite codes | `friendships`, `invite_codes` | the two people involved / the owner |
| Meal plan, recipes, shopping lists | `meal_plan_entries`, `recipes`, `shopping_*` | members of the household |
| Shared nutrition targets | `household_members` | household members — only while the member shares them; switching it off deletes the numbers |
| Findable, league, language, push switches | `user_settings` | the user only |
| Contact hashes | `contact_identifiers` | nobody but the `match-contacts` function |
| Subscription, AI usage | `subscriptions`, `ai_usage` | the user reads, only edge functions write |
| League groups and XP | `league_*` | through `league_standing()`: the user's own group |
| Push tokens | `push_tokens` | the user, and the `push` function |
| Who the user blocked | `blocks` | the blocker only |
| Reports | `reports` | nobody but the service role (moderation) |
| "Something changed in your friendships" | `social_pings` | the user only — a signal without names |

Every table has RLS enabled and explicit grants: a table gets exactly the
statements its policies are written for. `anon` (the publishable key alone)
gets nothing anywhere. The policies are tested in
[`supabase/tests/rls_test.ts`](../supabase/tests/rls_test.ts), which runs
inside one transaction against a development database and rolls everything
back.

## The feed

Everything a user does is an event in their own feed, and everything on
screen is a fold over events (`projectUser` in `hundred_core`). Postgres is
the source of truth; the phone keeps a cache.

```
events (id uuid, author, type, payload jsonb, visibility, client_ts,
        created_at, server_seq)
```

- **Append-only.** Clients may insert and select, nothing else. A correction
  is a new event (`food.removed`, `challenge.updated`, a check-in marked
  `undo`); a streak cannot be rewritten after the fact.
- **Only one's own feed.** `author = auth.uid()` on insert.
- **Ids come from the phone.** An event logged without a signal keeps its id
  when it is sent later, and a retried send is a no-op (`ON CONFLICT DO
  NOTHING`).
- **Two times.** `client_ts` is when the phone says it happened (at most ten
  minutes in the future); `created_at` is set by a trigger, whatever the
  client sends. An event that reaches the server more than 48 hours after
  its claimed time counts from when it arrived, so "logged live" cannot be
  forged by sending yesterday's entry next week.
- **Visibility.** A challenge is written twice — the view friends get (no
  body stats, no targets, no private habits) and the full one, private.
  Friends' devices compute the streak from what they can see.

### Sync

`SupabaseFeedSync` in the app:

1. **Push**: pending events in batches, then the server's copy (with
   `created_at` and `server_seq`) replaces the pending one in the cache. A
   batch the server refuses is sent again one event at a time, so one bad
   event does not hold back the rest; unsent events stamped too far ahead
   (a phone clock that ran ahead) get the real time first.
2. **Friends**: the friend list decides whose feeds belong on the phone. A
   new friend's whole history is fetched once; a former friend's feed is
   deleted from the phone.
3. **Pull**: everything readable with a `server_seq` above the pull cursor
   — kept in the cache's side table and moved only by the pull, never by
   pushed events, live inserts or a new friend's history, which would jump
   it past rows no pull has fetched. The pull runs even when the push
   failed. RLS decides what "readable" means; the client never filters by
   author for security.
4. **Live**: a realtime subscription while the app is open; the pull on
   resume and every two minutes catches what it missed.

Realtime does not apply Row Level Security to DELETE events, so tables whose
keys pair people up (`friendships`, `household_members`) are not in the
publication. Friendship changes reach the phone as a touch on the user's own
`social_pings` row; membership and settings changes as an UPDATE of the
`households` row.

## Friends

Invites are codes (`my_invite_code()`), shown as a QR code and a link
`hundreddays://invite/CODE`. Whoever shares a code has said yes, so
`redeem_invite()` makes both friends at once. Codes expire after 14 days and
can be revoked; ending a friendship revokes the remover's codes, so an old
code cannot make the same friendship again. Friend requests
(`send_friend_request()`) need an answer; two people asking each other are
friends. At most 30 new requests a day, and after a "no" the same person
cannot ask again for 30 days — unless the other one asks.

**Blocking and reporting.** `block_user()` ends the friendship and every
pending request both ways; from then on neither can send the other a request
or redeem the other's invite, and they do not find each other in search,
contact matching or the public league. `report_user()` stores a report for
moderation (at most 20 a day); nobody but the service role reads reports.

Finding people:

- **Username search** (`search_profiles()`): only people who chose a
  username, by its start or their name's.
- **Address book** (`match-contacts` function): the app sends e-mail
  addresses and E.164 phone numbers; the function hashes them with
  HMAC-SHA256 under a secret pepper, compares them with the registered
  hashes and forgets them. The hashes travel in the request body and are
  compared in the database (`match_contact_hashes()`). Only identifiers the
  identity provider (or an SMS code) verified are registered, and only for
  users who switched on "findable". At most 10 matches and 5000 identifiers
  a day per user, counted atomically. Phone numbers are not sent while no
  phone number can be verified (`kMatchPhoneNumbers` in the app).

## Households

A household is the people who cook and shop together. Members read and
change its plan, recipes and lists; nobody else sees them. The shopping
list is ticked off live through realtime. Invites work like friend invites
(`household_invite_code()`, `join_household()`); joining removes the
joiner's own empty household. Removing a member revokes the household's
codes; `leave_household()` takes the caller out and, if they owned it,
hands it to the longest-standing member (as does deleting the owner's
account). Members switch on sharing their calorie and
protein target so whoever plans can size their portions; the rest of the
diary is never part of a household.

## Leagues

Two leagues:

- **Among friends**, computed on every phone from the friends' events — the
  same verifiable number everywhere.
- **Public**, with divisions (Bronze to Obsidian): groups of up to 30 per
  division and week; `close_league_week()` runs from `pg_cron` on Monday at
  12:15 UTC — when the week is over in every time zone — and moves the top
  up and the bottom down (7 and 5 in a full group, fewer in small ones). The
  weekly XP is reported by the phone through `report_week_xp()` for the
  week of its own calendar (any week some time zone is in right now),
  capped at 1000 a day of the week so far; the function says whether the
  report was taken. That is
  the honest limit of a league with strangers: their number is a claim,
  bounded but not proven.

## Edge functions

| Function | Does | Secrets |
| --- | --- | --- |
| `llm-gateway` | the AI, see [`ai.md`](ai.md); reserves an estimate of a request's tokens before it starts and settles with the real usage, so parallel requests cannot overrun the allowance; at most 200,000 characters of text | `GEMINI_API_KEY`, allowance overrides |
| `verify-purchase` | asks the App Store or Google Play whether a subscription is real and writes `subscriptions` | `APPSTORE_*`, `APP_BUNDLE_ID`, `GOOGLE_SERVICE_ACCOUNT_JSON`, `ANDROID_PACKAGE_NAME` |
| `match-contacts` | address-book matching, registering as findable | `CONTACT_PEPPER` |
| `push` | FCM pushes for nudges, cheers, requests, friend activity | `FCM_SERVICE_ACCOUNT_JSON` |
| `delete-account` | deletes the user (everything cascades), revokes Sign in with Apple | `APPLE_*` (optional) |

All of them authenticate the caller themselves (`verify_jwt = false` in
`config.toml`): a user access token is required, the publishable key alone
is refused. Tests: `deno test --allow-env supabase/functions`.

## Premium

The tier lives in `subscriptions`, which only `verify-purchase` writes. The
app never decides that it is premium; it hands the store's proof to the
function, which asks the store (App Store Server API, Google Play Developer
API) and records the expiry. A store subscription bound to one account is
not handed over to another by replaying it. The app listens for purchases
from the start of every session, so a renewal is picked up; on Android,
where the store does not announce renewals, active subscriptions are handed
to the function again once a start. A purchase the function could not be
reached for is left open, so the store hands it over again. Sandbox
purchases are accepted on purpose: App Review buys in the sandbox with the
production build.
