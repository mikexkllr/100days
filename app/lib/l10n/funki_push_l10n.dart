import 'package:hundred_core/hundred_core.dart';

import 'generated/app_localizations.dart';

/// Funki's notifications in words: the rules pick the sentence
/// ([funkiReminders], [funkiLastCalls]), the app owns the wording.
extension FunkiPushL10n on AppLocalizations {
  String funkiPushText(FunkiPush push) => switch (push.template) {
        FunkiPushTemplate.feedMe => pushFeedMe(push.streak),
        FunkiPushTemplate.hungry => pushHungry(push.dayNumber, push.totalDays),
        FunkiPushTemplate.yesterdayToo => pushYesterdayToo(push.streak),
        FunkiPushTemplate.twoMinutes => pushTwoMinutes,
        FunkiPushTemplate.milestone => pushMilestone(push.dayNumber),
        FunkiPushTemplate.firstSpark => pushFirstSpark,
        FunkiPushTemplate.startSmall => pushStartSmall,
        FunkiPushTemplate.flameOut => pushFlameOut(push.lostStreak),
        FunkiPushTemplate.inTheDark => pushInTheDark,
        FunkiPushTemplate.dayOneAgain => pushDayOneAgain,
        FunkiPushTemplate.goodbye => pushGoodbye,
        FunkiPushTemplate.lastCallFlicker => pushLastCallFlicker(push.streak),
        FunkiPushTemplate.lastCallMath => pushLastCallMath(push.streak),
        FunkiPushTemplate.lastCallSmallest => pushLastCallSmallest(push.streak),
      };
}
