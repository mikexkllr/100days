import 'package:meta/meta.dart';

import '../plan/nutrition.dart';
import 'foods.dart';

/// A meal the app can suggest. Only suggestions: the diary is what the user
/// actually ate, and nothing here is ever logged on their behalf.
///
/// The name lives in the app's localizations under [id]; the numbers are
/// estimates for a normal portion.
@immutable
class MealIdea {
  const MealIdea(
    this.id,
    this.slot,
    this.kcal,
    this.proteinG, {
    this.diet = FoodDiet.omnivore,
  });

  final String id;
  final MealSlotKind slot;
  final int kcal;
  final int proteinG;
  final FoodDiet diet;

  bool fits(FoodDiet wanted) => diet.index <= wanted.index;
}

const List<MealIdea> kMealIdeas = <MealIdea>[
  MealIdea('breakfast1', MealSlotKind.breakfast, 380, 30,
      diet: FoodDiet.vegetarian),
  MealIdea('breakfast2', MealSlotKind.breakfast, 420, 25,
      diet: FoodDiet.vegetarian),
  MealIdea('breakfast3', MealSlotKind.breakfast, 450, 30,
      diet: FoodDiet.vegetarian),
  MealIdea('breakfast4', MealSlotKind.breakfast, 480, 35,
      diet: FoodDiet.vegetarian),
  MealIdea('breakfast5', MealSlotKind.breakfast, 420, 26,
      diet: FoodDiet.vegan),
  MealIdea('lunch1', MealSlotKind.lunch, 600, 50),
  MealIdea('lunch2', MealSlotKind.lunch, 620, 32, diet: FoodDiet.vegan),
  MealIdea('lunch3', MealSlotKind.lunch, 650, 38),
  MealIdea('lunch4', MealSlotKind.lunch, 650, 45),
  MealIdea('lunch5', MealSlotKind.lunch, 580, 28, diet: FoodDiet.vegan),
  MealIdea('snack1', MealSlotKind.snack, 280, 22, diet: FoodDiet.vegetarian),
  MealIdea('snack2', MealSlotKind.snack, 250, 26, diet: FoodDiet.vegetarian),
  MealIdea('snack3', MealSlotKind.snack, 270, 7, diet: FoodDiet.vegan),
  MealIdea('snack4', MealSlotKind.snack, 220, 18, diet: FoodDiet.vegetarian),
  MealIdea('snack5', MealSlotKind.snack, 200, 7, diet: FoodDiet.vegan),
  MealIdea('snack6', MealSlotKind.snack, 230, 8, diet: FoodDiet.vegan),
  MealIdea('dinner1', MealSlotKind.dinner, 520, 48),
  MealIdea('dinner2', MealSlotKind.dinner, 400, 28, diet: FoodDiet.vegetarian),
  MealIdea('dinner3', MealSlotKind.dinner, 560, 22, diet: FoodDiet.vegetarian),
  MealIdea('dinner4', MealSlotKind.dinner, 480, 42),
  MealIdea('dinner5', MealSlotKind.dinner, 500, 26, diet: FoodDiet.vegan),
  MealIdea('dinner6', MealSlotKind.dinner, 520, 40),
];

/// The ideas for [slot] that best fit what is left of the day.
///
/// Ranked by how close they land to [targetKcal], with a penalty for falling
/// short of [targetProteinG] — on a training goal, protein is the macro
/// people undershoot. Returns nothing when there is too little left to plan
/// a meal around.
List<MealIdea> suggestMeals({
  required MealSlotKind slot,
  required double targetKcal,
  required double targetProteinG,
  FoodDiet diet = FoodDiet.omnivore,
  int count = 3,
}) {
  if (targetKcal < 120) return const <MealIdea>[];
  double score(MealIdea idea) {
    final kcalMiss = (idea.kcal - targetKcal).abs() / targetKcal;
    final proteinShort = targetProteinG <= 0
        ? 0.0
        : (targetProteinG - idea.proteinG).clamp(0, targetProteinG) /
            targetProteinG;
    return kcalMiss + proteinShort * 0.5;
  }

  final candidates = <(int, MealIdea)>[
    for (var i = 0; i < kMealIdeas.length; i++)
      if (kMealIdeas[i].slot == slot && kMealIdeas[i].fits(diet))
        (i, kMealIdeas[i]),
  ]..sort(((int, MealIdea) a, (int, MealIdea) b) {
      final byScore = score(a.$2).compareTo(score(b.$2));
      return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
    });
  return candidates.take(count).map(((int, MealIdea) c) => c.$2).toList();
}
