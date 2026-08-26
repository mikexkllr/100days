import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

final DayKey _start = DayKey(2026, 3, 2); // Monday

Challenge _challenge() => Challenge(
      id: 'c1',
      goal: const Goal(
        archetype: GoalArchetype.clarity,
        statement: 'Kopf frei kriegen',
      ),
      habits: <Habit>[
        Habit.fromCategory(HabitCategory.noSugar),
        Habit.fromCategory(HabitCategory.reading),
      ],
      startDay: _start,
    );

Future<(Identity, MemoryFeedStore, FeedWriter)> _peer(String name) async {
  final identity = await Identity.generate();
  final store = MemoryFeedStore();
  final writer = FeedWriter(identity: identity, store: store);
  await writer.append(FeedEventType.profile, <String, dynamic>{
    'displayName': name,
    'avatarEmoji': '🐺',
  });
  return (identity, store, writer);
}

Future<void> _start100(FeedWriter writer, Challenge challenge) =>
    writer.append(
      FeedEventType.challengeStarted,
      <String, dynamic>{
        'challenge': challenge.toJson(),
        'statement': challenge.goal.statement,
      },
      timestamp: _start.toDateTime().add(const Duration(hours: 8)),
    );

Future<void> _checkIn(
  FeedWriter writer,
  Habit habit,
  DayKey day, {
  bool relapse = false,
  num? value,
}) =>
    writer.append(
      FeedEventType.checkIn,
      CheckIn(
        habitId: habit.id,
        category: habit.category,
        day: day,
        value: value ?? habit.target,
        loggedAt: day.toDateTime(),
        relapse: relapse,
      ).toPayload(),
      timestamp: day.toDateTime().add(const Duration(hours: 19)),
    );

void main() {
  group('projectUser', () {
    test('is total on an empty feed', () {
      final projection =
          projectUser('did:key:zNobody', const <FeedEvent>[], today: _start);

      expect(projection.challenge, isNull);
      expect(projection.streak.current, 0);
      expect(projection.lifetimeXp, 0);
      expect(projection.profile.displayName, 'Anonym');
    });

    test('folds profile, challenge and check-ins into state', () async {
      final (Identity id, MemoryFeedStore store, FeedWriter writer) =
          await _peer('Lisa');
      final challenge = _challenge();
      await _start100(writer, challenge);

      final noSugar = challenge.habits[0];
      final reading = challenge.habits[1];
      for (var i = 0; i < 3; i++) {
        await _checkIn(writer, noSugar, _start.addDays(i));
        await _checkIn(writer, reading, _start.addDays(i));
      }

      final projection = projectUser(
        id.did,
        await store.eventsOf(id.did),
        today: _start.addDays(2),
      );

      expect(projection.profile.displayName, 'Lisa');
      expect(projection.profile.avatarEmoji, '🐺');
      expect(projection.challenge!.goal.statement, 'Kopf frei kriegen');
      expect(projection.streak.current, 3);
      expect(projection.lifetimeXp, greaterThan(0));
      expect(projection.headSeq, 8);
    });

    test('the newest check-in for a habit and day wins', () async {
      final (Identity id, MemoryFeedStore store, FeedWriter writer) =
          await _peer('Lisa');
      final challenge = _challenge();
      await _start100(writer, challenge);
      final reading = challenge.habits[1];

      await _checkIn(writer, reading, _start, value: 5);
      await _checkIn(writer, reading, _start, value: 40);

      final projection =
          projectUser(id.did, await store.eventsOf(id.did), today: _start);

      expect(projection.logsByDay[_start.toString()]!.entries, hasLength(1));
      expect(
        projection.logsByDay[_start.toString()]!.entryFor(reading.id)!.value,
        40,
      );
    });

    test('scores each day with the streak the user had at the time', () async {
      final (Identity id, MemoryFeedStore store, FeedWriter writer) =
          await _peer('Lisa');
      final challenge = _challenge();
      await _start100(writer, challenge);

      for (var i = 0; i < 6; i++) {
        for (final Habit habit in challenge.habits) {
          await _checkIn(writer, habit, _start.addDays(i));
        }
      }

      final projection = projectUser(
        id.did,
        await store.eventsOf(id.did),
        today: _start.addDays(5),
      );

      final firstDay = projection.xpByDay[_start.toString()]!;
      final lastDay = projection.xpByDay[_start.addDays(5).toString()]!;
      expect(lastDay, greaterThan(firstDay));
    });

    test('records a relapse and resets the streak', () async {
      final (Identity id, MemoryFeedStore store, FeedWriter writer) =
          await _peer('Lisa');
      final challenge = _challenge();
      await _start100(writer, challenge);

      for (var i = 0; i < 3; i++) {
        for (final Habit habit in challenge.habits) {
          await _checkIn(writer, habit, _start.addDays(i));
        }
      }
      await _checkIn(writer, challenge.habits[0], _start.addDays(3),
          relapse: true);

      final projection = projectUser(
        id.did,
        await store.eventsOf(id.did),
        today: _start.addDays(4),
      );

      expect(projection.lastRelapseDay, _start.addDays(3));
      expect(projection.streak.current, 0);
      expect(projection.streak.longest, 3);
    });

    test('exposes weekly XP for the league', () async {
      final (Identity id, MemoryFeedStore store, FeedWriter writer) =
          await _peer('Lisa');
      final challenge = _challenge();
      await _start100(writer, challenge);

      for (var i = 0; i < 3; i++) {
        for (final Habit habit in challenge.habits) {
          await _checkIn(writer, habit, _start.addDays(i));
        }
      }

      final projection = projectUser(
        id.did,
        await store.eventsOf(id.did),
        today: _start.addDays(2),
      );

      expect(projection.xpInWeek(_start.isoWeekKey), projection.lifetimeXp);
      expect(projection.xpInWeek('2025-W01'), 0);
      expect(projection.checkInsInWeek(_start.isoWeekKey), 6);
    });

    test('ignores events from other authors', () async {
      final (Identity a, MemoryFeedStore aStore, FeedWriter aWriter) =
          await _peer('Alice');
      final (Identity b, MemoryFeedStore bStore, FeedWriter bWriter) =
          await _peer('Bob');
      await _start100(aWriter, _challenge());
      await _start100(bWriter, _challenge());

      final mixed = <FeedEvent>[
        ...await aStore.eventsOf(a.did),
        ...await bStore.eventsOf(b.did),
      ];

      expect(projectUser(a.did, mixed, today: _start).profile.displayName,
          'Alice');
      expect(
          projectUser(b.did, mixed, today: _start).profile.displayName, 'Bob');
    });

    test('produces a peer state the social screens can render', () async {
      final (Identity id, MemoryFeedStore store, FeedWriter writer) =
          await _peer('Lisa');
      final challenge = _challenge();
      await _start100(writer, challenge);
      await _checkIn(writer, challenge.habits[0], _start);

      final peer = projectUser(id.did, await store.eventsOf(id.did),
              today: _start)
          .toPeerState(today: _start);

      expect(peer.activeToday, isTrue);
      expect(peer.dayNumber, 1);
      expect(peer.lastActivity.kind, PeerActivityKind.checkIn);
      expect(peer.lastActivity.category, HabitCategory.noSugar);
      expect(peer.level, greaterThanOrEqualTo(1));
    });
  });

  group('buildActivityFeed', () {
    test('renders check-ins newest first', () async {
      final (Identity id, MemoryFeedStore store, FeedWriter writer) =
          await _peer('Lisa');
      final challenge = _challenge();
      await _start100(writer, challenge);
      await _checkIn(writer, challenge.habits[0], _start);
      await _checkIn(writer, challenge.habits[1], _start.addDays(1));

      final items = buildActivityFeed(
        await store.eventsOf(id.did),
        profiles: <String, PeerProfile>{
          id.did: PeerProfile(
              did: id.did, displayName: 'Lisa', avatarEmoji: '🐺'),
        },
        selfDid: 'did:key:zMe',
      );

      expect(items.first.kind, ActivityKind.checkIn);
      expect(items.first.category, HabitCategory.reading);
      expect(items.first.authorName, 'Lisa');
      expect(items.last.kind, ActivityKind.start);
      expect(items.last.statement, 'Kopf frei kriegen');
    });

    test('marks a backfilled check-in as not verified live', () async {
      final (Identity id, MemoryFeedStore store, FeedWriter writer) =
          await _peer('Lisa');
      final challenge = _challenge();
      await _start100(writer, challenge);
      await writer.append(
        FeedEventType.checkIn,
        CheckIn(
          habitId: challenge.habits[0].id,
          category: challenge.habits[0].category,
          day: _start,
          value: 1,
          loggedAt: _start.toDateTime(),
        ).toPayload(),
        // Logged three days later than the day it claims.
        timestamp: _start.addDays(3).toDateTime(),
      );

      final items = buildActivityFeed(
        await store.eventsOf(id.did),
        profiles: const <String, PeerProfile>{},
        selfDid: 'did:key:zMe',
      );

      final checkIn =
          items.firstWhere((ActivityItem i) => i.kind == ActivityKind.checkIn);
      expect(checkIn.isVerifiedLive, isFalse);
      expect(checkIn.claimedDay, _start);
    });

    test('hides nudges aimed at third parties', () async {
      final (Identity id, MemoryFeedStore store, FeedWriter writer) =
          await _peer('Lisa');
      await writer.append(FeedEventType.nudge, <String, dynamic>{
        'target': 'did:key:zSomeoneElse',
        'text': 'Los jetzt',
      });

      final items = buildActivityFeed(
        await store.eventsOf(id.did),
        profiles: const <String, PeerProfile>{},
        selfDid: 'did:key:zMe',
      );

      expect(items.where((ActivityItem i) => i.kind == ActivityKind.nudge),
          isEmpty);
    });

    test('shows a nudge aimed at me', () async {
      final (Identity id, MemoryFeedStore store, FeedWriter writer) =
          await _peer('Lisa');
      await writer.append(FeedEventType.nudge, <String, dynamic>{
        'target': 'did:key:zMe',
        'text': 'Ich war heute schon.',
      });

      final items = buildActivityFeed(
        await store.eventsOf(id.did),
        profiles: <String, PeerProfile>{
          id.did: PeerProfile(
              did: id.did, displayName: 'Lisa', avatarEmoji: '🐺'),
        },
        selfDid: 'did:key:zMe',
      );

      expect(items.single.kind, ActivityKind.nudge);
      expect(items.single.isOwn, isFalse);
      expect(items.single.message, 'Ich war heute schon.');
    });
  });
}
