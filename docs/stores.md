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
  Connect API key with the App Manager role, the `.p8` file base64-encoded).
  Without them the iOS job says so and stops.

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
(1320×2868) with the status bar set to 9:41
(`xcrun simctl status_bar <device> override --time 9:41 …`); the Play ones
are the same images padded to 9:16 and scaled to 1080×1920. Play's default
listing language is en-GB, so `en-GB` is a copy of `en-US`.

## Review accounts

Sign-in is Google or Apple only, and Google Play's reviewers do not use
personal accounts. The backend therefore accepts e-mail and password for
addresses listed in `public.review_accounts` and nobody else (the
`before_user_created` hook). Two accounts exist on the hosted instance:

- `app-review@my-diary.app` for App Review — free tier, so the reviewers see
  and can test the subscription purchase;
- `play-review@my-diary.app` for Google Play — premium is unlocked with a
  `manual` subscription, because Play's reviewers cannot buy.

Their passwords are not in the repository; the operator keeps them and
enters them in App Store Connect (App Review Information) and the Play
Console (App content → Sign-in details). In the app they use **Sign in with
email** on the first screen. If a reviewer deletes the account, create it
again with the Auth admin API.
