# Testing on a phone

## Android — the fast way

Every push builds installable APKs in CI.

1. Open the latest green run under **Actions → CI → android-build**.
2. Download the **`hundred-days-apk`** artifact at the bottom (a ZIP).
3. Unzip it. For essentially every phone since 2017 the right file is
   **`app-arm64-v8a-release.apk`** (`armeabi-v7a` only for very old devices,
   `x86_64` for emulators).
4. Get the file onto the phone — cable, Drive, send it to yourself, whatever.
5. Tap it. Android asks for permission to install from this source; allow it,
   install.

Requires **Android 7.0 or newer** (minSdk 24).

The APK is signed with the debug key. That is fine for testing — the Play Store
needs your own upload key, and shipping to the store is a separate manual
pipeline: [`play-release.md`](play-release.md).

**Pick one channel per phone.** The CI APK and the Play internal build are
signed with different keys, so Android will not install one over the other:
switching means uninstalling first. Nothing is lost: streaks, check-ins and
plans are in the account and come back after signing in again — only what
was logged offline and not yet sent stays on the old install.

## Android — building it yourself

```bash
# One-off: install the Flutter SDK and Android Studio, then
flutter doctor          # "Android toolchain" must be green

cd app
flutter pub get

# Plug the phone in over USB, enable USB debugging in developer options
flutter devices         # your phone must be listed
flutter run --release   # builds, installs and starts
```

`flutter run` without `--release` gives you hot reload — handy while working on
the code, noticeably slower to use.

Just the file, with no device attached:

```bash
flutter build apk --release --split-per-abi
# → app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## iPhone

There is no way around a **Mac with Xcode** — Apple only allows signing iOS
apps there. A free Apple account is enough; the app then runs for seven days
and has to be reinstalled after that.

```bash
cd app
flutter pub get
cd ios && pod install && cd ..

open ios/Runner.xcworkspace
```

In Xcode: set **Runner → Signing & Capabilities → Team** to your Apple ID and
change the bundle id to something unique (for example
`com.yourname.hundreddays`) — `com.hundreddays.hundred_days` may already be
taken.

Then plug in the iPhone and:

```bash
flutter devices
flutter run --release
```

On first launch the iPhone reports an untrusted developer.
**Settings → General → VPN & Device Management → your Apple ID → Trust.**

Without a Mac the only option is TestFlight, and that needs the Apple Developer
Program ($99/year) plus somebody with a Mac to upload the build.

## Switching language

The app follows the device language. To see the other one without changing your
phone's settings, use **Settings → Language** in the app: System / Deutsch /
English.

## What to test with two people

The interesting part of the app needs two accounts — two phones, anywhere:

1. Sign in and run through onboarding on both.
2. On phone A: **Friends → Find friends → Invite**, show the QR code or send
   the link.
3. On phone B: **Friends → Scan** (or open the link, or enter the code).
4. Tick something off on both — the other person's entry appears within
   seconds, and the league fills up.
5. **Plan → Meals → household bar → invite**, join on phone B, make a list
   from the plan and tick things off on both phones.

Without a second account everything works except the social part.

Sign-in needs the OAuth clients of the backend the build points at; the
project's hosted instance has them, your own needs them set up
([`self-hosting.md`](self-hosting.md#4-sign-in)). Without AI allowance or an
own key, the coach runs rule-based and plans are made by hand — that is a
normal state, not a fault ([`ai.md`](ai.md)).

## When something goes wrong

**"App not installed"** — usually the wrong ABI. Take `arm64-v8a`. Or a
version with a different signing key is still on the device — typically the
Play internal build when sideloading the CI APK, or the other way round:
uninstall it first; your data is in your account and comes back on sign-in.

**A friend's entries do not show up** — pull to refresh, or check
**Settings → Sync now**: "Offline" means the phone has no connection to the
backend; everything logged meanwhile is kept and sent later.

**Sign-in fails** — the build's backend has no OAuth client for this app id
or signing key (Google needs the SHA-1 of the exact key the APK is signed
with, debug included).

**No notifications** — Android 13+ asks on first launch; if you declined, the
only fix is system settings → Apps → 100 Days → Notifications.
