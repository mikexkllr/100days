import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/household_backend.dart';
import 'package:hundred_days/ui/mealplan/household_screen.dart';
import 'package:hundred_days/ui/mealplan/recipe_sheet.dart';
import 'package:hundred_days/ui/mealplan/shopping_view.dart';
import 'package:hundred_days/ui/mealplan/week_plan_view.dart';
import 'package:hundred_days/ui/nutrition/add_food_screen.dart';

import 'helpers.dart';

/// Answers every prompt with the same text — or, offline, with nothing.
class _Llm implements LlmClient {
  _Llm(this.answer, {this.fails = false});

  final String answer;
  final bool fails;
  String? lastPrompt;

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
  }) async {
    lastPrompt = prompt;
    if (fails) throw StateError('SocketException: Failed host lookup');
    return answer;
  }
}

Recipe _curry() => Recipe(
      id: newEventId(),
      title: 'Hähnchen-Curry',
      servings: 2,
      perServing: const Nutrients(kcal: 640, proteinG: 42, carbsG: 70, fatG: 18),
      ingredients: const <Ingredient>[
        Ingredient(name: 'Hähnchenbrust', quantity: Quantity(300, QtyUnit.g), category: ShopCategory.meat),
        Ingredient(name: 'Reis', quantity: Quantity(150, QtyUnit.g), category: ShopCategory.pantry),
      ],
    );

void main() {
  late AppRepository repository;
  late MemoryHouseholdBackend household;

  setUp(() async {
    repository = await testRepository();
    household = MemoryHouseholdBackend(userId: repository.userId, displayName: 'Mike');
    await repository.startChallenge(testChallenge());
  });

  Future<void> pump(WidgetTester tester, Widget child, {LlmClient? llm}) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrapForTest(
      repository: repository,
      child: child,
      household: household,
      llm: llm ?? const UnavailableLlmClient(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the week shows planned meals and offers dinner everywhere',
      (WidgetTester tester) async {
    final String id = await household.ensureHousehold();
    final Recipe curry = await household.saveRecipe(id, _curry());
    await household.saveEntry(id, PlanEntry(
      id: newEventId(),
      day: DayKey.today(),
      slot: MealSlotKind.dinner,
      recipeId: curry.id,
    ));
    await pump(tester, const WeekPlanView());

    expect(find.text('Hähnchen-Curry'), findsOneWidget);
    expect(find.text('Noch nichts geplant'), findsNWidgets(6));
    // Without a model, planning with the AI says why it is off.
    expect(tester.widget<FilledButton>(find.ancestor(
            of: find.text('Woche planen'), matching: find.byType(FilledButton))).onPressed,
        isNull);
  });

  testWidgets('planning the week takes the checked proposal into the plan',
      (WidgetTester tester) async {
    final DayKey monday = DayKey.today().weekStart;
    final DayKey day = DayKey.today();
    final _Llm llm = _Llm(jsonEncode(<String, dynamic>{
      'meals': <Object>[
        <String, dynamic>{
          'day': day.toString(),
          'slot': 'dinner',
          'title': 'Linsen-Dal',
          'servings': 2,
          'minutes': 25,
          'kcal': 520,
          'protein': 24,
          'carbs': 70,
          'fat': 14,
          'ingredients': <Object>[
            <String, dynamic>{'name': 'rote Linsen', 'qty': 200, 'unit': 'g', 'category': 'pantry'},
          ],
          'steps': <String>['Kochen.'],
        },
      ],
    }));
    await pump(tester, const WeekPlanView(), llm: llm);

    await tester.tap(find.byKey(const Key('plan-week')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('plan-wish')), 'kein Fisch');
    await tester.tap(find.byKey(const Key('plan-propose')));
    await tester.pumpAndSettle();
    expect(find.text('Linsen-Dal'), findsOneWidget);
    expect(llm.lastPrompt, contains('kein Fisch'));
    expect(llm.lastPrompt, contains('Mike'));

    await tester.tap(find.byKey(const Key('plan-accept')));
    await tester.pumpAndSettle();

    final List<PlanEntry> plan =
        await household.plan('home', monday, monday.addDays(6));
    expect(plan.single.day, day);
    expect(plan.single.portions[repository.userId], 1);
  });

  testWidgets('a list from the plan adds up the week, ticked off live',
      (WidgetTester tester) async {
    final String id = await household.ensureHousehold();
    final Recipe curry = await household.saveRecipe(id, _curry());
    for (int i = 0; i < 2; i++) {
      await household.saveEntry(id, PlanEntry(
        id: newEventId(),
        day: DayKey.today().addDays(i),
        slot: MealSlotKind.dinner,
        recipeId: curry.id,
      ));
    }
    await household.updateHousehold(id, cadence: const ManualShopping(days: 7));
    await pump(tester, const ShoppingView());

    await tester.tap(find.byKey(const Key('list-from-plan')));
    await tester.pumpAndSettle();

    // Two curries for a household of one: 300 g chicken.
    expect(find.text('Hähnchenbrust'), findsOneWidget);
    expect(find.text('300 g'), findsOneWidget);
    expect(find.text('FLEISCH & WURST'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('shop-add')), 'Milch');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('MILCH & EIER'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shop-item-Milch')));
    await tester.pumpAndSettle();
    final List<ShoppingListInfo> lists = await household.openLists(id);
    final List<ShoppingLine> lines = await household.items(lists.single.id);
    expect(lines.firstWhere((ShoppingLine l) => l.name == 'Milch').checked, isTrue);
  });

  testWidgets('finishing a list moves what is left to the next one',
      (WidgetTester tester) async {
    final String id = await household.ensureHousehold();
    final ShoppingListInfo list = await household.createList(
        id, ShoppingPeriod(DayKey.today(), DayKey.today()));
    await household.addItems(id, list.id, const <ShoppingItem>[
      ShoppingItem(name: 'Kaffee', category: ShopCategory.drinks),
    ]);
    await pump(tester, const ShoppingView());

    await tester.tap(find.byKey(const Key('shop-finish')));
    await tester.pumpAndSettle();

    final List<ShoppingListInfo> open = await household.openLists(id);
    expect(open.single.id, isNot(list.id));
    expect((await household.items(open.single.id)).single.name, 'Kaffee');
  });

  testWidgets('eaten as planned puts my portion into the diary, once',
      (WidgetTester tester) async {
    await repository.startChallenge(_dietChallenge());
    final String id = await household.ensureHousehold();
    final Recipe curry = await household.saveRecipe(id, _curry());
    final PlanEntry entry = PlanEntry(
      id: newEventId(),
      day: DayKey.today(),
      slot: MealSlotKind.dinner,
      recipeId: curry.id,
      portions: <String, double>{repository.userId: 1.5},
    );
    await household.saveEntry(id, entry);
    await pump(tester, Builder(builder: (BuildContext context) {
      return Consumer(builder: (BuildContext context, WidgetRef ref, _) {
        return TextButton(
          onPressed: () => showRecipeSheet(context, ref, entry, curry),
          child: const Text('open'),
        );
      });
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eaten-as-planned')));
    await tester.pumpAndSettle();

    final FoodEntry logged =
        (await repository.snapshot()).me.intakeOn(DayKey.today()).entries.single;
    expect(logged.name, 'Hähnchen-Curry');
    expect(logged.nutrients.kcal, 960);
    expect(logged.source, FoodSource.plan);

    // Opened again, it says so instead of offering a second helping.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('eaten-as-planned')), findsNothing);
    expect(find.text('IM TAGEBUCH'), findsOneWidget);
  });

  testWidgets('without a diary, or for a day to come, nothing is logged',
      (WidgetTester tester) async {
    final String id = await household.ensureHousehold();
    final Recipe curry = await household.saveRecipe(id, _curry());
    PlanEntry on(DayKey day) => PlanEntry(
          id: newEventId(),
          day: day,
          slot: MealSlotKind.dinner,
          recipeId: curry.id,
        );
    PlanEntry entry = on(DayKey.today());
    await pump(tester, Consumer(
        builder: (BuildContext context, WidgetRef ref, _) => TextButton(
              onPressed: () => showRecipeSheet(context, ref, entry, curry),
              child: const Text('open'),
            )));

    // No nutrition plan: there is no diary to put it in.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Zutaten für 2'), findsOneWidget);
    expect(find.byKey(const Key('eaten-as-planned')), findsNothing);
    Navigator.of(tester.element(find.text('Zutaten für 2'))).pop();
    await tester.pumpAndSettle();

    // With one, tomorrow's dinner is not eaten yet.
    await repository.startChallenge(_dietChallenge());
    entry = on(DayKey.today().addDays(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('eaten-as-planned')), findsNothing);
  });

  testWidgets('a meal idea goes into the plan in one tap',
      (WidgetTester tester) async {
    await pump(tester, const WeekPlanView());

    await tester.tap(find.text('Noch nichts geplant').first);
    await tester.pumpAndSettle();
    expect(find.text('IDEEN'), findsOneWidget);
    final MealIdea idea =
        kMealIdeas.firstWhere((MealIdea i) => i.slot == MealSlotKind.dinner);
    await tester.tap(find.byKey(Key('meal-idea-${idea.id}')));
    await tester.pumpAndSettle();

    final String id = await household.ensureHousehold();
    final DayKey monday = DayKey.today().weekStart;
    final PlanEntry planned =
        (await household.plan(id, monday, monday.addDays(6))).single;
    final Recipe recipe = (await household.recipes(id))[planned.recipeId]!;
    expect(planned.slot, MealSlotKind.dinner);
    expect(recipe.perServing.kcal, idea.kcal);
    expect(recipe.perServing.proteinG, idea.proteinG);
    expect(find.text(recipe.title), findsOneWidget);
  });

  testWidgets('calories typed with a decimal comma count',
      (WidgetTester tester) async {
    await pump(tester, const WeekPlanView());
    await tester.tap(find.text('Noch nichts geplant').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('add-meal-title')), 'Pizza');
    await tester.enterText(find.byKey(const Key('add-meal-kcal')), '650,5');
    await tester.tap(find.byKey(const Key('add-meal-save')));
    await tester.pumpAndSettle();

    final Recipe recipe = (await household.recipes('home')).values.single;
    expect(recipe.perServing.kcal, 650.5);
  });

  testWidgets('on a phone with the keyboard up, save is in reach',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrapForTest(
      repository: repository,
      child: const WeekPlanView(),
      household: household,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Noch nichts geplant').first);
    await tester.pumpAndSettle();
    // The title field asks for the keyboard; it takes half the screen.
    tester.view.viewInsets = const FakeViewPadding(bottom: 340 * 3);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('add-meal-title')), 'Pizza');
    await tester.pump();

    final Rect save = tester.getRect(find.byKey(const Key('add-meal-save')));
    expect(save.bottom, lessThanOrEqualTo(852 - 340));
    await tester.tap(find.byKey(const Key('add-meal-save')));
    await tester.pumpAndSettle();

    // No calories typed: they are optional, the meal is planned anyway.
    final Recipe recipe = (await household.recipes('home')).values.single;
    expect(recipe.title, 'Pizza');
    expect(recipe.perServing.kcal, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a save without a name says so instead of closing',
      (WidgetTester tester) async {
    await pump(tester, const WeekPlanView());
    await tester.tap(find.text('Noch nichts geplant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-meal-save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Gib der Mahlzeit einen Namen'), findsOneWidget);
    expect(find.byKey(const Key('add-meal-title')), findsOneWidget);
    expect(await household.recipes('home'), isEmpty);
  });

  testWidgets('a meal already eaten leads into the diary, onto the photo',
      (WidgetTester tester) async {
    await repository.startChallenge(_dietChallenge());
    await pump(tester, const WeekPlanView());
    // Monday has come, whatever today is.
    await tester.tap(find.text('Noch nichts geplant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-meal-to-diary')));
    await tester.pumpAndSettle();

    final AddFoodScreen screen =
        tester.widget<AddFoodScreen>(find.byType(AddFoodScreen));
    expect(screen.day, DayKey.today().weekStart);
    expect(screen.meal, MealSlotKind.dinner);
    // Without a model the photo tab says what it needs.
    expect(find.text('Ein Foto von deinem Teller'), findsOneWidget);
  });

  testWidgets('a day to come, or no diary, offers no way into it',
      (WidgetTester tester) async {
    await pump(tester, const WeekPlanView());
    await tester.tap(find.text('Noch nichts geplant').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-meal-to-diary')), findsNothing);
  });

  Map<String, dynamic> dal(DayKey day, {String title = 'Linsen-Dal'}) =>
      <String, dynamic>{
        'day': day.toString(),
        'slot': 'dinner',
        'title': title,
        'servings': 1,
        'kcal': 520,
        'protein': 24,
        'carbs': 70,
        'fat': 14,
        'ingredients': <Object>[
          <String, dynamic>{'name': 'rote Linsen', 'qty': 200, 'unit': 'g', 'category': 'pantry'},
        ],
      };

  Future<void> planWeek(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('plan-week')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-propose')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-accept')));
    await tester.pumpAndSettle();
  }

  testWidgets('planning the same week twice replaces each meal, not doubles it',
      (WidgetTester tester) async {
    final DayKey day = DayKey.today();
    final DayKey monday = day.weekStart;
    await pump(tester, const WeekPlanView(),
        llm: _Llm(jsonEncode(<String, dynamic>{'meals': <Object>[dal(day)]})));
    await planWeek(tester);
    await planWeek(tester);

    final List<PlanEntry> plan =
        await household.plan('home', monday, monday.addDays(6));
    expect(plan.single.day, day);
    expect(plan.single.slot, MealSlotKind.dinner);
  });

  testWidgets('a save that fails keeps the draft and says so',
      (WidgetTester tester) async {
    household = _FlakyHousehold(userId: repository.userId, displayName: 'Mike')
      ..failSaves = true;
    await pump(tester, const WeekPlanView(),
        llm: _Llm(jsonEncode(<String, dynamic>{'meals': <Object>[dal(DayKey.today())]})));
    await planWeek(tester);

    // No endless spinner: the draft is still there, with the reason.
    expect(find.text('Linsen-Dal'), findsOneWidget);
    expect(find.text('Der Plan konnte nicht gespeichert werden. Dein Entwurf '
        'ist noch da — versuch es noch einmal.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('plan-accept'))).onPressed,
        isNotNull);

    // The retry goes through.
    (household as _FlakyHousehold).failSaves = false;
    await tester.tap(find.byKey(const Key('plan-accept')));
    await tester.pumpAndSettle();
    final DayKey monday = DayKey.today().weekStart;
    expect(await household.plan('home', monday, monday.addDays(6)), hasLength(1));
  });

  testWidgets('offline, planning says so instead of "no usable plan"',
      (WidgetTester tester) async {
    await pump(tester, const WeekPlanView(), llm: _Llm('', fails: true));
    await tester.tap(find.byKey(const Key('plan-week')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-propose')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Die KI war nicht erreichbar'), findsOneWidget);
    expect(find.textContaining('kein brauchbarer Plan'), findsNothing);
  });

  testWidgets('what not to repeat is the most recently planned',
      (WidgetTester tester) async {
    final String id = await household.ensureHousehold();
    final DayKey monday = DayKey.today().weekStart;
    for (int i = 0; i < 25; i++) {
      final Recipe r = await household.saveRecipe(id, Recipe(
        id: 'r$i',
        title: 'Gericht $i',
        servings: 1,
        ingredients: const <Ingredient>[],
        perServing: Nutrients.zero,
      ));
      await household.saveEntry(id, PlanEntry(
        id: 'e$i',
        day: monday.addDays(-25 + i),
        slot: MealSlotKind.dinner,
        recipeId: r.id,
      ));
    }
    final _Llm llm = _Llm('{}');
    await pump(tester, const WeekPlanView(), llm: llm);
    await tester.tap(find.byKey(const Key('plan-week')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-propose')));
    await tester.pumpAndSettle();

    expect(llm.lastPrompt, contains('Gericht 24'));
    expect(llm.lastPrompt, isNot(contains('Gericht 0,')));
  });

  testWidgets('taking a meal off the plan can be undone',
      (WidgetTester tester) async {
    final String id = await household.ensureHousehold();
    final Recipe curry = await household.saveRecipe(id, _curry());
    final PlanEntry entry = PlanEntry(
      id: 'dinner-today',
      day: DayKey.today(),
      slot: MealSlotKind.dinner,
      recipeId: curry.id,
    );
    await household.saveEntry(id, entry);
    await pump(tester, const WeekPlanView());

    await tester.tap(find.text('Hähnchen-Curry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recipe-remove')));
    await tester.pumpAndSettle();
    expect(find.text('Hähnchen-Curry'), findsNothing);
    expect(find.text('Hähnchen-Curry aus dem Plan genommen'), findsOneWidget);

    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    final DayKey monday = DayKey.today().weekStart;
    expect((await household.plan(id, monday, monday.addDays(6))).single.id,
        'dinner-today');
    expect(find.text('Hähnchen-Curry'), findsOneWidget);
  });

  group('the shopping list', () {
    Future<ShoppingListInfo> listWith(List<String> names) async {
      final String id = await household.ensureHousehold();
      final ShoppingListInfo list = await household.createList(
          id, ShoppingPeriod(DayKey.today(), DayKey.today().addDays(6)));
      await household.addItems(id, list.id, <ShoppingItem>[
        for (final String name in names)
          ShoppingItem(name: name, category: guessCategory(name)),
      ]);
      return list;
    }

    bool ticked(WidgetTester tester, String name) => tester
        .widget<CheckboxListTile>(find.byKey(Key('shop-item-$name')))
        .value!;

    testWidgets('a tick shows at once and moves back when it fails',
        (WidgetTester tester) async {
      final _FlakyHousehold flaky =
          _FlakyHousehold(userId: repository.userId, displayName: 'Mike');
      household = flaky;
      await listWith(<String>['Milch']);
      await pump(tester, const ShoppingView());

      final Completer<void> reply = Completer<void>();
      flaky.checkReply = reply;
      await tester.tap(find.byKey(const Key('shop-item-Milch')));
      await tester.pump();
      // No connection yet: the box has moved all the same.
      expect(ticked(tester, 'Milch'), isTrue);

      reply.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(ticked(tester, 'Milch'), isFalse);
      expect(find.text('Nicht gespeichert — prüf deine Verbindung und versuch '
          'es noch einmal.'), findsOneWidget);
    });

    testWidgets('a swiped line goes at once and can be put back',
        (WidgetTester tester) async {
      final ShoppingListInfo list = await listWith(<String>['Kaffee', 'Milch']);
      await pump(tester, const ShoppingView());

      await tester.drag(find.byKey(const Key('shop-item-Kaffee')), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shop-item-Kaffee')), findsNothing);
      expect((await household.items(list.id)).map((ShoppingLine l) => l.name),
          <String>['Milch']);

      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shop-item-Kaffee')), findsOneWidget);
      expect((await household.items(list.id)).map((ShoppingLine l) => l.name).toSet(),
          <String>{'Kaffee', 'Milch'});
    });

    testWidgets('a typed line that fails to save comes back into the field',
        (WidgetTester tester) async {
      final _FlakyHousehold flaky =
          _FlakyHousehold(userId: repository.userId, displayName: 'Mike');
      household = flaky;
      await listWith(<String>['Kaffee']);
      await pump(tester, const ShoppingView());

      flaky.failSaves = true;
      await tester.enterText(find.byKey(const Key('shop-add')), 'Butter');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shop-item-Butter')), findsNothing);
      expect(find.widgetWithText(TextField, 'Butter'), findsOneWidget);
    });

    testWidgets('an empty list can be closed', (WidgetTester tester) async {
      await listWith(const <String>[]);
      await pump(tester, const ShoppingView());

      await tester.tap(find.text('Liste schließen'));
      await tester.pumpAndSettle();
      expect(await household.openLists('home'), isEmpty);
      expect(find.text('Liste schließen'), findsNothing);
    });

    testWidgets('a list from the plan made twice tops up the open one',
        (WidgetTester tester) async {
      final String id = await household.ensureHousehold();
      final Recipe curry = await household.saveRecipe(id, _curry());
      await household.saveEntry(id, PlanEntry(
        id: 'a',
        day: DayKey.today(),
        slot: MealSlotKind.dinner,
        recipeId: curry.id,
      ));
      await household.updateHousehold(id, cadence: const ManualShopping(days: 7));
      await pump(tester, const ShoppingView());

      await tester.tap(find.byKey(const Key('list-from-plan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('list-from-plan')));
      await tester.pumpAndSettle();
      expect(find.text('Auf der offenen Liste steht schon alles für diese Tage'),
          findsOneWidget);

      // Planned more since: only that is added.
      await household.saveEntry(id, PlanEntry(
        id: 'b',
        day: DayKey.today().addDays(1),
        slot: MealSlotKind.dinner,
        recipeId: curry.id,
      ));
      await tester.tap(find.byKey(const Key('list-from-plan')));
      await tester.pumpAndSettle();

      final List<ShoppingListInfo> open = await household.openLists(id);
      expect(open, hasLength(1));
      final List<ShoppingLine> chicken = (await household.items(open.single.id))
          .where((ShoppingLine l) => l.name == 'Hähnchenbrust')
          .toList();
      expect(chicken.fold(0.0, (double sum, ShoppingLine l) => sum + l.quantity!.amount),
          300);
    });

    testWidgets('a realtime tick keeps the list and the typed line',
        (WidgetTester tester) async {
      await listWith(<String>['Kaffee']);
      await pump(tester, const ShoppingView());
      await tester.enterText(find.byKey(const Key('shop-add')), 'Hafer');

      // Someone else changes something: the list reloads.
      await household.updateHousehold('home', name: 'WG');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('shop-item-Kaffee')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Hafer'), findsOneWidget);
    });

    testWidgets('a household that failed to load offers to try again',
        (WidgetTester tester) async {
      final _FlakyHousehold flaky =
          _FlakyHousehold(userId: repository.userId, displayName: 'Mike')
            ..failStart = true;
      household = flaky;
      await pump(tester, const ShoppingView());
      expect(find.text('Der Haushalt konnte nicht geladen werden.'), findsOneWidget);

      flaky.failStart = false;
      await tester.tap(find.byKey(const Key('household-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('list-from-plan')), findsOneWidget);
    });
  });

  group('the household', () {
    const HouseholdMember lena =
        HouseholdMember(userId: 'lena', displayName: 'Lena', emoji: '🦊');

    /// The screen scrolls; what is tapped is brought into view first.
    Future<void> tapShown(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(key));
    }

    testWidgets('a shopping day shows at once and says it is saved',
        (WidgetTester tester) async {
      await household.ensureHousehold();
      await pump(tester, const HouseholdScreen());

      await tapShown(tester, const Key('cadence-weekday-1'));
      await tester.pumpAndSettle();
      expect(find.text('Jeden Montag'), findsOneWidget);
      expect(find.text('Für den Haushalt gespeichert.'), findsOneWidget);
      expect((await household.household('home')).cadence,
          isA<WeeklyShopping>().having((WeeklyShopping c) => c.weekday, 'weekday', 1));
    });

    testWidgets('the pantry saves with a button that lights up when changed',
        (WidgetTester tester) async {
      await household.ensureHousehold();
      await pump(tester, const HouseholdScreen());
      FilledButton save() =>
          tester.widget<FilledButton>(find.byKey(const Key('household-save-pantry')));
      expect(save().onPressed, isNull);

      await tester.enterText(find.byKey(const Key('household-pantry')), 'Salz, Öl');
      await tester.pump();
      expect(save().onPressed, isNotNull);
      await tapShown(tester, const Key('household-save-pantry'));
      await tester.pumpAndSettle();
      expect((await household.household('home')).pantry, <String>['Salz', 'Öl']);
      expect(find.text('Für den Haushalt gespeichert.'), findsOneWidget);
      expect(save().onPressed, isNull);
    });

    testWidgets('unsaved text survives someone else\'s change',
        (WidgetTester tester) async {
      await household.ensureHousehold();
      await pump(tester, const HouseholdScreen());
      await tester.enterText(find.byKey(const Key('household-pantry')), 'Reis');

      household.addMember(lena);
      await tester.pumpAndSettle();
      expect(find.text('Lena'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Reis'), findsOneWidget);
    });

    testWidgets('removing a member asks first', (WidgetTester tester) async {
      await household.ensureHousehold();
      household.addMember(lena);
      await pump(tester, const HouseholdScreen());

      await tester.tap(find.byKey(const Key('household-remove-lena')));
      await tester.pumpAndSettle();
      expect(find.text('Lena aus dem Haushalt entfernen?'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect((await household.household('home')).members, hasLength(2));

      await tester.tap(find.byKey(const Key('household-remove-lena')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('household-remove-confirm')));
      await tester.pumpAndSettle();
      expect((await household.household('home')).members, hasLength(1));
      expect(find.text('Lena'), findsNothing);
    });

    testWidgets('a household with others can be left, after asking',
        (WidgetTester tester) async {
      await household.ensureHousehold();
      household.addMember(lena);
      await pump(tester, const HouseholdScreen());

      await tapShown(tester, const Key('household-leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('household-leave-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Du hast den Haushalt verlassen.'), findsOneWidget);
      expect(find.text('Lena'), findsNothing);
      // Alone again there is nothing to leave.
      expect(find.byKey(const Key('household-leave')), findsNothing);
    });

    testWidgets('joining another household warns while sharing this one',
        (WidgetTester tester) async {
      final _InviteHousehold invited =
          _InviteHousehold(userId: repository.userId, displayName: 'Mike');
      household = invited;
      await invited.ensureHousehold();
      invited.addMember(lena);
      await pump(tester, Consumer(
          builder: (BuildContext context, WidgetRef ref, _) => TextButton(
                onPressed: () => joinHouseholdFlow(context, ref, 'ABCD2345'),
                child: const Text('join'),
              )));

      await tester.tap(find.text('join'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('household-join-warning')), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(invited.joined, isFalse);
    });

    testWidgets('the shared target follows the nutrition plan',
        (WidgetTester tester) async {
      await repository.startChallenge(_dietChallenge());
      final String id = await household.ensureHousehold();
      final HouseholdMember me = (await household.household(id)).members.single;
      // Shared once, when the target was different.
      await household.updateMembership(
          id, me.withTargets(share: true, kcal: 1200, protein: 60));
      await pump(tester, const HouseholdScreen());

      final NutritionPlan plan = (await repository.snapshot()).plan!.nutrition!;
      final HouseholdMember now = (await household.household(id)).members.single;
      expect(now.kcalTarget, plan.kcal);
      expect(now.proteinG, plan.proteinG);
    });
  });
}

/// A household with an invite waiting.
class _InviteHousehold extends MemoryHouseholdBackend {
  _InviteHousehold({super.userId, super.displayName});

  bool joined = false;

  @override
  Future<HouseholdInvitePreview?> previewInvite(String code) async =>
      const HouseholdInvitePreview(
          householdId: 'elsewhere', name: 'WG', memberNames: <String>['Tom']);

  @override
  Future<String> join(String code) async {
    joined = true;
    return 'elsewhere';
  }
}

/// A household that can be made to fail or wait: the network a shop has.
class _FlakyHousehold extends MemoryHouseholdBackend {
  _FlakyHousehold({super.userId, super.displayName});

  bool failSaves = false;
  bool failStart = false;
  Completer<void>? checkReply;

  @override
  Future<String> ensureHousehold() async {
    if (failStart) throw StateError('offline');
    return super.ensureHousehold();
  }

  @override
  Future<void> saveEntry(String householdId, PlanEntry entry) async {
    if (failSaves) throw StateError('offline');
    await super.saveEntry(householdId, entry);
  }

  @override
  Future<List<ShoppingLine>> addItems(
      String householdId, String listId, List<ShoppingItem> items) async {
    if (failSaves) throw StateError('offline');
    return super.addItems(householdId, listId, items);
  }

  @override
  Future<void> setChecked(String itemId, {required bool checked}) async {
    final Completer<void>? reply = checkReply;
    if (reply != null) {
      checkReply = null;
      await reply.future;
    }
    await super.setChecked(itemId, checked: checked);
  }
}

/// A challenge with the nutrition plan on, so there is a diary.
Challenge _dietChallenge() => Challenge(
      id: 'diet',
      goal: const Goal(
        archetype: GoalArchetype.loseFat,
        statement: 'Leichter werden',
        body: BodyProfile(
          sex: BiologicalSex.male,
          ageYears: 34,
          heightCm: 182,
          weightKg: 88,
          activityLevel: ActivityLevel.moderate,
        ),
        nutritionPlanEnabled: true,
      ),
      habits: <Habit>[Habit.fromCategory(HabitCategory.nutrition)],
      startDay: DayKey.today(),
    );
