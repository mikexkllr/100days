import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/ui/social/social_screen.dart';

import 'helpers.dart';

void main() {
  late AppRepository repository;

  setUp(() async {
    repository = await testRepository();
    await repository.saveProfile(displayName: 'Mike', avatarEmoji: '🐺');
    await repository.startChallenge(
      testChallenge(startDay: DayKey.today().addDays(-5)),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapForTest(
      repository: repository,
      child: const SocialScreen(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('an empty feed explains itself', (WidgetTester tester) async {
    await pump(tester);
    expect(find.text('Feed'), findsOneWidget);
    // Only the challenge start is on the feed so far.
    expect(find.textContaining('hat die Challenge gestartet'), findsOneWidget);
  });

  testWidgets('a friend\'s check-in shows up with a verified badge',
      (WidgetTester tester) async {
    await seedFriend(repository, name: 'Marcel', emoji: '🦍');
    await pump(tester);

    expect(find.textContaining('Marcel'), findsWidgets);
    expect(find.text('VERIFIZIERT'), findsWidgets);
  });

  testWidgets('the league ranks friends by weekly XP',
      (WidgetTester tester) async {
    await seedFriend(repository, name: 'Marcel', emoji: '🦍', daysBack: 6);
    await seedFriend(repository, name: 'Lisa', emoji: '🦊', daysBack: 2);
    await pump(tester);

    await tester.tap(find.text('Liga'));
    await tester.pumpAndSettle();

    final AppSnapshot snapshot = await repository.snapshot();
    final List<String> order = snapshot.league.entries
        .map((LeagueEntry e) => e.displayName)
        .toList();

    // Mike logged nothing, so both friends outrank him.
    expect(order.last, 'Mike');
    expect(order.first, 'Marcel');
    expect(find.text('Marcel'), findsWidgets);
  });

  testWidgets('friends who skipped today get a ready-made nudge',
      (WidgetTester tester) async {
    await seedFriend(
      repository,
      name: 'Lisa',
      emoji: '🦊',
      inactiveDays: 2,
    );
    await pump(tester);

    await tester.tap(find.textContaining('Freunde'));
    await tester.pumpAndSettle();

    expect(find.text('Anstupsen'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Senden'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Senden'));
    await tester.pumpAndSettle();

    final List<FeedEvent> nudges = await repository.store.eventsOf(
      repository.userId,
      types: <String>{FeedEventType.nudge},
    );
    expect(nudges, hasLength(1));
    expect(nudges.single.payload['target'], isNotNull);
    expect(find.text('Gesendet'), findsOneWidget);
  });

  testWidgets('with no friends the app says so instead of faking a crowd',
      (WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.textContaining('Freunde'));
    await tester.pumpAndSettle();

    expect(find.text('Noch niemand verbunden'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Einladen'), findsOneWidget);
  });

  testWidgets('a friend\'s streak is computed from their events, not claimed',
      (WidgetTester tester) async {
    final String friend =
        await seedFriend(repository, name: 'Marcel', emoji: '🦍');
    final List<FeedEvent> events = await repository.store.eventsOf(friend);
    expect(events, isNotEmpty);

    final AppSnapshot snapshot = await repository.snapshot();
    final UserProjection projection =
        snapshot.friends.firstWhere((UserProjection f) => f.userId == friend);
    expect(projection.streak.current, 6);
  });

  testWidgets('an ended friendship takes their feed off this device',
      (WidgetTester tester) async {
    final String friend =
        await seedFriend(repository, name: 'Marcel', emoji: '🦍');
    await repository.removeFriend(friend);
    expect(await repository.store.eventsOf(friend), isEmpty);
    expect((await repository.snapshot()).friends, isEmpty);
  });
}
