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

DayLog _log(DayKey day, List<Habit> habits) => DayLog(
      day: day,
      entries: <CheckIn>[
        for (final Habit h in habits)
          CheckIn(
            habitId: h.id,
            category: h.category,
            day: day,
            value: h.target,
            loggedAt: day.toDateTime().add(const Duration(hours: 20)),
          ),
      ],
    );

Map<String, DayLog> _logs(Iterable<int> offsets, List<Habit> habits) =>
    <String, DayLog>{
      for (final int offset in offsets)
        _start.addDays(offset).toString(): _log(_start.addDays(offset), habits),
    };

StreakStats _streak(
  Challenge challenge,
  Map<String, DayLog> logs,
  DayKey today, {
  Set<String> frozen = const <String>{},
}) =>
    computeStreak(
      challenge: challenge,
      logsByDay: logs,
      frozenDays: frozen,
      today: today,
    );

void main() {
  final noSugar = Habit.fromCategory(HabitCategory.noSugar); // daily
  final gym = Habit.fromCategory(HabitCategory.gym); // Mon, Tue, Thu, Fri

  group('flame stages', () {
    test('grow with the streak and never skip a threshold', () {
      expect(flameStageFor(0), FlameStage.ember);
      expect(flameStageFor(1), FlameStage.spark);
      expect(flameStageFor(2), FlameStage.spark);
      expect(flameStageFor(3), FlameStage.flicker);
      expect(flameStageFor(7), FlameStage.flame);
      expect(flameStageFor(13), FlameStage.flame);
      expect(flameStageFor(14), FlameStage.blaze);
      expect(flameStageFor(30), FlameStage.inferno);
      expect(flameStageFor(50), FlameStage.blue);
      expect(flameStageFor(100), FlameStage.plasma);
      expect(flameStageFor(200), FlameStage.nova);
      expect(flameStageFor(365), FlameStage.galaxy);
      expect(flameStageFor(5000), FlameStage.galaxy);
    });

    test('every threshold is a milestone day', () {
      for (final FlameStage stage in FlameStage.values.skip(1)) {
        expect(kMilestoneDays, contains(stage.minStreak), reason: stage.name);
      }
    });

    test('count down to the next stage and fill a bar towards it', () {
      expect(daysToNextStage(0), 1);
      expect(daysToNextStage(4), 3);
      expect(daysToNextStage(49), 1);
      expect(daysToNextStage(365), isNull);

      expect(stageProgress(7), 0);
      expect(stageProgress(10), closeTo(3 / 7, 1e-9));
      expect(stageProgress(400), 1);
    });
  });

  group('previous best', () {
    test('is the longest run that ended before the current one', () {
      final challenge = _challenge(<Habit>[noSugar]);
      // Five days, a miss on day 6, then three days.
      final logs = _logs(<int>[0, 1, 2, 3, 4, 6, 7, 8], <Habit>[noSugar]);
      final stats = _streak(challenge, logs, _start.addDays(8));
      expect(stats.current, 3);
      expect(stats.longest, 5);
      expect(stats.previousBest, 5);
      expect(stats.beatPreviousBestToday, isFalse);
    });

    test('is beaten on exactly one day per comeback', () {
      final challenge = _challenge(<Habit>[noSugar]);
      final days = <int>[0, 1, 2, 4, 5, 6, 7, 8];
      bool beatenOn(int offset) => _streak(
            challenge,
            _logs(days.where((int d) => d <= offset), <Habit>[noSugar]),
            _start.addDays(offset),
          ).beatPreviousBestToday;

      expect(beatenOn(6), isFalse); // 3 days, ties the old best
      expect(beatenOn(7), isTrue); // 4 days, one past it
      expect(beatenOn(8), isFalse); // already beaten yesterday
    });

    test('does not exist for a streak that never broke', () {
      final challenge = _challenge(<Habit>[noSugar]);
      final stats = _streak(
        challenge,
        _logs(List<int>.generate(10, (int i) => i), <Habit>[noSugar]),
        _start.addDays(9),
      );
      expect(stats.previousBest, 0);
      expect(stats.beatPreviousBestToday, isFalse);
    });
  });

  group('day marks', () {
    test('follow the same rules the streak counts with', () {
      final challenge = _challenge(<Habit>[gym]);
      final today = _start.addDays(3); // Thursday
      final logs = _logs(<int>[0], <Habit>[gym]); // only Monday done
      final marks = weekMarks(
        challenge: challenge,
        day: today,
        today: today,
        logsByDay: logs,
        frozenDays: const <String>{},
      );
      expect(marks, <DayMark>[
        DayMark.done, // Mon
        DayMark.missed, // Tue
        DayMark.rest, // Wed
        DayMark.open, // Thu, today
        DayMark.upcoming, // Fri
        DayMark.rest, // Sat
        DayMark.rest, // Sun
      ]);
    });

    test('show a freeze and the days before the start', () {
      final challenge = _challenge(<Habit>[noSugar]);
      final today = _start.addDays(1);
      final marks = weekMarks(
        challenge: challenge,
        day: _start.addDays(-1), // the Sunday before
        today: today,
        logsByDay: _logs(<int>[0], <Habit>[noSugar]),
        frozenDays: <String>{today.toString()},
      );
      expect(marks.take(6), everyElement(DayMark.none));
      expect(marks.last, DayMark.none);
      expect(
        dayMarkFor(
          challenge: challenge,
          day: today,
          today: today,
          logsByDay: _logs(<int>[0], <Habit>[noSugar]),
          frozenDays: <String>{today.toString()},
        ),
        DayMark.frozen,
      );
    });
  });

  group('widget outlook', () {
    test('a done day keeps the streak until the next scheduled day', () {
      final challenge = _challenge(<Habit>[noSugar]);
      final today = _start.addDays(4);
      final logs = _logs(<int>[0, 1, 2, 3, 4], <Habit>[noSugar]);
      final outlook = projectOutlook(
        challenge: challenge,
        streak: _streak(challenge, logs, today),
        today: today,
        logsByDay: logs,
        frozenDays: const <String>{},
        days: 3,
      );

      expect(outlook[0].state, OutlookState.done);
      expect(outlook[0].streak, 5);
      expect(outlook[0].stage, FlameStage.flicker);
      // Tomorrow the same five days are alive and at stake.
      expect(outlook[1].state, OutlookState.open);
      expect(outlook[1].streak, 5);
      // If tomorrow passes untouched, the streak is gone the day after.
      expect(outlook[2].state, OutlookState.cold);
      expect(outlook[2].streak, 0);
    });

    test('an open day is the last day the streak can be saved', () {
      final challenge = _challenge(<Habit>[noSugar]);
      final today = _start.addDays(3);
      final logs = _logs(<int>[0, 1, 2], <Habit>[noSugar]);
      final outlook = projectOutlook(
        challenge: challenge,
        streak: _streak(challenge, logs, today),
        today: today,
        logsByDay: logs,
        frozenDays: const <String>{},
        days: 2,
      );
      expect(outlook[0].state, OutlookState.open);
      expect(outlook[0].streak, 3);
      expect(outlook[1].state, OutlookState.cold);
      expect(outlook[1].streak, 0);
    });

    test('rest days carry the streak instead of breaking it', () {
      final challenge = _challenge(<Habit>[gym]);
      final today = _start.addDays(1); // Tuesday
      final logs = _logs(<int>[0, 1], <Habit>[gym]);
      final outlook = projectOutlook(
        challenge: challenge,
        streak: _streak(challenge, logs, today),
        today: today,
        logsByDay: logs,
        frozenDays: const <String>{},
        days: 4,
      );
      expect(outlook.map((StreakOutlook o) => o.state), <OutlookState>[
        OutlookState.done, // Tue
        OutlookState.rest, // Wed
        OutlookState.open, // Thu
        OutlookState.cold, // Fri: Thursday was left undone
      ]);
      expect(outlook[1].streak, 2);
      expect(outlook[2].streak, 2);
    });

    test('a freeze holds today', () {
      final challenge = _challenge(<Habit>[noSugar]);
      final today = _start.addDays(2);
      final logs = _logs(<int>[0, 1], <Habit>[noSugar]);
      final frozen = <String>{today.toString()};
      final outlook = projectOutlook(
        challenge: challenge,
        streak: _streak(challenge, logs, today, frozen: frozen),
        today: today,
        logsByDay: logs,
        frozenDays: frozen,
        days: 2,
      );
      expect(outlook[0].state, OutlookState.frozen);
      expect(outlook[1].state, OutlookState.open);
      expect(outlook[1].streak, 2);
    });

    test('the week strip ages with the day it is shown on', () {
      final challenge = _challenge(<Habit>[noSugar]);
      final today = _start.addDays(1); // Tuesday, still open
      final logs = _logs(<int>[0], <Habit>[noSugar]);
      final outlook = projectOutlook(
        challenge: challenge,
        streak: _streak(challenge, logs, today),
        today: today,
        logsByDay: logs,
        frozenDays: const <String>{},
        days: 3,
      );
      expect(outlook[0].week.take(3), <DayMark>[
        DayMark.done,
        DayMark.open,
        DayMark.upcoming,
      ]);
      // Seen from Thursday: Tuesday and Wednesday went by untouched.
      expect(outlook[2].week.take(4), <DayMark>[
        DayMark.done,
        DayMark.missed,
        DayMark.missed,
        DayMark.open,
      ]);
      expect(outlook[2].toJson()['week'], hasLength(7));
    });
  });

  group('day reward', () {
    DayReward rewardOn(
      Challenge challenge,
      List<int> doneOffsets,
      int todayOffset,
    ) {
      final today = _start.addDays(todayOffset);
      final before = _projectionLogs(challenge, doneOffsets, todayOffset,
          includeToday: false);
      final after = _projectionLogs(challenge, doneOffsets, todayOffset,
          includeToday: true);
      final xpBefore = _xp(challenge, before, today);
      final xpAfter = _xp(challenge, after, today);
      return rewardForDay(
        challenge: challenge,
        today: today,
        before: _streak(challenge, before, today),
        after: _streak(challenge, after, today),
        xpBefore: xpBefore,
        xpAfter: xpAfter,
        xpToday: xpAfter - xpBefore,
      );
    }

    test('an ordinary day is a perfect day and nothing louder', () {
      final challenge = _challenge(<Habit>[noSugar]);
      final reward = rewardOn(challenge, <int>[0, 1, 2, 3, 4], 4);
      expect(reward.dayNumber, 5);
      expect(reward.streakBefore, 4);
      expect(reward.streak, 5);
      expect(reward.xpToday, greaterThan(0));
      expect(reward.highlights.last, RewardHighlight.perfectDay);
      expect(reward.isJackpot, isFalse);
    });

    test('day seven is a milestone and an evolution at once', () {
      final challenge = _challenge(<Habit>[noSugar]);
      final reward = rewardOn(
          challenge, List<int>.generate(7, (int i) => i), 6);
      expect(reward.top, RewardHighlight.milestone);
      expect(reward.highlights, contains(RewardHighlight.evolution));
      expect(reward.stageBefore, FlameStage.flicker);
      expect(reward.stage, FlameStage.flame);
      expect(reward.isJackpot, isTrue);
    });

    test('passing the old best is a record', () {
      final challenge = _challenge(<Habit>[noSugar]);
      // Days 1-2 done, day 3 missed, days 4-6 done: day 6 makes it three.
      final reward = rewardOn(challenge, <int>[0, 1, 3, 4, 5], 5);
      expect(reward.dayNumber, 6);
      expect(reward.streak, 3);
      expect(reward.highlights, contains(RewardHighlight.record));
    });

    test('the last day of the cycle beats everything', () {
      final challenge = _challenge(<Habit>[noSugar]);
      final reward = rewardOn(
          challenge, List<int>.generate(100, (int i) => i), 99);
      expect(reward.top, RewardHighlight.cycleComplete);
      expect(reward.highlights, contains(RewardHighlight.milestone));
      expect(reward.stage, FlameStage.plasma);
    });

    test('a level-up shows when lifetime XP crosses a threshold', () {
      final challenge = _challenge(<Habit>[noSugar]);
      final reward = rewardForDay(
        challenge: challenge,
        today: _start.addDays(4),
        before: StreakStats.empty,
        after: StreakStats.empty,
        xpBefore: xpRequiredForLevel(3) - 1,
        xpAfter: xpRequiredForLevel(3) + 10,
        xpToday: 11,
      );
      expect(reward.levelBefore, 2);
      expect(reward.level, 3);
      expect(reward.top, RewardHighlight.levelUp);
    });
  });
}

/// Logs for [doneOffsets] up to [todayOffset]; today's only when
/// [includeToday] — the state just before and just after the last tap.
Map<String, DayLog> _projectionLogs(
  Challenge challenge,
  List<int> doneOffsets,
  int todayOffset, {
  required bool includeToday,
}) =>
    _logs(
      doneOffsets.where(
          (int d) => d < todayOffset || (includeToday && d == todayOffset)),
      challenge.habits,
    );

int _xp(Challenge challenge, Map<String, DayLog> logs, DayKey today) {
  var total = 0;
  for (var i = 0; i <= today.differenceInDays(challenge.startDay); i++) {
    final day = challenge.startDay.addDays(i);
    total += xpForDay(
      challenge: challenge,
      day: day,
      log: logs[day.toString()],
      streakBeforeByHabit: const <String, int>{},
    );
  }
  return total;
}
