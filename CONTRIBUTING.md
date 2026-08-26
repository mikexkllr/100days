# Contributing

## Setup

```bash
cd packages/hundred_core && dart pub get
cd ../../app             && flutter pub get
```

Flutter 3.27 or newer, Dart 3.6 or newer.

## Before every commit

```bash
cd packages/hundred_core && dart analyze && dart test
cd ../../app             && flutter analyze && flutter test
```

Both must come back clean. CI runs exactly these four commands.

## Where code belongs

**In `hundred_core`** if it needs no Flutter, no network and no filesystem:
domain logic, calculations, the protocol, validation rules. That boundary is
the reason the parts that have to be correct can be tested at all. If you find
yourself needing `import 'package:flutter/…'` in there, the code is in the
wrong place or an interface is missing.

**In `app`** if it touches the platform: UI, SQLite, the keystore, sockets,
notifications, the camera.

New platform capabilities arrive as a port in the core and an adapter in the
app — the way `FeedStore`, `PeerTransport` and `LocalLlmRuntime` did.

## What we expect from changes

- **New event types** must be added to `FeedEventType.all`, or every peer
  rejects them as `unknownType`. Events are forever: a feed written today has
  to still verify in two years.
- **Changes to the canonical format** break every existing signature. If it
  cannot be avoided, it needs a protocol version.
- **Rules about streaks, XP or plans** need a test. Not on principle — because
  a mistake there only shows up weeks later, by which point the history is
  already wrong.
- **No dark patterns.** The app is allowed to be uncomfortable; it is not
  allowed to deceive. No invented friend activity, no made-up numbers, no
  artificial scarcity that is not real.
- **No display text in the core.** New content goes into `hundred_core` as an
  identifier and into the ARB files as a translation.

## Language

Code, comments and commit messages are **English**. No exceptions. That
includes this documentation.

Display text lives exclusively in `app/lib/l10n/*.arb`, in English and German.
A German string in Dart code is a bug; a German string in `hundred_core` is an
architectural one — that package must not know about display language.

The tone in the product: second person, direct, no schmaltz. German uses the
informal *du*.

If you add a string, add it in **both** languages.
`flutter test test/l10n_test.dart` enforces that.
Details: [`docs/localization.md`](docs/localization.md).
