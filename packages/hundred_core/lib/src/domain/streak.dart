import '../util/dates.dart';
import 'challenge.dart';
import 'check_in.dart';
import 'habit.dart';
import 'schedule.dart';

class StreakStats {
  const StreakStats({
    required this.current,
    required this.longest,
    required this.completedDays,
    required this.scheduledDays,
    required this.doneToday,
    required this.atRisk,
    required this.freezesUsed,
    this.heldToday = false,
    this.previousBest = 0,
  });

  static const StreakStats empty = StreakStats(
    current: 0,
    longest: 0,
    completedDays: 0,
    scheduledDays: 0,
    doneToday: false,
    atRisk: false,
    freezesUsed: 0,
  );

  final int current;
  final int longest;
  final int completedDays;
  final int scheduledDays;
  final bool doneToday;

  /// Today is scheduled, is not done, and the streak dies at midnight.
  final bool atRisk;

  /// Today is not done but the streak mode lets it pass: the streak is safe
  /// until tomorrow without growing today.
  final bool heldToday;

  final int freezesUsed;

  /// The longest run that ended before the current one — the record the
  /// current streak has to beat. 0 when the streak never broke.
  final int previousBest;

  /// Today's check-in carried the streak past the best run that came before
  /// it. True on exactly one day per comeback, not on every day of a streak
  /// that has never broken.
  bool get beatPreviousBestToday =>
      doneToday && previousBest > 0 && current == previousBest + 1;

  double get completionRate =>
      scheduledDays == 0 ? 0 : completedDays / scheduledDays;
}

/// What a scheduled day does to the challenge-wide streak.
enum DayOutcome {
  /// Counts: the streak grows by one.
  complete,

  /// Holds: the streak survives the day but does not grow.
  held,

  /// Breaks the streak — or, today, would break it at midnight.
  broken,
}

/// How [day] counts for the challenge-wide streak, by the challenge's streak
/// mode on that day. Rest days and freezes are not this function's business.
///
/// A relapse only ever costs the habit it was logged on: in no mode does it
/// turn the other habits' work into a missed day. What does break the
/// streak is a scheduled habit left undone (in [StreakMode.gentle], only a
/// day with nothing done at all).
DayOutcome dayOutcome(
  Challenge challenge,
  DayKey day,
  DayLog? log,
) {
  final required = requiredHabitsOn(challenge, day);
  if (required.isEmpty || log == null) return DayOutcome.broken;
  var done = 0;
  var relapsed = 0;
  var missing = 0;
  for (final habit in required) {
    final entry = log.entryFor(habit.id);
    if (entry != null && entry.relapse) {
      relapsed++;
    } else if (entry != null && entry.value >= habit.target) {
      done++;
    } else {
      missing++;
    }
  }
  // Nothing done is nothing done, whatever the reason.
  if (done == 0) return DayOutcome.broken;
  switch (challenge.streakModeOn(day)) {
    case StreakMode.gentle:
      return missing + relapsed == 0 ? DayOutcome.complete : DayOutcome.held;
    case StreakMode.balanced:
      return missing > 0 ? DayOutcome.broken : DayOutcome.complete;
    case StreakMode.strict:
      if (missing > 0) return DayOutcome.broken;
      return relapsed > 0 ? DayOutcome.held : DayOutcome.complete;
  }
}

/// Did this day count for the challenge-wide streak?
///
/// See [dayOutcome]: in the default mode a day counts when every habit
/// scheduled for it is logged at or above target, a relapsed habit aside.
/// Half a day is not a day.
bool isDayComplete(
  Challenge challenge,
  DayKey day,
  DayLog? log,
) =>
    dayOutcome(challenge, day, log) == DayOutcome.complete;

/// Challenge-wide streak, counted in scheduled days.
///
/// Rest days are transparent: they neither add to nor break the streak, so a
/// 4-day-a-week lifter is not punished for Wednesdays.
StreakStats computeStreak({
  required Challenge challenge,
  required Map<String, DayLog> logsByDay,
  required Set<String> frozenDays,
  DayKey? today,
}) {
  final now = today ?? DayKey.today();
  if (now.isBefore(challenge.startDay)) return StreakStats.empty;

  final totalDays = now.differenceInDays(challenge.startDay) + 1;
  var completed = 0;
  var scheduled = 0;
  var longest = 0;
  var running = 0;
  var previousBest = 0;

  // Walk forward from day 1 so `longest` is a true historical maximum.
  for (var i = 0; i < totalDays; i++) {
    final day = challenge.startDay.addDays(i);
    if (isRestDay(challenge, day)) continue;
    scheduled++;
    final outcome = dayOutcome(challenge, day, logsByDay[day.toString()]);
    final frozen = frozenDays.contains(day.toString());
    if (outcome == DayOutcome.complete) {
      completed++;
      running++;
      if (running > longest) longest = running;
    } else if (frozen || outcome == DayOutcome.held) {
      // A freeze — or a day the streak mode lets pass — holds the streak but
      // does not count as a completed day.
      if (running > longest) longest = running;
    } else if (day == now) {
      // Today is still open — the streak is not broken until midnight.
      break;
    } else {
      if (running > previousBest) previousBest = running;
      running = 0;
    }
  }

  final restToday = isRestDay(challenge, now);
  final todayOutcome = dayOutcome(challenge, now, logsByDay[now.toString()]);
  final doneToday = !restToday && todayOutcome == DayOutcome.complete;
  final heldToday = !restToday && todayOutcome == DayOutcome.held;

  return StreakStats(
    current: running,
    longest: longest,
    completedDays: completed,
    scheduledDays: scheduled,
    doneToday: doneToday,
    heldToday: heldToday,
    atRisk: !restToday && todayOutcome == DayOutcome.broken,
    freezesUsed: frozenDays.length,
    previousBest: previousBest,
  );
}

/// Per-habit streak. For abstinence habits this is the number the user
/// actually cares about: days since the last relapse.
int habitStreak({
  required Habit habit,
  required Map<String, DayLog> logsByDay,
  required DayKey startDay,
  DayKey? today,
}) {
  final now = today ?? DayKey.today();
  final from = habit.activeFrom;
  final floor = from != null && from.isAfter(startDay) ? from : startDay;
  var streak = 0;
  var day = now;
  while (!day.isBefore(floor)) {
    final log = logsByDay[day.toString()];
    final entry = log?.entryFor(habit.id);
    if (entry != null && entry.relapse) break;

    if (habit.kind == HabitKind.abstain) {
      // Clean until proven otherwise: a forgotten tap does not reset an
      // abstinence streak, only a confessed relapse does.
      streak++;
    } else {
      if (!isHabitScheduledOn(habit, day)) {
        day = day.addDays(-1);
        continue;
      }
      if (entry != null && entry.value >= habit.target) {
        streak++;
      } else if (day == now) {
        // Today has not happened yet.
      } else {
        break;
      }
    }
    day = day.addDays(-1);
  }
  return streak;
}
