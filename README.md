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
address book — and block or report anyone who should not find you; nudges and cheers arrive as pushes; a streak you keep together
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
abstinence streak, but an admitted relapse does — that habit's, and no
other. How strict the overall streak is, is yours to pick: **gentle**,
**balanced** or **strict** (a change applies from tomorrow).

Habits can be added, changed and taken out while the challenge runs: a new
target or frequency applies from a day on, and the days before keep counting
by the rules they were counted with. A tick in the wrong row can be taken
back, a day done but not ticked can be logged late the day after (marked as
late for friends), and the reminders come when you want them.

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

- **Plan the week** with the AI: pick days, meals, cooking time and how
  much you make yourself, type a wish ("no fish, Wednesday something
  quick"), get a draft, keep what you like. Portions are sized to each
  person's calorie target — for those who share it with the household;
  everything else stays private.
- **Three ways to cook the same dinner**: *convenient* (a ready-to-cook
  fillet, beans from a can), *everyday*, or *from scratch* (a side of wild
  salmon, dried beans soaked overnight). Everyone has their own default;
  it is picked wherever a plan or a recipe is written.
- **A recipe for every meal**: every ingredient — the oil, the salt and the
  spices too — and steps to cook from. A meal that is only a name gets its
  recipe written on a tap, and any recipe can be written again at another
  level.
- **Funki**, the coach, changes plan, recipes and list as you talk to him
  ("plan the week from scratch", "we still have rice", "500 g of mince as
  well") — every change shows up with an undo. He also reads and fills the
  diary, checks off habits and rebuilds your training plan ("swap the
  squats", "one day more"); he is one tap away on every screen, and his
  reminders sound like him.
- **By hand**: "pizza on Friday", or one of the app's meal ideas in a tap —
  ranked against your own target for that meal if you have one.
- **A list from the recipes** for the days until your next trip, added up
  and sorted by aisle. Kitchen basics — oil, salt, spices — stand at the
  end without an amount, to check at home; what you always have stays off
  it; and a planned meal without a recipe is named rather than silently
  missing. Shop weekly on your day, every few days, or whenever; add an
  extra list between trips; what you did not get moves to the next one.
- **Eaten as planned**: the planned meal waits in your diary; one tap puts
  your own portion in.

Planning and checking in are kept apart: **Plan** holds what lies ahead —
the training plan, the week of meals under your daily target, the shopping
list. **Today** holds what happened — the habits, today's workout and the
food diary.

Invite your partner or flatmates with a QR code, a link or a code.

## The food diary

It lives under Today, because it is how a nutrition day is checked in: one
number up top — what is left today — then breakfast, lunch, dinner and
snacks, each with its own add button, and next to each whatever the
household planned for it. Nothing lands in the diary unless you put it
there; closing the day on target makes it a tracked check-in.
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

Sign in with Apple, Google, or e-mail and a password; nothing else is asked
for. Everything you do is an event in your own feed — written to the phone
first, then to the server (Supabase: Postgres, Auth, Realtime, a few edge
functions). Row Level Security decides who reads what: your friends your
shared events, your household its plan, nobody your private ones. Details:
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

Working: sign-in with Apple, Google and e-mail (with password reset),
onboarding, check-ins with undo and late logging, editable habits, streaks, Funki
and the flame evolution, the day-complete slot machine, the home screen
widget on Android, editable training plans with set-by-set logging,
nutrition targets and a food diary with photo, description, barcode and
manual entry, households with a shared meal plan, recipes at three cooking
levels and a shopping list that knows the kitchen basics, the AI
planner and Funki, the coach with tools on everything, free and premium AI or one's own key, friends by
invite, search and address book, blocking and reporting, friend streaks and
quests, a public league with divisions and one among friends, nudges and
cheers, adjustable reminders, sounds, sync through the
backend with an offline outbox, English and German, and release pipelines:
`dev` goes to Google Play internal testing and TestFlight, `main` to Play
closed testing and the App Store version, with the store listings, the
website (`site/`) and the demo build for screenshots in the repository —
[`docs/stores.md`](docs/stores.md).

For your own backend — OAuth clients, the AI key, store products, Firebase:
[`docs/self-hosting.md`](docs/self-hosting.md).
What is still missing: [`docs/roadmap.md`](docs/roadmap.md).

## Licence

MIT — see [`LICENSE`](LICENSE).
