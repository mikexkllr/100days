import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hundred_core/hundred_core.dart';

import 'app_repository.dart';
import 'health_preferences.dart';

/// What one import round did, for the settings screen and nothing else.
@immutable
class HealthImportResult {
  const HealthImportResult({
    required this.written,
    required this.updated,
    required this.days,
    required this.access,
  });

  static const HealthImportResult none = HealthImportResult(
    written: 0,
    updated: 0,
    days: 0,
    access: HealthAuthorization.unavailable,
  );

  final int written;
  final int updated;
  final int days;
  final HealthAuthorization access;

  bool get changedSomething => written > 0 || updated > 0;
}

/// Reads the phone's fitness store and turns what it finds into check-ins.
///
/// The order matters and is the whole design: read, then *plan* in the core,
/// then write. Planning is a pure function over the challenge, the existing
/// log and the readings, so every rule about what may and may not be
/// overwritten is decided somewhere it can be tested — not in the middle of
/// an async method that also talks to a database.
class HealthImportService {
  HealthImportService({
    required this.source,
    required this.preferences,
    required this.repository,
  });

  final HealthDataSource source;
  final HealthPreferences preferences;
  final AppRepository repository;

  /// Guards against two rounds overlapping — the app runs one on resume and
  /// the user can press the button at the same moment.
  Future<HealthImportResult>? _inFlight;

  HealthPlatform get platform => source.platform;

  Set<HealthMetric> metricsForEnabled() => metricsFor(
        preferences.enabledCategories(),
        platform: source.platform,
      );

  Future<bool> isAvailable() => source.isAvailable();

  Future<HealthAccess> currentAccess() =>
      source.currentAccess(metricsForEnabled());

  Future<HealthAccess> requestAccess() =>
      source.requestAccess(metricsForEnabled());

  Future<void> openSystemSettings() => source.openSystemSettings();

  /// Runs a round if the user left auto-import on. Called on app start and on
  /// resume; silent about everything, including failure.
  Future<HealthImportResult> importIfEnabled({DayKey? today}) {
    if (!preferences.autoImport()) {
      return Future<HealthImportResult>.value(HealthImportResult.none);
    }
    return importNow(today: today);
  }

  Future<HealthImportResult> importNow({DayKey? today}) {
    final Future<HealthImportResult>? running = _inFlight;
    if (running != null) return running;
    final Future<HealthImportResult> round = _run(today: today)
        .whenComplete(() => _inFlight = null);
    return _inFlight = round;
  }

  Future<HealthImportResult> _run({DayKey? today}) async {
    final Set<HabitCategory> enabled = preferences.enabledCategories();
    if (enabled.isEmpty) return HealthImportResult.none;

    final Set<HealthMetric> metrics =
        metricsFor(enabled, platform: source.platform);
    if (metrics.isEmpty) return HealthImportResult.none;

    if (!await source.isAvailable()) return HealthImportResult.none;

    final HealthAccess access = await source.currentAccess(metrics);
    if (!access.canRead) {
      return HealthImportResult(
        written: 0,
        updated: 0,
        days: 0,
        access: access.status,
      );
    }

    final DayKey day = today ?? DayKey.today();
    final AppSnapshot snapshot = await repository.snapshot(today: day);
    final Challenge? challenge = snapshot.challenge;
    if (challenge == null) {
      return HealthImportResult(
        written: 0,
        updated: 0,
        days: 0,
        access: access.status,
      );
    }

    final ({DayKey from, DayKey to}) window =
        healthReadWindow(challenge: challenge, today: day);

    final Map<String, DailyHealthTotals> totals = await source.readDailyTotals(
      from: window.from,
      to: window.to,
      metrics: metrics,
    );
    if (totals.isEmpty) {
      await preferences.setLastImportAt(DateTime.now());
      return HealthImportResult(
        written: 0,
        updated: 0,
        days: 0,
        access: access.status,
      );
    }

    final HealthImportPlan plan = planHealthImport(
      challenge: challenge,
      logsByDay: snapshot.me.logsByDay,
      totalsByDay: totals,
      enabledCategories: enabled,
      platform: source.platform,
      today: day,
    );

    for (final HealthImport entry in plan.imports) {
      try {
        await repository.checkIn(
          habit: entry.habit,
          day: entry.day,
          value: entry.value,
          streak: snapshot.me.habitStreaks[entry.habit.id],
          health: entry.provenance,
        );
      } on Object catch (error) {
        // One failed append must not abandon the rest of the round; the next
        // one will pick up whatever is still missing.
        debugPrint('Health check-in failed for ${entry.day}: $error');
      }
    }

    await preferences.setLastImportAt(DateTime.now());
    return HealthImportResult(
      written: plan.newEntries,
      updated: plan.updatedEntries,
      days: plan.days.length,
      access: access.status,
    );
  }
}
