import 'package:meta/meta.dart';

import '../nutrition/food_entry.dart';
import '../nutrition/foods.dart';
import '../plan/nutrition.dart';
import '../util/dates.dart';
import 'recipe.dart';

/// One meal in the plan: a recipe on a day and slot, and how much of it each
/// household member eats.
@immutable
class PlanEntry {
  const PlanEntry({
    required this.id,
    required this.day,
    required this.slot,
    required this.recipeId,
    this.portions = const <String, double>{},
    this.note,
  });

  factory PlanEntry.fromJson(Map<String, dynamic> json) => PlanEntry(
        id: json['id'] as String,
        day: DayKey.parse(json['day'] as String),
        slot: MealSlotKind.values.asNameMap()[json['slot'] as String?] ??
            MealSlotKind.dinner,
        recipeId: json['recipe_id'] as String,
        portions: <String, double>{
          for (final MapEntry<String, dynamic> e
              in ((json['portions'] as Map?) ?? const <String, dynamic>{})
                  .cast<String, dynamic>()
                  .entries)
            if (e.value is num) e.key: (e.value as num).toDouble(),
        },
        note: json['note'] as String?,
      );

  final String id;
  final DayKey day;
  final MealSlotKind slot;
  final String recipeId;

  /// Member id → portions of the recipe. Empty means one portion for
  /// everyone in the household.
  final Map<String, double> portions;
  final String? note;

  /// How many portions get cooked, for the shopping list.
  double totalPortions(int householdSize) => portions.isEmpty
      ? householdSize.toDouble()
      : portions.values.fold(0.0, (double a, double b) => a + b);

  double portionFor(String memberId) =>
      portions.isEmpty ? 1 : portions[memberId] ?? 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'day': day.toString(),
        'slot': slot.name,
        'recipe_id': recipeId,
        'portions': portions,
        if (note != null) 'note': note,
      };
}

/// Share of the day's calories a slot usually carries. A planner fills a
/// slot with about this much; the portions then fit each person's target.
const Map<MealSlotKind, double> kSlotShare = <MealSlotKind, double>{
  MealSlotKind.breakfast: 0.25,
  MealSlotKind.lunch: 0.35,
  MealSlotKind.snack: 0.10,
  MealSlotKind.dinner: 0.30,
};

/// Portions that make [recipe] fit someone eating [dailyKcal] a day, in
/// quarters, between half a portion and two and a half. One portion when
/// the recipe's calories are unknown or the person shares no target.
double portionsFor({
  required Recipe recipe,
  required MealSlotKind slot,
  int? dailyKcal,
}) {
  final perServing = recipe.perServing.kcal;
  if (dailyKcal == null || dailyKcal <= 0 || perServing <= 0) return 1;
  final wanted = dailyKcal * (kSlotShare[slot] ?? 0.3);
  final raw = wanted / perServing;
  final quarters = (raw * 4).round() / 4;
  return quarters.clamp(0.5, 2.5).toDouble();
}

/// What [memberId] eats of [entry] — what "eaten as planned" puts into the
/// diary.
Nutrients nutrientsFor(PlanEntry entry, Recipe recipe, String memberId) =>
    recipe.perServing.scaled(entry.portionFor(memberId));

/// Whether [intake] — the diary of [entry]'s day — already holds [entry]:
/// a line from the plan with the recipe's name, in its slot. Keeps "eaten as
/// planned" to one tap per meal.
bool eatenAsPlanned(DayIntake intake, PlanEntry entry, Recipe recipe) =>
    intake.day == entry.day &&
    intake.entriesFor(entry.slot).any((FoodEntry e) =>
        e.source == FoodSource.plan && e.name == recipe.title);
