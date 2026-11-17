# Contributing

## Setup

```bash
cd packages/hundred_core && dart pub get
cd ../../app             && flutter pub get
```

Flutter 3.44 or newer (CI uses the current stable). For the backend:
the [Supabase CLI](https://supabase.com/docs/guides/cli) and
[Deno](https://deno.com) 2.

## Before every commit

```bash
cd packages/hundred_core && dart analyze && dart test
cd ../../app             && flutter analyze && flutter test
cd ..                    && deno test --allow-env supabase/functions && deno lint supabase
```

All must come back clean; CI runs them. A change to a migration or a policy
also runs the RLS tests against a development database:

```bash
DATABASE_URL=postgresql://… deno test -A supabase/tests/rls_test.ts
```

## Where code belongs

**In `hundred_core`** if it needs no Flutter, no network and no filesystem:
domain logic, calculations, validation rules, the checks on what a language
model answers. That boundary is
the reason the parts that have to be correct can be tested at all. If you find
yourself needing `import 'package:flutter/…'` in there, the code is in the
wrong place or an interface is missing.

**In `app`** if it touches the platform: UI, SQLite, the network and the
backend client, the keychain, notifications, the camera, purchases.

**In `supabase/`** if the server must enforce it: who may read and write
what (policies), what a client may not be trusted with (the AI key, the
premium tier, contact hashes). A new table gets RLS, explicit grants and a
case in `supabase/tests/rls_test.ts`; a secret goes into `.env.example` and
`docs/self-hosting.md`, never into the repository.

New platform capabilities arrive as a port in the core and an adapter in the
app — the way `FeedStore` and `LlmClient` did.

## What we expect from changes

- **New event types** go into `FeedEventType.all`. Older apps skip types
  they do not know, so a new type must never be needed to read an old one.
  Events are forever: a feed written today has to fold the same in two years.
- **Migrations only move forward.** A pushed migration is never edited; a
  change is a new one.
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
