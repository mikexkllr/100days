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

  final int freezesUsed;

  double get completionRate =>
      scheduledDays == 0 ? 0 : completedDays / scheduledDays;
}

/// Was this day fully done?
///
/// A day counts when every habit scheduled for it is logged at or above target
/// and no relapse was confessed. Half a day is not a day.
bool isDayComplete(
  Challenge challenge,
  DayKey day,
  DayLog? log,
) {
  final required = requiredHabitsOn(challenge, day);
  if (required.isEmpty) return false;
  if (log == null) return false;
  if (log.hasRelapse) return false;
  for (final habit in required) {
    final entry = log.entryFor(habit.id);
    if (entry == null || entry.relapse) return false;
    if (entry.value < habit.target) return false;
  }
  return true;
}

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

  // Walk forward from day 1 so `longest` is a true historical maximum.
  for (var i = 0; i < totalDays; i++) {
    final day = challenge.startDay.addDays(i);
    if (isRestDay(challenge, day)) continue;
    scheduled++;
    final complete = isDayComplete(challenge, day, logsByDay[day.toString()]);
    final frozen = frozenDays.contains(day.toString());
    if (complete) {
      completed++;
      running++;
      if (running > longest) longest = running;
    } else if (frozen) {
      // A freeze holds the streak but does not count as a completed day.
      if (running > longest) longest = running;
    } else if (day == now) {
      // Today is still open — the streak is not broken until midnight.
      break;
    } else {
      running = 0;
    }
  }

  final doneToday = !isRestDay(challenge, now) &&
      isDayComplete(challenge, now, logsByDay[now.toString()]);

  return StreakStats(
    current: running,
    longest: longest,
    completedDays: completed,
    scheduledDays: scheduled,
    doneToday: doneToday,
    atRisk: !isRestDay(challenge, now) && !doneToday,
    freezesUsed: frozenDays.length,
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
  var streak = 0;
  var day = now;
  while (!day.isBefore(startDay)) {
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
