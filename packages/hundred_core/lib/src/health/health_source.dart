import 'package:meta/meta.dart';

import '../util/dates.dart';
import 'health_metric.dart';
import 'health_sample.dart';

/// What the platform will tell us about read permission.
enum HealthAuthorization {
  /// The platform refuses to say. This is not a bug — HealthKit deliberately
  /// never reveals whether *read* access was granted, because "this app was
  /// denied access to blood glucose" would itself leak that the user has
  /// something to hide. On iOS the honest answer is almost always this one:
  /// ask, then read, and treat an empty result as "nothing to import".
  unknown,
  granted,
  denied,

  /// No provider on this device — Health Connect not installed, or a platform
  /// that has no health store at all.
  unavailable,
}

/// The result of asking for access.
@immutable
class HealthAccess {
  const HealthAccess({required this.status, this.granted = const <HealthMetric>{}});

  static const HealthAccess unavailable =
      HealthAccess(status: HealthAuthorization.unavailable);

  final HealthAuthorization status;

  /// The metrics the platform confirmed. Empty on iOS even when everything was
  /// granted — see [HealthAuthorization.unknown].
  final Set<HealthMetric> granted;

  /// Whether it is worth attempting a read. On iOS this is true even for
  /// [HealthAuthorization.unknown]: a read is the only way to find out.
  bool get canRead =>
      status == HealthAuthorization.granted ||
      status == HealthAuthorization.unknown;
}

/// Port for the phone's fitness store.
///
/// Everything behind this interface is platform code — HealthKit on iOS,
/// Health Connect on Android. Nothing behind it is allowed to reach the
/// network: fitness data is read on the device, converted on the device and
/// written into the user's own signed feed. The only way it ever leaves the
/// phone is the same way a manual check-in does, to the friends the user
/// added themselves.
abstract class HealthDataSource {
  HealthPlatform get platform;

  /// Whether a provider exists *and* is usable. False on an Android phone
  /// where Health Connect was never installed, which is a normal state and
  /// not an error.
  Future<bool> isAvailable();

  /// The metrics this platform can answer for at all.
  Set<HealthMetric> get supportedMetrics => kHealthMetrics.values
      .where((HealthMetricSpec spec) => spec.isSupportedOn(platform))
      .map((HealthMetricSpec spec) => spec.metric)
      .toSet();

  Future<HealthAccess> currentAccess(Set<HealthMetric> metrics);

  /// Shows the platform's own permission sheet. Only ever called for metrics
  /// the user actually enabled a habit for — asking for a scope the app has
  /// no use for is how permission dialogs get denied.
  Future<HealthAccess> requestAccess(Set<HealthMetric> metrics);

  /// Reads [from]..[to] inclusive, already folded into per-day totals.
  Future<Map<String, DailyHealthTotals>> readDailyTotals({
    required DayKey from,
    required DayKey to,
    required Set<HealthMetric> metrics,
  });

  /// Opens the system screen where the user can revoke what they granted.
  /// The app never pretends to own that decision.
  Future<void> openSystemSettings();
}

/// Stand-in for every platform without a health store: desktop, web, tests.
/// Everything answers "nothing here" rather than throwing, so the settings
/// screen can render a plain explanation instead of an error.
class UnavailableHealthSource implements HealthDataSource {
  const UnavailableHealthSource();

  @override
  HealthPlatform get platform => HealthPlatform.none;

  @override
  Set<HealthMetric> get supportedMetrics => const <HealthMetric>{};

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<HealthAccess> currentAccess(Set<HealthMetric> metrics) async =>
      HealthAccess.unavailable;

  @override
  Future<HealthAccess> requestAccess(Set<HealthMetric> metrics) async =>
      HealthAccess.unavailable;

  @override
  Future<Map<String, DailyHealthTotals>> readDailyTotals({
    required DayKey from,
    required DayKey to,
    required Set<HealthMetric> metrics,
  }) async =>
      const <String, DailyHealthTotals>{};

  @override
  Future<void> openSystemSettings() async {}
}
