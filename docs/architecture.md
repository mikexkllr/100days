# Architecture

## Two packages, one boundary

```
packages/hundred_core/     pure Dart — no Flutter, network or filesystem
                           dependency, and no display language
app/                       Flutter — UI, persistence, transports, platform
```

The boundary is not a matter of taste. Everything that has to be *correct* —
chain validation, streak arithmetic, the calorie formula, a complete sync round
— lives in the core and is testable without an emulator, without a camera and
without two phones on the same Wi-Fi. The core has over 100 tests that run in
two seconds.

The core also knows nothing about display language. It hands out identifiers
(`HabitCategory.noSugar`, an `exerciseId`, a `CoachTemplate`) and the app turns
them into sentences. See [`localization.md`](localization.md).

## The feed is the only truth

There is no state "beside" the log. Every action — setting a profile, starting
a challenge, a check-in, a relapse, a streak freeze, a nudge, an ascent —
becomes an entry in your own feed. Everything on screen is a fold over those
entries (`projectUser`).

That has two practical consequences:

1. **Someone else's streak is computed, not claimed.** Your device folds your
   friend's signed entries itself. There is no number to fake without breaking
   a signature.
2. **Replication is trivial.** Merging feeds means appending missing entries.
   No merge conflicts, no consensus round — each DID only ever writes its own
   feed.

```
FeedEvent { author, seq, prev, timestamp, type, payload, hash, sig }
             │      │      │                                 │     │
             │      │      └── hash of the predecessor ──────┘     │
             │      └───────── gapless from 1                      │
             └──────────────── did:key of the only writer ─────────┘
```

`hash` is SHA-256 over the canonical JSON encoding of the body (keys sorted, no
whitespace — otherwise two devices derive different bytes from the same event
and every check fails). `sig` is Ed25519 over that hash.

## Layers

```
   UI (Flutter)
      │  reads AppSnapshot, calls AppController
   ▼
   AppController (Riverpod AsyncNotifier)
      │  debounced re-projection on every feed event
   ▼
   AppRepository ──── FeedWriter ──► FeedStore ──► SQLite
      │                                  ▲
      │                                  │
      │              FeedReplicator ─────┘   (the single point where
      │                     ▲                 foreign bytes become state)
      ▼                     │
   projectUser()        Syncer ◄──── PeerTransport ◄──── LAN / relay later
```

**Why re-projection is debounced:** a sync round can land two hundred events at
once. Re-projecting per event would make the UI stutter; a 120 ms window is
enough.

**Why `FeedReplicator` is the only entrance:** there should be exactly one place
where unverified bytes become trusted state. It checks type, hash, signature,
sequence, chain link and timestamp — and stops at the first failure for that
author, because nothing behind a broken link is verifiable any more.

## Ports and adapters

The core defines interfaces, the app supplies the implementations:

| Port (core) | Adapter (app) | Test double |
| --- | --- | --- |
| `FeedStore` | `SqliteFeedStore` | `MemoryFeedStore` |
| `PeerTransport` / `PeerSession` | `LanTransport` / `SocketPeerSession` | `LoopbackSession` |
| `LocalLlmRuntime` | `LlamaCppRuntime` (llamadart) | fake in tests |
| `CoachPromptBuilder` | `LocalizedCoachPrompts` | `EnglishCoachPrompts` |
| `NutritionPromptBuilder` | `LocalizedNutritionPrompts` | `EnglishNutritionPrompts` |
| `FoodLookup` / `FoodVocabulary` | `FoodIndex`, `foodVocabularyFor` | English fixture |
| `CoachEngine` | — | `HeuristicCoach` is itself the fallback layer |

The sync logic is tested against `LoopbackSession` — two nodes in one process,
running a real protocol round. That leaves only the socket plumbing untested,
and that is the part you cannot meaningfully simulate anyway.

## Time

Streaks are keyed to *local calendar days*, not to instants. A check-in at
23:59 and one at 00:01 are two days even though they are two minutes apart —
which is exactly what a streak means to a person. That is what `DayKey` is for;
`DateTime` only appears at the edges.

Events carry two times: the claimed day (`payload.day`) and the moment of
writing (`timestamp`). When they differ it was a backfill, and the feed says so.

## Streak rules

- A day counts when **every habit scheduled for that day** hits its target and
  no relapse is logged. Half a day is not a day.
- **Rest days break nothing.** Someone training four days a week is not
  punished for Wednesdays. `kWeekdaySpread` fixes which weekdays are occupied
  for N days per week — deterministically, so every device computes the same
  answer.
- **Today stays open until midnight.** An unfinished current day does not break
  the streak, it marks it at risk.
- **Abstinence counts differently.** A forgotten tap does not reset an
  abstinence streak — only an admitted relapse does. Otherwise people quit, and
  that is the worse failure mode.
- **Streak freezes are scarce** (three per cycle) and hold the streak without
  counting as a completed day. If a missed day were free, the whole point of
  the app would collapse.

## Private data in a shared log

"The feed is the only truth" holds for private data too. Body stats,
nutrition targets, the food diary and habits the user keeps to themselves go
into the same feed as **sealed** events — ChaCha20-Poly1305 under a key
derived from the identity seed. Friends replicate and verify them like any
other event but cannot read them; the owner's device opens them before
folding. The chain stays complete, and a restore from the recovery key brings
the diary back from friends' copies. Details:
[`protocol.md`](protocol.md#sealed-events).

A challenge is published twice: a public view (no body stats, no targets, no
private habits) and the full one, sealed. A friend's device computes the
streak from the public view — the shared habits only.

## XP, levels, league

XP per check-in scales with difficulty (1–5 from the catalogue), streak length
(up to 2× at 50 days), a ×1.5 bonus for **tracked** check-ins — a workout
logged set by set, a diary day closed on target — and a bonus for logging on
the day itself. On top of that comes a bonus for a complete day and for
milestone days. The tracked flag is part of the signed check-in, so every
device computes the same XP.

Importantly, `_computeXpByDay` replays the challenge day by day so each
check-in is scored with the streak the user had *at the time*. Using today's
streak would retroactively inflate the entire past.

The weekly league buckets XP by ISO week. Promotion and relegation only kick in
from six participants — below that a rank says nothing. The league is friends
only, by construction: there is no server that knows anyone else.

## Plans

Both plans are optional and stored on the goal, so they are part of the
signed challenge and survive a restore.

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
