import 'dart:convert';

import 'package:meta/meta.dart';

import '../ai/llm_client.dart';
import '../domain/goal.dart';
import '../nutrition/nutrition_assistant.dart' show AiErrorCallback, askModel;
import 'exercises.dart';
import 'training.dart';

// ---------------------------------------------------------------------------
// One set of rules for a plan whose goal changes
// ---------------------------------------------------------------------------

/// What becomes of [setup] when the goal under it changes from [from] to
/// [to] — other days, experience or equipment. Onboarding and the plan
/// editor both go through here, so a plan set up later follows the same
/// rules as one set up on day one.
///
/// - A suggestion nobody touched is suggested again for the new goal; the
///   recommended split follows the days, a split picked by hand stays.
/// - A plan someone made — the user, or Funki — is kept. Only movements the
///   new equipment cannot do are swapped ([fitSetupToEquipment]).
TrainingSetup retargetTraining(
  TrainingSetup setup, {
  required Goal from,
  required Goal to,
}) {
  if (setup == suggestTrainingSetup(from, split: setup.split)) {
    final bool followsDays =
        setup.split == recommendedSplit(from.trainingDaysPerWeek);
    return suggestTrainingSetup(to, split: followsDays ? null : setup.split);
  }
  return fitSetupToEquipment(setup, to);
}

/// [setup] with every movement [goal]'s equipment cannot do swapped for the
/// closest one it can: the same pattern for the same muscle first, then the
/// same pattern, then anything for the same muscle. Sets and reps stay when
/// the replacement is the same kind of movement ([swapSlot]).
///
/// A movement with nothing to replace it is dropped; an id this version of
/// the library does not know is left alone — a newer app wrote it.
TrainingSetup fitSetupToEquipment(TrainingSetup setup, Goal goal) {
  final EquipmentAccess access = goal.equipment;
  return TrainingSetup(
    split: setup.split,
    sessions: <SessionPlan>[
      for (final SessionPlan session in setup.sessions)
        _fitSession(session, goal, access),
    ],
  );
}

SessionPlan _fitSession(
  SessionPlan session,
  Goal goal,
  EquipmentAccess access,
) {
  bool fits(ExerciseSlot slot) =>
      slot.exercise == null || slot.exercise!.availableWith(access);
  if (session.exercises.every(fits)) return session;
  // What stays is taken first, so a swap does not duplicate it.
  final Set<String> used = <String>{
    for (final ExerciseSlot slot in session.exercises)
      if (fits(slot)) slot.exerciseId,
  };
  final List<ExerciseSlot> slots = <ExerciseSlot>[];
  for (final ExerciseSlot slot in session.exercises) {
    if (fits(slot)) {
      slots.add(slot);
      continue;
    }
    final Exercise before = slot.exercise!;
    Exercise? swap = pickExercise(
      before.pattern,
      access,
      exclude: used,
      muscle: before.primary,
    );
    if (swap == null) {
      for (final Exercise e in alternativesFor(before.id, access)) {
        if (!used.contains(e.id)) {
          swap = e;
          break;
        }
      }
    }
    if (swap == null) continue;
    used.add(swap.id);
    slots.add(swapSlot(slot, swap, goal));
  }
  return session.copyWith(exercises: slots);
}

// ---------------------------------------------------------------------------
// Funki puts a plan together
// ---------------------------------------------------------------------------

/// What Funki is asked to build a plan for: the goal as it stands in the
/// form — days, experience, equipment — the plan in it now, and what the
/// user said ("dumbbells up to 20 kg and a bench, knees are bad").
@immutable
class TrainingRequest {
  const TrainingRequest({
    required this.goal,
    required this.wish,
    this.current,
  });

  final Goal goal;
  final String wish;
  final TrainingSetup? current;

  int get daysPerWeek => goal.trainingDaysPerWeek.clamp(2, 6);
}

/// A plan Funki put together, already checked against the library: every
/// exercise exists and fits [equipment], every session of [setup]'s split
/// is there and has something to train.
@immutable
class TrainingProposal {
  const TrainingProposal({
    required this.setup,
    required this.equipment,
    this.reason,
  });

  final TrainingSetup setup;

  /// What the user said they have, as far as the three levels go — the
  /// form's own unless the description said otherwise.
  final EquipmentAccess equipment;

  /// One sentence on why this plan, in the user's language.
  final String? reason;
}

/// The JSON a training proposal answers in. Real ids and numbers on
/// purpose: small models copy the example's shape, and zeros.
const String kTrainingProposalJson = '{"split":"upperLower",'
    '"equipment":"homeBasic","sessions":[{"kind":"upper","exercises":'
    '[{"id":"db_bench","sets":3,"reps_low":8,"reps_high":12},'
    '{"id":"db_row","sets":3,"reps_low":8,"reps_high":12}]},'
    '{"kind":"lower","exercises":[{"id":"goblet_squat","sets":3,'
    '"reps_low":8,"reps_high":12}]}],"reason":"one short sentence"}';

/// [kTrainingProposalJson] as a JSON Schema. [parseTrainingProposal] still
/// checks everything: a schema fixes the shape, not the sense.
const Map<String, Object?> kTrainingProposalSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'split': <String, Object?>{
      'type': 'string',
      'enum': <String>[
        'fullBody',
        'upperLower',
        'pushPullLegs',
        'pplUpperLower',
        'broSplit',
      ],
    },
    'equipment': <String, Object?>{
      'type': 'string',
      'enum': <String>['fullGym', 'homeBasic', 'bodyweight'],
    },
    'sessions': <String, Object?>{
      'type': 'array',
      'items': <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'kind': <String, Object?>{'type': 'string'},
          'exercises': <String, Object?>{
            'type': 'array',
            'items': <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{
                'id': <String, Object?>{'type': 'string'},
                'sets': <String, Object?>{'type': 'integer'},
                'reps_low': <String, Object?>{'type': 'integer'},
                'reps_high': <String, Object?>{'type': 'integer'},
              },
              'required': <String>['id', 'sets', 'reps_low', 'reps_high'],
            },
          },
        },
        'required': <String>['kind', 'exercises'],
      },
    },
    'reason': <String, Object?>{'type': 'string'},
  },
  'required': <String>['split', 'equipment', 'sessions'],
};

/// At most this many exercises in a proposed session: more is not a
/// workout anyone finishes.
const int kMaxProposedExercises = 8;

/// Exercises Funki may use: strength movements only, as in the editor's
/// picker — conditioning is not a slot in a session.
Iterable<Exercise> get proposableExercises => kExerciseLibrary
    .where((Exercise e) => e.pattern != MovementPattern.conditioning);

/// Checks [raw] against [request] and the exercise library.
///
/// Throws a [FormatException] saying what is wrong, worded for the model:
/// it gets the reason back and one more try. An unknown or unsuitable
/// exercise is left out rather than failing the whole plan, unless so many
/// are that the model plainly ignored the list.
TrainingProposal parseTrainingProposal(String raw, TrainingRequest request) {
  final int start = raw.indexOf('{');
  final int end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const FormatException('No JSON object in the answer.');
  }
  final Object? decoded = jsonDecode(raw.substring(start, end + 1));
  if (decoded is! Map) throw const FormatException('Answer a JSON object.');

  final EquipmentAccess equipment =
      EquipmentAccess.values.asNameMap()[decoded['equipment']] ??
          request.goal.equipment;
  final SplitKind? split = SplitKind.values.asNameMap()[decoded['split']];
  if (split == null) {
    throw FormatException('Unknown split "${decoded['split']}". Use one of '
        '${SplitKind.values.map((SplitKind s) => s.name).join(', ')}.');
  }
  final Goal goal = request.goal.copyWith(equipment: equipment);
  final List<WorkoutKind> kinds =
      sessionsOf(split, daysPerWeek: request.daysPerWeek);

  final List<Map<Object?, Object?>> given = <Map<Object?, Object?>>[
    for (final Object? s
        in decoded['sessions'] as List<Object?>? ?? const <Object?>[])
      if (s is Map) s,
  ];
  Map<Object?, Object?>? sessionFor(int index, WorkoutKind kind) {
    for (final Map<Object?, Object?> s in given) {
      if (s['kind'] == kind.name) return s;
    }
    // Right number of sessions, kinds misnamed: take them in order.
    return given.length == kinds.length ? given[index] : null;
  }

  int offered = 0;
  int dropped = 0;
  final List<SessionPlan> sessions = <SessionPlan>[];
  for (int i = 0; i < kinds.length; i++) {
    final WorkoutKind kind = kinds[i];
    final Map<Object?, Object?>? s = sessionFor(i, kind);
    if (s == null) {
      throw FormatException('Session "${kind.name}" is missing. '
          '${split.name} needs: ${kinds.map((WorkoutKind k) => k.name).join(', ')}.');
    }
    final Set<String> used = <String>{};
    final List<ExerciseSlot> slots = <ExerciseSlot>[];
    for (final Object? e
        in s['exercises'] as List<Object?>? ?? const <Object?>[]) {
      if (e is! Map) continue;
      offered++;
      final Exercise? exercise = kExerciseById[e['id']];
      if (exercise == null ||
          exercise.pattern == MovementPattern.conditioning ||
          !exercise.availableWith(equipment) ||
          used.contains(exercise.id) ||
          slots.length >= kMaxProposedExercises) {
        dropped++;
        continue;
      }
      used.add(exercise.id);
      final int? sets = _int(e['sets']);
      final int? low = _int(e['reps_low']);
      final int? high = _int(e['reps_high']);
      // Effort and rest come from the app's own prescription: the model
      // picks movements and volume, not how hard the last rep is.
      slots.add(defaultSlotFor(exercise, goal).copyWith(
        sets: sets,
        repsLow: low,
        repsHigh: high ?? low,
      ));
    }
    if (slots.isEmpty) {
      throw FormatException('Session "${kind.name}" has no usable exercise. '
          'Use only ids from the list that ${equipment.name} allows.');
    }
    sessions.add(SessionPlan(kind: kind, exercises: slots));
  }
  if (dropped * 2 > offered) {
    throw FormatException('$dropped of $offered exercises are not in the '
        'list or not possible with ${equipment.name}. Use only listed ids.');
  }

  final Object? why = decoded['reason'];
  final String? reason =
      why is String && why.trim().isNotEmpty ? _short(why.trim()) : null;
  return TrainingProposal(
    setup: TrainingSetup(split: split, sessions: sessions),
    equipment: equipment,
    reason: reason,
  );
}

int? _int(Object? value) => value is num ? value.round() : null;

String _short(String text) =>
    text.length <= 240 ? text : '${text.substring(0, 239)}…';

/// The training prompt, in the user's language. The app's localized one
/// names exercises the way the user reads them; ids stay as they are.
abstract class TrainingPromptBuilder {
  String proposePlan(TrainingRequest request);

  /// Appended when the last answer was refused, with [why].
  String refused(String why);
}

class EnglishTrainingPrompts implements TrainingPromptBuilder {
  const EnglishTrainingPrompts();

  @override
  String proposePlan(TrainingRequest request) {
    final Goal goal = request.goal;
    final TrainingSetup? current = request.current;
    return '''
You are Funki, a strength coach. Put a training plan together for this person.
Goal: "${goal.statement}" (${goal.archetype.name}).
Experience: ${goal.experience.name}. Training days a week: ${request.daysPerWeek} (fixed).
Equipment as they picked it: ${goal.equipment.name}.
${current == null ? '' : 'Their plan now:\n${describeSetup(current)}\n'}What they say: "${request.wish.trim()}"

Splits and the sessions they rotate through:
${describeSplits(request.daysPerWeek)}

Exercises (id: muscle, least equipment):
${proposableExercises.map((Exercise e) => '- ${e.id}: ${e.primary.name}, ${e.minEquipment.name}').join('\n')}

Pick the split that fits. Give every session of it, in that order, with 3 to
$kMaxProposedExercises exercises each, only ids from the list. If what they say
tells you they have more or less equipment, set "equipment" to fullGym,
homeBasic or bodyweight and use only exercises it allows. Sets 1 to 6,
reps 3 to 30.
Answer with JSON only, in this form:
$kTrainingProposalJson
''';
  }

  @override
  String refused(String why) => '\nYour last answer was refused: $why\n'
      'Answer again with JSON only.';
}

/// Every split with its sessions for [daysPerWeek], one per line.
String describeSplits(int daysPerWeek) => SplitKind.values
    .map((SplitKind s) => '- ${s.name}: '
        '${sessionsOf(s, daysPerWeek: daysPerWeek).map((WorkoutKind k) => k.name).join(', ')}')
    .join('\n');

/// [setup] in a few lines of ids and numbers.
String describeSetup(TrainingSetup setup) => <String>[
      'split ${setup.split.name}',
      for (final SessionPlan s in setup.sessions)
        '- ${s.kind.name}: ${s.exercises.map((ExerciseSlot e) => '${e.exerciseId} ${e.sets}x${e.repsLow}-${e.repsHigh}').join(', ')}',
    ].join('\n');

/// Asks the model for a plan and keeps only one that holds up.
///
/// Like the meal planner: every failure is null, never an exception, and a
/// proposal only ever lands in an editor the user saves — or does not.
class TrainingAssistant {
  TrainingAssistant({
    required this.llm,
    this.prompts = const EnglishTrainingPrompts(),
    this.timeout = const Duration(seconds: 60),
  });

  final LlmClient llm;
  final TrainingPromptBuilder prompts;
  final Duration timeout;

  /// [onError] hears when a call failed before there was an answer —
  /// offline, timed out, allowance used up. An answer that does not hold up
  /// goes back to the model once, with why.
  Future<TrainingProposal?> propose(
    TrainingRequest request, {
    AiErrorCallback? onError,
  }) async {
    if (!llm.isReady || request.wish.trim().isEmpty) return null;
    String prompt = prompts.proposePlan(request);
    for (int attempt = 0; attempt < 2; attempt++) {
      final String? raw = await askModel(
        () => llm.generate(prompt,
            purpose: LlmPurpose.plan,
            maxTokens: 2500,
            temperature: 0.4,
            json: true,
            schema: kTrainingProposalSchema,
            timeout: timeout),
        timeout: timeout,
        onError: onError,
      );
      if (raw == null) return null;
      try {
        return parseTrainingProposal(raw, request);
      } on FormatException catch (refused) {
        prompt =
            '${prompts.proposePlan(request)}${prompts.refused(refused.message)}';
      } on Object {
        prompt = '${prompts.proposePlan(request)}'
            '${prompts.refused('The answer was not valid JSON.')}';
      }
    }
    return null;
  }
}
