import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/health_gateway.dart';
import 'package:hundred_days/data/health_import_service.dart';
import 'package:hundred_days/data/health_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Stands in for the platform, so the whole chain — channel decoding, folding,
/// planning, appending signed events — runs without a phone.
class _FakeHealthSource implements HealthDataSource {
  _FakeHealthSource({
    required this.platform,
    this.totals = const <String, DailyHealthTotals>{},
    this.access = const HealthAccess(status: HealthAuthorization.granted),
  });

  @override
  final HealthPlatform platform;

  Map<String, DailyHealthTotals> totals;
  HealthAccess access;

  int reads = 0;
  Set<HealthMetric>? lastRequested;

  @override
  Set<HealthMetric> get supportedMetrics => kHealthMetrics.values
      .where((HealthMetricSpec spec) => spec.isSupportedOn(platform))
      .map((HealthMetricSpec spec) => spec.metric)
      .toSet();

  @override
  Future<bool> isAvailable() async => platform != HealthPlatform.none;

  @override
  Future<HealthAccess> currentAccess(Set<HealthMetric> metrics) async => access;

  @override
  Future<HealthAccess> requestAccess(Set<HealthMetric> metrics) async {
    lastRequested = metrics;
    return access;
  }

  @override
  Future<Map<String, DailyHealthTotals>> readDailyTotals({
    required DayKey from,
    required DayKey to,
    required Set<HealthMetric> metrics,
  }) async {
    reads++;
    lastRequested = metrics;
    return totals;
  }

  @override
  Future<void> openSystemSettings() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DayKey today;

  setUp(() {
    today = DayKey.today();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<HealthImportService> service(
    _FakeHealthSource source,
    AppRepository repository, {
    Set<HabitCategory> enabled = const <HabitCategory>{HabitCategory.steps},
  }) async {
    final HealthPreferences preferences = await HealthPreferences.open();
    await preferences.setEnabledCategories(enabled);
    return HealthImportService(
      source: source,
      preferences: preferences,
      repository: repository,
    );
  }

  Map<String, DailyHealthTotals> totalsFor(
    DayKey day,
    Map<HealthMetric, num> values, {
    Set<String> devices = const <String>{},
  }) =>
      <String, DailyHealthTotals>{
        day.toString():
            DailyHealthTotals(day: day, values: values, devices: devices),
      };

  group('preferences', () {
    test('nothing is enabled until the user picks something', () async {
      final HealthPreferences preferences = await HealthPreferences.open();
      expect(preferences.enabledCategories(), isEmpty);
    });

    test('keeps only categories a sensor could actually serve', () async {
      final HealthPreferences preferences = await HealthPreferences.open();
      await preferences.setEnabledCategories(<HabitCategory>{
        HabitCategory.steps,
        HabitCategory.noSugar,
      });
      expect(
        preferences.enabledCategories(),
        <HabitCategory>{HabitCategory.steps},
      );
    });
  });

  group('import service', () {
    test('writes a signed check-in that carries its provenance', () async {
      final AppRepository repository = await testRepository();
      await repository.startChallenge(testChallenge(
        habits: <HabitCategory>[HabitCategory.steps],
        startDay: today.addDays(-2),
      ));

      final _FakeHealthSource source = _FakeHealthSource(
        platform: HealthPlatform.healthConnect,
        totals: totalsFor(
          today,
          <HealthMetric, num>{HealthMetric.steps: 11500},
          devices: <String>{'Pixel Watch'},
        ),
      );
      final HealthImportResult result =
          await (await service(source, repository)).importNow(today: today);

      expect(result.written, 1);
      expect(result.days, 1);

      final AppSnapshot snapshot = await repository.snapshot(today: today);
      final CheckIn entry =
          snapshot.me.logsByDay[today.toString()]!.entries.single;
      expect(entry.value, 11500);
      expect(entry.isFromHealth, isTrue);
      expect(entry.health!.platform, HealthPlatform.healthConnect);
      expect(entry.health!.device, 'Pixel Watch');
    });

    test('a second round with the same reading writes nothing', () async {
      final AppRepository repository = await testRepository();
      await repository.startChallenge(testChallenge(
        habits: <HabitCategory>[HabitCategory.steps],
        startDay: today.addDays(-2),
      ));

      final _FakeHealthSource source = _FakeHealthSource(
        platform: HealthPlatform.healthConnect,
        totals: totalsFor(today, <HealthMetric, num>{HealthMetric.steps: 9000}),
      );
      final HealthImportService importer = await service(source, repository);

      expect((await importer.importNow(today: today)).written, 1);
      final HealthImportResult second = await importer.importNow(today: today);
      expect(second.written, 0);
      expect(second.updated, 0);

      final AppSnapshot snapshot = await repository.snapshot(today: today);
      expect(snapshot.me.logsByDay[today.toString()]!.entries, hasLength(1));
    });

    test('a grown step count replaces the earlier entry', () async {
      final AppRepository repository = await testRepository();
      await repository.startChallenge(testChallenge(
        habits: <HabitCategory>[HabitCategory.steps],
        startDay: today.addDays(-2),
      ));

      final _FakeHealthSource source = _FakeHealthSource(
        platform: HealthPlatform.healthConnect,
        totals: totalsFor(today, <HealthMetric, num>{HealthMetric.steps: 4000}),
      );
      final HealthImportService importer = await service(source, repository);
      await importer.importNow(today: today);

      source.totals =
          totalsFor(today, <HealthMetric, num>{HealthMetric.steps: 12000});
      final HealthImportResult second = await importer.importNow(today: today);
      expect(second.updated, 1);

      final AppSnapshot snapshot = await repository.snapshot(today: today);
      // Re-logging the same habit and day collapses at projection time, so the
      // user sees one entry rather than a contradiction.
      final DayLog log = snapshot.me.logsByDay[today.toString()]!;
      expect(log.entries, hasLength(1));
      expect(log.entries.single.value, 12000);
    });

    test('asks only for the metrics the enabled habits need', () async {
      final AppRepository repository = await testRepository();
      await repository.startChallenge(testChallenge(
        habits: <HabitCategory>[HabitCategory.steps, HabitCategory.sleep],
        startDay: today.addDays(-2),
      ));

      final _FakeHealthSource source =
          _FakeHealthSource(platform: HealthPlatform.healthConnect);
      await (await service(source, repository)).importNow(today: today);

      expect(source.lastRequested, <HealthMetric>{HealthMetric.steps});
    });

    test('does not read at all before a challenge exists', () async {
      final AppRepository repository = await testRepository();
      final _FakeHealthSource source = _FakeHealthSource(
        platform: HealthPlatform.healthConnect,
        totals: totalsFor(today, <HealthMetric, num>{HealthMetric.steps: 9000}),
      );
      final HealthImportResult result =
          await (await service(source, repository)).importNow(today: today);

      expect(result.written, 0);
      expect(source.reads, 0);
    });

    test('does nothing with no habit switched on', () async {
      final AppRepository repository = await testRepository();
      await repository.startChallenge(testChallenge(
        habits: <HabitCategory>[HabitCategory.steps],
      ));

      final _FakeHealthSource source = _FakeHealthSource(
        platform: HealthPlatform.healthConnect,
        totals: totalsFor(today, <HealthMetric, num>{HealthMetric.steps: 9000}),
      );
      final HealthImportResult result = await (await service(
        source,
        repository,
        enabled: const <HabitCategory>{},
      ))
          .importNow(today: today);

      expect(result.written, 0);
      expect(source.reads, 0);
    });

    test('stops at a refused permission without touching the feed', () async {
      final AppRepository repository = await testRepository();
      await repository.startChallenge(testChallenge(
        habits: <HabitCategory>[HabitCategory.steps],
      ));

      final _FakeHealthSource source = _FakeHealthSource(
        platform: HealthPlatform.healthConnect,
        access: const HealthAccess(status: HealthAuthorization.denied),
        totals: totalsFor(today, <HealthMetric, num>{HealthMetric.steps: 9000}),
      );
      final HealthImportResult result =
          await (await service(source, repository)).importNow(today: today);

      expect(result.access, HealthAuthorization.denied);
      expect(source.reads, 0);
      final AppSnapshot snapshot = await repository.snapshot(today: today);
      expect(snapshot.me.logsByDay, isEmpty);
    });

    test('reads anyway when the platform will not say (iOS)', () async {
      final AppRepository repository = await testRepository();
      await repository.startChallenge(testChallenge(
        habits: <HabitCategory>[HabitCategory.steps],
      ));

      final _FakeHealthSource source = _FakeHealthSource(
        platform: HealthPlatform.appleHealth,
        access: const HealthAccess(status: HealthAuthorization.unknown),
        totals: totalsFor(today, <HealthMetric, num>{HealthMetric.steps: 9000}),
      );
      await (await service(source, repository)).importNow(today: today);

      expect(source.reads, 1);
    });

    test('two overlapping rounds only run once', () async {
      final AppRepository repository = await testRepository();
      await repository.startChallenge(testChallenge(
        habits: <HabitCategory>[HabitCategory.steps],
      ));

      final _FakeHealthSource source = _FakeHealthSource(
        platform: HealthPlatform.healthConnect,
        totals: totalsFor(today, <HealthMetric, num>{HealthMetric.steps: 9000}),
      );
      final HealthImportService importer = await service(source, repository);
      await Future.wait<HealthImportResult>(<Future<HealthImportResult>>[
        importer.importNow(today: today),
        importer.importNow(today: today),
      ]);

      expect(source.reads, 1);
    });
  });

  group('platform channel', () {
    late List<MethodCall> calls;
    late PlatformHealthSource source;

    setUp(() {
      calls = <MethodCall>[];
      const MethodChannel channel = MethodChannel(
        PlatformHealthSource.channelName,
      );
      source = PlatformHealthSource(
        channel: channel,
        platform: HealthPlatform.healthConnect,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        calls.add(call);
        switch (call.method) {
          case 'available':
            return true;
          case 'read':
            return <String, Object?>{
              'daily': <Object?>[
                <String, Object?>{
                  'metric': 'steps',
                  'day': '2026-03-02',
                  'value': 9120,
                  'device': 'Pixel Watch',
                },
                // A row the platform could not label: skipped, not fatal.
                <String, Object?>{'metric': 'floors', 'value': 3},
              ],
              'sessions': <Object?>[
                <String, Object?>{
                  'metric': 'cardioMinutes',
                  'start':
                      DateTime(2026, 3, 2, 7).millisecondsSinceEpoch,
                  'end': DateTime(2026, 3, 2, 8).millisecondsSinceEpoch,
                  'device': 'Pixel Watch',
                },
                <String, Object?>{
                  'metric': 'cardioMinutes',
                  'start':
                      DateTime(2026, 3, 2, 7, 10).millisecondsSinceEpoch,
                  'end':
                      DateTime(2026, 3, 2, 7, 50).millisecondsSinceEpoch,
                  'device': 'Strava',
                },
              ],
            };
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(PlatformHealthSource.channelName),
        null,
      );
    });

    test('folds a platform response into per-day totals', () async {
      final Map<String, DailyHealthTotals> totals =
          await source.readDailyTotals(
        from: const DayKey(2026, 3, 2),
        to: const DayKey(2026, 3, 2),
        metrics: <HealthMetric>{
          HealthMetric.steps,
          HealthMetric.cardioMinutes,
        },
      );

      final DailyHealthTotals day = totals['2026-03-02']!;
      expect(day.valueOf(HealthMetric.steps), 9120);
      // The two overlapping cardio rows are one hour of running, not 100
      // minutes of it.
      expect(day.valueOf(HealthMetric.cardioMinutes), 60);
      expect(day.devices, contains('Pixel Watch'));
    });

    test('survives a platform that has no implementation at all', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(PlatformHealthSource.channelName),
        null,
      );
      expect(
        await source.readDailyTotals(
          from: const DayKey(2026, 3, 2),
          to: const DayKey(2026, 3, 2),
          metrics: <HealthMetric>{HealthMetric.steps},
        ),
        isEmpty,
      );
    });

    test('never asks the platform for a metric it cannot answer', () async {
      await source.readDailyTotals(
        from: const DayKey(2026, 3, 2),
        to: const DayKey(2026, 3, 2),
        metrics: <HealthMetric>{HealthMetric.mindfulMinutes},
      );
      // Health Connect has no mindfulness record type, so the call is
      // skipped rather than sent and ignored.
      expect(calls.where((MethodCall c) => c.method == 'read'), isEmpty);
    });
  });
}
