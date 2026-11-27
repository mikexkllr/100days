import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/household_backend.dart';
import 'package:hundred_days/ui/mealplan/household_screen.dart';
import 'package:hundred_days/ui/mealplan/shopping_view.dart';
import 'package:hundred_days/ui/mealplan/week_plan_view.dart';

import 'helpers.dart';

/// Answers every prompt with the same text and remembers what it was asked.
class _Llm implements LlmClient {
  _Llm(this.answer, {this.fails = false});

  String answer;
  bool fails;
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
    if (fails) throw StateError('SocketException: Failed host lookup');
    return answer;
  }
}

/// Salmon with beans, the way a model answers it: every ingredient, the
/// oil and the salt marked as basics, and steps to cook from.
String _salmon(DayKey day, {String title = 'Lachs mit weißen Bohnen', int kcal = 620}) =>
    jsonEncode(<String, dynamic>{
      'meals': <Object>[
        <String, dynamic>{
          'day': '$day',
          'slot': 'dinner',
          'title': title,
          'servings': 1,
          'minutes': 25,
          'kcal': kcal,
          'protein': 45,
          'carbs': 40,
          'fat': 30,
          'ingredients': <Object>[
            <String, dynamic>{'name': 'Lachsfilet', 'qty': 150, 'unit': 'g', 'category': 'fish'},
            <String, dynamic>{'name': 'Weiße Bohnen', 'qty': 240, 'unit': 'g', 'category': 'pantry'},
            <String, dynamic>{'name': 'Olivenöl', 'qty': 1, 'unit': 'tbsp', 'category': 'pantry', 'staple': true},
            <String, dynamic>{'name': 'Salz', 'qty': 0.5, 'unit': 'tsp', 'category': 'pantry', 'staple': true},
          ],
          'steps': <String>[
            'Die Bohnen abgießen und bei mittlerer Hitze 5 Minuten erwärmen.',
            'Den Lachs im Öl 3 Minuten je Seite braten und salzen.',
          ],
        },
      ],
    });

/// A dinner that is only a name: typed in by hand.
Recipe _onlyAName(String title, {double kcal = 600}) => Recipe(
      id: newEventId(),
      title: title,
      servings: 1,
      ingredients: const <Ingredient>[],
      perServing: Nutrients(kcal: kcal, proteinG: 0, carbsG: 0, fatG: 0),
    );

void main() {
  late AppRepository repository;
  late MemoryHouseholdBackend household;
  final DayKey today = DayKey.today();

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

  /// Puts [recipe] on today's dinner.
  Future<PlanEntry> plan(Recipe recipe, {DayKey? day}) async {
    final String id = await household.ensureHousehold();
    await household.saveRecipe(id, recipe);
    final PlanEntry entry = PlanEntry(
      id: newEventId(),
      day: day ?? today,
      slot: MealSlotKind.dinner,
      recipeId: recipe.id,
    );
    await household.saveEntry(id, entry);
    return entry;
  }

  Future<Recipe> stored(String recipeId) async =>
      (await household.recipes('home'))[recipeId]!;

  /// Scrolls the sheet to what [key] names: a recipe with its steps is
  /// longer than the sheet is tall.
  Future<void> show(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key, skipOffstage: false));
    await tester.pumpAndSettle();
  }

  group('the cooking level', () {
    testWidgets('is picked where the week is planned, written into the recipes and remembered',
        (WidgetTester tester) async {
      final _Llm llm = _Llm(_salmon(today));
      await pump(tester, const WeekPlanView(), llm: llm);
      await tester.tap(find.byKey(const Key('plan-week')));
      await tester.pumpAndSettle();

      // Everyday cooking until something else is picked, and what it means.
      expect(find.text('Aufwand'), findsOneWidget);
      expect(find.textContaining('Frisch gekocht'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cooking-scratch')));
      await tester.pumpAndSettle();
      expect(find.textContaining('getrocknete Bohnen'), findsOneWidget);

      await tester.tap(find.byKey(const Key('plan-propose')));
      await tester.pumpAndSettle();
      expect(llm.prompts.single, contains('Kochstufe: von Grund auf'));
      // Every prompt asks for the whole ingredient list.
      expect(llm.prompts.single, contains('Führe JEDE Zutat auf'));
      expect(llm.prompts.single, contains('"staple": true'));

      await tester.tap(find.byKey(const Key('plan-accept')));
      await tester.pumpAndSettle();
      final Recipe recipe = (await household.recipes('home')).values.single;
      expect(recipe.level, CookingLevel.scratch);
      expect(recipe.ingredients.where((Ingredient i) => i.staple).map((Ingredient i) => i.name),
          <String>['Olivenöl', 'Salz']);
      // The next plan starts from it.
      expect((await household.household('home')).member(repository.userId)!.cooking,
          CookingLevel.scratch);
      await tester.tap(find.byKey(const Key('plan-week')));
      await tester.pumpAndSettle();
      expect(
          tester.widget<ChoiceChip>(find.byKey(const Key('cooking-scratch'))).selected,
          isTrue);
    });

    testWidgets('is picked where one meal is planned, too', (WidgetTester tester) async {
      // Monday's dinner: the first empty slot of the week in view. Without
      // a diary there is nothing to log, so the sheet plans.
      final _Llm llm = _Llm(_salmon(today.weekStart));
      await pump(tester, const WeekPlanView(), llm: llm);
      await tester.tap(find.text('Noch nichts geplant').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('add-meal-title')), 'Lachs mit weißen Bohnen');
      await tester.tap(find.byKey(const Key('cooking-convenience')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-meal-save')));
      await tester.pumpAndSettle();

      expect(llm.prompts.single, contains('Kochstufe: schnell und fertig'));
      expect((await household.recipes('home')).values.single.level,
          CookingLevel.convenience);
    });

    testWidgets('is each member\'s own, set where their tastes are', (WidgetTester tester) async {
      await household.ensureHousehold();
      await pump(tester, const HouseholdScreen());
      await tester.ensureVisible(find.byKey(const Key('cooking-convenience')));
      await tester.tap(find.byKey(const Key('cooking-convenience')));
      await tester.pumpAndSettle();
      expect(find.text('Für den Haushalt gespeichert.'), findsOneWidget);
      final HouseholdMember me =
          (await household.household('home')).member(repository.userId)!;
      expect(me.cooking, CookingLevel.convenience);
      expect(me.preferencesJson()['cooking'], 'convenience');
    });
  });

  group('a recipe', () {
    testWidgets('shows what to buy, the basics apart, and how to cook it',
        (WidgetTester tester) async {
      final Recipe recipe = parseMealPlan(
        _salmon(today),
        MealPlanRequest(
          days: <DayKey>[today],
          slots: const <MealSlotKind>[MealSlotKind.dinner],
          people: const <PlanFor>[],
          level: CookingLevel.convenience,
        ),
      ).single.recipe;
      await plan(recipe);
      await pump(tester, const WeekPlanView());
      await tester.tap(find.text('Lachs mit weißen Bohnen'));
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.byKey(const Key('recipe-meta'))).data,
          allOf(contains('25 Min.'), contains('Bequem')));
      expect(find.text('BASICS AUS DEM VORRAT'), findsOneWidget);
      // The basics come after what is bought, with their amounts.
      expect(tester.getTopLeft(find.text('Olivenöl')).dy,
          greaterThan(tester.getTopLeft(find.text('BASICS AUS DEM VORRAT')).dy));
      expect(tester.getTopLeft(find.text('Lachsfilet')).dy,
          lessThan(tester.getTopLeft(find.text('BASICS AUS DEM VORRAT')).dy));
      expect(find.text('1 EL'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.textContaining('3 Minuten je Seite'), findsOneWidget);
      // Without a model there is nothing to write it again with.
      expect(find.byKey(const Key('recipe-write')), findsNothing);
    });

    testWidgets('of a meal that is only a name is written on a tap, and taken back',
        (WidgetTester tester) async {
      final Recipe pizza = _onlyAName('Lachs vom Blech');
      final PlanEntry entry = await plan(pizza);
      final _Llm llm = _Llm(_salmon(today, title: 'Ofenlachs nach Art des Hauses'));
      await pump(tester, const WeekPlanView(), llm: llm);

      // The week says which meals have nothing to cook from.
      expect(find.text('noch kein Rezept'), findsOneWidget);
      await tester.tap(find.text('Lachs vom Blech'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recipe-not-written')), findsOneWidget);
      expect(find.text('Funki schreibt das Rezept'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cooking-scratch')));
      await tester.pumpAndSettle();
      await show(tester, const Key('recipe-write'));
      await tester.tap(find.byKey(const Key('recipe-write')));
      await tester.pumpAndSettle();

      // Asked for under its name, near its calories, at the level picked.
      expect(llm.prompts.single, contains('„Lachs vom Blech“'));
      expect(llm.prompts.single, contains('Etwa 600 kcal pro Portion.'));
      expect(llm.prompts.single, contains('Kochstufe: von Grund auf'));
      // The dish keeps its name and its place; the sheet shows the recipe.
      Recipe now = await stored(pizza.id);
      expect(now.title, 'Lachs vom Blech');
      expect(now.level, CookingLevel.scratch);
      expect(now.ingredients, hasLength(4));
      expect((await household.plan('home', today, today)).single.id, entry.id);
      expect(find.byKey(const Key('recipe-not-written')), findsNothing);
      expect(find.text('Lachsfilet'), findsOneWidget);
      expect(find.text('Rezept: Lachs vom Blech · Von Grund auf'), findsOneWidget);
      expect(find.text('noch kein Rezept'), findsNothing);

      // The way back is in the sheet: it stays open over the recipe.
      await show(tester, const Key('recipe-undo'));
      await tester.tap(find.byKey(const Key('recipe-undo')));
      await tester.pumpAndSettle();
      now = await stored(pizza.id);
      expect(now.isWritten, isFalse);
      expect(now.level, isNull);
      expect(find.byKey(const Key('recipe-not-written')), findsOneWidget);
      expect(find.byKey(const Key('recipe-undo')), findsNothing);
    });

    testWidgets('can be written again at another level', (WidgetTester tester) async {
      final Recipe canned = parseMealPlan(
        _salmon(today),
        MealPlanRequest(
          days: <DayKey>[today],
          slots: const <MealSlotKind>[MealSlotKind.dinner],
          people: const <PlanFor>[],
          level: CookingLevel.convenience,
        ),
      ).single.recipe;
      await plan(canned);
      final _Llm llm = _Llm(jsonEncode(<String, dynamic>{
        'meals': <Object>[
          <String, dynamic>{
            ...(jsonDecode(_salmon(today)) as Map<String, dynamic>)['meals'][0] as Map<String, dynamic>,
            'minutes': 90,
            'ingredients': <Object>[
              <String, dynamic>{'name': 'Wildlachs, ganze Seite', 'qty': 400, 'unit': 'g', 'category': 'fish'},
              <String, dynamic>{'name': 'Getrocknete weiße Bohnen', 'qty': 100, 'unit': 'g', 'category': 'pantry'},
            ],
          },
        ],
      }));
      await pump(tester, const WeekPlanView(), llm: llm);
      await tester.tap(find.text('Lachs mit weißen Bohnen'));
      await tester.pumpAndSettle();

      // Under the steps: the same recipe at another level. The chips start
      // on the one it has.
      await show(tester, const Key('recipe-write'));
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('cooking-convenience'))).selected, isTrue);
      expect(find.text('Rezept neu schreiben'), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('cooking-scratch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recipe-write')));
      await tester.pumpAndSettle();

      final Recipe now = await stored(canned.id);
      expect(now.level, CookingLevel.scratch);
      expect(now.minutes, 90);
      expect(now.ingredients.map((Ingredient i) => i.name),
          <String>['Wildlachs, ganze Seite', 'Getrocknete weiße Bohnen']);
      expect(find.text('Wildlachs, ganze Seite'), findsOneWidget);
      // Scrolled out at the top by now, and changed all the same.
      expect(
          tester
              .widget<Text>(
                  find.byKey(const Key('recipe-meta'), skipOffstage: false))
              .data,
          contains('Von Grund auf'));
    });

    testWidgets('that does not add up leaves the meal as it was and says so',
        (WidgetTester tester) async {
      final Recipe pizza = _onlyAName('Pizza');
      await plan(pizza);
      // Twice the calories the meal has: not this dish.
      final _Llm llm = _Llm(_salmon(today, kcal: 1300));
      await pump(tester, const WeekPlanView(), llm: llm);
      await tester.tap(find.text('Pizza'));
      await tester.pumpAndSettle();
      await show(tester, const Key('recipe-write'));
      await tester.tap(find.byKey(const Key('recipe-write')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recipe-write-problem')), findsOneWidget);
      expect(find.textContaining('kein Rezept hinbekommen'), findsOneWidget);
      expect((await stored(pizza.id)).isWritten, isFalse);

      // Offline says so instead.
      llm.fails = true;
      await tester.tap(find.byKey(const Key('recipe-write')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Die KI war nicht erreichbar'), findsOneWidget);
    });
  });

  group('the shopping list', () {
    Future<void> shopFor(int days) async => household.updateHousehold(
        await household.ensureHousehold(),
        cadence: ManualShopping(days: days));

    testWidgets('names the basics once, without an amount, to check at home',
        (WidgetTester tester) async {
      await shopFor(7);
      for (int i = 0; i < 2; i++) {
        final Recipe recipe = parseMealPlan(
          _salmon(today.addDays(i), title: 'Lachs $i'),
          MealPlanRequest(
            days: <DayKey>[today.addDays(i)],
            slots: const <MealSlotKind>[MealSlotKind.dinner],
            people: const <PlanFor>[],
          ),
        ).single.recipe;
        await plan(recipe, day: today.addDays(i));
      }
      await pump(tester, const ShoppingView());
      await tester.tap(find.byKey(const Key('list-from-plan')));
      await tester.pumpAndSettle();

      // Bought with its amount, added up over both dinners.
      expect(find.text('Lachsfilet'), findsOneWidget);
      expect(find.text('300 g'), findsOneWidget);
      // The oil of two recipes is one line, and no two tablespoons to buy.
      expect(find.text('BASICS'), findsOneWidget);
      expect(find.byKey(const Key('shop-staples-hint')), findsOneWidget);
      expect(find.text('Olivenöl'), findsOneWidget);
      expect(find.text('Salz'), findsOneWidget);
      expect(find.text('2 EL'), findsNothing);
      final List<ShoppingLine> lines = await household.items(
          (await household.openLists('home')).single.id);
      final ShoppingLine oil = lines.firstWhere((ShoppingLine l) => l.name == 'Olivenöl');
      expect(oil.category, ShopCategory.staples);
      expect(oil.quantity, isNull);
      // After the aisles: the last section.
      expect(tester.getTopLeft(find.text('BASICS')).dy,
          greaterThan(tester.getTopLeft(find.text('VORRAT')).dy));

    });

    testWidgets('leaves the basics the household always has at home off it',
        (WidgetTester tester) async {
      await shopFor(7);
      await household.updateHousehold('home', pantry: <String>['Salz']);
      await plan(parseMealPlan(
        _salmon(today),
        MealPlanRequest(
          days: <DayKey>[today],
          slots: const <MealSlotKind>[MealSlotKind.dinner],
          people: const <PlanFor>[],
        ),
      ).single.recipe);
      await pump(tester, const ShoppingView());
      await tester.tap(find.byKey(const Key('list-from-plan')));
      await tester.pumpAndSettle();
      expect(find.text('Olivenöl'), findsOneWidget);
      expect(find.text('Salz'), findsNothing);
    });

    testWidgets('says which planned meals it cannot know, and has their recipes written',
        (WidgetTester tester) async {
      await shopFor(7);
      final Recipe pizza = _onlyAName('Lachs vom Blech');
      await plan(pizza);
      // Next week's is not this trip's.
      await plan(_onlyAName('Eintopf'), day: today.addDays(9));
      final _Llm llm = _Llm(_salmon(today));
      await pump(tester, const ShoppingView(), llm: llm);

      expect(find.byKey(const Key('shop-no-recipe')), findsOneWidget);
      expect(
          find.text('Ein geplantes Gericht hat noch kein Rezept und fehlt auf '
              'der Liste: Lachs vom Blech'),
          findsOneWidget);

      // A list is open already: the recipes written, it gets what they need.
      await tester.tap(find.byKey(const Key('list-extra')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shop-write-recipes')));
      await tester.pumpAndSettle();
      expect(find.text('Rezepte für die Liste'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cooking-convenience')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('write-recipes-go')));
      await tester.pumpAndSettle();

      expect(llm.prompts.single, contains('Kochstufe: schnell und fertig'));
      final Recipe now = await stored(pizza.id);
      expect(now.isWritten, isTrue);
      expect(now.level, CookingLevel.convenience);
      expect(find.text('1 Rezept geschrieben'), findsOneWidget);
      expect(find.byKey(const Key('shop-no-recipe')), findsNothing);
      // On the list now, the basics included.
      expect(find.text('Lachsfilet'), findsOneWidget);
      expect(find.text('BASICS'), findsOneWidget);
    });

    testWidgets('without a model still says what is missing', (WidgetTester tester) async {
      await shopFor(7);
      await plan(_onlyAName('Pizza'));
      await pump(tester, const ShoppingView());
      expect(find.byKey(const Key('shop-no-recipe')), findsOneWidget);
      expect(find.byKey(const Key('shop-write-recipes')), findsNothing);
    });

    testWidgets('a recipe that could not be written keeps the sheet open with the reason',
        (WidgetTester tester) async {
      await shopFor(7);
      final Recipe pizza = _onlyAName('Pizza');
      await plan(pizza);
      final _Llm llm = _Llm('', fails: true);
      await pump(tester, const ShoppingView(), llm: llm);
      await tester.tap(find.byKey(const Key('shop-write-recipes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('write-recipes-go')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('write-recipes-problem')), findsOneWidget);
      expect(find.textContaining('Die KI war nicht erreichbar'), findsOneWidget);
      expect((await stored(pizza.id)).isWritten, isFalse);

      // Back online, the same button finishes the job.
      llm
        ..fails = false
        ..answer = _salmon(today);
      await tester.tap(find.byKey(const Key('write-recipes-go')));
      await tester.pumpAndSettle();
      expect(find.text('Rezepte für die Liste'), findsNothing);
      expect((await stored(pizza.id)).isWritten, isTrue);
    });
  });
}
