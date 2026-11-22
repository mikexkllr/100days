import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

final DayKey _start = DayKey(2026, 11, 2); // Monday

Challenge _daily(String id) => Challenge(
      id: id,
      goal: const Goal(archetype: GoalArchetype.discipline, statement: ''),
      habits: <Habit>[Habit.fromCategory(HabitCategory.reading)],
      startDay: _start,
    );

Future<UserProjection> _user(
  String id,
  Set<int> doneDays, {
  DayKey? today,
  Set<int> frozenDays = const <int>{},
}) async {
  final store = MemoryFeedStore();
  final writer = FeedWriter(author: id, store: store);
  final challenge = _daily(id);
  await writer.append(FeedEventType.challengeStarted,
      <String, dynamic>{'challenge': challenge.toJson()},
      timestamp: _start.toDateTime());
  for (final int d in frozenDays.toList()..sort()) {
    final day = _start.addDays(d);
    await writer.append(
      FeedEventType.streakFreeze,
      <String, dynamic>{'day': day.toString()},
      timestamp: day.toDateTime().add(const Duration(hours: 21)),
    );
  }
  for (final int d in doneDays.toList()..sort()) {
    final day = _start.addDays(d);
    await writer.append(
      FeedEventType.checkIn,
      CheckIn(
        habitId: challenge.habits.single.id,
        category: HabitCategory.reading,
        day: day,
        value: challenge.habits.single.target,
        loggedAt: day.toDateTime(),
      ).toPayload(),
      timestamp: day.toDateTime().add(const Duration(hours: 20)),
    );
  }
  return projectUser(id, await store.eventsOf(id), today: today ?? _start.addDays(9));
}

void main() {
  group('friend streak', () {
    test('counts the days both showed up, back from yesterday while today is open', () async {
      final today = _start.addDays(9);
      final a = await _user('a', <int>{0, 1, 2, 3, 4, 5, 6, 7, 8}, today: today);
      final b = await _user('b', <int>{3, 4, 5, 6, 7, 8}, today: today);
      expect(friendStreak(a: a, b: b, today: today), 6);
    });

    test('today counts once both are done', () async {
      final today = _start.addDays(9);
      final a = await _user('a', <int>{7, 8, 9}, today: today);
      final b = await _user('b', <int>{7, 8, 9}, today: today);
      expect(friendStreak(a: a, b: b, today: today), 3);
    });

    test('one missed day breaks it for both', () async {
      final today = _start.addDays(9);
      final a = await _user('a', <int>{4, 5, 6, 7, 8}, today: today);
      final b = await _user('b', <int>{4, 5, 7, 8}, today: today);
      expect(friendStreak(a: a, b: b, today: today), 2);
    });

    test('a day one of them froze holds the streak without counting', () async {
      final today = _start.addDays(9);
      final a = await _user('a', <int>{4, 5, 6, 7, 8}, today: today);
      final b = await _user('b', <int>{4, 5, 7, 8}, today: today, frozenDays: <int>{6});
      // 4, 5, (6 held), 7, 8.
      expect(friendStreak(a: a, b: b, today: today), 4);
      // The same number from either side.
      expect(friendStreak(a: b, b: a, today: today), 4);
    });

    test('a day both froze holds it too', () async {
      final today = _start.addDays(9);
      final a = await _user('a', <int>{4, 5, 7, 8}, today: today, frozenDays: <int>{6});
      final b = await _user('b', <int>{4, 5, 7, 8}, today: today, frozenDays: <int>{6});
      expect(friendStreak(a: a, b: b, today: today), 4);
    });

    test('a freeze holds only its own day', () async {
      final today = _start.addDays(9);
      final a = await _user('a', <int>{4, 7, 8}, today: today, frozenDays: <int>{6});
      final b = await _user('b', <int>{4, 5, 6, 7, 8}, today: today);
      // a missed 5 without a freeze: the streak starts again at 6.
      expect(friendStreak(a: a, b: b, today: today), 2);
    });
  });

  test('a quest adds up both people\'s check-ins this week', () async {
    final today = _start.addDays(9); // Wednesday of the second week
    final me = await _user('a', <int>{7, 8, 9}, today: today);
    final friend = await _user('b', <int>{7}, today: today);
    final quest = friendQuest(me: me, friend: friend, today: today);
    expect(quest.target, 10);
    expect(quest.mine, 3);
    expect(quest.theirs, 1);
    expect(quest.done, isFalse);
    expect(quest.fraction, closeTo(0.4, 1e-9));
  });

  test('league slots grow with the group and vanish in tiny ones', () {
    expect(promotionSlots(30), 7);
    expect(demotionSlots(30), 5);
    expect(promotionSlots(8), 2);
    expect(demotionSlots(8), 1);
    expect(promotionSlots(3), 1);
    expect(demotionSlots(3), 0);
    expect(promotionSlots(1), 0);
  });

  test('week keys match ISO 8601 across the clock change', () {
    expect(DayKey(2026, 3, 26).isoWeekKey, '2026-W13');
    expect(DayKey(2026, 3, 29).isoWeekKey, '2026-W13');
    expect(DayKey(2026, 3, 30).isoWeekKey, '2026-W14');
    expect(DayKey(2027, 1, 1).isoWeekKey, '2026-W53');
    expect(DayKey(2026, 11, 17).isoWeekKey, '2026-W47');
  });
}
