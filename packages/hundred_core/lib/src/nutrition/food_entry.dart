import 'package:meta/meta.dart';

import '../plan/nutrition.dart';
import '../util/dates.dart';
import 'foods.dart';

/// Where a diary entry's numbers came from — shown next to the entry, so the
/// user knows which values are a label and which are an estimate.
enum FoodSource {
  /// Typed in by the user, numbers and all.
  manual,

  /// Picked from the built-in food table.
  database,

  /// Parsed from free text against the food table.
  parsed,

  /// Estimated by the on-device model.
  ai,

  /// Looked up by barcode — the numbers on the packaging.
  barcode,
}

/// One line of the food diary.
@immutable
class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.day,
    required this.meal,
    required this.name,
    required this.grams,
    required this.nutrients,
    required this.source,
    this.foodId,
    this.barcode,
  });

  factory FoodEntry.fromPayload(Map<String, dynamic> payload) => FoodEntry(
        id: payload['id'] as String,
        day: DayKey.parse(payload['day'] as String),
        meal: MealSlotKind.values.asNameMap()[payload['meal'] as String?] ??
            MealSlotKind.snack,
        name: payload['name'] as String? ?? '',
        grams: (payload['g'] as num?)?.toDouble() ?? 0,
        nutrients: Nutrients(
          kcal: (payload['kcal'] as num?)?.toDouble() ?? 0,
          proteinG: (payload['p'] as num?)?.toDouble() ?? 0,
          carbsG: (payload['c'] as num?)?.toDouble() ?? 0,
          fatG: (payload['f'] as num?)?.toDouble() ?? 0,
        ),
        source: FoodSource.values.asNameMap()[payload['src'] as String?] ??
            FoodSource.manual,
        foodId: payload['food'] as String?,
        barcode: payload['ean'] as String?,
      );

  /// Unique within the author's feed; a removal names it.
  final String id;
  final DayKey day;
  final MealSlotKind meal;

  /// What the user called it, or the product name. Never translated.
  final String name;
  final double grams;
  final Nutrients nutrients;
  final FoodSource source;
  final String? foodId;
  final String? barcode;

  Map<String, dynamic> toPayload() => <String, dynamic>{
        'id': id,
        'day': day.toString(),
        'meal': meal.name,
        'name': name,
        'g': _round1(grams),
        'kcal': nutrients.kcal.round(),
        'p': _round1(nutrients.proteinG),
        'c': _round1(nutrients.carbsG),
        'f': _round1(nutrients.fatG),
        'src': source.name,
        if (foodId != null) 'food': foodId,
        if (barcode != null) 'ean': barcode,
      };
}

num _round1(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble() ? rounded.round() : rounded;
}

/// A day of the food diary against its targets.
@immutable
class DayIntake {
  const DayIntake({required this.day, required this.entries});

  final DayKey day;
  final List<FoodEntry> entries;

  Nutrients get total => entries.fold(
      Nutrients.zero, (Nutrients sum, FoodEntry e) => sum + e.nutrients);

  List<FoodEntry> entriesFor(MealSlotKind meal) =>
      entries.where((FoodEntry e) => e.meal == meal).toList();

  Nutrients totalFor(MealSlotKind meal) => entriesFor(meal).fold(
      Nutrients.zero, (Nutrients sum, FoodEntry e) => sum + e.nutrients);

  bool get isEmpty => entries.isEmpty;

  /// Within [tolerance] of the calorie target — what "closing the day" in
  /// the diary checks before it counts as a tracked nutrition day.
  bool isOnTarget(NutritionPlan plan, {double tolerance = 0.10}) {
    if (entries.isEmpty) return false;
    final kcal = total.kcal;
    return (kcal - plan.kcal).abs() <= plan.kcal * tolerance;
  }
}
