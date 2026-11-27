import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

import '../ai/llm_client.dart';
import '../feed/event.dart' show newEventId;
import '../nutrition/foods.dart';
import '../nutrition/nutrition_assistant.dart' show AiErrorCallback, askModel;
import '../plan/nutrition.dart';
import '../util/dates.dart';
import 'meal_plan.dart';
import 'recipe.dart';

/// The JSON shape a meal plan proposal asks for. The example carries real
/// numbers on purpose, for the same reason as the meal estimate's: models
/// copy zeros. It also carries the oil and the spice: a model that sees a
/// recipe of two ingredients writes recipes of two ingredients.
const String kMealPlanJson = '{"meals":[{"day":"2026-11-18","slot":"dinner",'
    '"title":"Chicken curry with rice","servings":2,"minutes":30,'
    '"kcal":640,"protein":42,"carbs":70,"fat":18,'
    '"ingredients":[{"name":"chicken breast","qty":300,"unit":"g",'
    '"category":"meat"},{"name":"rice","qty":150,"unit":"g",'
    '"category":"pantry"},{"name":"onion","qty":1,"unit":"piece",'
    '"category":"produce"},{"name":"coconut milk","qty":200,"unit":"ml",'
    '"category":"pantry"},{"name":"rapeseed oil","qty":1,"unit":"tbsp",'
    '"category":"pantry","staple":true},{"name":"curry powder","qty":2,'
    '"unit":"tsp","category":"pantry","staple":true},{"name":"salt",'
    '"qty":0.5,"unit":"tsp","category":"pantry","staple":true}],'
    '"steps":["Simmer the rice in 300 ml salted water, lid on, for 12 '
    'minutes.","Dice the onion and the chicken.","Heat the oil in a pan '
    'over high heat and fry the chicken for 5 minutes until golden.","Add '
    'the onion and the curry powder, fry for 2 minutes, pour in the '
    'coconut milk and simmer for 8 minutes.","Season with salt and serve '
    'over the rice."]}]}';

/// [kMealPlanJson] as a JSON Schema, for models that can be held to one
/// (structured output). The checks in [parseMealPlan] still apply: a schema
/// fixes the shape, not whether the numbers make sense.
const Map<String, Object?> kMealPlanSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'meals': <String, Object?>{
      'type': 'array',
      'items': kMealSchema,
    },
  },
  'required': <String>['meals'],
};

/// One meal of [kMealPlanSchema] — also what a single drafted meal and the
/// chat's `set_meal` answer in.
const Map<String, Object?> kMealSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'day': <String, Object?>{'type': 'string', 'description': 'YYYY-MM-DD'},
    'slot': <String, Object?>{
      'type': 'string',
      'enum': <String>['breakfast', 'lunch', 'dinner', 'snack'],
    },
    'title': <String, Object?>{'type': 'string'},
    'servings': <String, Object?>{'type': 'integer'},
    'minutes': <String, Object?>{'type': 'integer'},
    'kcal': <String, Object?>{
      'type': 'number',
      'description': 'Calories of ONE serving',
    },
    'protein': <String, Object?>{'type': 'number'},
    'carbs': <String, Object?>{'type': 'number'},
    'fat': <String, Object?>{'type': 'number'},
    'ingredients': <String, Object?>{
      'type': 'array',
      'items': <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'name': <String, Object?>{'type': 'string'},
          'qty': <String, Object?>{'type': 'number'},
          'unit': <String, Object?>{
            'type': 'string',
            'enum': <String>['g', 'ml', 'piece', 'tbsp', 'tsp'],
          },
          'category': <String, Object?>{
            'type': 'string',
            'enum': <String>[
              'produce',
              'bakery',
              'dairy',
              'meat',
              'fish',
              'pantry',
              'frozen',
              'drinks',
              'household',
              'other',
            ],
          },
          'staple': <String, Object?>{
            'type': 'boolean',
            'description': 'true for a kitchen basic: oil, vinegar, salt, '
                'pepper, dried spices, sugar, flour. Never fresh food.',
          },
        },
        'required': <String>['name', 'qty', 'unit', 'category'],
      },
    },
    'steps': <String, Object?>{
      'type': 'array',
      'description': 'In order, one action each, with heat and times.',
      'items': <String, Object?>{'type': 'string'},
    },
  },
  'required': <String>[
    'day',
    'slot',
    'title',
    'servings',
    'kcal',
    'protein',
    'carbs',
    'fat',
    'ingredients',
  ],
};

/// Someone the plan is for.
@immutable
class PlanFor {
  const PlanFor({
    required this.name,
    this.dailyKcal,
    this.proteinG,
    this.dislikes = const <String>[],
    this.allergies = const <String>[],
    this.diet,
  });

  final String name;

  /// Only present when the member shares their targets with the household.
  final int? dailyKcal;
  final int? proteinG;
  final List<String> dislikes;
  final List<String> allergies;

  /// "vegetarian", "vegan", "pescetarian", or free text.
  final String? diet;
}

/// What to plan.
@immutable
class MealPlanRequest {
  const MealPlanRequest({
    required this.days,
    required this.slots,
    required this.people,
    this.wish,
    this.maxMinutes,
    this.level = CookingLevel.everyday,
    this.avoidTitles = const <String>[],
    this.plannedTitles = const <String>[],
  });

  final List<DayKey> days;
  final List<MealSlotKind> slots;
  final List<PlanFor> people;

  /// How much is made at home: what the recipes are written for, and what
  /// they are stamped with.
  final CookingLevel level;

  /// What the user typed: "no fish this week", "Wednesday something quick".
  final String? wish;
  final int? maxMinutes;

  /// Recent dishes, so a week does not repeat last week.
  final List<String> avoidTitles;

  /// Dishes already on this week's plan, in slots this request leaves as
  /// they are. A proposal that repeats one is dropped: a week with the same
  /// dinner twice is not what anyone asked for.
  final List<String> plannedTitles;

  /// Everything the prompt asks not to repeat, each once.
  List<String> get doNotRepeat {
    final seen = <String>{};
    return <String>[
      for (final title in <String>[...plannedTitles, ...avoidTitles])
        if (title.trim().isNotEmpty && seen.add(recipeKey(title))) title.trim(),
    ];
  }

  /// This request for [days] only, with [alsoPlanned] added to what is on
  /// the plan already — one part of a week asked for in several calls.
  MealPlanRequest forDays(List<DayKey> days, List<String> alsoPlanned) =>
      MealPlanRequest(
        days: days,
        slots: slots,
        people: people,
        wish: wish,
        maxMinutes: maxMinutes,
        level: level,
        avoidTitles: avoidTitles,
        plannedTitles: <String>[...plannedTitles, ...alsoPlanned],
      );
}

/// One meal for one slot, from what the user typed: a dish name — or
/// nothing, for "something that fits" — and, if they know it, the calories
/// of a portion.
@immutable
class MealDraftRequest {
  const MealDraftRequest({
    required this.day,
    required this.slot,
    required this.people,
    this.title,
    this.kcalPerServing,
    this.maxMinutes,
    this.level = CookingLevel.everyday,
  });

  final DayKey day;
  final MealSlotKind slot;
  final List<PlanFor> people;
  final String? title;
  final int? kcalPerServing;
  final int? maxMinutes;
  final CookingLevel level;

  bool get hasTitle => title != null && title!.trim().isNotEmpty;
}

/// A dish the model proposed for one slot, already checked.
@immutable
class ProposedMeal {
  const ProposedMeal({required this.day, required this.slot, required this.recipe});

  final DayKey day;
  final MealSlotKind slot;
  final Recipe recipe;
}

/// The prompt a planner sends. A port: written in the language the user
/// reads, by the app.
abstract class MealPlanPromptBuilder {
  String proposeWeek(MealPlanRequest request);

  String draftMeal(MealDraftRequest request);
}

class EnglishMealPlanPrompts implements MealPlanPromptBuilder {
  const EnglishMealPlanPrompts();

  @override
  String proposeWeek(MealPlanRequest request) {
    final people = request.people.map(describePerson).join('\n');
    return '''
You plan home cooking for a household. Plan these meals:
${request.days.map((DayKey d) => '- $d: ${request.slots.map((MealSlotKind s) => s.name).join(', ')}').join('\n')}

Who eats:
$people
${request.wish == null || request.wish!.trim().isEmpty ? '' : 'Their wish: "${request.wish!.trim()}"\n'}${request.maxMinutes == null ? '' : 'At most ${request.maxMinutes} minutes of cooking per meal.\n'}${request.doNotRepeat.isEmpty ? '' : 'Do not repeat: ${request.doNotRepeat.join(', ')}.\n'}${describeCookingLevel(request.level)}
Varied dishes from a normal supermarket. Reuse ingredients across the week
so little is left over. Give one recipe per meal with servings for the whole
household and the calories and macros of ONE serving.
$kRecipeRules
Answer with JSON only, in this form:
$kMealPlanJson
''';
  }

  @override
  String draftMeal(MealDraftRequest request) {
    final people = request.people.map(describePerson).join('\n');
    final dish = request.hasTitle
        ? 'The dish: "${request.title!.trim()}". Keep that name as the title.'
        : 'Pick a dish that suits the meal.';
    return '''
You write one home-cooking recipe for a household: ${request.slot.name} on ${request.day}.
$dish
${request.kcalPerServing == null ? '' : 'About ${request.kcalPerServing} kcal per serving.\n'}${request.maxMinutes == null ? '' : 'At most ${request.maxMinutes} minutes of cooking.\n'}${describeCookingLevel(request.level)}
Who eats:
$people

Give servings for the whole household and the calories and macros of ONE
serving.
$kRecipeRules
Answer with JSON only, in this form, with exactly one meal:
$kMealPlanJson
''';
  }
}

/// What every recipe is asked for, in the English prompts: the whole
/// ingredient list — the oil and the salt included, marked as basics — and
/// steps someone can cook from.
const String kRecipeRules =
    'Ingredients for all servings in g, ml or pieces (unit "g", "ml", '
    '"piece", "tbsp" or "tsp") with a category (produce, bakery, dairy, '
    'meat, fish, pantry, frozen, drinks, other). List EVERY ingredient the '
    'steps use, with a realistic amount: the fat for frying, salt, pepper, '
    'spices, herbs, stock, vinegar. Mark with "staple": true what a kitchen '
    'usually has and what is bought as a pack that lasts — oil, vinegar, '
    'salt, pepper, dried spices and herbs, sugar, flour, stock powder, soy '
    'sauce, mustard — and never fresh food. Steps are cooking instructions '
    'in order: one action each, with heat and times, so that someone who '
    'does not know the dish can cook it.';

/// One line about the cooking level for the English prompts.
String describeCookingLevel(CookingLevel level) => switch (level) {
      CookingLevel.convenience =>
        'Cooking level: convenience. Ready-made parts are welcome — '
            'ready-to-cook fillets, canned pulses, frozen vegetables, '
            'pre-cooked rice, a sauce from a jar, a spice mix. Few '
            'ingredients and few steps.',
      CookingLevel.everyday =>
        'Cooking level: everyday home cooking. Fresh main ingredients; '
            'canned tomatoes, canned pulses and stock from a cube are fine; '
            'no ready-made sauces or meals.',
      CookingLevel.scratch =>
        'Cooking level: from scratch. Whole, unprocessed ingredients — '
            'dried pulses soaked and cooked, whole fish or cuts of meat '
            'prepared at home, stock, sauces, doughs and spice blends made '
            'by hand. More steps and technique are welcome, and the steps '
            'explain them.',
    };

/// One line about a person for the prompt.
String describePerson(PlanFor p) {
  final parts = <String>[p.name];
  if (p.dailyKcal != null) parts.add('${p.dailyKcal} kcal/day');
  if (p.proteinG != null) parts.add('${p.proteinG} g protein/day');
  if (p.diet != null && p.diet!.isNotEmpty) parts.add(p.diet!);
  if (p.allergies.isNotEmpty) parts.add('allergic to ${p.allergies.join(', ')}');
  if (p.dislikes.isNotEmpty) parts.add('dislikes ${p.dislikes.join(', ')}');
  return '- ${parts.join('; ')}';
}

/// Proposes meals with the language model and keeps only what holds up.
///
/// Like the meal estimate: every failure is null, never an exception, and a
/// proposal is only ever a draft the user accepts or changes.
class MealPlanner {
  MealPlanner({
    required this.llm,
    this.prompts = const EnglishMealPlanPrompts(),
    this.timeout = const Duration(seconds: 90),
  });

  final LlmClient llm;
  final MealPlanPromptBuilder prompts;
  final Duration timeout;

  /// [onError] hears when the call failed before there was an answer —
  /// offline, timed out, allowance used up — as opposed to an answer that
  /// held nothing usable.
  ///
  /// A week of more than [kMealsPerCall] meals is asked for in several
  /// calls, a few days each: one answer cannot hold that many full recipes.
  /// Each call is told what the ones before it planned. When a later call
  /// fails, what the earlier ones gave is still a draft.
  Future<List<ProposedMeal>?> proposeWeek(
    MealPlanRequest request, {
    AiErrorCallback? onError,
  }) async {
    if (!llm.isReady || request.days.isEmpty || request.slots.isEmpty) return null;
    final daysPerCall =
        (kMealsPerCall ~/ request.slots.length).clamp(1, request.days.length);
    final meals = <ProposedMeal>[];
    for (var i = 0; i < request.days.length; i += daysPerCall) {
      final part = request.forDays(
        request.days.skip(i).take(daysPerCall).toList(),
        <String>[for (final meal in meals) meal.recipe.title],
      );
      final raw = await askModel(
        () => llm.generate(prompts.proposeWeek(part),
            purpose: LlmPurpose.plan,
            maxTokens: 8000,
            temperature: 0.7,
            json: true,
            schema: kMealPlanSchema,
            timeout: timeout),
        timeout: timeout,
        onError: onError,
      );
      // No answer: offline or out of allowance, and the next call would
      // fare no better.
      if (raw == null) break;
      try {
        meals.addAll(parseMealPlan(raw, part));
      } on Object {
        // An answer that is not a plan; the other days may still get one.
      }
    }
    return meals.isEmpty ? null : meals;
  }

  /// One meal for [request]'s slot, checked like a week's, or null. With
  /// calories given, a recipe more than [kKcalDraftTolerance] off them is
  /// not what was asked for and is dropped too.
  Future<ProposedMeal?> draftMeal(
    MealDraftRequest request, {
    AiErrorCallback? onError,
  }) async {
    if (!llm.isReady) return null;
    final raw = await askModel(
      () => llm.generate(prompts.draftMeal(request),
          purpose: LlmPurpose.plan,
          maxTokens: 3000,
          temperature: 0.5,
          json: true,
          schema: kMealPlanSchema,
          timeout: timeout),
      timeout: timeout,
      onError: onError,
    );
    if (raw == null) return null;
    try {
      final meals = parseMealPlan(
        raw,
        MealPlanRequest(
          days: <DayKey>[request.day],
          slots: <MealSlotKind>[request.slot],
          people: request.people,
          level: request.level,
        ),
      );
      if (meals.isEmpty) return null;
      final meal = meals.first;
      final wanted = request.kcalPerServing;
      if (wanted != null &&
          (meal.recipe.perServing.kcal - wanted).abs() >
              wanted * kKcalDraftTolerance) {
        return null;
      }
      return meal;
    } on Object {
      return null;
    }
  }
}

/// How far a drafted meal may land from the calories the user asked for.
const double kKcalDraftTolerance = 0.3;

/// How many meals one call is asked for. A recipe with every ingredient and
/// steps to cook from is some 600 tokens; many more than this in one answer
/// run into the output limit, and an answer cut off is no plan at all.
const int kMealsPerCall = 8;

/// What a recipe may hold at most. Far beyond anything cooked at home, and
/// inside what the backend stores for one recipe.
const int kMaxIngredients = 40;
const int kMaxSteps = 24;
const int kMaxStepLength = 600;

/// The titles of the most recently planned dishes, newest first and each
/// once — what a new plan is asked not to repeat.
List<String> recentTitles(
  Iterable<PlanEntry> entries,
  Map<String, Recipe> recipes, {
  int limit = 20,
}) {
  final newestFirst = entries.toList()
    ..sort((PlanEntry a, PlanEntry b) => b.day.compareTo(a.day));
  final seen = <String>{};
  final titles = <String>[];
  for (final entry in newestFirst) {
    final title = recipes[entry.recipeId]?.title.trim();
    if (title == null || title.isEmpty || !seen.add(title.toLowerCase())) continue;
    titles.add(title);
    if (titles.length >= limit) break;
  }
  return titles;
}

/// Reads a proposal and drops every meal that does not hold up: outside the
/// requested days and slots, calories that do not match the macros or make
/// no sense for one serving, ingredients that cannot be bought in a unit the
/// list can add up. One meal per day and slot — the first good one wins —
/// and each dish once, counting [MealPlanRequest.plannedTitles]. Every
/// recipe is stamped with the request's cooking level.
/// Also what checks a single meal the chat wants to set.
List<ProposedMeal> parseMealPlan(String raw, MealPlanRequest request) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) return const <ProposedMeal>[];
  final Object? decoded = jsonDecode(raw.substring(start, end + 1));
  final Object? list = decoded is Map ? decoded['meals'] : null;
  if (list is! List) return const <ProposedMeal>[];

  final days = request.days.map((DayKey d) => d.toString()).toSet();
  final slots = request.slots.toSet();
  final taken = <String>{};
  // Each dish once a week: what is planned already, then each new one.
  final titles = <String>{
    for (final title in request.plannedTitles) recipeKey(title),
  };
  final result = <ProposedMeal>[];

  for (final Object? item in list) {
    if (item is! Map) continue;
    final day = item['day'];
    final slot = MealSlotKind.values.asNameMap()[item['slot']];
    if (day is! String || !days.contains(day) || slot == null || !slots.contains(slot)) continue;
    if (!taken.add('$day/${slot.name}')) continue;

    final recipe = _recipeFrom(item, request.level);
    if (recipe == null || !titles.add(recipeKey(recipe.title))) {
      taken.remove('$day/${slot.name}');
      continue;
    }
    result.add(ProposedMeal(day: DayKey.parse(day), slot: slot, recipe: recipe));
  }
  result.sort((ProposedMeal a, ProposedMeal b) {
    final byDay = a.day.compareTo(b.day);
    return byDay != 0 ? byDay : a.slot.index.compareTo(b.slot.index);
  });
  return result;
}

Recipe? _recipeFrom(Map<dynamic, dynamic> item, CookingLevel level) {
  final title = item['title'];
  if (title is! String || title.trim().isEmpty) return null;
  final servings = _num(item['servings'])?.round() ?? 0;
  if (servings < 1 || servings > 12) return null;

  final kcal = _num(item['kcal']);
  final protein = _num(item['protein']) ?? 0;
  final carbs = _num(item['carbs']) ?? 0;
  final fat = _num(item['fat']) ?? 0;
  if (kcal == null || kcal < 80 || kcal > 1800) return null;
  // Energy from the macros has to roughly add up to the stated calories.
  final fromMacros = protein * 4 + carbs * 4 + fat * 9;
  if (fromMacros > 0 && (fromMacros - kcal).abs() > kcal * 0.3) return null;

  final ingredients = <Ingredient>[];
  for (final Object? raw in (item['ingredients'] as List?) ?? const <Object?>[]) {
    if (raw is! Map) continue;
    final name = raw['name'];
    final amount = _num(raw['qty']);
    if (name is! String || name.trim().isEmpty || amount == null) continue;
    final quantity = Quantity.parse(amount, raw['unit'] as String?);
    if (quantity == null) continue;
    // Nothing a household cooks needs ten kilos of one thing.
    if ((quantity.unit == QtyUnit.g || quantity.unit == QtyUnit.ml) && quantity.amount > 10000) continue;
    var category = ShopCategory.values.asNameMap()[raw['category']] ?? ShopCategory.other;
    // An aisle, not the list's own section for basics.
    if (category == ShopCategory.staples) category = ShopCategory.pantry;
    ingredients.add(Ingredient(
      name: name.trim(),
      quantity: quantity,
      category: category,
      staple: (raw['staple'] == true || isKitchenStaple(name)) &&
          _mayBeStaple(quantity, category),
    ));
    if (ingredients.length >= kMaxIngredients) break;
  }
  if (ingredients.isEmpty) return null;

  final minutes = _num(item['minutes'])?.round();
  return Recipe(
    id: newEventId(),
    title: title.trim(),
    servings: servings,
    ingredients: ingredients,
    perServing: Nutrients(kcal: kcal, proteinG: protein, carbsG: carbs, fatG: fat),
    minutes: minutes != null && minutes > 0 && minutes < 600 ? minutes : null,
    steps: <String>[
      for (final Object? s
          in ((item['steps'] as List?) ?? const <Object?>[]).take(kMaxSteps))
        if (s is String && s.trim().isNotEmpty) _step(s),
    ],
    level: level,
  );
}

/// A step as written, without the number some models put in front — the
/// recipe numbers its steps itself — and cut where no step should go on.
String _step(String raw) {
  final text = raw.trim().replaceFirst(RegExp(r'^(\d{1,2}[.):]|[-•*])\s+'), '');
  return text.length <= kMaxStepLength ? text : text.substring(0, kMaxStepLength);
}

/// Whether a line marked as a kitchen basic can be one: a little of
/// something from a shelf. Half a kilo of flour for a dough is flour to
/// buy, and nothing fresh is ever a basic — a model that marks the chicken
/// must not make it vanish from the amounts.
bool _mayBeStaple(Quantity quantity, ShopCategory category) {
  const fresh = <ShopCategory>{
    ShopCategory.produce,
    ShopCategory.bakery,
    ShopCategory.dairy,
    ShopCategory.meat,
    ShopCategory.fish,
    ShopCategory.frozen,
  };
  if (fresh.contains(category)) return false;
  return switch (quantity.unit) {
    QtyUnit.tbsp || QtyUnit.tsp => quantity.amount <= 12,
    QtyUnit.g => quantity.amount <= 100,
    QtyUnit.ml => quantity.amount <= 150,
    QtyUnit.piece => quantity.amount <= 3,
  };
}

double? _num(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}
