import 'package:meta/meta.dart';

import '../domain/habit.dart';
import 'health_metric.dart';

/// Ties one habit category to the metric that can stand in for it, and says
/// how the platform's number becomes the habit's number.
@immutable
class HealthBinding {
  const HealthBinding({
    required this.category,
    required this.metric,
    required this.floor,
    this.rawPerHabitUnit = 1,
  });

  final HabitCategory category;
  final HealthMetric metric;

  /// Below this many raw units the day yields nothing at all.
  ///
  /// Not a nicety: watches label three minutes of carrying shopping as
  /// "strength training", and a gym habit that ticks itself off for that is
  /// worse than no automation, because the streak stops meaning anything.
  final num floor;

  /// How many raw units make one unit of the habit's own scale — 250 ml to a
  /// glass of water, one minute to one minute.
  final num rawPerHabitUnit;

  /// Converts a day's raw reading into the value a check-in would carry.
  ///
  /// Rounds *down*. The app never credits a minute that was not moved: if the
  /// watch says 29.6 minutes of cardio against a 30-minute target, the day is
  /// not done, and the user can still close it by hand if they disagree.
  num habitValueFor(num raw) {
    if (raw < floor) return 0;
    if (habitDefinition(category).unit == HabitUnit.done) return 1;
    return (raw / rawPerHabitUnit).floor();
  }
}

/// Every habit the app can fill in from a watch.
///
/// Abstinence habits are absent by construction and always will be. No sensor
/// can show that someone did not drink, and a habit that quietly ticks itself
/// off is the opposite of what an abstinence streak is for. The one thing the
/// user must do themselves is confess a relapse.
const List<HealthBinding> kHealthBindings = <HealthBinding>[
  HealthBinding(
    category: HabitCategory.steps,
    metric: HealthMetric.steps,
    // Any phone in a pocket racks up a few hundred steps. A target of 10 000
    // is not met by walking to the kitchen, so the floor only exists to keep
    // an untouched day from producing an event.
    floor: 500,
  ),
  HealthBinding(
    category: HabitCategory.gym,
    metric: HealthMetric.strengthMinutes,
    floor: 20,
  ),
  HealthBinding(
    category: HabitCategory.cardio,
    metric: HealthMetric.cardioMinutes,
    floor: 5,
  ),
  HealthBinding(
    category: HabitCategory.sleep,
    metric: HealthMetric.sleepMinutes,
    // A 40-minute nap is not a night's sleep, and counting it as one would
    // hand the user a streak they did not sleep for.
    floor: 120,
  ),
  HealthBinding(
    category: HabitCategory.meditation,
    metric: HealthMetric.mindfulMinutes,
    floor: 1,
  ),
  HealthBinding(
    category: HabitCategory.water,
    metric: HealthMetric.water,
    floor: 250,
    rawPerHabitUnit: 250,
  ),
];

HealthBinding? healthBindingFor(HabitCategory category) {
  for (final HealthBinding binding in kHealthBindings) {
    if (binding.category == category) return binding;
  }
  return null;
}

/// The categories that can be filled in at all — what the settings screen
/// offers, intersected with the habits the user actually picked.
Set<HabitCategory> get healthLinkableCategories => kHealthBindings
    .map((HealthBinding binding) => binding.category)
    .toSet();

/// The metrics needed to serve [categories] on [platform].
///
/// Permissions follow the habits: a user who only tracks steps is never asked
/// for their sleep, because the app has nothing to do with it.
Set<HealthMetric> metricsFor(
  Iterable<HabitCategory> categories, {
  required HealthPlatform platform,
}) =>
    categories
        .map(healthBindingFor)
        .nonNulls
        .map((HealthBinding binding) => binding.metric)
        .where((HealthMetric metric) =>
            healthMetricSpec(metric).isSupportedOn(platform))
        .toSet();
