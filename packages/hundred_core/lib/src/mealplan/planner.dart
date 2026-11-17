import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

import '../ai/llm_client.dart';
import '../feed/event.dart' show newEventId;
import '../nutrition/foods.dart';
import '../plan/nutrition.dart';
import '../util/dates.dart';
import 'recipe.dart';

/// The JSON shape a meal plan proposal asks for. The example carries real
/// numbers on purpose, for the same reason as the meal estimate's: models
/// copy zeros.
const String kMealPlanJson = '{"meals":[{"day":"2026-11-18","slot":"dinner",'
    '"title":"Chicken curry with rice","servings":2,"minutes":30,'
    '"kcal":640,"protein":42,"carbs":70,"fat":18,'
    '"ingredients":[{"name":"chicken breast","qty":300,"unit":"g",'
    '"category":"meat"},{"name":"rice","qty":150,"unit":"g",'
    '"category":"pantry"}],"steps":["Cook the rice.","Fry the chicken."]}]}';

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
    this.avoidTitles = const <String>[],
  });

  final List<DayKey> days;
  final List<MealSlotKind> slots;
  final List<PlanFor> people;

  /// What the user typed: "no fish this week", "Wednesday something quick".
  final String? wish;
  final int? maxMinutes;

  /// Recent dishes, so a week does not repeat last week.
  final List<String> avoidTitles;
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
${request.wish == null || request.wish!.trim().isEmpty ? '' : 'Their wish: "${request.wish!.trim()}"\n'}${request.maxMinutes == null ? '' : 'At most ${request.maxMinutes} minutes of cooking per meal.\n'}${request.avoidTitles.isEmpty ? '' : 'Do not repeat: ${request.avoidTitles.join(', ')}.\n'}
Simple, varied dishes from a normal supermarket. Reuse ingredients across the
week so little is left over. Give one recipe per meal with servings for the
whole household, the calories and macros of ONE serving, ingredients for all
servings in g, ml or pieces (unit "g", "ml", "piece", "tbsp" or "tsp") with a
category (produce, bakery, dairy, meat, fish, pantry, frozen, drinks, other),
and short steps.
Answer with JSON only, in this form:
$kMealPlanJson
''';
  }
}

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

  Future<List<ProposedMeal>?> proposeWeek(MealPlanRequest request) async {
    if (!llm.isReady || request.days.isEmpty || request.slots.isEmpty) return null;
    try {
      final raw = await llm
          .generate(prompts.proposeWeek(request),
              purpose: LlmPurpose.plan,
              maxTokens: 8000,
              temperature: 0.7,
              json: true,
              timeout: timeout)
          .timeout(timeout);
      final meals = parseMealPlan(raw, request);
      return meals.isEmpty ? null : meals;
    } on Object {
      return null;
    }
  }
}

/// Reads a proposal and drops every meal that does not hold up: outside the
/// requested days and slots, calories that do not match the macros or make
/// no sense for one serving, ingredients that cannot be bought in a unit the
/// list can add up. One meal per day and slot — the first good one wins.
/// Also what checks a single meal the planning chat wants to set.
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
  final result = <ProposedMeal>[];

  for (final Object? item in list) {
    if (item is! Map) continue;
    final day = item['day'];
    final slot = MealSlotKind.values.asNameMap()[item['slot']];
    if (day is! String || !days.contains(day) || slot == null || !slots.contains(slot)) continue;
    if (!taken.add('$day/${slot.name}')) continue;

    final recipe = _recipeFrom(item);
    if (recipe == null) {
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

Recipe? _recipeFrom(Map<dynamic, dynamic> item) {
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
    ingredients.add(Ingredient(
      name: name.trim(),
      quantity: quantity,
      category: ShopCategory.values.asNameMap()[raw['category']] ?? ShopCategory.other,
    ));
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
      for (final Object? s in (item['steps'] as List?) ?? const <Object?>[])
        if (s is String && s.trim().isNotEmpty) s.trim(),
    ],
  );
}

double? _num(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}
