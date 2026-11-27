import 'dart:convert';

import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

Recipe _curry({int servings = 2}) => Recipe(
      id: 'curry',
      title: 'Hähnchen-Curry',
      servings: servings,
      perServing: const Nutrients(kcal: 640, proteinG: 42, carbsG: 70, fatG: 18),
      ingredients: const <Ingredient>[
        Ingredient(name: 'Hähnchenbrust', quantity: Quantity(300, QtyUnit.g), category: ShopCategory.meat),
        Ingredient(name: 'Reis', quantity: Quantity(150, QtyUnit.g), category: ShopCategory.pantry),
        Ingredient(name: 'Zwiebel', quantity: Quantity(1, QtyUnit.piece), category: ShopCategory.produce),
      ],
    );

Recipe _omelette() => const Recipe(
      id: 'omelette',
      title: 'Omelett',
      servings: 1,
      perServing: Nutrients(kcal: 320, proteinG: 22, carbsG: 4, fatG: 24),
      ingredients: <Ingredient>[
        Ingredient(name: 'Eier', quantity: Quantity(3, QtyUnit.piece), category: ShopCategory.dairy),
        Ingredient(name: 'Zwiebeln', quantity: Quantity(0.5, QtyUnit.piece), category: ShopCategory.produce),
      ],
    );

PlanEntry _entry(String id, DayKey day, String recipe, {Map<String, double> portions = const <String, double>{}}) =>
    PlanEntry(id: id, day: day, slot: MealSlotKind.dinner, recipeId: recipe, portions: portions);

final DayKey _sat = DayKey(2026, 11, 21);

void main() {
  group('quantities', () {
    test('read what people and models write', () {
      expect(Quantity.parse(1, 'kg'), const Quantity(1000, QtyUnit.g));
      expect(Quantity.parse(0.5, 'l'), const Quantity(500, QtyUnit.ml));
      expect(Quantity.parse(2, 'EL'), const Quantity(2, QtyUnit.tbsp));
      expect(Quantity.parse(3, 'Stk.'), const Quantity(3, QtyUnit.piece));
      expect(Quantity.parse(2, 'cloves'), const Quantity(2, QtyUnit.piece));
      expect(Quantity.parse(1, null), const Quantity(1, QtyUnit.piece));
      expect(Quantity.parse(1, 'handful'), isNull);
      expect(Quantity.parse(0, 'g'), isNull);
    });

    test('names fold plurals into one key', () {
      expect(shoppingKey('Zwiebeln '), shoppingKey('zwiebel'));
      expect(shoppingKey('Eier'), shoppingKey('Ei'));
      expect(shoppingKey('tomatoes'), shoppingKey('Tomato'));
      expect(shoppingKey('eggs'), 'egg');
      expect(shoppingKey('Reis'), 'reis', reason: 'short words keep their s');
    });
  });

  group('shopping list', () {
    test('scales recipes to the planned portions and adds them up', () {
      final items = buildShoppingList(
        entries: <PlanEntry>[
          _entry('a', _sat, 'curry', portions: <String, double>{'mike': 1.5, 'lena': 1}),
          _entry('b', _sat.addDays(1), 'omelette'),
        ],
        recipes: <String, Recipe>{'curry': _curry(), 'omelette': _omelette()},
        period: ShoppingPeriod(_sat, _sat.addDays(6)),
        householdSize: 2,
      );
      ShoppingItem line(String name) => items.firstWhere((ShoppingItem i) => shoppingKey(i.name) == shoppingKey(name));
      // 2.5 portions of a 2-serving curry: 375 g chicken, rounded up.
      expect(line('Hähnchenbrust').quantity, const Quantity(380, QtyUnit.g));
      expect(line('Reis').quantity, const Quantity(190, QtyUnit.g));
      // 1.25 onions from the curry + 1 (2 × 0.5) from the omelette, in
      // whole onions.
      expect(line('Zwiebel').quantity, const Quantity(3, QtyUnit.piece));
      expect(line('Zwiebel').recipeIds, <String>{'curry', 'omelette'});
      expect(line('Eier').quantity, const Quantity(6, QtyUnit.piece));
    });

    test('leaves out what is at home and what lies outside the period', () {
      final items = buildShoppingList(
        entries: <PlanEntry>[
          _entry('a', _sat, 'curry'),
          _entry('b', _sat.addDays(9), 'omelette'),
        ],
        recipes: <String, Recipe>{'curry': _curry(), 'omelette': _omelette()},
        period: ShoppingPeriod(_sat, _sat.addDays(6)),
        householdSize: 2,
        pantry: <String>{'reis'},
      );
      expect(items.map((ShoppingItem i) => i.name), isNot(contains('Reis')));
      expect(items.map((ShoppingItem i) => i.name), isNot(contains('Eier')));
    });

    test('is sorted by aisle, so a trip goes shelf by shelf', () {
      final items = buildShoppingList(
        entries: <PlanEntry>[_entry('a', _sat, 'curry')],
        recipes: <String, Recipe>{'curry': _curry()},
        period: ShoppingPeriod(_sat, _sat),
        householdSize: 2,
      );
      expect(items.map((ShoppingItem i) => i.category),
          <ShopCategory>[ShopCategory.produce, ShopCategory.meat, ShopCategory.pantry]);
    });

    test('a line typed by hand gets a likely aisle', () {
      expect(guessCategory('Vollmilch'), ShopCategory.dairy);
      expect(guessCategory('Reis'), ShopCategory.pantry);
      expect(guessCategory('Eier'), ShopCategory.dairy);
      expect(guessCategory('Olivenöl'), ShopCategory.pantry);
      expect(guessCategory('Bananen'), ShopCategory.produce);
      expect(guessCategory('Batterien'), ShopCategory.other);
    });
  });

  group('shopping rhythm', () {
    test('weekly on Saturday: a list made on Saturday runs to Friday', () {
      const cadence = WeeklyShopping();
      expect(cadence.nextTrip(DayKey(2026, 11, 18)), _sat);
      expect(cadence.nextTrip(_sat), _sat);
      expect(cadence.periodFrom(_sat), ShoppingPeriod(_sat, _sat.addDays(6)));
      // An extra list on a Wednesday covers the days until Saturday.
      expect(cadence.periodFrom(DayKey(2026, 11, 18)), ShoppingPeriod(DayKey(2026, 11, 18), DayKey(2026, 11, 20)));
    });

    test('every few days, counted from the first trip', () {
      final cadence = EveryNDays(days: 3, anchor: DayKey(2026, 11, 16));
      expect(cadence.nextTrip(DayKey(2026, 11, 17)), DayKey(2026, 11, 19));
      expect(cadence.nextTrip(DayKey(2026, 11, 19)), DayKey(2026, 11, 19));
      expect(cadence.periodFrom(DayKey(2026, 11, 19)).lengthDays, 3);
    });

    test('without a rhythm a list covers the next days', () {
      const cadence = ManualShopping(days: 4);
      expect(cadence.nextTrip(_sat), isNull);
      expect(cadence.periodFrom(_sat).lengthDays, 4);
    });

    test('survives its JSON', () {
      for (final ShoppingCadence c in <ShoppingCadence>[
        const WeeklyShopping(weekday: DateTime.thursday),
        EveryNDays(days: 14, anchor: _sat),
        const ManualShopping(days: 5),
      ]) {
        final back = ShoppingCadence.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
        expect(back.periodFrom(_sat), c.periodFrom(_sat));
      }
    });
  });

  group('portions', () {
    test('fit each person\'s target, in quarters', () {
      // 30 % of 2600 kcal for dinner is 780 kcal, about 1.25 servings.
      expect(portionsFor(recipe: _curry(), slot: MealSlotKind.dinner, dailyKcal: 2600), 1.25);
      // 30 % of 1700 kcal is 510 kcal, 0.75 servings.
      expect(portionsFor(recipe: _curry(), slot: MealSlotKind.dinner, dailyKcal: 1700), 0.75);
      expect(portionsFor(recipe: _curry(), slot: MealSlotKind.dinner), 1);
      expect(portionsFor(recipe: _curry(), slot: MealSlotKind.dinner, dailyKcal: 9000), 2.5);
    });

    test('what someone ate as planned is their share of the recipe', () {
      final entry = _entry('a', _sat, 'curry', portions: <String, double>{'mike': 1.5});
      expect(nutrientsFor(entry, _curry(), 'mike').kcal, 960);
      expect(nutrientsFor(entry, _curry(), 'lena').kcal, 0);
      expect(nutrientsFor(_entry('b', _sat, 'curry'), _curry(), 'lena').kcal, 640);
    });

    test('a planned meal counts as eaten once, in its slot on its day', () {
      final entry = _entry('a', _sat, 'curry');
      FoodEntry line({MealSlotKind meal = MealSlotKind.dinner, FoodSource source = FoodSource.plan, String name = 'Hähnchen-Curry'}) =>
          FoodEntry(id: 'f', day: _sat, meal: meal, name: name, grams: 0, nutrients: Nutrients.zero, source: source);
      DayIntake day(List<FoodEntry> entries, {DayKey? on}) => DayIntake(day: on ?? _sat, entries: entries);

      expect(eatenAsPlanned(day(const <FoodEntry>[]), entry, _curry()), isFalse);
      expect(eatenAsPlanned(day(<FoodEntry>[line()]), entry, _curry()), isTrue);
      // Typed in by hand, in another slot, something else, another day: not this one.
      expect(eatenAsPlanned(day(<FoodEntry>[line(source: FoodSource.manual)]), entry, _curry()), isFalse);
      expect(eatenAsPlanned(day(<FoodEntry>[line(meal: MealSlotKind.lunch)]), entry, _curry()), isFalse);
      expect(eatenAsPlanned(day(<FoodEntry>[line(name: 'Dal')]), entry, _curry()), isFalse);
      expect(eatenAsPlanned(day(<FoodEntry>[line()], on: _sat.addDays(1)), entry, _curry()), isFalse);
    });
  });

  group('meal planner', () {
    final request = MealPlanRequest(
      days: <DayKey>[_sat, _sat.addDays(1)],
      slots: const <MealSlotKind>[MealSlotKind.dinner],
      people: const <PlanFor>[PlanFor(name: 'Mike', dailyKcal: 2600), PlanFor(name: 'Lena', dislikes: <String>['Fisch'])],
    );

    Map<String, dynamic> meal(String day, {String slot = 'dinner', num kcal = 640, String title = 'Curry'}) => <String, dynamic>{
          'day': day,
          'slot': slot,
          'title': title,
          'servings': 2,
          'kcal': kcal,
          'protein': 42,
          'carbs': 70,
          'fat': 18,
          'ingredients': <Map<String, dynamic>>[
            <String, dynamic>{'name': 'Reis', 'qty': 0.15, 'unit': 'kg', 'category': 'pantry'},
            <String, dynamic>{'name': 'Liebe', 'qty': 1, 'unit': 'Hauch'},
          ],
          'steps': <String>['Kochen.'],
        };

    test('keeps what holds up and converts units', () {
      final meals = parseMealPlan(
        jsonEncode(<String, dynamic>{
          'meals': <Object>[meal('2026-11-22', title: 'Sonntagscurry'), meal('2026-11-21')],
        }),
        request,
      );
      expect(meals.map((ProposedMeal m) => m.day), <DayKey>[_sat, _sat.addDays(1)]);
      final reis = meals.first.recipe.ingredients.single;
      expect(reis.quantity, const Quantity(150, QtyUnit.g));
      expect(reis.category, ShopCategory.pantry);
    });

    test('drops meals outside the plan, duplicates and broken numbers', () {
      final meals = parseMealPlan(
        'Here is your plan: ${jsonEncode(<String, dynamic>{
              'meals': <Object>[
                meal('2026-11-21'),
                meal('2026-11-21', title: 'Second dinner'),
                meal('2026-11-30'),
                meal('2026-11-22', slot: 'breakfast'),
                meal('2026-11-22', kcal: 5000),
                meal('2026-11-22', kcal: 200),
              ],
            })}',
        request,
      );
      expect(meals.single.recipe.title, 'Curry');
    });

    test('a broken first proposal for a slot leaves room for a good one', () {
      final meals = parseMealPlan(
        jsonEncode(<String, dynamic>{
          'meals': <Object>[meal('2026-11-21', kcal: 5000), meal('2026-11-21', title: 'Good')],
        }),
        request,
      );
      expect(meals.single.recipe.title, 'Good');
    });

    test('the prompt names people, targets, dislikes and the shape', () {
      final prompt = const EnglishMealPlanPrompts().proposeWeek(request);
      expect(prompt, contains('2600 kcal/day'));
      expect(prompt, contains('dislikes Fisch'));
      expect(prompt, contains('2026-11-22'));
      expect(prompt, contains(kMealPlanJson));
    });

    test('a model that answers nothing usable yields null', () async {
      final planner = MealPlanner(llm: _Llm('Sorry, I cannot help.'));
      final errors = <Object>[];
      expect(await planner.proposeWeek(request, onError: errors.add), isNull);
      // Nothing usable is not a failed call: the user hears different
      // things for the two.
      expect(errors, isEmpty);
    });

    test('a call that fails says so', () async {
      final planner = MealPlanner(llm: _Llm('', fails: true));
      final errors = <Object>[];
      expect(await planner.proposeWeek(request, onError: errors.add), isNull);
      expect(errors.single, isA<StateError>());
    });

    test('what not to repeat is what was planned last, each dish once', () {
      final recipes = <String, Recipe>{
        'curry': _curry(),
        'omelette': _omelette(),
        'dal': const Recipe(
            id: 'dal', title: 'Dal', servings: 2, ingredients: <Ingredient>[], perServing: Nutrients.zero),
      };
      final titles = recentTitles(<PlanEntry>[
        _entry('a', _sat.addDays(-20), 'dal'),
        _entry('b', _sat.addDays(-2), 'curry'),
        _entry('c', _sat.addDays(-1), 'omelette'),
        _entry('d', _sat.addDays(-9), 'curry'),
        _entry('e', _sat, 'gone'),
      ], recipes, limit: 2);
      expect(titles, <String>['Omelett', 'Hähnchen-Curry']);
    });
  });

  group('each dish once', () {
    final request = MealPlanRequest(
      days: <DayKey>[_sat, _sat.addDays(1), _sat.addDays(2)],
      slots: const <MealSlotKind>[MealSlotKind.dinner],
      people: const <PlanFor>[PlanFor(name: 'Mike')],
      plannedTitles: const <String>['Linsen-Dal'],
    );

    Map<String, dynamic> meal(String day, String title) => <String, dynamic>{
          'day': day,
          'slot': 'dinner',
          'title': title,
          'servings': 2,
          'kcal': 640,
          'protein': 42,
          'carbs': 70,
          'fat': 18,
          'ingredients': <Map<String, dynamic>>[
            <String, dynamic>{'name': 'Reis', 'qty': 150, 'unit': 'g', 'category': 'pantry'},
          ],
        };

    test('a dish already in the week or in the draft is not proposed again', () {
      final meals = parseMealPlan(
        jsonEncode(<String, dynamic>{
          'meals': <Object>[
            meal('2026-11-21', 'Curry'),
            meal('2026-11-22', '  curry '),
            meal('2026-11-23', 'linsen-dal'),
          ],
        }),
        request,
      );
      expect(meals.map((ProposedMeal m) => m.recipe.title), <String>['Curry']);
    });

    test('the prompt asks not to repeat what is planned and what was eaten', () {
      final prompt = const EnglishMealPlanPrompts().proposeWeek(MealPlanRequest(
        days: request.days,
        slots: request.slots,
        people: request.people,
        plannedTitles: const <String>['Linsen-Dal'],
        avoidTitles: const <String>['linsen-dal', 'Pizza'],
      ));
      expect(prompt, contains('Do not repeat: Linsen-Dal, Pizza.'));
    });

    test('a week is asked for in the shape of a schema', () async {
      final llm = _Llm(jsonEncode(<String, dynamic>{
        'meals': <Object>[meal('2026-11-21', 'Curry')],
      }));
      final meals = await MealPlanner(llm: llm).proposeWeek(request);
      expect(meals!.single.recipe.title, 'Curry');
      expect(llm.lastSchema, kMealPlanSchema);
    });

    test('a recipe of a known name is the known one', () {
      final known = _curry();
      expect(recipeNamed(<Recipe>[known, _omelette()], ' hähnchen-CURRY'), same(known));
      expect(recipeNamed(<Recipe>[known], 'Curry'), isNull);
      final again = Recipe(
        id: 'new',
        title: 'Hähnchen-Curry',
        servings: 4,
        ingredients: const <Ingredient>[],
        perServing: const Nutrients(kcal: 500, proteinG: 0, carbsG: 0, fatG: 0),
      );
      expect(reconcileRecipe(known, again), same(known),
          reason: 'a dish with ingredients stays as it is');
    });

    test('a dish entered by hand takes in the full recipe, under its own id', () {
      const byHand = Recipe(
        id: 'pizza',
        title: 'Pizza',
        servings: 1,
        ingredients: <Ingredient>[],
        perServing: Nutrients(kcal: 800, proteinG: 0, carbsG: 0, fatG: 0),
      );
      expect(
          reconcileRecipe(
              byHand,
              const Recipe(
                id: 'x',
                title: 'pizza',
                servings: 1,
                ingredients: <Ingredient>[],
                perServing: Nutrients.zero,
              )),
          same(byHand),
          reason: 'a name alone adds nothing');
      final full = reconcileRecipe(byHand, _curry());
      expect(full.id, 'pizza');
      expect(full.title, 'Pizza');
      expect(full.ingredients, hasLength(3));
      expect(full.perServing.kcal, 640);
    });
  });

  group('one meal drafted', () {
    Map<String, dynamic> answer(num kcal) => <String, dynamic>{
          'meals': <Object>[
            <String, dynamic>{
              'day': '2026-11-21',
              'slot': 'dinner',
              'title': 'Lasagne',
              'servings': 2,
              'kcal': kcal,
              'protein': kcal * 0.25 / 4,
              'carbs': kcal * 0.45 / 4,
              'fat': kcal * 0.30 / 9,
              'ingredients': <Map<String, dynamic>>[
                <String, dynamic>{'name': 'Lasagneplatten', 'qty': 250, 'unit': 'g', 'category': 'pantry'},
              ],
              'steps': <String>['Schichten.', 'Backen.'],
            },
          ],
        };

    MealDraftRequest request({String? title = 'Lasagne', int? kcal = 700}) =>
        MealDraftRequest(
          day: _sat,
          slot: MealSlotKind.dinner,
          people: const <PlanFor>[PlanFor(name: 'Mike', dailyKcal: 2600)],
          title: title,
          kcalPerServing: kcal,
        );

    test('turns a name and calories into a full recipe', () async {
      final llm = _Llm(jsonEncode(answer(680)));
      final meal = await MealPlanner(llm: llm).draftMeal(request());
      expect(meal!.recipe.title, 'Lasagne');
      expect(meal.recipe.ingredients.single.name, 'Lasagneplatten');
      expect(meal.day, _sat);
      expect(llm.lastPrompt, contains('"Lasagne"'));
      expect(llm.lastPrompt, contains('About 700 kcal per serving.'));
      expect(llm.lastSchema, kMealPlanSchema);
    });

    test('far off the calories asked for is not what was asked for', () async {
      final llm = _Llm(jsonEncode(answer(1200)));
      expect(await MealPlanner(llm: llm).draftMeal(request()), isNull);
      expect(await MealPlanner(llm: llm).draftMeal(request(kcal: null)), isNotNull);
    });

    test('without a name it picks something for the meal', () async {
      final llm = _Llm(jsonEncode(answer(700)));
      await MealPlanner(llm: llm).draftMeal(request(title: ' '));
      expect(llm.lastPrompt, contains('Pick a dish'));
    });
  });

  group('a list made again', () {
    test('only tops up what the open list does not hold yet', () {
      const wanted = <ShoppingItem>[
        ShoppingItem(name: 'Hähnchenbrust', category: ShopCategory.meat, quantity: Quantity(600, QtyUnit.g)),
        ShoppingItem(name: 'Reis', category: ShopCategory.pantry, quantity: Quantity(300, QtyUnit.g)),
        ShoppingItem(name: 'Zwiebeln', category: ShopCategory.produce, quantity: Quantity(2, QtyUnit.piece)),
        ShoppingItem(name: 'Milch', category: ShopCategory.dairy, quantity: Quantity(500, QtyUnit.ml)),
      ];
      final missing = stillMissing(wanted, const <ShoppingItem>[
        // Already planned once: the same amounts, one of them ticked off.
        ShoppingItem(name: 'Hähnchenbrust', category: ShopCategory.meat, quantity: Quantity(300, QtyUnit.g)),
        ShoppingItem(name: 'Reis', category: ShopCategory.pantry, quantity: Quantity(300, QtyUnit.g), checked: true),
        ShoppingItem(name: 'Zwiebel', category: ShopCategory.produce, quantity: Quantity(1, QtyUnit.piece)),
        // Typed by hand without an amount: covered.
        ShoppingItem(name: 'Milch', category: ShopCategory.dairy),
      ]);
      expect(missing.map((ShoppingItem i) => i.name), <String>['Hähnchenbrust', 'Zwiebeln']);
      expect(missing.first.quantity, const Quantity(300, QtyUnit.g));
      expect(missing.last.quantity, const Quantity(1, QtyUnit.piece));
      expect(stillMissing(wanted, wanted), isEmpty);
    });
  });
}

class _Llm implements LlmClient {
  _Llm(this.answer, {this.fails = false});

  final String answer;
  final bool fails;
  String? lastPrompt;
  Map<String, Object?>? lastSchema;

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
    lastPrompt = prompt;
    lastSchema = schema;
    if (fails) throw StateError('offline');
    return answer;
  }
}
