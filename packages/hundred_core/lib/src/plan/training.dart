import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../domain/goal.dart';
import '../domain/schedule.dart';
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

  /// Reps in reserve — the same effort as [rpe], said the way most lifting
  /// apps say it: "stop two reps before failure" is RIR 2, RPE 8.
  int get rir => (10 - rpe).round().clamp(0, 5);

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
  chest,
  back,
  shoulders,
  arms,
}

/// How the training week is arranged. The user picks one; the app proposes
/// [recommendedSplit] for their number of training days.
///
/// Sessions rotate across training days rather than being pinned to
/// weekdays, so any split works with any number of days: Push/Pull/Legs on
/// four days runs Push, Pull, Legs, Push and carries on with Pull next week.
enum SplitKind {
  fullBody,
  upperLower,
  pushPullLegs,
  pplUpperLower,
  broSplit,
}

/// One exercise in a session, as the user configured it.
///
/// The plan builder starts every slot from a sensible prescription; from
/// there the user owns it — swap the movement, add a set, change the rep
/// range. Periodisation (build weeks, deload) is applied on top.
@immutable
class ExerciseSlot {
  const ExerciseSlot({
    required this.exerciseId,
    required this.sets,
    required this.repsLow,
    required this.repsHigh,
    required this.rpe,
    required this.restSeconds,
  });

  factory ExerciseSlot.fromJson(Map<String, dynamic> json) => ExerciseSlot(
        exerciseId: json['id'] as String,
        sets: (json['sets'] as num).toInt(),
        repsLow: (json['lo'] as num).toInt(),
        repsHigh: (json['hi'] as num).toInt(),
        rpe: (json['rpe'] as num).toDouble(),
        restSeconds: (json['rest'] as num?)?.toInt() ?? 90,
      );

  final String exerciseId;
  final int sets;
  final int repsLow;
  final int repsHigh;
  final double rpe;
  final int restSeconds;

  /// Null for an id this version of the library does not know — a plan
  /// written by a newer app on another device must not crash this one.
  Exercise? get exercise => kExerciseById[exerciseId];

  int get rir => (10 - rpe).round().clamp(0, 5);

  ExerciseSlot copyWith({
    String? exerciseId,
    int? sets,
    int? repsLow,
    int? repsHigh,
    double? rpe,
    int? restSeconds,
  }) {
    final low = repsLow ?? this.repsLow;
    final high = math.max(repsHigh ?? this.repsHigh, low);
    return ExerciseSlot(
      exerciseId: exerciseId ?? this.exerciseId,
      sets: (sets ?? this.sets).clamp(1, 10),
      repsLow: low.clamp(1, 50),
      repsHigh: high.clamp(1, 50),
      rpe: (rpe ?? this.rpe).clamp(5.0, 10.0),
      restSeconds: (restSeconds ?? this.restSeconds).clamp(15, 600),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': exerciseId,
        'sets': sets,
        'lo': repsLow,
        'hi': repsHigh,
        'rpe': rpe,
        'rest': restSeconds,
      };

  @override
  bool operator ==(Object other) =>
      other is ExerciseSlot &&
      other.exerciseId == exerciseId &&
      other.sets == sets &&
      other.repsLow == repsLow &&
      other.repsHigh == repsHigh &&
      other.rpe == rpe &&
      other.restSeconds == restSeconds;

  @override
  int get hashCode =>
      Object.hash(exerciseId, sets, repsLow, repsHigh, rpe, restSeconds);
}

/// One session of the rotation and its exercises, in order.
@immutable
class SessionPlan {
  const SessionPlan({required this.kind, required this.exercises});

  factory SessionPlan.fromJson(Map<String, dynamic> json) => SessionPlan(
        kind: WorkoutKind.values.asNameMap()[json['kind'] as String] ??
            WorkoutKind.fullBodyA,
        exercises: (json['ex'] as List<dynamic>)
            .map((dynamic e) =>
                ExerciseSlot.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
      );

  final WorkoutKind kind;
  final List<ExerciseSlot> exercises;

  int get totalSets =>
      exercises.fold(0, (int sum, ExerciseSlot s) => sum + s.sets);

  SessionPlan copyWith({List<ExerciseSlot>? exercises}) => SessionPlan(
        kind: kind,
        exercises: exercises ?? this.exercises,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.name,
        'ex': exercises.map((ExerciseSlot s) => s.toJson()).toList(),
      };
}

/// The user's training plan as configured: a split and the sessions it
/// rotates through. Stored on [Goal], so it is part of the signed challenge
/// and survives a restore from the recovery key.
@immutable
class TrainingSetup {
  const TrainingSetup({required this.split, required this.sessions});

  factory TrainingSetup.fromJson(Map<String, dynamic> json) => TrainingSetup(
        split: SplitKind.values.asNameMap()[json['split'] as String] ??
            SplitKind.fullBody,
        sessions: (json['sessions'] as List<dynamic>)
            .map((dynamic e) =>
                SessionPlan.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
      );

  final SplitKind split;
  final List<SessionPlan> sessions;

  TrainingSetup withSession(int index, SessionPlan session) => TrainingSetup(
        split: split,
        sessions: <SessionPlan>[
          for (var i = 0; i < sessions.length; i++)
            i == index ? session : sessions[i],
        ],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'split': split.name,
        'sessions': sessions.map((SessionPlan s) => s.toJson()).toList(),
      };
}

@immutable
class Workout {
  const Workout({
    required this.kind,
    required this.weekday,
    required this.blocks,
    required this.estimatedMinutes,
    this.sessionIndex = 0,
  });

  final WorkoutKind kind;
  final int weekday;
  final List<PlannedSet> blocks;
  final int estimatedMinutes;

  /// Position of this session in [TrainingSetup.sessions]; the workout
  /// logger uses it to find what the user lifted the last time round.
  final int sessionIndex;

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
    required this.setup,
  });

  final SplitKind split;
  final int daysPerWeek;
  final List<TrainingWeek> weeks;

  /// What the weeks were built from, for the editor.
  final TrainingSetup setup;

  TrainingWeek weekFor(DayKey startDay, DayKey day) {
    final dayNumber = day.differenceInDays(startDay);
    if (dayNumber < 0 || weeks.isEmpty) return weeks.first;
    return weeks[(dayNumber ~/ 7) % weeks.length];
  }

  Workout? workoutFor(DayKey startDay, DayKey day) =>
      weekFor(startDay, day).workoutOn(day.toDateTime().weekday);
}

/// One exercise position in a session template: a movement pattern, and
/// optionally which muscle or which concrete movements the slot is meant
/// for. A push day's arm slot is a triceps slot; a pull day's is biceps.
class _Slot {
  const _Slot(this.pattern, {this.muscle, this.prefer = const <String>[]});

  final MovementPattern pattern;
  final MuscleGroup? muscle;
  final List<String> prefer;
}

const Map<WorkoutKind, List<_Slot>> _templates = <WorkoutKind, List<_Slot>>{
  WorkoutKind.fullBodyA: <_Slot>[
    _Slot(MovementPattern.squat),
    _Slot(MovementPattern.horizontalPush),
    _Slot(MovementPattern.horizontalPull),
    _Slot(MovementPattern.core),
  ],
  WorkoutKind.fullBodyB: <_Slot>[
    _Slot(MovementPattern.hinge),
    _Slot(MovementPattern.verticalPush),
    _Slot(MovementPattern.verticalPull),
    _Slot(MovementPattern.isolationLegs),
  ],
  WorkoutKind.fullBodyC: <_Slot>[
    _Slot(MovementPattern.lunge),
    _Slot(MovementPattern.horizontalPush),
    _Slot(MovementPattern.horizontalPull),
    _Slot(MovementPattern.carry),
  ],
  WorkoutKind.push: <_Slot>[
    _Slot(MovementPattern.horizontalPush),
    _Slot(MovementPattern.verticalPush),
    _Slot(MovementPattern.isolationShoulders,
        prefer: <String>['lateral_raise', 'cable_lateral_raise']),
    _Slot(MovementPattern.isolationArms, muscle: MuscleGroup.triceps),
  ],
  WorkoutKind.pull: <_Slot>[
    _Slot(MovementPattern.verticalPull),
    _Slot(MovementPattern.horizontalPull),
    _Slot(MovementPattern.isolationArms, muscle: MuscleGroup.biceps),
    _Slot(MovementPattern.isolationShoulders,
        prefer: <String>['face_pull', 'rear_delt_fly']),
  ],
  WorkoutKind.legs: <_Slot>[
    _Slot(MovementPattern.squat),
    _Slot(MovementPattern.hinge),
    _Slot(MovementPattern.lunge),
    _Slot(MovementPattern.isolationLegs),
  ],
  WorkoutKind.upper: <_Slot>[
    _Slot(MovementPattern.horizontalPush),
    _Slot(MovementPattern.verticalPull),
    _Slot(MovementPattern.verticalPush),
    _Slot(MovementPattern.horizontalPull),
    _Slot(MovementPattern.isolationArms),
  ],
  WorkoutKind.lower: <_Slot>[
    _Slot(MovementPattern.squat),
    _Slot(MovementPattern.hinge),
    _Slot(MovementPattern.lunge),
    _Slot(MovementPattern.core),
  ],
  WorkoutKind.chest: <_Slot>[
    _Slot(MovementPattern.horizontalPush),
    _Slot(MovementPattern.horizontalPush,
        prefer: <String>['incline_bench', 'incline_db_press']),
    _Slot(MovementPattern.isolationChest),
    _Slot(MovementPattern.isolationArms, muscle: MuscleGroup.triceps),
  ],
  WorkoutKind.back: <_Slot>[
    _Slot(MovementPattern.verticalPull),
    _Slot(MovementPattern.horizontalPull),
    _Slot(MovementPattern.horizontalPull),
    _Slot(MovementPattern.isolationArms, muscle: MuscleGroup.biceps),
  ],
  WorkoutKind.shoulders: <_Slot>[
    _Slot(MovementPattern.verticalPush),
    _Slot(MovementPattern.isolationShoulders,
        prefer: <String>['lateral_raise', 'cable_lateral_raise']),
    _Slot(MovementPattern.isolationShoulders,
        prefer: <String>['rear_delt_fly', 'face_pull']),
    _Slot(MovementPattern.core),
  ],
  WorkoutKind.arms: <_Slot>[
    _Slot(MovementPattern.isolationArms, muscle: MuscleGroup.biceps),
    _Slot(MovementPattern.isolationArms, muscle: MuscleGroup.triceps),
    _Slot(MovementPattern.isolationArms,
        muscle: MuscleGroup.biceps, prefer: <String>['hammer_curl']),
    _Slot(MovementPattern.isolationArms, muscle: MuscleGroup.triceps),
  ],
};

/// The sessions a split rotates through.
List<WorkoutKind> sessionsOf(SplitKind split, {int daysPerWeek = 3}) {
  switch (split) {
    case SplitKind.fullBody:
      // Two days a week alternate A and B; three or more add C.
      return daysPerWeek <= 2
          ? const <WorkoutKind>[WorkoutKind.fullBodyA, WorkoutKind.fullBodyB]
          : const <WorkoutKind>[
              WorkoutKind.fullBodyA,
              WorkoutKind.fullBodyB,
              WorkoutKind.fullBodyC,
            ];
    case SplitKind.upperLower:
      return const <WorkoutKind>[WorkoutKind.upper, WorkoutKind.lower];
    case SplitKind.pushPullLegs:
      return const <WorkoutKind>[
        WorkoutKind.push,
        WorkoutKind.pull,
        WorkoutKind.legs,
      ];
    case SplitKind.pplUpperLower:
      return const <WorkoutKind>[
        WorkoutKind.push,
        WorkoutKind.pull,
        WorkoutKind.legs,
        WorkoutKind.upper,
        WorkoutKind.lower,
      ];
    case SplitKind.broSplit:
      return const <WorkoutKind>[
        WorkoutKind.chest,
        WorkoutKind.back,
        WorkoutKind.legs,
        WorkoutKind.shoulders,
        WorkoutKind.arms,
      ];
  }
}

/// The split the app proposes for a number of training days. Fewer days
/// means each session has to be more general; more days lets sessions
/// specialise without cooking the same muscles twice.
SplitKind recommendedSplit(int daysPerWeek) {
  switch (daysPerWeek.clamp(2, 6)) {
    case 2:
    case 3:
      return SplitKind.fullBody;
    case 4:
      return SplitKind.upperLower;
    case 5:
      return SplitKind.pplUpperLower;
    default:
      return SplitKind.pushPullLegs;
  }
}

/// Every split, the recommended one first, then the ones that still make
/// sense for this many days, then the rest.
List<SplitKind> splitOptions(int daysPerWeek) {
  final recommended = recommendedSplit(daysPerWeek);
  final days = daysPerWeek.clamp(2, 6);
  int fit(SplitKind split) {
    if (split == recommended) return 0;
    final length = sessionsOf(split, daysPerWeek: days).length;
    // A rotation no longer than the week sees every session at least once
    // a week; anything longer stretches muscles out to once every ten days.
    return length <= days ? 1 : 2;
  }

  return SplitKind.values.toList()
    ..sort((SplitKind a, SplitKind b) {
      final byFit = fit(a).compareTo(fit(b));
      return byFit != 0 ? byFit : a.index.compareTo(b.index);
    });
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

/// The starting prescription for [exercise] — what a slot gets when the
/// user adds a movement or swaps one compound for an isolation exercise.
ExerciseSlot defaultSlotFor(Exercise exercise, Goal goal) {
  final p = _prescription(goal, exercise.isCompound);
  return ExerciseSlot(
    exerciseId: exercise.id,
    sets: p.sets,
    repsLow: p.low,
    repsHigh: p.high,
    rpe: p.rpe,
    restSeconds: p.rest,
  );
}

/// Replaces the movement in [slot] with [exercise], keeping the user's own
/// numbers when the two are the same kind of movement.
ExerciseSlot swapSlot(ExerciseSlot slot, Exercise exercise, Goal goal) {
  final before = slot.exercise;
  if (before != null && before.isCompound == exercise.isCompound) {
    return slot.copyWith(exerciseId: exercise.id);
  }
  return defaultSlotFor(exercise, goal);
}

/// The proposed exercises for one session: the starting point the user then
/// edits.
SessionPlan suggestSession(WorkoutKind kind, Goal goal) {
  final used = <String>{};
  final slots = <ExerciseSlot>[];
  for (final _Slot slot in _templates[kind]!) {
    Exercise? exercise;
    for (final String id in slot.prefer) {
      final candidate = kExerciseById[id];
      if (candidate != null &&
          candidate.availableWith(goal.equipment) &&
          !used.contains(id)) {
        exercise = candidate;
        break;
      }
    }
    exercise ??= pickExercise(
      slot.pattern,
      goal.equipment,
      exclude: used,
      muscle: slot.muscle,
    );
    if (exercise == null) continue;
    used.add(exercise.id);
    slots.add(defaultSlotFor(exercise, goal));
  }
  return SessionPlan(kind: kind, exercises: slots);
}

/// The plan the app proposes: the chosen (or recommended) split with
/// exercises picked for the user's equipment and experience.
TrainingSetup suggestTrainingSetup(Goal goal, {SplitKind? split}) {
  final days = goal.trainingDaysPerWeek.clamp(2, 6);
  final chosen = split ?? recommendedSplit(days);
  return TrainingSetup(
    split: chosen,
    sessions: <SessionPlan>[
      for (final WorkoutKind kind in sessionsOf(chosen, daysPerWeek: days))
        suggestSession(kind, goal),
    ],
  );
}

/// Builds a mesocycle-based plan from the user's [TrainingSetup], or from
/// the suggestion when they never edited one.
///
/// Four-week blocks: three weeks of adding a set per compound, then a deload
/// at roughly 60 % volume. Without the deload, 100 straight days of adding
/// volume ends in a stalled lifter or an injured one — both quit.
TrainingPlan buildTrainingPlan(Goal goal, {int totalWeeks = 15}) {
  final daysPerWeek = goal.trainingDaysPerWeek.clamp(2, 6);
  final setup = goal.training ?? suggestTrainingSetup(goal);
  final weekdays = kWeekdaySpread[daysPerWeek]!;

  final weeks = <TrainingWeek>[];
  for (var week = 1; week <= totalWeeks; week++) {
    final positionInBlock = (week - 1) % 4;
    final isDeload = positionInBlock == 3;
    final workouts = <Workout>[];

    for (var i = 0; i < weekdays.length && setup.sessions.isNotEmpty; i++) {
      // Rotate rather than pin: day i of week w is training day number
      // (w - 1) * days + i, and the sessions follow each other in order.
      final sessionIndex =
          ((week - 1) * daysPerWeek + i) % setup.sessions.length;
      final session = setup.sessions[sessionIndex];
      final blocks = <PlannedSet>[];

      for (final ExerciseSlot slot in session.exercises) {
        final exercise = slot.exercise;
        if (exercise == null) continue;
        final sets = isDeload
            ? (slot.sets * 0.6).ceil()
            : slot.sets + (exercise.isCompound ? positionInBlock : 0);
        blocks.add(PlannedSet(
          exerciseId: slot.exerciseId,
          sets: sets,
          repsLow: slot.repsLow,
          repsHigh: slot.repsHigh,
          rpe: isDeload
              ? math.max(slot.rpe - 2, 5)
              : math.min(slot.rpe + positionInBlock * 0.5, 10),
          restSeconds: slot.restSeconds,
        ));
      }

      final totalSets =
          blocks.fold(0, (int sum, PlannedSet b) => sum + b.sets);
      workouts.add(Workout(
        kind: session.kind,
        weekday: weekdays[i],
        blocks: blocks,
        sessionIndex: sessionIndex,
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
    split: setup.split,
    daysPerWeek: daysPerWeek,
    weeks: weeks,
    setup: setup,
  );
}
