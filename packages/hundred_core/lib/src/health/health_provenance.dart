import 'package:meta/meta.dart';

import 'health_metric.dart';

/// Where a check-in came from.
///
/// This is a *claim about provenance, not a proof*. The feed proves that the
/// entry is yours, was written when it says, and has not been altered since —
/// it cannot prove a watch was involved, because nothing Apple or Google hands
/// an app is signed in a way a friend's phone could verify. Someone determined
/// to fake a streak can still write steps into Health by hand.
///
/// The app is honest about that distinction and so is the UI: an imported
/// entry is labelled "from Health", never "verified".
@immutable
class HealthProvenance {
  const HealthProvenance({
    required this.platform,
    required this.metric,
    required this.rawValue,
    this.device,
  });

  /// Returns null when [payload] has no health block — which is what every
  /// manually tapped check-in, and every event written before this feature
  /// existed, looks like.
  static HealthProvenance? fromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    final String? platformName = payload['platform'] as String?;
    final String? metricName = payload['metric'] as String?;
    if (platformName == null || metricName == null) return null;
    final HealthMetric? metric = healthMetricByName(metricName);
    if (metric == null) return null;
    final HealthPlatform platform = HealthPlatform.values
        .where((HealthPlatform p) => p.name == platformName)
        .firstOrNull ??
        HealthPlatform.none;
    return HealthProvenance(
      platform: platform,
      metric: metric,
      rawValue: (payload['raw'] as num?) ?? 0,
      device: payload['device'] as String?,
    );
  }

  final HealthPlatform platform;
  final HealthMetric metric;

  /// The number as the platform reported it, before conversion into the
  /// habit's own unit — 2400 millilitres behind a target of "8 glasses".
  /// Kept so the app can show what it actually read rather than only what it
  /// derived, and so a changed conversion never silently rewrites history.
  final num rawValue;

  /// The app or device that wrote the data, when the platform names one
  /// ("Pixel Watch", "Apple Watch", "Strava").
  final String? device;

  Map<String, dynamic> toPayload() => <String, dynamic>{
        'platform': platform.name,
        'metric': metric.name,
        'raw': rawValue,
        if (device != null) 'device': device,
      };

  @override
  bool operator ==(Object other) =>
      other is HealthProvenance &&
      other.platform == platform &&
      other.metric == metric &&
      other.rawValue == rawValue &&
      other.device == device;

  @override
  int get hashCode => Object.hash(platform, metric, rawValue, device);
}
