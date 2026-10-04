# Google Play — internal releases

A manual pipeline ships the app to the **internal track** on Google Play:
**Actions → Play Store — internal release → Run workflow** builds a release
AAB, signs it with the upload key and uploads it to the Play Console.

Internal is the right first step on the store: up to 100 testers you name
yourself, no review, and a release is on a tester's phone about two minutes
after the button is pressed. Promotion to the closed, open and production
tracks is a later pipeline — deliberately not this one.

## One-time setup

The pipeline needs five repository secrets and one app entry in the Play
Console. Nothing here changes the app's architecture: still no server, still
no account, and the key material lives in GitHub's secret store, not in the
repository.

### 1. The app in the Play Console

[play.google.com/console](https://play.google.com/console) → **Create app**,
name it, and pick the package name **`com.hundreddays.hundred_days`** — it has
to match the `applicationId` in `app/android/app/build.gradle.kts` exactly.
Everything else (listings, screenshots, content ratings) can stay empty for
the internal track.

### 2. The upload key

One keystore, generated once, kept forever — Play identifies the app by it,
and losing it means a support ticket to Google. Generate it with `keytool`,
which ships with every JDK:

```bash
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

The key password may be the same as the store password — then
`ANDROID_KEY_PASSWORD` and `ANDROID_KEYSTORE_PASSWORD` hold the same value.

Play App Signing (the store re-signing deliveries with its own key) is on by
default and recommended; the upload key is then only the identity you push
with, exactly what this pipeline uses it for.

### 3. The service account

In the Play Console: **Setup → API access → Create new service account**,
follow the link to the Google Cloud Console, create the account, generate a
**JSON** key for it, download the JSON file. Back in the Play Console, grant
the account access to this app — **Admin** is the simplest, **App manager**
is the smaller role that still suffices for uploads.

### 4. The secrets

With the GitHub CLI (`gh auth login` once, if you have not):

```bash
gh secret set PLAY_SERVICE_ACCOUNT_JSON < service-account.json
gh secret set ANDROID_KEYSTORE_ALIAS   -b "upload"

# passwords typed on the next line, not on the command line
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_PASSWORD

base64 -i upload-keystore.jks -o upload-keystore.b64   # macOS
# base64 -w0 upload-keystore.jks  > upload-keystore.b64  # Linux
gh secret set ANDROID_KEYSTORE_BASE64 < upload-keystore.b64
```

Delete `upload-keystore.b64` and keep a second copy of `upload-keystore.jks`
somewhere safe that is not this machine.

### 5. A tester list

**Testing → Internal testing → testers** — create a list with the Gmail
addresses of the people who should get it. They opt in once via the track's
link, and from then on updates arrive on their own, like any store update.

## Releasing

Two things, in this order:

1. **Bump the build number** — the `+N` suffix in `version:` in
   `app/pubspec.yaml`. Play rejects a version code it has already seen, with
   exactly that wording in the failed run.
2. **Actions → Play Store — internal release → Run workflow** on the branch
   you want to ship.

The run shows the version it is about to ship, then builds, signs and
uploads. The AAB is also kept as a workflow artifact, so a shipped release
can be inspected afterwards.

## Signing a local build the same way

CI passes the key through four environment variables; a local release build
can do the same:

```bash
export HUNDRED_KEYSTORE_PATH=~/keys/upload-keystore.jks
export HUNDRED_KEYSTORE_PASSWORD=…   # store password
export HUNDRED_KEY_ALIAS=upload
export HUNDRED_KEY_PASSWORD=…        # key password

cd app && flutter build appbundle --release
```

Without the variables the release build falls back to the debug key — that
is what `flutter run --release` has always done, and it keeps working.

## What is deliberately not here

- **Production, closed and open tracks.** Promotion beyond internal is a
  separate pipeline, and a separate decision.
- **Release notes and staged rollout.** The internal track does not need
  them; a production pipeline would.
- **Automatic triggers.** No push, tag or schedule starts a release. A store
  upload should never be a side effect.
