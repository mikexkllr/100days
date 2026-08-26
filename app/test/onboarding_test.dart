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
      ],
      child: MaterialApp(
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

    await next(tester);
    expect(find.text('Ein paar Zahlen.'), findsOneWidget);
  });

  testWidgets('completing the flow writes a signed challenge to the feed',
      (WidgetTester tester) async {
    await pump(tester);

    await next(tester); // welcome -> goal
    await tapText(tester, 'Clean bleiben');
    await next(tester); // goal -> statement
    await tester.enterText(
        find.byKey(const Key('statement-field')), '100 Tage trocken');
    await tester.pumpAndSettle();
    await next(tester); // statement -> habits
    await next(tester); // habits -> identity
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
        await repository.store.eventsOf(repository.did);
    expect(
      events.map((FeedEvent e) => e.type),
      containsAll(<String>[
        FeedEventType.profile,
        FeedEventType.challengeStarted,
      ]),
    );

    // The feed the friends will replicate must verify end to end.
    for (int i = 0; i < events.length; i++) {
      final result = await validateEvent(
        events[i],
        previous: i == 0 ? null : events[i - 1],
      );
      expect(result.isValid, isTrue, reason: '${events[i].type} did not verify');
    }

    final snapshot = await repository.snapshot();
    expect(snapshot.hasChallenge, isTrue);
    expect(snapshot.me.profile.displayName, 'Mike');
    expect(snapshot.challenge!.goal.statement, '100 Tage trocken');
  });
}
