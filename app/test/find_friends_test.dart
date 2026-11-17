import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/phone_numbers.dart';
import 'package:hundred_days/data/social_backend.dart';
import 'package:hundred_days/ui/social/find_friends_screen.dart';
import 'package:hundred_days/ui/social/together_card.dart';

import 'helpers.dart';

void main() {
  group('phone numbers', () {
    test('become E.164 in the phone\'s region', () {
      expect(toE164('0151 2345 678', countryCode: 'DE'), '+491512345678');
      expect(toE164('+49 (151) 234-5678', countryCode: 'US'), '+491512345678');
      expect(toE164('0049 151 2345678', countryCode: 'DE'), '+491512345678');
      expect(toE164('(415) 555-0132', countryCode: 'US'), '+14155550132');
      expect(toE164('0151 2345678', countryCode: 'XX'), isNull);
      expect(toE164('112', countryCode: 'DE'), isNull);
    });
  });

  late AppRepository repository;
  late MemorySocialBackend social;

  setUp(() async {
    repository = await testRepository();
    social = repository.social as MemorySocialBackend;
    await repository.startChallenge(testChallenge());
  });

  Future<void> pump(WidgetTester tester, Widget child, {List<Override> overrides = const <Override>[]}) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrapForTest(repository: repository, child: child, overrides: overrides));
    await tester.pumpAndSettle();
  }

  testWidgets('search finds people by username and sends a request',
      (WidgetTester tester) async {
    social.people.add(const PersonResult(
        userId: 'lena', displayName: 'Lena', emoji: '🦊', username: 'lena_lifts'));
    await pump(tester, const FindFriendsScreen());

    await tester.enterText(find.byKey(const Key('find-search')), '@lena');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('@lena_lifts'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Hinzufügen'));
    await tester.pumpAndSettle();
    expect(find.text('Angefragt'), findsOneWidget);
    expect(social.notified, contains('request:lena'));
  });

  testWidgets('the address book finds who is findable, and makes me findable',
      (WidgetTester tester) async {
    social.people.add(const PersonResult(userId: 'marcel', displayName: 'Marcel', emoji: '🦍'));
    await pump(
      tester,
      const FindFriendsScreen(),
      overrides: <Override>[
        addressBookProvider.overrideWithValue(() async =>
            (emails: <String>['marcel@example.org'], phones: <String>['+491512345678'])),
      ],
    );

    await tester.tap(find.byKey(const Key('find-contacts')));
    await tester.pumpAndSettle();
    expect(find.text('Marcel'), findsOneWidget);
    expect((await social.settings()).findable, isTrue);
  });

  testWidgets('a friend\'s profile shows the streak and quest we share',
      (WidgetTester tester) async {
    final String friend = await seedFriend(repository, name: 'Marcel', emoji: '🦍', daysBack: 3);
    final AppSnapshot snapshot = await repository.snapshot();
    await pump(
      tester,
      TogetherCard(
        me: snapshot.me,
        friend: snapshot.friends.firstWhere((UserProjection f) => f.userId == friend),
        today: snapshot.today,
      ),
    );
    expect(find.textContaining('Starte einen Streak mit Marcel'), findsOneWidget);
    expect(find.textContaining('Quest diese Woche'), findsOneWidget);
  });

  test('the week\'s XP goes to the public league once per change', () async {
    final AppSnapshot snapshot = await repository.snapshot();
    await repository.reportLeagueXp(snapshot);
    await repository.reportLeagueXp(snapshot);
    expect(social.reportedXp.keys, <String>[snapshot.today.isoWeekKey]);
  });

  test('a nudge asks the server to tell its target', () async {
    final FeedEvent nudge = await repository.nudge('marcel', 'Hopp!');
    await repository.notifyFriends(nudge);
    expect(social.notified, <String>[nudge.id]);
  });
}
