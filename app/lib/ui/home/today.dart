import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../theme/fire.dart';

/// Where today stands: the facts the home screen, the ring around Funki and
/// the sky all show.
class TodayState {
  const TodayState({
    required this.habits,
    required this.done,
    required this.parts,
    required this.rest,
    required this.frozen,
    required this.relapse,
    required this.complete,
    required this.streak,
  });

  factory TodayState.of(AppSnapshot snapshot) {
    final Challenge challenge = snapshot.challenge!;
    final DayKey today = snapshot.today;
    final DayLog? log = snapshot.me.logsByDay[today.toString()];
    final List<Habit> habits = requiredHabitsOn(challenge, today);
    return TodayState(
      habits: habits,
      done: <bool>[for (final Habit h in habits) isHabitDone(h, log)],
      parts: <double>[for (final Habit h in habits) habitProgress(h, log)],
      rest: habits.isEmpty,
      frozen: snapshot.me.frozenDays.contains(today.toString()),
      relapse: log?.hasRelapse ?? false,
      complete: snapshot.me.streak.doneToday,
      streak: snapshot.me.streak.current,
    );
  }

  /// The habits scheduled today, in the order they are listed.
  final List<Habit> habits;

  /// Which of [habits] hit their target.
  final List<bool> done;

  /// How far each of [habits] is towards its target, 0 to 1.
  final List<double> parts;
  final bool rest;
  final bool frozen;
  final bool relapse;

  /// Every scheduled habit is done and nothing was confessed.
  final bool complete;
  final int streak;

  int get doneCount => done.where((bool d) => d).length;

  /// 0 to 1 through today.
  double get fraction => habits.isEmpty ? 0 : doneCount / habits.length;

  /// How high the aurora stands: a held day glows a little, a done day all
  /// the way.
  double get glow => complete
      ? 1
      : (rest || frozen)
          ? 0.4
          : fraction * 0.75;

  Fire get fire => Fire.ofStreak(streak);
}

/// Whether [habit] hit its target in [log] — an under-target entry is
/// progress, not a completed habit.
bool isHabitDone(Habit habit, DayLog? log) {
  final CheckIn? entry = log?.entryFor(habit.id);
  return entry != null && !entry.relapse && entry.value >= habit.target;
}

/// How far [habit] is towards its target in [log], 0 to 1.
double habitProgress(Habit habit, DayLog? log) {
  final CheckIn? entry = log?.entryFor(habit.id);
  if (entry == null || entry.relapse || habit.target <= 0) return 0;
  return (entry.value / habit.target).clamp(0.0, 1.0).toDouble();
}
