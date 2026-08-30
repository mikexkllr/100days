import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

final DayKey _start = DayKey(2026, 3, 2); // a Monday

Challenge _challenge(List<Habit> habits, {DayKey? startDay}) => Challenge(
      id: 'c1',
      goal: const Goal(
        archetype: GoalArchetype.getFit,
        statement: '100 days, no negotiating',
      ),
      habits: habits,
      startDay: startDay ?? _start,
    );

DateTime _at(DayKey day, int hour, [int minute = 0]) =>
    DateTime(day.year, day.month, day.day, hour, minute);

/// A day of health data, as the folder would have produced it.
Map<String, DailyHealthTotals> _totals(
  DayKey day,
  Map<HealthMetric, num> values, {
  Set<String> devices = const <String>{},
}) =>
    <String, DailyHealthTotals>{
      day.toString():
          DailyHealthTotals(day: day, values: values, devices: devices),
    };

DayLog _logWith(DayKey day, List<CheckIn> entries) =>
    DayLog(day: day, entries: entries);

CheckIn _manual(Habit habit, DayKey day, num value) => CheckIn(
      habitId: habit.id,
      category: habit.category,
      day: day,
      value: value,
      loggedAt: _at(day, 20),
    );

CheckIn _imported(Habit habit, DayKey day, num value, {num? raw}) => CheckIn(
      habitId: habit.id,
      category: habit.category,
      day: day,
      value: value,
      loggedAt: _at(day, 20),
      health: HealthProvenance(
        platform: HealthPlatform.healthConnect,
        metric: healthBindingFor(habit.category)!.metric,
        rawValue: raw ?? value,
      ),
    );

HealthSkipReason? _reasonFor(
  HealthImportPlan plan,
  Habit habit,
  DayKey day,
) {
  for (final HealthSkip skip in plan.skips) {
    if (skip.habit.id == habit.id && skip.day == day) return skip.reason;
  }
  return null;
}

void main() {
  final Habit steps = Habit.fromCategory(HabitCategory.steps); // daily, 10 000
  final Habit gym = Habit.fromCategory(HabitCategory.gym); // 4 days/week
  final Habit cardio = Habit.fromCategory(HabitCategory.cardio); // 3 days/week
  final Habit water = Habit.fromCategory(HabitCategory.water); // daily, 8
  final Habit noSugar = Habit.fromCategory(HabitCategory.noSugar);

  group('bindings', () {
    test('never bind an abstinence habit to a sensor', () {
      for (final HealthBinding binding in kHealthBindings) {
        expect(
          habitDefinition(binding.category).kind,
          HabitKind.build,
          reason: 'no sensor can prove someone did not do something',
        );
      }
    });

    test('every bound metric exists in the metric catalogue', () {
      for (final HealthBinding binding in kHealthBindings) {
        expect(kHealthMetrics.containsKey(binding.metric), isTrue);
      }
    });

    test('converts millilitres into glasses, rounding down', () {
      final HealthBinding binding = healthBindingFor(HabitCategory.water)!;
      expect(binding.habitValueFor(2000), 8);
      expect(binding.habitValueFor(2249), 8); // 8.99 glasses is still 8
      expect(binding.habitValueFor(250), 1);
    });

    test('yields nothing below the floor', () {
      final HealthBinding binding = healthBindingFor(HabitCategory.gym)!;
      expect(binding.habitValueFor(19), 0);
      expect(binding.habitValueFor(20), 1);
    });

    test('a done-unit habit converts to exactly 1, not to the raw minutes', () {
      final HealthBinding binding = healthBindingFor(HabitCategory.gym)!;
      expect(binding.habitValueFor(75), 1);
    });

    test('asks only for the metrics the enabled habits need', () {
      expect(
        metricsFor(
          <HabitCategory>[HabitCategory.steps],
          platform: HealthPlatform.healthConnect,
        ),
        <HealthMetric>{HealthMetric.steps},
      );
    });

    test('drops metrics the platform cannot answer for', () {
      expect(
        metricsFor(
          <HabitCategory>[HabitCategory.meditation],
          platform: HealthPlatform.healthConnect,
        ),
        isEmpty,
        reason: 'Health Connect has no mindfulness record type',
      );
      expect(
        metricsFor(
          <HabitCategory>[HabitCategory.meditation],
          platform: HealthPlatform.appleHealth,
        ),
        <HealthMetric>{HealthMetric.mindfulMinutes},
      );
    });
  });

  group('session folding', () {
    test('counts one run once when two apps both recorded it', () {
      final Map<String, DailyHealthTotals> folded = foldHealthData(
        sessions: <HealthSession>[
          HealthSession(
            metric: HealthMetric.cardioMinutes,
            start: _at(_start, 7),
            end: _at(_start, 8),
            device: 'Pixel Watch',
          ),
          HealthSession(
            metric: HealthMetric.cardioMinutes,
            start: _at(_start, 7, 2),
            end: _at(_start, 7, 58),
            device: 'Strava',
          ),
        ],
      );
      expect(folded[_start.toString()]!.valueOf(HealthMetric.cardioMinutes), 60);
      expect(
        folded[_start.toString()]!.devices,
        <String>{'Pixel Watch', 'Strava'},
      );
    });

    test('adds up genuinely separate sessions', () {
      final Map<String, DailyHealthTotals> folded = foldHealthData(
        sessions: <HealthSession>[
          HealthSession(
            metric: HealthMetric.cardioMinutes,
            start: _at(_start, 7),
            end: _at(_start, 7, 30),
          ),
          HealthSession(
            metric: HealthMetric.cardioMinutes,
            start: _at(_start, 18),
            end: _at(_start, 18, 20),
          ),
        ],
      );
      expect(folded[_start.toString()]!.valueOf(HealthMetric.cardioMinutes), 50);
    });

    test('joins sessions a watch split at a pause', () {
      final Map<String, DailyHealthTotals> folded = foldHealthData(
        sessions: <HealthSession>[
          HealthSession(
            metric: HealthMetric.strengthMinutes,
            start: _at(_start, 17),
            end: _at(_start, 17, 30),
          ),
          HealthSession(
            metric: HealthMetric.strengthMinutes,
            start: _at(_start, 17, 30),
            end: _at(_start, 18),
          ),
        ],
      );
      expect(
        folded[_start.toString()]!.valueOf(HealthMetric.strengthMinutes),
        60,
      );
    });

    test('does not merge a run into a lifting session it overlaps', () {
      final Map<String, DailyHealthTotals> folded = foldHealthData(
        sessions: <HealthSession>[
          HealthSession(
            metric: HealthMetric.cardioMinutes,
            start: _at(_start, 17),
            end: _at(_start, 18),
          ),
          HealthSession(
            metric: HealthMetric.strengthMinutes,
            start: _at(_start, 17, 30),
            end: _at(_start, 18, 30),
          ),
        ],
      );
      final DailyHealthTotals day = folded[_start.toString()]!;
      expect(day.valueOf(HealthMetric.cardioMinutes), 60);
      expect(day.valueOf(HealthMetric.strengthMinutes), 60);
    });

    test('books a night of sleep on the day you woke up', () {
      final DayKey tuesday = _start.addDays(1);
      final Map<String, DailyHealthTotals> folded = foldHealthData(
        sessions: <HealthSession>[
          HealthSession(
            metric: HealthMetric.sleepMinutes,
            start: _at(_start, 23),
            end: _at(tuesday, 7),
          ),
        ],
      );
      expect(folded.containsKey(_start.toString()), isFalse);
      expect(folded[tuesday.toString()]!.valueOf(HealthMetric.sleepMinutes), 480);
    });

    test('books a workout on the day it started, even past midnight', () {
      final DayKey tuesday = _start.addDays(1);
      final Map<String, DailyHealthTotals> folded = foldHealthData(
        sessions: <HealthSession>[
          HealthSession(
            metric: HealthMetric.cardioMinutes,
            start: _at(_start, 23, 40),
            end: _at(tuesday, 0, 20),
          ),
        ],
      );
      expect(folded[_start.toString()]!.valueOf(HealthMetric.cardioMinutes), 40);
      expect(folded.containsKey(tuesday.toString()), isFalse);
    });

    test('ignores a session that ends before it starts', () {
      final Map<String, DailyHealthTotals> folded = foldHealthData(
        sessions: <HealthSession>[
          HealthSession(
            metric: HealthMetric.cardioMinutes,
            start: _at(_start, 8),
            end: _at(_start, 7),
          ),
        ],
      );
      expect(folded, isEmpty);
    });
  });

  group('import planning', () {
    test('writes a check-in for a day the watch covered', () {
      final HealthImportPlan plan = planHealthImport(
        challenge: _challenge(<Habit>[steps]),
        logsByDay: const <String, DayLog>{},
        totalsByDay: _totals(
          _start,
          <HealthMetric, num>{HealthMetric.steps: 11200},
          devices: <String>{'Pixel Watch'},
        ),
        enabledCategories: <HabitCategory>{HabitCategory.steps},
        platform: HealthPlatform.healthConnect,
        today: _start,
      );

      expect(plan.imports, hasLength(1));
      final HealthImport import = plan.imports.single;
      expect(import.value, 11200);
      expect(import.replacesEarlierImport, isFalse);
      expect(import.provenance.metric, HealthMetric.steps);
      expect(import.provenance.rawValue, 11200);
      expect(import.provenance.device, 'Pixel Watch');
      expect(plan.newEntries, 1);
    });

    test('leaves a habit the user did not switch on alone', () {
      final HealthImportPlan plan = planHealthImport(
        challenge: _challenge(<Habit>[steps]),
        logsByDay: const <String, DayLog>{},
        totalsByDay:
            _totals(_start, <HealthMetric, num>{HealthMetric.steps: 11200}),
        enabledCategories: const <HabitCategory>{},
        platform: HealthPlatform.healthConnect,
        today: _start,
      );
      expect(plan.imports, isEmpty);
      expect(
        _reasonFor(plan, steps, _start),
        HealthSkipReason.notEnabled,
      );
    });

    test('never touches an abstinence habit', () {
      final HealthImportPlan plan = planHealthImport(
        challenge: _challenge(<Habit>[noSugar]),
        logsByDay: const <String, DayLog>{},
        totalsByDay:
            _totals(_start, <HealthMetric, num>{HealthMetric.steps: 20000}),
        enabledCategories: HabitCategory.values.toSet(),
        platform: HealthPlatform.healthConnect,
        today: _start,
      );
      expect(plan.imports, isEmpty);
      expect(_reasonFor(plan, noSugar, _start), HealthSkipReason.noBinding);
    });

    test('does not overwrite a number a person typed in', () {
      final HealthImportPlan plan = planHealthImport(
        challenge: _challenge(<Habit>[water]),
        logsByDay: <String, DayLog>{
          _start.toString(): _logWith(_start, <CheckIn>[
            _manual(water, _start, 6),
          ]),
        },
        totalsByDay:
            _totals(_start, <HealthMetric, num>{HealthMetric.water: 2500}),
        enabledCategories: <HabitCategory>{HabitCategory.water},
        platform: HealthPlatform.healthConnect,
        today: _start,
      );
      expect(plan.imports, isEmpty);
      expect(_reasonFor(plan, water, _start), HealthSkipReason.manualEntry);
    });

    test('raises its own earlier import as the day goes on', () {
      final HealthImportPlan plan = planHealthImport(
        challenge: _challenge(<Habit>[steps]),
        logsByDay: <String, DayLog>{
          _start.toString(): _logWith(_start, <CheckIn>[
            _imported(steps, _start, 4000),
          ]),
        },
        totalsByDay:
            _totals(_start, <HealthMetric, num>{HealthMetric.steps: 9000}),
        enabledCategories: <HabitCategory>{HabitCategory.steps},
        platform: HealthPlatform.healthConnect,
        today: _start,
      );
      expect(plan.imports, hasLength(1));
      expect(plan.imports.single.value, 9000);
      expect(plan.imports.single.replacesEarlierImport, isTrue);
      expect(plan.updatedEntries, 1);
    });

    test('writes nothing when the reading has not grown', () {
      final HealthImportPlan plan = planHealthImport(
        challenge: _challenge(<Habit>[steps]),
        logsByDay: <String, DayLog>{
          _start.toString(): _logWith(_start, <CheckIn>[
            _imported(steps, _start, 9000),
          ]),
        },
        totalsByDay:
            _totals(_start, <HealthMetric, num>{HealthMetric.steps: 9000}),
        enabledCategories: <HabitCategory>{HabitCategory.steps},
        platform: HealthPlatform.healthConnect,
        today: _start,
      );
      expect(plan.imports, isEmpty);
      expect(_reasonFor(plan, steps, _start), HealthSkipReason.notHigher);
    });

    test('never lowers a value the sensor revised downwards', () {
      final HealthImportPlan plan = planHealthImport(
        challenge: _challenge(<Habit>[steps]),
        logsByDay: <String, DayLog>{
          _start.toString(): _logWith(_start, <CheckIn>[
            _imported(steps, _start, 12000),
          ]),
        },
        totalsByDay:
            _totals(_start, <HealthMetric, num>{HealthMetric.steps: 9000}),
        enabledCategories: <HabitCategory>{HabitCategory.steps},
        platform: HealthPlatform.healthConnect,
        today: _start,
      );
      expect(plan.imports, isEmpty);
      expect(_reasonFor(plan, steps, _start), HealthSkipReason.notHigher);
    });

    test('a confessed relapse outranks the sensor', () {
      final HealthImportPlan plan = planHealthImport(
        challenge: _challenge(<Habit>[steps]),
        logsByDay: <String, DayLog>{
          _start.toString(): _logWith(_start, <CheckIn>[
            CheckIn(
              habitId: noSugar.id,
              category: noSugar.category,
              day: _start,
              value: 0,
              loggedAt: _at(_start, 22),
              relapse: true,
            ),
          ]),
        },
        totalsByDay:
            _totals(_start, <HealthMetric, num>{HealthMetric.steps: 15000}),
        enabledCategories: <HabitCategory>{HabitCategory.steps},
        platform: HealthPlatform.healthConnect,
        today: _start,
      );
      expect(plan.imports, isEmpty);
      expect(_reasonFor(plan, steps, _start), HealthSkipReason.relapseLogged);
    });

    test('leaves rest days empty so they cannot earn XP', () {
      // gym runs Mon/Tue/Thu/Fri, so Wednesday is a rest day.
      final DayKey wednesday = _start.addDays(2);
      final HealthImportPlan plan = planHealthImport(
        challenge: _challenge(<Habit>[gym]),
        logsByDay: const <String, DayLog>{},
        totalsByDay: _totals(
          wednesday,
          <HealthMetric, num>{HealthMetric.strengthMinutes: 60},
        ),
        enabledCategories: <HabitCategory>{HabitCategory.gym},
        platform: HealthPlatform.healthConnect,
        today: wednesday,
      );
      expect(plan.imports, isEmpty);
      expect(_reasonFor(plan, gym, wednesday), HealthSkipReason.restDay);
    });

    test('ignores days further back than the backfill window', () {
      final DayKey today = _start.addDays(30);
      final DayKey longAgo = _start.addDays(2);
      final HealthImportPlan plan = planHealthImport(
        challenge: _challenge(<Habit>[steps]),
        logsByDay: const <String, DayLog>{},
        totalsByDay:
            _totals(longAgo, <HealthMetric, num>{HealthMetric.steps: 12000}),
        enabledCategories: <HabitCategory>{HabitCategory.steps},
        platform: HealthPlatform.healthConnect,
        today: today,
      );
      expect(plan.imports, isEmpty);
      expect(_reasonFor(plan, steps, longAgo), HealthSkipReason.outsideWindow);
    });

    test('ignores days before the challenge even inside the window', () {
      final DayKey beforeStart = _start.addDays(-2);
      final HealthImportPlan plan = planHealthImport(
        challenge: _challenge(<Habit>[steps]),
        logsByDay: const <String, DayLog>{},
        totalsByDay: _totals(
          beforeStart,
          <HealthMetric, num>{HealthMetric.steps: 12000},
        ),
        enabledCategories: <HabitCategory>{HabitCategory.steps},
        platform: HealthPlatform.healthConnect,
        today: _start,
      );
      expect(plan.imports, isEmpty);
      expect(
        _reasonFor(plan, steps, beforeStart),
        HealthSkipReason.outsideWindow,
      );
    });

    test('ignores a day in the future', () {
      final DayKey tomorrow = _start.addDays(1);
      final HealthImportPlan plan = planHealthImport(
        challenge: _challenge(<Habit>[steps]),
        logsByDay: const <String, DayLog>{},
        totalsByDay:
            _totals(tomorrow, <HealthMetric, num>{HealthMetric.steps: 12000}),
        enabledCategories: <HabitCategory>{HabitCategory.steps},
        platform: HealthPlatform.healthConnect,
        today: _start,
      );
      expect(plan.imports, isEmpty);
    });

    test('skips a habit whose metric this platform does not have', () {
      final Habit meditation = Habit.fromCategory(HabitCategory.meditation);
      final HealthImportPlan plan = planHealthImport(
        challenge: _challenge(<Habit>[meditation]),
        logsByDay: const <String, DayLog>{},
        totalsByDay: _totals(
          _start,
          <HealthMetric, num>{HealthMetric.mindfulMinutes: 15},
        ),
        enabledCategories: <HabitCategory>{HabitCategory.meditation},
        platform: HealthPlatform.healthConnect,
        today: _start,
      );
      expect(plan.imports, isEmpty);
      expect(
        _reasonFor(plan, meditation, _start),
        HealthSkipReason.unsupportedMetric,
      );

      final HealthImportPlan onApple = planHealthImport(
        challenge: _challenge(<Habit>[meditation]),
        logsByDay: const <String, DayLog>{},
        totalsByDay: _totals(
          _start,
          <HealthMetric, num>{HealthMetric.mindfulMinutes: 15},
        ),
        enabledCategories: <HabitCategory>{HabitCategory.meditation},
        platform: HealthPlatform.appleHealth,
        today: _start,
      );
      expect(onApple.imports, hasLength(1));
      expect(onApple.imports.single.value, 15);
    });

    test('drops a reading below the floor without writing an event', () {
      final HealthImportPlan plan = planHealthImport(
        challenge: _challenge(<Habit>[gym]),
        logsByDay: const <String, DayLog>{},
        totalsByDay: _totals(
          _start,
          <HealthMetric, num>{HealthMetric.strengthMinutes: 6},
        ),
        enabledCategories: <HabitCategory>{HabitCategory.gym},
        platform: HealthPlatform.healthConnect,
        today: _start,
      );
      expect(plan.imports, isEmpty);
      expect(_reasonFor(plan, gym, _start), HealthSkipReason.belowFloor);
    });

    test('fills several habits and days in one round, oldest first', () {
      final DayKey today = _start.addDays(3); // Thursday
      final Map<String, DailyHealthTotals> totals = <String, DailyHealthTotals>{
        ..._totals(_start, <HealthMetric, num>{
          HealthMetric.steps: 12000,
          HealthMetric.cardioMinutes: 35,
        }),
        ..._totals(today, <HealthMetric, num>{HealthMetric.steps: 8000}),
      };

      final HealthImportPlan plan = planHealthImport(
        challenge: _challenge(<Habit>[steps, cardio]),
        logsByDay: const <String, DayLog>{},
        totalsByDay: totals,
        enabledCategories: <HabitCategory>{
          HabitCategory.steps,
          HabitCategory.cardio,
        },
        platform: HealthPlatform.healthConnect,
        today: today,
      );

      expect(plan.imports, hasLength(3));
      expect(plan.imports.first.day, _start);
      expect(plan.days, <String>{_start.toString(), today.toString()});
    });

    test('an under-target import still records what the watch measured', () {
      final HealthImportPlan plan = planHealthImport(
        challenge: _challenge(<Habit>[steps]),
        logsByDay: const <String, DayLog>{},
        totalsByDay:
            _totals(_start, <HealthMetric, num>{HealthMetric.steps: 6000}),
        enabledCategories: <HabitCategory>{HabitCategory.steps},
        platform: HealthPlatform.healthConnect,
        today: _start,
      );
      // Below the 10 000 target, so the day is not complete — but the progress
      // is visible instead of the app pretending nothing happened.
      expect(plan.imports.single.value, 6000);
      expect(plan.imports.single.value < steps.target, isTrue);
    });
  });

  group('read window', () {
    test('never reaches back past the start of the challenge', () {
      final ({DayKey from, DayKey to}) window = healthReadWindow(
        challenge: _challenge(<Habit>[steps]),
        today: _start.addDays(2),
      );
      expect(window.from, _start);
      expect(window.to, _start.addDays(2));
    });

    test('caps the backfill on a long-running challenge', () {
      final DayKey today = _start.addDays(60);
      final ({DayKey from, DayKey to}) window = healthReadWindow(
        challenge: _challenge(<Habit>[steps]),
        today: today,
      );
      expect(window.from, today.addDays(-kHealthBackfillDays));
      expect(window.to, today);
    });
  });

  group('provenance on the wire', () {
    test('survives a round trip through the payload', () {
      const HealthProvenance provenance = HealthProvenance(
        platform: HealthPlatform.appleHealth,
        metric: HealthMetric.cardioMinutes,
        rawValue: 42,
        device: 'Apple Watch',
      );
      final CheckIn checkIn = CheckIn(
        habitId: cardio.id,
        category: cardio.category,
        day: _start,
        value: 42,
        loggedAt: _at(_start, 19),
        health: provenance,
      );

      final CheckIn parsed = CheckIn.fromPayload(
        checkIn.toPayload(),
        loggedAt: _at(_start, 19),
      );
      expect(parsed.isFromHealth, isTrue);
      expect(parsed.health, provenance);
    });

    test('a manual check-in carries no health block at all', () {
      final CheckIn checkIn = _manual(water, _start, 6);
      expect(checkIn.toPayload().containsKey('health'), isFalse);
      expect(
        CheckIn.fromPayload(checkIn.toPayload(), loggedAt: _at(_start, 20))
            .isFromHealth,
        isFalse,
      );
    });

    test('a payload from a newer version degrades to manual', () {
      final CheckIn parsed = CheckIn.fromPayload(
        <String, dynamic>{
          'habitId': steps.id,
          'category': steps.category.name,
          'day': _start.toString(),
          'value': 9000,
          'health': <String, dynamic>{
            'platform': 'wearOsDirect',
            'metric': 'floorsClimbed',
            'raw': 12,
          },
        },
        loggedAt: _at(_start, 20),
      );
      expect(parsed.isFromHealth, isFalse);
      expect(parsed.value, 9000);
    });
  });
}
