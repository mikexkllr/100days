import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'coach_l10n.dart';
export 'core_l10n.dart';
export 'exercise_l10n.dart';
export 'generated/app_localizations.dart';
export 'plan_l10n.dart';
export 'social_l10n.dart';

/// One import for every screen: `context.l10n.homeCheckOffToday`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
