import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/ui/home/home_screen.dart';
import 'package:hundred_days/ui/widgets/habit_tile.dart';
import 'package:hundred_days/ui/widgets/pressure_banner.dart';
import 'package:hundred_days/ui/widgets/streak_ring.dart';

import 'helpers.dart';

void main() {
  late AppRepository repository;

  Future<void> startChallenge({
    List<HabitCategory> habits = const <HabitCategory>[
      HabitCategory.noSugar,
      HabitCategory.reading,
    ],
  }) async {
    await repository.saveProfile(displayName: 'Mike', avatarEmoji: '🐺');
    await repository.startChallenge(testChallenge(habits: habits));
  }

  setUp(() async {
    repository = await testRepository();
  });

  Future<void> pump(WidgetTester tester) async {
    // A tall phone viewport: the home screen is a scroll view, and the default
    // 800x600 test surface would leave half the habits unbuilt.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapForTest(
      repository: repository,
      child: const HomeScreen(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the streak ring and today\'s habits',
      (WidgetTester tester) async {
    await startChallenge();
    await pump(tester);

    expect(find.byType(StreakRing), findsOneWidget);
    expect(find.text('Tag 1 / 100'), findsOneWidget);
    expect(find.byType(HabitTile), findsNWidgets(2));
    expect(find.text('Kein Zucker'), findsOneWidget);
    expect(find.text('Lesen'), findsOneWidget);
  });

  testWidgets('checking in writes a signed event and updates the tile',
      (WidgetTester tester) async {
    await startChallenge(habits: <HabitCategory>[HabitCategory.noSugar]);
    await pump(tester);

    final Finder button = find.widgetWithText(FilledButton, 'Heute clean');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    final List<FeedEvent> all =
        await repository.store.eventsOf(repository.did);
    final List<FeedEvent> checkIns = all
        .where((FeedEvent e) => e.type == FeedEventType.checkIn)
        .toList();
    expect(checkIns, hasLength(1));
    expect(checkIns.single.payload['habitId'], 'noSugar');

    // The whole chain has to verify, not just the new link: that is what a
    // friend's device will do when it replicates this feed.
    for (int i = 0; i < all.length; i++) {
      final EventValidationResult result = await validateEvent(
        all[i],
        previous: i == 0 ? null : all[i - 1],
      );
      expect(result.isValid, isTrue, reason: 'event ${all[i].type} at $i');
    }

    expect(find.widgetWithText(FilledButton, 'Erledigt'), findsOneWidget);
  });

  testWidgets('a completed day is reflected in the streak',
      (WidgetTester tester) async {
    await startChallenge(habits: <HabitCategory>[HabitCategory.noSugar]);
    await pump(tester);

    expect(find.text('0'), findsWidgets);

    final Finder button = find.widgetWithText(FilledButton, 'Heute clean');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    final AppSnapshot snapshot = await repository.snapshot();
    expect(snapshot.me.streak.doneToday, isTrue);
    expect(snapshot.me.streak.current, 1);
    expect(snapshot.me.lifetimeXp, greaterThan(0));
  });

  testWidgets('names the friends who already trained today',
      (WidgetTester tester) async {
    await startChallenge();
    await seedFriend(repository, name: 'Marcel', emoji: '🦍');
    await pump(tester);

    expect(find.byType(PressureBanner), findsOneWidget);
    expect(find.textContaining('Marcel'), findsWidgets);
    expect(
      find.textContaining('Du stehst heute noch auf null'),
      findsOneWidget,
    );
  });

  testWidgets('shows no pressure banner when nobody has been active',
      (WidgetTester tester) async {
    await startChallenge();
    await seedFriend(
      repository,
      name: 'Lisa',
      emoji: '🦊',
      inactiveDays: 1,
    );
    await pump(tester);

    expect(
      find.descendant(
        of: find.byType(PressureBanner),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });

  testWidgets('the coach speaks on the home screen',
      (WidgetTester tester) async {
    await startChallenge();
    await pump(tester);

    expect(find.text('COACH'), findsOneWidget);
    expect(find.textContaining('Tag 1 von 100'), findsWidgets);
  });

  testWidgets('rest days are labelled instead of shown as failures',
      (WidgetTester tester) async {
    // Gym runs four days a week (Mon, Tue, Thu, Fri), so whether today is a
    // training day depends on the calendar — assert whichever case applies.
    await startChallenge(habits: <HabitCategory>[HabitCategory.gym]);
    await pump(tester);

    final bool isTrainingDay = const <int>[
      DateTime.monday,
      DateTime.tuesday,
      DateTime.thursday,
      DateTime.friday,
    ].contains(DayKey.today().toDateTime().weekday);

    if (isTrainingDay) {
      expect(find.byType(HabitTile), findsWidgets);
      expect(find.textContaining('Pausentag'), findsNothing);
    } else {
      expect(find.textContaining('Pausentag laut Plan'), findsOneWidget);
      // The habit is still offered as an optional extra rather than hidden.
      expect(find.text('Freiwillig'), findsOneWidget);
    }
  });
}
