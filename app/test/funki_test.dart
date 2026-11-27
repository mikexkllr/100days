import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/ai/funki/funki.dart';
import 'package:hundred_days/ai/funki/funki_tools.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/household_backend.dart';
import 'package:hundred_days/ui/funki/funki_sheet.dart';
import 'package:hundred_days/ui/funki/funki_widgets.dart';
import 'package:hundred_days/ui/mealplan/week_plan_view.dart';
import 'package:hundred_days/ui/nutrition/diary_view.dart';

import 'helpers.dart';

/// One answer of the script: the tools Funki calls, in order, and what he
/// says afterwards — or the failure instead.
class _Step {
  const _Step(this.answer, {this.calls = const <(String, Map<String, dynamic>)>[], this.fails});

  final String answer;
  final List<(String, Map<String, dynamic>)> calls;
  final Object? fails;
}

/// Funki's brain with the model taken out: it calls the real tools the way
/// the model would and remembers what it was given.
class _ScriptedBrain implements FunkiBrain {
  _ScriptedBrain(this.steps);

  final List<_Step> steps;
  final List<List<ChatMessage>> histories = <List<ChatMessage>>[];
  final List<String> results = <String>[];
  final List<String> toolNames = <String>[];

  @override
  Future<({String output, List<ChatMessage> messages})> reply(
    String text, {
    required List<ChatMessage> history,
    required List<Tool> tools,
  }) async {
    histories.add(history);
    toolNames
      ..clear()
      ..addAll(tools.map((Tool t) => t.name));
    final _Step step = steps.removeAt(0);
    if (step.fails != null) throw step.fails!;
    for (final (String name, Map<String, dynamic> args) in step.calls) {
      final Tool tool = tools.firstWhere((Tool t) => t.name == name);
      results.add('${await tool.call(args)}');
    }
    return (
      output: step.answer,
      messages: <ChatMessage>[ChatMessage.user(text), ChatMessage.model(step.answer)],
    );
  }
}

const BodyProfile _body = BodyProfile(
  sex: BiologicalSex.female,
  ageYears: 29,
  heightCm: 170,
  weightKg: 66,
  activityLevel: ActivityLevel.moderate,
);

Challenge _challenge() => Challenge(
      id: 'funki',
      goal: const Goal(
        archetype: GoalArchetype.loseFat,
        statement: 'Leichter werden',
        body: _body,
        nutritionPlanEnabled: true,
      ),
      habits: <Habit>[
        Habit.fromCategory(HabitCategory.nutrition),
        Habit.fromCategory(HabitCategory.reading),
      ],
      startDay: DayKey.today().addDays(-3),
    );

void main() {
  late AppRepository repository;
  late MemoryHouseholdBackend household;

  setUp(() async {
    repository = await testRepository();
    household = MemoryHouseholdBackend(userId: repository.userId, displayName: 'Mike');
    await repository.startChallenge(_challenge());
  });

  Future<void> pump(WidgetTester tester, Widget child, _ScriptedBrain? brain,
      {LlmClient llm = const UnavailableLlmClient()}) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrapForTest(
      repository: repository,
      child: child,
      household: household,
      llm: llm,
      overrides: <Override>[funkiBrainProvider.overrideWithValue(brain)],
    ));
    await tester.pumpAndSettle();
  }

  /// The card of a change Funki made, by its words, and its way back.
  Future<void> undo(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
      matching: find.text('Rückgängig'),
    ));
    await tester.pumpAndSettle();
  }

  /// Funki's sheet, opened from [opener] unless it is up already, and a
  /// question put to him there.
  Future<void> ask(WidgetTester tester, String text,
      {Key opener = const Key('funki-ask')}) async {
    if (find.byKey(const Key('funki-input')).evaluate().isEmpty) {
      await tester.tap(find.byKey(opener));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byKey(const Key('funki-input')), text);
    await tester.tap(find.byKey(const Key('funki-send')));
    await tester.pump();
    // A tool that loads the household first waits on more than this frame:
    // until Funki has answered.
    for (int i = 0;
        i < 200 && find.byType(FunkiThinking).evaluate().isNotEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  /// "Ask Funki" as it stands on a screen.
  Widget askButton() => Center(
        child: FunkiAskButton(
          key: const Key('funki-ask'),
          focus: FunkiFocus.home(DayKey.today()),
        ),
      );

  testWidgets('in the diary, what was eaten goes in with its numbers, and back out',
      (WidgetTester tester) async {
    final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
      const _Step('Zwei Brezeln sind drin, 440 kcal.', calls: <(String, Map<String, dynamic>)>[
        ('log_food', <String, dynamic>{
          'slot': 'breakfast',
          'foods': <Map<String, dynamic>>[
            <String, dynamic>{'name': 'Brezel', 'grams': 160, 'kcal': 440, 'protein': 12, 'carbs': 88, 'fat': 4},
            // More energy than the grams can hold: not written.
            <String, dynamic>{'name': 'Butter', 'grams': 5, 'kcal': 900, 'protein': 0, 'carbs': 0, 'fat': 100},
          ],
        }),
      ]),
    ]);
    await pump(tester, const DiaryScreen(), brain);

    await ask(tester, '2 Brezeln zum Frühstück', opener: const Key('funki-bar'));

    expect(find.text('Zwei Brezeln sind drin, 440 kcal.'), findsOneWidget);
    expect(find.text('Tagebuch, Frühstück: Brezel · 440 kcal'), findsOneWidget);
    expect(brain.results.single, contains('rejected'));
    AppSnapshot s = await repository.snapshot();
    final List<FoodEntry> logged = s.me.intakeOn(DayKey.today()).entries;
    expect(logged.single.name, 'Brezel');
    expect(logged.single.source, FoodSource.ai);
    expect(logged.single.meal, MealSlotKind.breakfast);
    // The system prompt says where Funki was opened and which day is meant.
    expect(brain.histories.single.first.text, contains('Ernährungstagebuch vom ${DayKey.today()}'));

    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    s = await repository.snapshot();
    expect(s.me.intakeOn(DayKey.today()).entries, isEmpty);
  });

  testWidgets('a habit is checked off on the word, and the tick can be taken back',
      (WidgetTester tester) async {
    final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
      const _Step('Stark, Lesen ist abgehakt.', calls: <(String, Map<String, dynamic>)>[
        ('check_in', <String, dynamic>{'habit_id': 'reading'}),
      ]),
      const _Step('Schon erledigt.', calls: <(String, Map<String, dynamic>)>[
        ('check_in', <String, dynamic>{'habit_id': 'reading'}),
      ]),
    ]);
    await pump(tester, askButton(), brain);

    await ask(tester, 'Hab heute gelesen');
    AppSnapshot s = await repository.snapshot();
    expect(s.me.logsByDay[DayKey.today().toString()]?.entryFor('reading'), isNotNull);
    expect(find.text('Abgehakt: Lesen'), findsOneWidget);

    // Asked again, he does not tick it twice.
    await ask(tester, 'Und nochmal gelesen');
    expect(brain.results.last, contains('already done'));
    // The history carries the first exchange into the second.
    expect(brain.histories.last.map((ChatMessage m) => m.text), contains('Hab heute gelesen'));
  });

  testWidgets('the tick is undone from the card', (WidgetTester tester) async {
    final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
      const _Step('', calls: <(String, Map<String, dynamic>)>[
        ('check_in', <String, dynamic>{'habit_id': 'reading'}),
      ]),
    ]);
    await pump(tester, askButton(), brain);
    await ask(tester, 'gelesen');
    // An answer that is only a change still says something.
    expect(find.text('Erledigt.'), findsOneWidget);

    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    final AppSnapshot s = await repository.snapshot();
    expect(s.me.logsByDay[DayKey.today().toString()]?.entryFor('reading'), isNull);
  });

  testWidgets('an allowance used up says so and offers the way on',
      (WidgetTester tester) async {
    final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
      _Step('', fails: Exception('402 quota_exceeded')),
    ]);
    await pump(tester, askButton(), brain);
    await ask(tester, 'Wie läuft es?');
    expect(find.textContaining('KI-Kontingent'), findsOneWidget);
    expect(find.byKey(const Key('funki-paywall')), findsOneWidget);
  });

  testWidgets('closed and opened again, the conversation goes on — until it is started over',
      (WidgetTester tester) async {
    final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
      const _Step('Heute fehlt noch Lesen.', calls: <(String, Map<String, dynamic>)>[
        ('get_today', <String, dynamic>{}),
      ]),
      const _Step('Gern.'),
    ]);
    await pump(tester, askButton(), brain);
    await ask(tester, 'Was fehlt noch?');
    expect(brain.results.single, contains('"required_today":true'));
    expect(find.byType(FunkiSheet), findsOneWidget);

    await tester.tap(find.byKey(const Key('funki-close')));
    await tester.pumpAndSettle();
    expect(find.byType(FunkiSheet), findsNothing);

    await tester.tap(find.byKey(const Key('funki-ask')));
    await tester.pumpAndSettle();
    expect(find.text('Was fehlt noch?'), findsOneWidget);
    expect(find.text('Heute fehlt noch Lesen.'), findsOneWidget);

    await ask(tester, 'Danke');
    expect(find.text('Gern.'), findsOneWidget);
    expect(brain.histories.last.length, greaterThan(2));

    await tester.tap(find.byKey(const Key('funki-new')));
    await tester.pumpAndSettle();
    expect(find.text('Was fehlt noch?'), findsNothing);
    expect(find.text('Gern.'), findsNothing);
  });

  testWidgets('from the plan, Funki plans a meal — the dish the household knows',
      (WidgetTester tester) async {
    final String id = await household.ensureHousehold();
    final Recipe dal = await household.saveRecipe(id, const Recipe(
      id: 'dal',
      title: 'Linsen-Dal',
      servings: 2,
      perServing: Nutrients(kcal: 520, proteinG: 24, carbsG: 70, fatG: 14),
      ingredients: <Ingredient>[
        Ingredient(name: 'rote Linsen', quantity: Quantity(200, QtyUnit.g), category: ShopCategory.pantry),
      ],
    ));
    final DayKey day = DayKey.today();
    final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
      _Step('Dal steht drin.', calls: <(String, Map<String, dynamic>)>[
        ('set_meal', <String, dynamic>{
          'day': day.toString(),
          'slot': 'dinner',
          'title': 'linsen-dal',
          'servings': 2,
          'kcal': 500,
          'protein': 24,
          'carbs': 66,
          'fat': 14,
          'ingredients': <Map<String, dynamic>>[
            <String, dynamic>{'name': 'Linsen', 'qty': 200, 'unit': 'g', 'category': 'pantry'},
          ],
        }),
      ]),
    ]);
    // The week plan needs a model to offer Funki at all.
    await tester.pumpWidget(const SizedBox());
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrapForTest(
      repository: repository,
      household: household,
      llm: const _ReadyLlm(),
      overrides: <Override>[funkiBrainProvider.overrideWithValue(brain)],
      child: const WeekPlanView(),
    ));
    await tester.pumpAndSettle();

    await ask(tester, 'Heute Dal', opener: const Key('plan-chat'));
    expect(find.byType(FunkiSheet), findsOneWidget);

    final List<PlanEntry> plan = await household.plan(id, day, day);
    expect(plan.single.recipeId, dal.id, reason: 'one recipe per name');
    expect((await household.recipes(id)).length, 1);
    expect(brain.toolNames, containsAll(<String>['log_food', 'check_in', 'set_meal', 'get_training']));
  });

  group('the meal plan and its recipes', () {
    final DayKey today = DayKey.today();

    /// A dinner that is only a name, on [day].
    Future<Recipe> planName(String title, DayKey day) async {
      final String id = await household.ensureHousehold();
      final Recipe recipe = await household.saveRecipe(id, Recipe(
        id: newEventId(),
        title: title,
        servings: 1,
        ingredients: const <Ingredient>[],
        perServing: const Nutrients(kcal: 600, proteinG: 0, carbsG: 0, fatG: 0),
      ));
      await household.saveEntry(id, PlanEntry(
        id: newEventId(),
        day: day,
        slot: MealSlotKind.dinner,
        recipeId: recipe.id,
      ));
      return recipe;
    }

    testWidgets('a week is planned at the level asked for, and taken back in one',
        (WidgetTester tester) async {
      final _PlannerLlm llm = _PlannerLlm((String prompt) => _salmon(<DayKey>[
            for (final DayKey day in <DayKey>[today, today.addDays(1)])
              if (prompt.contains('- $day')) day,
          ]));
      final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
        _Step('Zwei Abendessen stehen.', calls: <(String, Map<String, dynamic>)>[
          ('plan_week', <String, dynamic>{
            'days': <String>['$today', '${today.addDays(1)}'],
            'complexity': 'scratch',
            'wish': 'viel Fisch',
          }),
        ]),
      ]);
      await pump(tester, askButton(), brain, llm: llm);
      await ask(tester, 'Plane heute und morgen, alles selbst gemacht, viel Fisch');

      expect(llm.prompts.single, contains('Kochstufe: von Grund auf'));
      expect(llm.prompts.single, contains('viel Fisch'));
      List<PlanEntry> plan = await household.plan('home', today, today.addDays(1));
      expect(plan, hasLength(2));
      final Map<String, Recipe> recipes = await household.recipes('home');
      expect(recipes.values.every((Recipe r) => r.level == CookingLevel.scratch), isTrue);
      expect(recipes.values.first.ingredients.any((Ingredient i) => i.staple), isTrue);
      // The conversation holds the names, not the recipes.
      expect(brain.results.single, contains('"title":"Lachs $today"'));
      expect(brain.results.single, isNot(contains('Lachsfilet')));

      await undo(tester, '2 Mahlzeiten geplant · Von Grund auf');
      plan = await household.plan('home', today, today.addDays(1));
      expect(plan, isEmpty);
    });

    testWidgets('without a level named, the user\'s own is the one', (WidgetTester tester) async {
      final String id = await household.ensureHousehold();
      await household.updateMembership(
          id,
          (await household.household(id))
              .member(repository.userId)!
              .withTastes(cooking: CookingLevel.convenience));
      final _PlannerLlm llm = _PlannerLlm((String _) => _salmon(<DayKey>[today]));
      final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
        _Step('', calls: <(String, Map<String, dynamic>)>[
          ('get_meal_plan', <String, dynamic>{}),
          ('plan_week', <String, dynamic>{'days': <String>['$today']}),
        ]),
      ]);
      await pump(tester, askButton(), brain, llm: llm);
      await ask(tester, 'Plane heute');

      expect(brain.results.first, contains('"my_cooking_level":"convenience"'));
      expect(llm.prompts.single, contains('Kochstufe: schnell und fertig'));
      expect(find.text('Eine Mahlzeit geplant · Bequem'), findsOneWidget);
    });

    testWidgets('the recipe of a planned meal is written, and written again',
        (WidgetTester tester) async {
      final Recipe pizza = await planName('Lachs vom Blech', today);
      final _PlannerLlm llm = _PlannerLlm((String _) => _salmon(<DayKey>[today]));
      final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
        _Step('Das Rezept steht.', calls: <(String, Map<String, dynamic>)>[
          ('get_recipe', <String, dynamic>{'day': '$today', 'slot': 'dinner'}),
          ('write_recipe', <String, dynamic>{'day': '$today', 'slot': 'dinner', 'complexity': 'convenience'}),
          ('get_recipe', <String, dynamic>{'day': '$today', 'slot': 'dinner'}),
        ]),
        _Step('Jetzt von Grund auf.', calls: <(String, Map<String, dynamic>)>[
          ('write_recipe', <String, dynamic>{'day': '$today', 'slot': 'dinner', 'complexity': 'scratch'}),
        ]),
        _Step('Da steht nichts.', calls: <(String, Map<String, dynamic>)>[
          ('write_recipe', <String, dynamic>{'day': '${today.addDays(3)}', 'slot': 'dinner'}),
        ]),
      ]);
      await pump(tester, askButton(), brain, llm: llm);
      await ask(tester, 'Schreib das Rezept für heute Abend, schnell und einfach');

      // Only a name before, a recipe with its basics marked after.
      expect(brain.results[0], contains('"has_recipe":false'));
      expect(brain.results[1], contains('"complexity":"convenience"'));
      expect(brain.results[2], contains('1 EL Olivenöl (kitchen basic)'));
      expect(llm.prompts.single, contains('„Lachs vom Blech“'));
      Recipe now = (await household.recipes('home'))[pizza.id]!;
      expect(now.title, 'Lachs vom Blech');
      expect(now.level, CookingLevel.convenience);
      expect(find.text('Rezept: Lachs vom Blech · Bequem'), findsOneWidget);

      await ask(tester, 'Doch lieber alles selbst gemacht');
      now = (await household.recipes('home'))[pizza.id]!;
      expect(now.level, CookingLevel.scratch);
      // Back to the first writing, not to the bare name.
      await undo(tester, 'Rezept: Lachs vom Blech · Von Grund auf');
      now = (await household.recipes('home'))[pizza.id]!;
      expect(now.level, CookingLevel.convenience);
      expect(now.isWritten, isTrue);

      await ask(tester, 'Und Montag?');
      expect(brain.results.last, 'Nothing is planned there.');
    });

    testWidgets('a meal moves to another day; one that was there takes its place',
        (WidgetTester tester) async {
      final Recipe a = await planName('Pizza', today);
      final Recipe b = await planName('Suppe', today.addDays(1));
      final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
        _Step('Getauscht.', calls: <(String, Map<String, dynamic>)>[
          ('move_meal', <String, dynamic>{
            'from_day': '$today',
            'from_slot': 'dinner',
            'to_day': '${today.addDays(1)}',
          }),
        ]),
      ]);
      await pump(tester, askButton(), brain);
      await ask(tester, 'Pizza lieber morgen');

      Future<Map<String, String>> byDay() async => <String, String>{
            for (final PlanEntry e in await household.plan('home', today, today.addDays(1)))
              '${e.day}': e.recipeId,
          };
      expect(await byDay(), <String, String>{'$today': b.id, '${today.addDays(1)}': a.id});
      expect(brain.results.single, contains('what was there is on $today'));
      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      expect(await byDay(), <String, String>{'$today': a.id, '${today.addDays(1)}': b.id});
    });
  });

  group('the shopping list', () {
    final DayKey today = DayKey.today();

    testWidgets('takes amounts, ticks, and what is always at home',
        (WidgetTester tester) async {
      final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
        const _Step('Steht drauf.', calls: <(String, Map<String, dynamic>)>[
          ('add_to_list', <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Hackfleisch', 'qty': 0.5, 'unit': 'kg'},
              <String, dynamic>{'name': 'Salz'},
              <String, dynamic>{'name': 'Milch'},
            ],
          }),
        ]),
        const _Step('Abgehakt.', calls: <(String, Map<String, dynamic>)>[
          ('tick_list_items', <String, dynamic>{'names': <String>['milch', 'Butter']}),
        ]),
        const _Step('Merke ich mir.', calls: <(String, Map<String, dynamic>)>[
          ('set_pantry', <String, dynamic>{'add': <String>['Salz', 'Öl']}),
          ('get_shopping_list', <String, dynamic>{}),
        ]),
      ]);
      await pump(tester, askButton(), brain);
      await ask(tester, '500 g Hack, Salz und Milch auf die Liste');

      final String listId = (await household.openLists('home')).single.id;
      Future<Map<String, ShoppingLine>> lines() async => <String, ShoppingLine>{
            for (final ShoppingLine l in await household.items(listId)) l.name: l,
          };
      expect((await lines())['Hackfleisch']!.quantity, const Quantity(500, QtyUnit.g));
      expect((await lines())['Hackfleisch']!.category, ShopCategory.meat);
      expect(find.text('Auf der Liste: 500 g Hackfleisch'), findsOneWidget);
      expect(find.text('Auf der Liste: Milch'), findsOneWidget);

      await ask(tester, 'Milch hab ich');
      expect((await lines())['Milch']!.checked, isTrue);
      expect(brain.results.last, contains('Not on the list, or already ticked: Butter'));
      expect(find.text('Im Korb: milch'), findsOneWidget);

      // Always at home: off this list, and off every list to come.
      await ask(tester, 'Salz und Öl haben wir immer');
      expect((await household.household('home')).pantry, <String>['Salz', 'Öl']);
      expect((await lines()).keys, isNot(contains('Salz')));
      expect(brain.results.last, contains('"always_at_home":["Salz","Öl"]'));
      await undo(tester, 'Immer zuhause: Salz, Öl');
      expect((await household.household('home')).pantry, isEmpty);
      expect((await lines()).keys, contains('Salz'));
    });

    testWidgets('made from the plan, says which meals it could not shop for',
        (WidgetTester tester) async {
      final String id = await household.ensureHousehold();
      await household.updateHousehold(id, cadence: const ManualShopping(days: 7));
      final Recipe salmon = parseMealPlan(
        _salmon(<DayKey>[today]),
        MealPlanRequest(
          days: <DayKey>[today],
          slots: const <MealSlotKind>[MealSlotKind.dinner],
          people: const <PlanFor>[],
        ),
      ).single.recipe;
      await household.saveRecipe(id, salmon);
      await household.saveRecipe(id, const Recipe(
        id: 'pizza',
        title: 'Pizza',
        servings: 1,
        ingredients: <Ingredient>[],
        perServing: Nutrients(kcal: 800, proteinG: 0, carbsG: 0, fatG: 0),
      ));
      for (final (int i, String recipe) in <(int, String)>[(0, salmon.id), (1, 'pizza')]) {
        await household.saveEntry(id, PlanEntry(
          id: newEventId(),
          day: today.addDays(i),
          slot: MealSlotKind.dinner,
          recipeId: recipe,
        ));
      }
      final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
        const _Step('Liste steht, für die Pizza fehlt das Rezept.', calls: <(String, Map<String, dynamic>)>[
          ('make_list_from_plan', <String, dynamic>{}),
          ('get_shopping_list', <String, dynamic>{}),
        ]),
      ]);
      await pump(tester, askButton(), brain);
      await ask(tester, 'Mach die Einkaufsliste');

      final Map<String, dynamic> made = jsonDecode(brain.results.first) as Map<String, dynamic>;
      expect(made['result'], contains('4 lines'));
      expect(made['kitchen_basics'], contains('2 of them are basics'));
      expect(made['meals_without_recipe'], <Object>[
        <String, dynamic>{'day': '${today.addDays(1)}', 'slot': 'dinner', 'title': 'Pizza'},
      ]);
      final Map<String, dynamic> list = jsonDecode(brain.results.last) as Map<String, dynamic>;
      final List<Map<String, dynamic>> lines =
          (list['lines'] as List<dynamic>).cast<Map<String, dynamic>>();
      final Map<String, dynamic> oil =
          lines.firstWhere((Map<String, dynamic> l) => l['name'] == 'Olivenöl');
      expect(oil['section'], contains('kitchen basics'));
      expect(oil.containsKey('amount'), isFalse);
      expect(lines.firstWhere((Map<String, dynamic> l) => l['name'] == 'Lachsfilet')['amount'], '150 g');
    });

    testWidgets('tastes are the user\'s own, and every plan after respects them',
        (WidgetTester tester) async {
      final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
        const _Step('Gemerkt.', calls: <(String, Map<String, dynamic>)>[
          ('set_food_preferences', <String, dynamic>{
            'diet': 'vegetarisch',
            'dislikes': <String>['Rosenkohl'],
            'complexity': 'scratch',
          }),
          ('get_meal_plan', <String, dynamic>{}),
        ]),
      ]);
      await pump(tester, askButton(), brain);
      await ask(tester, 'Ich esse vegetarisch, mag keinen Rosenkohl und koche alles selbst');

      HouseholdMember me = (await household.household('home')).member(repository.userId)!;
      expect(me.diet, 'vegetarisch');
      expect(me.dislikes, <String>['Rosenkohl']);
      expect(me.allergies, isEmpty);
      expect(me.cooking, CookingLevel.scratch);
      expect(brain.results.last, contains('"my_cooking_level":"scratch"'));
      expect(brain.results.last, contains('"dislikes":["Rosenkohl"]'));

      await undo(tester, 'Deine Essensvorlieben geändert');
      me = (await household.household('home')).member(repository.userId)!;
      expect(me.diet, anyOf(isNull, isEmpty));
      expect(me.cooking, isNull);
    });
  });

  group('the training plan', () {
    Future<TrainingSetup> setup() async {
      final Goal goal = (await repository.snapshot()).challenge!.goal;
      return goal.training ?? suggestTrainingSetup(goal);
    }

    setUp(() async {
      repository = await testRepository();
      household = MemoryHouseholdBackend(userId: repository.userId, displayName: 'Mike');
      await repository.startChallenge(_gymChallenge());
    });

    testWidgets('is read, and an exercise swapped for one the tools named',
        (WidgetTester tester) async {
      final TrainingSetup before = await setup();
      final ExerciseSlot first = before.sessions.first.exercises.first;
      final Exercise other = alternativesFor(first.exerciseId, EquipmentAccess.fullGym).first;
      final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
        _Step('Getauscht.', calls: <(String, Map<String, dynamic>)>[
          ('get_training_plan', <String, dynamic>{}),
          ('find_exercises', <String, dynamic>{'like': first.exerciseId}),
          ('change_exercise', <String, dynamic>{'session': 1, 'position': 1, 'exercise_id': other.id, 'sets': 5}),
        ]),
        const _Step('Das geht nicht.', calls: <(String, Map<String, dynamic>)>[
          ('change_exercise', <String, dynamic>{'session': 1, 'position': 1, 'exercise_id': 'handstand_on_mars'}),
          ('change_exercise', <String, dynamic>{'session': 9, 'position': 1, 'sets': 2}),
          ('find_exercises', <String, dynamic>{}),
        ]),
      ]);
      await pump(tester, askButton(), brain);
      await ask(tester, 'Tausch die erste Übung');

      final Map<String, dynamic> plan = jsonDecode(brain.results[0]) as Map<String, dynamic>;
      expect(plan['days_per_week'], 3);
      expect((plan['sessions'] as List<dynamic>).length, before.sessions.length);
      expect(((plan['sessions'] as List<dynamic>).first as Map<String, dynamic>)['exercises'][0]['id'],
          first.exerciseId);
      expect(brain.results[1], contains('"id":"${other.id}"'));

      TrainingSetup now = await setup();
      expect(now.sessions.first.exercises.first.exerciseId, other.id);
      expect(now.sessions.first.exercises.first.sets, 5);
      // Everything else as it was.
      expect(now.sessions.first.exercises.skip(1), before.sessions.first.exercises.skip(1));
      expect(now.sessions.skip(1), before.sessions.skip(1));

      // Nothing the library does not have, and nowhere that is not there.
      await ask(tester, 'Und jetzt Handstand auf dem Mars');
      expect(brain.results[3], contains('No exercise with the id "handstand_on_mars"'));
      expect(brain.results[4], contains('No such session'));
      expect(brain.results[5], contains('Give a muscle'));
      expect(await setup(), now);

      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      now = await setup();
      expect(now, before);
    });

    testWidgets('gets an exercise more, one less — but never an empty session',
        (WidgetTester tester) async {
      final TrainingSetup before = await setup();
      final SessionPlan session = before.sessions.first;
      final Exercise extra = exercisesByMuscle(EquipmentAccess.fullGym)[MuscleGroup.calves]!
          .firstWhere((Exercise e) => session.exercises.every((ExerciseSlot s) => s.exerciseId != e.id));
      final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
        _Step('Drin.', calls: <(String, Map<String, dynamic>)>[
          ('find_exercises', <String, dynamic>{'muscle': 'calves'}),
          ('add_exercise', <String, dynamic>{'session': 1, 'exercise_id': extra.id, 'sets': 2}),
          ('add_exercise', <String, dynamic>{'session': 1, 'exercise_id': extra.id}),
        ]),
        _Step('Raus.', calls: <(String, Map<String, dynamic>)>[
          for (int i = 0; i <= session.exercises.length; i++)
            ('remove_exercise', <String, dynamic>{'session': 1, 'position': 1}),
        ]),
      ]);
      await pump(tester, askButton(), brain);
      await ask(tester, 'Noch Waden dazu');

      expect(brain.results[0], contains('"id":"${extra.id}"'));
      TrainingSetup now = await setup();
      expect(now.sessions.first.exercises.last.exerciseId, extra.id);
      expect(now.sessions.first.exercises.last.sets, 2);
      expect(now.sessions.first.exercises, hasLength(session.exercises.length + 1));
      expect(brain.results[2], contains('is in that session already'));

      await ask(tester, 'Nimm alles raus');
      now = await setup();
      // The last one stays: a session with nothing in it cannot be trained.
      expect(now.sessions.first.exercises.single.exerciseId, extra.id);
      expect(brain.results.last, contains('cannot be empty'));
    });

    testWidgets('trains more days on another split, and the habit follows',
        (WidgetTester tester) async {
      final TrainingSetup before = await setup();
      final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
        const _Step('Vier Tage, Ober-/Unterkörper.', calls: <(String, Map<String, dynamic>)>[
          ('set_training_days', <String, dynamic>{'days_per_week': 4, 'split': 'upperLower'}),
          ('set_training_days', <String, dynamic>{'days_per_week': 9}),
        ]),
      ]);
      await pump(tester, askButton(), brain);
      await ask(tester, 'Ich will viermal die Woche, Ober- und Unterkörper');

      Challenge challenge = (await repository.snapshot()).challenge!;
      expect(challenge.goal.trainingDaysPerWeek, 4);
      expect(challenge.goal.training!.split, SplitKind.upperLower);
      expect(scheduledWeekdays(trainingHabitOf(challenge.habits)!, DayKey.today()), hasLength(4));
      expect(brain.results.last, 'Between 2 and 6 days a week.');
      expect(find.text('Training: Oberkörper / Unterkörper, 4× pro Woche'), findsOneWidget);

      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      challenge = (await repository.snapshot()).challenge!;
      expect(challenge.goal.trainingDaysPerWeek, 3);
      expect(challenge.goal.training, before);
      expect(scheduledWeekdays(trainingHabitOf(challenge.habits)!, DayKey.today()), hasLength(3));
      // With a plan, everything that changes it is there.
      expect(brain.toolNames, containsAll(<String>[
        'get_training_plan', 'find_exercises', 'change_exercise',
        'add_exercise', 'remove_exercise', 'set_training_days',
      ]));
    });

    testWidgets('without a plan its tools are not even declared, and Funki can say why',
        (WidgetTester tester) async {
      repository = await testRepository();
      await repository.startChallenge(_challenge());
      final _ScriptedBrain brain = _ScriptedBrain(<_Step>[
        const _Step('Du hast keinen Trainingsplan.', calls: <(String, Map<String, dynamic>)>[
          ('get_training', <String, dynamic>{}),
        ]),
      ]);
      await pump(tester, askButton(), brain);
      await ask(tester, 'Viermal die Woche');
      expect(brain.results.single, contains('"has_training_plan":false'));
      // Declarations are sent with every message: none for what is not there.
      expect(brain.toolNames, isNot(contains('get_training_plan')));
      expect(brain.toolNames, isNot(contains('set_training_days')));
    });
  });

  testWidgets('Funki is asked from the shopping list and the training plan, and knows where he is',
      (WidgetTester tester) async {
    final _ScriptedBrain brain = _ScriptedBrain(<_Step>[const _Step('Gern.')]);
    await pump(
      tester,
      Center(
        child: FunkiAskButton(
          key: const Key('funki-ask'),
          focus: FunkiFocus.shopping(DayKey.today()),
        ),
      ),
      brain,
    );
    await tester.tap(find.byKey(const Key('funki-ask')));
    await tester.pumpAndSettle();
    expect(find.textContaining('was auf die Liste soll'), findsOneWidget);
    expect(find.text('Öl und Salz haben wir immer zuhause'), findsOneWidget);
    await ask(tester, 'Hallo');
    expect(brain.histories.single.first.text, contains('aus der Einkaufsliste geöffnet'));
    // Everything he can do, wherever he is asked.
    expect(brain.toolNames, containsAll(<String>[
      'plan_week', 'write_recipe', 'move_meal', 'tick_list_items', 'set_pantry',
      'set_food_preferences', 'get_training',
    ]));
  });

  testWidgets('without a model that can call tools, the line is not offered',
      (WidgetTester tester) async {
    await pump(tester, askButton(), null);
    expect(find.text('Funki fragen'), findsNothing);
  });
}

Challenge _gymChallenge() => Challenge(
      id: 'gym',
      goal: const Goal(
        archetype: GoalArchetype.buildMuscle,
        statement: 'Stärker werden',
        body: _body,
        trainingDaysPerWeek: 3,
      ),
      habits: <Habit>[
        Habit.fromCategory(HabitCategory.gym).copyWith(daysPerWeek: 3),
        Habit.fromCategory(HabitCategory.reading),
      ],
      startDay: DayKey.today().addDays(-3),
    );

/// Salmon dinners for [days], the way the planner's model answers them:
/// every ingredient, the oil and the salt marked as basics.
String _salmon(List<DayKey> days) => jsonEncode(<String, dynamic>{
      'meals': <Object>[
        for (final DayKey day in days)
          <String, dynamic>{
            'day': '$day',
            'slot': 'dinner',
            'title': 'Lachs $day',
            'servings': 1,
            'minutes': 25,
            'kcal': 620,
            'protein': 45,
            'carbs': 40,
            'fat': 30,
            'ingredients': <Object>[
              <String, dynamic>{'name': 'Lachsfilet', 'qty': 150, 'unit': 'g', 'category': 'fish'},
              <String, dynamic>{'name': 'Weiße Bohnen', 'qty': 240, 'unit': 'g', 'category': 'pantry'},
              <String, dynamic>{'name': 'Olivenöl', 'qty': 1, 'unit': 'tbsp', 'category': 'pantry', 'staple': true},
              <String, dynamic>{'name': 'Salz', 'qty': 0.5, 'unit': 'tsp', 'category': 'pantry', 'staple': true},
            ],
            'steps': <String>['Bohnen erwärmen.', 'Lachs braten.'],
          },
      ],
    });

/// The model behind the planner: answers each prompt and keeps it.
class _PlannerLlm implements LlmClient {
  _PlannerLlm(this.answer);

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

/// Ready, for screens that only offer the AI when a model is there.
class _ReadyLlm implements LlmClient {
  const _ReadyLlm();

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
  }) async =>
      '';
}
