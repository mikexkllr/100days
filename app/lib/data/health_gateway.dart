import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hundred_core/hundred_core.dart';

/// Talks to Apple Health and Health Connect over a single method channel.
///
/// The native halves deliberately do as little as possible: they hand back
/// per-day totals for the metrics the platform already aggregates, and raw
/// intervals for everything session-shaped. Merging overlapping workouts,
/// attributing a night's sleep to the right calendar day and deciding what
/// becomes a check-in all happen in `hundred_core`, where they are testable
/// without a watch, a phone or a permission dialog.
class PlatformHealthSource implements HealthDataSource {
  PlatformHealthSource({MethodChannel? channel, HealthPlatform? platform})
      : _channel = channel ?? const MethodChannel(channelName),
        platform = platform ?? detectPlatform();

  static const String channelName = 'hundred_days/health';

  final MethodChannel _channel;

  @override
  final HealthPlatform platform;

  /// Which store this build can talk to. Overridable through the constructor
  /// so the decoding above can be tested on a machine that has neither.
  static HealthPlatform detectPlatform() {
    if (kIsWeb) return HealthPlatform.none;
    if (Platform.isIOS) return HealthPlatform.appleHealth;
    if (Platform.isAndroid) return HealthPlatform.healthConnect;
    return HealthPlatform.none;
  }

  @override
  Set<HealthMetric> get supportedMetrics => kHealthMetrics.values
      .where((HealthMetricSpec spec) => spec.isSupportedOn(platform))
      .map((HealthMetricSpec spec) => spec.metric)
      .toSet();

  @override
  Future<bool> isAvailable() async {
    if (platform == HealthPlatform.none) return false;
    try {
      return await _channel.invokeMethod<bool>('available') ?? false;
    } on PlatformException catch (error) {
      debugPrint('Health provider unavailable: ${error.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<HealthAccess> currentAccess(Set<HealthMetric> metrics) =>
      _access('access', metrics);

  @override
  Future<HealthAccess> requestAccess(Set<HealthMetric> metrics) =>
      _access('request', metrics);

  Future<HealthAccess> _access(String method, Set<HealthMetric> metrics) async {
    if (platform == HealthPlatform.none || metrics.isEmpty) {
      return HealthAccess.unavailable;
    }
    try {
      final Map<Object?, Object?>? result =
          await _channel.invokeMethod<Map<Object?, Object?>>(
        method,
        <String, Object?>{'metrics': _names(metrics)},
      );
      if (result == null) return HealthAccess.unavailable;
      return HealthAccess(
        status: _statusByName(result['status'] as String?),
        granted: _metrics(result['granted']),
      );
    } on PlatformException catch (error) {
      debugPrint('Health access failed: ${error.message}');
      return HealthAccess.unavailable;
    } on MissingPluginException {
      return HealthAccess.unavailable;
    }
  }

  @override
  Future<Map<String, DailyHealthTotals>> readDailyTotals({
    required DayKey from,
    required DayKey to,
    required Set<HealthMetric> metrics,
  }) async {
    final Set<HealthMetric> wanted =
        metrics.intersection(supportedMetrics);
    if (wanted.isEmpty) return const <String, DailyHealthTotals>{};

    try {
      final Map<Object?, Object?>? result =
          await _channel.invokeMethod<Map<Object?, Object?>>(
        'read',
        <String, Object?>{
          'from': from.toString(),
          'to': to.toString(),
          'metrics': _names(wanted),
        },
      );
      if (result == null) return const <String, DailyHealthTotals>{};

      return foldHealthData(
        dailyValues: _dailyValues(result['daily']),
        sessions: _sessions(result['sessions']),
      );
    } on PlatformException catch (error) {
      // A revoked permission surfaces here rather than at request time, which
      // is normal on iOS: reading is the only way to discover a denial.
      debugPrint('Health read failed: ${error.message}');
      return const <String, DailyHealthTotals>{};
    } on MissingPluginException {
      return const <String, DailyHealthTotals>{};
    }
  }

  @override
  Future<void> openSystemSettings() async {
    try {
      await _channel.invokeMethod<void>('openSettings');
    } on PlatformException catch (error) {
      debugPrint('Could not open health settings: ${error.message}');
    } on MissingPluginException {
      // Nothing to open on a platform with no health store.
    }
  }

  static List<String> _names(Set<HealthMetric> metrics) =>
      metrics.map((HealthMetric m) => m.name).toList(growable: false);

  static HealthAuthorization _statusByName(String? name) {
    switch (name) {
      case 'granted':
        return HealthAuthorization.granted;
      case 'denied':
        return HealthAuthorization.denied;
      case 'unknown':
        return HealthAuthorization.unknown;
      default:
        return HealthAuthorization.unavailable;
    }
  }

  static Set<HealthMetric> _metrics(Object? raw) {
    if (raw is! List) return const <HealthMetric>{};
    return raw
        .whereType<String>()
        .map(healthMetricByName)
        .nonNulls
        .toSet();
  }

  /// Rows the native side could not produce are skipped rather than throwing:
  /// one unreadable metric must not cost the user the other five.
  static List<DailyHealthValue> _dailyValues(Object? raw) {
    if (raw is! List) return const <DailyHealthValue>[];
    final List<DailyHealthValue> values = <DailyHealthValue>[];
    for (final Object? row in raw) {
      if (row is! Map) continue;
      final HealthMetric? metric =
          healthMetricByName(row['metric'] as String? ?? '');
      final String? day = row['day'] as String?;
      final num? value = row['value'] as num?;
      if (metric == null || day == null || value == null) continue;
      try {
        values.add(DailyHealthValue(
          metric: metric,
          day: DayKey.parse(day),
          value: value,
          device: row['device'] as String?,
        ));
      } on FormatException {
        continue;
      }
    }
    return values;
  }

  static List<HealthSession> _sessions(Object? raw) {
    if (raw is! List) return const <HealthSession>[];
    final List<HealthSession> sessions = <HealthSession>[];
    for (final Object? row in raw) {
      if (row is! Map) continue;
      final HealthMetric? metric =
          healthMetricByName(row['metric'] as String? ?? '');
      final num? start = row['start'] as num?;
      final num? end = row['end'] as num?;
      if (metric == null || start == null || end == null) continue;
      sessions.add(HealthSession(
        metric: metric,
        start: DateTime.fromMillisecondsSinceEpoch(start.toInt()),
        end: DateTime.fromMillisecondsSinceEpoch(end.toInt()),
        device: row['device'] as String?,
      ));
    }
    return sessions;
  }
}
