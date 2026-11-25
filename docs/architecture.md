# Architecture

## Three parts, two boundaries

```
packages/hundred_core/     pure Dart — no Flutter, network or filesystem
                           dependency, and no display language
app/                       Flutter — UI, the local cache and sync, sign-in,
                           AI clients, purchases, platform
supabase/                  the backend — schema, policies, edge functions
```

The first boundary is not a matter of taste. Everything that has to be
*correct* — streak arithmetic, XP, the calorie formula, shopping-list sums,
what counts as a usable answer from a language model — lives in the core and
is testable without an emulator, a camera or a network. The core has about
200 tests that run in seconds.

The second boundary is the server's: who may read and write what is decided
by Row Level Security in Postgres, not by the app, and tested against a real
database ([`backend.md`](backend.md)).

The core also knows nothing about display language. It hands out identifiers
(`HabitCategory.noSugar`, an `exerciseId`, a `CoachTemplate`, a
`ShopCategory`) and the app turns them into sentences. See
[`localization.md`](localization.md).

## The feed is the only truth

There is no state "beside" the log. Every action — setting a profile, starting
a challenge, a check-in, a relapse, a streak freeze, a nudge, an ascent, a
logged meal — becomes an event in your own feed. Everything on screen is a
fold over those events (`projectUser`).

That has two practical consequences:

1. **Someone else's streak is computed, not claimed.** Your device folds your
   friend's events itself. There is no number to send.
2. **History cannot be rewritten.** The `events` table is append-only for
   everyone; a correction is a new event.

```
FeedEvent { id, author, timestamp, type, payload, visibility,
            createdAt, serverSeq }
             │    │        │                         │          │
             │    │        │                         │          └ pull cursor
             │    │        │                         └ when the server got it
             │    │        └ when the phone says it happened
             │    └ the account; the server checks author = auth.uid()
             └ generated on the phone: an offline event keeps its identity
```

Events fold by the phone's time, then id. `FeedWriter` keeps one device's
timestamps strictly increasing, so two events written in the same instant
(a challenge's public view and its private twin) fold in the order they were
written, on every device. Meal plans and shopping lists are the exception to
the log: they are edited by several people at once, so they are ordinary
rows ([`backend.md`](backend.md#households)).

## Layers

```
   UI (Flutter)
      │  reads AppSnapshot, calls AppController
   ▼
   AppController (Riverpod AsyncNotifier)
      │  debounced re-projection on every feed event
   ▼
   AppRepository ──── FeedWriter ──► FeedStore (SQLite: cache + outbox)
      │                                  ▲
      │                                  │
      │                            SupabaseFeedSync ◄──► events (Postgres, RLS)
      ▼                                                  + realtime
   projectUser()
```

**Why re-projection is debounced:** a pull can land two hundred events at
once. Re-projecting per event would make the UI stutter; a 120 ms window is
enough.

**Why the phone keeps a cache:** a check-in in a basement gym has to work.
Events are written to SQLite first and wait there (pending) until the sync
has sent them; the server's copy then replaces the pending one.

## Ports and adapters

The core defines interfaces, the app supplies the implementations:

| Port (core) | Adapter (app) | Test double |
| --- | --- | --- |
| `FeedStore` | `SqliteFeedStore` | `MemoryFeedStore` |
| `LlmClient` | `DartanticLlmClient` (gateway or own key) | fakes in tests |
| `CoachPromptBuilder` | `LocalizedCoachPrompts` | `EnglishCoachPrompts` |
| `NutritionPromptBuilder` | `LocalizedNutritionPrompts` | `EnglishNutritionPrompts` |
| `MealPlanPromptBuilder` | `LocalizedMealPlanPrompts` | `EnglishMealPlanPrompts` |
| `FoodLookup` / `FoodVocabulary` | `FoodIndex`, `foodVocabularyFor` | English fixture |
| `CoachEngine` | — | `HeuristicCoach` is itself the fallback layer |

And the app has its own seams to the backend, each with an in-memory
version for widget tests: `FeedSync` (`SupabaseFeedSync` / `OfflineFeedSync`),
`SocialBackend` (`SupabaseSocialBackend` / `MemorySocialBackend`),
`HouseholdBackend` (`SupabaseHouseholdBackend` / `MemoryHouseholdBackend`).

## Time

Streaks are keyed to *local calendar days*, not to instants. A check-in at
23:59 and one at 00:01 are two days even though they are two minutes apart —
which is exactly what a streak means to a person. That is what `DayKey` is for;
`DateTime` only appears at the edges.

Events carry two times: the claimed day (`payload.day`) and the moment of
writing (`timestamp`). When they differ it was a backfill, and the feed says so.
A check-in also carries the writer's UTC offset (`payload.tz`): whether it was
logged on its day is judged by the writer's clock, and a friend's streak is
folded with the friend's today (`authorTodayOf`) — a friend eight hours
behind still has the evening that is already tomorrow here.

The fold never trusts a payload: an event it cannot read — written by a newer
app version, or malformed — is skipped, not fatal. A second plain
`challenge.started` keeps the running challenge's start day and cycle; only a
start marked `restart` begins at day one again.

## Streak rules

- **A relapse costs only its own habit.** It resets that habit's streak and no
  other: failing at sugar does not undo a month in the gym.
- **Three streak modes** decide what a day that is not fully done does to the
  challenge-wide streak (`StreakMode`). A day either *counts* (+1), *holds*
  (survives, +0) or *breaks* the streak:

  | | All done | A relapse, rest done | A habit left undone | Nothing done |
  | --- | --- | --- | --- | --- |
  | Gentle | counts | holds | holds | breaks |
  | Balanced (default) | counts | counts | breaks | breaks |
  | Strict | counts | holds | breaks | breaks |

  A day on which every habit was relapsed counts as nothing done. A mode
  change applies from the day it is made; earlier days keep the mode they
  were counted in (`Challenge.streakModeHistory`), so going gentle cannot
  bring a broken streak back. The public view of the challenge carries the
  mode, so friends' phones count by the same rules.
- **Rest days break nothing.** Someone training four days a week is not
  punished for Wednesdays. `kWeekdaySpread` fixes which weekdays are occupied
  for N days per week — deterministically, so every device computes the same
  answer.
- **Today stays open until midnight.** An unfinished current day does not break
  the streak, it marks it at risk.
- **Abstinence counts differently.** A forgotten tap does not reset an
  abstinence streak — only an admitted relapse does. Otherwise people quit, and
  that is the worse failure mode.
- **Streak freezes are scarce** (three per cycle, counted per cycle) and hold
  the streak without counting as a completed day. If a missed day were free,
  the whole point of the app would collapse. A frozen today is not at risk.
- **Corrections are events.** An undo is a check-in marked `undo` that takes
  the entry back out of the day; the timeline shows neither.
- **Editing a running challenge never rewrites the past.** A habit's target
  and weekly frequency keep their history (`targetOn`, `daysPerWeekOn`), a
  habit taken out keeps counting for the days before (`activeUntil`), and a
  new one counts from the day it was added (`activeFrom`).

## Private data in the same feed

Body stats, nutrition targets, the food diary and habits the user keeps to
themselves go into the same feed as everything else, with visibility
`private`: the server hands them to nobody but their author. A challenge is
published twice — the public view (no body stats, no targets, no private
habits, the goal sentence only if shared) and the full one, private. A
friend's device computes the streak from the public view: the shared habits
only, which is the honest number to show them. A habit that was private and
is shared later carries a `sharedSince` day in the public view, so its
private past does not look like misses.

## XP, levels, league

XP per check-in scales with the share of the target reached, difficulty
(1–5 from the catalogue), streak length
(up to 2× at 50 days), a ×1.5 bonus for **tracked** check-ins — a workout
logged set by set, a diary day closed on target — and a bonus for logging on
the day itself. On top of that comes a bonus for a complete day and for
milestone days. The tracked flag is part of the check-in event, so every
device computes the same XP.

Importantly, `_computeXpByDay` replays the challenge day by day so each
check-in is scored with the streak the user had *at the time*. Using today's
streak would retroactively inflate the entire past.

The weekly league among friends buckets XP by ISO week. Promotion and
relegation only kick in from six participants — below that a rank says
nothing. Every phone computes it from the friends' events, so it is the same
verifiable number everywhere. The public league with divisions runs on the
server from XP each phone reports, capped per day ([`backend.md`](backend.md#leagues)).

## Flame, outlook, rewards

Three small pure functions carry the reward design
([`design.md`](design.md)), and they live in the core for the same reason as
the streak: they have to be right.

- **`flameStageFor`** maps the current streak to one of ten forms. A pure
  function of the streak, so a friend's device draws the same flame.
- **`projectOutlook`** projects the streak over the coming days *if nothing
  more is logged*, by the same rules `computeStreak` counts with. It is the
  timetable the home screen widget reads, since the widget cannot run the
  core itself.
- **`rewardForDay`** compares the streak and lifetime XP just before and just
  after the check-in that completed a day, and lists what the day earned:
  cycle complete, milestone, evolution, record (`StreakStats.previousBest`),
  level-up, perfect day. The celebration only decides how loud to be about
  it.

## Plans

Both plans are optional and stored on the goal, so they are part of the
challenge and live in the account.

- **Training.** The user picks a split; sessions rotate across training days
  rather than being pinned to weekdays, so any split works with any number of
  days. Each session's exercises start as a suggestion (by movement pattern,
  equipment and experience) and are then the user's to edit. Periodisation —
  three build weeks, a deload — is applied on top. Logged sessions feed a
  double-progression recommender: more reps at the same weight until every
  set reaches the top of the range, then the smallest load jump.
- **Nutrition.** Mifflin-St Jeor for the suggestion, the user's own number if
  they set one (bounded to 1000–6000 kcal, with a warning more than 25 % under
  expenditure), macros from body weight or a preset split.
