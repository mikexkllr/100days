import 'package:meta/meta.dart';

import '../domain/challenge.dart';
import '../domain/habit.dart';
import '../util/dates.dart';

/// What the user shares with friends. Friends only — there is no "public".
///
/// Some things are never shared and have no switch here: body stats, the
/// calorie and macro targets and the food diary stay on the device (sealed in
/// the user's own feed, see `PrivateBox`). What a friend can see is the
/// streak, the habits marked as shared, and — if the user wants — the goal
/// sentence and what they lifted.
@immutable
class SharingPrefs {
  const SharingPrefs({
    this.privateHabits = const <String>{},
    this.shareStatement = true,
    this.shareWorkouts = true,
    this.sharedSince = const <String, DayKey>{},
  });

  factory SharingPrefs.fromJson(Map<String, dynamic> json) => SharingPrefs(
        privateHabits: ((json['private'] as List<dynamic>?) ??
                const <dynamic>[])
            .whereType<String>()
            .toSet(),
        shareStatement: json['statement'] as bool? ?? true,
        shareWorkouts: json['workouts'] as bool? ?? true,
        sharedSince: <String, DayKey>{
          for (final MapEntry<String, dynamic> e
              in ((json['since'] as Map?) ?? const <String, dynamic>{})
                  .cast<String, dynamic>()
                  .entries)
            if (e.value is String) e.key: DayKey.parse(e.value as String),
        },
      );

  /// Ids of habits friends must not see — neither the habit nor its
  /// check-ins nor its relapses.
  final Set<String> privateHabits;

  /// The goal sentence ("8 kg down in 100 days").
  final bool shareStatement;

  /// Workout logs: session, sets, weights. Off means friends only see that
  /// the training was done.
  final bool shareWorkouts;

  /// Habits that were private and are shared since a given day. Friends'
  /// devices only count them from then on — their check-ins before that day
  /// are sealed, and must not look like misses. The owner's own count is
  /// unaffected.
  final Map<String, DayKey> sharedSince;

  bool isHabitShared(String habitId) => !privateHabits.contains(habitId);

  SharingPrefs copyWith({
    Set<String>? privateHabits,
    bool? shareStatement,
    bool? shareWorkouts,
    Map<String, DayKey>? sharedSince,
  }) =>
      SharingPrefs(
        privateHabits: privateHabits ?? this.privateHabits,
        shareStatement: shareStatement ?? this.shareStatement,
        shareWorkouts: shareWorkouts ?? this.shareWorkouts,
        sharedSince: sharedSince ?? this.sharedSince,
      );

  /// Shares or hides [habitId]. Sharing a habit that was private records
  /// [since], so friends start counting it from that day.
  SharingPrefs withHabitShared(String habitId, bool shared, {DayKey? since}) {
    final wasPrivate = privateHabits.contains(habitId);
    return copyWith(
      privateHabits: shared
          ? (privateHabits.toSet()..remove(habitId))
          : (privateHabits.toSet()..add(habitId)),
      sharedSince: shared && wasPrivate && since != null
          ? <String, DayKey>{...sharedSince, habitId: since}
          : sharedSince,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'private': (privateHabits.toList()..sort()),
        'statement': shareStatement,
        'workouts': shareWorkouts,
        if (sharedSince.isNotEmpty)
          'since': <String, String>{
            for (final MapEntry<String, DayKey> e in sharedSince.entries)
              e.key: e.value.toString(),
          },
      };
}

/// The challenge as friends get to see it.
///
/// Private habits are removed — a friend's device then computes the streak
/// from the shared habits only, which is the honest number to show them.
/// Body stats, nutrition targets and the sharing settings themselves are
/// stripped; the goal sentence only stays if the user shares it.
Challenge publicViewOf(Challenge challenge) {
  final sharing = challenge.sharing;
  final goal = challenge.goal;
  return Challenge(
    id: challenge.id,
    goal: goal.copyWith(
      clearBody: true,
      statement: sharing.shareStatement ? goal.statement : '',
      clearNutrition: true,
    ),
    habits: <Habit>[
      for (final Habit h in challenge.habits)
        if (sharing.isHabitShared(h.id)) _visibleFrom(h, sharing.sharedSince[h.id]),
    ],
    startDay: challenge.startDay,
    lengthDays: challenge.lengthDays,
    cycle: challenge.cycle,
    streakFreezesRemaining: challenge.streakFreezesRemaining,
  );
}

Habit _visibleFrom(Habit habit, DayKey? since) {
  if (since == null) return habit;
  final from = habit.activeFrom;
  if (from != null && !from.isBefore(since)) return habit;
  return habit.copyWith(activeFrom: since);
}
