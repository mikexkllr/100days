# The reward design

The app is built to make showing up feel good — loudly. A flame with a face,
a night sky you light yourself, a slot machine when the day is done. This
page explains what each piece does, why it works, and the line it does not
cross.

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

**It grows with the streak.** Ten forms, from a red ember at zero through
magenta, violet, blue, cyan and white to a holographic galaxy at 365 days (`FlameStage` in `hundred_core`). Every threshold is a milestone day.
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

Today fits on one screen: the streak, the state of the day and every habit
you have to do, without scrolling. The title is the day itself — "Day 13 /
100". Top to bottom, the order of what matters:

1. **The streak, hollow or lit.** A huge number that counts up every time
   the app opens. While today is open it is an outline: the streak exists,
   but it is at stake. Once the day is done — or held by a freeze or a rest
   day — it fills with fire. Nobody has to read a status line to know which
   it is.
2. **Funki in the ring of today.** The ring around Funki has one segment per
   habit scheduled today. A segment lights when its habit is done (and shows
   how far a half-read chapter got before that). The last segment closes the
   ring. On a rest day it is a dotted line; under a freeze it is closed in
   ice. Funki's line sits above, pointing at him.
3. **The clock.** While today is open, a live countdown to midnight — when
   the streak really ends. Red from four hours out.
4. **The week as lamps.** A finished day is lit, and lit days next to each
   other are joined into a chain, so the gap you are about to leave is
   impossible to miss. Tap a day to see what was logged on it.
5. **The way to the next form**: the current one, the next one and the bar
   between them. Opens the whole ladder.
6. **Today's quests.** One row per habit, and the whole row is the button
   (`app/lib/ui/widgets/habit_tile.dart`). Checking in is a **hold**: the row
   fills with fire, the phone ticks at every quarter, and when it is full it
   fires with a hard knock and logs the habit at its target. Let go early and
   nothing is logged. Then sparks fly, the XP the check-in earned floats up
   and the row stays lit. A quick tap is not a check-in; it opens what else
   the habit can do — a different amount than the target, or an honest
   relapse. Screen readers get a plain tap instead of the hold.

Below that: who of your friends was already active, the freeze as a way out
(offered, not pushed), today's workout and macros, the coach, and the whole
cycle as a strip of a hundred lamps.

## The board

A hundred days is a number you cannot picture; a hundred lamps you can
(`app/lib/ui/widgets/day_board.dart`). The numbers screen shows the cycle
ten by ten: finished days lit in the colour of the flame, frozen days in
ice, missed days dark with a red rim, and the days still to come as dim
dots — with the milestone days ringed, so you can see what you are walking
towards. Tap any day that has happened for what was logged on it.

## The slot machine

Completing the day — the last habit of the day ticked — rolls a machine
(`app/lib/ui/celebration/day_complete.dart`):

- Three reels: **STREAK**, **XP TODAY**, **BONUS**. They spin with motion
  blur, a selection click for every symbol that passes, and stop one after
  the other with a heavy thud and a bounce.
- The bonus reel lands on the loudest real highlight of the day
  (`rewardForDay` in `hundred_core`): cycle complete, milestone, evolution,
  record, level-up — or a perfect day, which every completed day is.
- Anything louder than a perfect day is a **jackpot**: a holographic title,
  rays of every colour, marquee lights chasing, a fountain of gems, three
  hard knocks of haptics.
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

## The look: Lights

A quiet night that you light yourself. The rule the whole look follows:

> **The chrome has no colour. Light is earned.**

- **The sky is yours** (`app/lib/ui/motion/sky.dart`). Painted once behind
  the navigator, so every page lies over the same sky. Nothing in it is
  decoration: **every star is a day you finished** — a new challenge starts
  under an almost empty sky, day 100 under a full one, and every seventh
  star is a bigger one with a flare. **The aurora is today**: barely there in
  the morning, higher with every check-in, all the way up once the day is
  done. An unfinished day looks unfinished.
- **The app burns in the colour of your flame** (`Fire` in
  `app/lib/theme/fire.dart`). Whatever is lit — the streak number, the ring,
  a finished habit, the lamps, the aurora — takes the colour of Funki's
  current form: pink in the first days, then magenta, violet, blue, cyan,
  white-hot. Day 50 does not look like day 5. Break the streak and the
  colour goes back with the form. A friend's streak is shown in *their*
  colour.
- **Matte, not glass.** Panels are dark and flat with a hairline rim. No
  gradient borders, no glow on things that are not lit. Light itself — white
  — is what you can press: buttons, the selected tab, a switch that is on.
- **Colour that means something.** Mint is verified or logged, ice blue is a
  freeze or a rest day, red is a relapse or the last hours of the day,
  lavender is XP, blue is other people. No orange anywhere. Holographic foil
  is kept for jackpots.
- **Type.** Unbounded — wide and round — only for the numbers the app exists
  for and the few lines that are meant as a statement; Manrope for titles,
  buttons and everything that is read (both SIL OFL, `app/assets/fonts`).
- **Navigation.** A matte dock floats over the sky; what scrolls under it
  sinks into the night first. The selected tab is lit. While today is open,
  the Today tab carries a dot in the colour of the streak.

## The home screen widget

See [`home-screen-widget.md`](home-screen-widget.md).
