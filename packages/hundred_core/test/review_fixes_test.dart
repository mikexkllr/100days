import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

/// Pins the fixes from the pre-release review (docs/review-2026-11.md).

final DayKey _start = DayKey(2026, 3, 2); // Monday

Challenge _challenge({DayKey? start, SharingPrefs? sharing}) => Challenge(
      id: 'c1',
      goal: const Goal(archetype: GoalArchetype.sober, statement: 'Clean'),
      habits: <Habit>[
        Habit.fromCategory(HabitCategory.noSugar),
        Habit.fromCategory(HabitCategory.reading),
      ],
      startDay: start ?? _start,
      sharing: sharing ?? const SharingPrefs(),
    );

FeedEvent _event(
  String type,
  Map<String, dynamic> payload, {
  required DateTime at,
}) =>
    FeedEvent.create(author: 'me', type: type, payload: payload, timestamp: at);

FeedEvent _started(Challenge c, {required DateTime at, bool restart = false}) =>
    _event(
      FeedEventType.challengeStarted,
      <String, dynamic>{
        'challenge': c.toJson(),
        if (restart) 'restart': true,
      },
      at: at,
    );

FeedEvent _tick(
  Habit habit,
  DayKey day, {
  num? value,
  bool undo = false,
  int? tz,
  DateTime? at,
}) =>
    _event(
      FeedEventType.checkIn,
      <String, dynamic>{
        ...CheckIn(
          habitId: habit.id,
          category: habit.category,
          day: day,
          value: value ?? habit.target,
          loggedAt: day.toDateTime(),
          utcOffsetMinutes: tz,
        ).toPayload(),
        if (undo) 'undo': true,
      },
      at: at ?? day.toDateTime().add(const Duration(hours: 19)),
    );

void main() {
  final Challenge challenge = _challenge();
  final Habit noSugar = challenge.habits[0];
  final Habit reading = challenge.habits[1];
  final DateTime t0 = _start.toDateTime().add(const Duration(hours: 8));

  group('the fold', () {
    test('skips an event it cannot read instead of failing', () {
      final List<FeedEvent> events = <FeedEvent>[
        _started(challenge, at: t0),
        _tick(noSugar, _start),
        _event(
          FeedEventType.checkIn,
          <String, dynamic>{
            'habitId': 'x',
            'category': 'aHabitFromTheFuture',
            'day': _start.toString(),
            'value': 1,
          },
          at: t0.add(const Duration(hours: 1)),
        ),
      ];
      final UserProjection me = projectUser('me', events, today: _start);
      expect(me.challenge, isNotNull);
      expect(me.logsByDay[_start.toString()]!.entries, hasLength(1));
      expect(
        buildActivityFeed(events, profiles: const <String, PeerProfile>{},
            selfId: 'me'),
        isNotEmpty,
      );
    });

    test('a second start keeps the running challenge; a restart does not', () {
      final DayKey later = _start.addDays(10);
      final Challenge again = _challenge(start: later);
      final UserProjection kept = projectUser(
        'me',
        <FeedEvent>[
          _started(challenge, at: t0),
          _started(again, at: later.toDateTime()),
        ],
        today: later,
      );
      expect(kept.challenge!.startDay, _start);

      final UserProjection restarted = projectUser(
        'me',
        <FeedEvent>[
          _started(challenge, at: t0),
          _started(again, at: later.toDateTime(), restart: true),
        ],
        today: later,
      );
      expect(restarted.challenge!.startDay, later);
    });

    test('an undo takes the tick back out, also off the timeline', () {
      final List<FeedEvent> events = <FeedEvent>[
        _started(challenge, at: t0),
        _tick(noSugar, _start),
        _tick(noSugar, _start,
            value: 0,
            undo: true,
            at: _start.toDateTime().add(const Duration(hours: 20))),
      ];
      final UserProjection me = projectUser('me', events, today: _start);
      expect(me.logsByDay[_start.toString()], isNull);
      expect(me.lifetimeXp, 0);
      final List<ActivityItem> feed = buildActivityFeed(events,
          profiles: const <String, PeerProfile>{}, selfId: 'me');
      expect(feed.where((ActivityItem i) => i.kind == ActivityKind.checkIn),
          isEmpty);
    });

    test('an entry below target is not activity', () {
      final UserProjection me = projectUser(
        'me',
        <FeedEvent>[_started(challenge, at: t0), _tick(reading, _start, value: 0)],
        today: _start,
      );
      expect(me.toPeerState().activeToday, isFalse);
      expect(me.checkInsInWeek(_start.isoWeekKey), 0);
    });
  });

  group('freezes', () {
    test('every cycle brings its own', () {
      final Set<String> frozen = <String>{
        _start.addDays(4).toString(),
        _start.addDays(9).toString(),
        _start.addDays(20).toString(),
      };
      expect(challenge.freezesLeftOn(_start.addDays(30), frozen), 0);
      // Day 101 opens the next cycle with three fresh freezes.
      expect(challenge.freezesLeftOn(_start.addDays(100), frozen), 3);
    });

    test('a frozen today is not at risk', () {
      final StreakStats stats = computeStreak(
        challenge: challenge,
        logsByDay: <String, DayLog>{
          _start.toString(): DayLog(day: _start, entries: <CheckIn>[
            for (final Habit h in challenge.habits)
              CheckIn(
                habitId: h.id,
                category: h.category,
                day: _start,
                value: h.target,
                loggedAt: _start.toDateTime(),
              ),
          ]),
        },
        frozenDays: <String>{_start.addDays(1).toString()},
        today: _start.addDays(1),
      );
      expect(stats.atRisk, isFalse);
      expect(stats.current, 1);
    });
  });

  group('ascent', () {
    test('stays available after day 100, whether or not it was done', () {
      final DayKey day100 = _start.addDays(99);
      expect(challenge.canAscend(day100, lastDayDone: false), isFalse);
      expect(challenge.canAscend(day100, lastDayDone: true), isTrue);
      expect(challenge.canAscend(_start.addDays(130), lastDayDone: false),
          isTrue);
      expect(challenge.ascentTarget(day100), 1);
      // Someone at day 250 who never ascended lands in the cycle they are in.
      expect(challenge.ascentTarget(_start.addDays(249)), 2);
    });
  });

  group('XP', () {
    test('part of the target earns part of the XP', () {
      int xp(num value) => xpForCheckIn(
            habit: reading,
            checkIn: CheckIn(
              habitId: reading.id,
              category: reading.category,
              day: _start,
              value: value,
              loggedAt: _start.toDateTime(),
            ),
            streakBefore: 0,
          );
      expect(xp(0), 0);
      expect(xp(reading.target / 2), lessThan(xp(reading.target)));
      expect(xp(reading.target * 3), xp(reading.target));
    });
  });

  group('league', () {
    test('nobody is marked as promoting below six people', () {
      final LeagueStanding standing = buildLeagueStanding(
        weekKey: _start.isoWeekKey,
        league: League.bronze,
        entries: <LeagueEntry>[
          for (final (String id, int xp) in <(String, int)>[('a', 90), ('b', 30)])
            LeagueEntry(
              userId: id,
              displayName: id,
              avatarEmoji: '🙂',
              weeklyXp: xp,
              currentStreak: 0,
              checkInsThisWeek: 0,
              activeToday: false,
            ),
        ],
      );
      expect(standing.promotionCutoff, 0);
      expect(standing.isPromoting('a'), isFalse);
    });
  });

  group('time zones', () {
    test('live is judged by the writer\'s clock', () {
      // Logged at 22:00 in Los Angeles (UTC−8) on the 2nd: 06:00 UTC on the
      // 3rd. Still live, whichever zone reads it.
      final CheckIn entry = CheckIn(
        habitId: reading.id,
        category: reading.category,
        day: _start,
        value: reading.target,
        loggedAt: DateTime.utc(2026, 3, 3, 6),
        utcOffsetMinutes: -8 * 60,
      );
      expect(entry.isLive, isTrue);
    });

    test('a friend\'s today follows their offset', () {
      final DateTime now = DateTime.utc(2026, 3, 3, 6); // 22:00 on the 2nd in LA
      final DayKey theirs = authorTodayOf(
        <FeedEvent>[_tick(reading, _start, tz: -8 * 60)],
        now: now,
      );
      expect(theirs, _start);
    });
  });

  group('privacy', () {
    test('a hidden goal sentence hides the kind of goal too', () {
      final Challenge hidden =
          _challenge(sharing: const SharingPrefs(shareStatement: false));
      expect(publicViewOf(hidden).goal.archetype, GoalArchetype.custom);
      expect(publicViewOf(challenge).goal.archetype, GoalArchetype.sober);
    });
  });

  group('coach', () {
    test('the day after a relapse does not say the streak is gone', () async {
      final DayKey today = _start.addDays(20);
      final DayKey yesterday = today.addDays(-1);
      final DayLog relapseLog = DayLog(day: yesterday, entries: <CheckIn>[
        CheckIn(
          habitId: noSugar.id,
          category: noSugar.category,
          day: yesterday,
          value: 0,
          loggedAt: yesterday.toDateTime(),
          relapse: true,
        ),
      ]);
      final CoachDirective directive =
          await const HeuristicCoach().dailyBriefing(CoachContext(
        challenge: challenge,
        streak: const StreakStats(
          current: 12,
          longest: 12,
          completedDays: 12,
          scheduledDays: 20,
          doneToday: false,
          atRisk: true,
          freezesUsed: 0,
        ),
        today: today,
        todayLog: null,
        peers: const <PeerState>[],
        now: today.toDateTime().add(const Duration(hours: 10)),
        habitStreaks: const <String, int>{},
        lastRelapseDay: yesterday,
        lastRelapseLog: relapseLog,
      ));
      expect(directive.template, isNot(CoachTemplate.recoverStreakLost));
      expect(directive.template, CoachTemplate.recoverRelapse);
    });
  });

  group('editing habits mid-challenge', () {
    CheckIn read(DayKey day, num pages) => CheckIn(
          habitId: reading.id,
          category: reading.category,
          day: day,
          value: pages,
          loggedAt: day.toDateTime(),
        );

    test('a higher target does not turn past days into misses', () {
      final DayKey from = _start.addDays(2);
      final Habit raised = reading.withTarget(30, from: from);
      expect(raised.targetOn(_start), reading.target);
      expect(raised.targetOn(from), 30);
      final Challenge edited = Challenge(
        id: 'c1',
        goal: challenge.goal,
        habits: <Habit>[raised],
        startDay: _start,
      );
      final StreakStats stats = computeStreak(
        challenge: edited,
        logsByDay: <String, DayLog>{
          for (int i = 0; i < 2; i++)
            _start.addDays(i).toString(): DayLog(
              day: _start.addDays(i),
              entries: <CheckIn>[read(_start.addDays(i), 20)],
            ),
        },
        frozenDays: const <String>{},
        today: from,
      );
      expect(stats.current, 2);
      expect(Habit.fromJson(raised.toJson()).targetOn(_start), reading.target);
    });

    test('a habit taken out stops counting from that day, not before', () {
      final DayKey until = _start.addDays(3);
      final Habit out = noSugar.retiredFrom(until);
      expect(out.isActiveOn(_start), isTrue);
      expect(out.isActiveOn(until), isFalse);
      expect(out.isRetiredOn(until), isTrue);
      final Challenge edited = Challenge(
        id: 'c1',
        goal: challenge.goal,
        habits: <Habit>[out, reading],
        startDay: _start,
      );
      expect(requiredHabitsOn(edited, _start), hasLength(2));
      expect(requiredHabitsOn(edited, until).map((Habit h) => h.id),
          <String>[reading.id]);
      expect(Habit.fromJson(out.toJson()).activeUntil, until);
    });
  });
}
