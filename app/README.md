# hundred_days

The Flutter app: everything that touches the platform — UI, the local cache
and the sync with the backend, sign-in, AI clients, purchases, notifications,
the camera — plus the translations.

The rules live next door in [`../packages/hundred_core`](../packages/hundred_core):
the feed fold, streak arithmetic, the plan generators, meal plans and shopping
lists, the coach and the checks on AI answers, all in pure Dart with no
display language of their own. The backend is in [`../supabase`](../supabase).

```bash
flutter pub get
flutter run              # a connected device or emulator, the project's backend
flutter run --dart-define-from-file=config/my-backend.json   # your own
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
[`../docs/`](../docs) for architecture, the backend, the AI, self-hosting,
localization and how to run it on a phone.
