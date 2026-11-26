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

  Future<void> pump(WidgetTester tester, Widget child, _ScriptedBrain? brain) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrapForTest(
      repository: repository,
      child: child,
      household: household,
      overrides: <Override>[funkiBrainProvider.overrideWithValue(brain)],
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

  testWidgets('without a model that can call tools, the line is not offered',
      (WidgetTester tester) async {
    await pump(tester, askButton(), null);
    expect(find.text('Funki fragen'), findsNothing);
  });
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
