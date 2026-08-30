import 'package:hundred_core/hundred_core.dart';

import 'generated/app_localizations.dart';

/// Wording for the health identifiers the core hands over.
///
/// Same rule as [CoreL10n]: the core names a metric, the app decides what a
/// person reads. That is what keeps "cardio sessions" translatable without a
/// German string ever reaching the import logic.
extension HealthL10n on AppLocalizations {
  String healthMetricName(HealthMetric metric) {
    switch (metric) {
      case HealthMetric.steps:
        return healthMetricSteps;
      case HealthMetric.strengthMinutes:
        return healthMetricStrength;
      case HealthMetric.cardioMinutes:
        return healthMetricCardio;
      case HealthMetric.sleepMinutes:
        return healthMetricSleep;
      case HealthMetric.mindfulMinutes:
        return healthMetricMindful;
      case HealthMetric.water:
        return healthMetricWater;
    }
  }

  /// The provider's own product name, which is not translated — a German user
  /// looking for "Health Connect" on their phone finds "Health Connect".
  String healthPlatformName(HealthPlatform platform) {
    switch (platform) {
      case HealthPlatform.appleHealth:
        return healthBadgeApple;
      case HealthPlatform.healthConnect:
        return healthBadgeConnect;
      case HealthPlatform.none:
        return healthBadge;
    }
  }

  String healthIntro(HealthPlatform platform) {
    switch (platform) {
      case HealthPlatform.appleHealth:
        return healthIntroApple;
      case HealthPlatform.healthConnect:
        return healthIntroConnect;
      case HealthPlatform.none:
        return healthIntroNone;
    }
  }
}
