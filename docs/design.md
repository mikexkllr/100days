# The reward design

The app is built to make showing up feel good — loudly. A flame with a face,
a ring of fire, a slot machine when the day is done. This page explains what
each piece does, why it works, and the line it does not cross.

## The line

[CONTRIBUTING](../CONTRIBUTING.md) says the app may be uncomfortable but must
not deceive. The reward design keeps to that with one rule:

> **The presentation varies. The truth does not.**

Everything the celebrations reveal is a fact the feed already proves: the
streak, the XP the day scored, a milestone day, a new level, a new form of the
flame, a beaten record. The slot machine decides how *big* a moment looks —
never *what* happened. There are no random rewards, no bought luck, no
near-misses staged to keep you pulling, no invented numbers. When a reel lands
on a jackpot it is because something rare really happened today.

That is also why the rare moments come at irregular times without anyone
having to fake irregularity: milestone days thin out (1, 3, 7, 14, 21, 30 …),
level thresholds grow quadratically and the XP a day scores varies, flame
stages are spaced further apart the higher you go, and a record only exists
once you have lost a streak and fought back past it.

## Funki, the flame

The streak is a character, not a number. Funki is drawn entirely in code
(`app/lib/ui/mascot/flame_painter.dart`) — no image assets, the same painter
in the app, in tests and in the pictures handed to the home screen widget.

**It grows with the streak.** Ten forms, from an ember at zero to a sun at
365 days (`FlameStage` in `hundred_core`). Every threshold is a milestone day.
The next form is always shown — with the days still missing — and the ones
after it are silhouettes you have to earn to see. Breaking the streak takes
the form back: the flame is exactly as honest as the streak it is made of.

**It has a mood**, derived from the facts on the home screen
(`moodForToday`):

| Mood | When |
| --- | --- |
| hopeful | no streak yet |
| hungry | today is open |
| worried | today is open and it is past eight in the evening |
| happy | today is done |
| sleepy | rest day or a freeze |
| hyped | the celebration |
| sad | a relapse was logged today |

**It talks.** A line per mood, picked by the day so it is stable all day and
different tomorrow. Lines with numbers fill them from the real day — "3 h
left" is three hours, "42 days" is the streak. Every line is its own ARB key,
the same rule the coach follows. Tap Funki and it jumps, throws sparks and
answers; poke it five times in a row and it complains.

## The home screen

Top to bottom, the order of what matters:

1. **Funki in the ring of the cycle.** The arc is the cycle (day 12 of 100);
   the dots on it are the milestone days — gold once passed, the next one
   pulsing. Embers rise around it.
2. **The streak as a number that counts up** — every time the app opens.
3. **The form and the next one**, tappable into the evolution.
4. **The clock.** While today is open, a live countdown to midnight — when
   the streak really ends. Red from four hours out.
5. **The week as a chain.** Done days are linked; the gap you are about to
   leave is impossible to miss.
6. **The habits**, with a bar that fills segment by segment. Checking in is
   loud: the button sinks under the finger with a heavy buzz, sparks fly, the
   XP the tap earned floats up in gold, the card turns green.

## The slot machine

Completing the day — the last habit of the day ticked — rolls a machine
(`app/lib/ui/celebration/day_complete.dart`):

- Three reels: **STREAK**, **XP TODAY**, **BONUS**. They spin with motion
  blur, a selection click for every symbol that passes, and stop one after
  the other with a heavy thud and a bounce.
- The bonus reel lands on the loudest real highlight of the day
  (`rewardForDay` in `hundred_core`): cycle complete, milestone, evolution,
  record, level-up — or a perfect day, which every completed day is.
- Anything louder than a perfect day is a **jackpot**: gold title, marquee
  lights chasing, a coin fountain, three hard knocks of haptics.
- Then every highlight as its own chip, and **what is next**: the next form,
  the next milestone and the next level, each with the real distance to it.
  That is the goal-gradient effect, with true numbers.
- Tap anywhere to skip the spin. "Brag about it" shares the streak.

## Motion and accessibility

Looping decoration — the flicker, the embers, the shimmer on buttons, the
light rays — stops when the system asks for reduced motion
(`ambientMotionOf`). The celebration then shows its result without the spin.
Screen readers hear what the animation shows: every check-in is announced.

Widget tests run with reduced motion on (`reducedMotion` in
`app/test/helpers.dart`); otherwise `pumpAndSettle` would wait for a flame
that never stops.

## The look

A night sky with a fire in it: a deep purple-black base (orange and gold are
loudest next to violet), a fire gradient from hot pink to yellow, gold for
rewards, lime for done, ice blue for freezes and rest days. Numbers,
headlines and buttons use Lilita One (SIL OFL, `app/assets/fonts`); body text
stays in the system font. Buttons are raised on a darker lip and sink when
pressed.

## The home screen widget

See [`home-screen-widget.md`](home-screen-widget.md).
