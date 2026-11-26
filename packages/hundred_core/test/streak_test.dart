import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

final DayKey _start = DayKey(2026, 3, 2); // a Monday

Challenge _challenge(List<Habit> habits) => Challenge(
      id: 'c1',
      goal: const Goal(
        archetype: GoalArchetype.discipline,
        statement: '100 Tage nicht verhandeln',
      ),
      habits: habits,
      startDay: _start,
    );

DayLog _log(DayKey day, List<Habit> habits, {bool relapse = false}) => DayLog(
      day: day,
      entries: <CheckIn>[
        for (final Habit h in habits)
          CheckIn(
            habitId: h.id,
            category: h.category,
            day: day,
            value: h.target,
            loggedAt: day.toDateTime().add(const Duration(hours: 20)),
            relapse: relapse,
          ),
      ],
    );

Map<String, DayLog> _logsForDays(
  Iterable<int> offsets,
  List<Habit> habits,
) =>
    <String, DayLog>{
      for (final int offset in offsets)
        _start.addDays(offset).toString(): _log(_start.addDays(offset), habits),
    };

void main() {
  final gym = Habit.fromCategory(HabitCategory.gym); // 4 days/week
  final noSugar = Habit.fromCategory(HabitCategory.noSugar); // daily

  group('DayKey', () {
    test('counts days across a month boundary', () {
      expect(DayKey(2026, 3, 1).differenceInDays(DayKey(2026, 2, 26)), 3);
    });

    test('buckets days into ISO weeks', () {
      expect(DayKey(2026, 3, 2).isoWeekKey, equals(DayKey(2026, 3, 8).isoWeekKey));
      expect(DayKey(2026, 3, 8).isoWeekKey,
          isNot(equals(DayKey(2026, 3, 9).isoWeekKey)));
    });
  });

  group('schedule', () {
    test('spreads four training days with rest in between', () {
      expect(scheduledWeekdays(gym), <int>[
        DateTime.monday,
        DateTime.tuesday,
        DateTime.thursday,
        DateTime.friday,
      ]);
    });

    test('treats an unscheduled weekday as a rest day', () {
      final challenge = _challenge(<Habit>[gym]);
      expect(isRestDay(challenge, _start.addDays(2)), isTrue); // Wednesday
      expect(isRestDay(challenge, _start), isFalse); // Monday
    });
  });

  group('computeStreak', () {
    test('counts consecutive completed days', () {
      final challenge = _challenge(<Habit>[noSugar]);
      final stats = computeStreak(
        challenge: challenge,
        logsByDay: _logsForDays(List<int>.generate(10, (int i) => i),
            <Habit>[noSugar]),
        frozenDays: const <String>{},
        today: _start.addDays(9),
      );

      expect(stats.current, 10);
      expect(stats.longest, 10);
      expect(stats.doneToday, isTrue);
      expect(stats.atRisk, isFalse);
    });

    test('does not break the streak while today is still open', () {
      final challenge = _challenge(<Habit>[noSugar]);
      final stats = computeStreak(
        challenge: challenge,
        logsByDay:
            _logsForDays(List<int>.generate(5, (int i) => i), <Habit>[noSugar]),
        frozenDays: const <String>{},
        today: _start.addDays(5),
      );

      expect(stats.current, 5);
      expect(stats.doneToday, isFalse);
      expect(stats.atRisk, isTrue);
    });

    test('resets after a missed day in the past', () {
      final challenge = _challenge(<Habit>[noSugar]);
      final stats = computeStreak(
        challenge: challenge,
        logsByDay: _logsForDays(<int>[0, 1, 2, 4, 5], <Habit>[noSugar]),
        frozenDays: const <String>{},
        today: _start.addDays(5),
      );

      expect(stats.current, 2);
      expect(stats.longest, 3);
      expect(stats.completedDays, 5);
    });

    test('a streak freeze holds the streak without counting as done', () {
      final challenge = _challenge(<Habit>[noSugar]);
      final stats = computeStreak(
        challenge: challenge,
        logsByDay: _logsForDays(<int>[0, 1, 2, 4, 5], <Habit>[noSugar]),
        frozenDays: <String>{_start.addDays(3).toString()},
        today: _start.addDays(5),
      );

      expect(stats.current, 5);
      expect(stats.completedDays, 5);
      expect(stats.freezesUsed, 1);
    });

    test('rest days neither extend nor break the streak', () {
      final challenge = _challenge(<Habit>[gym]);
      // Mon, Tue, Thu, Fri of week one — Wednesday is a rest day.
      final stats = computeStreak(
        challenge: challenge,
        logsByDay: _logsForDays(<int>[0, 1, 3, 4], <Habit>[gym]),
        frozenDays: const <String>{},
        today: _start.addDays(4),
      );

      expect(stats.current, 4);
      expect(stats.scheduledDays, 4);
      expect(stats.completionRate, 1.0);
    });

    test('a relapse on the only habit breaks the streak', () {
      final challenge = _challenge(<Habit>[noSugar]);
      final logs = _logsForDays(<int>[0, 1], <Habit>[noSugar])
        ..[_start.addDays(2).toString()] =
            _log(_start.addDays(2), <Habit>[noSugar], relapse: true);

      final stats = computeStreak(
        challenge: challenge,
        logsByDay: logs,
        frozenDays: const <String>{},
        today: _start.addDays(3),
      );

      expect(stats.current, 0);
      expect(stats.longest, 2);
    });

    test('a partially logged day does not count', () {
      final challenge = _challenge(<Habit>[gym, noSugar]);
      final stats = computeStreak(
        challenge: challenge,
        logsByDay: <String, DayLog>{
          _start.toString(): _log(_start, <Habit>[gym]),
        },
        frozenDays: const <String>{},
        today: _start.addDays(1),
      );

      expect(stats.current, 0);
    });
  });

  group('habitStreak', () {
    test('abstinence counts days that were never explicitly logged', () {
      final streak = habitStreak(
        habit: noSugar,
        logsByDay: const <String, DayLog>{},
        startDay: _start,
        today: _start.addDays(6),
      );

      expect(streak, 7);
    });

    test('abstinence resets on a confessed relapse', () {
      final streak = habitStreak(
        habit: noSugar,
        logsByDay: <String, DayLog>{
          _start.addDays(4).toString():
              _log(_start.addDays(4), <Habit>[noSugar], relapse: true),
        },
        startDay: _start,
        today: _start.addDays(6),
      );

      expect(streak, 2);
    });

    test('build habits skip unscheduled days', () {
      final streak = habitStreak(
        habit: gym,
        logsByDay: _logsForDays(<int>[0, 1, 3, 4], <Habit>[gym]),
        startDay: _start,
        today: _start.addDays(4),
      );

      expect(streak, 4);
    });
  });

  group('progression', () {
    test('a longer streak is worth more XP', () {
      final checkIn = CheckIn(
        habitId: gym.id,
        category: gym.category,
        day: _start,
        value: 1,
        loggedAt: _start.toDateTime(),
      );

      final fresh = xpForCheckIn(habit: gym, checkIn: checkIn, streakBefore: 0);
      final seasoned =
          xpForCheckIn(habit: gym, checkIn: checkIn, streakBefore: 50);

      expect(seasoned, greaterThan(fresh));
      expect(seasoned, equals(fresh * 2));
    });

    test('a relapse is worth nothing', () {
      final relapse = CheckIn(
        habitId: noSugar.id,
        category: noSugar.category,
        day: _start,
        value: 1,
        loggedAt: _start.toDateTime(),
        relapse: true,
      );

      expect(
        xpForCheckIn(habit: noSugar, checkIn: relapse, streakBefore: 30),
        0,
      );
    });

    test('levels get progressively more expensive', () {
      final toTwo = xpRequiredForLevel(2) - xpRequiredForLevel(1);
      final toTen = xpRequiredForLevel(10) - xpRequiredForLevel(9);

      expect(toTen, greaterThan(toTwo));
      expect(levelForXp(xpRequiredForLevel(5)), 5);
      expect(levelForXp(xpRequiredForLevel(5) - 1), 4);
    });

    test('a fresh account cannot land in a high league', () {
      expect(leagueForXp(0), League.wood);
      expect(leagueForXp(30000), League.obsidian);
    });

    test('the standing ranks by weekly XP, then streak', () {
      final standing = buildLeagueStanding(
        weekKey: '2026-W10',
        league: League.silver,
        entries: const <LeagueEntry>[
          LeagueEntry(
            userId: 'user-A',
            displayName: 'Ali',
            avatarEmoji: '🐺',
            weeklyXp: 300,
            currentStreak: 4,
            checkInsThisWeek: 5,
            activeToday: true,
          ),
          LeagueEntry(
            userId: 'user-B',
            displayName: 'Bea',
            avatarEmoji: '🦊',
            weeklyXp: 300,
            currentStreak: 40,
            checkInsThisWeek: 5,
            activeToday: false,
          ),
          LeagueEntry(
            userId: 'user-C',
            displayName: 'Cem',
            avatarEmoji: '🦈',
            weeklyXp: 900,
            currentStreak: 2,
            checkInsThisWeek: 9,
            activeToday: true,
          ),
        ],
      );

      expect(standing.entries.first.displayName, 'Cem');
      expect(standing.rankOf('user-B'), 2);
      expect(standing.rankOf('user-A'), 3);
    });
  });

  test('day differences survive the clocks going forward', () {
    // Europe switches to summer time on 29 March 2026: that night has 23
    // hours, which must not cost anyone a day of their streak.
    expect(DayKey(2026, 4, 1).differenceInDays(DayKey(2026, 3, 2)), 30);
    expect(DayKey(2026, 11, 1).differenceInDays(DayKey(2026, 10, 1)), 31);
  });

  group('picked weekdays and optional habits', () {
    // Monday to Saturday; Sunday is the cheat day.
    final nutrition = Habit.fromCategory(HabitCategory.nutrition).withSchedule(
        const HabitSchedule(daysPerWeek: 6, weekdays: <int>[6, 1, 2, 3, 4, 5, 5]),
        from: _start);
    final reading = Habit.fromCategory(HabitCategory.reading);

    test('a habit is required on the days picked, the cheat day is free', () {
      expect(nutrition.weekdays, <int>[1, 2, 3, 4, 5, 6]);
      expect(nutrition.daysPerWeek, 6);
      final challenge = _challenge(<Habit>[nutrition, reading]);
      // 2026-03-05 is a Thursday, 2026-03-08 a Sunday.
      expect(requiredHabitsOn(challenge, DayKey(2026, 3, 5)), contains(nutrition));
      expect(requiredHabitsOn(challenge, DayKey(2026, 3, 8)), <Habit>[reading]);
    });

    test('skipping the cheat day does not break the streak', () {
      final challenge = _challenge(<Habit>[nutrition]);
      final stats = computeStreak(
        challenge: challenge,
        // Monday to Saturday, then Monday: Sunday left out.
        logsByDay: _logsForDays(<int>[0, 1, 2, 3, 4, 5, 7], <Habit>[nutrition]),
        frozenDays: const <String>{},
        today: _start.addDays(7),
      );
      expect(stats.current, 7);
    });

    test('an optional habit is never required; done, it does not count either way', () {
      final optional = reading.withSchedule(
          const HabitSchedule(daysPerWeek: 7, optional: true),
          from: _start);
      final challenge = _challenge(<Habit>[noSugar, optional]);
      expect(requiredHabitsOn(challenge, _start), <Habit>[noSugar]);
      expect(scheduledWeekdays(optional), isEmpty);
      final stats = computeStreak(
        challenge: challenge,
        logsByDay: _logsForDays(<int>[0, 1, 2], <Habit>[noSugar]),
        frozenDays: const <String>{},
        today: _start.addDays(2),
      );
      expect(stats.current, 3);
    });

    test('a new schedule applies from its day on; the days before keep theirs', () {
      final from = _start.addDays(7);
      final made = reading.withSchedule(
          const HabitSchedule(daysPerWeek: 7, optional: true),
          from: from);
      // The first week it was required, and a miss then stays a miss.
      expect(isHabitScheduledOn(made, _start.addDays(3)), isTrue);
      expect(isHabitScheduledOn(made, from), isFalse);
      final back = made.withSchedule(
          const HabitSchedule(daysPerWeek: 3, weekdays: <int>[1, 3, 5]),
          from: from.addDays(7));
      expect(isHabitScheduledOn(back, from.addDays(2)), isFalse, reason: 'still optional then');
      expect(scheduledWeekdays(back, from.addDays(9)), <int>[1, 3, 5]);
      expect(isHabitScheduledOn(back, _start.addDays(1)), isTrue, reason: 'the first week, daily');
    });

    test('the same schedule again changes nothing', () {
      expect(identical(nutrition.withSchedule(nutrition.schedule, from: _start.addDays(9)), nutrition),
          isTrue);
      expect(identical(reading.withDaysPerWeek(reading.daysPerWeek, from: _start), reading), isTrue);
    });

    test('survives its JSON, and old JSON reads as before', () {
      final optional = nutrition.withSchedule(
          const HabitSchedule(daysPerWeek: 6, optional: true),
          from: _start.addDays(14));
      final copy = Habit.fromJson(optional.toJson());
      expect(copy.optional, isTrue);
      expect(copy.scheduleOn(_start.addDays(3)).weekdays, <int>[1, 2, 3, 4, 5, 6]);
      expect(copy.scheduleOn(_start.addDays(20)).optional, isTrue);
      final old = Habit.fromJson(<String, dynamic>{
        'id': 'gym',
        'category': 'gym',
        'target': 1,
        'daysPerWeek': 4,
      });
      expect(old.weekdays, isNull);
      expect(old.optional, isFalse);
      expect(scheduledWeekdays(old), scheduledWeekdays(gym));
    });
  });
}
