import 'dart:async';
import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart' hide Provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../data/household_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/household_providers.dart';
import '../../state/providers.dart';
import '../dartantic_llm_client.dart';
import 'funki.dart';

/// The brain behind Funki, or null without a model that can call tools.
/// Tests override it with a script.
final Provider<FunkiBrain?> funkiBrainProvider = Provider<FunkiBrain?>((Ref ref) {
  final LlmClient llm = ref.watch(llmClientProvider);
  return llm is DartanticLlmClient ? DartanticFunkiBrain(llm) : null;
});

/// A new conversation about [focus], or null when Funki cannot be reached.
///
/// The tools read through [container], which outlives the screen that
/// opened the conversation: Funki is asked from a sheet over whatever
/// screen the user is on.
FunkiConversation? createFunkiConversation(
  ProviderContainer container,
  AppLocalizations l10n,
  FunkiFocus focus,
) {
  final FunkiBrain? brain = container.read(funkiBrainProvider);
  if (brain == null) return null;
  return FunkiConversation(
    brain: brain,
    focus: focus,
    system: () => funkiSystemPrompt(
      l10n,
      focus,
      container.read(appStateProvider).valueOrNull,
    ),
    tools: (void Function(FunkiChange) record) => FunkiToolbox(
      container: container,
      l10n: l10n,
      focus: focus,
      record: record,
    ).tools,
  );
}

/// The conversations with Funki that are going on: one for each place and
/// day he was asked about, so closing his sheet and opening it again goes
/// on where it stopped. Gone with the session.
class FunkiSession {
  final Map<String, FunkiConversation> _open = <String, FunkiConversation>{};

  static String _key(FunkiFocus focus) =>
      '${focus.place.name}-${focus.day}-${focus.weekStart}';

  /// The conversation about [focus], started if there is none. Null without
  /// a model that can call tools.
  FunkiConversation? about(
    ProviderContainer container,
    AppLocalizations l10n,
    FunkiFocus focus,
  ) {
    final FunkiConversation? known = _open[_key(focus)];
    if (known != null) return known;
    final FunkiConversation? fresh =
        createFunkiConversation(container, l10n, focus);
    if (fresh != null) _open[_key(focus)] = fresh;
    return fresh;
  }

  /// Starts over about [focus]: a new conversation, the old one let go.
  FunkiConversation? startOver(
    ProviderContainer container,
    AppLocalizations l10n,
    FunkiFocus focus,
  ) {
    // Not disposed here: a sheet may still be listening to it.
    _open.remove(_key(focus));
    return about(container, l10n, focus);
  }

  void dispose() {
    for (final FunkiConversation c in _open.values) {
      c.dispose();
    }
    _open.clear();
  }
}

final Provider<FunkiSession> funkiSessionProvider =
    Provider<FunkiSession>((Ref ref) {
  // Another account, another model: nothing said before carries over.
  ref.watch(funkiBrainProvider);
  final FunkiSession session = FunkiSession();
  ref.onDispose(session.dispose);
  return session;
});

String funkiSystemPrompt(
  AppLocalizations l10n,
  FunkiFocus focus,
  AppSnapshot? snapshot,
) {
  final DayKey today = DayKey.today();
  final String name = snapshot?.me.profile.displayName.trim() ?? '';
  final String where = switch (focus.place) {
    FunkiPlace.home => l10n.promptFunkiFromHome,
    FunkiPlace.diary => l10n.promptFunkiFromDiary(focus.day.toString()),
    FunkiPlace.mealPlan => l10n.promptFunkiFromPlan(
        focus.weekStart.toString(), focus.weekStart.addDays(6).toString()),
    FunkiPlace.shopping => l10n.promptFunkiFromShopping,
    FunkiPlace.training => l10n.promptFunkiFromTraining,
  };
  return l10n.promptFunki(
    today.toString(),
    l10n.weekdayLong(today.toDateTime().weekday),
    name.isEmpty ? l10n.promptFunkiNoName : name,
    where,
  );
}

const List<String> _kSlotNames = <String>['breakfast', 'lunch', 'snack', 'dinner'];

/// The cooking levels, by the names the model uses for them.
final List<String> _kLevelNames = <String>[
  for (final CookingLevel level in CookingLevel.values) level.name,
];

/// Said once, in the system prompt, what the levels mean: every tool
/// declaration is sent with every message, so the tools only name them.
const String _kLevelHelp = "Cooking level. Default: the user's own.";

/// A planned meal as `set_meal` takes it: [kMealSchema] and the level it is
/// written at.
final Map<String, Object?> _kSetMealSchema = <String, Object?>{
  ...kMealSchema,
  'properties': <String, Object?>{
    ...kMealSchema['properties']! as Map<String, Object?>,
    'complexity': <String, Object?>{
      'type': 'string',
      'enum': _kLevelNames,
      'description': _kLevelHelp,
    },
  },
};

/// Funki's hands: everything he may read and change, as tools for the
/// model. Reads answer in JSON; every change goes to [record] with an undo,
/// and every answer the model writes goes through the same checks as the
/// rest of the app — a meal through [parseMealPlan], a food through
/// [foodEstimateFrom], an exercise against the library.
///
/// Two tools ask the model themselves, through the [MealPlanner]:
/// `plan_week` and `write_recipe`. A week of full recipes passed through
/// the conversation would be paid for again with every later message; this
/// way the conversation only holds the dishes' names.
class FunkiToolbox {
  FunkiToolbox({
    required ProviderContainer container,
    required this.l10n,
    required this.focus,
    required this.record,
  }) : _c = container;

  final ProviderContainer _c;
  final AppLocalizations l10n;
  final FunkiFocus focus;
  final void Function(FunkiChange change) record;

  Future<AppSnapshot> get _snapshot => _c.read(appStateProvider.future);
  AppController get _app => _c.read(appStateProvider.notifier);
  HouseholdBackend get _backend => _c.read(householdBackendProvider);
  HouseholdActions get _actions => _c.read(householdActionsProvider);
  Future<String> get _householdId => _c.read(householdIdProvider.future);
  String get _me => _c.read(repositoryProvider).userId;

  bool get _hasTrainingPlan =>
      _c.read(appStateProvider).valueOrNull?.plan?.training != null;

  List<Tool> get tools => <Tool>[
        _tool(
          'get_today',
          'Today at a glance: the challenge day, the streak, every habit with '
              'whether it is required today and done, and how many friends '
              'were active.',
          (_) => _today(),
        ),
        _tool(
          'check_in',
          'Marks a habit as done for today. Only when the user says they did '
              'it. value: the amount for habits with a number (pages, '
              'minutes …); leave it out for the target.',
          _checkIn,
          input: S.object(
            properties: <String, Schema>{
              'habit_id': S.string(),
              'value': S.number(),
            },
            required: <String>['habit_id'],
          ),
        ),
        _tool(
          'get_diary',
          'The food diary of a day (default: the day in view): targets, every '
              'entry with its id, what is eaten and left, and planned meals '
              'not eaten yet.',
          _diary,
          input: S.object(properties: <String, Schema>{
            'day': S.string(description: 'YYYY-MM-DD'),
          }),
        ),
        _tool(
          'log_food',
          'Writes foods the user ate into the diary. Estimate realistically: '
              'grams eaten and kcal, protein, carbs, fat for that amount.',
          _logFood,
          input: S.object(
            properties: <String, Schema>{
              'day': S.string(description: 'YYYY-MM-DD, default: the day in view'),
              'slot': S.string(enumValues: _kSlotNames),
              'foods': S.list(
                items: S.object(
                  properties: <String, Schema>{
                    'name': S.string(),
                    'grams': S.number(),
                    'kcal': S.number(),
                    'protein': S.number(),
                    'carbs': S.number(),
                    'fat': S.number(),
                  },
                  required: <String>['name', 'grams', 'kcal', 'protein', 'carbs', 'fat'],
                ),
              ),
            },
            required: <String>['slot', 'foods'],
          ),
        ),
        _tool(
          'remove_food',
          'Removes one diary entry, by the id get_diary gives.',
          _removeFood,
          input: S.object(
            properties: <String, Schema>{'entry_id': S.string()},
            required: <String>['entry_id'],
          ),
        ),
        _tool(
          'eat_planned',
          "Puts the user's portion of a planned meal into the diary as eaten.",
          _eatPlanned,
          input: S.object(
            properties: <String, Schema>{
              'day': S.string(description: 'YYYY-MM-DD'),
              'slot': S.string(enumValues: _kSlotNames),
            },
            required: <String>['slot'],
          ),
        ),
        _tool(
          'get_meal_plan',
          "The household and its meal plan for a week (default: the week in "
              "view): members with their targets and tastes, the user's own "
              'cooking level, and every planned meal by day and slot with '
              'whether its recipe is written.',
          (Map<String, dynamic> input) => _plan(input),
          input: S.object(properties: <String, Schema>{
            'week_start': S.string(description: 'YYYY-MM-DD, a Monday'),
          }),
        ),
        _tool(
          'plan_week',
          'Plans several meals at once and puts them on the meal plan, '
              'replacing what was in those slots: a full recipe for each.',
          _planWeek,
          input: S.object(
            properties: <String, Schema>{
              'days': S.list(
                description: 'YYYY-MM-DD. Default: the rest of the week '
                    'in view.',
                items: S.string(),
              ),
              'slots': S.list(
                description: 'Default: dinner.',
                items: S.string(enumValues: _kSlotNames),
              ),
              'complexity':
                  S.string(enumValues: _kLevelNames, description: _kLevelHelp),
              'wish': S.string(
                  description: "The user's wishes, in their words."),
              'max_minutes': S.integer(description: 'Cooking time, at most.'),
            },
          ),
        ),
        _tool(
          'get_recipe',
          'The recipe planned on a day and slot: ingredients (kitchen '
              'basics marked), cooking steps, cooking level, calories per '
              'serving and the portion of each member.',
          _recipe,
          input: S.object(
            properties: <String, Schema>{
              'day': S.string(description: 'YYYY-MM-DD'),
              'slot': S.string(enumValues: _kSlotNames),
            },
            required: <String>['day', 'slot'],
          ),
        ),
        _tool(
          'set_meal',
          'Puts a recipe on a day and slot of the meal plan, replacing what '
              'was there. Servings for the whole household; calories and '
              'macros of ONE serving.',
          _setMeal,
          input: Schema.fromMap(_kSetMealSchema),
        ),
        _tool(
          'write_recipe',
          'Writes the recipe of a meal already planned — ingredients and '
              'cooking steps — when it is only a name, or again at another '
              'cooking level. The dish keeps its name and place.',
          _writeRecipe,
          input: S.object(
            properties: <String, Schema>{
              'day': S.string(description: 'YYYY-MM-DD'),
              'slot': S.string(enumValues: _kSlotNames),
              'complexity':
                  S.string(enumValues: _kLevelNames, description: _kLevelHelp),
            },
            required: <String>['day', 'slot'],
          ),
        ),
        _tool(
          'move_meal',
          'Moves a planned meal to another day or slot. A meal already '
              'there takes its place: the two swap.',
          _moveMeal,
          input: S.object(
            properties: <String, Schema>{
              'from_day': S.string(description: 'YYYY-MM-DD'),
              'from_slot': S.string(enumValues: _kSlotNames),
              'to_day': S.string(description: 'YYYY-MM-DD'),
              'to_slot': S.string(enumValues: _kSlotNames),
            },
            required: <String>['from_day', 'from_slot', 'to_day'],
          ),
        ),
        _tool(
          'remove_meal',
          'Removes the meal planned on a day and slot.',
          _removeMeal,
          input: S.object(
            properties: <String, Schema>{
              'day': S.string(description: 'YYYY-MM-DD'),
              'slot': S.string(enumValues: _kSlotNames),
            },
            required: <String>['day', 'slot'],
          ),
        ),
        _tool(
          'get_shopping_list',
          'The current shopping list: every line with amount, section '
              'and whether it is in the basket; what is always at home; '
              'and planned meals missing from it for want of a recipe.',
          (_) => _listSnapshot(),
        ),
        _tool(
          'add_to_list',
          'Adds lines to the current shopping list, with an amount where '
              'one was said.',
          _addToList,
          input: S.object(
            properties: <String, Schema>{
              'items': S.list(
                items: S.object(
                  properties: <String, Schema>{
                    'name': S.string(),
                    'qty': S.number(),
                    'unit': S.string(
                        enumValues: <String>['g', 'ml', 'piece', 'tbsp', 'tsp']),
                  },
                  required: <String>['name'],
                ),
              ),
            },
            required: <String>['items'],
          ),
        ),
        _tool(
          'remove_from_list',
          'Removes lines from the current shopping list, e.g. because they '
              'are still at home.',
          _removeFromList,
          input: S.object(
            properties: <String, Schema>{
              'names': S.list(items: S.string()),
            },
            required: <String>['names'],
          ),
        ),
        _tool(
          'tick_list_items',
          'Ticks lines of the current shopping list off as in the basket, '
              'or unticks them.',
          _tickItems,
          input: S.object(
            properties: <String, Schema>{
              'names': S.list(items: S.string()),
              'in_basket': S.boolean(description: 'Default: true'),
            },
            required: <String>['names'],
          ),
        ),
        _tool(
          'make_list_from_plan',
          'Makes the shopping list for the next trip from the recipes of '
              'the planned meals, or tops up the one already open. Says '
              'which meals it could not shop for.',
          (_) => _listFromPlan(),
        ),
        _tool(
          'set_pantry',
          'Changes what the household always has at home (salt, oil …): '
              'those stay off lists made from the plan.',
          _setPantry,
          input: S.object(
            properties: <String, Schema>{
              'add': S.list(items: S.string()),
              'remove': S.list(items: S.string()),
            },
          ),
        ),
        _tool(
          'set_food_preferences',
          "Changes the user's own tastes, which every plan respects. A "
              'list replaces the one before: send it whole (get_meal_plan '
              'has the current ones).',
          _setTastes,
          input: S.object(
            properties: <String, Schema>{
              'diet': S.string(description: '"" for none'),
              'dislikes': S.list(items: S.string()),
              'allergies': S.list(items: S.string()),
              'complexity':
                  S.string(enumValues: _kLevelNames, description: _kLevelHelp),
            },
          ),
        ),
        _tool(
          'get_training',
          "Whether there is a training plan, today's workout from it, and "
              'the last logged workouts with sets, reps and weights.',
          (_) => _training(),
        ),
        // What changes a training plan is only declared to someone who has
        // one: declarations are sent with every message.
        if (_hasTrainingPlan) ...<Tool>[
          _tool(
            'get_training_plan',
            'The training plan as configured: split, days a week, and every '
                'session with its exercises (id, sets, reps, rest) by '
                'position.',
            (_) => _trainingPlan(),
          ),
          _tool(
            'find_exercises',
            "Exercises the user's equipment allows: for a muscle, or to "
                'replace an exercise (like). Gives the ids the training '
                'tools take.',
            _findExercises,
            input: S.object(
              properties: <String, Schema>{
                'muscle': S.string(enumValues: <String>[
                  for (final MuscleGroup m in MuscleGroup.values) m.name,
                ]),
                'like': S.string(description: 'An exercise id to replace'),
              },
            ),
          ),
          _tool(
            'change_exercise',
            'Changes one exercise of a session: swaps it for another '
                '(exercise_id) and/or sets its sets, reps and rest.',
            _changeExercise,
            input: S.object(
              properties: <String, Schema>{
                'session': S.integer(description: 'From get_training_plan'),
                'position': S.integer(description: 'From get_training_plan'),
                'exercise_id': S.string(),
                'sets': S.integer(),
                'reps_low': S.integer(),
                'reps_high': S.integer(),
                'rest_seconds': S.integer(),
              },
              required: <String>['session', 'position'],
            ),
          ),
          _tool(
            'add_exercise',
            'Adds an exercise to a session, at the end unless a position is '
                'given.',
            _addExercise,
            input: S.object(
              properties: <String, Schema>{
                'session': S.integer(),
                'exercise_id': S.string(),
                'position': S.integer(),
                'sets': S.integer(),
                'reps_low': S.integer(),
                'reps_high': S.integer(),
              },
              required: <String>['session', 'exercise_id'],
            ),
          ),
          _tool(
            'remove_exercise',
            'Takes one exercise out of a session.',
            _removeExercise,
            input: S.object(
              properties: <String, Schema>{
                'session': S.integer(),
                'position': S.integer(),
              },
              required: <String>['session', 'position'],
            ),
          ),
          _tool(
            'set_training_days',
            'Changes how many days a week the user trains (2–6) and, if '
                'given, the split — which starts that split from its '
                'proposed exercises.',
            _setTrainingDays,
            input: S.object(
              properties: <String, Schema>{
                'days_per_week': S.integer(),
                'split': S.string(enumValues: <String>[
                  for (final SplitKind k in SplitKind.values) k.name,
                ]),
              },
            ),
          ),
          ],
        _tool(
          'get_friends',
          'Friends with their streak and whether they were active today.',
          (_) => _friends(),
        ),
      ];

  /// A tool whose failures go back to the model as text instead of ending
  /// the conversation: it can then say so or try differently.
  Tool<Map<String, dynamic>> _tool(
    String name,
    String description,
    Future<Object?> Function(Map<String, dynamic> input) run, {
    Schema? input,
  }) =>
      Tool<Map<String, dynamic>>(
        name: name,
        description: description,
        inputSchema: input,
        onCall: (Map<String, dynamic> args) async {
          try {
            final Object? result = await run(args);
            return result is String ? result : jsonEncode(result);
          } on Object catch (error) {
            return 'Failed: $error';
          }
        },
      );

  DayKey _day(Object? value, DayKey fallback) {
    if (value is String && value.trim().isNotEmpty) {
      try {
        return DayKey.parse(value.trim());
      } on Object {
        throw ArgumentError('day must be YYYY-MM-DD, not "$value"');
      }
    }
    return fallback;
  }

  MealSlotKind _slot(Object? value) {
    final MealSlotKind? slot = MealSlotKind.values.asNameMap()[value];
    if (slot == null) {
      throw ArgumentError('slot must be one of ${_kSlotNames.join(', ')}');
    }
    return slot;
  }

  CookingLevel _level(Object? value, CookingLevel fallback) {
    if (value == null || value == '') return fallback;
    final CookingLevel? level = CookingLevel.values.asNameMap()[value];
    if (level == null) {
      throw ArgumentError('complexity must be one of ${_kLevelNames.join(', ')}');
    }
    return level;
  }

  /// How the user likes to cook, from their place in the household.
  CookingLevel _myLevel(Household household) =>
      household.member(_me)?.cooking ?? CookingLevel.everyday;

  static List<String> _strings(Object? value) => <String>[
        if (value is String && value.trim().isNotEmpty) value.trim(),
        if (value is List)
          for (final Object? v in value)
            if (v is String && v.trim().isNotEmpty) v.trim(),
      ];

  static int _r(double value) => value.round();

  Map<String, Object?> _nutrients(Nutrients n) => <String, Object?>{
        'kcal': _r(n.kcal),
        'protein_g': _r(n.proteinG),
        'carbs_g': _r(n.carbsG),
        'fat_g': _r(n.fatG),
      };

  // ── Today and habits ────────────────────────────────────────────────

  String _schedule(Habit habit, DayKey day) {
    final List<int> days = scheduledWeekdays(habit, day);
    if (days.isEmpty) return 'optional';
    if (days.length == 7) return 'every day';
    return days.map(l10n.weekdayShort).join(', ');
  }

  Future<Map<String, Object?>> _today() async {
    final AppSnapshot s = await _snapshot;
    final DayKey today = s.today;
    final Challenge? challenge = s.challenge;
    if (challenge == null) {
      return <String, Object?>{
        'today': '$today',
        'challenge': null,
        'note': 'No challenge started yet.',
      };
    }
    final DayLog? log = s.me.logsByDay[today.toString()];
    final Set<String> required = <String>{
      for (final Habit h in requiredHabitsOn(challenge, today)) h.id,
    };
    return <String, Object?>{
      'today': '$today',
      'weekday': l10n.weekdayLong(today.toDateTime().weekday),
      'challenge_day': challenge.dayNumber(today),
      'challenge_length': challenge.lengthDays,
      'streak': <String, Object?>{
        'current': s.me.streak.current,
        'longest': s.me.streak.longest,
        'day_complete': s.me.streak.doneToday,
        'at_risk': s.me.streak.atRisk,
        'freezes_left': challenge.freezesLeftOn(today, s.me.frozenDays),
      },
      'habits': <Map<String, Object?>>[
        for (final Habit h in challenge.habits)
          if (h.isActiveOn(today))
            <String, Object?>{
              'id': h.id,
              'name': l10n.habitLabel(h),
              'kind': h.kind == HabitKind.abstain ? 'stay clean' : 'do',
              'target': l10n.formatTarget(h, value: h.targetOn(today)),
              'schedule': _schedule(h, today),
              'required_today': required.contains(h.id),
              'done_today': _done(h, log),
              if (log?.entryFor(h.id) case final CheckIn e when !e.relapse)
                'logged_today': e.value,
              if (log?.entryFor(h.id)?.relapse ?? false) 'relapse_today': true,
              'streak': s.me.habitStreaks[h.id] ?? 0,
            },
      ],
      'friends_active_today':
          s.peerStates.where((PeerState p) => p.activeToday).length,
    };
  }

  static bool _done(Habit habit, DayLog? log) {
    final CheckIn? entry = log?.entryFor(habit.id);
    return entry != null &&
        !entry.relapse &&
        entry.value >= habit.targetOn(entry.day);
  }

  Future<String> _checkIn(Map<String, dynamic> input) async {
    final AppSnapshot s = await _snapshot;
    final Challenge? challenge = s.challenge;
    if (challenge == null) return 'No challenge started yet.';
    final Habit? habit = challenge.habits
        .where((Habit h) => h.id == input['habit_id'] && h.isActiveOn(s.today))
        .firstOrNull;
    if (habit == null) return 'No such habit today. get_today has the ids.';
    final DayLog? log = s.me.logsByDay[s.today.toString()];
    final String name = l10n.habitLabel(habit);
    if (_done(habit, log)) return '$name is already done today.';
    final num value = (input['value'] as num?) ?? habit.targetOn(s.today);
    if (value <= 0) return 'The value must be more than 0.';
    final CheckIn? before = log?.entryFor(habit.id);
    await _app.checkIn(habit, value: value);
    record(FunkiChange(l10n.funkiCheckedIn(name), () async {
      if (before == null || before.relapse) {
        await _app.undoCheckIn(habit);
      } else {
        await _app.checkIn(habit, value: before.value);
      }
    }));
    return 'Checked in $name for today.';
  }

  // ── The food diary ──────────────────────────────────────────────────

  static const String _noDiary =
      'The user keeps no food diary: there is no nutrition plan. They can '
      'turn it on in the plan settings.';

  Future<Object?> _diary(Map<String, dynamic> input) async {
    final AppSnapshot s = await _snapshot;
    final NutritionPlan? plan = s.plan?.nutrition;
    if (plan == null) return _noDiary;
    final DayKey day = _day(input['day'], focus.day);
    final DayIntake intake = s.me.intakeOn(day);
    final Nutrients eaten = intake.total;
    return <String, Object?>{
      'day': '$day',
      'targets': <String, Object?>{
        'kcal': plan.kcal,
        'protein_g': plan.proteinG,
        'carbs_g': plan.carbsG,
        'fat_g': plan.fatG,
        'by_slot': <Map<String, Object?>>[
          for (final MealSlot m in plan.meals)
            <String, Object?>{'slot': m.kind.name, 'kcal': m.kcal, 'protein_g': m.proteinG},
        ],
      },
      'entries': <Map<String, Object?>>[
        for (final FoodEntry e in intake.entries)
          <String, Object?>{
            'id': e.id,
            'slot': e.meal.name,
            'name': e.name,
            if (e.grams > 0) 'grams': _r(e.grams),
            ..._nutrients(e.nutrients),
          },
      ],
      'eaten': _nutrients(eaten),
      'left': <String, Object?>{
        'kcal': plan.kcal - _r(eaten.kcal),
        'protein_g': plan.proteinG - _r(eaten.proteinG),
      },
      'planned_not_eaten': await _plannedNotEaten(day, intake),
    };
  }

  /// The user's planned meals of [day] that are not in the diary yet. The
  /// household may be out of reach; the diary is still the diary.
  Future<List<Map<String, Object?>>> _plannedNotEaten(
      DayKey day, DayIntake intake) async {
    try {
      final String id = await _householdId;
      final Map<String, Recipe> recipes = await _backend.recipes(id);
      return <Map<String, Object?>>[
        for (final PlanEntry e in await _backend.plan(id, day, day))
          if (recipes[e.recipeId] case final Recipe r
              when e.portionFor(_me) > 0 && !eatenAsPlanned(intake, e, r))
            <String, Object?>{
              'slot': e.slot.name,
              'title': r.title,
              'my_portion_kcal': _r(nutrientsFor(e, r, _me).kcal),
            },
      ];
    } on Object {
      return const <Map<String, Object?>>[];
    }
  }

  Future<Object?> _logFood(Map<String, dynamic> input) async {
    final AppSnapshot s = await _snapshot;
    if (s.plan?.nutrition == null) return _noDiary;
    final DayKey day = _day(input['day'], focus.day);
    if (day.isAfter(s.today)) return 'That day has not come yet.';
    final MealSlotKind slot = _slot(input['slot']);
    final List<String> logged = <String>[];
    final List<Object?> rejected = <Object?>[];
    for (final Object? item in (input['foods'] as List?) ?? const <Object?>[]) {
      final FoodEstimate? food = foodEstimateFrom(item);
      if (food == null) {
        rejected.add(item is Map ? item['name'] : item);
        continue;
      }
      final FoodEntry entry = FoodEntry(
        id: newEventId(),
        day: day,
        meal: slot,
        name: food.name,
        grams: food.grams,
        nutrients: food.nutrients,
        source: FoodSource.ai,
      );
      await _app.logFood(entry);
      logged.add('${food.name} (${_r(food.nutrients.kcal)} kcal)');
      record(FunkiChange(
        l10n.funkiLogged(l10n.mealName(slot), food.name, _r(food.nutrients.kcal)),
        () => _app.removeFood(entry.id),
      ));
    }
    return <String, Object?>{
      'logged': logged,
      if (rejected.isNotEmpty) 'rejected': rejected,
      if (rejected.isNotEmpty)
        'why_rejected': 'grams missing or out of range, or more kcal than '
            'the grams can hold (over 9 kcal a gram)',
    };
  }

  Future<String> _removeFood(Map<String, dynamic> input) async {
    final AppSnapshot s = await _snapshot;
    final String id = '${input['entry_id']}';
    FoodEntry? found;
    for (final List<FoodEntry> day in s.me.foodByDay.values) {
      for (final FoodEntry e in day) {
        if (e.id == id) found = e;
      }
    }
    if (found == null) return 'No entry with that id. get_diary has the ids.';
    final FoodEntry gone = found;
    await _app.removeFood(gone.id);
    record(FunkiChange(l10n.funkiRemovedFood(gone.name), () => _app.logFood(FoodEntry(
          id: newEventId(),
          day: gone.day,
          meal: gone.meal,
          name: gone.name,
          grams: gone.grams,
          nutrients: gone.nutrients,
          source: gone.source,
          foodId: gone.foodId,
          barcode: gone.barcode,
        ))));
    return 'Removed ${gone.name}.';
  }

  Future<String> _eatPlanned(Map<String, dynamic> input) async {
    final AppSnapshot s = await _snapshot;
    if (s.plan?.nutrition == null) return _noDiary;
    final DayKey day = _day(input['day'], focus.day);
    if (day.isAfter(s.today)) return 'That day has not come yet.';
    final MealSlotKind slot = _slot(input['slot']);
    final String id = await _householdId;
    final Map<String, Recipe> recipes = await _backend.recipes(id);
    final DayIntake intake = s.me.intakeOn(day);
    for (final PlanEntry e in await _backend.plan(id, day, day)) {
      final Recipe? recipe = recipes[e.recipeId];
      if (e.slot != slot || recipe == null || e.portionFor(_me) <= 0) continue;
      if (eatenAsPlanned(intake, e, recipe)) return '${recipe.title} is in the diary already.';
      final FoodEntry entry = FoodEntry(
        id: newEventId(),
        day: day,
        meal: slot,
        name: recipe.title,
        grams: 0,
        nutrients: nutrientsFor(e, recipe, _me),
        source: FoodSource.plan,
      );
      await _app.logFood(entry);
      record(FunkiChange(
        l10n.funkiLogged(l10n.mealName(slot), recipe.title, _r(entry.nutrients.kcal)),
        () => _app.removeFood(entry.id),
      ));
      return 'Logged the planned ${recipe.title}, ${_r(entry.nutrients.kcal)} kcal.';
    }
    return 'Nothing is planned for the user there.';
  }

  // ── The meal plan ───────────────────────────────────────────────────

  Future<Map<String, Object?>> _plan(Map<String, dynamic> input) async {
    final DayKey start = _day(input['week_start'], focus.weekStart).weekStart;
    final String id = await _householdId;
    final Household household = await _backend.household(id);
    final List<PlanEntry> entries = await _backend.plan(id, start, start.addDays(6));
    final Map<String, Recipe> recipes = await _backend.recipes(id);
    final HouseholdMember? me = household.member(_me);
    return <String, Object?>{
      'week': '$start – ${start.addDays(6)}',
      'members': <String>[
        for (final HouseholdMember m in household.members) describePerson(m.toPlanFor()),
      ],
      'my_cooking_level': _myLevel(household).name,
      if (me != null)
        'my_preferences': <String, Object?>{
          'diet': me.diet ?? '',
          'dislikes': me.dislikes,
          'allergies': me.allergies,
        },
      'meals': <Map<String, Object?>>[
        for (final PlanEntry e in entries)
          <String, Object?>{
            'day': e.day.toString(),
            'slot': e.slot.name,
            'title': recipes[e.recipeId]?.title,
            'kcal_per_serving': recipes[e.recipeId]?.perServing.kcal.round(),
            'has_recipe': recipes[e.recipeId]?.isWritten ?? false,
            if (recipes[e.recipeId]?.level case final CookingLevel level)
              'complexity': level.name,
          },
      ],
    };
  }

  /// The meal planned on [day]'s [slot], with its recipe.
  Future<(PlanEntry, Recipe)?> _planned(DayKey day, MealSlotKind slot) async {
    final String id = await _householdId;
    final Map<String, Recipe> recipes = await _backend.recipes(id);
    for (final PlanEntry e in await _backend.plan(id, day, day)) {
      final Recipe? r = recipes[e.recipeId];
      if (e.slot == slot && r != null) return (e, r);
    }
    return null;
  }

  Future<Object?> _recipe(Map<String, dynamic> input) async {
    final DayKey day = _day(input['day'], focus.day);
    final MealSlotKind slot = _slot(input['slot']);
    final (PlanEntry, Recipe)? planned = await _planned(day, slot);
    if (planned == null) return 'Nothing is planned there.';
    final (PlanEntry e, Recipe r) = planned;
    final Household household = await _backend.household(await _householdId);
    return <String, Object?>{
      'title': r.title,
      'has_recipe': r.isWritten,
      if (!r.isWritten)
        'note': 'Only a name so far: write_recipe writes the ingredients '
            'and the steps.',
      if (r.level != null) 'complexity': r.level!.name,
      'servings': r.servings,
      if (r.minutes != null) 'minutes': r.minutes,
      'per_serving': _nutrients(r.perServing),
      'ingredients': <String>[
        for (final Ingredient i in r.ingredients)
          '${l10n.quantityLabel(i.quantity)} ${i.name}'
              '${i.staple ? ' (kitchen basic)' : ''}',
      ],
      'steps': r.steps,
      'portions': <String, double>{
        for (final HouseholdMember m in household.members) m.displayName: e.portionFor(m.userId),
      },
    };
  }

  /// What a plan for [days] must and should not repeat: the dishes on this
  /// stretch's other slots, and what was eaten in the weeks before.
  Future<({List<String> recent, List<String> planned})> _dishesAround(
    String householdId,
    List<DayKey> days,
    Set<String> requested,
  ) async {
    final List<PlanEntry> entries = await _backend.plan(
        householdId, days.first.addDays(-28), days.last);
    final Map<String, Recipe> recipes = await _backend.recipes(householdId);
    return (
      recent: recentTitles(entries, recipes),
      planned: recentTitles(
        <PlanEntry>[
          for (final PlanEntry e in entries)
            if (!e.day.isBefore(days.first.weekStart) &&
                !requested.contains('${e.day}/${e.slot.name}'))
              e,
        ],
        recipes,
        limit: 40,
      ),
    );
  }

  Future<Object?> _planWeek(Map<String, dynamic> input) async {
    final MealPlanner? planner = await _c.read(mealPlannerProvider.future);
    if (planner == null) return 'No model to plan with.';
    final DayKey today = DayKey.today();
    final List<DayKey> days = <DayKey>{
      for (final Object? d in (input['days'] as List?) ?? const <Object?>[])
        _day(d, today),
    }.toList()
      ..sort();
    if (days.isEmpty) {
      // The days of the week in view that have not passed.
      days.addAll(<DayKey>[
        for (int i = 0; i < 7; i++)
          if (!focus.weekStart.addDays(i).isBefore(today))
            focus.weekStart.addDays(i),
      ]);
    }
    if (days.isEmpty) return 'That week is over. Name the days to plan.';
    if (days.length > 14) return 'At most 14 days at a time.';
    final Set<MealSlotKind> wanted = <MealSlotKind>{
      for (final Object? s in (input['slots'] as List?) ?? const <Object?>[])
        _slot(s),
    };
    final List<MealSlotKind> slots = wanted.isEmpty
        ? const <MealSlotKind>[MealSlotKind.dinner]
        : MealSlotKind.values.where(wanted.contains).toList();
    final String id = await _householdId;
    final Household household = await _backend.household(id);
    final CookingLevel level =
        _level(input['complexity'], _myLevel(household));
    final int? maxMinutes = (input['max_minutes'] as num?)?.round();
    final dishes = await _dishesAround(id, days, <String>{
      for (final DayKey d in days)
        for (final MealSlotKind s in slots) '$d/${s.name}',
    });
    Object? failure;
    final List<ProposedMeal>? meals = await planner.proposeWeek(
      MealPlanRequest(
        days: days,
        slots: slots,
        people: <PlanFor>[
          for (final HouseholdMember m in household.members) m.toPlanFor(),
        ],
        wish: input['wish'] as String?,
        maxMinutes: maxMinutes != null && maxMinutes > 0 ? maxMinutes : null,
        level: level,
        avoidTitles: dishes.recent,
        plannedTitles: dishes.planned,
      ),
      onError: (Object error) => failure = error,
    );
    if (meals == null) {
      return failure != null
          ? 'Failed: $failure'
          : 'The model gave no plan that adds up. Try again, or fewer days.';
    }
    final PlanChange change = await _actions.acceptProposal(meals);
    record(FunkiChange(
      l10n.funkiPlannedWeek(meals.length, l10n.cookingLevelName(level)),
      () => _actions.undoPlanChange(change),
    ));
    final Set<String> got = <String>{
      for (final ProposedMeal m in meals) '${m.day}/${m.slot.name}',
    };
    return <String, Object?>{
      'complexity': level.name,
      'planned': <Map<String, Object?>>[
        for (final ProposedMeal m in meals)
          <String, Object?>{
            'day': '${m.day}',
            'slot': m.slot.name,
            'title': m.recipe.title,
            'kcal_per_serving': _r(m.recipe.perServing.kcal),
            if (m.recipe.minutes != null) 'minutes': m.recipe.minutes,
          },
      ],
      'not_planned': <String>[
        for (final DayKey d in days)
          for (final MealSlotKind s in slots)
            if (!got.contains('$d/${s.name}')) '$d ${s.name}',
      ],
      'note': 'Each has its full recipe. make_list_from_plan puts what '
          'they need on the shopping list.',
    };
  }

  Future<Object?> _writeRecipe(Map<String, dynamic> input) async {
    final DayKey day = _day(input['day'], focus.day);
    final MealSlotKind slot = _slot(input['slot']);
    final (PlanEntry, Recipe)? planned = await _planned(day, slot);
    if (planned == null) return 'Nothing is planned there.';
    final (PlanEntry entry, Recipe recipe) = planned;
    final Household household = await _backend.household(await _householdId);
    final CookingLevel level = _level(
        input['complexity'], recipe.level ?? _myLevel(household));
    Object? failure;
    final RecipeRewrite? done = await _actions.writeRecipe(entry, recipe, level,
        onError: (Object error) => failure = error);
    if (done == null) {
      return failure != null
          ? 'Failed: $failure'
          : 'The model wrote no recipe that adds up. Try again.';
    }
    record(FunkiChange(
      l10n.recipeWritten(done.now.title, l10n.cookingLevelName(level)),
      () => _actions.undoRewrite(done),
    ));
    return <String, Object?>{
      'title': done.now.title,
      'complexity': level.name,
      if (done.now.minutes != null) 'minutes': done.now.minutes,
      'ingredients': done.now.ingredients.length,
      'steps': done.now.steps.length,
      'note': 'get_recipe has it in full. make_list_from_plan puts what it '
          'needs on the shopping list.',
    };
  }

  Future<String> _moveMeal(Map<String, dynamic> input) async {
    final DayKey from = _day(input['from_day'], focus.day);
    final MealSlotKind fromSlot = _slot(input['from_slot']);
    final DayKey to = _day(input['to_day'], from);
    final MealSlotKind toSlot =
        input['to_slot'] == null ? fromSlot : _slot(input['to_slot']);
    if (from == to && fromSlot == toSlot) return 'It is there already.';
    final (PlanEntry, Recipe)? planned = await _planned(from, fromSlot);
    if (planned == null) return 'Nothing is planned there.';
    final (PlanEntry entry, Recipe recipe) = planned;
    final String id = await _householdId;
    final List<PlanEntry> before = <PlanEntry>[
      entry,
      ...(await _backend.plan(id, to, to))
          .where((PlanEntry e) => e.slot == toSlot && e.id != entry.id),
    ];
    await _actions.moveEntry(entry, to, toSlot);
    record(FunkiChange(
      l10n.funkiMovedMeal(recipe.title, l10n.formatDay(to), l10n.mealName(toSlot)),
      () async {
        for (final PlanEntry e in before) {
          await _actions.restoreEntry(e);
        }
      },
    ));
    return before.length > 1
        ? 'Moved ${recipe.title} to $to (${toSlot.name}); what was there '
            'is on $from (${fromSlot.name}) now.'
        : 'Moved ${recipe.title} to $to (${toSlot.name}).';
  }

  Future<String> _setMeal(Map<String, dynamic> input) async {
    final DayKey day = _day(input['day'], focus.day);
    final String id = await _householdId;
    final CookingLevel level = _level(
        input['complexity'], _myLevel(await _backend.household(id)));
    final List<ProposedMeal> parsed = parseMealPlan(
      jsonEncode(<String, dynamic>{
        'meals': <Object>[
          <String, dynamic>{...input, 'day': day.toString()},
        ],
      }),
      MealPlanRequest(
        days: <DayKey>[day],
        slots: MealSlotKind.values,
        people: const <PlanFor>[],
        level: level,
      ),
    );
    if (parsed.isEmpty) {
      return 'Rejected: the numbers or ingredients do not add up. Check that '
          'kcal matches the macros for one serving and every ingredient has '
          'an amount in g, ml or pieces.';
    }
    final ProposedMeal meal = parsed.single;
    final List<PlanEntry> before = (await _backend.plan(id, day, day))
        .where((PlanEntry e) => e.slot == meal.slot)
        .toList();
    for (final PlanEntry old in before) {
      await _backend.removeEntry(old.id);
    }
    final (PlanEntry now, Recipe stored) =
        await _actions.setMeal(meal.day, meal.slot, meal.recipe, fromAi: true);
    record(FunkiChange(
      l10n.plannerSetMeal(l10n.formatDay(day), l10n.mealName(meal.slot), stored.title),
      () async {
        await _actions.removeEntry(now.id);
        for (final PlanEntry e in before) {
          await _actions.restoreEntry(e);
        }
      },
    ));
    return 'Planned ${stored.title} on ${meal.day} (${meal.slot.name}).';
  }

  Future<String> _removeMeal(Map<String, dynamic> input) async {
    final DayKey day = _day(input['day'], focus.day);
    final MealSlotKind slot = _slot(input['slot']);
    final String id = await _householdId;
    final List<PlanEntry> removed = (await _backend.plan(id, day, day))
        .where((PlanEntry e) => e.slot == slot)
        .toList();
    if (removed.isEmpty) return 'Nothing was planned there.';
    for (final PlanEntry e in removed) {
      await _actions.removeEntry(e.id);
    }
    record(FunkiChange(
      l10n.plannerRemovedMeal(l10n.formatDay(day), l10n.mealName(slot)),
      () async {
        for (final PlanEntry e in removed) {
          await _actions.restoreEntry(e);
        }
      },
    ));
    return 'Removed.';
  }

  // ── The shopping list ───────────────────────────────────────────────

  Future<ShoppingListInfo?> _currentList() async {
    final List<ShoppingListInfo> open = await _backend.openLists(await _householdId);
    return open.isEmpty ? null : open.first;
  }

  /// The meals up to the next trip that a list cannot shop for.
  Future<List<Map<String, Object?>>> _withoutRecipe(Household household) async {
    final String id = household.id;
    final ShoppingPeriod period = household.cadence.periodFrom(DayKey.today());
    final Map<String, Recipe> recipes = await _backend.recipes(id);
    return <Map<String, Object?>>[
      for (final PlanEntry e in mealsWithoutRecipe(
        entries: await _backend.plan(id, period.start, period.end),
        recipes: recipes,
        period: period,
      ))
        if (recipes[e.recipeId] case final Recipe r)
          <String, Object?>{'day': '${e.day}', 'slot': e.slot.name, 'title': r.title},
    ];
  }

  Future<Map<String, Object?>> _listSnapshot() async {
    final Household household = await _backend.household(await _householdId);
    final ShoppingListInfo? list = await _currentList();
    final List<Map<String, Object?>> unwritten = await _withoutRecipe(household);
    return <String, Object?>{
      'list': list == null ? null : 'for ${list.period}',
      'lines': <Map<String, Object?>>[
        if (list != null)
          for (final ShoppingLine l in await _backend.items(list.id))
            <String, Object?>{
              'name': l.name,
              if (l.quantity != null) 'amount': l10n.quantityLabel(l.quantity!),
              'section': l.category == ShopCategory.staples
                  ? 'kitchen basics — to check at home, no amount'
                  : l.category.name,
              'in_basket': l.checked,
            },
      ],
      'always_at_home': household.pantry,
      if (unwritten.isNotEmpty) 'meals_without_recipe': unwritten,
      if (unwritten.isNotEmpty)
        'note': 'Those meals are missing from the list: write_recipe '
            'writes their recipe, then make_list_from_plan adds it.',
    };
  }

  /// The lines of [list] called [name], however it was written.
  Future<List<ShoppingLine>> _lines(ShoppingListInfo list, String name) async =>
      (await _backend.items(list.id))
          .where((ShoppingLine l) => shoppingKey(l.name) == shoppingKey(name))
          .toList();

  Future<String> _addToList(Map<String, dynamic> input) async {
    final List<(String, Quantity?)> wanted = <(String, Quantity?)>[
      for (final String name in _strings(input['name'])) (name, null),
      for (final Object? item in (input['items'] as List?) ?? const <Object?>[])
        if (item is String && item.trim().isNotEmpty)
          (item.trim(), null)
        else if (item is Map && '${item['name'] ?? ''}'.trim().isNotEmpty)
          (
            '${item['name']}'.trim(),
            item['qty'] is num
                ? Quantity.parse(item['qty'] as num, item['unit'] as String?)
                : null,
          ),
    ];
    if (wanted.isEmpty) return 'No name given.';
    final ShoppingListInfo list = await _currentList() ?? await _actions.emptyList();
    final List<String> labels = <String>[];
    for (final (String name, Quantity? quantity) in wanted) {
      final List<ShoppingLine> added =
          await _actions.addItem(list.id, name, quantity: quantity);
      final String label =
          quantity == null ? name : '${l10n.quantityLabel(quantity)} $name';
      labels.add(label);
      // Only the line this added: a "Milch" that was on the list before stays.
      record(FunkiChange(l10n.plannerAdded(label), () async {
        for (final ShoppingLine line in added) {
          await _actions.removeItem(line);
        }
      }));
    }
    return 'Added ${labels.join(', ')}.';
  }

  Future<String> _removeFromList(Map<String, dynamic> input) async {
    final List<String> names = <String>[
      ..._strings(input['name']),
      ..._strings(input['names']),
    ];
    if (names.isEmpty) return 'No name given.';
    final ShoppingListInfo? list = await _currentList();
    if (list == null) return 'There is no list.';
    final List<String> removed = <String>[];
    final List<String> absent = <String>[];
    for (final String name in names) {
      final List<ShoppingLine> matching = await _lines(list, name);
      if (matching.isEmpty) {
        absent.add(name);
        continue;
      }
      for (final ShoppingLine l in matching) {
        await _actions.removeItem(l);
      }
      removed.add(name);
      record(FunkiChange(l10n.plannerRemoved(name), () async {
        for (final ShoppingLine l in matching) {
          await _actions.restoreItem(l);
        }
      }));
    }
    return <String>[
      if (removed.isNotEmpty) 'Removed ${removed.join(', ')}.',
      if (absent.isNotEmpty) 'Not on the list: ${absent.join(', ')}.',
    ].join(' ');
  }

  Future<String> _tickItems(Map<String, dynamic> input) async {
    final List<String> names = _strings(input['names']);
    if (names.isEmpty) return 'No name given.';
    final bool on = input['in_basket'] != false;
    final ShoppingListInfo? list = await _currentList();
    if (list == null) return 'There is no list.';
    final List<String> done = <String>[];
    final List<String> absent = <String>[];
    for (final String name in names) {
      final List<ShoppingLine> matching = (await _lines(list, name))
          .where((ShoppingLine l) => l.checked != on)
          .toList();
      if (matching.isEmpty) {
        absent.add(name);
        continue;
      }
      for (final ShoppingLine l in matching) {
        await _actions.setChecked(l, on);
      }
      done.add(name);
      record(FunkiChange(
        on ? l10n.funkiTicked(name) : l10n.funkiUnticked(name),
        () async {
          for (final ShoppingLine l in matching) {
            await _actions.setChecked(l, !on);
          }
        },
      ));
    }
    return <String>[
      if (done.isNotEmpty)
        '${on ? 'In the basket' : 'Open again'}: ${done.join(', ')}.',
      if (absent.isNotEmpty)
        'Not on the list, or already ${on ? 'ticked' : 'open'}: '
            '${absent.join(', ')}.',
    ].join(' ');
  }

  Future<Object?> _listFromPlan() async {
    final ListFromPlan made = await _actions.listFromPlan();
    final List<Map<String, Object?>> unwritten = await _withoutRecipe(
        await _backend.household(await _householdId));
    if (made.created) {
      record(FunkiChange(l10n.plannerListMade, () async {
        await _backend.closeList(made.list.id);
        _c.invalidate(openListsProvider);
      }));
    } else {
      // The trip's list was open already and got what it lacked: undo takes
      // exactly that back off.
      record(FunkiChange(l10n.plannerListToppedUp, () async {
        for (final ShoppingLine line in made.added) {
          await _actions.removeItem(line);
        }
      }));
    }
    final int basics = made.added
        .where((ShoppingLine l) => l.category == ShopCategory.staples)
        .length;
    return <String, Object?>{
      'result': made.created
          ? 'Made a list for ${made.list.period} with ${made.added.length} lines.'
          : 'The list for ${made.list.period} was open already; added '
              '${made.added.length} missing lines to it.',
      if (basics > 0)
        'kitchen_basics': '$basics of them are basics (oil, salt, spices) '
            'without an amount, to check at home.',
      if (unwritten.isNotEmpty) 'meals_without_recipe': unwritten,
      if (unwritten.isNotEmpty)
        'note': 'Those meals are not on the list. Offer to write their '
            'recipes (write_recipe), then make the list again.',
    };
  }

  Future<String> _setPantry(Map<String, dynamic> input) async {
    final List<String> add = _strings(input['add']);
    final Set<String> remove = _strings(input['remove']).map(shoppingKey).toSet();
    final Household household = await _backend.household(await _householdId);
    final List<String> before = household.pantry;
    final Set<String> have = before.map(shoppingKey).toSet();
    final List<String> added = <String>[
      for (final String name in add)
        if (have.add(shoppingKey(name))) name,
    ];
    final List<String> removed = <String>[
      for (final String name in before)
        if (remove.contains(shoppingKey(name))) name,
    ];
    if (added.isEmpty && removed.isEmpty) return 'Nothing to change.';
    await _actions.updateHousehold(pantry: <String>[
      for (final String name in before)
        if (!remove.contains(shoppingKey(name))) name,
      ...added,
    ]);
    // What is always at home comes off the list that is open, too.
    final ShoppingListInfo? list = await _currentList();
    final List<ShoppingLine> offList = <ShoppingLine>[
      if (list != null)
        for (final String name in added)
          for (final ShoppingLine l in await _lines(list, name))
            if (!l.checked) l,
    ];
    for (final ShoppingLine l in offList) {
      await _actions.removeItem(l);
    }
    record(FunkiChange(
      <String>[
        if (added.isNotEmpty) l10n.funkiPantryAdded(added.join(', ')),
        if (removed.isNotEmpty) l10n.funkiPantryRemoved(removed.join(', ')),
      ].join(' · '),
      () async {
        await _actions.updateHousehold(pantry: before);
        for (final ShoppingLine l in offList) {
          await _actions.restoreItem(l);
        }
      },
    ));
    return <String>[
      if (added.isNotEmpty) 'Always at home now: ${added.join(', ')}.',
      if (removed.isNotEmpty) 'No longer: ${removed.join(', ')}.',
      if (offList.isNotEmpty)
        'Taken off the current list: '
            '${offList.map((ShoppingLine l) => l.name).join(', ')}.',
    ].join(' ');
  }

  Future<String> _setTastes(Map<String, dynamic> input) async {
    final Household household = await _backend.household(await _householdId);
    final HouseholdMember? me = household.member(_me);
    if (me == null) return 'The user is in no household.';
    final HouseholdMember now = me.withTastes(
      diet: (input['diet'] as String?)?.trim(),
      dislikes: input['dislikes'] is List ? _strings(input['dislikes']) : null,
      allergies: input['allergies'] is List ? _strings(input['allergies']) : null,
      cooking: input['complexity'] == null
          ? null
          : _level(input['complexity'], CookingLevel.everyday),
    );
    if (jsonEncode(now.preferencesJson()) == jsonEncode(me.preferencesJson())) {
      return 'Nothing to change.';
    }
    await _actions.updateMe(now);
    record(FunkiChange(l10n.funkiTastesChanged, () => _actions.updateMe(me)));
    return 'Saved. Plans from now on respect it; what is planned already '
        'stays as it is.';
  }

  // ── Training and friends ────────────────────────────────────────────

  Future<Map<String, Object?>> _training() async {
    final AppSnapshot s = await _snapshot;
    final Challenge? challenge = s.challenge;
    final Workout? workout =
        challenge == null ? null : s.plan?.workoutFor(challenge.startDay, s.today);
    return <String, Object?>{
      'has_training_plan': s.plan?.training != null,
      'today': workout == null
          ? null
          : <String, Object?>{
              'name': l10n.workoutName(workout.kind),
              'minutes': workout.estimatedMinutes,
              if (workout.isDeload) 'deload': true,
              'exercises': <Map<String, Object?>>[
                for (final PlannedSet b in workout.blocks)
                  <String, Object?>{
                    'name': l10n.exerciseName(b.exerciseId),
                    'sets': b.sets,
                    'reps': b.repsLow == b.repsHigh ? '${b.repsLow}' : '${b.repsLow}-${b.repsHigh}',
                  },
              ],
            },
      'logged_today': s.me.workoutLogOn(s.today) != null,
      'recent': <Map<String, Object?>>[
        for (final WorkoutLog log in s.me.workoutLogs.reversed.take(5))
          <String, Object?>{
            'day': '${log.day}',
            'name': l10n.workoutName(log.kind),
            'exercises': <Map<String, Object?>>[
              for (final ExerciseLog e in log.exercises)
                <String, Object?>{
                  'name': l10n.exerciseName(e.exerciseId),
                  'sets': <String>[
                    for (final LoggedSet set in e.sets)
                      set.weightKg > 0 ? '${set.reps} x ${set.weightKg} kg' : '${set.reps}',
                  ],
                },
            ],
          },
      ],
    };
  }

  static const String _noTrainingPlan =
      'The user has no training plan. They can switch one on under Plan → '
      'Training.';

  /// The challenge and its training as configured — or as proposed, for a
  /// plan the user never edited. Null without a training plan.
  Future<(Challenge, TrainingSetup)?> _trainingSetup() async {
    final AppSnapshot s = await _snapshot;
    final Challenge? challenge = s.challenge;
    if (challenge == null || s.plan?.training == null) return null;
    return (
      challenge,
      challenge.goal.training ?? suggestTrainingSetup(challenge.goal),
    );
  }

  String _reps(ExerciseSlot slot) => slot.repsLow == slot.repsHigh
      ? '${slot.repsLow}'
      : '${slot.repsLow}-${slot.repsHigh}';

  Future<Object?> _trainingPlan() async {
    final (Challenge, TrainingSetup)? plan = await _trainingSetup();
    if (plan == null) return _noTrainingPlan;
    final (Challenge challenge, TrainingSetup setup) = plan;
    return <String, Object?>{
      'split': setup.split.name,
      'split_name': l10n.splitName(setup.split),
      'days_per_week': challenge.goal.trainingDaysPerWeek.clamp(2, 6),
      'equipment': challenge.goal.equipment.name,
      'sessions': <Map<String, Object?>>[
        for (int i = 0; i < setup.sessions.length; i++)
          <String, Object?>{
            'session': i + 1,
            'name': l10n.workoutName(setup.sessions[i].kind),
            'exercises': <Map<String, Object?>>[
              for (int j = 0; j < setup.sessions[i].exercises.length; j++)
                <String, Object?>{
                  'position': j + 1,
                  'id': setup.sessions[i].exercises[j].exerciseId,
                  'name': l10n.exerciseName(
                      setup.sessions[i].exercises[j].exerciseId),
                  'sets': setup.sessions[i].exercises[j].sets,
                  'reps': _reps(setup.sessions[i].exercises[j]),
                  'rest_seconds': setup.sessions[i].exercises[j].restSeconds,
                },
            ],
          },
      ],
      'note': 'Sessions rotate across the training days. These are the '
          'base sets: build weeks add sets to compound lifts, every fourth '
          'week is a deload.',
    };
  }

  Future<Object?> _findExercises(Map<String, dynamic> input) async {
    final (Challenge, TrainingSetup)? plan = await _trainingSetup();
    if (plan == null) return _noTrainingPlan;
    final EquipmentAccess access = plan.$1.goal.equipment;
    final String like = '${input['like'] ?? ''}'.trim();
    final MuscleGroup? muscle = MuscleGroup.values.asNameMap()[input['muscle']];
    final List<Exercise> found;
    if (like.isNotEmpty) {
      if (kExerciseById[like] == null) {
        return 'No exercise with the id "$like". get_training_plan has the ids.';
      }
      found = alternativesFor(like, access);
    } else if (muscle != null) {
      found = exercisesByMuscle(access)[muscle] ?? const <Exercise>[];
    } else {
      return 'Give a muscle, or an exercise id to replace (like).';
    }
    return <Map<String, Object?>>[
      for (final Exercise e in found.take(25))
        <String, Object?>{
          'id': e.id,
          'name': l10n.exerciseName(e.id),
          'muscle': e.primary.name,
          'kind': e.isCompound ? 'compound' : 'isolation',
          if (e.isBodyweight) 'bodyweight': true,
        },
    ];
  }

  /// Saves [now] as the user's training and records the way back. Like the
  /// editor: a challenge update, so the days trained so far stay as they
  /// were.
  Future<void> _saveTraining(
    Challenge challenge,
    TrainingSetup before,
    TrainingSetup now,
    String label,
  ) async {
    await _app.updateChallenge(challenge.copyWith(
      goal: challenge.goal.copyWith(training: now),
    ));
    record(FunkiChange(label, () async {
      final Challenge? current = (await _snapshot).challenge;
      if (current == null) return;
      await _app.updateChallenge(current.copyWith(
        goal: current.goal.copyWith(training: before),
      ));
    }));
  }

  /// The session [input] names, by its number, or why there is none.
  (int, SessionPlan)? _session(TrainingSetup setup, Map<String, dynamic> input) {
    final int index = ((input['session'] as num?)?.round() ?? 0) - 1;
    if (index < 0 || index >= setup.sessions.length) return null;
    return (index, setup.sessions[index]);
  }

  /// An exercise by its id, if the library has it and the user's equipment
  /// allows it — or the reason it cannot be used.
  (Exercise?, String?) _exercise(Object? id, Goal goal) {
    final Exercise? exercise = kExerciseById['$id'];
    if (exercise == null) {
      return (null, 'No exercise with the id "$id". find_exercises has the ids.');
    }
    if (!exercise.availableWith(goal.equipment)) {
      return (
        null,
        "${l10n.exerciseName(exercise.id)} needs equipment the user does "
            'not have. find_exercises lists what they can do.',
      );
    }
    return (exercise, null);
  }

  static const String _noSuchSession =
      'No such session. get_training_plan numbers them.';
  static const String _noSuchPosition =
      'No exercise at that position. get_training_plan numbers them.';

  Future<String> _changeExercise(Map<String, dynamic> input) async {
    final (Challenge, TrainingSetup)? plan = await _trainingSetup();
    if (plan == null) return _noTrainingPlan;
    final (Challenge challenge, TrainingSetup setup) = plan;
    final (int, SessionPlan)? found = _session(setup, input);
    if (found == null) return _noSuchSession;
    final (int index, SessionPlan session) = found;
    final int position = ((input['position'] as num?)?.round() ?? 0) - 1;
    if (position < 0 || position >= session.exercises.length) {
      return _noSuchPosition;
    }
    final ExerciseSlot before = session.exercises[position];
    ExerciseSlot now = before;
    if (input['exercise_id'] != null && input['exercise_id'] != before.exerciseId) {
      final (Exercise? exercise, String? problem) =
          _exercise(input['exercise_id'], challenge.goal);
      if (exercise == null) return problem!;
      if (session.exercises.any((ExerciseSlot s) => s.exerciseId == exercise.id)) {
        return '${l10n.exerciseName(exercise.id)} is in that session already.';
      }
      now = swapSlot(before, exercise, challenge.goal);
    }
    now = now.copyWith(
      sets: (input['sets'] as num?)?.round(),
      repsLow: (input['reps_low'] as num?)?.round(),
      repsHigh: (input['reps_high'] as num?)?.round(),
      restSeconds: (input['rest_seconds'] as num?)?.round(),
    );
    if (now == before) return 'Nothing to change.';
    final String name = l10n.workoutName(session.kind);
    await _saveTraining(
      challenge,
      setup,
      setup.withSession(
        index,
        session.copyWith(exercises: <ExerciseSlot>[
          for (int i = 0; i < session.exercises.length; i++)
            i == position ? now : session.exercises[i],
        ]),
      ),
      now.exerciseId != before.exerciseId
          ? l10n.funkiExerciseSwapped(name, l10n.exerciseName(before.exerciseId),
              l10n.exerciseName(now.exerciseId))
          : l10n.funkiExerciseChanged(
              name, l10n.exerciseName(now.exerciseId), now.sets, _reps(now)),
    );
    return '$name: ${l10n.exerciseName(now.exerciseId)}, ${now.sets} sets of '
        '${_reps(now)}, ${now.restSeconds} s rest.';
  }

  Future<String> _addExercise(Map<String, dynamic> input) async {
    final (Challenge, TrainingSetup)? plan = await _trainingSetup();
    if (plan == null) return _noTrainingPlan;
    final (Challenge challenge, TrainingSetup setup) = plan;
    final (int, SessionPlan)? found = _session(setup, input);
    if (found == null) return _noSuchSession;
    final (int index, SessionPlan session) = found;
    final (Exercise? exercise, String? problem) =
        _exercise(input['exercise_id'], challenge.goal);
    if (exercise == null) return problem!;
    if (session.exercises.any((ExerciseSlot s) => s.exerciseId == exercise.id)) {
      return '${l10n.exerciseName(exercise.id)} is in that session already.';
    }
    if (session.exercises.length >= 12) return 'That session is full.';
    final ExerciseSlot slot = defaultSlotFor(exercise, challenge.goal).copyWith(
      sets: (input['sets'] as num?)?.round(),
      repsLow: (input['reps_low'] as num?)?.round(),
      repsHigh: (input['reps_high'] as num?)?.round(),
    );
    final int at = (((input['position'] as num?)?.round() ??
                session.exercises.length + 1) -
            1)
        .clamp(0, session.exercises.length);
    final String name = l10n.workoutName(session.kind);
    await _saveTraining(
      challenge,
      setup,
      setup.withSession(
        index,
        session.copyWith(
            exercises: List<ExerciseSlot>.of(session.exercises)..insert(at, slot)),
      ),
      l10n.funkiExerciseAdded(name, l10n.exerciseName(exercise.id)),
    );
    return 'Added ${l10n.exerciseName(exercise.id)} to $name: ${slot.sets} '
        'sets of ${_reps(slot)}.';
  }

  Future<String> _removeExercise(Map<String, dynamic> input) async {
    final (Challenge, TrainingSetup)? plan = await _trainingSetup();
    if (plan == null) return _noTrainingPlan;
    final (Challenge challenge, TrainingSetup setup) = plan;
    final (int, SessionPlan)? found = _session(setup, input);
    if (found == null) return _noSuchSession;
    final (int index, SessionPlan session) = found;
    final int position = ((input['position'] as num?)?.round() ?? 0) - 1;
    if (position < 0 || position >= session.exercises.length) {
      return _noSuchPosition;
    }
    final SessionPlan without = session.copyWith(exercises: <ExerciseSlot>[
      for (int i = 0; i < session.exercises.length; i++)
        if (i != position) session.exercises[i],
    ]);
    // A session with nothing in it is a workout that can never be finished.
    if (!without.isTrainable) {
      return 'That is the last exercise of the session; it cannot be empty. '
          'Swap it instead.';
    }
    final String name = l10n.workoutName(session.kind);
    final String gone = l10n.exerciseName(session.exercises[position].exerciseId);
    await _saveTraining(challenge, setup, setup.withSession(index, without),
        l10n.funkiExerciseRemoved(name, gone));
    return 'Removed $gone from $name.';
  }

  Future<String> _setTrainingDays(Map<String, dynamic> input) async {
    final (Challenge, TrainingSetup)? plan = await _trainingSetup();
    if (plan == null) return _noTrainingPlan;
    final (Challenge challenge, TrainingSetup setup) = plan;
    final int daysBefore = challenge.goal.trainingDaysPerWeek.clamp(2, 6);
    final int? asked = (input['days_per_week'] as num?)?.round();
    if (asked != null && (asked < 2 || asked > 6)) {
      return 'Between 2 and 6 days a week.';
    }
    final int days = asked ?? daysBefore;
    final SplitKind? split = input['split'] == null
        ? null
        : SplitKind.values.asNameMap()[input['split']];
    if (input['split'] != null && split == null) {
      return 'split must be one of '
          '${SplitKind.values.map((SplitKind k) => k.name).join(', ')}.';
    }
    final Goal goal = challenge.goal.copyWith(trainingDaysPerWeek: days);
    final TrainingSetup now = split == null || split == setup.split
        ? setup
        : suggestTrainingSetup(goal, split: split);
    if (days == daysBefore && now == setup) return 'Nothing to change.';
    // The habit the plan checks in follows its days, as in the editor.
    final String? habitId = trainingHabitOf(challenge.habits)?.id;
    final DayKey today = DayKey.today();
    Challenge withPlan(Challenge c, TrainingSetup training, int perWeek) =>
        c.copyWith(
          goal: c.goal.copyWith(training: training, trainingDaysPerWeek: perWeek),
          habits: <Habit>[
            for (final Habit h in c.habits)
              h.id == habitId ? h.withDaysPerWeek(perWeek, from: today) : h,
          ],
        );
    await _app.updateChallenge(withPlan(challenge, now, days));
    record(FunkiChange(
      l10n.funkiTrainingDays(l10n.splitName(now.split), days),
      () async {
        final Challenge? current = (await _snapshot).challenge;
        if (current == null) return;
        await _app.updateChallenge(withPlan(current, setup, daysBefore));
      },
    ));
    return 'Training is ${l10n.splitName(now.split)}, $days days a week now'
        '${now == setup ? '' : ', with that split\'s proposed exercises'}.';
  }

  Future<List<Map<String, Object?>>> _friends() async {
    final AppSnapshot s = await _snapshot;
    return <Map<String, Object?>>[
      for (final PeerState p in s.peerStates)
        <String, Object?>{
          'name': p.profile.displayName,
          'streak': p.currentStreak,
          'active_today': p.activeToday,
        },
    ];
  }
}
