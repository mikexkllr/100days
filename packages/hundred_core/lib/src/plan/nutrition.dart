import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../domain/goal.dart';

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
    required this.rationaleDe,
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
  final String rationaleDe;
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
    required this.nameDe,
    required this.share,
    required this.kcal,
    required this.proteinG,
    required this.suggestionsDe,
  });

  final String nameDe;
  final double share;
  final int kcal;
  final int proteinG;
  final List<String> suggestionsDe;
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
  String rationale;
  switch (goal.archetype) {
    case GoalArchetype.loseFat:
      kcal = (tdee * 0.80).round();
      rationale = '20 % Defizit unter deinem Verbrauch von $tdee kcal. '
          'Das sind rund 0,5 kg Fett pro Woche — schnell genug, dass du es '
          'siehst, langsam genug, dass die Muskeln bleiben.';
    case GoalArchetype.buildMuscle:
      kcal = (tdee * 1.12).round();
      rationale = '12 % Überschuss über deinem Verbrauch von $tdee kcal. '
          'Lean Bulk: genug für Aufbau, wenig genug, dass du nicht nur '
          'Fett zunimmst.';
    case GoalArchetype.getFit:
      kcal = tdee;
      rationale = 'Erhaltung bei $tdee kcal. Erst Gewohnheit und Leistung, '
          'dann Körperkomposition.';
    case GoalArchetype.discipline:
    case GoalArchetype.clarity:
    case GoalArchetype.sober:
    case GoalArchetype.custom:
      kcal = tdee;
      rationale = 'Erhaltung bei $tdee kcal. Dein Ziel liegt woanders — '
          'Ernährung soll dich hier nur nicht ausbremsen.';
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
    rationaleDe: rationale,
    meals: _buildMeals(kcal, proteinG),
  );
}

const List<List<String>> _mealIdeas = <List<String>>[
  <String>[
    'Skyr mit Beeren, Haferflocken und Leinsamen',
    'Rührei aus 3 Eiern mit Vollkorntoast',
    'Overnight Oats mit Magerquark und Banane',
    'Proteinporridge mit Erdnussmus',
  ],
  <String>[
    'Hähnchenbrust, Reis, Brokkoli',
    'Linsenbolognese mit Vollkornnudeln',
    'Lachsfilet mit Kartoffeln und Salat',
    'Rindergeschnetzeltes mit Couscous und Ofengemüse',
  ],
  <String>[
    'Magerquark mit Honig und Walnüssen',
    'Proteinshake mit Banane',
    'Handvoll Mandeln und ein Apfel',
    'Hüttenkäse auf Knäckebrot',
  ],
  <String>[
    'Putenpfanne mit Zucchini und Feta',
    'Omelette mit Champignons und Spinat',
    'Kichererbsencurry mit Naturjoghurt',
    'Thunfischsalat mit Bohnen und Ei',
  ],
];

List<MealSlot> _buildMeals(int kcal, int proteinG) {
  const List<String> names = <String>[
    'Frühstück',
    'Mittagessen',
    'Snack',
    'Abendessen',
  ];
  const List<double> shares = <double>[0.25, 0.35, 0.10, 0.30];
  return <MealSlot>[
    for (var i = 0; i < names.length; i++)
      MealSlot(
        nameDe: names[i],
        share: shares[i],
        kcal: (kcal * shares[i]).round(),
        proteinG: (proteinG * shares[i]).round(),
        suggestionsDe: _mealIdeas[i],
      ),
  ];
}
