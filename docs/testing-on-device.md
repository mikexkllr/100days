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
would need your own upload key.

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

The interesting part of the app needs two devices on the **same Wi-Fi**:

1. Run through onboarding on both devices.
2. On device A: **Friends → Invite**, show the QR code.
3. On device B: **Friends → Scan**, scan it.
4. Tick something off on both devices.
5. Pull to refresh — the other person's entries appear in the feed with a
   **VERIFIED** badge, and the league fills up.

Without a second device everything works except the social part: setting a
goal, getting a plan, checking in, streaks, statistics, the coach.

With no model installed the coach runs rule-based — that is the normal case,
not a fault. See [`local-ai.md`](local-ai.md).

## When something goes wrong

**"App not installed"** — usually the wrong ABI. Take `arm64-v8a`. Or an older
version with a different signing key is still on the device: uninstall it
first.

**Friends do not find each other** — are both devices on the same Wi-Fi? Guest
networks and many corporate networks block multicast between clients. As a
fallback use the invite *link* instead of the QR code: it contains the IP
address.

**No notifications** — Android 13+ asks on first launch; if you declined, the
only fix is system settings → Apps → 100 Days → Notifications.
