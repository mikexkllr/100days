import '../util/dates.dart';
import 'challenge.dart';
import 'check_in.dart';
import 'flame.dart';
import 'schedule.dart';
import 'streak.dart';

/// How a single day looks on a week strip.
enum DayMark {
  /// Before the challenge started.
  none,

  /// Every scheduled habit hit its target.
  done,

  /// A streak freeze held the day.
  frozen,

  /// Scheduled, over, not done: the streak broke here.
  missed,

  /// Nothing scheduled — neither breaks nor extends the streak.
  rest,

  /// Today, scheduled and not done yet.
  open,

  /// Still to come.
  upcoming,
}

/// The mark for [day], by the same rules [computeStreak] counts with.
DayMark dayMarkFor({
  required Challenge challenge,
  required DayKey day,
  required DayKey today,
  required Map<String, DayLog> logsByDay,
  required Set<String> frozenDays,
}) {
  if (day.isBefore(challenge.startDay)) return DayMark.none;
  if (isRestDay(challenge, day)) return DayMark.rest;
  if (day.isAfter(today)) return DayMark.upcoming;
  if (isDayComplete(challenge, day, logsByDay[day.toString()])) {
    return DayMark.done;
  }
  if (frozenDays.contains(day.toString())) return DayMark.frozen;
  return day == today ? DayMark.open : DayMark.missed;
}

/// Monday to Sunday of the week [day] falls in.
List<DayMark> weekMarks({
  required Challenge challenge,
  required DayKey day,
  required DayKey today,
  required Map<String, DayLog> logsByDay,
  required Set<String> frozenDays,
}) {
  final monday = day.weekStart;
  return <DayMark>[
    for (var i = 0; i < 7; i++)
      dayMarkFor(
        challenge: challenge,
        day: monday.addDays(i),
        today: today,
        logsByDay: logsByDay,
        frozenDays: frozenDays,
      ),
  ];
}

/// What the home screen widget shows on a day.
enum OutlookState {
  /// Done; the streak is safe until tomorrow.
  done,

  /// A freeze holds the day; the streak is safe until tomorrow.
  frozen,

  /// Scheduled and not done yet: the streak dies at midnight.
  open,

  /// Nothing scheduled; the streak waits.
  rest,

  /// No streak left to lose — a fresh start.
  cold,
}

/// One row of the widget's timetable.
class StreakOutlook {
  const StreakOutlook({
    required this.day,
    required this.state,
    required this.streak,
    required this.week,
  });

  final DayKey day;
  final OutlookState state;

  /// The streak alive on [day], counting [day] itself only when it is done.
  final int streak;

  /// The week strip as it would look on [day], Monday first.
  final List<DayMark> week;

  FlameStage get stage => flameStageFor(streak);

  Map<String, Object> toJson() => <String, Object>{
        'day': day.toString(),
        'state': state.name,
        'streak': streak,
        'stage': stage.name,
        'week': week.map((DayMark m) => m.name).toList(),
      };
}

/// The streak over the coming [days], assuming nothing more is logged.
///
/// A home screen widget cannot ask the app what today looks like; it can only
/// read what the app left behind. So the app leaves it a short timetable:
/// for each coming day, the state to show and the streak still alive. Under
/// that assumption a scheduled day that is not done today breaks the streak
/// at midnight, exactly as [computeStreak] will count it — and as soon as the
/// user opens the app or checks in, the timetable is rewritten.
List<StreakOutlook> projectOutlook({
  required Challenge challenge,
  required StreakStats streak,
  required DayKey today,
  required Map<String, DayLog> logsByDay,
  required Set<String> frozenDays,
  int days = 14,
}) {
  final result = <StreakOutlook>[];
  var alive = streak.current;
  for (var i = 0; i < days; i++) {
    final day = today.addDays(i);
    final monday = day.weekStart;
    final week = <DayMark>[
      for (var w = 0; w < 7; w++)
        _markSeenFrom(
          day,
          markDay: monday.addDays(w),
          today: today,
          actual: dayMarkFor(
            challenge: challenge,
            day: monday.addDays(w),
            today: today,
            logsByDay: logsByDay,
            frozenDays: frozenDays,
          ),
        ),
    ];

    OutlookState state;
    if (day.isBefore(challenge.startDay)) {
      state = OutlookState.cold;
    } else if (i == 0 && streak.doneToday) {
      state = OutlookState.done;
    } else if (frozenDays.contains(day.toString())) {
      state = OutlookState.frozen;
    } else if (isRestDay(challenge, day)) {
      state = OutlookState.rest;
    } else {
      state = alive > 0 ? OutlookState.open : OutlookState.cold;
    }
    result.add(StreakOutlook(
      day: day,
      state: state,
      streak: day.isBefore(challenge.startDay) ? 0 : alive,
      week: week,
    ));

    // Left undone, a scheduled day breaks the streak at midnight.
    if (state == OutlookState.open || state == OutlookState.cold) alive = 0;
  }
  return result;
}

/// [actual] as it will look on [seenFrom] if nothing more is logged: what is
/// still open today and every scheduled day in between stays undone.
DayMark _markSeenFrom(
  DayKey seenFrom, {
  required DayKey markDay,
  required DayKey today,
  required DayMark actual,
}) {
  if (!seenFrom.isAfter(today)) return actual;
  if (actual == DayMark.open) return DayMark.missed;
  if (actual != DayMark.upcoming) return actual;
  if (markDay.isBefore(seenFrom)) return DayMark.missed;
  if (markDay == seenFrom) return DayMark.open;
  return DayMark.upcoming;
}
