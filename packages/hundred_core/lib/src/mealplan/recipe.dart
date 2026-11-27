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

  /// Not an aisle: kitchen basics a recipe takes a little of — oil, salt,
  /// spices — which a list names to check at home rather than to buy
  /// outright. Last, so the aisles before it keep their order.
  staples,
}

/// How much of a dish is made at home and how much is bought ready.
///
/// The same dinner is three different shopping trips: a ready-to-cook
/// salmon fillet with beans from a can, the fillet with fresh sides — or a
/// side of wild salmon to portion and dried beans soaked overnight. Chosen
/// when a plan or a recipe is written, and kept on the recipe.
enum CookingLevel {
  /// Ready-made parts welcome: canned, frozen, pre-cooked, ready to cook.
  convenience,

  /// Home cooking as most households do it: fresh main ingredients, a can
  /// of tomatoes or beans where that is usual.
  everyday,

  /// From whole, raw ingredients: dried pulses, whole fish, stock and dough
  /// made at home.
  scratch,
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
      // "A pinch of salt" is still salt: a quarter teaspoon, so it stays in
      // the recipe instead of being dropped for its unit.
      case 'prise':
      case 'prisen':
      case 'pinch':
      case 'pinches':
      case 'msp':
      case 'messerspitze':
      case 'dash':
        return Quantity(value * 0.25, QtyUnit.tsp);
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
    this.staple = false,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        name: (json['name'] as String? ?? '').trim(),
        quantity: Quantity(
          (json['qty'] as num?)?.toDouble() ?? 0,
          QtyUnit.values.asNameMap()[json['unit'] as String?] ?? QtyUnit.piece,
        ),
        category: ShopCategory.values.asNameMap()[json['category'] as String?] ??
            ShopCategory.other,
        staple: json['staple'] == true,
      );

  final String name;
  final Quantity quantity;

  /// The aisle it is bought in — also for a [staple], which a list files
  /// under [ShopCategory.staples] instead.
  final ShopCategory category;

  /// A kitchen basic: the recipe takes a little, the shop sells a pack
  /// that lasts for months, and most kitchens have one — oil, salt, dried
  /// spices. The recipe still says how much; the shopping list only asks
  /// whether it is there.
  final bool staple;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'qty': _round(quantity.amount),
        'unit': quantity.unit.name,
        'category': category.name,
        if (staple) 'staple': true,
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
    this.level,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final tags = <String>[
      for (final Object? t in (json['tags'] as List?) ?? const <Object?>[])
        if (t is String) t,
    ];
    CookingLevel? level;
    for (final tag in tags) {
      if (!tag.startsWith(_levelTag)) continue;
      level ??= CookingLevel.values.asNameMap()[tag.substring(_levelTag.length)];
    }
    return Recipe(
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
        for (final tag in tags)
          if (!tag.startsWith(_levelTag)) tag,
      ],
      level: level,
    );
  }

  /// How a recipe's [level] is stored: as one of its tags. Recipes have
  /// had tags from the start, so a backend from before levels keeps one
  /// without a change to its tables, and an older app reads past it.
  static const String _levelTag = 'level:';

  final String id;
  final String title;

  /// The number of portions the [ingredients] are for.
  final int servings;
  final List<Ingredient> ingredients;

  /// Energy and macros of one portion.
  final Nutrients perServing;
  final int? minutes;

  /// The cooking instructions, one action each, in order.
  final List<String> steps;
  final List<String> tags;

  /// The level it was written at. Null for a recipe from before levels, and
  /// for one that is only a name.
  final CookingLevel? level;

  /// Whether there is more to it than a name: something to buy. A meal
  /// typed in by hand, or picked from the meal ideas, has none until its
  /// recipe is written — and until then no shopping list can know it.
  bool get isWritten => ingredients.isNotEmpty;

  /// This recipe with the content of [written] — the same dish, written
  /// again. The id and the name stay: the plan points at them.
  Recipe rewrittenAs(Recipe written) => Recipe(
        id: id,
        title: title,
        servings: written.servings,
        ingredients: written.ingredients,
        perServing: written.perServing,
        minutes: written.minutes,
        steps: written.steps,
        tags: tags,
        level: written.level,
      );

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
        'tags': <String>[
          ...tags,
          if (level != null) '$_levelTag${level!.name}',
        ],
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
///
/// With [level], the one written at that level — chili from cans and chili
/// from dried beans are two recipes with one name — or one from before
/// recipes had a level, or else one that is only a name so far: both of
/// those a newly written recipe takes the place of (see [reconcileRecipe]).
/// Without [level], a written recipe of that name before one that is only
/// a name.
Recipe? recipeNamed(
  Iterable<Recipe> recipes,
  String title, {
  CookingLevel? level,
}) {
  final key = recipeKey(title);
  if (key.isEmpty) return null;
  Recipe? onlyAName;
  for (final recipe in recipes) {
    if (recipeKey(recipe.title) != key) continue;
    if (!recipe.isWritten) {
      onlyAName ??= recipe;
    } else if (level == null || recipe.level == null || recipe.level == level) {
      return recipe;
    }
  }
  return onlyAName;
}

/// What to store when [incoming] has the name of a recipe the household
/// already has: one recipe per name, so planning "chili" a third time does
/// not leave three chilis behind.
///
/// The stored recipe stays as it is when it already has ingredients — a
/// dish the household knows does not change because a plan named it again.
/// One entered by hand without them takes the new one's content, under its
/// own id. So does one written before recipes had a level: those left out
/// the oil and the salt, and the dish written anew is the one a shopping
/// list can be made from. Returns [existing] itself when nothing needs
/// writing.
Recipe reconcileRecipe(Recipe existing, Recipe incoming) {
  if (existing.isWritten) {
    return existing.level == null && incoming.level != null && incoming.isWritten
        ? existing.rewrittenAs(incoming)
        : existing;
  }
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
    level: incoming.level ?? existing.level,
  );
}

/// Whether [name] is a kitchen basic by its name alone: salt, pepper, an
/// oil, a vinegar, a common dried spice. The model marks the basics of the
/// recipes it writes; this catches the ones it forgets to mark, in German
/// and English. Deliberately short — "paprika" is a vegetable in one
/// language and a spice in the other, and is not on it.
bool isKitchenStaple(String name) {
  final key = recipeKey(name);
  return _stapleNames.contains(key) || _stapleEndings.any(key.endsWith);
}

const Set<String> _stapleNames = <String>{
  'salz', 'meersalz', 'jodsalz', 'salt', 'sea salt', 'table salt',
  'oil', 'vinegar',
  'pfeffer', 'schwarzer pfeffer', 'pepper', 'black pepper', 'ground pepper',
  'salz und pfeffer', 'salt and pepper',
  'paprikapulver', 'paprika edelsüß', 'paprika powder', 'smoked paprika',
  'kreuzkümmel', 'cumin', 'ground cumin',
  'currypulver', 'curry powder', 'kurkuma', 'turmeric',
  'zimt', 'cinnamon', 'muskat', 'muskatnuss', 'nutmeg',
  'oregano', 'getrockneter oregano', 'dried oregano',
  'chiliflocken', 'chili flakes', 'chilli flakes',
  'lorbeerblatt', 'lorbeerblätter', 'bay leaf', 'bay leaves',
};

/// "Olivenöl", "olive oil", "Apfelessig", "white wine vinegar".
const List<String> _stapleEndings = <String>['öl', ' oil', 'essig', ' vinegar'];

