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

    // Being findable is the user's call: the box starts empty.
    final Finder alsoFindMe = find.byType(CheckboxListTile);
    expect(tester.widget<CheckboxListTile>(alsoFindMe).value, isFalse);
    await tester.tap(alsoFindMe);
    await tester.pump();

    await tester.tap(find.byKey(const Key('find-contacts')));
    await tester.pumpAndSettle();
    expect(find.text('Marcel'), findsOneWidget);
    expect((await social.settings()).findable, isTrue);
    // No phone numbers go out while nobody's number can be matched.
    expect(social.matchedPhones, isEmpty);
  });

  testWidgets('looking through the address book alone does not make me findable',
      (WidgetTester tester) async {
    social.people.add(const PersonResult(userId: 'marcel', displayName: 'Marcel', emoji: '🦍'));
    await pump(
      tester,
      const FindFriendsScreen(),
      overrides: <Override>[
        addressBookProvider.overrideWithValue(
            () async => (emails: <String>['marcel@example.org'], phones: <String>[])),
      ],
    );

    await tester.tap(find.byKey(const Key('find-contacts')));
    await tester.pumpAndSettle();
    expect(find.text('Marcel'), findsOneWidget);
    expect((await social.settings()).findable, isFalse);
  });

  Future<void> searchLena(WidgetTester tester) async {
    social.people.add(const PersonResult(
        userId: 'lena', displayName: 'Lena', emoji: '🦊', username: 'lena_lifts'));
    await pump(tester, const FindFriendsScreen());
    await tester.enterText(find.byKey(const Key('find-search')), '@lena');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('an add that did not reach the server says so and comes back',
      (WidgetTester tester) async {
    await searchLena(tester);
    social.offline = true;
    await tester.tap(find.widgetWithText(FilledButton, 'Hinzufügen'));
    await tester.pumpAndSettle();

    expect(find.text('Angefragt'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Hinzufügen'), findsOneWidget);
    expect(find.text('Keine Verbindung zum Server. Versuch es gleich noch einmal.'),
        findsOneWidget);
  });

  testWidgets('a request the server turns down says why',
      (WidgetTester tester) async {
    await searchLena(tester);
    social.refuseRequests = FriendRequestProblem.declinedRecently;
    await tester.tap(find.widgetWithText(FilledButton, 'Hinzufügen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('vor Kurzem abgelehnt'), findsOneWidget);
    expect(find.text('Angefragt'), findsNothing);

    social.refuseRequests = FriendRequestProblem.tooMany;
    await tester.tap(find.widgetWithText(FilledButton, 'Hinzufügen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Für heute reicht'), findsOneWidget);
  });

  testWidgets('someone found can be blocked right from the results',
      (WidgetTester tester) async {
    await searchLena(tester);
    await tester.tap(find.byKey(const Key('person-more-lena')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('person-block')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('block-confirm')));
    await tester.pumpAndSettle();

    expect(social.blocked.keys, <String>['lena']);
    expect(find.text('@lena_lifts'), findsNothing);
    expect(await social.search('lena'), isEmpty);
  });

  testWidgets('a friend\'s profile shows the streak and quest we share',
      (WidgetTester tester) async {
    final String friend = await seedFriend(repository, name: 'Marcel', emoji: '🦍', daysBack: 3);
    final AppSnapshot snapshot = await repository.snapshot();
    await pump(
      tester,
      TogetherCard(
        me: snapshot.meAsFriendsSeeMe,
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

  test('a report the server did not count is sent again', () async {
    final AppSnapshot snapshot = await repository.snapshot();
    final String week = snapshot.today.isoWeekKey;
    social.refusedWeeks.add(week);
    await repository.reportLeagueXp(snapshot);
    expect(social.reportedXp, isEmpty);

    social.refusedWeeks.clear();
    await repository.reportLeagueXp(snapshot);
    expect(social.reportedXp.keys, <String>[week]);
  });

  test('a nudge asks the server to tell its target', () async {
    final FeedEvent nudge = await repository.nudge('marcel', 'Hopp!');
    await repository.notifyFriends(nudge);
    expect(social.notified, <String>[nudge.id]);
  });
}
