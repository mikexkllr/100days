# Google Play — internal releases

Every merge to `main` ships the app to the **internal track** on Google
Play: the **Play Store — internal release** workflow runs the full CI, builds
a release AAB, signs it with the upload key and uploads it to the Play
Console. A manual run works from any branch and can build and sign without
touching the store.

Internal is the right first step on the store: up to 100 testers you name
yourself, no review, and a release reaches a tester's phone within minutes of
the upload. Promotion to the closed, open and production tracks is a later
pipeline — deliberately not this one.

## What the internal track does not need

Answering the obvious questions up front, because guides written for the
older console imply you need all of it before anything can ship:

- **A website.** Never required by Play, on any track.
- **A privacy policy.** Not required while the app lives on the internal
  track. It becomes mandatory together with the Data safety form once the
  app publishes to a closed, open or production track — even for an app
  that collects nothing. A public URL is enough (no PDFs); it does not have
  to be a real website.
- **The Data safety form.** Apps that are exclusively active on the internal
  track are exempt from it.
- **A store listing, screenshots, a content rating.** All of that is for
  the later tracks; an internal test can be started before the app setup in
  the console is completed at all.

One thing that *does* wait for you later: personal developer accounts
created after November 2023 cannot publish to production until a **closed
test with at least 12 testers, opted in continuously for 14 days**, has run
and a production access application has been answered. The internal track
does not count toward it — worth knowing before anyone plans a launch date.

## One-time setup

The pipeline needs an app entry in the Play Console, a service account, four
secrets (five with the optional key password) in a GitHub environment, and one
release uploaded by hand. Nothing here changes the app's architecture: still
no server, still no account, and the key material lives in GitHub's secret
store, not in the repository.

Work in a directory **outside this repository** (say `~/keys`) for everything
below, so no key file can end up in a commit. `.gitignore` catches the usual
names as a second line of defence, not as the first.

### 1. The app in the Play Console

[play.google.com/console](https://play.google.com/console) → **Create app**,
name it, and pick the package name **`com.hundreddays.hundred_days`** — it has
to match the `applicationId` in `app/android/app/build.gradle.kts` exactly.
Listings, screenshots and content ratings can stay empty for the internal
track.

### 2. The upload key

One keystore, generated once, kept forever — Play identifies your uploads by
it, and losing it means a support ticket to Google. Generate it with `keytool`,
which ships with every JDK:

```bash
cd ~/keys
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

One catch learned the hard way: a stock Mac has **no Java**, so a bare
`keytool` fails with *Unable to locate a Java Runtime*. Android Studio ships
its own JDK, so its `keytool` works without installing anything:

```bash
"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" \
  -genkeypair -v \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

`brew install --cask temurin` is the alternative — the same JDK distribution
CI uses — if you want `keytool` on the `PATH` for everything.

keytool asks for **one** password. Its default keystore format (PKCS12) has no
separate key password, so that single password is the store password, and the
`ANDROID_KEY_PASSWORD` secret below can be left out.

Keep a second copy of `upload-keystore.jks` and its password somewhere safe
that is not this machine — a password manager is ideal.

Play App Signing (the store re-signing deliveries with its own key) is on by
default and recommended; the upload key is then only the identity you push
with, exactly what this pipeline uses it for.

### 3. The service account

The Play Console used to have a **Setup → API access** page that created and
linked the service account for you. That page is gone; today the account is
created in the Google Cloud Console and invited into the Play Console like a
user.

**In the Google Cloud Console** ([console.cloud.google.com](https://console.cloud.google.com)):

1. Pick or create a project — if you have created the app entry in the Play
   Console first, the automatically linked project is a fine choice, but any
   project works.
2. **IAM & Admin → Service Accounts → Create service account** — a name
   suffices, roles and access can stay empty.
3. On the new account: **Keys → Add key → Create new key → JSON**. Save the
   download as `~/keys/service-account.json`.
4. **APIs & Services → Enabled APIs** — enable the **Google Play Android
   Developer API** for the project.

**In the Play Console**: leave the app's pages and go to the console home,
then **Users and permissions → Invite new users** in the left navigation, and
paste the service account's email address — it is the `client_email` field
in the JSON key and ends in `.iam.gserviceaccount.com`. Service accounts
become active immediately, without accepting anything by mail.

Give it as little as the upload needs: leave **Account permissions** empty,
and under **App permissions → Add app** pick this app and tick **View app
information (read-only)** and **Release apps to testing tracks**. Admin works
too, but this key sits in CI — if it ever leaks, it should be able to push a
test build of one app, not run the whole developer account.

### 4. The secrets, in an environment

The secrets live in a GitHub **environment** called `play-internal`, not at
repository level: secrets in an environment are readable only by jobs that
name that environment, and in this repository only the release workflow does.
No other workflow can read the upload key or the Play credentials.

On GitHub: **Settings → Environments → New environment** → `play-internal`.
Nothing further: manual runs are allowed from every branch, so the
environment must answer to every branch too — leave its deployment branch
settings alone.

Then, with the GitHub CLI (`gh auth login` once, if you have not), from
`~/keys`:

```bash
R=mikexkllr/100days
gh secret set PLAY_SERVICE_ACCOUNT_JSON --repo $R --env play-internal < service-account.json
gh secret set ANDROID_KEYSTORE_ALIAS    --repo $R --env play-internal -b "upload"

# the password is typed on the next prompt, not on the command line
gh secret set ANDROID_KEYSTORE_PASSWORD --repo $R --env play-internal

base64 -i upload-keystore.jks -o upload-keystore.b64     # macOS
# base64 -w0 upload-keystore.jks > upload-keystore.b64   # Linux
gh secret set ANDROID_KEYSTORE_BASE64   --repo $R --env play-internal < upload-keystore.b64

rm upload-keystore.b64 service-account.json
```

Delete the JSON key once it is a secret: it is a working credential, and the
Cloud Console issues a new one whenever you need it. Set
`ANDROID_KEY_PASSWORD` the same way only if your keystore really has a
separate key password (a JKS store made with `-storetype JKS`); otherwise
leave it out and the store password is used.

If you set any of these as repository secrets earlier, delete them under
**Settings → Secrets and variables → Actions** — repository secrets are
readable from every workflow on every branch.

### 5. A tester list

**Test and release → Testing → Internal testing → Testers** — create a list
with the Google account addresses of the people who should get it. They opt
in once via the track's link, and from then on updates arrive on their own,
like any store update.

### 6. The first release — by hand

Google's publishing API cannot create the first release of an app: for an app
that has never received a bundle it answers *Package not found*, and until
the app's first release has been rolled out it only accepts drafts. So the
first bundle goes through the Play Console by hand — but it is still built
and signed by the pipeline, so the console registers exactly the upload key
CI will keep using.

1. **Merge the pipeline into `main`.** The merge itself starts the first
   run: CI runs, the bundle is built and signed and kept as an artifact —
   and the upload fails with *Package not found*, which is expected for a
   brand-new app and is listed under *When a run fails*. To keep the first
   run green instead, dispatch it by hand with the upload unticked (next
   step).
2. Or instead: **Actions → Play Store — internal release → Run workflow**,
   untick **Upload to the internal track**, run. It runs CI, then builds
   and signs the bundle and stops there.
3. From that run, download the artifact
   **`hundred-days-aab-<version code>`** and unzip it: `app-release.aab`.
4. Play Console → the app → **Test and release → Testing → Internal
   testing → Create new release**. If it asks about app signing, keep
   Google's default (Play App Signing with a Google-generated key). Upload
   `app-release.aab`, keep the generated release name, **Next**, then roll
   it out — the button says *Save and publish* or *Start rollout to Internal
   testing*, depending on the console. If the review page lists tasks that
   block the rollout, finish those first.
5. Check **Test and release → App integrity → Upload key certificate**: its
   SHA-256 fingerprint is the one the run printed in *Decode and open the
   upload keystore*.

From here on the button does the whole job.

## Releasing

**Merge to `main`.** That is all: every push to `main` runs the full CI,
checks that every secret is set and that the keystore opens with the
password and alias, then builds, signs, keeps the AAB as a workflow artifact
and uploads it. A merge and a manual run queue up rather than race.

A **manual run** works from any branch: **Actions → Play Store — internal
release → Run workflow**. Unticking **Upload to the internal track** builds
and signs only — useful for trying the pipeline on a branch without shipping
anything to testers.

**Version codes take care of themselves**: each run ships version code
`1000 + run number`, which only ever goes up, so there is nothing to bump
before merging. The version *name* testers see still comes from `version:`
in `app/pubspec.yaml` — change it when you want them to see a new one. The
`+N` there only applies to local builds.

## When a run fails

The failing step names the problem; the common ones:

- **Not set in the play-internal environment: …** — the named secret is
  missing, misspelt, or set at repository level only; see step 4.
- **not valid base64 / does not open** — re-encode the keystore and set
  `ANDROID_KEYSTORE_BASE64` again, or fix the password or alias secret.
- **Package not found** — Play has never seen a bundle for this app; do the
  first release by hand (step 6).
- **Only releases with status draft may be created on draft app** — the
  hand-made first release exists but has not been rolled out yet.
- **The caller does not have permission** — the service account is not
  invited, lacks the app permissions from step 3, or the Play Android
  Developer API is not enabled in its Cloud project.
- **signed with the wrong key** — the keystore in the secret is not the one
  the console registered; compare the fingerprints as in step 6.
- **Version code … has already been used** — a bundle with a higher code was
  uploaded by hand, or the workflow file was renamed (which restarts run
  numbers). Raise the `1000` offset in the *Pick the version code* step.
- **Changes cannot be sent for review automatically** — Play wants to review
  something in this edit, typically a pending policy declaration. Open
  **Publishing overview** in the Play Console, deal with what is listed
  there, and run again.

## Signing a local build the same way

CI passes the key through environment variables; a local release build can do
the same:

```bash
export HUNDRED_KEYSTORE_PATH="$HOME/keys/upload-keystore.jks"   # absolute
export HUNDRED_KEYSTORE_PASSWORD=…
export HUNDRED_KEY_ALIAS=upload
# HUNDRED_KEY_PASSWORD only for a JKS store with its own key password

cd app && flutter build appbundle --release
```

With none of the variables set, the release build falls back to the debug
key — that is what `flutter run --release` has always done, and it keeps
working. With some set but not all, or with a path that does not exist, the
build stops and names what is missing rather than quietly signing with the
debug key.

## What is deliberately not here

- **Production, closed and open tracks.** Promotion beyond internal is a
  separate pipeline, and a separate decision.
- **Release notes and staged rollout.** The internal track does not need
  them; a production pipeline would.
- **Triggers beyond main.** Only a push to `main` and a manual run release.
  No tag, no schedule, and no push to any other branch ships anything.
