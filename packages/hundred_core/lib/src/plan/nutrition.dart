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

/// How the calories are split into protein, carbs and fat.
///
/// [auto] sets protein and fat per kilogram of body weight and fills the rest
/// with carbs — the most useful default for training goals. The others are
/// the fixed splits people know from calorie-counting apps.
enum MacroPreset { auto, balanced, highProtein, lowCarb, custom }

/// Protein / carbs / fat in percent of calories for each fixed preset.
const Map<MacroPreset, ({int protein, int carbs, int fat})> kMacroPresets =
    <MacroPreset, ({int protein, int carbs, int fat})>{
  MacroPreset.balanced: (protein: 20, carbs: 50, fat: 30),
  MacroPreset.highProtein: (protein: 35, carbs: 40, fat: 25),
  MacroPreset.lowCarb: (protein: 30, carbs: 20, fat: 50),
};

/// Lowest and highest daily target the app accepts as the user's own. Below
/// the floor the plan stops being a diet and becomes a risk; the editor says
/// so rather than silently clamping.
const int kMinCustomKcal = 1000;
const int kMaxCustomKcal = 6000;

/// The user's own nutrition targets, on top of what the app computes.
@immutable
class NutritionGoals {
  const NutritionGoals({
    this.kcalTarget,
    this.preset = MacroPreset.auto,
    this.proteinPercent,
    this.carbsPercent,
    this.fatPercent,
  });

  factory NutritionGoals.fromJson(Map<String, dynamic> json) =>
      NutritionGoals(
        kcalTarget: (json['kcal'] as num?)?.toInt(),
        preset: MacroPreset.values.asNameMap()[json['preset'] as String?] ??
            MacroPreset.auto,
        proteinPercent: (json['p'] as num?)?.toInt(),
        carbsPercent: (json['c'] as num?)?.toInt(),
        fatPercent: (json['f'] as num?)?.toInt(),
      );

  /// Null means "use the computed target".
  final int? kcalTarget;
  final MacroPreset preset;

  /// Only read for [MacroPreset.custom]; must add up to 100.
  final int? proteinPercent;
  final int? carbsPercent;
  final int? fatPercent;

  bool get hasCustomKcal => kcalTarget != null;

  /// The percentages in effect, or null for [MacroPreset.auto].
  ({int protein, int carbs, int fat})? get percentages {
    if (preset == MacroPreset.auto) return null;
    if (preset != MacroPreset.custom) return kMacroPresets[preset];
    final p = proteinPercent ?? 25;
    final c = carbsPercent ?? 45;
    final f = fatPercent ?? 30;
    final sum = p + c + f;
    if (sum <= 0) return kMacroPresets[MacroPreset.balanced];
    // Normalise rather than reject: a slider UI can momentarily sum to 99.
    final protein = (p * 100 / sum).round();
    final carbs = (c * 100 / sum).round();
    return (protein: protein, carbs: carbs, fat: 100 - protein - carbs);
  }

  NutritionGoals copyWith({
    int? kcalTarget,
    bool clearKcal = false,
    MacroPreset? preset,
    int? proteinPercent,
    int? carbsPercent,
    int? fatPercent,
  }) =>
      NutritionGoals(
        kcalTarget: clearKcal ? null : kcalTarget ?? this.kcalTarget,
        preset: preset ?? this.preset,
        proteinPercent: proteinPercent ?? this.proteinPercent,
        carbsPercent: carbsPercent ?? this.carbsPercent,
        fatPercent: fatPercent ?? this.fatPercent,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (kcalTarget != null) 'kcal': kcalTarget,
        'preset': preset.name,
        if (preset == MacroPreset.custom) ...<String, dynamic>{
          'p': proteinPercent,
          'c': carbsPercent,
          'f': fatPercent,
        },
      };
}

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
    int? suggestedKcal,
    this.isCustomTarget = false,
    this.preset = MacroPreset.auto,
  }) : suggestedKcal = suggestedKcal ?? kcal;

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

  /// What the app would have prescribed. Equal to [kcal] unless the user set
  /// their own target, in which case the screen can show both.
  final int suggestedKcal;

  /// The user overrode the computed calorie target.
  final bool isCustomTarget;

  final MacroPreset preset;

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
  final NutritionStrategy suggestedStrategy;
  final int suggestedDelta;
  final bool goalDrivesNutrition;
  switch (goal.archetype) {
    case GoalArchetype.loseFat:
      kcal = (tdee * 0.80).round();
      suggestedStrategy = NutritionStrategy.deficit;
      suggestedDelta = 20;
      goalDrivesNutrition = true;
    case GoalArchetype.buildMuscle:
      kcal = (tdee * 1.12).round();
      suggestedStrategy = NutritionStrategy.surplus;
      suggestedDelta = 12;
      goalDrivesNutrition = true;
    case GoalArchetype.getFit:
      kcal = tdee;
      suggestedStrategy = NutritionStrategy.maintenance;
      suggestedDelta = 0;
      goalDrivesNutrition = true;
    case GoalArchetype.discipline:
    case GoalArchetype.clarity:
    case GoalArchetype.sober:
    case GoalArchetype.custom:
      kcal = tdee;
      suggestedStrategy = NutritionStrategy.maintenance;
      suggestedDelta = 0;
      goalDrivesNutrition = false;
  }

  final floor = body.sex == BiologicalSex.male ? 1600 : 1300;
  kcal = math.max(kcal, floor);
  final suggestedKcal = kcal;

  final goals = goal.nutrition;
  var strategy = suggestedStrategy;
  var deltaPercent = suggestedDelta;
  var isCustom = false;
  if (goals?.kcalTarget != null) {
    // The user's own number wins, within sane bounds. The strategy and the
    // delta are then read off their number, so the explanation stays true.
    kcal = goals!.kcalTarget!.clamp(kMinCustomKcal, kMaxCustomKcal);
    isCustom = kcal != suggestedKcal;
    final delta = (kcal - tdee) / tdee;
    strategy = delta < -0.03
        ? NutritionStrategy.deficit
        : delta > 0.03
            ? NutritionStrategy.surplus
            : NutritionStrategy.maintenance;
    deltaPercent = strategy == NutritionStrategy.maintenance
        ? 0
        : (delta.abs() * 100).round();
  }

  final preset = goals?.preset ?? MacroPreset.auto;
  final percentages = goals?.percentages;
  final int proteinG;
  final int fatG;
  final int carbsG;
  if (percentages == null) {
    final deficit = kcal < tdee;
    final proteinPerKg = deficit ? 2.2 : 2.0;
    proteinG = (body.weightKg * proteinPerKg).round();
    fatG = math.max((body.weightKg * 0.9).round(), 40);
    final remainingKcal = kcal - proteinG * 4 - fatG * 9;
    carbsG = math.max((remainingKcal / 4).round(), 50);
  } else {
    proteinG = (kcal * percentages.protein / 100 / 4).round();
    carbsG = (kcal * percentages.carbs / 100 / 4).round();
    fatG = (kcal * percentages.fat / 100 / 9).round();
  }
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
    goalDrivesNutrition: goalDrivesNutrition || isCustom,
    meals: _buildMeals(kcal, proteinG),
    suggestedKcal: suggestedKcal,
    isCustomTarget: isCustom,
    preset: preset,
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
