import 'package:meta/meta.dart';

/// Rough grouping for the search screen and for meal suggestions.
enum FoodCategory {
  eggsDairy,
  meatFish,
  plantProtein,
  grains,
  bread,
  vegetables,
  fruit,
  nuts,
  fats,
  sweets,
  drinks,
  dishes,
  supplements,
}

/// What a food is compatible with. Ordered from strictest to loosest, so a
/// vegan food is also vegetarian.
enum FoodDiet { vegan, vegetarian, omnivore }

/// One entry of the built-in food table, per 100 g (or 100 ml for drinks).
///
/// The numbers are typical values from public nutrient tables, rounded —
/// good enough for a diary, which is what this is. Names, plurals and
/// synonyms live in the app's localizations under [id], because "Ei" and
/// "egg" must both find the same row.
@immutable
class FoodItem {
  const FoodItem(
    this.id,
    this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.portionG, {
    required this.category,
    this.pieceG,
    this.sliceG,
    this.diet = FoodDiet.omnivore,
  });

  final String id;

  /// Per 100 g.
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  /// A typical serving, used when the user names a food without an amount.
  final double portionG;

  /// Weight of one piece, for countable foods ("2 eggs", "a banana").
  final double? pieceG;

  /// Weight of one slice ("2 slices of bread").
  final double? sliceG;

  final FoodCategory category;
  final FoodDiet diet;

  bool get isVegetarian => diet != FoodDiet.omnivore;

  bool get isVegan => diet == FoodDiet.vegan;

  /// Nutrients for [grams] of this food.
  Nutrients forGrams(double grams) => Nutrients(
        kcal: kcal * grams / 100,
        proteinG: proteinG * grams / 100,
        carbsG: carbsG * grams / 100,
        fatG: fatG * grams / 100,
      );
}

/// Energy and macros of an amount of food.
@immutable
class Nutrients {
  const Nutrients({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  static const Nutrients zero =
      Nutrients(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0);

  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  Nutrients operator +(Nutrients other) => Nutrients(
        kcal: kcal + other.kcal,
        proteinG: proteinG + other.proteinG,
        carbsG: carbsG + other.carbsG,
        fatG: fatG + other.fatG,
      );

  Nutrients scaled(double factor) => Nutrients(
        kcal: kcal * factor,
        proteinG: proteinG * factor,
        carbsG: carbsG * factor,
        fatG: fatG * factor,
      );
}

const List<FoodItem> kFoodLibrary = <FoodItem>[
  FoodItem('egg', 143, 12.6, 0.7, 9.5, 110, pieceG: 55, category: FoodCategory.eggsDairy, diet: FoodDiet.vegetarian),
  FoodItem('milk', 47, 3.4, 4.9, 1.5, 200, category: FoodCategory.drinks, diet: FoodDiet.vegetarian),
  FoodItem('whole_milk', 64, 3.3, 4.8, 3.5, 200, category: FoodCategory.drinks, diet: FoodDiet.vegetarian),
  FoodItem('oat_milk', 46, 1.0, 6.7, 1.5, 200, category: FoodCategory.drinks, diet: FoodDiet.vegan),
  FoodItem('soy_milk', 41, 3.3, 1.8, 1.9, 200, category: FoodCategory.drinks, diet: FoodDiet.vegan),
  FoodItem('natural_yogurt', 61, 3.5, 4.0, 3.5, 150, category: FoodCategory.eggsDairy, diet: FoodDiet.vegetarian),
  FoodItem('greek_yogurt', 120, 4.4, 3.6, 10.0, 150, category: FoodCategory.eggsDairy, diet: FoodDiet.vegetarian),
  FoodItem('skyr', 63, 11.0, 4.0, 0.2, 150, category: FoodCategory.eggsDairy, diet: FoodDiet.vegetarian),
  FoodItem('quark', 67, 12.0, 4.0, 0.3, 250, category: FoodCategory.eggsDairy, diet: FoodDiet.vegetarian),
  FoodItem('cottage_cheese', 98, 12.0, 3.0, 4.3, 200, category: FoodCategory.eggsDairy, diet: FoodDiet.vegetarian),
  FoodItem('cheese', 356, 25.0, 0.0, 28.0, 30, sliceG: 25, category: FoodCategory.eggsDairy, diet: FoodDiet.vegetarian),
  FoodItem('mozzarella', 254, 18.0, 1.0, 19.5, 60, pieceG: 125, category: FoodCategory.eggsDairy, diet: FoodDiet.vegetarian),
  FoodItem('feta', 264, 14.0, 4.0, 21.0, 50, category: FoodCategory.eggsDairy, diet: FoodDiet.vegetarian),
  FoodItem('butter', 741, 0.7, 0.6, 83.0, 10, category: FoodCategory.fats, diet: FoodDiet.vegetarian),
  FoodItem('chicken_breast', 165, 31.0, 0.0, 3.6, 150, category: FoodCategory.meatFish),
  FoodItem('turkey_breast', 135, 30.0, 0.0, 1.5, 150, category: FoodCategory.meatFish),
  FoodItem('ground_beef', 230, 26.0, 0.0, 14.0, 125, category: FoodCategory.meatFish),
  FoodItem('steak', 190, 30.0, 0.0, 7.0, 180, category: FoodCategory.meatFish),
  FoodItem('ham', 107, 19.0, 1.0, 3.0, 30, sliceG: 20, category: FoodCategory.meatFish),
  FoodItem('salami', 380, 22.0, 1.0, 32.0, 30, sliceG: 10, category: FoodCategory.meatFish),
  FoodItem('bacon', 541, 37.0, 1.4, 42.0, 30, sliceG: 10, category: FoodCategory.meatFish),
  FoodItem('salmon', 206, 22.0, 0.0, 13.0, 125, category: FoodCategory.meatFish),
  FoodItem('tuna', 116, 26.0, 0.0, 1.0, 130, category: FoodCategory.meatFish),
  FoodItem('shrimp', 99, 24.0, 0.2, 0.3, 100, category: FoodCategory.meatFish),
  FoodItem('white_fish', 105, 23.0, 0.0, 0.9, 150, category: FoodCategory.meatFish),
  FoodItem('schnitzel', 260, 20.0, 12.0, 15.0, 180, pieceG: 180, category: FoodCategory.dishes),
  FoodItem('tofu', 144, 15.6, 2.3, 8.7, 150, category: FoodCategory.plantProtein, diet: FoodDiet.vegan),
  FoodItem('tempeh', 192, 20.0, 7.6, 11.0, 100, category: FoodCategory.plantProtein, diet: FoodDiet.vegan),
  FoodItem('lentils', 116, 9.0, 20.0, 0.4, 150, category: FoodCategory.plantProtein, diet: FoodDiet.vegan),
  FoodItem('chickpeas', 164, 8.9, 27.0, 2.6, 150, category: FoodCategory.plantProtein, diet: FoodDiet.vegan),
  FoodItem('kidney_beans', 127, 8.7, 22.8, 0.5, 150, category: FoodCategory.plantProtein, diet: FoodDiet.vegan),
  FoodItem('protein_powder', 380, 75.0, 8.0, 5.0, 30, category: FoodCategory.supplements, diet: FoodDiet.vegetarian),
  FoodItem('oats', 372, 13.5, 58.7, 7.0, 60, category: FoodCategory.grains, diet: FoodDiet.vegan),
  FoodItem('muesli', 365, 10.0, 60.0, 7.0, 60, category: FoodCategory.grains, diet: FoodDiet.vegan),
  FoodItem('granola', 470, 9.0, 64.0, 19.0, 50, category: FoodCategory.grains, diet: FoodDiet.vegan),
  FoodItem('cornflakes', 378, 7.5, 84.0, 0.9, 40, category: FoodCategory.grains, diet: FoodDiet.vegan),
  FoodItem('rice', 130, 2.7, 28.0, 0.3, 180, category: FoodCategory.grains, diet: FoodDiet.vegan),
  FoodItem('pasta', 157, 5.8, 30.6, 0.9, 200, category: FoodCategory.grains, diet: FoodDiet.vegan),
  FoodItem('couscous', 112, 3.8, 23.0, 0.2, 180, category: FoodCategory.grains, diet: FoodDiet.vegan),
  FoodItem('quinoa', 120, 4.4, 21.3, 1.9, 180, category: FoodCategory.grains, diet: FoodDiet.vegan),
  FoodItem('potatoes', 86, 1.7, 20.0, 0.1, 200, pieceG: 100, category: FoodCategory.vegetables, diet: FoodDiet.vegan),
  FoodItem('sweet_potato', 90, 2.0, 20.7, 0.2, 200, pieceG: 150, category: FoodCategory.vegetables, diet: FoodDiet.vegan),
  FoodItem('fries', 312, 3.4, 41.0, 15.0, 150, category: FoodCategory.dishes, diet: FoodDiet.vegan),
  FoodItem('wholegrain_bread', 216, 7.0, 39.0, 1.5, 50, sliceG: 50, category: FoodCategory.bread, diet: FoodDiet.vegan),
  FoodItem('toast', 265, 9.0, 49.0, 3.2, 50, sliceG: 25, category: FoodCategory.bread, diet: FoodDiet.vegan),
  FoodItem('bread_roll', 275, 9.0, 53.0, 1.8, 55, pieceG: 55, category: FoodCategory.bread, diet: FoodDiet.vegan),
  FoodItem('crispbread', 360, 10.0, 66.0, 2.0, 20, pieceG: 10, category: FoodCategory.bread, diet: FoodDiet.vegan),
  FoodItem('tortilla', 310, 8.5, 52.0, 7.5, 60, pieceG: 60, category: FoodCategory.bread, diet: FoodDiet.vegan),
  FoodItem('rice_cakes', 387, 8.0, 81.0, 2.8, 16, pieceG: 8, category: FoodCategory.bread, diet: FoodDiet.vegan),
  FoodItem('croissant', 406, 8.2, 45.8, 21.0, 60, pieceG: 60, category: FoodCategory.bread, diet: FoodDiet.vegetarian),
  FoodItem('pancake', 227, 6.4, 28.0, 9.7, 100, pieceG: 50, category: FoodCategory.dishes, diet: FoodDiet.vegetarian),
  FoodItem('broccoli', 34, 2.8, 4.0, 0.4, 150, category: FoodCategory.vegetables, diet: FoodDiet.vegan),
  FoodItem('spinach', 23, 2.9, 1.4, 0.4, 100, category: FoodCategory.vegetables, diet: FoodDiet.vegan),
  FoodItem('tomato', 18, 0.9, 2.6, 0.2, 120, pieceG: 120, category: FoodCategory.vegetables, diet: FoodDiet.vegan),
  FoodItem('cucumber', 15, 0.6, 2.2, 0.1, 150, category: FoodCategory.vegetables, diet: FoodDiet.vegan),
  FoodItem('carrot', 41, 0.9, 7.6, 0.2, 70, pieceG: 70, category: FoodCategory.vegetables, diet: FoodDiet.vegan),
  FoodItem('bell_pepper', 31, 1.0, 4.6, 0.3, 150, pieceG: 150, category: FoodCategory.vegetables, diet: FoodDiet.vegan),
  FoodItem('lettuce', 15, 1.3, 1.6, 0.2, 100, category: FoodCategory.vegetables, diet: FoodDiet.vegan),
  FoodItem('onion', 40, 1.1, 7.6, 0.1, 100, pieceG: 100, category: FoodCategory.vegetables, diet: FoodDiet.vegan),
  FoodItem('mushrooms', 22, 3.1, 0.6, 0.3, 100, category: FoodCategory.vegetables, diet: FoodDiet.vegan),
  FoodItem('zucchini', 17, 1.2, 2.2, 0.3, 200, pieceG: 200, category: FoodCategory.vegetables, diet: FoodDiet.vegan),
  FoodItem('green_beans', 31, 1.8, 4.3, 0.2, 150, category: FoodCategory.vegetables, diet: FoodDiet.vegan),
  FoodItem('sweetcorn', 80, 3.0, 14.0, 1.2, 100, category: FoodCategory.vegetables, diet: FoodDiet.vegan),
  FoodItem('vegetables', 35, 2.0, 5.0, 0.4, 200, category: FoodCategory.vegetables, diet: FoodDiet.vegan),
  FoodItem('avocado', 160, 2.0, 1.9, 14.7, 75, pieceG: 150, category: FoodCategory.vegetables, diet: FoodDiet.vegan),
  FoodItem('banana', 93, 1.1, 20.0, 0.3, 120, pieceG: 120, category: FoodCategory.fruit, diet: FoodDiet.vegan),
  FoodItem('apple', 52, 0.3, 11.4, 0.2, 180, pieceG: 180, category: FoodCategory.fruit, diet: FoodDiet.vegan),
  FoodItem('orange', 47, 0.9, 9.4, 0.1, 150, pieceG: 150, category: FoodCategory.fruit, diet: FoodDiet.vegan),
  FoodItem('pear', 57, 0.4, 12.4, 0.1, 170, pieceG: 170, category: FoodCategory.fruit, diet: FoodDiet.vegan),
  FoodItem('kiwi', 61, 1.1, 10.8, 0.5, 75, pieceG: 75, category: FoodCategory.fruit, diet: FoodDiet.vegan),
  FoodItem('berries', 45, 0.9, 7.5, 0.4, 125, category: FoodCategory.fruit, diet: FoodDiet.vegan),
  FoodItem('strawberries', 32, 0.7, 5.5, 0.3, 150, category: FoodCategory.fruit, diet: FoodDiet.vegan),
  FoodItem('grapes', 69, 0.7, 16.0, 0.2, 125, category: FoodCategory.fruit, diet: FoodDiet.vegan),
  FoodItem('mango', 60, 0.8, 13.7, 0.4, 150, category: FoodCategory.fruit, diet: FoodDiet.vegan),
  FoodItem('dates', 282, 2.5, 64.0, 0.4, 40, pieceG: 8, category: FoodCategory.fruit, diet: FoodDiet.vegan),
  FoodItem('raisins', 299, 3.1, 66.0, 0.5, 30, category: FoodCategory.fruit, diet: FoodDiet.vegan),
  FoodItem('almonds', 600, 21.0, 9.4, 50.0, 30, category: FoodCategory.nuts, diet: FoodDiet.vegan),
  FoodItem('walnuts', 654, 15.0, 7.0, 65.0, 30, category: FoodCategory.nuts, diet: FoodDiet.vegan),
  FoodItem('peanuts', 567, 26.0, 16.0, 49.0, 30, category: FoodCategory.nuts, diet: FoodDiet.vegan),
  FoodItem('cashews', 553, 18.0, 27.0, 44.0, 30, category: FoodCategory.nuts, diet: FoodDiet.vegan),
  FoodItem('peanut_butter', 588, 25.0, 20.0, 50.0, 20, category: FoodCategory.nuts, diet: FoodDiet.vegan),
  FoodItem('chia_seeds', 486, 17.0, 8.0, 31.0, 15, category: FoodCategory.nuts, diet: FoodDiet.vegan),
  FoodItem('olive_oil', 884, 0.0, 0.0, 100.0, 10, category: FoodCategory.fats, diet: FoodDiet.vegan),
  FoodItem('hummus', 166, 8.0, 14.0, 9.6, 50, category: FoodCategory.plantProtein, diet: FoodDiet.vegan),
  FoodItem('hazelnut_spread', 539, 6.3, 57.5, 30.9, 20, category: FoodCategory.sweets, diet: FoodDiet.vegetarian),
  FoodItem('honey', 304, 0.3, 82.0, 0.0, 20, category: FoodCategory.sweets, diet: FoodDiet.vegetarian),
  FoodItem('jam', 250, 0.4, 60.0, 0.1, 20, category: FoodCategory.sweets, diet: FoodDiet.vegan),
  FoodItem('sugar', 400, 0.0, 100.0, 0.0, 5, category: FoodCategory.sweets, diet: FoodDiet.vegan),
  FoodItem('dark_chocolate', 580, 8.0, 33.0, 42.0, 20, pieceG: 5, category: FoodCategory.sweets, diet: FoodDiet.vegetarian),
  FoodItem('milk_chocolate', 535, 7.6, 59.0, 30.0, 25, pieceG: 6, category: FoodCategory.sweets, diet: FoodDiet.vegetarian),
  FoodItem('gummy_bears', 343, 6.9, 77.0, 0.1, 30, category: FoodCategory.sweets),
  FoodItem('crisps', 536, 6.6, 53.0, 34.0, 30, category: FoodCategory.sweets, diet: FoodDiet.vegan),
  FoodItem('ice_cream', 207, 3.5, 24.0, 11.0, 100, category: FoodCategory.sweets, diet: FoodDiet.vegetarian),
  FoodItem('cookie', 480, 6.0, 66.0, 21.0, 24, pieceG: 12, category: FoodCategory.sweets, diet: FoodDiet.vegetarian),
  FoodItem('cake', 360, 5.0, 50.0, 16.0, 100, pieceG: 100, category: FoodCategory.sweets, diet: FoodDiet.vegetarian),
  FoodItem('protein_bar', 350, 30.0, 35.0, 10.0, 60, pieceG: 60, category: FoodCategory.supplements, diet: FoodDiet.vegetarian),
  FoodItem('cereal_bar', 400, 6.0, 65.0, 13.0, 25, pieceG: 25, category: FoodCategory.sweets, diet: FoodDiet.vegetarian),
  FoodItem('coffee', 2, 0.1, 0.0, 0.0, 200, category: FoodCategory.drinks, diet: FoodDiet.vegan),
  FoodItem('cappuccino', 39, 2.0, 3.4, 1.9, 250, category: FoodCategory.drinks, diet: FoodDiet.vegetarian),
  FoodItem('tea', 1, 0.0, 0.2, 0.0, 250, category: FoodCategory.drinks, diet: FoodDiet.vegan),
  FoodItem('orange_juice', 45, 0.7, 10.4, 0.2, 250, category: FoodCategory.drinks, diet: FoodDiet.vegan),
  FoodItem('smoothie', 55, 0.8, 12.0, 0.3, 250, category: FoodCategory.drinks, diet: FoodDiet.vegan),
  FoodItem('cola', 42, 0.0, 10.6, 0.0, 330, category: FoodCategory.drinks, diet: FoodDiet.vegan),
  FoodItem('cola_zero', 0.3, 0.0, 0.0, 0.0, 330, category: FoodCategory.drinks, diet: FoodDiet.vegan),
  FoodItem('beer', 43, 0.5, 3.6, 0.0, 500, category: FoodCategory.drinks, diet: FoodDiet.vegan),
  FoodItem('wine', 85, 0.1, 2.6, 0.0, 200, category: FoodCategory.drinks, diet: FoodDiet.vegan),
  FoodItem('pizza', 266, 11.0, 33.0, 10.0, 350, pieceG: 350, sliceG: 100, category: FoodCategory.dishes, diet: FoodDiet.vegetarian),
  FoodItem('burger', 250, 13.0, 24.0, 12.0, 220, pieceG: 220, category: FoodCategory.dishes),
  FoodItem('doner_kebab', 215, 12.0, 20.0, 10.0, 350, pieceG: 350, category: FoodCategory.dishes),
  FoodItem('spaghetti_bolognese', 140, 7.0, 18.0, 4.5, 400, category: FoodCategory.dishes),
  FoodItem('lasagna', 150, 8.0, 13.0, 7.0, 350, category: FoodCategory.dishes),
  FoodItem('currywurst', 270, 10.0, 8.0, 22.0, 200, category: FoodCategory.dishes),
  FoodItem('sushi', 145, 6.0, 26.0, 2.0, 250, pieceG: 30, category: FoodCategory.dishes),
  FoodItem('curry', 145, 12.0, 6.0, 8.0, 300, category: FoodCategory.dishes),
  FoodItem('chili_con_carne', 115, 8.0, 9.0, 5.0, 350, category: FoodCategory.dishes),
  FoodItem('fried_rice', 175, 4.5, 26.0, 6.0, 300, category: FoodCategory.dishes, diet: FoodDiet.vegan),
  FoodItem('instant_noodles', 88, 2.0, 12.6, 3.3, 400, category: FoodCategory.dishes, diet: FoodDiet.vegan),
  FoodItem('vegetable_soup', 40, 1.5, 6.0, 1.0, 300, category: FoodCategory.dishes, diet: FoodDiet.vegan),
  FoodItem('mixed_salad', 80, 2.0, 4.0, 6.0, 250, category: FoodCategory.dishes, diet: FoodDiet.vegan),
  FoodItem('omelette', 154, 11.0, 0.6, 12.0, 120, category: FoodCategory.dishes, diet: FoodDiet.vegetarian),
  FoodItem('scrambled_eggs', 149, 10.0, 1.6, 11.0, 120, category: FoodCategory.dishes, diet: FoodDiet.vegetarian),
  FoodItem('porridge', 95, 4.0, 13.0, 2.5, 300, category: FoodCategory.dishes, diet: FoodDiet.vegetarian),
  FoodItem('sandwich', 250, 12.0, 28.0, 9.0, 150, pieceG: 150, category: FoodCategory.dishes),
  FoodItem('falafel', 333, 13.0, 32.0, 18.0, 100, pieceG: 17, category: FoodCategory.dishes, diet: FoodDiet.vegan),
  FoodItem('burrito', 210, 9.0, 27.0, 7.0, 300, pieceG: 300, category: FoodCategory.dishes),
];

final Map<String, FoodItem> kFoodById = <String, FoodItem>{
  for (final FoodItem f in kFoodLibrary) f.id: f,
};
