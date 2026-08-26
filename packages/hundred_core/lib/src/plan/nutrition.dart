import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../domain/goal.dart';

/// Which way the calorie target deviates from maintenance, and why.
///
/// The app turns this into a sentence; the numbers that justify it live on
/// [NutritionPlan] so the explanation cannot drift from the maths.
enum NutritionStrategy { deficit, surplus, maintenance }

/// The four slots a day is split into. Meal ideas per slot come from the
/// app's localizations — a German breakfast suggestion is not an English one.
enum MealSlotKind { breakfast, lunch, snack, dinner }

/// Daily energy and macro targets.
@immutable
class NutritionPlan {
  const NutritionPlan({
    required this.bmr,
    required this.tdee,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.fiberG,
    required this.waterMl,
    required this.strategy,
    required this.deltaPercent,
    required this.goalDrivesNutrition,
    required this.meals,
  });

  final int bmr;
  final int tdee;
  final int kcal;
  final int proteinG;
  final int fatG;
  final int carbsG;
  final int fiberG;
  final int waterMl;
  final NutritionStrategy strategy;

  /// Absolute deviation from [tdee] in percent, 0 for maintenance.
  final int deltaPercent;

  /// False when the goal is not about the body at all — the app then says
  /// "eating should not slow you down" rather than explaining a deficit.
  final bool goalDrivesNutrition;

  final List<MealSlot> meals;

  /// Expected weekly weight change in kg from the calorie delta
  /// (≈7700 kcal per kg of body fat).
  double get weeklyWeightChangeKg => (kcal - tdee) * 7 / 7700;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'bmr': bmr,
        'tdee': tdee,
        'kcal': kcal,
        'proteinG': proteinG,
        'fatG': fatG,
        'carbsG': carbsG,
        'fiberG': fiberG,
        'waterMl': waterMl,
      };
}

@immutable
class MealSlot {
  const MealSlot({
    required this.kind,
    required this.share,
    required this.kcal,
    required this.proteinG,
  });

  final MealSlotKind kind;
  final double share;
  final int kcal;
  final int proteinG;
}

double activityFactor(ActivityLevel level) {
  switch (level) {
    case ActivityLevel.sedentary:
      return 1.2;
    case ActivityLevel.light:
      return 1.375;
    case ActivityLevel.moderate:
      return 1.55;
    case ActivityLevel.high:
      return 1.725;
    case ActivityLevel.athlete:
      return 1.9;
  }
}

/// Mifflin-St Jeor. Chosen over Harris-Benedict because it is the more
/// accurate predictor for the general population, and over Katch-McArdle
/// because we cannot assume the user knows their body fat percentage.
int basalMetabolicRate(BodyProfile body) {
  final base = 10 * body.weightKg + 6.25 * body.heightCm - 5 * body.ageYears;
  final value = body.sex == BiologicalSex.male ? base + 5 : base - 161;
  return value.round();
}

/// Builds the daily nutrition target for a goal.
///
/// The deficit is capped at 20% and floored at a sex-specific absolute
/// minimum: aggressive cuts are how people lose muscle, wreck their sleep and
/// quit in week three, which is the opposite of a 100-day app's job.
NutritionPlan buildNutritionPlan(Goal goal) {
  final body = goal.body;
  if (body == null) {
    throw ArgumentError('Nutrition plan requires body stats');
  }

  final bmr = basalMetabolicRate(body);
  final tdee = (bmr * activityFactor(body.activityLevel)).round();

  int kcal;
  final NutritionStrategy strategy;
  final int deltaPercent;
  final bool goalDrivesNutrition;
  switch (goal.archetype) {
    case GoalArchetype.loseFat:
      kcal = (tdee * 0.80).round();
      strategy = NutritionStrategy.deficit;
      deltaPercent = 20;
      goalDrivesNutrition = true;
    case GoalArchetype.buildMuscle:
      kcal = (tdee * 1.12).round();
      strategy = NutritionStrategy.surplus;
      deltaPercent = 12;
      goalDrivesNutrition = true;
    case GoalArchetype.getFit:
      kcal = tdee;
      strategy = NutritionStrategy.maintenance;
      deltaPercent = 0;
      goalDrivesNutrition = true;
    case GoalArchetype.discipline:
    case GoalArchetype.clarity:
    case GoalArchetype.sober:
    case GoalArchetype.custom:
      kcal = tdee;
      strategy = NutritionStrategy.maintenance;
      deltaPercent = 0;
      goalDrivesNutrition = false;
  }

  final floor = body.sex == BiologicalSex.male ? 1600 : 1300;
  kcal = math.max(kcal, floor);

  final deficit = kcal < tdee;
  final proteinPerKg = deficit ? 2.2 : 2.0;
  final proteinG = (body.weightKg * proteinPerKg).round();
  final fatG = math.max((body.weightKg * 0.9).round(), 40);
  final remainingKcal = kcal - proteinG * 4 - fatG * 9;
  final carbsG = math.max((remainingKcal / 4).round(), 50);
  final fiberG = (kcal / 1000 * 14).round();
  final waterMl = (body.weightKg * 35).round();

  return NutritionPlan(
    bmr: bmr,
    tdee: tdee,
    kcal: kcal,
    proteinG: proteinG,
    fatG: fatG,
    carbsG: carbsG,
    fiberG: fiberG,
    waterMl: waterMl,
    strategy: strategy,
    deltaPercent: deltaPercent,
    goalDrivesNutrition: goalDrivesNutrition,
    meals: _buildMeals(kcal, proteinG),
  );
}

List<MealSlot> _buildMeals(int kcal, int proteinG) {
  const List<double> shares = <double>[0.25, 0.35, 0.10, 0.30];
  return <MealSlot>[
    for (var i = 0; i < MealSlotKind.values.length; i++)
      MealSlot(
        kind: MealSlotKind.values[i],
        share: shares[i],
        kcal: (kcal * shares[i]).round(),
        proteinG: (proteinG * shares[i]).round(),
      ),
  ];
}
