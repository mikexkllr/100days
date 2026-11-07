# 100 Days — and far beyond

An open challenge app for iOS and Android. You set a goal up front, get a
training plan, a nutrition plan or simply a daily streak out of it — and your
friends see every day whether you showed up.

No account. No server. No cloud. Your data lives on your device and goes
directly to the people you connected yourself.

The interface ships in **English and German** and follows your device language.

---

## Why this works differently

**The streak is provable.** Every check-in is a signed entry in a hash-chained
log. Your friends compute your streak from *your signed entries* — you do not
claim a number, you prove it. A workout spliced in after the fact breaks the
chain, and a day logged late is visibly marked as backfilled in the feed.

**The pressure comes from real people — and only from them.** Not "3 users
were active today", but: Marcel was at the gym, he is on a 47-day streak, and
you are still on zero. Weekly league with promotion and relegation, nudges,
cheers. The Duolingo mechanic, except the pool is your own friends — losing to
a stranger costs nothing, losing to your flatmate does. Strangers get nothing:
every sync proves who is on the other end, and only people you accepted are
served. What friends see is up to you, habit by habit; body stats, calorie
targets and the food diary never leave the phone in readable form.

**It does not stop at day 100.** Day 100 closes a cycle. After that you ascend
a tier, the streak keeps counting, and the targets get harder.

**Nobody is watching.** There is no server that knows about your relapses,
because there is no server at all. The coach runs on the device.

**Showing up feels like winning.** Your streak is Funki, a flame with a face
that grows through ten forms — from a red ember to a holographic galaxy — and
goes hungry, worried or proud with your day. You check in by holding until the
bar ignites, and a clock runs to midnight while today is open.
Finishing the day rolls a slot machine: streak, XP and bonus reels, and a
jackpot when something rare really happened — a milestone, a level-up, a new
form, a record. Every reel lands on a real number; only the size of the
moment varies. More: [`docs/design.md`](docs/design.md).

**It is on your home screen.** A widget with Funki, the streak, the countdown
and the week, which turns over at midnight and turns worried in the evening
without the app having to run. [`docs/home-screen-widget.md`](docs/home-screen-widget.md).

## What you can track

🏋️ Training · 🏃 Cardio · 🥗 Nutrition · 🚱 No alcohol · 🍬 No sugar ·
🧠 Dopamine detox · 🛡️ NoFap · 🚭 No nicotine · 📚 Reading · 🧘 Meditation ·
🧊 Cold showers · 😴 Sleep · 💧 Water · ✍️ Journaling · ⭐ Your own

Habits are either **build** (do something) or **abstain** (avoid something),
and that changes how they are counted: a forgotten tap does not kill an
abstinence streak, but an admitted relapse does.

## What the app generates

| Goal | What comes out of it |
| --- | --- |
| Build muscle / lose fat / get fit | Optional training plan: pick your split (full body, upper/lower, PPL, PPL + upper/lower, body-part), get proposed exercises, swap or edit any of them, log every set — the logger shows last time's numbers and what to beat today. Optional nutrition plan: a calorie target from Mifflin-St Jeor or your own, macro presets, and a food diary |
| Discipline / clarity / staying clean | A daily streak with a milestone track: what happens in your body and your head on day 3, 14, 30, 90 |

Both plans are **optional** — without them the habit is a plain tick. With
them a logged workout or a diary day closed on target is a *tracked* check-in,
worth **+50 % XP**.

The plans are computed **deterministically on the device**. Same inputs, same
plan — auditable rather than a black box, and it works in a basement gym with
no signal.

## The food diary

One number up top — what is left today — then breakfast, lunch, dinner and
snacks, each with its own add button and meal ideas that fit what is left.
The ideas are only ideas; nothing lands in the diary unless you put it there.
Four ways in:

- **Search** a built-in table of ~125 common foods (German and English names,
  plurals, synonyms), or re-log something recent.
- **Describe** it: "2 Eier, eine Scheibe Vollkornbrot und ein Cappuccino" is
  parsed against the table; with the on-device model, dishes it does not know
  are estimated too.
- **Barcode**: scan it or type the EAN; the label values come from Open Food
  Facts. Only the number is sent.
- **Manual**: name and calories, macros if you have them.

## The coach on your device

Two implementations behind one interface:

- **Rule-based** (always on): picks its tone from your state — fresh start,
  social pressure, "the day is nearly over", milestone, relapse. Needs no
  model, answers instantly, works offline.
- **Local language model** (optional): onboarding detects your phone and its
  memory, proposes the model that fits — Qwen3.5 2B, Gemma 4 E2B or E4B —
  and offers every smaller one right next to it, down to Qwen3.5 0.8B; one
  tap downloads. Each was run for real before it went into the list. It runs through llama.cpp on
  the phone; the prompt never leaves it. It also estimates meals you describe
  and proposes nutrition targets. On any failure — too slow, unusable output —
  it falls back silently to the rule-based coach.

The download is pinned to a fixed revision and checked against its SHA-256
before it is used. Details: [`docs/local-ai.md`](docs/local-ai.md).

## How the network works

Your identity is an Ed25519 key pair addressed as a W3C
[`did:key`](https://w3c-ccg.github.io/did-method-key/). You add friends by QR
code or link — there is no registry to look anyone up in. The person whose
code you scanned sees you as a friend request; nothing is shared until they
accept.

Replication is gossip: two devices exchange the heads of their feeds, ask for
what they are missing, and hang up. No client, no server, no session anyone has
to keep open. The bundled transport finds friends on the same Wi-Fi (UDP beacon
plus TCP); further transports plug in behind the same interface. Protocol:
[`docs/protocol.md`](docs/protocol.md).

## Getting started

```bash
flutter --version        # 3.38 or newer
cd app
flutter pub get
flutter run
```

A ready-made APK to try: the latest green CI run → **Actions → CI →
android-build** → artifact `hundred-days-apk`. In detail, including iPhone:
[`docs/testing-on-device.md`](docs/testing-on-device.md).

Analysis and tests for both packages:

```bash
cd packages/hundred_core && dart pub get && dart analyze && dart test
cd ../../app             && flutter pub get && flutter analyze && flutter test
```

## Layout

```
packages/hundred_core/   Pure Dart: identity, signed feed, domain, plan
                         generator, coach, sync protocol
app/                     Flutter: UI, SQLite, keystore, transports,
                         notifications, translations
```

The core knows nothing about Flutter, the network, the filesystem — or the
display language. Everything that has to be *correct* — chain validation,
streak arithmetic, calorie maths, sync rounds — is therefore testable without a
device, and the same rules drive a German and an English user.
More on this: [`docs/architecture.md`](docs/architecture.md).

## Status

Working: onboarding, check-ins, streaks, Funki and the flame evolution, the
day-complete slot machine, the home screen widget on Android, editable
training plans with set-by-set logging, nutrition targets and a food diary,
privacy settings, the on-device model with download, coach, feed, league,
nudges, invites and friend requests, LAN sync, local notifications, recovery
key, English and German, and a manual pipeline that ships a signed AAB to the
Google Play internal track.

What is still missing is listed honestly in [`docs/roadmap.md`](docs/roadmap.md)
— among other things a relay transport for friends outside your Wi-Fi, an
optional global league, and background sync on iOS.

## Licence

MIT — see [`LICENSE`](LICENSE).
