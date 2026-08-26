import 'package:meta/meta.dart';

import '../domain/goal.dart';
import '../util/dates.dart';
import 'exercises.dart';

@immutable
class PlannedSet {
  const PlannedSet({
    required this.exerciseId,
    required this.sets,
    required this.repsLow,
    required this.repsHigh,
    required this.rpe,
    required this.restSeconds,
  });

  final String exerciseId;
  final int sets;
  final int repsLow;
  final int repsHigh;

  /// Rate of perceived exertion, 1–10. The plan prescribes effort rather than
  /// absolute weight because we have no idea what the user can lift, and
  /// asking them to guess a 1RM in onboarding is how people get hurt.
  final double rpe;

  final int restSeconds;

  Exercise get exercise => kExerciseById[exerciseId]!;

  String get repRange =>
      repsLow == repsHigh ? '$repsLow' : '$repsLow–$repsHigh';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'exerciseId': exerciseId,
        'sets': sets,
        'repsLow': repsLow,
        'repsHigh': repsHigh,
        'rpe': rpe,
        'restSeconds': restSeconds,
      };
}

/// Which session this is. Name and focus line come from the app's
/// localizations, keyed by this.
enum WorkoutKind {
  fullBodyA,
  fullBodyB,
  fullBodyC,
  push,
  pull,
  legs,
  upper,
  lower,
}

/// How the training week is arranged.
enum SplitKind {
  fullBodyTwice,
  fullBodyThrice,
  upperLower,
  pplPlusUpperLower,
  pplTwice,
}

@immutable
class Workout {
  const Workout({
    required this.kind,
    required this.weekday,
    required this.blocks,
    required this.estimatedMinutes,
  });

  final WorkoutKind kind;
  final int weekday;
  final List<PlannedSet> blocks;
  final int estimatedMinutes;

  int get totalSets =>
      blocks.fold(0, (int sum, PlannedSet b) => sum + b.sets);
}

@immutable
class TrainingWeek {
  const TrainingWeek({
    required this.weekNumber,
    required this.blockNumber,
    required this.weekInBlock,
    required this.isDeload,
    required this.workouts,
  });

  final int weekNumber;

  /// 1-based four-week mesocycle this week belongs to.
  final int blockNumber;

  /// 1..3 during accumulation, 4 on the deload week.
  final int weekInBlock;

  final bool isDeload;
  final List<Workout> workouts;

  Workout? workoutOn(int weekday) {
    for (final w in workouts) {
      if (w.weekday == weekday) return w;
    }
    return null;
  }
}

@immutable
class TrainingPlan {
  const TrainingPlan({
    required this.split,
    required this.daysPerWeek,
    required this.weeks,
  });

  final SplitKind split;
  final int daysPerWeek;
  final List<TrainingWeek> weeks;

  TrainingWeek weekFor(DayKey startDay, DayKey day) {
    final dayNumber = day.differenceInDays(startDay);
    if (dayNumber < 0 || weeks.isEmpty) return weeks.first;
    return weeks[(dayNumber ~/ 7) % weeks.length];
  }

  Workout? workoutFor(DayKey startDay, DayKey day) =>
      weekFor(startDay, day).workoutOn(day.toDateTime().weekday);
}

/// A single training day's template: which session it is and which movement
/// patterns it hits.
class _SessionTemplate {
  const _SessionTemplate(this.kind, this.patterns);
  final WorkoutKind kind;
  final List<MovementPattern> patterns;
}

const _SessionTemplate _fullBodyA = _SessionTemplate(
  WorkoutKind.fullBodyA,
  <MovementPattern>[
    MovementPattern.squat,
    MovementPattern.horizontalPush,
    MovementPattern.horizontalPull,
    MovementPattern.core,
  ],
);

const _SessionTemplate _fullBodyB = _SessionTemplate(
  WorkoutKind.fullBodyB,
  <MovementPattern>[
    MovementPattern.hinge,
    MovementPattern.verticalPush,
    MovementPattern.verticalPull,
    MovementPattern.isolationLegs,
  ],
);

const _SessionTemplate _fullBodyC = _SessionTemplate(
  WorkoutKind.fullBodyC,
  <MovementPattern>[
    MovementPattern.lunge,
    MovementPattern.horizontalPush,
    MovementPattern.horizontalPull,
    MovementPattern.carry,
  ],
);

const _SessionTemplate _push = _SessionTemplate(
  WorkoutKind.push,
  <MovementPattern>[
    MovementPattern.horizontalPush,
    MovementPattern.verticalPush,
    MovementPattern.isolationShoulders,
    MovementPattern.isolationArms,
  ],
);

const _SessionTemplate _pull = _SessionTemplate(
  WorkoutKind.pull,
  <MovementPattern>[
    MovementPattern.verticalPull,
    MovementPattern.horizontalPull,
    MovementPattern.isolationArms,
    MovementPattern.isolationShoulders,
  ],
);

const _SessionTemplate _legs = _SessionTemplate(
  WorkoutKind.legs,
  <MovementPattern>[
    MovementPattern.squat,
    MovementPattern.hinge,
    MovementPattern.lunge,
    MovementPattern.isolationLegs,
  ],
);

const _SessionTemplate _upper = _SessionTemplate(
  WorkoutKind.upper,
  <MovementPattern>[
    MovementPattern.horizontalPush,
    MovementPattern.verticalPull,
    MovementPattern.verticalPush,
    MovementPattern.horizontalPull,
    MovementPattern.isolationArms,
  ],
);

const _SessionTemplate _lower = _SessionTemplate(
  WorkoutKind.lower,
  <MovementPattern>[
    MovementPattern.squat,
    MovementPattern.hinge,
    MovementPattern.lunge,
    MovementPattern.core,
  ],
);

/// Split selection. Fewer days means each session has to be more general;
/// more days lets sessions specialise without cooking the same muscles twice.
({SplitKind kind, List<_SessionTemplate> sessions}) _splitFor(int daysPerWeek) {
  switch (daysPerWeek.clamp(2, 6)) {
    case 2:
      return (
        kind: SplitKind.fullBodyTwice,
        sessions: <_SessionTemplate>[_fullBodyA, _fullBodyB],
      );
    case 3:
      return (
        kind: SplitKind.fullBodyThrice,
        sessions: <_SessionTemplate>[_fullBodyA, _fullBodyB, _fullBodyC],
      );
    case 4:
      return (
        kind: SplitKind.upperLower,
        sessions: <_SessionTemplate>[_upper, _lower, _upper, _lower],
      );
    case 5:
      return (
        kind: SplitKind.pplPlusUpperLower,
        sessions: <_SessionTemplate>[_push, _pull, _legs, _upper, _lower],
      );
    default:
      return (
        kind: SplitKind.pplTwice,
        sessions: <_SessionTemplate>[_push, _pull, _legs, _push, _pull, _legs],
      );
  }
}

({int low, int high, double rpe, int sets, int rest}) _prescription(
  Goal goal,
  bool isCompound,
) {
  final experience = goal.experience;
  final hypertrophy = goal.archetype == GoalArchetype.buildMuscle;

  final sets = switch (experience) {
    TrainingExperience.beginner => isCompound ? 3 : 2,
    TrainingExperience.intermediate => isCompound ? 4 : 3,
    TrainingExperience.advanced => isCompound ? 5 : 3,
  };

  if (isCompound) {
    return (
      low: hypertrophy ? 6 : 8,
      high: hypertrophy ? 10 : 12,
      rpe: experience == TrainingExperience.beginner ? 7.0 : 8.0,
      sets: sets,
      rest: hypertrophy ? 150 : 120,
    );
  }
  return (
    low: 10,
    high: 15,
    rpe: experience == TrainingExperience.beginner ? 7.0 : 8.5,
    sets: sets,
    rest: 75,
  );
}

/// Builds a mesocycle-based plan.
///
/// Four-week blocks: three weeks of adding a set per compound, then a deload
/// at roughly 60 % volume. Without the deload, 100 straight days of adding
/// volume ends in a stalled lifter or an injured one — both quit.
TrainingPlan buildTrainingPlan(Goal goal, {int totalWeeks = 15}) {
  final daysPerWeek = goal.trainingDaysPerWeek.clamp(2, 6);
  final split = _splitFor(daysPerWeek);
  final weekdays = _trainingWeekdays(daysPerWeek);

  final weeks = <TrainingWeek>[];
  for (var week = 1; week <= totalWeeks; week++) {
    final positionInBlock = (week - 1) % 4;
    final isDeload = positionInBlock == 3;
    final workouts = <Workout>[];

    for (var i = 0; i < split.sessions.length && i < weekdays.length; i++) {
      final template = split.sessions[i];
      final used = <String>{};
      final blocks = <PlannedSet>[];

      for (final pattern in template.patterns) {
        final exercise = pickExercise(pattern, goal.equipment, exclude: used);
        if (exercise == null) continue;
        used.add(exercise.id);
        final base = _prescription(goal, exercise.isCompound);
        final sets = isDeload
            ? (base.sets * 0.6).ceil()
            : base.sets + (exercise.isCompound ? positionInBlock : 0);
        blocks.add(PlannedSet(
          exerciseId: exercise.id,
          sets: sets,
          repsLow: base.low,
          repsHigh: base.high,
          rpe: isDeload ? base.rpe - 2 : base.rpe + positionInBlock * 0.5,
          restSeconds: base.rest,
        ));
      }

      final totalSets =
          blocks.fold(0, (int sum, PlannedSet b) => sum + b.sets);
      workouts.add(Workout(
        kind: template.kind,
        weekday: weekdays[i],
        blocks: blocks,
        // ~3 min per working set including rest, plus a 10 min warm-up.
        estimatedMinutes: 10 + totalSets * 3,
      ));
    }

    weeks.add(TrainingWeek(
      weekNumber: week,
      blockNumber: ((week - 1) ~/ 4) + 1,
      weekInBlock: positionInBlock + 1,
      isDeload: isDeload,
      workouts: workouts,
    ));
  }

  return TrainingPlan(
    split: split.kind,
    daysPerWeek: daysPerWeek,
    weeks: weeks,
  );
}

List<int> _trainingWeekdays(int daysPerWeek) {
  switch (daysPerWeek) {
    case 2:
      return <int>[DateTime.monday, DateTime.thursday];
    case 3:
      return <int>[DateTime.monday, DateTime.wednesday, DateTime.friday];
    case 4:
      return <int>[
        DateTime.monday,
        DateTime.tuesday,
        DateTime.thursday,
        DateTime.friday,
      ];
    case 5:
      return <int>[
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.friday,
        DateTime.saturday,
      ];
    default:
      return <int>[
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
      ];
  }
}
