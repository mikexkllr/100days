import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/device_profile.dart';
import 'package:hundred_days/state/providers.dart';
import 'package:hundred_days/ui/nutrition/diary_view.dart';
import 'package:hundred_days/ui/plan/plan_screen.dart';
import 'package:hundred_days/ui/plan/workout_logger.dart';
import 'package:hundred_days/ui/settings/ai_screen.dart';
import 'package:hundred_days/ui/settings/privacy_screen.dart';

import 'helpers.dart';

const BodyProfile _body = BodyProfile(
  sex: BiologicalSex.female,
  ageYears: 29,
  heightCm: 170,
  weightKg: 66,
  activityLevel: ActivityLevel.moderate,
);

Challenge _fitChallenge({bool plans = true}) => Challenge(
      id: 'fit',
      goal: Goal(
        archetype: GoalArchetype.buildMuscle,
        statement: 'Stärker werden',
        body: _body,
        trainingDaysPerWeek: 3,
        trainingPlanEnabled: plans,
        nutritionPlanEnabled: plans,
      ),
      habits: <Habit>[
        Habit.fromCategory(HabitCategory.gym).copyWith(daysPerWeek: 3),
        Habit.fromCategory(HabitCategory.nutrition),
      ],
      startDay: DayKey.today(),
    );

void main() {
  late AppRepository repository;

  setUp(() async {
    repository = await testRepository();
    await repository.saveProfile(displayName: 'Mia', avatarEmoji: '🦊');
  });

  Future<void> pump(WidgetTester tester, Widget child,
      {DeviceProfile? device}) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrapForTest(
      repository: repository,
      child: child,
      overrides: device == null
          ? const <Override>[]
          : <Override>[
              deviceProfileProvider.overrideWith((Ref ref) async => device),
            ],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the plan has no advice tab, only things to act on',
      (WidgetTester tester) async {
    await repository.startChallenge(_fitChallenge());
    await pump(tester, const PlanScreen());

    expect(find.text('Anpassungen'), findsNothing);
    expect(find.text('Training'), findsOneWidget);
    expect(find.text('Ernährung'), findsOneWidget);
    expect(find.byKey(const Key('edit-training-plan')), findsOneWidget);
  });

  testWidgets('switched-off plans offer themselves, with the bonus',
      (WidgetTester tester) async {
    await repository.startChallenge(_fitChallenge(plans: false));
    await pump(tester, const PlanScreen());

    expect(find.text('Trainingsplan einschalten'), findsWidgets);
    expect(find.textContaining('+50 % XP'), findsOneWidget);
  });

  testWidgets('logging a meal by hand updates the day and stays sealed',
      (WidgetTester tester) async {
    await repository.startChallenge(_fitChallenge());
    await pump(tester, const DiaryScreen());

    final String before =
        tester.widget<Text>(find.byKey(const Key('kcal-left'))).data!;

    await tester.tap(find.byKey(const Key('add-food-lunch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manuell'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('manual-name')), 'Omas Gulasch');
    await tester.enterText(find.byKey(const Key('manual-kcal')), '640');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-add')));
    await tester.pumpAndSettle();

    expect(find.text('Omas Gulasch'), findsOneWidget);
    final String after =
        tester.widget<Text>(find.byKey(const Key('kcal-left'))).data!;
    expect(int.parse(before) - int.parse(after), 640);

    final FeedEvent last =
        (await repository.store.eventsOf(repository.did)).last;
    expect(last.type, FeedEventType.private);
    expect(last.payload.toString(), isNot(contains('Gulasch')));
  });

  testWidgets('describing a meal recognises foods from the table',
      (WidgetTester tester) async {
    await repository.startChallenge(_fitChallenge());
    await pump(tester, const DiaryScreen());

    await tester.tap(find.byKey(const Key('add-food-breakfast')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beschreiben'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('food-describe')), '2 Eier und 1 Banane');
    await tester.tap(find.byKey(const Key('food-parse')));
    await tester.pumpAndSettle();

    expect(find.text('Ei'), findsOneWidget);
    expect(find.text('Banane'), findsOneWidget);
    await tester.tap(find.byKey(const Key('food-add-parsed')));
    await tester.pumpAndSettle();

    final AppSnapshot snapshot = await repository.snapshot();
    final List<FoodEntry> entries =
        snapshot.me.intakeOn(DayKey.today()).entries;
    expect(entries.map((FoodEntry e) => e.foodId).toSet(),
        <String>{'egg', 'banana'});
    expect(entries.every((FoodEntry e) => e.meal == MealSlotKind.breakfast),
        isTrue);
  });

  testWidgets('a logged workout is tracked and worth more than a tick',
      (WidgetTester tester) async {
    final Challenge challenge = _fitChallenge();
    await repository.startChallenge(challenge);
    final Workout workout =
        buildPlan(challenge).training!.weeks.first.workouts.first;
    await pump(
      tester,
      WorkoutLoggerScreen(workout: workout, day: DayKey.today()),
    );

    // The first time there is nothing to beat yet.
    expect(find.textContaining('Erstes Mal'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, '40');
    await tester.tap(find.byIcon(Icons.check).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finish-workout')));
    await tester.pumpAndSettle();

    final AppSnapshot snapshot = await repository.snapshot();
    final WorkoutLog log = snapshot.me.workoutLogOn(DayKey.today())!;
    expect(log.totalSets, 1);
    expect(log.exercises.first.sets.single.weightKg, 40);
    final CheckIn checkIn =
        snapshot.me.logsByDay[DayKey.today().toString()]!.entryFor('gym')!;
    expect(checkIn.tracked, isTrue);

    final int tickXp = xpForCheckIn(
      habit: challenge.habits.first,
      checkIn: CheckIn(
        habitId: 'gym',
        category: HabitCategory.gym,
        day: DayKey.today(),
        value: 1,
        loggedAt: DateTime.now(),
      ),
      streakBefore: 0,
    );
    expect(snapshot.me.xpByDay[DayKey.today().toString()],
        greaterThan(tickXp));

    // Next time, the logger has a number to beat.
    expect(
      recommendNext(
        target: workout.blocks.first,
        history: snapshot.me.historyOf(workout.blocks.first.exerciseId),
      ).weightKg,
      40,
    );
  });

  testWidgets('onboarding offers the smaller models, not the too-big ones',
      (WidgetTester tester) async {
    await repository.startChallenge(_fitChallenge());
    await pump(
      tester,
      const SingleChildScrollView(
        child: ModelSetupCard(showAlternatives: false),
      ),
      device: const DeviceProfile(
        model: 'Galaxy A55',
        ramMb: 5700,
        supportsLocalAi: true,
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('ai-recommended')),
        matching: find.text('Qwen3.5 2B'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-option-qwen3.5-0.8b-q4')), findsOneWidget);
    // Larger and too-big models stay out of onboarding.
    expect(find.byKey(const Key('ai-option-gemma-4-e2b-qat')), findsNothing);
    expect(find.byKey(const Key('ai-option-gemma-4-e2b-qat-mobile')),
        findsNothing);
  });

  testWidgets('the AI card names the phone and the model that fits it',
      (WidgetTester tester) async {
    await repository.startChallenge(_fitChallenge());
    await pump(
      tester,
      const SingleChildScrollView(child: ModelSetupCard()),
      device: const DeviceProfile(
        model: 'Pixel 8',
        ramMb: 7800,
        supportsLocalAi: true,
      ),
    );

    expect(find.text('Pixel 8 · 8 GB RAM'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('ai-recommended')),
        matching: find.text('Gemma 4 E2B'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Jetzt laden (2.6 GB)'), findsOneWidget);

    // Smaller models are offered next to the proposal, ready to download.
    expect(find.text('Kleiner und schneller'), findsOneWidget);
    for (final String id in <String>[
      'gemma-4-e2b-qat-mobile',
      'qwen3.5-2b-q4',
      'qwen3.5-0.8b-q4',
    ]) {
      expect(find.byKey(Key('ai-option-$id')), findsOneWidget, reason: id);
    }
    // The one that does not fit is listed in settings, marked.
    expect(find.byKey(const Key('ai-option-gemma-4-e4b-qat-mobile')),
        findsOneWidget);
    expect(find.text('ZU GROß'), findsOneWidget);
  });

  testWidgets('hiding a habit seals its check-ins from then on',
      (WidgetTester tester) async {
    await repository.saveProfile(
      displayName: 'Mia',
      avatarEmoji: '🦊',
      goalStatement: 'Stärker werden',
    );
    await repository.startChallenge(_fitChallenge());
    await pump(tester, const PrivacyScreen());

    await tester.tap(find.byKey(const Key('share-nutrition')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-statement')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('privacy-save')));
    await tester.pumpAndSettle();

    final AppSnapshot snapshot = await repository.snapshot();
    expect(snapshot.challenge!.sharing.isHabitShared('nutrition'), isFalse);
    await repository.checkIn(
      habit: snapshot.challenge!.habitById('nutrition')!,
      day: DayKey.today(),
    );

    final List<FeedEvent> raw =
        await repository.store.eventsOf(repository.did);
    expect(raw.last.type, FeedEventType.private);
    final UserProjection asFriend = projectUser(repository.did, raw);
    expect(asFriend.challenge!.habits.map((Habit h) => h.id), <String>['gym']);
    expect(asFriend.challenge!.goal.statement, isEmpty);
    expect(asFriend.profile.goalStatement, isNull);
  });
}
