import 'dart:convert';

import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

final DayKey _mon = DayKey(2026, 11, 23);

/// A meal the way a model answers it: salmon with beans, the oil and the
/// salt included.
Map<String, dynamic> _meal(
  String day, {
  String slot = 'dinner',
  String title = 'Lachs mit weißen Bohnen',
  List<Map<String, dynamic>>? ingredients,
  List<String> steps = const <String>['Bohnen erwärmen.', 'Lachs braten.'],
}) =>
    <String, dynamic>{
      'day': day,
      'slot': slot,
      'title': title,
      'servings': 2,
      'minutes': 25,
      'kcal': 620,
      'protein': 45,
      'carbs': 40,
      'fat': 30,
      'ingredients': ingredients ??
          <Map<String, dynamic>>[
            <String, dynamic>{'name': 'Lachsfilet', 'qty': 300, 'unit': 'g', 'category': 'fish'},
            <String, dynamic>{'name': 'Weiße Bohnen', 'qty': 400, 'unit': 'g', 'category': 'pantry'},
            <String, dynamic>{'name': 'Olivenöl', 'qty': 2, 'unit': 'tbsp', 'category': 'pantry', 'staple': true},
            <String, dynamic>{'name': 'Salz', 'qty': 1, 'unit': 'Prise', 'category': 'pantry'},
          ],
      'steps': steps,
    };

MealPlanRequest _request({
  List<DayKey>? days,
  List<MealSlotKind> slots = const <MealSlotKind>[MealSlotKind.dinner],
  CookingLevel level = CookingLevel.everyday,
}) =>
    MealPlanRequest(
      days: days ?? <DayKey>[_mon],
      slots: slots,
      people: const <PlanFor>[PlanFor(name: 'Mike')],
      level: level,
    );

Recipe _parsed(Map<String, dynamic> meal, {CookingLevel level = CookingLevel.everyday}) =>
    parseMealPlan(
      jsonEncode(<String, dynamic>{'meals': <Object>[meal]}),
      _request(days: <DayKey>[DayKey.parse(meal['day'] as String)], level: level),
    ).single.recipe;

PlanEntry _entry(String id, DayKey day, String recipe) =>
    PlanEntry(id: id, day: day, slot: MealSlotKind.dinner, recipeId: recipe);

void main() {
  group('kitchen basics', () {
    test('the oil and the salt stay in the recipe, marked as basics', () {
      final recipe = _parsed(_meal('2026-11-23'));
      final byName = <String, Ingredient>{
        for (final Ingredient i in recipe.ingredients) i.name: i,
      };
      expect(byName.keys, <String>['Lachsfilet', 'Weiße Bohnen', 'Olivenöl', 'Salz']);
      expect(byName['Olivenöl']!.staple, isTrue, reason: 'marked by the model');
      // Not marked, but salt by its name — and a pinch is an amount.
      expect(byName['Salz']!.staple, isTrue);
      expect(byName['Salz']!.quantity, const Quantity(0.25, QtyUnit.tsp));
      expect(byName['Lachsfilet']!.staple, isFalse);
      expect(byName['Weiße Bohnen']!.staple, isFalse);
    });

    test('nothing fresh and nothing bought in quantity is a basic, whatever the model says', () {
      final recipe = _parsed(_meal('2026-11-23', ingredients: <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Hähnchenbrust', 'qty': 300, 'unit': 'g', 'category': 'meat', 'staple': true},
        <String, dynamic>{'name': 'Mehl', 'qty': 500, 'unit': 'g', 'category': 'pantry', 'staple': true},
        <String, dynamic>{'name': 'Mehl zum Bestäuben', 'qty': 20, 'unit': 'g', 'category': 'pantry', 'staple': true},
        <String, dynamic>{'name': 'Frittieröl', 'qty': 1, 'unit': 'l', 'category': 'pantry'},
        <String, dynamic>{'name': 'Zucker', 'qty': 1, 'unit': 'tsp', 'category': 'staples', 'staple': true},
      ]));
      expect(<String, bool>{for (final Ingredient i in recipe.ingredients) i.name: i.staple}, <String, bool>{
        'Hähnchenbrust': false,
        'Mehl': false,
        'Mehl zum Bestäuben': true,
        'Frittieröl': false,
        'Zucker': true,
      });
      // The list's section for basics is not an aisle a model may file under.
      expect(recipe.ingredients.last.category, ShopCategory.pantry);
    });

    test('are known by name in both languages, and paprika is not one of them', () {
      for (final String name in <String>['Salz', 'Pfeffer', 'Olivenöl', 'olive oil', 'Rapsöl', 'Apfelessig', 'white wine vinegar', 'Kreuzkümmel', ' Black  pepper ']) {
        expect(isKitchenStaple(name), isTrue, reason: name);
      }
      for (final String name in <String>['Paprika', 'Kohl', 'Reis', 'Butter', 'bell pepper', 'Öle und Fette']) {
        expect(isKitchenStaple(name), isFalse, reason: name);
      }
    });

    test('survive the recipe JSON, and a recipe without them reads as before', () {
      final recipe = _parsed(_meal('2026-11-23'));
      final back = Recipe.fromJson(jsonDecode(jsonEncode(recipe.toJson())) as Map<String, dynamic>);
      expect(back.ingredients.map((Ingredient i) => i.staple), <bool>[false, false, true, true]);
      final plain = Ingredient.fromJson(const <String, dynamic>{'name': 'Reis', 'qty': 150, 'unit': 'g', 'category': 'pantry'});
      expect(plain.staple, isFalse);
      expect(plain.toJson().containsKey('staple'), isFalse);
    });
  });

  group('a shopping list with basics', () {
    final salmon = _parsed(_meal('2026-11-23'));
    final soup = _parsed(_meal('2026-11-24', title: 'Linsensuppe', ingredients: <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Linsen', 'qty': 200, 'unit': 'g', 'category': 'pantry'},
      <String, dynamic>{'name': 'olivenöl', 'qty': 1, 'unit': 'tbsp', 'category': 'pantry', 'staple': true},
      <String, dynamic>{'name': 'Kreuzkümmel', 'qty': 1, 'unit': 'tsp', 'category': 'pantry'},
    ]));
    final recipes = <String, Recipe>{salmon.id: salmon, soup.id: soup};
    final entries = <PlanEntry>[_entry('a', _mon, salmon.id), _entry('b', _mon.addDays(1), soup.id)];
    final period = ShoppingPeriod(_mon, _mon.addDays(6));

    test('names each basic once, without an amount, after the aisles', () {
      final items = buildShoppingList(entries: entries, recipes: recipes, period: period, householdSize: 2);
      final basics = items.where((ShoppingItem i) => i.category == ShopCategory.staples).toList();
      expect(basics.map((ShoppingItem i) => i.name), <String>['Kreuzkümmel', 'Olivenöl', 'Salz']);
      expect(basics.every((ShoppingItem i) => i.quantity == null), isTrue);
      expect(basics[1].recipeIds, <String>{salmon.id, soup.id});
      expect(items.last.category, ShopCategory.staples);
      // What is bought keeps its amounts.
      expect(items.firstWhere((ShoppingItem i) => i.name == 'Lachsfilet').quantity, const Quantity(300, QtyUnit.g));
    });

    test('leaves out the basics the household always has', () {
      final items = buildShoppingList(
        entries: entries,
        recipes: recipes,
        period: period,
        householdSize: 2,
        pantry: <String>{'Salz', 'Olivenöl'},
      );
      expect(items.where((ShoppingItem i) => i.category == ShopCategory.staples).map((ShoppingItem i) => i.name),
          <String>['Kreuzkümmel']);
    });

    test('a basic that another dish needs in quantity is on the list once, with that amount', () {
      final fries = _parsed(_meal('2026-11-25', title: 'Pommes', ingredients: <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Kartoffeln', 'qty': 800, 'unit': 'g', 'category': 'produce'},
        <String, dynamic>{'name': 'Olivenöl', 'qty': 500, 'unit': 'ml', 'category': 'pantry'},
      ]));
      final items = buildShoppingList(
        entries: <PlanEntry>[...entries, _entry('c', _mon.addDays(2), fries.id)],
        recipes: <String, Recipe>{...recipes, fries.id: fries},
        period: period,
        householdSize: 2,
      );
      final oil = items.where((ShoppingItem i) => shoppingKey(i.name) == 'olivenöl').toList();
      expect(oil.single.quantity, const Quantity(500, QtyUnit.ml));
      expect(oil.single.category, ShopCategory.pantry);
    });

    test('made again, a basic already on the list is not named twice', () {
      final wanted = buildShoppingList(entries: entries, recipes: recipes, period: period, householdSize: 2);
      final missing = stillMissing(wanted, const <ShoppingItem>[
        ShoppingItem(name: 'Olivenöl', category: ShopCategory.staples, checked: true),
        ShoppingItem(name: 'Lachsfilet', category: ShopCategory.fish, quantity: Quantity(300, QtyUnit.g)),
      ]);
      expect(missing.map((ShoppingItem i) => i.name), isNot(contains('Olivenöl')));
      expect(missing.map((ShoppingItem i) => i.name), containsAll(<String>['Salz', 'Kreuzkümmel', 'Linsen']));
    });

    test('a meal that is only a name is what the list cannot know', () {
      const pizza = Recipe(
        id: 'pizza',
        title: 'Pizza',
        servings: 1,
        ingredients: <Ingredient>[],
        perServing: Nutrients(kcal: 800, proteinG: 0, carbsG: 0, fatG: 0),
      );
      final all = <PlanEntry>[
        _entry('late', _mon.addDays(3), 'pizza'),
        ...entries,
        _entry('early', _mon, 'gone'),
        _entry('next-week', _mon.addDays(9), 'pizza'),
      ];
      final missing = mealsWithoutRecipe(
        entries: all,
        recipes: <String, Recipe>{...recipes, 'pizza': pizza},
        period: period,
      );
      expect(missing.map((PlanEntry e) => e.id), <String>['early', 'late']);
      expect(pizza.isWritten, isFalse);
      expect(salmon.isWritten, isTrue);
    });
  });

  group('cooking level', () {
    test('the prompt says how much is made at home', () {
      const prompts = EnglishMealPlanPrompts();
      expect(prompts.proposeWeek(_request(level: CookingLevel.convenience)), contains('canned pulses'));
      expect(prompts.proposeWeek(_request(level: CookingLevel.scratch)), contains('dried pulses soaked'));
      final draft = prompts.draftMeal(MealDraftRequest(
        day: _mon,
        slot: MealSlotKind.dinner,
        people: const <PlanFor>[PlanFor(name: 'Mike')],
        title: 'Lachs',
        level: CookingLevel.scratch,
      ));
      expect(draft, contains('from scratch'));
      // Every prompt asks for the whole ingredient list and steps to cook from.
      expect(draft, contains('List EVERY ingredient'));
      expect(prompts.proposeWeek(_request()), contains('"staple": true'));
    });

    test('a recipe carries the level it was written at, through its JSON', () {
      final recipe = _parsed(_meal('2026-11-23'), level: CookingLevel.scratch);
      expect(recipe.level, CookingLevel.scratch);
      final json = jsonDecode(jsonEncode(recipe.toJson())) as Map<String, dynamic>;
      // Among the tags: a backend from before levels stores it as it is.
      expect(json['tags'], <String>['level:scratch']);
      expect(json.containsKey('level'), isFalse);
      final back = Recipe.fromJson(json);
      expect(back.level, CookingLevel.scratch);
      expect(back.tags, isEmpty);
      // A recipe from before levels, and a level a newer app wrote.
      expect(Recipe.fromJson(<String, dynamic>{...json, 'tags': <String>['quick']}).level, isNull);
      final newer = Recipe.fromJson(<String, dynamic>{...json, 'tags': <String>['quick', 'level:sousvide']});
      expect(newer.level, isNull);
      expect(newer.tags, <String>['quick']);
    });

    test('one name, two levels: two recipes', () {
      final canned = _parsed(_meal('2026-11-23'), level: CookingLevel.convenience);
      final scratch = _parsed(_meal('2026-11-23'), level: CookingLevel.scratch);
      final old = Recipe.fromJson(<String, dynamic>{...canned.toJson(), 'id': 'old', 'title': 'Chili', 'tags': <String>[]});
      const onlyAName = Recipe(
        id: 'pizza',
        title: 'Pizza',
        servings: 1,
        ingredients: <Ingredient>[],
        perServing: Nutrients(kcal: 800, proteinG: 0, carbsG: 0, fatG: 0),
      );
      final known = <Recipe>[onlyAName, canned, scratch, old];
      expect(recipeNamed(known, canned.title, level: CookingLevel.scratch), same(scratch));
      expect(recipeNamed(known, canned.title, level: CookingLevel.convenience), same(canned));
      expect(recipeNamed(known, canned.title, level: CookingLevel.everyday), isNull);
      // Typed by hand, without a level: the dish the household has written.
      expect(recipeNamed(known, canned.title), same(canned));
      // A name without a recipe takes whichever is written for it.
      expect(recipeNamed(known, 'pizza', level: CookingLevel.scratch), same(onlyAName));
      final filled = reconcileRecipe(onlyAName, scratch);
      expect(filled.id, 'pizza');
      expect(filled.level, CookingLevel.scratch);
      // A dish known at this level stays as the household has it.
      expect(reconcileRecipe(scratch, _parsed(_meal('2026-11-23'), level: CookingLevel.scratch)), same(scratch));

      // From before levels — and before recipes listed their basics: found
      // whatever level is asked for, and the new writing takes its place,
      // under the id the plan knows.
      expect(old.level, isNull);
      expect(recipeNamed(known, 'chili', level: CookingLevel.everyday), same(old));
      expect(recipeNamed(known, 'chili', level: CookingLevel.scratch), same(old));
      final renewed = reconcileRecipe(old, scratch);
      expect(renewed.id, 'old');
      expect(renewed.title, 'Chili');
      expect(renewed.level, CookingLevel.scratch);
      expect(renewed.ingredients, scratch.ingredients);
      // Named again by hand, it is not emptied.
      expect(reconcileRecipe(old, onlyAName), same(old));
    });

    test('written again, a dish keeps its name and its place in the plan', () {
      final canned = _parsed(_meal('2026-11-23'), level: CookingLevel.convenience);
      final scratch = _parsed(
        _meal('2026-11-23', title: 'Wildlachs, selbst filetiert', steps: <String>['1. Bohnen über Nacht einweichen.', '2) Lachs filetieren.', '- Braten.']),
        level: CookingLevel.scratch,
      );
      final again = canned.rewrittenAs(scratch);
      expect(again.id, canned.id);
      expect(again.title, canned.title);
      expect(again.level, CookingLevel.scratch);
      // Steps are numbered by whoever shows them.
      expect(again.steps, <String>['Bohnen über Nacht einweichen.', 'Lachs filetieren.', 'Braten.']);
    });

    test('a recipe is held to a size the backend stores', () {
      final recipe = _parsed(_meal(
        '2026-11-23',
        ingredients: <Map<String, dynamic>>[
          for (int i = 0; i < 60; i++)
            <String, dynamic>{'name': 'Zutat $i', 'qty': 10, 'unit': 'g', 'category': 'pantry'},
        ],
        steps: <String>[for (int i = 0; i < 40; i++) 'Schritt ' * 200],
      ));
      expect(recipe.ingredients, hasLength(kMaxIngredients));
      expect(recipe.steps, hasLength(kMaxSteps));
      expect(recipe.steps.first.length, kMaxStepLength);
    });
  });

  group('a long week', () {
    test('is asked for a few days at a time, each call told what the others planned', () async {
      final days = <DayKey>[for (int i = 0; i < 7; i++) _mon.addDays(i)];
      const slots = <MealSlotKind>[MealSlotKind.lunch, MealSlotKind.dinner];
      final llm = _Llm((String prompt) => jsonEncode(<String, dynamic>{
            'meals': <Object>[
              for (final DayKey day in days)
                if (prompt.contains('- $day:'))
                  for (final MealSlotKind slot in slots)
                    _meal('$day', slot: slot.name, title: 'Gericht $day ${slot.name}'),
            ],
          }));
      final meals = await MealPlanner(llm: llm).proposeWeek(
          _request(days: days, slots: slots, level: CookingLevel.scratch));
      expect(meals, hasLength(14));
      // Eight meals a call: four days, then three.
      expect(llm.prompts, hasLength(2));
      expect(llm.prompts.first, isNot(contains('Do not repeat')));
      expect(llm.prompts.last, contains('Gericht $_mon lunch'));
      expect(llm.prompts.last, isNot(contains('- $_mon:')));
      expect(meals!.every((ProposedMeal m) => m.recipe.level == CookingLevel.scratch), isTrue);
    });

    test('keeps the days it got when a later call fails', () async {
      final days = <DayKey>[for (int i = 0; i < 10; i++) _mon.addDays(i)];
      var calls = 0;
      final llm = _Llm((String prompt) {
        if (++calls > 1) throw StateError('offline');
        return jsonEncode(<String, dynamic>{
          'meals': <Object>[
            for (final DayKey day in days.take(8)) _meal('$day', title: 'Gericht $day'),
          ],
        });
      });
      final errors = <Object>[];
      final meals = await MealPlanner(llm: llm).proposeWeek(_request(days: days), onError: errors.add);
      expect(meals, hasLength(8));
      expect(errors, hasLength(1));
    });
  });
}

class _Llm implements LlmClient {
  _Llm(this.answer);

  final String Function(String prompt) answer;
  final List<String> prompts = <String>[];

  @override
  String get modelName => 'fake';

  @override
  bool get isReady => true;

  @override
  Future<String> generate(
    String prompt, {
    List<LlmImage> images = const <LlmImage>[],
    LlmPurpose purpose = LlmPurpose.food,
    int maxTokens = 400,
    double temperature = 0.7,
    Duration timeout = const Duration(seconds: 30),
    bool json = false,
    Map<String, Object?>? schema,
  }) async {
    prompts.add(prompt);
    return answer(prompt);
  }
}
