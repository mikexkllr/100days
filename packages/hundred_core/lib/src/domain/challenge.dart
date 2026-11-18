import 'package:meta/meta.dart';

import '../privacy/sharing.dart';
import '../util/dates.dart';
import 'goal.dart';
import 'habit.dart';

/// The challenge does not end on day 100 — that is the whole premise of
/// "100 days and far beyond". Day 100 closes a *cycle*; the streak keeps
/// counting and the user ascends into the next tier.
/// A tier is identified by its index; the app looks up the name. Tiers past
/// the named ones repeat the last emoji and are numbered by the app.
@immutable
class ChallengeTier {
  const ChallengeTier({required this.index, required this.emoji});

  final int index;
  final String emoji;

  /// True once the user has gone past every named tier, at which point the
  /// app numbers them instead ("Legend 3").
  bool get isNumbered => index >= kNamedTierCount;

  /// 2 for the first unnamed tier, 3 for the next, and so on.
  int get numberedRank => index - kNamedTierCount + 2;
}

/// How many tiers have a name of their own in the localizations.
const int kNamedTierCount = 6;

const List<String> _tierEmoji = <String>['🔥', '⚡', '🌘', '🌍', '🗿', '👑'];

ChallengeTier tierForCycle(int cycle) => ChallengeTier(
      index: cycle,
      emoji: cycle < _tierEmoji.length ? _tierEmoji[cycle] : '👑',
    );

/// How hard the challenge-wide streak is on a day that is not fully done.
///
/// Whatever the mode, a relapse resets the streak of the habit it was logged
/// on and of no other habit — failing at sugar does not undo a month in the
/// gym. The modes only decide what such a day does to the streak that spans
/// the whole challenge, and what a forgotten habit does to it.
enum StreakMode {
  /// A day counts once at least one habit is done; anything missed or
  /// relapsed only holds the streak. It breaks on a scheduled day with
  /// nothing done at all.
  gentle,

  /// Every scheduled habit is required, and a miss breaks the streak. A
  /// relapse costs only the habit it was logged on: done everything else,
  /// and the day counts.
  balanced,

  /// Every scheduled habit is required, and a miss breaks the streak. A
  /// relapse — with everything else done — holds the streak for the day
  /// but does not add to it.
  strict,
}

/// A past streak mode: [mode] applied to every day before [until]. Kept so
/// that switching to a gentler mode cannot bring a broken streak back.
@immutable
class StreakModeChange {
  const StreakModeChange({required this.until, required this.mode});

  factory StreakModeChange.fromJson(Map<String, dynamic> json) =>
      StreakModeChange(
        until: DayKey.parse(json['until'] as String),
        mode: _modeFromName(json['mode'] as String?),
      );

  final DayKey until;
  final StreakMode mode;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'until': until.toString(),
        'mode': mode.name,
      };
}

StreakMode _modeFromName(String? name) {
  for (final mode in StreakMode.values) {
    if (mode.name == name) return mode;
  }
  return StreakMode.balanced;
}

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
    this.sharing = const SharingPrefs(),
    this.streakMode = StreakMode.balanced,
    this.streakModeHistory = const <StreakModeChange>[],
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
        sharing: json['sharing'] == null
            ? const SharingPrefs()
            : SharingPrefs.fromJson(
                Map<String, dynamic>.from(json['sharing'] as Map)),
        streakMode: _modeFromName(json['streakMode'] as String?),
        streakModeHistory: ((json['streakModeHistory'] as List<dynamic>?) ??
                const <dynamic>[])
            .map((dynamic e) => StreakModeChange.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
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

  /// What friends get to see. Only ever present on the user's own, private
  /// copy of the challenge — the public copy carries the defaults.
  final SharingPrefs sharing;

  /// How strict the challenge-wide streak is from now on.
  final StreakMode streakMode;

  /// Earlier streak modes, oldest first.
  final List<StreakModeChange> streakModeHistory;

  /// The streak mode that applied on [day].
  StreakMode streakModeOn(DayKey day) {
    for (final change in streakModeHistory) {
      if (day.isBefore(change.until)) return change.mode;
    }
    return streakMode;
  }

  /// This challenge in [mode] from [from] on, with the old mode kept for
  /// every day before — history is not re-scored.
  Challenge withStreakMode(StreakMode mode, {required DayKey from}) {
    if (mode == streakMode) return this;
    return Challenge(
      id: id,
      goal: goal,
      habits: habits,
      startDay: startDay,
      lengthDays: lengthDays,
      cycle: cycle,
      streakFreezesRemaining: streakFreezesRemaining,
      sharing: sharing,
      streakMode: mode,
      streakModeHistory: <StreakModeChange>[
        ...streakModeHistory
            .where((StreakModeChange c) => c.until.isBefore(from)),
        if (from.isAfter(startDay))
          StreakModeChange(until: from, mode: streakModeOn(from.addDays(-1))),
      ],
    );
  }

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
    SharingPrefs? sharing,
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
        sharing: sharing ?? this.sharing,
        streakMode: streakMode,
        streakModeHistory: streakModeHistory,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'goal': goal.toJson(),
        'habits': habits.map((Habit h) => h.toJson()).toList(),
        'startDay': startDay.toString(),
        'lengthDays': lengthDays,
        'cycle': cycle,
        'streakFreezesRemaining': streakFreezesRemaining,
        if (!_isDefaultSharing) 'sharing': sharing.toJson(),
        if (streakMode != StreakMode.balanced) 'streakMode': streakMode.name,
        if (streakModeHistory.isNotEmpty)
          'streakModeHistory': streakModeHistory
              .map((StreakModeChange c) => c.toJson())
              .toList(),
      };

  bool get _isDefaultSharing =>
      sharing.privateHabits.isEmpty &&
      sharing.sharedSince.isEmpty &&
      sharing.shareStatement &&
      sharing.shareWorkouts;
}
