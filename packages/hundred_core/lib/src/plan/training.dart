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

@immutable
class Workout {
  const Workout({
    required this.nameDe,
    required this.focusDe,
    required this.weekday,
    required this.blocks,
    required this.estimatedMinutes,
  });

  final String nameDe;
  final String focusDe;
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
    required this.phaseDe,
    required this.isDeload,
    required this.workouts,
  });

  final int weekNumber;
  final String phaseDe;
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
    required this.splitNameDe,
    required this.daysPerWeek,
    required this.weeks,
    required this.rationaleDe,
  });

  final String splitNameDe;
  final int daysPerWeek;
  final List<TrainingWeek> weeks;
  final String rationaleDe;

  TrainingWeek weekFor(DayKey startDay, DayKey day) {
    final dayNumber = day.differenceInDays(startDay);
    if (dayNumber < 0 || weeks.isEmpty) return weeks.first;
    return weeks[(dayNumber ~/ 7) % weeks.length];
  }

  Workout? workoutFor(DayKey startDay, DayKey day) =>
      weekFor(startDay, day).workoutOn(day.toDateTime().weekday);
}

/// A single training day's template: a name and the movement patterns it hits.
class _SessionTemplate {
  const _SessionTemplate(this.nameDe, this.focusDe, this.patterns);
  final String nameDe;
  final String focusDe;
  final List<MovementPattern> patterns;
}

const _SessionTemplate _fullBodyA = _SessionTemplate(
  'Ganzkörper A',
  'Knie, Druck, Zug',
  <MovementPattern>[
    MovementPattern.squat,
    MovementPattern.horizontalPush,
    MovementPattern.horizontalPull,
    MovementPattern.core,
  ],
);

const _SessionTemplate _fullBodyB = _SessionTemplate(
  'Ganzkörper B',
  'Hüfte, Überkopf, Klimmzug',
  <MovementPattern>[
    MovementPattern.hinge,
    MovementPattern.verticalPush,
    MovementPattern.verticalPull,
    MovementPattern.isolationLegs,
  ],
);

const _SessionTemplate _fullBodyC = _SessionTemplate(
  'Ganzkörper C',
  'Einbeinig, Druck, Zug',
  <MovementPattern>[
    MovementPattern.lunge,
    MovementPattern.horizontalPush,
    MovementPattern.horizontalPull,
    MovementPattern.carry,
  ],
);

const _SessionTemplate _push = _SessionTemplate(
  'Push',
  'Brust, Schultern, Trizeps',
  <MovementPattern>[
    MovementPattern.horizontalPush,
    MovementPattern.verticalPush,
    MovementPattern.isolationShoulders,
    MovementPattern.isolationArms,
  ],
);

const _SessionTemplate _pull = _SessionTemplate(
  'Pull',
  'Rücken, Bizeps, hintere Schulter',
  <MovementPattern>[
    MovementPattern.verticalPull,
    MovementPattern.horizontalPull,
    MovementPattern.isolationArms,
    MovementPattern.isolationShoulders,
  ],
);

const _SessionTemplate _legs = _SessionTemplate(
  'Legs',
  'Quads, Hamstrings, Glutes',
  <MovementPattern>[
    MovementPattern.squat,
    MovementPattern.hinge,
    MovementPattern.lunge,
    MovementPattern.isolationLegs,
  ],
);

const _SessionTemplate _upper = _SessionTemplate(
  'Oberkörper',
  'Druck und Zug',
  <MovementPattern>[
    MovementPattern.horizontalPush,
    MovementPattern.verticalPull,
    MovementPattern.verticalPush,
    MovementPattern.horizontalPull,
    MovementPattern.isolationArms,
  ],
);

const _SessionTemplate _lower = _SessionTemplate(
  'Unterkörper',
  'Beine und Rumpf',
  <MovementPattern>[
    MovementPattern.squat,
    MovementPattern.hinge,
    MovementPattern.lunge,
    MovementPattern.core,
  ],
);

/// Split selection. Fewer days means each session has to be more general;
/// more days lets sessions specialise without cooking the same muscles twice.
({String name, List<_SessionTemplate> sessions}) _splitFor(int daysPerWeek) {
  switch (daysPerWeek.clamp(2, 6)) {
    case 2:
      return (name: 'Ganzkörper 2x', sessions: <_SessionTemplate>[
        _fullBodyA,
        _fullBodyB,
      ]);
    case 3:
      return (name: 'Ganzkörper 3x', sessions: <_SessionTemplate>[
        _fullBodyA,
        _fullBodyB,
        _fullBodyC,
      ]);
    case 4:
      return (name: 'Upper / Lower', sessions: <_SessionTemplate>[
        _upper,
        _lower,
        _upper,
        _lower,
      ]);
    case 5:
      return (name: 'Push / Pull / Legs + Upper / Lower',
          sessions: <_SessionTemplate>[_push, _pull, _legs, _upper, _lower]);
    default:
      return (name: 'Push / Pull / Legs 2x', sessions: <_SessionTemplate>[
        _push,
        _pull,
        _legs,
        _push,
        _pull,
        _legs,
      ]);
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
        nameDe: template.nameDe,
        focusDe: template.focusDe,
        weekday: weekdays[i],
        blocks: blocks,
        // ~3 min per working set including rest, plus a 10 min warm-up.
        estimatedMinutes: 10 + totalSets * 3,
      ));
    }

    weeks.add(TrainingWeek(
      weekNumber: week,
      phaseDe: isDeload
          ? 'Deload'
          : 'Aufbau ${positionInBlock + 1}/3 · Block ${((week - 1) ~/ 4) + 1}',
      isDeload: isDeload,
      workouts: workouts,
    ));
  }

  return TrainingPlan(
    splitNameDe: split.name,
    daysPerWeek: daysPerWeek,
    weeks: weeks,
    rationaleDe: '$daysPerWeek Trainingstage pro Woche als '
        '"${split.name}". Drei Wochen Aufbau, dann eine Deload-Woche — '
        'so hältst du 100 Tage durch, ohne auszubrennen.',
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
