import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/l10n/l10n.dart';
import 'package:hundred_days/state/onboarding_state.dart';
import 'package:hundred_days/state/providers.dart';
import 'package:hundred_days/ui/onboarding/onboarding_flow.dart';

import 'package:hundred_days/data/locale_store.dart';

import 'helpers.dart';

void main() {
  late AppRepository repository;

  setUp(() async {
    repository = await testRepository();
  });

  /// Scrolls to the target before tapping: the onboarding steps are long
  /// enough that a naive tap lands off-screen and silently does nothing.
  Future<void> tapText(WidgetTester tester, String text) async {
    final Finder finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Weiter'));
    await tester.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('de'),
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        repositoryProvider.overrideWithValue(repository),
        ...platformFreeOverrides(),
      ],
      child: MaterialApp(
        builder: reducedMotion,
        locale: locale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const OnboardingFlow(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the manifesto and can advance',
      (WidgetTester tester) async {
    await pump(tester);

    expect(find.textContaining('Du brauchst kein neues Ich'), findsOneWidget);
    expect(find.text('Weiter'), findsOneWidget);

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();

    expect(find.text('Worum geht es?'), findsOneWidget);
  });

  testWidgets('runs in English when the system language is English',
      (WidgetTester tester) async {
    await pump(tester, locale: const Locale('en'));

    expect(find.textContaining('You do not need a new you'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('What is this about?'), findsOneWidget);
    expect(find.text('Build discipline'), findsOneWidget);
    // No stray German left on a translated screen.
    expect(find.text('Disziplin aufbauen'), findsNothing);
  });

  testWidgets('cannot advance past the goal step without picking one',
      (WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();

    final Finder next = find.widgetWithText(FilledButton, 'Weiter');
    expect(tester.widget<FilledButton>(next).onPressed, isNull);

    await tapText(tester, 'Disziplin aufbauen');

    expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
  });

  testWidgets('choosing a goal preselects the habits it implies',
      (WidgetTester tester) async {
    await pump(tester);
    await next(tester);
    await tapText(tester, 'Kopf frei kriegen');

    final OnboardingDraft draft = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingFlow)),
    ).read(onboardingProvider);

    expect(
      draft.selectedHabits,
      containsAll(goalInfo(GoalArchetype.clarity).suggestedHabits),
    );
  });

  testWidgets('a body-stats goal asks for body stats, a mindset goal does not',
      (WidgetTester tester) async {
    await pump(tester);
    await next(tester);
    await tapText(tester, 'Fett verlieren');
    await next(tester);
    await tester.enterText(
        find.byKey(const Key('statement-field')), '8 kg runter');
    await tester.pumpAndSettle();
    await next(tester);
    // Habits -> training, because fat loss suggests gym and cardio.
    await next(tester);
    expect(find.text('Wie oft und womit?'), findsOneWidget);

    // The training plan is on by default, so the split comes next.
    await next(tester);
    expect(find.text('Dein Split.'), findsOneWidget);

    // Fat loss also switches the nutrition plan on, which needs body stats.
    await next(tester);
    expect(find.text('Ein paar Zahlen.'), findsOneWidget);

    await next(tester);
    expect(find.text('Dein Tagesziel.'), findsOneWidget);
  });

  testWidgets('without the optional plans there is no split and no weighing',
      (WidgetTester tester) async {
    await pump(tester);
    await next(tester);
    await tapText(tester, 'Fett verlieren');
    await next(tester);
    await tester.enterText(
        find.byKey(const Key('statement-field')), '8 kg runter');
    await tester.pumpAndSettle();
    await next(tester);

    // Both plans are opt-in, right on the habit rows.
    for (final String key in <String>['plan-gym', 'plan-nutrition']) {
      final Finder toggle = find.byKey(Key(key));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
    }
    final OnboardingDraft draft = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingFlow)),
    ).read(onboardingProvider);
    expect(draft.usesTrainingPlan, isFalse);
    expect(draft.usesNutritionPlan, isFalse);

    await next(tester); // habits -> training (days only)
    expect(find.text('Wie oft und womit?'), findsOneWidget);
    await next(tester); // training -> privacy, no split, no body stats
    expect(find.text('Wer sieht was.'), findsOneWidget);
  });

  testWidgets('the split step proposes exercises that can be swapped',
      (WidgetTester tester) async {
    await pump(tester);
    await next(tester);
    await tapText(tester, 'Muskeln aufbauen');
    await next(tester);
    await tester.enterText(
        find.byKey(const Key('statement-field')), '5 kg Muskeln');
    await tester.pumpAndSettle();
    await next(tester); // statement -> habits
    await next(tester); // habits -> training
    await next(tester); // training -> split
    expect(find.text('Dein Split.'), findsOneWidget);

    await tapText(tester, 'Push / Pull / Beine');
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingFlow)),
    );
    expect(container.read(onboardingProvider).effectiveSplit,
        SplitKind.pushPullLegs);

    // Open the first exercise of the first session and swap it.
    final String first = container
        .read(onboardingProvider)
        .currentTrainingSetup()
        .sessions
        .first
        .exercises
        .first
        .exerciseId;
    expect(first, 'bench_press');
    await tapText(tester, 'Bankdrücken');
    final Finder swap =
        find.widgetWithText(ActionChip, 'Kurzhantel-Bankdrücken');
    await tester.ensureVisible(swap);
    await tester.pumpAndSettle();
    await tester.tap(swap);
    await tester.pumpAndSettle();
    final Finder save = find.widgetWithText(FilledButton, 'Speichern');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final TrainingSetup setup =
        container.read(onboardingProvider).currentTrainingSetup();
    expect(setup.sessions.first.exercises.first.exerciseId, 'db_bench');
    expect(setup.split, SplitKind.pushPullLegs);
  });

  test('a plan edited in onboarding keeps its edits when moving home', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final OnboardingController c = container.read(onboardingProvider.notifier);
    c.chooseArchetype(GoalArchetype.buildMuscle);
    OnboardingDraft draft() => container.read(onboardingProvider);
    expect(draft().usesTrainingPlan, isTrue);

    final TrainingSetup suggested = draft().currentTrainingSetup();
    final ExerciseSlot first = suggested.sessions.first.exercises.first;
    expect(first.exercise!.availableWith(EquipmentAccess.homeBasic), isFalse);
    c.setTrainingSetup(suggested.withSession(
      0,
      suggested.sessions.first.copyWith(exercises: <ExerciseSlot>[
        first.copyWith(sets: first.sets + 1),
        ...suggested.sessions.first.exercises.skip(1),
      ]),
    ));

    c.setEquipment(EquipmentAccess.homeBasic);
    final TrainingSetup moved = draft().currentTrainingSetup();
    expect(moved.split, suggested.split);
    final ExerciseSlot swapped = moved.sessions.first.exercises.first;
    expect(swapped.exercise!.availableWith(EquipmentAccess.homeBasic), isTrue);
    expect(swapped.exercise!.pattern, first.exercise!.pattern);
    expect(swapped.sets, first.sets + 1);
  });

  test('an untouched plan follows the answers, also after Funki is undone',
      () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final OnboardingController c = container.read(onboardingProvider.notifier);
    c.chooseArchetype(GoalArchetype.buildMuscle);
    OnboardingDraft draft() => container.read(onboardingProvider);
    final TrainingSetup before = draft().currentTrainingSetup();

    // Funki's plan, then back to the suggestion it replaced.
    c.setTrainingPlan(
      EquipmentAccess.bodyweight,
      suggestTrainingSetup(
        draft().toGoal().copyWith(equipment: EquipmentAccess.bodyweight),
        split: SplitKind.pushPullLegs,
      ),
    );
    expect(draft().equipment, EquipmentAccess.bodyweight);
    c.setTrainingPlan(EquipmentAccess.fullGym, before);
    expect(draft().trainingSetup, isNull);

    c.setTrainingDays(3);
    expect(draft().currentTrainingSetup().split, recommendedSplit(3));
  });

  testWidgets('completing the flow writes the challenge to the feed',
      (WidgetTester tester) async {
    await pump(tester);

    await next(tester); // welcome -> goal
    await tapText(tester, 'Clean bleiben');
    await next(tester); // goal -> statement
    await tester.enterText(
        find.byKey(const Key('statement-field')), '100 Tage trocken');
    await tester.pumpAndSettle();
    await next(tester); // statement -> habits
    await next(tester); // habits -> privacy
    expect(find.text('Wer sieht was.'), findsOneWidget);
    // "Clean bleiben" has no nutrition plan: the AI page is skipped.
    await next(tester); // privacy -> identity
    expect(find.text('KI, die mitdenkt.'), findsNothing);
    await tester.enterText(find.byKey(const Key('name-field')), 'Mike');
    await tester.pumpAndSettle();
    await next(tester); // identity -> summary

    expect(find.text('Challenge starten'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Challenge starten'));
    // Not pumpAndSettle: the submit button shows an indeterminate spinner,
    // which never "settles".
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final List<FeedEvent> events =
        await repository.store.eventsOf(repository.userId);
    expect(
      events.map((FeedEvent e) => e.type),
      containsAll(<String>[
        FeedEventType.profile,
        FeedEventType.challengeStarted,
      ]),
    );

    // Written to this device first, waiting for the sync to send them —
    // so a challenge started without a signal is not lost.
    expect(events.every((FeedEvent e) => e.isPending), isTrue);
    expect(
      await repository.store.pending(repository.userId),
      hasLength(events.length),
    );

    final snapshot = await repository.snapshot();
    expect(snapshot.hasChallenge, isTrue);
    expect(snapshot.me.profile.displayName, 'Mike');
    expect(snapshot.challenge!.goal.statement, '100 Tage trocken');
  });
}
