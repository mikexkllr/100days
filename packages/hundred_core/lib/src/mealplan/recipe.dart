import 'package:meta/meta.dart';

import '../nutrition/foods.dart';

/// The units a shopping list adds up in. Weights and volumes are kept in
/// grams and millilitres so that "500 g" and "1 kg" of the same thing add
/// up; spoons stay spoons, pieces stay pieces.
enum QtyUnit { g, ml, piece, tbsp, tsp }

/// Where something sits in a supermarket — what a shopping list is sorted
/// by, so a trip goes aisle by aisle instead of back and forth.
enum ShopCategory {
  produce,
  bakery,
  dairy,
  meat,
  fish,
  pantry,
  frozen,
  drinks,
  household,
  other,
}

/// A quantity in one of [QtyUnit]s.
@immutable
class Quantity {
  const Quantity(this.amount, this.unit);

  final double amount;
  final QtyUnit unit;

  /// Reads what people and models write: `kg`, `Gramm`, `l`, `EL`, `Stk`,
  /// `cloves` … Returns null for a unit the list cannot add up.
  static Quantity? parse(num amount, String? unit) {
    final value = amount.toDouble();
    if (value.isNaN || value <= 0) return null;
    final u = (unit ?? '').trim().toLowerCase().replaceAll('.', '');
    switch (u) {
      case 'g':
      case 'gr':
      case 'gramm':
      case 'gram':
      case 'grams':
        return Quantity(value, QtyUnit.g);
      case 'kg':
      case 'kilo':
      case 'kilogramm':
        return Quantity(value * 1000, QtyUnit.g);
      case 'ml':
      case 'milliliter':
        return Quantity(value, QtyUnit.ml);
      case 'cl':
        return Quantity(value * 10, QtyUnit.ml);
      case 'l':
      case 'liter':
      case 'litre':
        return Quantity(value * 1000, QtyUnit.ml);
      case 'el':
      case 'tbsp':
      case 'esslöffel':
      case 'tablespoon':
        return Quantity(value, QtyUnit.tbsp);
      case 'tl':
      case 'tsp':
      case 'teelöffel':
      case 'teaspoon':
        return Quantity(value, QtyUnit.tsp);
      case '':
      case 'stk':
      case 'stück':
      case 'st':
      case 'x':
      case 'pc':
      case 'pcs':
      case 'piece':
      case 'pieces':
      case 'zehe':
      case 'zehen':
      case 'clove':
      case 'cloves':
      case 'dose':
      case 'can':
      case 'bund':
      case 'bunch':
      case 'packung':
      case 'pack':
        return Quantity(value, QtyUnit.piece);
      default:
        return null;
    }
  }

  Quantity operator +(Quantity other) {
    assert(unit == other.unit);
    return Quantity(amount + other.amount, unit);
  }

  Quantity scaled(double factor) => Quantity(amount * factor, unit);

  @override
  bool operator ==(Object other) =>
      other is Quantity && other.amount == amount && other.unit == unit;

  @override
  int get hashCode => Object.hash(amount, unit);

  @override
  String toString() => '$amount ${unit.name}';
}

/// One line of a recipe.
@immutable
class Ingredient {
  const Ingredient({
    required this.name,
    required this.quantity,
    this.category = ShopCategory.other,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        name: (json['name'] as String? ?? '').trim(),
        quantity: Quantity(
          (json['qty'] as num?)?.toDouble() ?? 0,
          QtyUnit.values.asNameMap()[json['unit'] as String?] ?? QtyUnit.piece,
        ),
        category: ShopCategory.values.asNameMap()[json['category'] as String?] ??
            ShopCategory.other,
      );

  final String name;
  final Quantity quantity;
  final ShopCategory category;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'qty': _round(quantity.amount),
        'unit': quantity.unit.name,
        'category': category.name,
      };
}

/// A dish: what to buy for [servings] portions, and what one portion holds.
@immutable
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.servings,
    required this.ingredients,
    required this.perServing,
    this.minutes,
    this.steps = const <String>[],
    this.tags = const <String>[],
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        servings: (json['servings'] as num?)?.toInt() ?? 1,
        ingredients: <Ingredient>[
          for (final Object? i in (json['ingredients'] as List?) ?? const <Object?>[])
            if (i is Map) Ingredient.fromJson(Map<String, dynamic>.from(i)),
        ],
        perServing: _nutrients(json['nutrition']),
        minutes: (json['minutes'] as num?)?.toInt(),
        steps: <String>[
          for (final Object? s in (json['steps'] as List?) ?? const <Object?>[])
            if (s is String) s,
        ],
        tags: <String>[
          for (final Object? t in (json['tags'] as List?) ?? const <Object?>[])
            if (t is String) t,
        ],
      );

  final String id;
  final String title;

  /// The number of portions the [ingredients] are for.
  final int servings;
  final List<Ingredient> ingredients;

  /// Energy and macros of one portion.
  final Nutrients perServing;
  final int? minutes;
  final List<String> steps;
  final List<String> tags;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'servings': servings,
        'ingredients': <Map<String, dynamic>>[
          for (final Ingredient i in ingredients) i.toJson(),
        ],
        'nutrition': <String, dynamic>{
          'kcal': perServing.kcal.round(),
          'p': _round(perServing.proteinG),
          'c': _round(perServing.carbsG),
          'f': _round(perServing.fatG),
        },
        if (minutes != null) 'minutes': minutes,
        'steps': steps,
        'tags': tags,
      };
}

Nutrients _nutrients(Object? json) {
  final map = json is Map ? json : const <String, dynamic>{};
  double n(String key) => (map[key] as num?)?.toDouble() ?? 0;
  return Nutrients(kcal: n('kcal'), proteinG: n('p'), carbsG: n('c'), fatG: n('f'));
}

num _round(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble() ? rounded.round() : rounded;
}

/// What makes two dish names the same dish: case and spacing do not count.
String recipeKey(String title) =>
    title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// The household's recipe called [title], if it has one.
Recipe? recipeNamed(Iterable<Recipe> recipes, String title) {
  final key = recipeKey(title);
  if (key.isEmpty) return null;
  for (final recipe in recipes) {
    if (recipeKey(recipe.title) == key) return recipe;
  }
  return null;
}

/// What to store when [incoming] has the name of a recipe the household
/// already has: one recipe per name, so planning "chili" a third time does
/// not leave three chilis behind.
///
/// The stored recipe stays as it is when it already has ingredients — a
/// dish the household knows does not change because a plan named it again.
/// One entered by hand without them takes the new one's content, under its
/// own id. Returns [existing] itself when nothing needs writing.
Recipe reconcileRecipe(Recipe existing, Recipe incoming) {
  if (existing.ingredients.isNotEmpty) return existing;
  if (incoming.ingredients.isEmpty &&
      (incoming.perServing.kcal <= 0 ||
          incoming.perServing.kcal == existing.perServing.kcal)) {
    return existing;
  }
  return Recipe(
    id: existing.id,
    title: existing.title,
    servings: incoming.servings,
    ingredients: incoming.ingredients,
    perServing: incoming.perServing,
    minutes: incoming.minutes ?? existing.minutes,
    steps: incoming.steps.isEmpty ? existing.steps : incoming.steps,
    tags: incoming.tags.isEmpty ? existing.tags : incoming.tags,
  );
}
