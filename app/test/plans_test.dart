import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/l10n/l10n.dart';
import 'package:hundred_days/ui/nutrition/diary_view.dart';
import 'package:hundred_days/ui/plan/plan_screen.dart';
import 'package:hundred_days/ui/plan/session_editor.dart';
import 'package:hundred_days/ui/plan/training_editor.dart';
import 'package:hundred_days/ui/plan/workout_draft.dart';
import 'package:hundred_days/ui/plan/workout_logger.dart';
import 'package:hundred_days/ui/settings/privacy_screen.dart';
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
      ) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrapForTest(
      repository: repository,
      child: child,
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
}
