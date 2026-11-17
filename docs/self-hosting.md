# Running your own backend

100 Days is open source end to end: the app, and everything the server
does. The app talks to the project's hosted instance by default; you can
point it at your own Supabase — on supabase.com or self-hosted with Docker —
and pay for nothing but what you run.

No secret is ever in the repository. The app carries only public values
(the backend URL, its publishable key, OAuth client ids); everything that
must stay secret lives in Supabase's function secrets, in a git-ignored
`supabase/.env`, or in GitHub secrets.

## 1. A Supabase project

Hosted:

```bash
supabase projects create my-100days --region eu-central-1
supabase link --project-ref <ref>
```

Self-hosted: follow Supabase's [self-hosting guide](https://supabase.com/docs/guides/self-hosting),
then link the CLI to it with `--db-url`. Everything below works the same;
`pg_cron` and `pg_net` ship with the Supabase Postgres image.

## 2. Schema, policies, functions

```bash
supabase db push
supabase functions deploy llm-gateway verify-purchase match-contacts push delete-account
```

Check the policies against your database (it runs in a transaction that is
rolled back — still, use a development project):

```bash
DATABASE_URL=postgresql://… deno test -A supabase/tests/rls_test.ts
```

## 3. Secrets

Copy `supabase/.env.example` to `supabase/.env` (git-ignored), fill in what
you use, then:

```bash
supabase secrets set --env-file supabase/.env
supabase config push          # auth providers from config.toml
```

| Secret | For | Without it |
| --- | --- | --- |
| `GEMINI_API_KEY` | the AI gateway | AI only with users' own keys |
| `FREE_AI_TOKENS_PER_MONTH`, `PREMIUM_AI_TOKENS_PER_MONTH`, `AI_REQUESTS_PER_MINUTE` | allowances | 50k / 3M / 20 |
| `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID`, `…_GOOGLE_SECRET` | Google sign-in | no Google button |
| `SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID` | Sign in with Apple (your bundle id) | no Apple button |
| `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_CLIENT_ID` | revoking Sign in with Apple on account deletion | deletion works, revocation is skipped |
| `CONTACT_PEPPER` | address-book matching (any long random string) | no contact matching |
| `FCM_SERVICE_ACCOUNT_JSON` | push notifications | no pushes; local reminders still work |
| `APPSTORE_ISSUER_ID`, `APPSTORE_KEY_ID`, `APPSTORE_PRIVATE_KEY`, `APP_BUNDLE_ID` | premium on iOS | no purchases on iOS |
| `GOOGLE_SERVICE_ACCOUNT_JSON`, `ANDROID_PACKAGE_NAME` | premium on Android | no purchases on Android |
| `PREMIUM_PRODUCT_IDS` | store product ids | `hundred_days_premium_monthly`, `hundred_days_premium_yearly` |

Want a premium tier without stores, e.g. for your family? Insert rows into
`subscriptions` with platform `manual` as the service role.

## 4. Sign-in

**Google.** In Google Cloud, create OAuth clients: a *Web* client (its id
and secret go into the Supabase settings above; the app uses its id as
`serverClientId`), an *iOS* client for your bundle id, and an *Android*
client per signing key (debug, upload, Play app signing) with its SHA-1.
Put the web and iOS ids comma-separated into
`SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID`. On iOS, add the iOS client's
reversed id as a URL scheme in `ios/Runner/Info.plist`.

**Apple.** Enable *Sign in with Apple* for your bundle id in the Apple
Developer portal (the entitlement is in `ios/Runner/Runner.entitlements`).
Native sign-in needs no secret; for the revocation on account deletion,
create a *Sign in with Apple* key and set the `APPLE_*` secrets.

## 5. The app

Build-time configuration, as a JSON file you keep out of git:

```json
{
  "SUPABASE_URL": "https://<ref>.supabase.co",
  "SUPABASE_KEY": "sb_publishable_…",
  "GOOGLE_WEB_CLIENT_ID": "….apps.googleusercontent.com",
  "GOOGLE_IOS_CLIENT_ID": "….apps.googleusercontent.com",
  "FIREBASE_API_KEY": "…",
  "FIREBASE_PROJECT_ID": "…",
  "FIREBASE_SENDER_ID": "…",
  "FIREBASE_ANDROID_APP_ID": "1:…:android:…",
  "FIREBASE_IOS_APP_ID": "1:…:ios:…"
}
```

```bash
flutter run --dart-define-from-file=config/my-backend.json
```

Only `SUPABASE_URL` and `SUPABASE_KEY` are required; without the Google ids
the Google button is hidden, without the Firebase values push is off.
Users of a stock build can also switch to your server on the sign-in screen
under **Own server** (URL, publishable key, optionally the Google web
client id); the choice is remembered on the device.

In CI, store that JSON as a secret and write it to a file before
`flutter build`.

## Moving off the hosted instance

```bash
supabase db dump --linked -f schema.sql
supabase db dump --linked --data-only -f data.sql
supabase db dump --linked --data-only --schema auth -f auth.sql
```

Restore the three into your own instance (auth first), deploy the functions,
set the secrets, and give the app the new URL. Users sign in again with the
same Google account — or the same Apple account, as long as the app stays in
the same Apple developer team — and find everything where it was.
