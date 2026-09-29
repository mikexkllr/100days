import 'package:meta/meta.dart';

import '../domain/challenge.dart';
import '../domain/check_in.dart';
import '../domain/habit.dart';
import '../domain/schedule.dart';
import '../util/dates.dart';
import 'health_mapping.dart';
import 'health_metric.dart';
import 'health_provenance.dart';
import 'health_sample.dart';

/// How far back an import is allowed to reach.
///
/// A watch that was offline for a week should still be able to fill in that
/// week, but an unbounded backfill would let a phone that has not been opened
/// since March suddenly write four months of history in one burst — which is
/// indistinguishable, in a friend's feed, from someone gaming their streak.
const int kHealthBackfillDays = 7;

/// Why a day produced no check-in. Every one of these is a rule the app is
/// deliberately following, so the settings screen can explain itself instead
/// of showing "0 imported" and leaving the user guessing.
enum HealthSkipReason {
  /// The habit has no metric that could stand in for it — every abstinence
  /// habit, and anything the user typed in themselves.
  noBinding,

  /// The user did not switch this habit on for import.
  notEnabled,

  /// The platform cannot answer for this metric (mindfulness on Android).
  unsupportedMetric,

  /// Outside the challenge, or further back than [kHealthBackfillDays].
  outsideWindow,

  /// The habit is not scheduled on that weekday. Writing a check-in anyway
  /// would hand out XP for a rest day the plan deliberately left empty.
  restDay,

  /// The user confessed a relapse that day. A step count does not get to
  /// overrule a person admitting they broke.
  relapseLogged,

  /// Below the binding's floor — no reading worth writing down.
  belowFloor,

  /// A human already logged this habit that day. Their number stands.
  manualEntry,

  /// An earlier import already wrote this value or a higher one.
  notHigher,
}

/// One check-in the import wants to write.
@immutable
class HealthImport {
  const HealthImport({
    required this.habit,
    required this.day,
    required this.value,
    required this.provenance,
    required this.replacesEarlierImport,
  });

  final Habit habit;
  final DayKey day;

  /// Already converted into the habit's own unit.
  final num value;

  final HealthProvenance provenance;

  /// True when this supersedes an earlier health-sourced entry for the same
  /// habit and day — the normal case while a day is still running and the
  /// step count keeps climbing.
  final bool replacesEarlierImport;
}

/// A day the import deliberately left alone.
@immutable
class HealthSkip {
  const HealthSkip({
    required this.habit,
    required this.day,
    required this.reason,
  });

  final Habit habit;
  final DayKey day;
  final HealthSkipReason reason;
}

/// What one import round would do, before anything is written.
@immutable
class HealthImportPlan {
  const HealthImportPlan({required this.imports, required this.skips});

  static const HealthImportPlan empty =
      HealthImportPlan(imports: <HealthImport>[], skips: <HealthSkip>[]);

  final List<HealthImport> imports;
  final List<HealthSkip> skips;

  bool get isEmpty => imports.isEmpty;

  int get newEntries =>
      imports.where((HealthImport i) => !i.replacesEarlierImport).length;

  int get updatedEntries =>
      imports.where((HealthImport i) => i.replacesEarlierImport).length;

  /// The days touched, for the "imported 3 days" line.
  Set<String> get days =>
      imports.map((HealthImport i) => i.day.toString()).toSet();
}

/// Decides which health readings become check-ins.
///
/// Pure, and deliberately so: this is the part that has to be right. It writes
/// nothing and reads no clock beyond [today], so every rule below is a test
/// rather than something you find out about when a user's streak breaks.
///
/// The rules, in the order they are applied per habit and day:
///
/// 1. The habit must have a binding and be switched on by the user.
/// 2. The metric must exist on this platform.
/// 3. The day must sit inside the challenge and within the backfill window.
/// 4. The habit must be scheduled that day — rest days are left empty.
/// 5. A confessed relapse wins over any sensor.
/// 6. The reading must clear the binding's floor.
/// 7. A manual entry is never overwritten.
/// 8. An earlier import is replaced only by a strictly higher value.
HealthImportPlan planHealthImport({
  required Challenge challenge,
  required Map<String, DayLog> logsByDay,
  required Map<String, DailyHealthTotals> totalsByDay,
  required Set<HabitCategory> enabledCategories,
  required HealthPlatform platform,
  required DayKey today,
  int backfillDays = kHealthBackfillDays,
}) {
  final List<HealthImport> imports = <HealthImport>[];
  final List<HealthSkip> skips = <HealthSkip>[];

  final DayKey windowStart = () {
    final DayKey earliest = today.addDays(-backfillDays);
    return earliest.isAfter(challenge.startDay) ? earliest : challenge.startDay;
  }();

  for (final Habit habit in challenge.habits) {
    final HealthBinding? binding = healthBindingFor(habit.category);
    if (binding == null) {
      skips.add(HealthSkip(
        habit: habit,
        day: today,
        reason: HealthSkipReason.noBinding,
      ));
      continue;
    }
    if (!enabledCategories.contains(habit.category)) {
      skips.add(HealthSkip(
        habit: habit,
        day: today,
        reason: HealthSkipReason.notEnabled,
      ));
      continue;
    }
    if (!healthMetricSpec(binding.metric).isSupportedOn(platform)) {
      skips.add(HealthSkip(
        habit: habit,
        day: today,
        reason: HealthSkipReason.unsupportedMetric,
      ));
      continue;
    }

    for (final MapEntry<String, DailyHealthTotals> entry
        in totalsByDay.entries) {
      final DailyHealthTotals totals = entry.value;
      final DayKey day = totals.day;

      if (day.isBefore(windowStart) || day.isAfter(today)) {
        skips.add(HealthSkip(
          habit: habit,
          day: day,
          reason: HealthSkipReason.outsideWindow,
        ));
        continue;
      }
      if (!isHabitScheduledOn(habit, day)) {
        skips.add(HealthSkip(
          habit: habit,
          day: day,
          reason: HealthSkipReason.restDay,
        ));
        continue;
      }

      final DayLog? log = logsByDay[day.toString()];
      if (log != null && log.hasRelapse) {
        skips.add(HealthSkip(
          habit: habit,
          day: day,
          reason: HealthSkipReason.relapseLogged,
        ));
        continue;
      }

      final num raw = totals.valueOf(binding.metric);
      final num value = binding.habitValueFor(raw);
      if (value <= 0) {
        skips.add(HealthSkip(
          habit: habit,
          day: day,
          reason: HealthSkipReason.belowFloor,
        ));
        continue;
      }

      final CheckIn? existing = log?.entryFor(habit.id);
      if (existing != null && !existing.isFromHealth) {
        skips.add(HealthSkip(
          habit: habit,
          day: day,
          reason: HealthSkipReason.manualEntry,
        ));
        continue;
      }
      if (existing != null && value <= existing.value) {
        skips.add(HealthSkip(
          habit: habit,
          day: day,
          reason: HealthSkipReason.notHigher,
        ));
        continue;
      }

      imports.add(HealthImport(
        habit: habit,
        day: day,
        value: value,
        provenance: HealthProvenance(
          platform: platform,
          metric: binding.metric,
          rawValue: raw,
          device: totals.devices.isEmpty ? null : totals.devices.first,
        ),
        replacesEarlierImport: existing != null,
      ));
    }
  }

  imports.sort((HealthImport a, HealthImport b) => a.day.compareTo(b.day));
  return HealthImportPlan(imports: imports, skips: skips);
}

/// The span an import round needs to read, given the same window the planner
/// applies. Keeping the two in one file is the point: a reader that fetched a
/// different range than the planner accepts would silently drop days.
({DayKey from, DayKey to}) healthReadWindow({
  required Challenge challenge,
  required DayKey today,
  int backfillDays = kHealthBackfillDays,
}) {
  final DayKey earliest = today.addDays(-backfillDays);
  return (
    from: earliest.isAfter(challenge.startDay) ? earliest : challenge.startDay,
    to: today,
  );
}
