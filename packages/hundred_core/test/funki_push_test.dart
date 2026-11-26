import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

final DayKey _start = DayKey(2026, 1, 1);

final Challenge _challenge = Challenge(
  id: 'c1',
  goal: const Goal(
    archetype: GoalArchetype.discipline,
    statement: '100 Tage nicht verhandeln',
  ),
  habits: <Habit>[Habit.fromCategory(HabitCategory.reading)],
  startDay: _start,
);

/// Day [number] of the challenge in [state], with [streak] alive.
StreakOutlook _day(int number, OutlookState state, [int streak = 0]) =>
    StreakOutlook(
      day: _start.addDays(number - 1),
      state: state,
      streak: streak,
      week: const <DayMark>[],
    );

void main() {
  group('Funki\'s reminders', () {
    test('a day that is done, resting or frozen gets none', () {
      final List<FunkiPush?> pushes = funkiReminders(<StreakOutlook>[
        _day(10, OutlookState.done, 10),
        _day(11, OutlookState.rest, 10),
        _day(12, OutlookState.frozen, 10),
      ], _challenge);
      expect(pushes, <FunkiPush?>[null, null, null]);
    });

    test('with a streak alive the sentences take turns', () {
      final List<FunkiPush?> pushes = funkiReminders(<StreakOutlook>[
        for (int n = 8; n < 12; n++) _day(n, OutlookState.open, 5),
      ], _challenge);
      final Set<FunkiPushTemplate> said =
          pushes.map((FunkiPush? p) => p!.template).toSet();
      expect(said, hasLength(4), reason: 'never the same two days running');
      expect(pushes.first!.streak, 5);
      expect(pushes.first!.dayNumber, 8);
      expect(pushes.first!.totalDays, _challenge.lengthDays);
    });

    test('a milestone day says so — but not day 1', () {
      expect(
        funkiReminders(<StreakOutlook>[_day(30, OutlookState.open, 12)],
                _challenge)
            .single!
            .template,
        FunkiPushTemplate.milestone,
      );
      expect(
        funkiReminders(<StreakOutlook>[_day(1, OutlookState.open)], _challenge)
            .single!
            .template,
        isNot(FunkiPushTemplate.milestone),
      );
    });

    test('after the streak goes out he asks, quieter each day, then stops',
        () {
      final List<FunkiPush?> pushes = funkiReminders(<StreakOutlook>[
        _day(20, OutlookState.open, 12),
        for (int n = 21; n < 29; n++) _day(n, OutlookState.cold),
      ], _challenge);
      expect(
        pushes.skip(1).map((FunkiPush? p) => p?.template).toList(),
        <FunkiPushTemplate?>[
          FunkiPushTemplate.flameOut,
          FunkiPushTemplate.inTheDark,
          FunkiPushTemplate.dayOneAgain,
          null,
          FunkiPushTemplate.goodbye,
          null,
          null,
          null,
        ],
      );
      // The day after says which flame it was.
      expect(pushes[1]!.lostStreak, 12);
    });

    test('someone who never had a streak is not told they lost one', () {
      final List<FunkiPush?> pushes = funkiReminders(<StreakOutlook>[
        for (int n = 4; n < 7; n++) _day(n, OutlookState.cold),
      ], _challenge);
      expect(
        pushes.map((FunkiPush? p) => p!.template),
        <FunkiPushTemplate>[
          FunkiPushTemplate.firstSpark,
          FunkiPushTemplate.startSmall,
          FunkiPushTemplate.dayOneAgain,
        ],
      );
    });
  });

  group('Funki\'s last call', () {
    test('only for an open day with a streak worth losing', () {
      final List<FunkiPush?> calls = funkiLastCalls(<StreakOutlook>[
        _day(10, OutlookState.open, 9),
        _day(11, OutlookState.open, 1),
        _day(12, OutlookState.done, 9),
        _day(13, OutlookState.frozen, 9),
        _day(14, OutlookState.rest, 9),
        _day(15, OutlookState.cold),
      ], _challenge);
      expect(calls.first, isNotNull);
      expect(calls.first!.streak, 9);
      expect(calls.skip(1), everyElement(isNull));
    });

    test('the sentence changes with the streak', () {
      final Set<FunkiPushTemplate> said = <FunkiPushTemplate>{
        for (int streak = 2; streak < 5; streak++)
          funkiLastCalls(<StreakOutlook>[_day(9, OutlookState.open, streak)],
                  _challenge)
              .single!
              .template,
      };
      expect(said, hasLength(3));
    });
  });
}
