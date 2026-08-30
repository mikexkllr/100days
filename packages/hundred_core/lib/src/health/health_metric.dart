import 'package:meta/meta.dart';

/// Which system on the phone holds the user's fitness data.
///
/// The two platforms differ in more than their API surface — they have
/// genuinely different privacy models, and the app has to be written for the
/// stricter of the two. See [HealthAuthorization].
enum HealthPlatform {
  /// Apple Health (HealthKit). An Apple Watch writes here, as does the iPhone
  /// itself for steps.
  appleHealth,

  /// Health Connect. On Android this is the only sensible target: Fitbit,
  /// Pixel Watch, Samsung Health, Garmin and Strava all write into it, and
  /// Google is retiring the old Google Fit APIs in favour of it.
  healthConnect,

  /// No provider — a desktop build, a test, or a phone where the user never
  /// installed Health Connect.
  none,
}

/// The unit a metric is measured in, before it is converted to whatever unit
/// the habit it feeds is counted in.
enum HealthUnit { count, minutes, millilitres }

/// How a metric arrives from the platform.
enum HealthSampleKind {
  /// The platform aggregates it per day and hands us one number. Steps and
  /// hydration work this way: both HealthKit's statistics queries and Health
  /// Connect's aggregation API already de-duplicate across the apps that
  /// wrote the samples, and they do it better than we could.
  dailyTotal,

  /// Arrives as a list of intervals with a start and an end — workouts, a
  /// night's sleep, a meditation session. Two apps recording the same run
  /// produce two overlapping intervals, so these have to be merged before
  /// they are counted. That is [mergeSessions]' job.
  session,
}

/// Which calendar day a session belongs to when it spans midnight.
enum DayAttribution {
  /// The day it began. A workout that starts at 23:40 on Friday was Friday's
  /// workout, whatever the clock says when it ends.
  start,

  /// The day it ended. Sleep is the case that matters: you go to bed on
  /// Monday and that is *Tuesday's* night of sleep, which is how every sleep
  /// tracker reports it and how a person thinks about it.
  end,
}

/// The quantities the app knows how to read.
///
/// Deliberately short. Every entry here is one that some habit actually
/// consumes ([kHealthBindings]), because a metric with no binding would mean
/// asking the user for a permission the app has no use for.
enum HealthMetric {
  steps,
  strengthMinutes,
  cardioMinutes,
  sleepMinutes,
  mindfulMinutes,
  water,
}

/// Everything true of a metric regardless of who is measuring it.
@immutable
class HealthMetricSpec {
  const HealthMetricSpec({
    required this.metric,
    required this.unit,
    required this.kind,
    required this.platforms,
    this.attribution = DayAttribution.start,
  });

  final HealthMetric metric;
  final HealthUnit unit;
  final HealthSampleKind kind;

  /// The platforms that can actually answer for this metric. Not every metric
  /// exists on both sides, and pretending otherwise produces a permission
  /// dialog that asks for something the platform will never return.
  final Set<HealthPlatform> platforms;

  final DayAttribution attribution;

  bool isSupportedOn(HealthPlatform platform) => platforms.contains(platform);
}

const Set<HealthPlatform> _both = <HealthPlatform>{
  HealthPlatform.appleHealth,
  HealthPlatform.healthConnect,
};

/// The catalogue. Adding a metric to the app means adding a row here, a row in
/// [kHealthBindings] and a case in each platform adapter — nothing else reads
/// the enum directly.
const Map<HealthMetric, HealthMetricSpec> kHealthMetrics =
    <HealthMetric, HealthMetricSpec>{
  HealthMetric.steps: HealthMetricSpec(
    metric: HealthMetric.steps,
    unit: HealthUnit.count,
    kind: HealthSampleKind.dailyTotal,
    platforms: _both,
  ),
  HealthMetric.strengthMinutes: HealthMetricSpec(
    metric: HealthMetric.strengthMinutes,
    unit: HealthUnit.minutes,
    kind: HealthSampleKind.session,
    platforms: _both,
  ),
  HealthMetric.cardioMinutes: HealthMetricSpec(
    metric: HealthMetric.cardioMinutes,
    unit: HealthUnit.minutes,
    kind: HealthSampleKind.session,
    platforms: _both,
  ),
  HealthMetric.sleepMinutes: HealthMetricSpec(
    metric: HealthMetric.sleepMinutes,
    unit: HealthUnit.minutes,
    kind: HealthSampleKind.session,
    platforms: _both,
    attribution: DayAttribution.end,
  ),
  HealthMetric.mindfulMinutes: HealthMetricSpec(
    metric: HealthMetric.mindfulMinutes,
    unit: HealthUnit.minutes,
    kind: HealthSampleKind.session,
    // Health Connect has no mindfulness record type, so on Android this stays
    // a manual habit. Better to say so than to ship a toggle that silently
    // never fires.
    platforms: <HealthPlatform>{HealthPlatform.appleHealth},
  ),
  HealthMetric.water: HealthMetricSpec(
    metric: HealthMetric.water,
    unit: HealthUnit.millilitres,
    kind: HealthSampleKind.dailyTotal,
    platforms: _both,
  ),
};

HealthMetricSpec healthMetricSpec(HealthMetric metric) =>
    kHealthMetrics[metric]!;

/// Parses the wire name used on the platform channel and in feed payloads.
/// Returns null for anything unknown, because a payload written by a newer
/// version of the app must not crash an older one.
HealthMetric? healthMetricByName(String name) {
  for (final HealthMetric metric in HealthMetric.values) {
    if (metric.name == name) return metric;
  }
  return null;
}
