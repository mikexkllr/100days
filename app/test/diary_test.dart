import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/ai/meal_photo.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/ui/nutrition/diary_view.dart';
import 'package:hundred_days/ui/nutrition/nutrition_goals_screen.dart';

import 'helpers.dart';

/// The food diary, the add-food screen and the targets screen: what the
/// pre-release review found in them.

/// Answers every prompt with [answer], remembers the last one — or fails
/// the way a phone without network does.
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

const BodyProfile _body = BodyProfile(
  sex: BiologicalSex.female,
  ageYears: 29,
  heightCm: 170,
  weightKg: 66,
  activityLevel: ActivityLevel.moderate,
);

Challenge _dietChallenge() => Challenge(
      id: 'diet',
      goal: const Goal(
        archetype: GoalArchetype.loseFat,
        statement: 'Leichter werden',
        body: _body,
        nutritionPlanEnabled: true,
      ),
      habits: <Habit>[Habit.fromCategory(HabitCategory.nutrition)],
      startDay: DayKey.today().addDays(-5),
    );

FoodEntry _entry(String id, double kcal, {DayKey? day, double grams = 100}) =>
    FoodEntry(
      id: id,
      day: day ?? DayKey.today(),
      meal: MealSlotKind.lunch,
      name: 'Eintopf $id',
      grams: grams,
      nutrients: Nutrients(kcal: kcal, proteinG: 20, carbsG: 30, fatG: 10),
      source: FoodSource.photo,
    );

void main() {
  late AppRepository repository;

  setUp(() async {
    repository = await testRepository();
    await repository.startChallenge(_dietChallenge());
  });

  Future<void> pump(WidgetTester tester, Widget child, {LlmClient? llm}) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrapForTest(
      repository: repository,
      child: child,
      llm: llm ?? const UnavailableLlmClient(),
    ));
    await tester.pumpAndSettle();
  }

  Future<List<FoodEntry>> eaten({DayKey? on}) async =>
      (await repository.snapshot()).me.intakeOn(on ?? DayKey.today()).entries;

  group('the diary', () {
    testWidgets('left open overnight, it moves on to the new day',
        (WidgetTester tester) async {
      final DayKey today = DayKey.today();
      final ValueNotifier<AppSnapshot> snapshot = ValueNotifier<AppSnapshot>(
          await repository.snapshot(today: today.addDays(-1)));
      await pump(
        tester,
        ValueListenableBuilder<AppSnapshot>(
          valueListenable: snapshot,
          builder: (BuildContext context, AppSnapshot s, _) =>
              NutritionDiaryView(snapshot: s),
        ),
      );

      // Midnight passes with the diary open.
      snapshot.value = await repository.snapshot(today: today);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-food-lunch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manuell'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('manual-name')), 'Müsli');
      await tester.enterText(find.byKey(const Key('manual-kcal')), '350');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manual-add')));
      await tester.pumpAndSettle();

      expect((await eaten(on: today)).single.name, 'Müsli');
      expect(await eaten(on: today.addDays(-1)), isEmpty);
    });

    testWidgets('a day the user went back to stays put',
        (WidgetTester tester) async {
      final DayKey today = DayKey.today();
      final ValueNotifier<AppSnapshot> snapshot = ValueNotifier<AppSnapshot>(
          await repository.snapshot(today: today.addDays(-1)));
      await pump(
        tester,
        ValueListenableBuilder<AppSnapshot>(
          valueListenable: snapshot,
          builder: (BuildContext context, AppSnapshot s, _) =>
              NutritionDiaryView(snapshot: s),
        ),
      );
      await tester.tap(find.byKey(const Key('diary-previous-day')));
      await tester.pumpAndSettle();

      snapshot.value = await repository.snapshot(today: today);
      await tester.pumpAndSettle();
      expect(find.text('Heute'), findsNothing);
    });

    testWidgets('a swiped line goes, and comes back with undo',
        (WidgetTester tester) async {
      await repository.logFood(_entry('a', 600));
      await pump(tester, const DiaryScreen());

      await tester.drag(find.byKey(const Key('diary-entry-a')), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Eintopf a'), findsNothing);
      expect(await eaten(), isEmpty);

      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      expect(find.text('Eintopf a'), findsOneWidget);
      final FoodEntry back = (await eaten()).single;
      expect(back.id, 'a');
      expect(back.nutrients.kcal, 600);
    });

    testWidgets('an estimate in the diary can be put right',
        (WidgetTester tester) async {
      await repository.logFood(_entry('a', 600, grams: 400));
      await pump(tester, const DiaryScreen());

      await tester.tap(find.byKey(const Key('diary-entry-a')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('edit-grams')), '200');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-save')));
      await tester.pumpAndSettle();

      final FoodEntry fixed = (await eaten()).single;
      expect(fixed.id, 'a');
      expect(fixed.grams, 200);
      expect(fixed.nutrients.kcal, 300);
      expect(fixed.nutrients.proteinG, 10);
    });

    testWidgets('off target, the dialog says under or over',
        (WidgetTester tester) async {
      await repository.logFood(_entry('a', 500));
      await pump(tester, const DiaryScreen());
      final int target = (await repository.snapshot()).plan!.nutrition!.kcal;

      await tester.tap(find.byKey(const Key('close-day')));
      await tester.pumpAndSettle();
      expect(find.textContaining('${target - 500} kcal unter deinem Ziel'),
          findsOneWidget);
      expect(find.textContaining(RegExp(r'-\d')), findsNothing);
    });

    testWidgets('a plain tick can still be closed on target later',
        (WidgetTester tester) async {
      final AppSnapshot before = await repository.snapshot();
      final Habit habit = before.challenge!.habitById('nutrition')!;
      // Ticked on Today, before anything was logged.
      await repository.checkIn(habit: habit, day: DayKey.today());
      await repository.logFood(
          _entry('a', before.plan!.nutrition!.kcal.toDouble()));
      await pump(tester, const DiaryScreen());

      expect(find.text('Tag abgehakt.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('close-day-tracked')));
      await tester.pumpAndSettle();

      final CheckIn now = (await repository.snapshot())
          .me
          .logsByDay[DayKey.today().toString()]!
          .entryFor(habit.id)!;
      expect(now.tracked, isTrue);
      expect(find.byKey(const Key('close-day-tracked')), findsNothing);
    });
  });

  group('adding food', () {
    Future<void> describe(WidgetTester tester, String text) async {
      await tester.tap(find.byKey(const Key('add-food-breakfast')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beschreiben'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('food-describe')), text);
      await tester.pumpAndSettle();
    }

    testWidgets('a double tap on "add" logs once and closes once',
        (WidgetTester tester) async {
      await pump(tester, const DiaryScreen());
      await describe(tester, '2 Eier');
      await tester.tap(find.byKey(const Key('food-parse')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('food-add-parsed')));
      await tester.tap(find.byKey(const Key('food-add-parsed')), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(await eaten(), hasLength(1));
      // Still in the diary, not popped past it.
      expect(find.byKey(const Key('kcal-left')), findsOneWidget);
    });

    testWidgets('the estimate asks about the text as it reads now',
        (WidgetTester tester) async {
      final _Llm llm = _Llm('{"foods":[{"name":"Käsekuchen","grams":120,'
          '"kcal":350,"protein":8,"carbs":40,"fat":17}]}');
      await pump(tester, const DiaryScreen(), llm: llm);
      await describe(tester, '2 Eier und Thunfischpizza');
      await tester.tap(find.byKey(const Key('food-parse')));
      await tester.pumpAndSettle();

      // Changed after "recognise", estimated without it.
      await tester.enterText(
          find.byKey(const Key('food-describe')), '2 Eier und Käsekuchen');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-estimate')));
      await tester.pumpAndSettle();
      expect(llm.lastPrompt, contains('käsekuchen'));
      expect(llm.lastPrompt, isNot(contains('thunfischpizza')));
      expect(find.text('Käsekuchen'), findsOneWidget);

      // Nothing left to ask about: the button rests.
      FilledButton estimate() =>
          tester.widget<FilledButton>(find.byKey(const Key('food-estimate')));
      expect(estimate().onPressed, isNull);

      // A paid estimate survives a look at another tab.
      await tester.tap(find.text('Suchen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beschreiben'));
      await tester.pumpAndSettle();
      expect(find.text('Käsekuchen'), findsOneWidget);

      // And can be put right before it is added.
      await tester.tap(find.byKey(const Key('draft-edit-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('edit-kcal')), '420');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-add-parsed')));
      await tester.pumpAndSettle();
      final FoodEntry cake =
          (await eaten()).firstWhere((FoodEntry e) => e.name == 'Käsekuchen');
      expect(cake.nutrients.kcal, 420);
      expect(cake.source, FoodSource.ai);
    });

    testWidgets('with everything recognised there is nothing to estimate',
        (WidgetTester tester) async {
      await pump(tester, const DiaryScreen(), llm: _Llm('{}'));
      await describe(tester, '2 Eier');
      expect(
          tester.widget<FilledButton>(find.byKey(const Key('food-estimate'))).onPressed,
          isNull);
    });

    testWidgets('offline, the estimate says so', (WidgetTester tester) async {
      await pump(tester, const DiaryScreen(), llm: _Llm('', fails: true));
      await describe(tester, 'Käsekuchen');
      await tester.tap(find.byKey(const Key('food-estimate')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Die KI war nicht erreichbar'), findsOneWidget);
    });
  });

  group('meal photos', () {
    test('a refused permission is told apart from a broken picker', () {
      expect(pickProblem(PlatformException(code: 'camera_access_denied')),
          MealPhotoProblem.noPermission);
      expect(pickProblem(PlatformException(code: 'photo_access_denied')),
          MealPhotoProblem.noPermission);
      expect(pickProblem(PlatformException(code: 'no_available_camera')),
          MealPhotoProblem.pickFailed);
      expect(pickProblem(StateError('boom')), MealPhotoProblem.pickFailed);
    });

    test('bytes that are no image give null, never an exception', () async {
      // The start of a HEIC file, which the decoder does not read.
      final Uint8List heic = Uint8List.fromList(
          <int>[0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63]);
      expect(await prepareMealPhoto(heic), isNull);
    });
  });

  group('nutrition targets', () {
    testWidgets('a proposal is labelled as the cloud call it is',
        (WidgetTester tester) async {
      final Challenge challenge = (await repository.snapshot()).challenge!;
      final int tdee = buildNutritionPlan(challenge.goal).tdee;
      await pump(
        tester,
        NutritionGoalsScreen(challenge: challenge),
        llm: _Llm('{"kcal":${tdee - 100},"protein_pct":35,"carbs_pct":30,'
            '"fat_pct":35,"reason":"Weniger Kohlenhydrate."}'),
      );
      await tester.enterText(find.byType(TextField).last, 'weniger Kohlenhydrate');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Vorschlag holen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vorschlag holen'));
      await tester.pumpAndSettle();

      expect(find.text('CLOUD-KI'), findsOneWidget);
      expect(find.textContaining('on-device'), findsNothing);
    });
  });

  group('entering numbers by hand', () {
    Future<void> openManual(WidgetTester tester) async {
      await pump(tester, const DiaryScreen());
      await tester.tap(find.byKey(const Key('add-food-lunch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manuell'));
      await tester.pumpAndSettle();
    }

    testWidgets('without calories, add says what is missing and where to go',
        (WidgetTester tester) async {
      await openManual(tester);
      await tester.enterText(find.byKey(const Key('manual-name')), 'Pasta');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manual-add')));
      await tester.pumpAndSettle();

      expect(await eaten(), isEmpty);
      expect(find.textContaining('Ohne Kalorien geht es nicht'), findsOneWidget);
      await tester.tap(find.byKey(const Key('manual-to-photo')));
      await tester.pumpAndSettle();
      // Without a model the photo tab says what it needs.
      expect(find.text('Ein Foto von deinem Teller'), findsOneWidget);
    });

    testWidgets('without a name, add asks for it', (WidgetTester tester) async {
      await openManual(tester);
      await tester.enterText(find.byKey(const Key('manual-kcal')), '500');
      await tester.tap(find.byKey(const Key('manual-add')));
      await tester.pumpAndSettle();

      expect(await eaten(), isEmpty);
      expect(find.text('Was war es?'), findsOneWidget);
    });

    testWidgets('macros without calories add up to them',
        (WidgetTester tester) async {
      await openManual(tester);
      await tester.enterText(find.byKey(const Key('manual-name')), 'Riegel');
      await tester.enterText(
          find.widgetWithText(TextField, 'Eiweiß in g (optional)'), '20');
      await tester.enterText(
          find.widgetWithText(TextField, 'Fett in g (optional)'), '10');
      await tester.pumpAndSettle();
      expect(find.text('≈ 170 kcal aus den Makros unten'), findsOneWidget);
      await tester.tap(find.byKey(const Key('manual-add')));
      await tester.pumpAndSettle();

      final FoodEntry entry = (await eaten()).single;
      expect(entry.nutrients.kcal, 20 * 4 + 10 * 9);
      expect(entry.nutrients.proteinG, 20);
    });

    testWidgets('opened on a day gone by, it logs onto that day',
        (WidgetTester tester) async {
      final DayKey day = DayKey.today().addDays(-2);
      await pump(tester, DiaryScreen(day: day));
      expect(find.text('Heute'), findsNothing);
      await tester.tap(find.byKey(const Key('add-food-lunch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manuell'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('manual-name')), 'Suppe');
      await tester.enterText(find.byKey(const Key('manual-kcal')), '300');
      await tester.tap(find.byKey(const Key('manual-add')));
      await tester.pumpAndSettle();

      expect((await eaten(on: day)).single.name, 'Suppe');
      expect(await eaten(), isEmpty);
    });
  });
}
