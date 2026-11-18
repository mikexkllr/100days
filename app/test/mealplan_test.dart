import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/household_backend.dart';
import 'package:hundred_days/ui/mealplan/recipe_sheet.dart';
import 'package:hundred_days/ui/mealplan/shopping_view.dart';
import 'package:hundred_days/ui/mealplan/week_plan_view.dart';

import 'helpers.dart';

/// Answers every prompt with the same text.
class _Llm implements LlmClient {
  _Llm(this.answer);

  final String answer;
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
