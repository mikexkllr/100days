import '../util/dates.dart';
import 'challenge.dart';
import 'habit.dart';

/// Which weekdays a habit with N days per week lands on.
///
/// Spread matters: 4 training days as Mon–Thu is a worse plan than Mon/Tue +
/// Thu/Fri, and a fixed table keeps "is today a rest day?" answerable offline
/// and identically on every peer's device.
const Map<int, List<int>> kWeekdaySpread = <int, List<int>>{
  1: <int>[DateTime.monday],
  2: <int>[DateTime.monday, DateTime.thursday],
  3: <int>[DateTime.monday, DateTime.wednesday, DateTime.friday],
  4: <int>[
    DateTime.monday,
    DateTime.tuesday,
    DateTime.thursday,
    DateTime.friday,
  ],
  5: <int>[
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.friday,
    DateTime.saturday,
  ],
  6: <int>[
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
  ],
  7: <int>[
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ],
};

List<int> scheduledWeekdays(Habit habit) =>
    kWeekdaySpread[habit.daysPerWeek.clamp(1, 7)]!;

bool isHabitScheduledOn(Habit habit, DayKey day) =>
    scheduledWeekdays(habit).contains(day.toDateTime().weekday);

/// The habits that must be logged on [day] for it to count as a complete day.
List<Habit> requiredHabitsOn(Challenge challenge, DayKey day) => challenge.habits
    .where((Habit h) => isHabitScheduledOn(h, day))
    .toList(growable: false);

/// Rest days are not failures. A day with nothing scheduled is "free" and
/// neither breaks nor extends the challenge streak.
bool isRestDay(Challenge challenge, DayKey day) =>
    requiredHabitsOn(challenge, day).isEmpty;
