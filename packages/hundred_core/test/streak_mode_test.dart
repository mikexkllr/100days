import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

final DayKey _start = DayKey(2026, 3, 2); // a Monday

final Habit _reading = Habit.fromCategory(HabitCategory.reading); // daily
final Habit _noSugar = Habit.fromCategory(HabitCategory.noSugar); // daily
final Habit _noAlcohol = Habit.fromCategory(HabitCategory.noAlcohol); // daily

Challenge _challenge(
  StreakMode mode, {
  List<Habit>? habits,
}) =>
    Challenge(
      id: 'c1',
      goal: const Goal(
        archetype: GoalArchetype.discipline,
        statement: 'Hold the line',
      ),
      habits: habits ?? <Habit>[_reading, _noSugar],
      startDay: _start,
      streakMode: mode,
    );

CheckIn _entry(Habit habit, DayKey day, {bool relapse = false}) => CheckIn(
      habitId: habit.id,
      category: habit.category,
      day: day,
      value: relapse ? 0 : habit.target,
      loggedAt: day.toDateTime().add(const Duration(hours: 20)),
      relapse: relapse,
    );

/// Days 0..3: everything done, except whatever [day2] says for day 2.
Map<String, DayLog> _logs(List<CheckIn> Function(DayKey day) day2) {
  final logs = <String, DayLog>{};
  for (var i = 0; i < 4; i++) {
    final day = _start.addDays(i);
    logs[day.toString()] = DayLog(
      day: day,
      entries: i == 2
          ? day2(day)
          : <CheckIn>[_entry(_reading, day), _entry(_noSugar, day)],
    );
  }
  return logs;
}

StreakStats _streak(Challenge challenge, Map<String, DayLog> logs,
        {int today = 3}) =>
    computeStreak(
      challenge: challenge,
      logsByDay: logs,
      frozenDays: const <String>{},
      today: _start.addDays(today),
    );

void main() {
  final relapseDay = _logs((DayKey d) =>
      <CheckIn>[_entry(_reading, d), _entry(_noSugar, d, relapse: true)]);
  final missedDay = _logs((DayKey d) => <CheckIn>[_entry(_noSugar, d)]);
  final emptyDay = _logs((DayKey d) => const <CheckIn>[]);

  group('a relapse never costs the other habits', () {
    for (final mode in StreakMode.values) {
      test('${mode.name}: the challenge streak survives it', () {
        final stats = _streak(_challenge(mode), relapseDay);
        expect(stats.previousBest, 0, reason: 'the streak never broke');
        expect(stats.current, greaterThanOrEqualTo(3));
      });

      test('${mode.name}: only the relapsed habit starts over', () {
        final challenge = _challenge(mode);
        int streakOf(Habit h) => habitStreak(
              habit: h,
              logsByDay: relapseDay,
              startDay: challenge.startDay,
              today: _start.addDays(3),
            );
        expect(streakOf(_noSugar), 1);
        expect(streakOf(_reading), 4);
      });
    }

    test('balanced: the day counts once everything else is done', () {
      final stats = _streak(_challenge(StreakMode.balanced), relapseDay);
      expect(stats.current, 4);
      expect(stats.completedDays, 4);
    });

    test('strict: the day holds the streak but does not add to it', () {
      final stats = _streak(_challenge(StreakMode.strict), relapseDay);
      expect(stats.current, 3);
      expect(stats.completedDays, 3);
    });

    test('gentle: the day holds the streak but does not add to it', () {
      final stats = _streak(_challenge(StreakMode.gentle), relapseDay);
      expect(stats.current, 3);
    });

    test('relapsing on everything is a day with nothing done', () {
      final habits = <Habit>[_noSugar, _noAlcohol];
      final logs = <String, DayLog>{
        for (var i = 0; i < 3; i++)
          _start.addDays(i).toString(): DayLog(
            day: _start.addDays(i),
            entries: <CheckIn>[
              for (final h in habits)
                _entry(h, _start.addDays(i), relapse: i == 1),
            ],
          ),
      };
      for (final mode in StreakMode.values) {
        final stats =
            _streak(_challenge(mode, habits: habits), logs, today: 2);
        expect(stats.current, 1, reason: mode.name);
        expect(stats.previousBest, 1, reason: mode.name);
      }
    });
  });

  group('a habit left undone', () {
    test('breaks the streak in balanced and strict', () {
      for (final mode in <StreakMode>[StreakMode.balanced, StreakMode.strict]) {
        final stats = _streak(_challenge(mode), missedDay);
        expect(stats.current, 1, reason: mode.name);
        expect(stats.previousBest, 2, reason: mode.name);
      }
    });

    test('only holds the streak in gentle', () {
      final stats = _streak(_challenge(StreakMode.gentle), missedDay);
      expect(stats.current, 3);
      expect(stats.previousBest, 0);
    });

    test('a day with nothing done breaks even the gentle streak', () {
      final stats = _streak(_challenge(StreakMode.gentle), emptyDay);
      expect(stats.current, 1);
      expect(stats.previousBest, 2);
    });
  });

  group('today', () {
    test('a held day is safe until midnight without counting as done', () {
      final stats = _streak(_challenge(StreakMode.strict), relapseDay, today: 2);
      expect(stats.doneToday, isFalse);
      expect(stats.heldToday, isTrue);
      expect(stats.atRisk, isFalse);
      expect(stats.current, 2);
    });

    test('a held day shows as held on the week strip', () {
      expect(
        dayMarkFor(
          challenge: _challenge(StreakMode.gentle),
          day: _start.addDays(2),
          today: _start.addDays(3),
          logsByDay: missedDay,
          frozenDays: const <String>{},
        ),
        DayMark.held,
      );
    });
  });

  group('changing the mode', () {
    test('does not re-score the days before the change', () {
      final changed = _challenge(StreakMode.balanced)
          .withStreakMode(StreakMode.gentle, from: _start.addDays(3));
      expect(changed.streakModeOn(_start.addDays(2)), StreakMode.balanced);
      expect(changed.streakModeOn(_start.addDays(3)), StreakMode.gentle);

      // The miss on day 2 broke the balanced streak; going gentle on day 3
      // does not bring it back.
      final stats = _streak(changed, missedDay);
      expect(stats.current, 1);
    });

    test('survives JSON and reaches friends', () {
      final changed = _challenge(StreakMode.strict)
          .withStreakMode(StreakMode.gentle, from: _start.addDays(5));
      final back = Challenge.fromJson(changed.toJson());
      expect(back.streakMode, StreakMode.gentle);
      expect(back.streakModeOn(_start), StreakMode.strict);

      final public = publicViewOf(changed);
      expect(public.streakMode, StreakMode.gentle);
      expect(public.streakModeOn(_start), StreakMode.strict);
    });

    test('a challenge without a mode is balanced', () {
      final json = _challenge(StreakMode.balanced).toJson()
        ..remove('streakMode');
      expect(Challenge.fromJson(json).streakMode, StreakMode.balanced);
    });
  });
}
