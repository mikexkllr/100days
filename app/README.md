# hundred_days

The Flutter app: everything that touches the platform — UI, SQLite, the
keystore, sockets, notifications, the camera — plus the translations.

The rules live next door in [`../packages/hundred_core`](../packages/hundred_core):
identity, the signed feed, streak arithmetic, the plan generator, the coach and
the sync protocol, all in pure Dart with no display language of their own.

```bash
flutter pub get
flutter run              # a connected device or emulator
flutter analyze --fatal-infos
flutter test
```

After editing `lib/l10n/*.arb`, regenerate the bindings:

```bash
flutter gen-l10n
```

The generated output under `lib/l10n/generated/` is committed so CI can prove it
is in sync with the ARB files.

See the [repository README](../README.md) for what the app is, and
[`../docs/`](../docs) for architecture, protocol, localization and how to run it
on a phone.
