# The home screen widget

Funki and the streak on the home screen: fed, hungry, or about to go out —
with a live countdown to midnight while today is open, a line from Funki and
the week as a strip of flames.

| Size | Shows |
| --- | --- |
| 2 × 2 | Funki, the streak, today's state, the countdown |
| 4 × 2 | all of that, plus a line from Funki and the week |

## How it works

A widget cannot run Dart and cannot read the feed. So the app leaves it
everything it needs, already decided and already translated
(`app/lib/data/streak_widget.dart`):

1. **A two-week timetable.** `projectOutlook` in `hundred_core` projects the
   streak over the next 14 days *assuming nothing more is logged*: today is
   done or open, tomorrow the same streak is at stake, a scheduled day left
   untouched breaks it at midnight, rest days and freezes carry it. Each row
   holds the state, the streak still alive, the week strip as it will look
   that day, the status line and Funki's line — in the app's language.
2. **Funki as pictures.** The same `FlamePainter` the app uses renders one PNG
   per form and mood the timetable needs (for an open day also the worried
   face for the evening).
3. **Redraws.** On Android the app schedules a redraw at every midnight and
   every eight in the evening for the next week (on top of the system's own
   half-hourly update); on iOS the widget's timeline has an entry at each of
   those moments.

The native side only picks the row for today's date — and, after eight in the
evening, the worried face and line. Opening the app or checking in rewrites
the timetable. After two weeks without the app the widget falls back to a
fresh start, which is what the streak would be by then.

The rules are the app's rules, so the widget never shows a streak the app
would not.

## Android

Nothing to set up. `StreakWidgetProvider` (Kotlin) draws it with
`RemoteViews`; the layouts, backgrounds and the preview image live in
`app/android/app/src/main/res`.

To add it: long-press the home screen → Widgets → 100 Tage. On launchers that
support it, the app also offers an *Add widget* card at the bottom of the
home screen while no widget is placed.

The label and description in the widget picker are the only display text
outside the ARB files (`res/values/strings.xml`, `res/values-de/strings.xml`):
the launcher reads them before the app has ever run.

## iOS

The WidgetKit code is ready in `app/ios/StreakWidget/`, but the extension
target is not in the Xcode project yet — adding one needs Xcode and an App
Group on the developer account. Once:

1. In Xcode, *File → New → Target… → Widget Extension*. Name it
   `StreakWidget`; untick *Include Live Activity* and *Include Configuration
   App Intent*. Embed it in *Runner*.
2. Delete the Swift file Xcode generated and add
   `ios/StreakWidget/StreakWidget.swift` plus the two `Localizable.strings`
   (`en.lproj`, `de.lproj`) to the `StreakWidget` target.
3. Set the extension's deployment target to iOS 16.4, like *Runner*.
4. Under *Signing & Capabilities*, add **App Groups** to both *Runner* and
   *StreakWidget* with the group `group.com.hundreddays.hundredDays`. The app
   writes the timetable and the pictures there.
5. Build and run, then add the widget from the home screen.

Until then the app's calls to the widget fail quietly and change nothing.
