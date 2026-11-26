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
/// opened the conversation: the one-line question and the chat it goes on
/// in are different screens.
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

/// Who Funki is, what day it is and where he was opened.
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
  };
  return l10n.promptFunki(
    today.toString(),
    l10n.weekdayLong(today.toDateTime().weekday),
    name.isEmpty ? l10n.promptFunkiNoName : name,
    where,
  );
}

const List<String> _kSlotNames = <String>['breakfast', 'lunch', 'snack', 'dinner'];

/// Funki's hands: everything he may read and change, as tools for the
/// model. Reads answer in JSON; every change goes to [record] with an undo,
/// and every answer the model writes goes through the same checks as the
/// rest of the app — a meal through [parseMealPlan], a food through
/// [foodEstimateFrom].
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
              "view): members with their targets and tastes, and every planned "
              'meal by day and slot.',
          (Map<String, dynamic> input) => _plan(input),
          input: S.object(properties: <String, Schema>{
            'week_start': S.string(description: 'YYYY-MM-DD, a Monday'),
          }),
        ),
        _tool(
          'get_recipe',
          'The recipe planned on a day and slot: ingredients, steps, '
              'calories per serving and the portion of each member.',
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
          input: Schema.fromMap(kMealSchema),
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
          'The current shopping list: every line with its amount and whether '
              'it is already in the basket.',
          (_) => _listSnapshot(),
        ),
        _tool(
          'add_to_list',
          'Adds a line to the current shopping list.',
          _addToList,
          input: S.object(
            properties: <String, Schema>{'name': S.string()},
            required: <String>['name'],
          ),
        ),
        _tool(
          'remove_from_list',
          'Removes a line from the current shopping list, e.g. because it is '
              'still at home.',
          _removeFromList,
          input: S.object(
            properties: <String, Schema>{'name': S.string()},
            required: <String>['name'],
          ),
        ),
        _tool(
          'make_list_from_plan',
          'Makes the shopping list for the next trip from the planned meals, '
              'or tops up the one already open.',
          (_) => _listFromPlan(),
        ),
        _tool(
          'get_training',
          "Today's workout from the training plan, and the last logged "
              'workouts with sets, reps and weights.',
          (_) => _training(),
        ),
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
    return <String, Object?>{
      'week': '$start – ${start.addDays(6)}',
      'members': <String>[
        for (final HouseholdMember m in household.members) describePerson(m.toPlanFor()),
      ],
      'meals': <Map<String, Object?>>[
        for (final PlanEntry e in entries)
          <String, Object?>{
            'day': e.day.toString(),
            'slot': e.slot.name,
            'title': recipes[e.recipeId]?.title,
            'kcal_per_serving': recipes[e.recipeId]?.perServing.kcal.round(),
          },
      ],
    };
  }

  Future<Object?> _recipe(Map<String, dynamic> input) async {
    final DayKey day = _day(input['day'], focus.day);
    final MealSlotKind slot = _slot(input['slot']);
    final String id = await _householdId;
    final Household household = await _backend.household(id);
    final Map<String, Recipe> recipes = await _backend.recipes(id);
    for (final PlanEntry e in await _backend.plan(id, day, day)) {
      final Recipe? r = recipes[e.recipeId];
      if (e.slot != slot || r == null) continue;
      return <String, Object?>{
        'title': r.title,
        'servings': r.servings,
        if (r.minutes != null) 'minutes': r.minutes,
        'per_serving': _nutrients(r.perServing),
        'ingredients': <String>[
          for (final Ingredient i in r.ingredients) '${l10n.quantityLabel(i.quantity)} ${i.name}',
        ],
        'steps': r.steps,
        'portions': <String, double>{
          for (final HouseholdMember m in household.members) m.displayName: e.portionFor(m.userId),
        },
      };
    }
    return 'Nothing is planned there.';
  }

  Future<String> _setMeal(Map<String, dynamic> input) async {
    final DayKey day = _day(input['day'], focus.day);
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
      ),
    );
    if (parsed.isEmpty) {
      return 'Rejected: the numbers or ingredients do not add up. Check that '
          'kcal matches the macros for one serving and every ingredient has '
          'an amount in g, ml or pieces.';
    }
    final ProposedMeal meal = parsed.single;
    final String id = await _householdId;
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

  Future<List<Map<String, Object?>>> _listSnapshot() async {
    final ShoppingListInfo? list = await _currentList();
    if (list == null) return const <Map<String, Object?>>[];
    return <Map<String, Object?>>[
      for (final ShoppingLine l in await _backend.items(list.id))
        <String, Object?>{
          'name': l.name,
          if (l.quantity != null) 'amount': l10n.quantityLabel(l.quantity!),
          'in_basket': l.checked,
        },
    ];
  }

  Future<String> _addToList(Map<String, dynamic> input) async {
    final String name = '${input['name'] ?? ''}'.trim();
    if (name.isEmpty) return 'No name given.';
    final ShoppingListInfo list = await _currentList() ?? await _actions.emptyList();
    final List<ShoppingLine> added = await _actions.addItem(list.id, name);
    // Only the line this added: a "Milch" that was on the list before stays.
    record(FunkiChange(l10n.plannerAdded(name), () async {
      for (final ShoppingLine line in added) {
        await _actions.removeItem(line);
      }
    }));
    return 'Added $name.';
  }

  Future<String> _removeFromList(Map<String, dynamic> input) async {
    final String name = '${input['name'] ?? ''}'.trim();
    final ShoppingListInfo? list = await _currentList();
    if (list == null) return 'There is no list.';
    final List<ShoppingLine> matching = (await _backend.items(list.id))
        .where((ShoppingLine l) => shoppingKey(l.name) == shoppingKey(name))
        .toList();
    if (matching.isEmpty) return '$name is not on the list.';
    for (final ShoppingLine l in matching) {
      await _actions.removeItem(l);
    }
    record(FunkiChange(l10n.plannerRemoved(name), () async {
      for (final ShoppingLine l in matching) {
        await _actions.restoreItem(l);
      }
    }));
    return 'Removed $name.';
  }

  Future<String> _listFromPlan() async {
    final ListFromPlan made = await _actions.listFromPlan();
    if (made.created) {
      record(FunkiChange(l10n.plannerListMade, () async {
        await _backend.closeList(made.list.id);
        _c.invalidate(openListsProvider);
      }));
      return 'Made a list for ${made.list.period} with ${made.added.length} lines.';
    }
    // The trip's list was open already and got what it lacked: undo takes
    // exactly that back off.
    record(FunkiChange(l10n.plannerListToppedUp, () async {
      for (final ShoppingLine line in made.added) {
        await _actions.removeItem(line);
      }
    }));
    return 'The list for ${made.list.period} was open already; added '
        '${made.added.length} missing lines to it.';
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
