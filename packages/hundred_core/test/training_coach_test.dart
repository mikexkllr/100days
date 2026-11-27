import 'dart:convert';

import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

Goal _goal({
  int days = 4,
  EquipmentAccess equipment = EquipmentAccess.fullGym,
  TrainingExperience experience = TrainingExperience.intermediate,
}) =>
    Goal(
      archetype: GoalArchetype.buildMuscle,
      statement: 'Masse',
      experience: experience,
      equipment: equipment,
      trainingDaysPerWeek: days,
    );

Iterable<Exercise> _exercises(TrainingSetup setup) => <Exercise>[
      for (final SessionPlan s in setup.sessions)
        for (final ExerciseSlot slot in s.exercises) slot.exercise!,
    ];

class _Llm implements LlmClient {
  _Llm(this.answers);

  final List<String> answers;
  final List<String> prompts = <String>[];

  @override
  String get modelName => 'fake';

  @override
  bool get isReady => true;

  @override
  Future<String> generate(
    String prompt, {
    List<LlmImage> images = const <LlmImage>[],
    LlmPurpose purpose = LlmPurpose.food,
    int maxTokens = 400,
    double temperature = 0.7,
    Duration timeout = const Duration(seconds: 30),
    bool json = false,
    Map<String, Object?>? schema,
  }) async {
    prompts.add(prompt);
    return answers[prompts.length - 1];
  }
}

String _answer({
  String split = 'upperLower',
  String equipment = 'homeBasic',
  List<Map<String, Object?>>? sessions,
}) =>
    jsonEncode(<String, Object?>{
      'split': split,
      'equipment': equipment,
      'sessions': sessions ??
          <Map<String, Object?>>[
            <String, Object?>{
              'kind': 'upper',
              'exercises': <Object?>[
                <String, Object?>{
                  'id': 'db_bench',
                  'sets': 4,
                  'reps_low': 6,
                  'reps_high': 10,
                },
                <String, Object?>{
                  'id': 'db_row',
                  'sets': 3,
                  'reps_low': 8,
                  'reps_high': 12,
                },
              ],
            },
            <String, Object?>{
              'kind': 'lower',
              'exercises': <Object?>[
                <String, Object?>{
                  'id': 'goblet_squat',
                  'sets': 3,
                  'reps_low': 10,
                  'reps_high': 15,
                },
              ],
            },
          ],
      'reason': 'Zwei Tage oben, zwei unten – mit dem, was du zu Hause hast.',
    });

void main() {
  group('a goal that changes under a plan', () {
    test('an untouched suggestion is suggested again for the new equipment',
        () {
      final Goal gym = _goal();
      final Goal home = _goal(equipment: EquipmentAccess.homeBasic);
      final TrainingSetup moved =
          retargetTraining(suggestTrainingSetup(gym), from: gym, to: home);
      expect(moved, suggestTrainingSetup(home));
    });

    test('the recommended split follows the days, a picked one stays', () {
      final Goal four = _goal();
      final Goal three = _goal(days: 3);
      expect(
        retargetTraining(suggestTrainingSetup(four), from: four, to: three)
            .split,
        SplitKind.fullBody,
      );
      final TrainingSetup ppl =
          suggestTrainingSetup(four, split: SplitKind.pushPullLegs);
      expect(retargetTraining(ppl, from: four, to: three).split,
          SplitKind.pushPullLegs);
    });

    test('an edited plan keeps its edits and only swaps what home cannot do',
        () {
      final Goal gym = _goal();
      final TrainingSetup suggested = suggestTrainingSetup(gym);
      final SessionPlan first = suggested.sessions.first;
      // One more set on the first movement, and a home-friendly one kept.
      final TrainingSetup edited = suggested.withSession(
        0,
        first.copyWith(exercises: <ExerciseSlot>[
          first.exercises.first.copyWith(sets: first.exercises.first.sets + 1),
          defaultSlotFor(kExerciseById['pullup']!, gym),
          ...first.exercises.skip(1),
        ]),
      );
      final Goal home = _goal(equipment: EquipmentAccess.homeBasic);
      final TrainingSetup fitted =
          retargetTraining(edited, from: gym, to: home);

      expect(fitted.split, edited.split);
      expect(
          _exercises(fitted).every(
              (Exercise e) => e.availableWith(EquipmentAccess.homeBasic)),
          isTrue);
      final List<ExerciseSlot> slots = fitted.sessions.first.exercises;
      // The pull-up needed nothing new and stayed where it was.
      expect(slots[1].exerciseId, 'pullup');
      // The barbell movement became one of the same pattern, extra set and
      // all.
      final Exercise before = first.exercises.first.exercise!;
      expect(slots.first.exercise!.pattern, before.pattern);
      expect(slots.first.sets, first.exercises.first.sets + 1);
      // No movement twice in a session.
      for (final SessionPlan s in fitted.sessions) {
        final List<String> ids =
            s.exercises.map((ExerciseSlot e) => e.exerciseId).toList();
        expect(ids.toSet().length, ids.length);
      }
    });

    test('down to body weight, every session still has something to train', () {
      final Goal gym = _goal(days: 5);
      final TrainingSetup edited =
          suggestTrainingSetup(gym, split: SplitKind.broSplit)
              .withSession(0, suggestTrainingSetup(gym).sessions.first);
      final TrainingSetup fitted = fitSetupToEquipment(
          edited, _goal(days: 5, equipment: EquipmentAccess.bodyweight));
      expect(fitted.isTrainable, isTrue);
      expect(_exercises(fitted).every((Exercise e) => e.isBodyweight), isTrue);
    });

    test('more equipment leaves a home plan as it is', () {
      final Goal home = _goal(equipment: EquipmentAccess.homeBasic);
      final TrainingSetup suggested = suggestTrainingSetup(home);
      final TrainingSetup edited = suggested.withSession(
          0,
          suggested.sessions.first.copyWith(
              exercises: suggested.sessions.first.exercises.reversed.toList()));
      expect(retargetTraining(edited, from: home, to: _goal()), edited);
    });
  });

  group('what Funki proposes', () {
    final TrainingRequest request = TrainingRequest(
      goal: _goal(),
      wish: 'Kurzhanteln und Klimmzugstange zu Hause',
    );

    test('a plan from the list is taken, with the equipment it was told of',
        () {
      final TrainingProposal p = parseTrainingProposal(_answer(), request);
      expect(p.equipment, EquipmentAccess.homeBasic);
      expect(p.setup.split, SplitKind.upperLower);
      expect(p.setup.sessions.map((SessionPlan s) => s.kind),
          <WorkoutKind>[WorkoutKind.upper, WorkoutKind.lower]);
      final ExerciseSlot bench = p.setup.sessions.first.exercises.first;
      expect(bench.exerciseId, 'db_bench');
      expect((bench.sets, bench.repsLow, bench.repsHigh), (4, 6, 10));
      // Effort comes from the app's prescription, not the model.
      expect(bench.rpe, defaultSlotFor(bench.exercise!, request.goal).rpe);
      expect(p.reason, contains('zu Hause'));
    });

    test('an exercise the equipment cannot do is left out', () {
      final TrainingProposal p = parseTrainingProposal(
        _answer(sessions: <Map<String, Object?>>[
          <String, Object?>{
            'kind': 'upper',
            'exercises': <Object?>[
              <String, Object?>{
                'id': 'db_bench',
                'sets': 3,
                'reps_low': 8,
                'reps_high': 12
              },
              <String, Object?>{
                'id': 'pullup',
                'sets': 3,
                'reps_low': 5,
                'reps_high': 8
              },
              <String, Object?>{
                'id': 'lat_pulldown',
                'sets': 3,
                'reps_low': 8,
                'reps_high': 12
              },
            ],
          },
          <String, Object?>{
            'kind': 'lower',
            'exercises': <Object?>[
              <String, Object?>{
                'id': 'goblet_squat',
                'sets': 3,
                'reps_low': 8,
                'reps_high': 12
              },
              <String, Object?>{
                'id': 'goblet_squat',
                'sets': 3,
                'reps_low': 8,
                'reps_high': 12
              },
            ],
          },
        ]),
        request,
      );
      expect(
          p.setup.sessions.first.exercises
              .map((ExerciseSlot s) => s.exerciseId),
          <String>['db_bench', 'pullup']);
      // And none twice.
      expect(p.setup.sessions.last.exercises, hasLength(1));
    });

    test('absurd numbers are held to what a slot allows', () {
      final TrainingProposal p = parseTrainingProposal(
        _answer(sessions: <Map<String, Object?>>[
          <String, Object?>{
            'kind': 'upper',
            'exercises': <Object?>[
              <String, Object?>{
                'id': 'db_bench',
                'sets': 40,
                'reps_low': 12,
                'reps_high': 6
              },
            ],
          },
          <String, Object?>{
            'kind': 'lower',
            'exercises': <Object?>[
              <String, Object?>{
                'id': 'goblet_squat',
                'sets': 3,
                'reps_low': 8,
                'reps_high': 12
              },
            ],
          },
        ]),
        request,
      );
      final ExerciseSlot slot = p.setup.sessions.first.exercises.single;
      expect(slot.sets, 10);
      expect(slot.repsHigh, greaterThanOrEqualTo(slot.repsLow));
    });

    test('a missing session, an empty one or made-up ids are refused', () {
      expect(
        () => parseTrainingProposal(
            _answer(sessions: <Map<String, Object?>>[
              <String, Object?>{
                'kind': 'upper',
                'exercises': <Object?>[
                  <String, Object?>{
                    'id': 'db_bench',
                    'sets': 3,
                    'reps_low': 8,
                    'reps_high': 12
                  },
                ],
              },
            ]),
            request),
        throwsA(isA<FormatException>().having(
            (FormatException e) => e.message, 'message', contains('lower'))),
      );
      expect(
        () => parseTrainingProposal(
            _answer(sessions: <Map<String, Object?>>[
              <String, Object?>{
                'kind': 'upper',
                'exercises': <Object?>[
                  <String, Object?>{
                    'id': 'db_bench',
                    'sets': 3,
                    'reps_low': 8,
                    'reps_high': 12
                  },
                ],
              },
              <String, Object?>{
                'kind': 'lower',
                'exercises': <Object?>[
                  <String, Object?>{
                    'id': 'leg_press',
                    'sets': 3,
                    'reps_low': 8,
                    'reps_high': 12
                  },
                ],
              },
            ]),
            request),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseTrainingProposal(_answer(split: 'yoga'), request),
        throwsA(isA<FormatException>()),
      );
    });

    test('a refused answer goes back once with why, then it is null', () async {
      final _Llm llm = _Llm(<String>[_answer(split: 'yoga'), _answer()]);
      final TrainingProposal? p =
          await TrainingAssistant(llm: llm).propose(request);
      expect(p, isNotNull);
      expect(llm.prompts, hasLength(2));
      expect(llm.prompts.last, contains('Unknown split "yoga"'));

      final _Llm stubborn = _Llm(<String>['nonsense', _answer(split: 'yoga')]);
      expect(await TrainingAssistant(llm: stubborn).propose(request), isNull);
      expect(stubborn.prompts, hasLength(2));
    });

    test('the prompt lists every split for the days and no conditioning', () {
      final String prompt = const EnglishTrainingPrompts().proposePlan(
        TrainingRequest(
          goal: _goal(days: 2),
          wish: 'x',
          current: suggestTrainingSetup(_goal(days: 2)),
        ),
      );
      expect(prompt, contains('fullBody: fullBodyA, fullBodyB\n'));
      expect(prompt, contains('- db_bench: chest, homeBasic'));
      expect(prompt, isNot(contains('jump_rope')));
      expect(prompt, contains('Their plan now'));
    });
  });
}
