import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

Goal _goal({
  int days = 4,
  EquipmentAccess equipment = EquipmentAccess.fullGym,
  TrainingSetup? training,
}) =>
    Goal(
      archetype: GoalArchetype.buildMuscle,
      statement: 'Masse',
      experience: TrainingExperience.intermediate,
      equipment: equipment,
      trainingDaysPerWeek: days,
      training: training,
    );

void main() {
  group('split choice', () {
    test('every day count recommends its split first', () {
      for (var days = 2; days <= 6; days++) {
        expect(splitOptions(days).first, recommendedSplit(days));
        expect(splitOptions(days).toSet(), SplitKind.values.toSet());
      }
    });

    test('a chosen split is used whatever the day count', () {
      final goal = _goal(days: 3);
      final setup = suggestTrainingSetup(goal, split: SplitKind.broSplit);
      expect(setup.split, SplitKind.broSplit);
      expect(setup.sessions.map((SessionPlan s) => s.kind), <WorkoutKind>[
        WorkoutKind.chest,
        WorkoutKind.back,
        WorkoutKind.legs,
        WorkoutKind.shoulders,
        WorkoutKind.arms,
      ]);
    });

    test('sessions rotate across weeks instead of repeating the same days',
        () {
      final goal = _goal(
        days: 4,
        training: suggestTrainingSetup(_goal(days: 4),
            split: SplitKind.pushPullLegs),
      );
      final plan = buildTrainingPlan(goal);
      final kinds = <WorkoutKind>[
        for (final TrainingWeek w in plan.weeks.take(2))
          for (final Workout workout in w.workouts) workout.kind,
      ];
      expect(kinds, <WorkoutKind>[
        WorkoutKind.push,
        WorkoutKind.pull,
        WorkoutKind.legs,
        WorkoutKind.push,
        WorkoutKind.pull,
        WorkoutKind.legs,
        WorkoutKind.push,
        WorkoutKind.pull,
      ]);
      expect(plan.weeks[1].workouts.first.sessionIndex, 1);
    });
  });

  group('suggested exercises', () {
    test('a push day trains triceps and a pull day biceps', () {
      final goal = _goal();
      final push = suggestSession(WorkoutKind.push, goal);
      final pull = suggestSession(WorkoutKind.pull, goal);
      MuscleGroup? armOf(SessionPlan s) => s.exercises
          .map((ExerciseSlot e) => e.exercise!)
          .where((Exercise e) => e.pattern == MovementPattern.isolationArms)
          .map((Exercise e) => e.primary)
          .firstOrNull;
      expect(armOf(push), MuscleGroup.triceps);
      expect(armOf(pull), MuscleGroup.biceps);
    });

    test('no suggested session repeats an exercise', () {
      for (final WorkoutKind kind in WorkoutKind.values) {
        for (final EquipmentAccess access in EquipmentAccess.values) {
          final ids = suggestSession(kind, _goal(equipment: access))
              .exercises
              .map((ExerciseSlot e) => e.exerciseId)
              .toList();
          expect(ids.toSet(), hasLength(ids.length), reason: '$kind $access');
        }
      }
    });

    test('a full gym chest day uses gym equipment', () {
      final chest = suggestSession(WorkoutKind.chest, _goal());
      expect(chest.exercises.map((ExerciseSlot e) => e.exerciseId),
          containsAll(<String>['bench_press', 'incline_bench', 'pec_deck']));
    });
  });

  group('editing', () {
    test('the plan is built from the user\'s own setup', () {
      final base = suggestTrainingSetup(_goal(days: 2),
          split: SplitKind.fullBody);
      final custom = base.withSession(
        0,
        base.sessions[0].copyWith(exercises: <ExerciseSlot>[
          base.sessions[0].exercises.first.copyWith(sets: 6),
          defaultSlotFor(kExerciseById['hip_thrust']!, _goal()),
        ]),
      );
      final plan = buildTrainingPlan(_goal(days: 2, training: custom));
      final first = plan.weeks.first.workouts.first;
      expect(first.blocks.map((PlannedSet b) => b.exerciseId),
          <String>[custom.sessions[0].exercises.first.exerciseId, 'hip_thrust']);
      expect(first.blocks.first.sets, 6);
    });

    test('the setup survives a round trip through the goal JSON', () {
      final setup = suggestTrainingSetup(_goal(), split: SplitKind.upperLower);
      final goal = Goal.fromJson(_goal(training: setup).toJson());
      expect(goal.training!.split, SplitKind.upperLower);
      expect(goal.training!.sessions.first.exercises,
          setup.sessions.first.exercises);
    });

    test('alternatives keep the movement pattern first and the equipment',
        () {
      final alternatives =
          alternativesFor('bench_press', EquipmentAccess.homeBasic);
      expect(alternatives.first.pattern, MovementPattern.horizontalPush);
      expect(
        alternatives.every(
            (Exercise e) => e.availableWith(EquipmentAccess.homeBasic)),
        isTrue,
      );
      expect(alternatives.map((Exercise e) => e.id), isNot(contains('bench_press')));
    });

    test('swapping like for like keeps the user\'s numbers', () {
      final slot = defaultSlotFor(kExerciseById['bench_press']!, _goal())
          .copyWith(sets: 5, repsLow: 5, repsHigh: 5);
      final swapped = swapSlot(slot, kExerciseById['db_bench']!, _goal());
      expect(swapped.exerciseId, 'db_bench');
      expect(swapped.sets, 5);
      expect(swapped.repsHigh, 5);

      final isolation = swapSlot(slot, kExerciseById['pec_deck']!, _goal());
      expect(isolation.repsLow, greaterThanOrEqualTo(10));
    });

    test('an unknown exercise id from a newer app is skipped, not fatal', () {
      final setup = TrainingSetup(split: SplitKind.fullBody, sessions: <SessionPlan>[
        SessionPlan(kind: WorkoutKind.fullBodyA, exercises: <ExerciseSlot>[
          const ExerciseSlot(
            exerciseId: 'quantum_squat',
            sets: 3,
            repsLow: 5,
            repsHigh: 8,
            rpe: 8,
            restSeconds: 120,
          ),
          defaultSlotFor(kExerciseById['deadlift']!, _goal()),
        ]),
      ]);
      final plan = buildTrainingPlan(_goal(days: 2, training: setup));
      expect(plan.weeks.first.workouts.first.blocks.single.exerciseId,
          'deadlift');
    });
  });

  group('progression recommendation', () {
    const target = PlannedSet(
      exerciseId: 'bench_press',
      sets: 3,
      repsLow: 6,
      repsHigh: 10,
      rpe: 8,
      restSeconds: 150,
    );

    ExerciseLog log(double weight, List<int> reps) => ExerciseLog(
          exerciseId: 'bench_press',
          sets: <LoggedSet>[
            for (final int r in reps) LoggedSet(weightKg: weight, reps: r),
          ],
        );

    test('no history asks for a first weight at the bottom of the range', () {
      final rec = recommendNext(target: target, history: const <ExerciseLog>[]);
      expect(rec.advice, ProgressionAdvice.firstTime);
      expect(rec.weightKg, isNull);
      expect(rec.reps, <int>[6, 6, 6]);
    });

    test('the top of the range on every set adds weight', () {
      final rec = recommendNext(
        target: target,
        history: <ExerciseLog>[log(80, <int>[10, 10, 10])],
      );
      expect(rec.advice, ProgressionAdvice.addWeight);
      expect(rec.weightKg, 82.5);
      expect(rec.reps, <int>[6, 6, 6]);
    });

    test('inside the range adds a rep at the same weight', () {
      final rec = recommendNext(
        target: target,
        history: <ExerciseLog>[log(80, <int>[8, 7, 6])],
      );
      expect(rec.advice, ProgressionAdvice.addReps);
      expect(rec.weightKg, 80);
      expect(rec.reps, <int>[9, 8, 7]);
    });

    test('missing the range twice takes ten percent off', () {
      final rec = recommendNext(
        target: target,
        history: <ExerciseLog>[
          log(80, <int>[5, 4, 4]),
          log(80, <int>[5, 5, 4]),
        ],
      );
      expect(rec.advice, ProgressionAdvice.reduce);
      expect(rec.weightKg, 72.5);
    });

    test('bodyweight work progresses in reps only', () {
      const pushups = PlannedSet(
        exerciseId: 'pushup',
        sets: 2,
        repsLow: 8,
        repsHigh: 12,
        rpe: 8,
        restSeconds: 90,
      );
      final rec = recommendNext(
        target: pushups,
        history: const <ExerciseLog>[
          ExerciseLog(exerciseId: 'pushup', sets: <LoggedSet>[
            LoggedSet(weightKg: 0, reps: 12),
            LoggedSet(weightKg: 0, reps: 12),
          ]),
        ],
      );
      expect(rec.weightKg, isNull);
      expect(rec.reps, <int>[13, 13]);
    });

    test('dumbbell work moves in two kilo steps', () {
      expect(progressionIncrementKg(kExerciseById['db_bench']!), 2);
      expect(progressionIncrementKg(kExerciseById['pushup']!), 0);
    });
  });

  group('workout log', () {
    test('round-trips through its payload', () {
      final original = WorkoutLog(
        day: DayKey.parse('2026-11-02'),
        kind: WorkoutKind.push,
        sessionIndex: 2,
        durationMinutes: 55,
        loggedAt: DateTime.utc(2026, 11, 2, 18),
        exercises: const <ExerciseLog>[
          ExerciseLog(exerciseId: 'bench_press', sets: <LoggedSet>[
            LoggedSet(weightKg: 80, reps: 8),
            LoggedSet(weightKg: 82.5, reps: 6),
          ]),
        ],
      );
      final copy = WorkoutLog.fromPayload(original.toPayload(),
          loggedAt: original.loggedAt);
      expect(copy.kind, WorkoutKind.push);
      expect(copy.sessionIndex, 2);
      expect(copy.totalSets, 2);
      expect(copy.volumeKg, 80 * 8 + 82.5 * 6);
      expect(copy.exercises.single.topWeightKg, 82.5);
    });

    test('a malformed set is dropped instead of crashing the projection', () {
      final log = WorkoutLog.fromPayload(<String, dynamic>{
        'day': '2026-11-02',
        'kind': 'push',
        'ex': <dynamic>[
          <String, dynamic>{
            'id': 'bench_press',
            's': <dynamic>[
              <dynamic>[80, 8],
              'nonsense',
              <dynamic>[80],
            ],
          },
          'junk',
        ],
      }, loggedAt: DateTime.utc(2026));
      expect(log.exercises.single.sets, hasLength(1));
    });
  });
}
