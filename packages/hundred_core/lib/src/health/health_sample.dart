import 'package:meta/meta.dart';

import '../util/dates.dart';
import 'health_metric.dart';

/// A number the platform already aggregated for one calendar day.
@immutable
class DailyHealthValue {
  const DailyHealthValue({
    required this.metric,
    required this.day,
    required this.value,
    this.device,
  });

  final HealthMetric metric;
  final DayKey day;
  final num value;
  final String? device;
}

/// A bounded activity: a workout, a night's sleep, a meditation session.
@immutable
class HealthSession {
  const HealthSession({
    required this.metric,
    required this.start,
    required this.end,
    this.device,
  });

  final HealthMetric metric;
  final DateTime start;
  final DateTime end;
  final String? device;

  Duration get duration =>
      end.isAfter(start) ? end.difference(start) : Duration.zero;
}

/// Everything read for one calendar day.
@immutable
class DailyHealthTotals {
  const DailyHealthTotals({
    required this.day,
    required this.values,
    this.devices = const <String>{},
  });

  final DayKey day;
  final Map<HealthMetric, num> values;

  /// Which apps or watches contributed, for the "where did this come from?"
  /// line in the UI.
  final Set<String> devices;

  num valueOf(HealthMetric metric) => values[metric] ?? 0;

  bool get isEmpty => values.values.every((num v) => v <= 0);
}

/// Merges overlapping and touching intervals into the smallest set that covers
/// the same time.
///
/// This is the whole reason sessions are not simply summed. An Apple Watch
/// records a run and Strava records the same run: two sessions, one hour of
/// actual effort. Summing gives two hours and a cardio habit that hits its
/// target on a day the user went for a jog. Merging first gives one hour.
///
/// Intervals that merely touch (one ends exactly when the next begins) are
/// joined too — a watch that splits a session at midnight or on a pause should
/// not produce a gap.
List<({DateTime start, DateTime end})> mergeSessions(
  List<HealthSession> sessions,
) {
  final List<HealthSession> ordered = sessions
      .where((HealthSession s) => s.end.isAfter(s.start))
      .toList()
    ..sort((HealthSession a, HealthSession b) => a.start.compareTo(b.start));
  final List<({DateTime start, DateTime end})> merged =
      <({DateTime start, DateTime end})>[];

  for (final HealthSession session in ordered) {
    if (merged.isEmpty || session.start.isAfter(merged.last.end)) {
      merged.add((start: session.start, end: session.end));
      continue;
    }
    if (session.end.isAfter(merged.last.end)) {
      merged[merged.length - 1] =
          (start: merged.last.start, end: session.end);
    }
  }
  return merged;
}

/// Folds one read of the platform into per-day totals, keyed by `DayKey`.
///
/// Daily values are taken as the platform reported them; sessions are merged
/// per metric first, then attributed to a calendar day according to the
/// metric's [DayAttribution] — a workout counts on the day it started, a
/// night's sleep on the morning you woke up.
Map<String, DailyHealthTotals> foldHealthData({
  List<DailyHealthValue> dailyValues = const <DailyHealthValue>[],
  List<HealthSession> sessions = const <HealthSession>[],
}) {
  final Map<String, Map<HealthMetric, num>> values =
      <String, Map<HealthMetric, num>>{};
  final Map<String, Set<String>> devices = <String, Set<String>>{};

  void add(DayKey day, HealthMetric metric, num amount, String? device) {
    if (amount <= 0) return;
    final String key = day.toString();
    final Map<HealthMetric, num> bucket =
        values.putIfAbsent(key, () => <HealthMetric, num>{});
    bucket[metric] = (bucket[metric] ?? 0) + amount;
    if (device != null && device.isNotEmpty) {
      devices.putIfAbsent(key, () => <String>{}).add(device);
    }
  }

  for (final DailyHealthValue value in dailyValues) {
    add(value.day, value.metric, value.value, value.device);
  }

  // Group by metric so a run and a lifting session never merge into each
  // other just because they overlap in time.
  final Map<HealthMetric, List<HealthSession>> byMetric =
      <HealthMetric, List<HealthSession>>{};
  for (final HealthSession session in sessions) {
    byMetric.putIfAbsent(session.metric, () => <HealthSession>[]).add(session);
  }

  byMetric.forEach((HealthMetric metric, List<HealthSession> group) {
    final DayAttribution attribution = healthMetricSpec(metric).attribution;
    for (final ({DateTime start, DateTime end}) span in mergeSessions(group)) {
      final DayKey day = DayKey.fromDateTime(
        attribution == DayAttribution.end ? span.end : span.start,
      );
      add(day, metric, span.end.difference(span.start).inMinutes, null);
    }
    // Device names survive the merge even though the merged spans no longer
    // carry one: the user wants to know a watch was involved, not which
    // minute came from which app.
    for (final HealthSession session in group) {
      final String? device = session.device;
      if (device == null || device.isEmpty) continue;
      if (!session.end.isAfter(session.start)) continue;
      final DayKey day = DayKey.fromDateTime(
        attribution == DayAttribution.end ? session.end : session.start,
      );
      devices.putIfAbsent(day.toString(), () => <String>{}).add(device);
    }
  });

  return <String, DailyHealthTotals>{
    for (final MapEntry<String, Map<HealthMetric, num>> entry in values.entries)
      entry.key: DailyHealthTotals(
        day: DayKey.parse(entry.key),
        values: entry.value,
        devices: devices[entry.key] ?? const <String>{},
      ),
  };
}
