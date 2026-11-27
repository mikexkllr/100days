import 'package:meta/meta.dart';

import 'cadence.dart';
import 'meal_plan.dart';
import 'recipe.dart';

/// One line of a shopping list.
@immutable
class ShoppingItem {
  const ShoppingItem({
    required this.name,
    required this.category,
    this.quantity,
    this.checked = false,
    this.recipeIds = const <String>{},
  });

  final String name;
  final ShopCategory category;

  /// Null for a line added by hand without an amount ("Kaffee").
  final Quantity? quantity;
  final bool checked;

  /// The recipes this line is for — "for Wednesday's curry".
  final Set<String> recipeIds;
}

/// Turns a written name into the key items are merged by: "Zwiebeln",
/// "zwiebel " and "Zwiebel" are one line. Simple plural endings for German
/// and English are folded; anything smarter (synonyms) comes from the app's
/// food vocabulary through [buildShoppingList]'s `canonical`.
String shoppingKey(String name) {
  final key = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  for (final (String suffix, String replacement) in const <(String, String)>[
    ('tomatoes', 'tomato'),
    ('potatoes', 'potato'),
    ('ies', 'y'),
    ('eier', 'ei'),
    ('beeren', 'beere'),
    ('zwiebeln', 'zwiebel'),
    ('karotten', 'karotte'),
    ('paprikas', 'paprika'),
    ('tomaten', 'tomate'),
    ('bananen', 'banane'),
    ('kartoffeln', 'kartoffel'),
    ('gurken', 'gurke'),
    ('nudeln', 'nudel'),
  ]) {
    if (key.endsWith(suffix)) {
      return key.substring(0, key.length - suffix.length) + replacement;
    }
  }
  // English "eggs", "onions", "carrots" — but not where the s belongs to the
  // word: "Reis", "Mais", "Kürbis", "Hummus", "grass".
  if (key.length > 3 &&
      key.endsWith('s') &&
      !RegExp(r'(is|us|ss)$').hasMatch(key)) {
    return key.substring(0, key.length - 1);
  }
  return key;
}

/// What to buy for the plan in [period].
///
/// Each planned meal's ingredients are scaled from the recipe's servings to
/// the portions planned for [members] — the ids of everyone in the household
/// now — then lines with the same name and unit are added up. Things already at home ([pantry], by name) are left out. Sorted
/// by aisle, then name. Deterministic: the same plan gives the same list on
/// every phone of the household.
List<ShoppingItem> buildShoppingList({
  required Iterable<PlanEntry> entries,
  required Map<String, Recipe> recipes,
  required ShoppingPeriod period,
  required Iterable<String> members,
  Set<String> pantry = const <String>{},
  String Function(String name)? canonical,
}) {
  final key = canonical ?? shoppingKey;
  final excluded = pantry.map(key).toSet();
  final lines = <(String, QtyUnit), _Line>{};

  for (final entry in entries) {
    if (!period.contains(entry.day)) continue;
    final recipe = recipes[entry.recipeId];
    if (recipe == null || recipe.servings <= 0) continue;
    final factor = entry.totalPortions(members) / recipe.servings;
    if (factor <= 0) continue;
    for (final ingredient in recipe.ingredients) {
      final k = key(ingredient.name);
      if (k.isEmpty || excluded.contains(k)) continue;
      final line = lines.putIfAbsent(
        (k, ingredient.quantity.unit),
        () => _Line(ingredient.name, ingredient.category, ingredient.quantity.unit),
      );
      line.amount += ingredient.quantity.amount * factor;
      line.recipeIds.add(recipe.id);
    }
  }

  final items = <ShoppingItem>[
    for (final line in lines.values)
      ShoppingItem(
        name: line.name,
        category: line.category,
        quantity: Quantity(_shoppable(line.amount, line.unit), line.unit),
        recipeIds: line.recipeIds,
      ),
  ]..sort((ShoppingItem a, ShoppingItem b) {
      final byAisle = a.category.index.compareTo(b.category.index);
      return byAisle != 0 ? byAisle : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return items;
}

/// What of [wanted] is not on a list yet that already holds [onList] — so
/// making the list from the plan again tops it up instead of doubling it.
///
/// Lines are matched by name and unit, ticked ones included: bought is
/// covered. A line without an amount ("Milch", typed by hand) covers its
/// name in full. What is left is rounded the way [buildShoppingList]
/// rounds.
List<ShoppingItem> stillMissing(
  Iterable<ShoppingItem> wanted,
  Iterable<ShoppingItem> onList, {
  String Function(String name)? canonical,
}) {
  final key = canonical ?? shoppingKey;
  final covered = <(String, QtyUnit), double>{};
  final named = <String>{};
  for (final item in onList) {
    final quantity = item.quantity;
    if (quantity == null) {
      named.add(key(item.name));
      continue;
    }
    final k = (key(item.name), quantity.unit);
    covered[k] = (covered[k] ?? 0) + quantity.amount;
  }
  final missing = <ShoppingItem>[];
  for (final item in wanted) {
    final k = key(item.name);
    if (named.contains(k)) continue;
    final quantity = item.quantity;
    if (quantity == null) {
      if (!covered.keys.any(((String, QtyUnit) c) => c.$1 == k)) missing.add(item);
      continue;
    }
    final left = quantity.amount - (covered[(k, quantity.unit)] ?? 0);
    if (left <= 0.001) continue;
    missing.add(ShoppingItem(
      name: item.name,
      category: item.category,
      quantity: Quantity(_shoppable(left, quantity.unit), quantity.unit),
      recipeIds: item.recipeIds,
    ));
  }
  return missing;
}

/// Rounds up to what a shop sells: whole pieces, 10 g / 10 ml steps,
/// half spoons. Nobody buys 1.3 onions.
double _shoppable(double amount, QtyUnit unit) => switch (unit) {
      QtyUnit.piece => amount.ceilToDouble(),
      QtyUnit.g || QtyUnit.ml => (amount / 10).ceil() * 10.0,
      QtyUnit.tbsp || QtyUnit.tsp => (amount * 2).ceil() / 2,
    };

class _Line {
  _Line(this.name, this.category, this.unit);

  final String name;
  final ShopCategory category;
  final QtyUnit unit;
  double amount = 0;
  final Set<String> recipeIds = <String>{};
}

/// A best guess at the aisle for a line typed by hand, from its words. The
/// model assigns categories to the ingredients it plans; this only covers
/// "add milk".
ShopCategory guessCategory(String name) {
  final n = shoppingKey(name);
  final words = n.split(RegExp(r'[\s-]+'));
  // Long words may sit inside a compound ("Vollmilch", "Olivenöl"); short
  // ones only count as a whole word or a compound's end, or "Reis" would be
  // an egg.
  bool any(List<String> keys) => keys.any((String k) => k.length > 3
      ? n.contains(k)
      : words.any((String w) => w == k || (w.length > k.length + 2 && w.endsWith(k))));
  // Checked in this order: the first match wins.
  const rules = <(ShopCategory, List<String>)>[
    (ShopCategory.produce, <String>['apfel', 'apple', 'banane', 'banana', 'tomate', 'tomato', 'salat', 'lettuce', 'zwiebel', 'onion', 'karotte', 'carrot', 'paprika', 'pepper', 'gurke', 'cucumber', 'kartoffel', 'potato', 'beere', 'berry', 'zitrone', 'lemon', 'knoblauch', 'garlic', 'spinat', 'spinach', 'brokkoli', 'broccoli', 'avocado', 'pilz', 'mushroom']),
    (ShopCategory.bakery, <String>['brot', 'bread', 'brötchen', 'roll', 'toast', 'baguette']),
    (ShopCategory.meat, <String>['hähnchen', 'chicken', 'rind', 'beef', 'hack', 'mince', 'schwein', 'pork', 'wurst', 'sausage', 'schinken', 'ham', 'pute', 'turkey']),
    (ShopCategory.fish, <String>['lachs', 'salmon', 'thunfisch', 'tuna', 'fisch', 'fish', 'garnele', 'shrimp']),
    (ShopCategory.pantry, <String>['reis', 'rice', 'nudel', 'pasta', 'mehl', 'flour', 'zucker', 'sugar', 'öl', 'oil', 'haferflocken', 'oats', 'linse', 'lentil', 'bohne', 'bean', 'salz', 'salt', 'gewürz', 'spice']),
    (ShopCategory.dairy, <String>['milch', 'milk', 'joghurt', 'yogurt', 'käse', 'cheese', 'quark', 'butter', 'sahne', 'cream', 'ei', 'egg']),
    (ShopCategory.drinks, <String>['wasser', 'water', 'saft', 'juice', 'kaffee', 'coffee', 'tee', 'tea', 'bier', 'beer', 'wein', 'wine']),
    (ShopCategory.frozen, <String>['tiefkühl', 'frozen', 'eis', 'ice cream']),
    (ShopCategory.household, <String>['spülmittel', 'dish soap', 'toilettenpapier', 'toilet paper', 'waschmittel', 'detergent', 'müllbeutel', 'bin bag']),
  ];
  for (final (ShopCategory category, List<String> keys) in rules) {
    if (any(keys)) return category;
  }
  return ShopCategory.other;
}
