import 'package:meta/meta.dart';

import '../util/dates.dart';
import 'goal.dart';
import 'habit.dart';

/// The challenge does not end on day 100 — that is the whole premise of
/// "100 days and far beyond". Day 100 closes a *cycle*; the streak keeps
/// counting and the user ascends into the next tier.
@immutable
class ChallengeTier {
  const ChallengeTier({
    required this.index,
    required this.nameDe,
    required this.emoji,
  });

  final int index;
  final String nameDe;
  final String emoji;
}

const List<ChallengeTier> kChallengeTiers = <ChallengeTier>[
  ChallengeTier(index: 0, nameDe: 'Die ersten 100', emoji: '🔥'),
  ChallengeTier(index: 1, nameDe: 'Jenseits der 100', emoji: '⚡'),
  ChallengeTier(index: 2, nameDe: 'Dreihundert', emoji: '🌘'),
  ChallengeTier(index: 3, nameDe: 'Das Jahr', emoji: '🌍'),
  ChallengeTier(index: 4, nameDe: 'Unbeugsam', emoji: '🗿'),
  ChallengeTier(index: 5, nameDe: 'Legende', emoji: '👑'),
];

ChallengeTier tierForCycle(int cycle) => cycle < kChallengeTiers.length
    ? kChallengeTiers[cycle]
    : ChallengeTier(
        index: cycle,
        nameDe: 'Legende ${cycle - kChallengeTiers.length + 2}',
        emoji: '👑',
      );

/// Day counts worth interrupting the user for.
const List<int> kMilestoneDays = <int>[
  1, 3, 7, 14, 21, 30, 50, 66, 75, 90, 100,
  150, 200, 250, 300, 365, 500, 750, 1000,
];

@immutable
class Challenge {
  const Challenge({
    required this.id,
    required this.goal,
    required this.habits,
    required this.startDay,
    this.lengthDays = 100,
    this.cycle = 0,
    this.streakFreezesRemaining = 3,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
        id: json['id'] as String,
        goal: Goal.fromJson(Map<String, dynamic>.from(json['goal'] as Map)),
        habits: (json['habits'] as List<dynamic>)
            .map((dynamic e) =>
                Habit.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        startDay: DayKey.parse(json['startDay'] as String),
        lengthDays: (json['lengthDays'] as num?)?.toInt() ?? 100,
        cycle: (json['cycle'] as num?)?.toInt() ?? 0,
        streakFreezesRemaining:
            (json['streakFreezesRemaining'] as num?)?.toInt() ?? 3,
      );

  final String id;
  final Goal goal;
  final List<Habit> habits;
  final DayKey startDay;
  final int lengthDays;

  /// How many full cycles the user has already completed. Starts at 0.
  final int cycle;

  /// "Streak freezes" — a limited number of days that can be missed without
  /// resetting. Deliberately scarce: the whole point of the app collapses if
  /// missing a day is free.
  final int streakFreezesRemaining;

  ChallengeTier get tier => tierForCycle(cycle);

  /// 1-based day number for [day]; 0 or negative before the challenge starts.
  int dayNumber(DayKey day) => day.differenceInDays(startDay) + 1;

  /// Position inside the current cycle, 1..[lengthDays].
  int dayInCycle(DayKey day) {
    final n = dayNumber(day);
    if (n <= 0) return 0;
    return ((n - 1) % lengthDays) + 1;
  }

  int cycleOf(DayKey day) {
    final n = dayNumber(day);
    if (n <= 0) return 0;
    return (n - 1) ~/ lengthDays;
  }

  double progressInCycle(DayKey day) =>
      (dayInCycle(day) / lengthDays).clamp(0.0, 1.0);

  bool isCycleComplete(DayKey day) => dayNumber(day) > lengthDays * (cycle + 1);

  Habit? habitById(String id) {
    for (final habit in habits) {
      if (habit.id == id) return habit;
    }
    return null;
  }

  /// The next milestone the user is walking towards, or null past the last one.
  int? nextMilestone(int currentDay) {
    for (final m in kMilestoneDays) {
      if (m > currentDay) return m;
    }
    return null;
  }

  Challenge copyWith({
    Goal? goal,
    List<Habit>? habits,
    DayKey? startDay,
    int? lengthDays,
    int? cycle,
    int? streakFreezesRemaining,
  }) =>
      Challenge(
        id: id,
        goal: goal ?? this.goal,
        habits: habits ?? this.habits,
        startDay: startDay ?? this.startDay,
        lengthDays: lengthDays ?? this.lengthDays,
        cycle: cycle ?? this.cycle,
        streakFreezesRemaining:
            streakFreezesRemaining ?? this.streakFreezesRemaining,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'goal': goal.toJson(),
        'habits': habits.map((Habit h) => h.toJson()).toList(),
        'startDay': startDay.toString(),
        'lengthDays': lengthDays,
        'cycle': cycle,
        'streakFreezesRemaining': streakFreezesRemaining,
      };
}
