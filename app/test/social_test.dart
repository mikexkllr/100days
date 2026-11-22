import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/social_backend.dart';
import 'package:hundred_days/state/providers.dart';
import 'package:hundred_days/ui/settings/social_settings_screen.dart';
import 'package:hundred_days/ui/social/friend_detail.dart';
import 'package:hundred_days/ui/social/friend_flame.dart';
import 'package:hundred_days/ui/social/league_tab.dart';
import 'package:hundred_days/ui/social/scan_screen.dart';
import 'package:hundred_days/ui/social/social_screen.dart';
import 'package:hundred_days/ui/mascot/mascot_mood.dart';

import 'helpers.dart';

void main() {
  late AppRepository repository;
  late MemorySocialBackend social;

  setUp(() async {
    repository = await testRepository();
    social = repository.social as MemorySocialBackend;
    await repository.saveProfile(displayName: 'Mike', avatarEmoji: '🐺');
    await repository.startChallenge(
      testChallenge(startDay: DayKey.today().addDays(-5)),
    );
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget child, {
    double height = 3000,
  }) async {
    tester.view.physicalSize = Size(1080, height);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapForTest(repository: repository, child: child));
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester) =>
      pumpScreen(tester, const SocialScreen());

  Future<void> openFriendsTab(WidgetTester tester) async {
    await tester.tap(find.textContaining('Freunde ('));
    await tester.pumpAndSettle();
  }

  AppController controllerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(appStateProvider.notifier);

  Future<List<FeedEvent>> myEvents(String type) =>
      repository.store.eventsOf(repository.userId, types: <String>{type});

  testWidgets('an empty feed explains itself', (WidgetTester tester) async {
    await pump(tester);
    expect(find.text('Feed'), findsOneWidget);
    // Only the challenge start is on the feed so far.
    expect(find.textContaining('hat die Challenge gestartet'), findsOneWidget);
  });

  group('the feed', () {
    testWidgets('a friend\'s day is one card, its habits as chips, cheered once',
        (WidgetTester tester) async {
      await seedFriend(repository, name: 'Marcel', emoji: '🦍', daysBack: 1);
      await pump(tester);

      // Two days of two habits each: two cards, not four.
      expect(find.text('Marcel: 2 Check-ins'), findsNWidgets(2));
      // Logged on the day is the rule; nothing says so on every card.
      expect(find.text('VERIFIZIERT'), findsNothing);
      expect(find.textContaining('nachgetragen'), findsNothing);

      final Finder cheer = find.widgetWithText(TextButton, 'Feiern');
      expect(cheer, findsNWidgets(2));
      await tester.tap(cheer.first);
      await tester.tap(cheer.first);
      await tester.pumpAndSettle();
      expect(await myEvents(FeedEventType.cheer), hasLength(1));
      expect(find.widgetWithText(TextButton, 'Gefeiert'), findsOneWidget);
    });

    testWidgets('only an entry made after its day is marked',
        (WidgetTester tester) async {
      final String friend =
          await seedFriend(repository, name: 'Marcel', emoji: '🦍', daysBack: 1);
      final DayKey yesterday = DayKey.today().addDays(-1);
      await FeedWriter(author: friend, store: repository.store).append(
        FeedEventType.checkIn,
        CheckIn(
          habitId: 'late',
          category: HabitCategory.water,
          day: yesterday,
          value: 1,
          loggedAt: DateTime.now(),
        ).toPayload(),
      );
      await pump(tester);

      expect(find.text('Marcel: 3 Check-ins'), findsOneWidget);
      expect(find.textContaining('nachgetragen'), findsOneWidget);
    });

    test('bundles by person and day, newest first, and cheers the newest', () {
      const DayKey today = DayKey(2026, 11, 20);
      final DayKey yesterday = today.addDays(-1);
      ActivityItem item(
        String id,
        String author,
        DayKey day,
        int hour, {
        ActivityKind kind = ActivityKind.checkIn,
        DayKey? writtenOn,
      }) =>
          ActivityItem(
            eventId: id,
            author: author,
            authorName: author,
            authorEmoji: '🙂',
            timestamp: (writtenOn ?? day).toDateTime().add(Duration(hours: hour)),
            emoji: '📖',
            kind: kind,
            isVerifiedLive: writtenOn == null,
            claimedDay: day,
            category: HabitCategory.reading,
          );

      final List<FeedCard> cards = groupActivity(<ActivityItem>[
        item('a4', 'anna', yesterday, 9, writtenOn: today),
        item('b1', 'ben', today, 8),
        item('a3', 'anna', today, 7, kind: ActivityKind.relapse),
        item('a2', 'anna', today, 6),
        ActivityItem(
          eventId: 'n1',
          author: 'ben',
          authorName: 'ben',
          authorEmoji: '🙂',
          timestamp: yesterday.toDateTime().add(const Duration(hours: 22)),
          emoji: '👀',
          kind: ActivityKind.nudge,
          isVerifiedLive: true,
        ),
        item('a1', 'anna', yesterday, 20),
      ]);

      expect(
        cards.map((FeedCard c) => c.items.map((ActivityItem i) => i.eventId)),
        <List<String>>[
          <String>['a4', 'a1'],
          <String>['b1'],
          <String>['a3', 'a2'],
          <String>['n1'],
        ],
      );
      expect(cards[0].cheerable?.eventId, 'a4');
      // A relapse is not cheered; the check-in before it is.
      expect(cards[2].cheerable?.eventId, 'a2');
      expect(cards[3].isDay, isFalse);
    });
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
    // Nothing promotes among friends, and the footer no longer says so.
    final Finder footer = find.textContaining('steigt niemand auf oder ab');
    await tester.scrollUntilVisible(footer, 300,
        scrollable: find
            .descendant(
                of: find.byType(LeagueTab), matching: find.byType(Scrollable))
            .first);
    expect(footer, findsOneWidget);
    expect(find.textContaining('Am Sonntag'), findsNothing);
  });

  group('the public league card', () {
    testWidgets('fetches when the XP changes, after reporting it',
        (WidgetTester tester) async {
      final String friend =
          await seedFriend(repository, name: 'Marcel', emoji: '🦍');
      await pump(tester);
      await tester.tap(find.text('Liga'));
      await tester.pumpAndSettle();
      expect(social.leagueFetches, 1);
      expect(find.byKey(const Key('global-league')), findsOneWidget);

      // A nudge changes the app state, not the XP: nothing is refetched.
      await controllerOf(tester).nudge(friend, 'Hopp');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(social.leagueFetches, 1);

      // A check-in does, and the standing already carries its XP.
      final Habit habit = (await repository.snapshot()).challenge!.habits.first;
      await controllerOf(tester).checkIn(habit);
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(social.leagueFetches, 2);
      final int xp = social.reportedXp[DayKey.today().isoWeekKey]!;
      expect(xp, greaterThan(0));
      expect(find.text('$xp XP'), findsWidgets);
    });

    testWidgets('a stranger in the group can be reported',
        (WidgetTester tester) async {
      social.leagueOthers.add(const GlobalLeagueRow(
          userId: 'troll', displayName: 'xXTrollXx', emoji: '👹', xp: 900, rank: 1));
      await pump(tester);
      await tester.tap(find.text('Liga'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('league-row-troll')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('person-report')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-inappropriate')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('report-send')));
      await tester.pumpAndSettle();

      expect(social.reports.single.$1, 'troll');
      expect(social.reports.single.$2, ReportReason.inappropriate);
      expect(find.text('Danke. Deine Meldung ist angekommen.'), findsOneWidget);
      expect(social.blocked, isEmpty);
    });
  });

  group('friends', () {
    testWidgets('friends who skipped today get a ready-made nudge, sent once',
        (WidgetTester tester) async {
      await seedFriend(
        repository,
        name: 'Lisa',
        emoji: '🦊',
        inactiveDays: 2,
      );
      await pump(tester);
      await openFriendsTab(tester);

      expect(find.text('Anstupsen'), findsOneWidget);
      final Finder send = find.widgetWithText(FilledButton, 'Senden');
      expect(send, findsOneWidget);

      await tester.tap(send);
      await tester.tap(send);
      await tester.pumpAndSettle();

      final List<FeedEvent> nudges = await myEvents(FeedEventType.nudge);
      expect(nudges, hasLength(1));
      expect(nudges.single.payload['target'], isNotNull);
      expect(find.text('Gesendet'), findsOneWidget);
    });

    testWidgets('with no friends the app says so instead of faking a crowd',
        (WidgetTester tester) async {
      await pump(tester);
      await openFriendsTab(tester);

      expect(find.text('Noch niemand verbunden'), findsOneWidget);
      expect(find.byKey(const Key('friends-find')), findsOneWidget);
      expect(find.byKey(const Key('campfire')), findsNothing);
    });

    testWidgets('everyone sits around the fire as their flame',
        (WidgetTester tester) async {
      final String marcel =
          await seedFriend(repository, name: 'Marcel', emoji: '🦍');
      final String lisa = await seedFriend(repository,
          name: 'Lisa', emoji: '🦊', inactiveDays: 1);
      await pump(tester);
      await openFriendsTab(tester);

      expect(find.byKey(const Key('campfire')), findsOneWidget);
      expect(find.byKey(Key('campfire-${repository.userId}')), findsOneWidget);
      expect(find.byKey(Key('campfire-$marcel')), findsOneWidget);
      // In the fire and in the list.
      expect(find.byType(FriendFlame), findsNWidgets(3 + 2));

      final AppSnapshot snapshot = await repository.snapshot();
      UserProjection of(String id) =>
          snapshot.friends.firstWhere((UserProjection f) => f.userId == id);
      expect(friendMood(of(marcel), snapshot.today), MascotMood.happy);
      expect(friendMood(of(lisa), snapshot.today), MascotMood.hungry);

      await tester.tap(find.byKey(Key('campfire-$marcel')));
      await tester.pumpAndSettle();
      expect(find.byType(FriendDetailScreen), findsOneWidget);
      expect(find.byKey(const Key('profile-flame')), findsOneWidget);
    });

    testWidgets('accepting offline says so and keeps the request',
        (WidgetTester tester) async {
      social.link(const FriendLink(
          userId: 'nora', displayName: 'Nora', emoji: '🦉', status: FriendStatus.incoming));
      await repository.refreshFriends();
      await pump(tester);
      await openFriendsTab(tester);

      social.offline = true;
      await tester.tap(find.widgetWithText(FilledButton, 'Annehmen'));
      await tester.pumpAndSettle();
      expect(find.text('Keine Verbindung zum Server. Versuch es gleich noch einmal.'),
          findsOneWidget);
      expect(find.byKey(const Key('request-nora')), findsOneWidget);

      social.offline = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Annehmen'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('request-nora')), findsNothing);
    });

    testWidgets('a request from a stranger can be blocked after asking once',
        (WidgetTester tester) async {
      social.link(const FriendLink(
          userId: 'spam', displayName: 'Spammer', emoji: '🤖', status: FriendStatus.incoming));
      await repository.refreshFriends();
      await pump(tester);
      await openFriendsTab(tester);

      await tester.tap(find.byKey(const Key('request-menu-spam')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blockieren').last);
      await tester.pumpAndSettle();
      expect(find.text('Spammer blockieren?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('block-confirm')));
      await tester.pumpAndSettle();

      expect(social.blocked.keys, <String>['spam']);
      expect(find.byKey(const Key('request-spam')), findsNothing);
    });

    testWidgets('a sent request is listed and can be withdrawn',
        (WidgetTester tester) async {
      social.link(const FriendLink(
          userId: 'lena', displayName: 'Lena', emoji: '🦊', status: FriendStatus.outgoing));
      await repository.refreshFriends();
      await pump(tester);
      await openFriendsTab(tester);

      expect(find.text('Gesendete Anfragen'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Zurückziehen'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sent-lena')), findsNothing);
      expect(await social.friendships(), isEmpty);
    });
  });

  group('a friend\'s profile', () {
    testWidgets('nudges once a day and cheers their newest check-in once',
        (WidgetTester tester) async {
      final String friend =
          await seedFriend(repository, name: 'Marcel', emoji: '🦍');
      await pumpScreen(tester, FriendDetailScreen(userId: friend));

      final Finder nudge = find.byKey(const Key('profile-nudge'));
      await tester.tap(nudge);
      await tester.tap(nudge);
      await tester.pumpAndSettle();
      expect(await myEvents(FeedEventType.nudge), hasLength(1));
      expect(find.text('Heute angestupst'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(nudge).onPressed, isNull);

      final Finder cheer = find.byKey(const Key('profile-cheer'));
      await tester.tap(cheer);
      await tester.tap(cheer);
      await tester.pumpAndSettle();
      final List<FeedEvent> cheers = await myEvents(FeedEventType.cheer);
      expect(cheers, hasLength(1));
      expect(cheers.single.payload['event'], isNotNull);
      expect(tester.widget<ButtonStyleButton>(cheer).onPressed, isNull);
    });

    testWidgets('removing offline says so instead of closing',
        (WidgetTester tester) async {
      final String friend =
          await seedFriend(repository, name: 'Marcel', emoji: '🦍');
      await pumpScreen(tester, FriendDetailScreen(userId: friend));

      social.offline = true;
      await tester.scrollUntilVisible(
          find.byKey(const Key('profile-disconnect')), 300,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-disconnect')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Entfernen'));
      await tester.pumpAndSettle();

      expect(find.text('Keine Verbindung zum Server. Versuch es gleich noch einmal.'),
          findsOneWidget);
      expect(find.byType(FriendDetailScreen), findsOneWidget);
      expect(repository.follows, contains(friend));
    });

    testWidgets('can be reported and blocked from its menu',
        (WidgetTester tester) async {
      final String friend =
          await seedFriend(repository, name: 'Marcel', emoji: '🦍');
      await pumpScreen(tester, FriendDetailScreen(userId: friend));

      await tester.tap(find.byKey(const Key('profile-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Melden').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-harassment')));
      await tester.enterText(find.byKey(const Key('report-details')), 'Mean nudges');
      await tester.tap(find.byKey(const Key('report-also-block')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('report-send')));
      await tester.pumpAndSettle();

      expect(social.reports.single, (friend, ReportReason.harassment, 'Mean nudges'));
      expect(social.blocked.keys, <String>[friend]);
      expect(repository.follows, isNot(contains(friend)));
      expect(await repository.store.eventsOf(friend), isEmpty);
    });

    testWidgets('shares a streak computed from what each friend can see',
        (WidgetTester tester) async {
      // Mike keeps reading to himself and never logs it; friends only see
      // his no-sugar days, which he logged every day.
      final Challenge challenge = testChallenge(
        startDay: DayKey.today().addDays(-3),
      );
      final Habit hidden = challenge.habits
          .firstWhere((Habit h) => h.category == HabitCategory.reading);
      final Habit shown = challenge.habits
          .firstWhere((Habit h) => h.category == HabitCategory.noSugar);
      repository = await testRepository();
      social = repository.social as MemorySocialBackend;
      await repository.saveProfile(displayName: 'Mike', avatarEmoji: '🐺');
      await repository.startChallenge(challenge.copyWith(
        sharing: SharingPrefs(privateHabits: <String>{hidden.id}),
      ));
      for (int i = 3; i >= 1; i--) {
        await repository.checkIn(habit: shown, day: DayKey.today().addDays(-i));
      }
      final String friend =
          await seedFriend(repository, name: 'Marcel', emoji: '🦍', daysBack: 3);

      final AppSnapshot snapshot = await repository.snapshot();
      final UserProjection marcel = snapshot.friends.single;
      expect(friendStreak(a: snapshot.me, b: marcel, today: snapshot.today), 0,
          reason: 'the private habit is missing from Mike\'s own days');
      expect(
          friendStreak(
              a: snapshot.meAsFriendsSeeMe, b: marcel, today: snapshot.today),
          3,
          reason: 'what Marcel\'s phone computes');

      await pumpScreen(tester, FriendDetailScreen(userId: friend));
      expect(find.text('3 Tage am Stück zusammen'), findsOneWidget);
    });
  });

  group('social settings', () {
    testWidgets('two quick switches both stick', (WidgetTester tester) async {
      await pumpScreen(tester, const SocialSettingsScreen(), height: 4800);

      await tester.tap(find.byKey(const Key('push-nudge')));
      await tester.tap(find.byKey(const Key('push-cheer')));
      await tester.pumpAndSettle();

      final SocialSettings saved = social.savedSettings.last;
      expect(saved.notify['nudge'], isFalse);
      expect(saved.notify['cheer'], isFalse);
      expect((await social.settings()).notify['nudge'], isFalse);
    });

    testWidgets('an offline start offers a retry', (WidgetTester tester) async {
      social.offline = true;
      await pumpScreen(tester, const SocialSettingsScreen());
      expect(find.byKey(const Key('social-settings-retry')), findsOneWidget);

      social.offline = false;
      await tester.tap(find.byKey(const Key('social-settings-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('findable-switch')), findsOneWidget);
    });

    testWidgets('lists who is blocked, with a way back',
        (WidgetTester tester) async {
      social.blocked['troll'] = const PersonResult(
          userId: 'troll', displayName: 'xXTrollXx', emoji: '👹', username: 'troll');
      await pumpScreen(tester, const SocialSettingsScreen(), height: 4800);

      expect(find.byKey(const Key('blocked-troll')), findsOneWidget);
      expect(find.text('xXTrollXx'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Freigeben'));
      await tester.pumpAndSettle();
      expect(social.blocked, isEmpty);
      expect(find.text('Niemand blockiert.'), findsOneWidget);
    });
  });

  test('the scanner takes friend invites and nothing else', () {
    final String example = inviteLink('ABCDE23456').toString();
    expect(isFriendInviteLink(example), isTrue);
    // What the paste hint shows is what the parser reads.
    expect(normalizeInviteCode(example), 'ABCDE23456');
    expect(isFriendInviteLink('hundreddays://invite?d=xyz'), isFalse);
    expect(isFriendInviteLink('hundreddays://household/ABCD2345'), isFalse);
    expect(isFriendInviteLink('https://example.com/menu'), isFalse);
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
