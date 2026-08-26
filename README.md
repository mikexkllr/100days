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

**The pressure comes from real people.** Not "3 users were active today", but:
Marcel was at the gym, he is on a 47-day streak, and you are still on zero.
Weekly league with promotion and relegation, nudges, cheers. The Duolingo
mechanic, except the pool is your own friends — losing to a stranger costs
nothing, losing to your flatmate does.

**It does not stop at day 100.** Day 100 closes a cycle. After that you ascend
a tier, the streak keeps counting, and the targets get harder.

**Nobody is watching.** There is no server that knows about your relapses,
because there is no server at all. The coach runs on the device.

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
| Build muscle / lose fat / get fit | A training plan with a split chosen by training days, mesocycles of three build weeks plus a deload, RPE instead of guessed weights — and calorie and macro targets from Mifflin-St Jeor |
| Discipline / clarity / staying clean | A daily streak with a milestone track: what happens in your body and your head on day 3, 14, 30, 90 |

Both are computed **deterministically on the device**. Same inputs, same plan —
auditable rather than a black box, and it works in a basement gym with no
signal.

## The coach on your device

Two implementations behind one interface:

- **Rule-based** (always on): picks its tone from your state — fresh start,
  social pressure, "the day is nearly over", milestone, relapse. Needs no
  model, answers instantly, works offline.
- **Local language model** (optional): a GGUF model you put in the model folder
  yourself. The prompt never leaves the device. On any failure — no model, too
  slow, unusable output — it falls back silently to the rule-based coach.

The app never downloads a model on its own. A gigabyte over mobile data is not
something that should happen unasked. Details:
[`docs/local-ai.md`](docs/local-ai.md).

## How the network works

Your identity is an Ed25519 key pair addressed as a W3C
[`did:key`](https://w3c-ccg.github.io/did-method-key/). You add friends by QR
code or link — there is no registry to look anyone up in.

Replication is gossip: two devices exchange the heads of their feeds, ask for
what they are missing, and hang up. No client, no server, no session anyone has
to keep open. The bundled transport finds friends on the same Wi-Fi (UDP beacon
plus TCP); further transports plug in behind the same interface. Protocol:
[`docs/protocol.md`](docs/protocol.md).

## Getting started

```bash
flutter --version        # 3.27 or newer
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

Working: onboarding, check-ins, streaks, plans, coach, feed, league, nudges,
invites, LAN sync, local notifications, recovery key, English and German.

What is still missing is listed honestly in [`docs/roadmap.md`](docs/roadmap.md)
— among other things a real inference engine behind the model port, a relay
transport for friends outside your Wi-Fi, and background sync on iOS.

## Licence

MIT — see [`LICENSE`](LICENSE).
