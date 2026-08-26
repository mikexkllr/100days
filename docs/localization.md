# Localization

The app speaks **English and German** and follows the device language by
default. Anyone who wants otherwise changes it under *Settings → Language*; the
choice survives restarts.

**Code is English throughout** — identifiers, comments, commit messages,
documentation. German exists only as a translation file.

## The one rule

`hundred_core` contains **no display text at all**.

The package hands out identifiers and numbers — `HabitCategory.noSugar`,
`exerciseId: 'back_squat'`, `AbstinenceMilestone(track: alcohol, day: 14)`,
`CoachTemplate.pressureTheySeeYourFeed`. Wording happens exclusively in the
app, against `AppLocalizations`.

This is not a style question. A training plan generator that writes `nameDe`
into its data structures is unusable for English speakers, and a streak
calculation that can depend on display language is a bug that only surfaces
with the first foreign user. The boundary prevents both by construction:
`hundred_core` does not import `flutter` and therefore cannot reach
translations at all.

## Where things live

```
app/lib/l10n/
  app_en.arb            English (template)
  app_de.arb            German
  generated/            produced by `flutter gen-l10n`, do not hand-edit
  core_l10n.dart        habits, goals, tiers, leagues, units, times
  plan_l10n.dart        workouts, splits, meals, milestones, macro copy
  exercise_l10n.dart    exercise names and form cues
  coach_l10n.dart       coach directives, nudges, plan advice
  social_l10n.dart      feed lines, peer status
  prompt_l10n.dart      prompts for the local language model
  l10n.dart             one import plus `context.l10n`
```

In a screen it looks like this:

```dart
import '../../l10n/l10n.dart';

Text(context.l10n.homeCheckOffToday)
Text(l10n.habitTitle(habit.category))
Text(l10n.coachBody(directive))
```

## The coach

The coach is where "no text in the core" costs the most and pays off the most.
Instead of finished sentences it returns a **directive**:

```dart
CoachDirective(
  tone: CoachTone.socialPressure,
  template: CoachTemplate.pressureTheySeeYourFeed,
  peers: [PeerMention(displayName: 'Marcel', streak: 30, …)],
  streak: 12, dayNumber: 41, …
)
```

Which sentence fits the situation is decided by the core — testable without
asserting on prose. How it sounds is decided by the translation file.

Every phrasing variant is its own `CoachTemplate` value rather than an index
into a list. Otherwise a translation with a different number of variants could
quietly pull the wrong line.

The **prompt** for the local model is translated too: asking a model for German
output from an English prompt works badly. That is why `CoachPromptBuilder` is
a port; the app supplies `LocalizedCoachPrompts`, and the package itself only
carries an English version so it stays runnable and testable on its own.

## What does not get translated

- **Text the user wrote** — the goal sentence, notes, custom habit names, nudge
  messages. Shown verbatim.
- **Emoji.** Language-neutral, they stay in the core.
- **The wire format.** Events carry identifiers, never translated strings. That
  is why a `challenge.ascended` event holds only `cycle: 3` — your English
  friend reads "Beyond the 100" and you read "Jenseits der 100", from the same
  signed block of bytes.

## Adding a language

1. Create `app/lib/l10n/app_xx.arb`, using `app_en.arb` as the template.
2. Add the locale to `kSupportedLocales` in `app/lib/data/locale_store.dart`.
3. Run `flutter gen-l10n`.
4. Run `flutter test test/l10n_test.dart` — it walks *every* habit, goal,
   exercise, milestone and coach template and reports what is missing.

Nothing in the code needs changing. If it does, something is in the wrong
place.

## What the tests guard against

`app/test/l10n_test.dart` checks that:

- both ARB files define **exactly the same keys** — a forgotten translation is
  a red test, not an English fragment in the German UI
- no value is empty
- **placeholders match** between the two languages (otherwise `gen-l10n` throws
  at runtime)
- every enum value and id from `hundred_core` has text in **both** languages —
  this catches the forgotten `switch` case
- plurals actually inflect ("1 Tag" vs "9 Tage", "1 day" vs "9 days")
- sampled strings differ between languages, so they are translated rather than
  copied

On top of that, widget tests render the same state once in German and once in
English and assert that nothing from the other language is left on screen.
