# Releasing to the stores

## The pipes

| Branch | Android (`play-internal.yml`) | iOS (`ios.yml`) |
| --- | --- | --- |
| `dev` | internal testing | TestFlight, internal testers |
| `main` | closed testing (track `alpha`) | App Store Connect: build and listing attached to the App Store version |

Both run the full CI first. Submitting the App Store version for review is a
click in App Store Connect, unless the repository variable `IOS_AUTO_SUBMIT`
is `true`. Production on Google Play is promoted by hand from closed testing;
a new developer account may request production access only after 14 days of
closed testing with at least 12 opted-in testers.

Secrets:

- `play-internal` environment: `ANDROID_KEYSTORE_*`, `PLAY_SERVICE_ACCOUNT_JSON`
  (see [`play-release.md`](play-release.md)).
- `app-store` environment: `APP_STORE_CONNECT_KEY_ID`,
  `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_BASE64` (an App Store
  Connect API key with the **Admin** role, the `.p8` file base64-encoded).
  Admin, because the export uses Apple's cloud signing ("cloud-managed
  distribution certificate"), which App Manager keys may not use. Without
  them the iOS job says so and stops.
- Repository secret `SENTRY_DSN`: the client key of the Sentry project
  `mike-keller-2t/100days` (EU region). Both release workflows add it and
  `SENTRY_ENVIRONMENT` (`production` on `main`, `internal` / `testflight`
  on `dev`) to the build defines; without it the builds report nothing.
  The project stores no IP addresses; the app sends errors and crashes
  only (no tracing, no screenshots, no user). Debug symbols are not
  uploaded yet: the builds are not obfuscated, so Dart stack traces read
  as they are; native frames would need `SENTRY_AUTH_TOKEN` and
  `sentry_dart_plugin`.
- Repository secrets `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`,
  `SUPABASE_PROJECT_REF` for `supabase.yml` (migrations and functions on
  `main`); without them that job skips.

## What the stores are set up with

| | App Store | Google Play |
| --- | --- | --- |
| Name | 100 Days & Beyond (DE: 100 Tage & mehr) | same |
| Bundle / package | `com.hundreddays.hundredDays` | `com.hundreddays.hundred_days` |
| Category | Health & Fitness, Lifestyle | Health & fitness |
| Premium | group "Premium": `hundred_days_premium_yearly` €19.99, `hundred_days_premium_monthly` €2.99 | subscriptions with the same ids, base plans `yearly` / `monthly`, DE €19.99 / €2.99 |
| Privacy | label: name, e-mail, health, fitness, photos, contacts (the friend list is a social graph), other content (incl. reports), user id, device id, purchases — app functionality, linked to the user; crash data and other diagnostics (Sentry) — app functionality, not linked; no tracking | data safety form: the same, address book and photos processed ephemerally, reports also for fraud prevention and security, crash logs and diagnostics; sign-up with username and password and with OAuth; deletion URL |
| Age | 16+ in the terms; age rating from `app/ios/fastlane/age_rating.json`: computed 13+ (alcohol and nicotine come up as habits to quit), overridden to 16+ because the terms require it | IARC questionnaire, target audience 16–17 and 18+ |
| Policies | | ads: no; advertising ID: no; health: activity & nutrition; finance: none; government: no |

Purchases are checked by the `verify-purchase` function: the App Store
Server API with an **In-App Purchase key** (`APPSTORE_ISSUER_ID`,
`APPSTORE_KEY_ID`, `APPSTORE_PRIVATE_KEY`, `APP_BUNDLE_ID`) and the Google
Play Developer API with a service account (`GOOGLE_SERVICE_ACCOUNT_JSON`,
`ANDROID_PACKAGE_NAME`) that has "View financial data" in the Play Console.
See [`self-hosting.md`](self-hosting.md) for setting function secrets.

Google sign-in uses the Google Cloud project's OAuth consent screen
("100 Days & Beyond", in production) and OAuth clients: a web client (its id
is the `serverClientId` and in Supabase's Google provider), an iOS client
(its reversed id is a URL scheme in `ios/Runner/Info.plist`) and one Android
client per signing certificate (debug, upload key, Play app signing). The
hosted instance's ids are the defaults in `lib/config/backend_config.dart`.

E-mail sign-up confirms the address with a mail, sent through our own mail
server — the one Memoria uses (docker-mailserver on the VPS, see Memoria's
`CLAUDE.md`). In the Supabase dashboard, Authentication → Emails → SMTP
Settings: host `mail.my-diary.app`, port 465, user and sender
`noreply@my-diary.app`, sender name "100 Days & Beyond", and that account's
password; a password change on the mail server has to be repeated here and
in Memoria. With its own SMTP server Supabase sends up to 30 auth mails an
hour (Authentication → Rate Limits). The link in the mail leads to
`hundreddays://login-callback`, which has to be the Site URL or one of the
Redirect URLs (Authentication → URL Configuration).

## Before the first review

- App Review information in App Store Connect: the demo account and a note
  ("Sign in with email" on the first screen).
- A review screenshot per App Store subscription: the AI & subscription
  screen with both plans (`tool/store_screenshots.sh`, see *Screenshots*).
- Closed testing on Google Play: the track (`alpha`) uses the email list
  "Tester", all countries, feedback to info@my-diary.app. Production access
  can be requested after 14 days with at least 12 opted-in testers.
- Push notifications: Firebase is enabled on the Google Cloud project
  `daysandbeyond` (Analytics off) with an Android and an iOS app. Their ids
  and the Firebase API key are the `FIREBASE_*` build defines in the
  repository secret `APP_DEFINES_JSON`, which both release workflows pass to
  `--dart-define-from-file`. The `push` function needs
  `FCM_SERVICE_ACCOUNT_JSON` (a key of the `firebase-adminsdk` service
  account, set on the hosted instance), and iOS delivery goes through a
  team-scoped APNs key (sandbox and production) uploaded under Project
  settings → Cloud Messaging. A self-hosted build without them runs with
  local reminders only.

## The listing

Everything the stores show lives in the repository:

- `app/android/fastlane/metadata/android/<locale>/` — title, descriptions,
  release notes, icon, feature graphic, phone screenshots. Uploaded by
  `play-listing.yml` (manual, and on `main` when it changes).
- `app/ios/fastlane/metadata/<locale>/` and `app/ios/fastlane/screenshots/` —
  uploaded with the build on `main` (`fastlane release`) or alone
  (`fastlane listing`, from the workflow's manual run).
- The website with privacy policy, terms and account deletion: `site/`
  (see `pages.yml`).

### Icon and graphics

```bash
cd app
flutter test tool/app_icon_test.dart   # icon, adaptive layers, feature graphics
./tool/install_app_icon.sh             # into the iOS and Android projects
```

### Screenshots

`lib/main_demo.dart` starts the app with a believable account in memory —
no sign-in, no server, the AI off:

```bash
flutter run -t lib/main_demo.dart --dart-define=DEMO_LOCALE=en
```

The store screenshots are taken from it on an iPhone 17 Pro Max simulator
(1320×2868) with the status bar set to 9:41; the Play ones are the same
images padded to 9:16 and scaled to 1080×1920. Play's default listing
language is en-GB, so `en-GB` is a copy of `en-US`. One command does all
of it, for both languages:

```bash
cd app
./tool/store_screenshots.sh <simulator-udid>      # or: … <udid> en
```

`integration_test/store_screenshots_test.dart` opens each screen and the
script takes the simulator's screenshot, so the status bar is real. The
same run leaves the subscription review screenshot (the AI & subscription
screen with both plans, which the demo prices without a store) in
`build/store_screenshots/`. Commit the images; `main` uploads them.

## Review accounts

Google Play's reviewers do not use personal accounts, and both stores want
an account they can be handed. Anyone can register with e-mail and password
in the app; for the stores, two such accounts are set up in advance on the
hosted instance (`public.review_accounts` lists them, as a note):

- `app-review@my-diary.app` for App Review — free tier, so the reviewers see
  and can test the subscription purchase;
- `play-review@my-diary.app` for Google Play — premium is unlocked with a
  `manual` subscription, because Play's reviewers cannot buy.

Their passwords are not in the repository; the operator keeps them and
enters them in App Store Connect (App Review Information) and the Play
Console (App content → Sign-in details). In the app they use **Continue with
email** on the first screen. If a reviewer deletes the account, create it
again with the Auth admin API.
