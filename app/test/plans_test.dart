import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/household_backend.dart';
import 'package:hundred_days/l10n/l10n.dart';
import 'package:hundred_days/ui/nutrition/diary_view.dart';
import 'package:hundred_days/ui/plan/plan_screen.dart';
import 'package:hundred_days/ui/plan/session_editor.dart';
import 'package:hundred_days/ui/plan/training_editor.dart';
import 'package:hundred_days/ui/plan/workout_draft.dart';
import 'package:hundred_days/ui/plan/workout_logger.dart';
import 'package:hundred_days/theme/theme.dart';
import 'package:hundred_days/ui/settings/privacy_screen.dart';
import 'package:hundred_days/ui/widgets/app_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// A button that pushes [screen], so leaving it goes through the real back
/// navigation.
Widget _opener(Widget screen) => Builder(
      builder: (BuildContext context) => TextButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (BuildContext context) => screen),
        ),
        child: const Text('open'),
      ),
    );

void main() {
  late AppRepository repository;

  setUp(() async {
    // Unfinished workouts wait in the preferences; start every test clean.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = await testRepository();
    await repository.saveProfile(displayName: 'Mia', avatarEmoji: '🦊');
  });

  Future<void> pump(WidgetTester tester, Widget child,
      {HouseholdBackend? household}) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrapForTest(
      repository: repository,
      child: child,
      household: household,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the plan is what lies ahead; the diary is not one of its tabs',
      (WidgetTester tester) async {
    await repository.startChallenge(_fitChallenge());
    await pump(tester, const PlanScreen());

    expect(find.text('Anpassungen'), findsNothing);
    expect(find.widgetWithText(Tab, 'Training'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Essensplan'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Einkauf'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Ernährung'), findsNothing);
    expect(find.byKey(const Key('edit-training-plan')), findsOneWidget);
    expect(find.byKey(const Key('add-food-lunch')), findsNothing);

    // The nutrition target sits on top of the meals it portions.
    await tester.tap(find.widgetWithText(Tab, 'Essensplan'));
    await tester.pumpAndSettle();
    final NutritionPlan plan = buildNutritionPlan(_fitChallenge().goal);
    expect(find.byKey(const Key('nutrition-target')), findsOneWidget);
    expect(find.textContaining('${plan.kcal} kcal'), findsOneWidget);
    expect(find.byKey(const Key('plan-week')), findsOneWidget);
  });

  testWidgets('switched-off plans offer themselves, with the bonus',
      (WidgetTester tester) async {
    await repository.startChallenge(_fitChallenge(plans: false));
    await pump(tester, const PlanScreen());

    expect(find.text('Trainingsplan einschalten'), findsWidgets);
    expect(find.textContaining('+50 % XP'), findsOneWidget);

    // The nutrition plan is offered above the meals, and says where the
    // diary will be.
    await tester.tap(find.widgetWithText(Tab, 'Essensplan'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enable-nutrition')), findsOneWidget);
    expect(find.text('Ernährungsplan einschalten'), findsOneWidget);
    expect(find.textContaining('unter Heute'), findsOneWidget);
    expect(find.byKey(const Key('nutrition-target')), findsNothing);
  });

  testWidgets('what the household planned waits in the diary, one tap away',
      (WidgetTester tester) async {
    await repository.startChallenge(_fitChallenge());
    final MemoryHouseholdBackend household = MemoryHouseholdBackend(
        userId: repository.userId, displayName: 'Mia');
    final String id = await household.ensureHousehold();
    final Recipe dal = await household.saveRecipe(
      id,
      Recipe(
        id: newEventId(),
        title: 'Linsen-Dal',
        servings: 2,
        ingredients: const <Ingredient>[],
        perServing:
            const Nutrients(kcal: 500, proteinG: 24, carbsG: 70, fatG: 14),
      ),
    );
    await household.saveEntry(
      id,
      PlanEntry(
        id: newEventId(),
        day: DayKey.today(),
        slot: MealSlotKind.dinner,
        recipeId: dal.id,
        portions: <String, double>{repository.userId: 1.5},
      ),
    );
    await pump(tester, const DiaryScreen(), household: household);

    expect(find.text('Linsen-Dal'), findsOneWidget);
    expect(find.text('Geplant · 750 kcal'), findsOneWidget);
    expect(find.byKey(const Key('eat-planned-lunch')), findsNothing);
    final String before =
        tester.widget<Text>(find.byKey(const Key('kcal-left'))).data!;

    await tester.tap(find.byKey(const Key('eat-planned-dinner')));
    await tester.pumpAndSettle();

    // In the diary now, with my portion — and no longer offered.
    final List<FoodEntry> eaten =
        (await repository.snapshot()).me.intakeOn(DayKey.today()).entries;
    expect(eaten.single.name, 'Linsen-Dal');
    expect(eaten.single.nutrients.kcal, 750);
    expect(eaten.single.source, FoodSource.plan);
    expect(find.byKey(const Key('eat-planned-dinner')), findsNothing);
    expect(find.text('Linsen-Dal'), findsOneWidget);
    final String after =
        tester.widget<Text>(find.byKey(const Key('kcal-left'))).data!;
    expect(int.parse(before) - int.parse(after), 750);
  });

  testWidgets('logging a meal by hand updates the day and stays private',
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
        (await repository.store.eventsOf(repository.userId)).last;
    expect(last.type, FeedEventType.foodLogged);
    expect(last.visibility, EventVisibility.private);
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

  testWidgets('without the AI the photo tab says how to get it',
      (WidgetTester tester) async {
    await repository.startChallenge(_fitChallenge());
    await pump(tester, const DiaryScreen());

    await tester.tap(find.byKey(const Key('add-food-lunch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto'));
    await tester.pumpAndSettle();

    expect(find.text('Ein Foto von deinem Teller'), findsOneWidget);
    expect(find.byKey(const Key('food-photo-camera')), findsNothing);
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

  testWidgets('dips and pull-ups take added weight, but do not ask for it',
      (WidgetTester tester) async {
    await repository.startChallenge(_fitChallenge());
    const Workout workout = Workout(
      kind: WorkoutKind.push,
      weekday: DateTime.monday,
      estimatedMinutes: 20,
      blocks: <PlannedSet>[
        PlannedSet(
          exerciseId: 'dip',
          sets: 2,
          repsLow: 6,
          repsHigh: 10,
          rpe: 8,
          restSeconds: 120,
        ),
      ],
    );
    await pump(
      tester,
      WorkoutLoggerScreen(workout: workout, day: DayKey.today()),
    );

    // Optional, so the empty field says what it is for.
    expect(find.text('+ kg'), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).first, '10');
    await tester.tap(find.byIcon(Icons.check).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finish-workout')));
    await tester.pumpAndSettle();

    final AppSnapshot snapshot = await repository.snapshot();
    final LoggedSet set =
        snapshot.me.workoutLogOn(DayKey.today())!.exercises.single.sets.single;
    expect(set.weightKg, 10);
    expect(set.reps, 6);
  });

  testWidgets('a deload week says go lighter, and is logged as one',
      (WidgetTester tester) async {
    final Challenge challenge = _fitChallenge();
    await repository.startChallenge(challenge);
    final TrainingPlan plan = buildPlan(challenge).training!;
    final Workout build = plan.weeks.first.workouts.first;
    final Workout deload = plan.weeks[3].workouts.first;
    expect(deload.isDeload, isTrue);
    final String exercise = deload.blocks.first.exerciseId;
    // Last week's session: the top of the range at 80 kg.
    await repository.logWorkout(
      log: WorkoutLog(
        day: DayKey.today().addDays(-7),
        kind: build.kind,
        sessionIndex: build.sessionIndex,
        loggedAt: DateTime.now().subtract(const Duration(days: 7)),
        exercises: <ExerciseLog>[
          ExerciseLog(exerciseId: exercise, sets: <LoggedSet>[
            for (int i = 0; i < 3; i++)
              LoggedSet(weightKg: 80, reps: build.blocks.first.repsHigh),
          ]),
        ],
      ),
      habit: challenge.habits.first,
      challenge: challenge,
    );

    await pump(
      tester,
      WorkoutLoggerScreen(workout: deload, day: DayKey.today()),
    );

    expect(find.byKey(const Key('logger-deload')), findsOneWidget);
    expect(find.textContaining('Deload: leichter mit 72,5 kg'), findsOneWidget);
    expect(find.textContaining('jetzt 82,5 kg'), findsNothing);
    await tester.tap(find.byIcon(Icons.check).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finish-workout')));
    await tester.pumpAndSettle();

    final AppSnapshot snapshot = await repository.snapshot();
    final WorkoutLog log = snapshot.me.workoutLogOn(DayKey.today())!;
    expect(log.deload, isTrue);
    expect(log.exercises.first.sets.single.weightKg, 72.5);
    // The week after, last week's 80 kg is still the number to beat.
    expect(
      recommendNext(
        target: build.blocks.first,
        history: snapshot.me.historyOf(exercise),
      ).weightKg,
      82.5,
    );
  });

  testWidgets('a workout killed halfway is offered again, sets and all',
      (WidgetTester tester) async {
    final Challenge challenge = _fitChallenge();
    await repository.startChallenge(challenge);
    final Workout workout =
        buildPlan(challenge).training!.weeks.first.workouts.first;
    final Widget logger =
        WorkoutLoggerScreen(workout: workout, day: DayKey.today());
    await pump(tester, logger);

    await tester.enterText(find.byType(TextField).first, '40');
    await tester.tap(find.byIcon(Icons.check).first);
    await tester.pumpAndSettle();
    // Android kills the app in the background: no pop, no dispose hook.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    await pump(tester, logger);
    expect(find.text('Weitermachen, wo du warst?'), findsOneWidget);
    expect(find.textContaining('Ein Satz ist abgehakt'), findsOneWidget);
    await tester.tap(find.byKey(const Key('draft-resume')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '40',
    );

    await tester.tap(find.byKey(const Key('finish-workout')));
    await tester.pumpAndSettle();
    final AppSnapshot snapshot = await repository.snapshot();
    expect(snapshot.me.workoutLogOn(DayKey.today())!.totalSets, 1);
    expect(
      snapshot.me.workoutLogOn(DayKey.today())!.exercises.first.sets.single
          .weightKg,
      40,
    );
    // Finished: nothing left to offer.
    expect(
      await WorkoutDraftStore()
          .load(repository.userId, DayKey.today(), workout.sessionIndex),
      isNull,
    );
  });

  testWidgets('typed but unticked numbers are not lost on the way out',
      (WidgetTester tester) async {
    final Challenge challenge = _fitChallenge();
    await repository.startChallenge(challenge);
    final Workout workout =
        buildPlan(challenge).training!.weeks.first.workouts.first;
    await pump(
      tester,
      _opener(WorkoutLoggerScreen(workout: workout, day: DayKey.today())),
    );
    Future<void> open() async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    // Nothing entered: back simply leaves.
    await open();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutLoggerScreen), findsNothing);

    // A number typed, no set ticked: back asks first, and can keep it.
    await open();
    await tester.enterText(find.byType(TextField).first, '55');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Training verlassen?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('logger-keep')));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutLoggerScreen), findsNothing);

    // Back in: offered, and starting over throws it away.
    await open();
    expect(find.text('Weitermachen, wo du warst?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('draft-start-over')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isNot('55'),
    );
    expect(
      await WorkoutDraftStore()
          .load(repository.userId, DayKey.today(), workout.sessionIndex),
      isNull,
    );

    // Discarding on the way out leaves nothing behind either.
    await tester.enterText(find.byType(TextField).first, '60');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logger-discard')));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutLoggerScreen), findsNothing);
    await open();
    expect(find.text('Weitermachen, wo du warst?'), findsNothing);
  });

  testWidgets('the plan editor keeps edits until they are saved or let go',
      (WidgetTester tester) async {
    final Challenge challenge = _fitChallenge();
    await repository.startChallenge(challenge);
    final ExerciseSlot first =
        suggestTrainingSetup(challenge.goal).sessions.first.exercises.first;
    final AppLocalizations de = await localizationsFor(const Locale('de'));
    await pump(tester, _opener(TrainingEditorScreen(challenge: challenge)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // One more set, then move it down: the move keeps the extra set.
    final Finder name = find.text(de.exerciseName(first.exerciseId));
    await tester.scrollUntilVisible(name, 300,
        scrollable: find.byType(Scrollable).first);
    final Finder row = name.first;
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('slot-move-down')));
    await tester.pumpAndSettle();

    // Tapping the split that is already chosen changes nothing.
    final Finder chosen = find.byKey(Key('split-${SplitKind.fullBody.name}'));
    await tester.scrollUntilVisible(chosen, -300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(chosen);
    await tester.pumpAndSettle();
    await tester.tap(chosen);
    await tester.pumpAndSettle();

    // Back asks first; cancelling stays.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Änderungen verwerfen?'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.byType(TrainingEditorScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();
    final AppSnapshot snapshot = await repository.snapshot();
    final ExerciseSlot moved =
        snapshot.challenge!.goal.training!.sessions.first.exercises[1];
    expect(moved.exerciseId, first.exerciseId);
    expect(moved.sets, first.sets + 1);
  });

  testWidgets('the training plan switches off, keeps the log, comes back',
      (WidgetTester tester) async {
    final Challenge challenge = _fitChallenge();
    await repository.startChallenge(challenge);
    await repository.logWorkout(
      log: WorkoutLog(
        day: DayKey.today(),
        kind: WorkoutKind.fullBodyA,
        sessionIndex: 0,
        loggedAt: DateTime.now(),
        exercises: const <ExerciseLog>[
          ExerciseLog(exerciseId: 'back_squat', sets: <LoggedSet>[
            LoggedSet(weightKg: 80, reps: 8),
          ]),
        ],
      ),
      habit: challenge.habits.first,
      challenge: challenge,
    );
    await pump(tester, const PlanScreen());

    await tester.tap(find.byKey(const Key('edit-training-plan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('training-plan-switch')));
    await tester.pumpAndSettle();
    // What off means, before it is saved: no split to edit, no bonus.
    expect(find.text('Split'), findsNothing);
    expect(find.textContaining('+50 % XP'), findsOneWidget);
    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();

    AppSnapshot snapshot = await repository.snapshot();
    expect(snapshot.challenge!.goal.trainingPlanEnabled, isFalse);
    expect(snapshot.plan?.training, isNull);
    expect(snapshot.me.workoutLogOn(DayKey.today()), isNotNull);

    // The way back: the tab offers the plan, and saving switches it on.
    await tester.tap(find.text('Trainingsplan einschalten').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
              find.byKey(const Key('training-plan-switch')))
          .value,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();
    snapshot = await repository.snapshot();
    expect(snapshot.challenge!.goal.trainingPlanEnabled, isTrue);
    expect(snapshot.plan?.training, isNotNull);
    expect(find.byKey(const Key('edit-training-plan')), findsOneWidget);
  });

  testWidgets('without a gym habit, cardio follows the plan\'s days',
      (WidgetTester tester) async {
    final Challenge challenge = Challenge(
      id: 'run',
      goal: const Goal(
        archetype: GoalArchetype.getFit,
        statement: 'Fitter werden',
        trainingDaysPerWeek: 3,
      ),
      habits: <Habit>[
        Habit.fromCategory(HabitCategory.cardio).copyWith(daysPerWeek: 3),
        Habit.fromCategory(HabitCategory.reading),
      ],
      startDay: DayKey.today(),
    );
    await repository.startChallenge(challenge);
    await pump(tester, _opener(TrainingEditorScreen(challenge: challenge)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('4×'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();

    final Challenge saved = (await repository.snapshot()).challenge!;
    expect(saved.goal.trainingDaysPerWeek, 4);
    expect(trainingHabitOf(saved.habits)!.category, HabitCategory.cardio);
    expect(trainingHabitOf(saved.habits)!.daysPerWeek, 4);
    expect(
      saved.habits
          .firstWhere((Habit h) => h.category == HabitCategory.reading)
          .daysPerWeek,
      challenge.habits.last.daysPerWeek,
    );
  });

  testWidgets('a session with no exercise is not saved',
      (WidgetTester tester) async {
    final Challenge fit = _fitChallenge();
    final TrainingSetup suggested = suggestTrainingSetup(fit.goal);
    final Challenge challenge = fit.copyWith(
      goal: fit.goal.copyWith(
        training: suggested.withSession(
          1,
          suggested.sessions[1].copyWith(exercises: const <ExerciseSlot>[]),
        ),
      ),
    );
    await repository.startChallenge(challenge);
    await pump(tester, _opener(TrainingEditorScreen(challenge: challenge)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Jede Einheit braucht mindestens eine Übung'),
        findsOneWidget);
    expect(find.byType(TrainingEditorScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('session-1')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(
      tester.widget<AppCard>(find.byKey(const Key('session-1'))).border,
      AppColors.danger,
    );
    expect(tester.widget<AppCard>(find.byKey(const Key('session-0'))).border,
        isNull);
  });

  testWidgets('a workout with nothing in it says so instead of hanging',
      (WidgetTester tester) async {
    await repository.startChallenge(_fitChallenge());
    await pump(
      tester,
      WorkoutLoggerScreen(
        workout: const Workout(
          kind: WorkoutKind.upper,
          weekday: DateTime.monday,
          estimatedMinutes: 10,
          blocks: <PlannedSet>[],
        ),
        day: DayKey.today(),
      ),
    );
    expect(find.byKey(const Key('logger-empty')), findsOneWidget);
    expect(find.byKey(const Key('finish-workout')), findsNothing);
    expect(find.text('Split und Übungen bearbeiten'), findsOneWidget);
  });

  testWidgets('tapping the split already chosen is not a new choice',
      (WidgetTester tester) async {
    final List<SplitKind> picked = <SplitKind>[];
    await pump(
      tester,
      SingleChildScrollView(
        child: SplitPicker(
          daysPerWeek: 3,
          selected: SplitKind.fullBody,
          onSelected: picked.add,
        ),
      ),
    );
    await tester.tap(find.byKey(Key('split-${SplitKind.fullBody.name}')));
    await tester.tap(find.byKey(Key('split-${SplitKind.upperLower.name}')));
    expect(picked, <SplitKind>[SplitKind.upperLower]);
  });

  testWidgets('hiding a habit keeps its check-ins private from then on',
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
        await repository.store.eventsOf(repository.userId);
    expect(raw.last.visibility, EventVisibility.private);
    final UserProjection asFriend = projectUser(
      repository.userId,
      raw.where((FeedEvent e) => e.visibility == EventVisibility.friends).toList(),
    );
    expect(asFriend.challenge!.habits.map((Habit h) => h.id), <String>['gym']);
    expect(asFriend.challenge!.goal.statement, isEmpty);
    expect(asFriend.profile.goalStatement, isNull);
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('the plan opens on the current week, not on week 1',
      (WidgetTester tester) async {
    await repository.startChallenge(
        _fitChallenge().copyWith(startDay: DayKey.today().addDays(-21)));
    phone(tester);
    await tester.pumpWidget(
        wrapForTest(repository: repository, child: const PlanScreen()));
    await tester.pumpAndSettle();

    const Rect screen = Rect.fromLTWH(0, 0, 390, 844);
    expect(screen.contains(tester.getCenter(find.text('Woche 4'))), isTrue);
    expect(screen.contains(tester.getCenter(find.text('AKTUELL'))), isTrue);
    final Finder week1 = find.text('Woche 1');
    expect(
      week1.evaluate().isEmpty || !screen.contains(tester.getCenter(week1)),
      isTrue,
    );

    // The earlier weeks and the plan's header are above: a scroll up
    // brings week 3 in, all the way up the header and week 1.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('Woche 3'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 20000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit-training-plan')), findsOneWidget);
    expect(find.text('Woche 1'), findsOneWidget);
  });

  // Last in the file: it loads the real text font, which the tests above
  // do not expect.
  testWidgets('every sub-tab fits a 390 px phone; large text scrolls',
      (WidgetTester tester) async {
    await _loadTextFont();
    phone(tester);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final Locale locale in const <Locale>[Locale('de'), Locale('en')]) {
      final AppLocalizations l10n = await localizationsFor(locale);
      // Every tab the plan can have at once.
      final List<String> labels = <String>[
        l10n.planTabTraining,
        l10n.planTabMeals,
        l10n.planTabShopping,
        l10n.planTabAbstinence,
      ];
      for (final double scale in const <double>[1.0, 1.3, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: DefaultTabController(
              length: labels.length,
              child: PlanTabBar(labels: labels),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final Rect bar = tester.getRect(find.byType(TabBar));
        bool whole(int i) {
          final Rect tab = tester.getRect(find.byType(Tab).at(i));
          return tab.left >= bar.left - 0.5 && tab.right <= bar.right + 0.5;
        }

        if (scale == 1.0) {
          for (int i = 0; i < labels.length; i++) {
            expect(whole(i), isTrue, reason: '$locale: ${labels[i]} is cut');
          }
        }
        // Whatever the text size, the chosen tab is never cut.
        for (int i = 0; i < labels.length; i++) {
          DefaultTabController.of(tester.element(find.byType(TabBar)))
              .animateTo(i);
          await tester.pumpAndSettle();
          expect(whole(i), isTrue, reason: '$locale ×$scale: ${labels[i]}');
        }
      }
    }
  });
}

/// The tab bar fits itself by measuring its labels, and the test font is
/// one wide square per glyph; this loads the real one.
Future<void> _loadTextFont() async {
  final FontLoader loader = FontLoader(kTextFont);
  for (final String weight in <String>['Bold', 'ExtraBold']) {
    final Uint8List bytes =
        File('assets/fonts/Manrope-$weight.ttf').readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}
