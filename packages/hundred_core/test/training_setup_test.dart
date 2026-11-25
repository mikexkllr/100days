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

    test('sessions rotate across weeks instead of repeating the same days', () {
      final goal = _goal(
        days: 4,
        training:
            suggestTrainingSetup(_goal(days: 4), split: SplitKind.pushPullLegs),
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

  group('rotation', () {
    // A Monday; adding 0..6 days gives every start weekday.
    final monday = DayKey(2026, 3, 2);

    /// The workouts of the first [days] calendar days, in the order they
    /// come up.
    List<Workout> walk(TrainingPlan plan, DayKey start, {int days = 140}) =>
        <Workout>[
          for (var d = 0; d < days; d++)
            if (plan.workoutFor(start, start.addDays(d)) case final Workout w)
              w,
        ];

    test('the review\'s cases: no session twice in a row', () {
      final wednesday = monday.addDays(2);
      final upperLower = buildTrainingPlan(
        _goal(
          days: 3,
          training:
              suggestTrainingSetup(_goal(days: 3), split: SplitKind.upperLower),
        ),
        startWeekday: DateTime.wednesday,
      );
      expect(
        walk(upperLower, wednesday, days: 14 + 2).map((Workout w) => w.kind),
        <WorkoutKind>[
          WorkoutKind.upper, WorkoutKind.lower, WorkoutKind.upper, // wk 1
          WorkoutKind.lower, WorkoutKind.upper, WorkoutKind.lower, // wk 2
          WorkoutKind.upper, // the next Wednesday
        ],
      );

      final ppl = buildTrainingPlan(
        _goal(
          days: 4,
          training: suggestTrainingSetup(_goal(days: 4),
              split: SplitKind.pushPullLegs),
        ),
        startWeekday: DateTime.wednesday,
      );
      expect(
        walk(ppl, wednesday, days: 7).map((Workout w) => w.kind),
        <WorkoutKind>[
          WorkoutKind.push,
          WorkoutKind.pull,
          WorkoutKind.legs,
          WorkoutKind.push,
        ],
      );
    });

    test('every split, day count and start weekday rotates in order', () {
      for (final SplitKind split in SplitKind.values) {
        for (var days = 2; days <= 6; days++) {
          final setup = suggestTrainingSetup(_goal(days: days), split: split);
          final goal = _goal(days: days, training: setup);
          for (var offset = 0; offset < 7; offset++) {
            final start = monday.addDays(offset);
            final plan = buildTrainingPlan(
              goal,
              startWeekday: start.toDateTime().weekday,
            );
            final what = '${split.name}, $days days, start +$offset';
            final workouts = walk(plan, start);

            // 20 weeks of [days] sessions each, in rotation order.
            expect(workouts, hasLength(20 * days), reason: what);
            for (var k = 0; k < workouts.length; k++) {
              final expected = k % setup.sessions.length;
              expect(workouts[k].sessionIndex, expected, reason: '$what #$k');
              expect(workouts[k].kind, setup.sessions[expected].kind,
                  reason: '$what #$k');
            }

            // Each plan week lists its days in calendar order from the start.
            final week = plan.week(3);
            final order = week.workouts
                .map(
                    (Workout w) => (w.weekday - start.toDateTime().weekday) % 7)
                .toList();
            expect(order, List<int>.of(order)..sort(), reason: what);
            expect(week.workouts.map((Workout w) => w.weekday).toSet(),
                kWeekdaySpread[days]!.toSet(),
                reason: what);
          }
        }
      }
    });

    test('a plan built for Monday still rotates right for another start', () {
      final goal = _goal(days: 3);
      final start = monday.addDays(4); // Friday
      final forMonday = buildTrainingPlan(goal);
      final forFriday = buildTrainingPlan(goal, startWeekday: DateTime.friday);
      expect(
        walk(forMonday, start).map((Workout w) => w.sessionIndex),
        walk(forFriday, start).map((Workout w) => w.sessionIndex),
      );
    });

    test('buildPlan lays the weeks out from the challenge start', () {
      final start = monday.addDays(2); // Wednesday
      final plan = buildPlan(Challenge(
        id: 'c',
        goal: _goal(days: 3),
        habits: <Habit>[Habit.fromCategory(HabitCategory.gym)],
        startDay: start,
      )).training!;
      expect(plan.weeks.first.workouts.map((Workout w) => w.weekday),
          <int>[DateTime.wednesday, DateTime.friday, DateTime.monday]);
      expect(plan.workoutFor(start, start)!.sessionIndex, 0);
      expect(plan.workoutFor(start, start.addDays(-1)), isNull);
    });

    test('an empty session is left out of the rotation', () {
      final suggested =
          suggestTrainingSetup(_goal(days: 3), split: SplitKind.pushPullLegs);
      final setup = suggested.withSession(
          1, suggested.sessions[1].copyWith(exercises: const <ExerciseSlot>[]));
      expect(setup.isTrainable, isFalse);
      expect(suggested.isTrainable, isTrue);

      final plan = buildTrainingPlan(_goal(days: 3, training: setup));
      final kinds = <WorkoutKind>[
        for (final TrainingWeek w in plan.weeks.take(2))
          for (final Workout workout in w.workouts) workout.kind,
      ];
      expect(kinds, <WorkoutKind>[
        WorkoutKind.push,
        WorkoutKind.legs,
        WorkoutKind.push,
        WorkoutKind.legs,
        WorkoutKind.push,
        WorkoutKind.legs,
      ]);
      expect(
        plan.weeks.every((TrainingWeek w) =>
            w.workouts.every((Workout x) => x.blocks.isNotEmpty)),
        isTrue,
      );
    });

    test('setups compare by value, so the editor can tell an edit', () {
      final a = suggestTrainingSetup(_goal(days: 4));
      final b = suggestTrainingSetup(_goal(days: 4));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      final edited = a.withSession(
          0,
          a.sessions[0].copyWith(exercises: <ExerciseSlot>[
            a.sessions[0].exercises.first.copyWith(sets: 9),
            ...a.sessions[0].exercises.skip(1),
          ]));
      expect(edited, isNot(a));
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
      final base =
          suggestTrainingSetup(_goal(days: 2), split: SplitKind.fullBody);
      final custom = base.withSession(
        0,
        base.sessions[0].copyWith(exercises: <ExerciseSlot>[
          base.sessions[0].exercises.first.copyWith(sets: 6),
          defaultSlotFor(kExerciseById['hip_thrust']!, _goal()),
        ]),
      );
      final plan = buildTrainingPlan(_goal(days: 2, training: custom));
      final first = plan.weeks.first.workouts.first;
      expect(first.blocks.map((PlannedSet b) => b.exerciseId), <String>[
        custom.sessions[0].exercises.first.exerciseId,
        'hip_thrust'
      ]);
      expect(first.blocks.first.sets, 6);
    });

    test('the setup survives a round trip through the goal JSON', () {
      final setup = suggestTrainingSetup(_goal(), split: SplitKind.upperLower);
      final goal = Goal.fromJson(_goal(training: setup).toJson());
      expect(goal.training!.split, SplitKind.upperLower);
      expect(goal.training!.sessions.first.exercises,
          setup.sessions.first.exercises);
    });

    test('alternatives keep the movement pattern first and the equipment', () {
      final alternatives =
          alternativesFor('bench_press', EquipmentAccess.homeBasic);
      expect(alternatives.first.pattern, MovementPattern.horizontalPush);
      expect(
        alternatives
            .every((Exercise e) => e.availableWith(EquipmentAccess.homeBasic)),
        isTrue,
      );
      expect(alternatives.map((Exercise e) => e.id),
          isNot(contains('bench_press')));
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
      final setup =
          TrainingSetup(split: SplitKind.fullBody, sessions: <SessionPlan>[
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
      expect(
          plan.weeks.first.workouts.first.blocks.single.exerciseId, 'deadlift');
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
        history: <ExerciseLog>[
          log(80, <int>[10, 10, 10])
        ],
      );
      expect(rec.advice, ProgressionAdvice.addWeight);
      expect(rec.weightKg, 82.5);
      expect(rec.reps, <int>[6, 6, 6]);
    });

    test('inside the range adds a rep at the same weight', () {
      final rec = recommendNext(
        target: target,
        history: <ExerciseLog>[
          log(80, <int>[8, 7, 6])
        ],
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

    test('past the top of the range, each set climbs from its own reps', () {
      const pushups = PlannedSet(
        exerciseId: 'pushup',
        sets: 3,
        repsLow: 10,
        repsHigh: 15,
        rpe: 8,
        restSeconds: 90,
      );
      final rec = recommendNext(
        target: pushups,
        history: const <ExerciseLog>[
          ExerciseLog(exerciseId: 'pushup', sets: <LoggedSet>[
            LoggedSet(weightKg: 0, reps: 20),
            LoggedSet(weightKg: 0, reps: 20),
            LoggedSet(weightKg: 0, reps: 18),
          ]),
        ],
      );
      expect(rec.advice, ProgressionAdvice.beyondRange);
      expect(rec.weightKg, isNull);
      expect(rec.reps, <int>[21, 21, 19]);
    });

    test('added load on a bodyweight movement progresses like a barbell', () {
      const pullups = PlannedSet(
        exerciseId: 'pullup',
        sets: 3,
        repsLow: 6,
        repsHigh: 8,
        rpe: 8,
        restSeconds: 120,
      );
      ExerciseLog pullupLog(double added, List<int> reps) => ExerciseLog(
            exerciseId: 'pullup',
            sets: <LoggedSet>[
              for (final int r in reps) LoggedSet(weightKg: added, reps: r),
            ],
          );

      final top = recommendNext(target: pullups, history: <ExerciseLog>[
        pullupLog(10, <int>[8, 8, 8])
      ]);
      expect(top.advice, ProgressionAdvice.addWeight);
      expect(top.weightKg, 10 + kAddedLoadIncrementKg);
      expect(top.reps, <int>[6, 6, 6]);

      final inside = recommendNext(target: pullups, history: <ExerciseLog>[
        pullupLog(10, <int>[7, 6, 6])
      ]);
      expect(inside.advice, ProgressionAdvice.addReps);
      expect(inside.weightKg, 10);

      final missed = recommendNext(target: pullups, history: <ExerciseLog>[
        pullupLog(2.5, <int>[4, 4, 3]),
        pullupLog(2.5, <int>[5, 4, 4]),
      ]);
      expect(missed.advice, ProgressionAdvice.reduce);
      expect(missed.weightKg, isNull, reason: 'back to body weight alone');
    });

    test('a deload goes lighter instead of beating last time', () {
      final rec = recommendNext(
        target: target,
        history: <ExerciseLog>[
          log(80, <int>[10, 10, 10])
        ],
        deload: true,
      );
      expect(rec.advice, ProgressionAdvice.deload);
      expect(rec.weightKg, 72.5);
      expect(rec.reps, <int>[6, 6, 6]);

      final bodyweight = recommendNext(
        target: const PlannedSet(
          exerciseId: 'pushup',
          sets: 2,
          repsLow: 8,
          repsHigh: 12,
          rpe: 6,
          restSeconds: 90,
        ),
        history: const <ExerciseLog>[
          ExerciseLog(exerciseId: 'pushup', sets: <LoggedSet>[
            LoggedSet(weightKg: 0, reps: 12),
          ]),
        ],
        deload: true,
      );
      expect(bodyweight.advice, ProgressionAdvice.deload);
      expect(bodyweight.weightKg, isNull);
    });

    test('the deload week is not the number to beat afterwards', () {
      final rec = recommendNext(
        target: target,
        history: <ExerciseLog>[
          const ExerciseLog(
            exerciseId: 'bench_press',
            deload: true,
            sets: <LoggedSet>[LoggedSet(weightKg: 72.5, reps: 6)],
          ),
          log(80, <int>[10, 10, 10]),
        ],
      );
      expect(rec.advice, ProgressionAdvice.addWeight);
      expect(rec.weightKg, 82.5);
    });

    test('taking weight off is at least one step', () {
      const dumbbell = PlannedSet(
        exerciseId: 'db_bench',
        sets: 3,
        repsLow: 8,
        repsHigh: 12,
        rpe: 8,
        restSeconds: 90,
      );
      ExerciseLog db(List<int> reps) => ExerciseLog(
            exerciseId: 'db_bench',
            sets: <LoggedSet>[
              for (final int r in reps) LoggedSet(weightKg: 10, reps: r),
            ],
          );
      final rec = recommendNext(
        target: dumbbell,
        history: <ExerciseLog>[
          db(<int>[6, 5, 5]),
          db(<int>[7, 6, 5])
        ],
      );
      expect(rec.advice, ProgressionAdvice.reduce);
      expect(rec.weightKg, 8);
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
      expect(copy.deload, isFalse);
      expect(original.toPayload().containsKey('deload'), isFalse);
    });

    test('a deload session says so, down to every exercise', () {
      final original = WorkoutLog(
        day: DayKey.parse('2026-11-23'),
        kind: WorkoutKind.upper,
        sessionIndex: 0,
        deload: true,
        loggedAt: DateTime.utc(2026, 11, 23, 18),
        exercises: const <ExerciseLog>[
          ExerciseLog(exerciseId: 'bench_press', sets: <LoggedSet>[
            LoggedSet(weightKg: 72.5, reps: 6),
          ]),
        ],
      );
      final copy = WorkoutLog.fromPayload(original.toPayload(),
          loggedAt: original.loggedAt);
      expect(copy.deload, isTrue);
      expect(copy.exercises.single.deload, isTrue);
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
