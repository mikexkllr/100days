# Apple Health and Health Connect

The app can fill in some check-ins from a watch instead of making you tap
them. Steps from a Fitbit or a Pixel Watch, a lifting session from an Apple
Watch, last night's sleep — read on the device, converted on the device, and
written into your own signed feed like any other check-in.

Nothing about this needs a server, and nothing about it moves the app closer to
having one.

## What it reads

Six metrics, and not one more. Every metric here backs a habit in the
catalogue; a metric with no habit behind it would mean asking for a permission
the app has no use for.

| Habit | Metric | Apple Health | Health Connect | Counts when |
| --- | --- | --- | --- | --- |
| 👟 Steps | step count | ✅ | ✅ | over 500 steps |
| 🏋️ Training | strength sessions | ✅ | ✅ | session of 20 minutes or more |
| 🏃 Cardio | cardio sessions | ✅ | ✅ | session of 5 minutes or more |
| 😴 Sleep | sleep duration | ✅ | ✅ | at least 2 hours |
| 🧘 Meditation | mindfulness sessions | ✅ | — | any session |
| 💧 Water | hydration | ✅ | ✅ | 250 ml to a glass |

Meditation is Apple-only because Health Connect has no mindfulness record
type. The toggle is shown disabled on Android rather than hidden, so it is
obvious why the habit stays manual instead of looking broken.

**Abstinence habits are absent by construction and always will be.** No sensor
can show that you did not drink, and a habit that quietly ticks itself off is
the opposite of what an abstinence streak is for.

## What it will not do

These are the rules, and each one is a test in
`packages/hundred_core/test/health_test.dart`:

- **It never overwrites a number you entered yourself.** A manual entry has no
  `health` block in its payload, and the planner refuses to touch one — even
  when the sensor's number is higher.
- **It never writes on a day you logged a relapse.** A step count does not get
  to overrule a person admitting they broke.
- **It leaves rest days empty.** A habit that runs four days a week gets
  nothing written on the other three; otherwise a Sunday walk would earn XP on
  a day the plan deliberately left free.
- **It only ever raises a value.** Steps climb through the day, so an import
  can replace its own earlier entry — but never with a lower number, and never
  when nothing changed (which would grow the feed for no reason).
- **It reaches at most seven days back**, and never past the start of your
  challenge. A phone that has not been opened since March must not suddenly
  write four months of history: in a friend's feed that is indistinguishable
  from someone gaming their streak.
- **It rounds down.** 29.6 minutes of cardio against a 30-minute target is not
  a completed day. You can still close it by hand if you disagree — you were
  there, the watch was only strapped to you.

## What it proves

Less than it looks like, and the app says so on the screen where you turn it
on.

The feed proves that an entry is yours, when it was written, and that nobody
altered it afterwards. It cannot prove a watch was involved. Nothing Apple or
Google hands an app is signed in a way a friend's phone could verify, and
anyone determined to fake a streak can write steps into Health by hand.

So an imported check-in is labelled **"from Apple Health"** or **"from Health
Connect"**, never "verified". The badge is a claim about where a number came
from, not a proof, and calling it anything stronger would be the one dishonest
thing in an app whose whole pitch is that the streak is real.

## Where the work happens

The split follows the same rule as the rest of the project: anything that has
to be *correct* lives in `hundred_core` and is tested without a device.

```
packages/hundred_core/lib/src/health/
  health_metric.dart      metrics, units, which platform has which
  health_sample.dart      merging overlapping sessions, per-day folding
  health_mapping.dart     habit ↔ metric bindings and unit conversion
  health_import.dart      what becomes a check-in, and what does not
  health_source.dart      the port the app implements
  health_provenance.dart  the label that rides along in the payload

app/lib/data/
  health_gateway.dart         method channel → the port
  health_preferences.dart     which habits you released, device-local
  health_import_service.dart  read → plan → append

app/android/.../HealthPlugin.kt   Health Connect
app/ios/Runner/HealthPlugin.swift HealthKit
```

The native halves do as little as possible. They hand Dart per-day totals for
the two things the platforms aggregate better than we could — steps and
hydration, where their own de-duplication across writing apps is the entire
point — and raw intervals for everything session-shaped. Merging, day
attribution and the import rules all happen in Dart.

### Why sessions are merged rather than summed

Your watch records a run and Strava records the same run. That is two sessions
and one hour of actual effort; summing them gives two hours and a cardio habit
that hits its target because you went for a jog. `mergeSessions` collapses
overlapping and touching intervals first, per metric, so the same hour is
counted once. Sessions a watch split at a pause are rejoined the same way.

### Why sleep is attributed differently

A workout counts on the day it started: one that begins at 23:40 on Friday was
Friday's workout. A night's sleep counts on the day it *ended* — you go to bed
on Monday and that is Tuesday's night, which is how every sleep tracker reports
it and how a person thinks about it. `DayAttribution` is the one bit of the
metric table that exists purely for this.

## When it runs

On app start and when you bring the app back to the foreground, if you left
auto-import on. That is the honest schedule: neither platform offers background
health reads worth relying on, and the app is not going to claim otherwise.

Both rounds are silent. A missing provider, a revoked permission, or a phone
with no health store at all are ordinary states, not errors, and none of them
puts a dialog in front of you.

## Setting it up

**Android.** Health Connect ships with Android 14 and up; on older phones it is
a free app from the Play Store. Your watch's own app (Fitbit, Samsung Health,
Garmin Connect, Strava) has to be told to write into it — that is a setting in
*their* app, not in this one. Then: Settings → Watch & health data → pick your
habits → Allow access.

The app declares four read permissions and no write permission at all:
`READ_STEPS`, `READ_EXERCISE`, `READ_SLEEP`, `READ_HYDRATION`. A bug in it
cannot corrupt your health record, because it holds nothing that could.

**iOS.** Building for a real iPhone needs the HealthKit capability on your
signing profile; `app/ios/Runner/Runner.entitlements` already declares it. The
background-delivery entitlement is deliberately absent — the app reads when you
open it, so it never needs waking up to look at your health data.

iOS will not tell the app whether reading was allowed. That is by design: a
refusal would itself be a signal, so HealthKit reports success either way and
simply returns nothing. The settings screen says "Apple does not say" rather
than inventing a status, and an empty read is treated as "nothing to import"
rather than as a failure.

## Adding a metric

1. A row in `kHealthMetrics` (`health_metric.dart`) — unit, whether it is a
   daily total or a session, which platforms have it.
2. A row in `kHealthBindings` (`health_mapping.dart`) — which habit it feeds,
   the floor, the conversion.
3. A case in each platform adapter.

Nothing else reads the enum directly, and the analyzer's exhaustive switches
will point at anything you missed.
