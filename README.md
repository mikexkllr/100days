# 100 Days — and far beyond

An open challenge app for iOS and Android. You set a goal up front, get a
training plan, a nutrition plan or simply a daily streak out of it — and your
friends see every day whether you showed up. Photograph a meal and get it
estimated; plan the week's meals and the shopping list together with the
people you live with.

Open source, end to end: the app and the backend. It runs on the project's
own server by default, and on yours if you like
([`docs/self-hosting.md`](docs/self-hosting.md)).

The interface ships in **English and German** and follows your device language.

---

## Why this works differently

**The streak is computed, not claimed.** Every check-in is an entry in your
own append-only feed: nobody — you included — can edit or delete one after
the fact. Your friends' phones compute your streak from *your entries*; you
do not send a number. The server stamps when an entry arrived, so a day
logged late is visibly marked as backfilled.

**The pressure comes from real people — and only from them.** Not "3 users
were active today", but: Marcel was at the gym, he is on a 47-day streak, and
you are still on zero. Find friends by name, username or in your
address book; nudges and cheers arrive as pushes; a streak you keep together
with each friend, a weekly quest you can only finish together. Weekly
leagues with promotion and relegation — a public one with divisions, and the
one that bites: among your friends, where losing to your flatmate is a
conversation at breakfast. What friends see is up to you, habit by habit;
body stats, calorie targets and the food diary are private, and the server
hands them to nobody but you.

**It does not stop at day 100.** Day 100 closes a cycle. After that you ascend
a tier, the streak keeps counting, and the targets get harder.

**Nothing is for sale.** No ads, no tracking, no data brokers. The server
keeps what the app needs and Row Level Security decides who reads it —
tested against a real database
([`docs/backend.md`](docs/backend.md)). The code is open: check it instead
of believing it, or run your own.

**Showing up feels like winning.** Your streak is Funki, a flame with a face
that grows through ten forms — from a red ember to a holographic galaxy — and
goes hungry, worried or proud with your day. You check in by holding a habit
until it ignites, and a clock runs to midnight while today is open. The night
sky behind the app is yours: a star for every day you finished, an aurora that
rises as today gets done, and everything lit burns in the colour of your
flame — so day 50 does not look like day 5.
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

The training and calorie plans are computed **deterministically on the
device**. Same inputs, same plan — auditable rather than a black box, and it
works in a basement gym with no signal: everything you log waits on the phone
until there is a connection again.

## Meals and shopping, together

Everyone has a household — alone, as a couple, as a flat. Its members share
one **week of meals** and one **shopping list**, live on every phone.

- **Plan the week** with the AI: pick days, meals, cooking time, type a wish
  ("no fish, Wednesday something quick"), get a draft, keep what you like.
  Portions are sized to each person's calorie target — for those who share
  it with the household; everything else stays private.
- **The planning chat** changes plan and list as you talk to it ("we still
  have rice") — every change shows up with an undo.
- **A list from the plan** for the days until your next trip, added up and
  sorted by aisle. Shop weekly on your day, every few days, or whenever; add
  an extra list between trips; what you did not get moves to the next one.
- **Eaten as planned**: one tap puts your own portion into your diary.

Invite your partner or flatmates with a QR code, a link or a code.

## The food diary

One number up top — what is left today — then breakfast, lunch, dinner and
snacks, each with its own add button and meal ideas that fit what is left.
The ideas are only ideas; nothing lands in the diary unless you put it there.
Five ways in:

- **Search** a built-in table of ~125 common foods (German and English names,
  plurals, synonyms), or re-log something recent.
- **Photo**: take a picture of your plate; the AI estimates foods and amounts
  and you confirm them. The photo is scaled down and stripped of location
  and camera data on the phone, sent once, and not stored.
- **Describe** it: "2 Eier, eine Scheibe Vollkornbrot und ein Cappuccino" is
  parsed against the table; dishes it does not know are estimated by the AI.
- **Barcode**: scan it or type the EAN; the label values come from Open Food
  Facts. Only the number is sent.
- **Manual**: name and calories, macros if you have them.

## AI, free and premium

All AI runs through [dartantic_ai](https://pub.dev/packages/dartantic_ai):

- through the project's **gateway** — an edge function that holds the API
  key and counts a small monthly allowance per account (enough for photos
  now and then and a meal plan). **Premium** lifts it for everyday use and
  lets the AI write the coach's daily line;
- or with **your own API key** for Google, Anthropic or OpenAI, kept in the
  phone's keychain, going straight to that provider.

Every answer is checked before it counts — a meal estimate that breaks
physics or a plan whose calories do not match its macros is dropped — and
everything falls back without AI: the coach to its rules (picking its tone
from your state: fresh start, social pressure, "the day is nearly over",
milestone, relapse), the diary to the food table, the planner to your own
hands. What is sent, and when: [`docs/ai.md`](docs/ai.md).

## How it works

Sign in with Apple or Google; nothing else is asked for. Everything you do is
an event in your own feed — written to the phone first, then to the server
(Supabase: Postgres, Auth, Realtime, a few edge functions). Row Level
Security decides who reads what: your friends your shared events, your
household its plan, nobody your private ones. Details:
[`docs/backend.md`](docs/backend.md), [`docs/architecture.md`](docs/architecture.md).

## Getting started

```bash
flutter --version        # 3.44 or newer
cd app
flutter pub get
flutter run              # against the project's backend
flutter run --dart-define-from-file=config/my-backend.json   # or your own
```

A ready-made APK to try: the latest green CI run → **Actions → CI →
android-build** → artifact `hundred-days-apk`. In detail, including iPhone:
[`docs/testing-on-device.md`](docs/testing-on-device.md).

Analysis and tests:

```bash
cd packages/hundred_core && dart pub get && dart analyze && dart test
cd ../../app             && flutter pub get && flutter analyze && flutter test
cd ..                    && deno test --allow-env supabase/functions
```

## Layout

```
packages/hundred_core/   Pure Dart: the feed fold, streaks, XP, leagues,
                         training and nutrition plans, meal plans and
                         shopping lists, the coach, checks on AI answers
app/                     Flutter: UI, the local cache and sync, sign-in,
                         AI clients, purchases, notifications, translations
supabase/                The backend: schema and policies, edge functions,
                         RLS tests
```

The core knows nothing about Flutter, the network, the filesystem — or the
display language. Everything that has to be *correct* — streak arithmetic,
XP, calorie maths, shopping-list sums, what counts as a usable AI answer —
is therefore testable without a device, and the same rules drive a German
and an English user.
More on this: [`docs/architecture.md`](docs/architecture.md).

## Status

Working: sign-in with Apple and Google, onboarding, check-ins, streaks, Funki
and the flame evolution, the day-complete slot machine, the home screen
widget on Android, editable training plans with set-by-set logging,
nutrition targets and a food diary with photo, description, barcode and
manual entry, households with a shared meal plan and shopping list, the AI
planner and planning chat, free and premium AI or one's own key, friends by
invite, search and address book, friend streaks and quests, a public league
with divisions and one among friends, nudges and cheers, sync through the
backend with an offline outbox, English and German, and a manual pipeline
that ships a signed AAB to the Google Play internal track.

Needs setting up outside the code before it works for real — OAuth clients,
the AI key, store products, Firebase: [`docs/self-hosting.md`](docs/self-hosting.md).
What is still missing: [`docs/roadmap.md`](docs/roadmap.md).

## Licence

MIT — see [`LICENSE`](LICENSE).
