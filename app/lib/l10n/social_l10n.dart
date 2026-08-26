import 'package:hundred_core/hundred_core.dart';

import 'core_l10n.dart';
import 'generated/app_localizations.dart';

/// Wording for the feed and for peer state.
extension SocialL10n on AppLocalizations {
  String activityHeadline(ActivityItem item) {
    switch (item.kind) {
      case ActivityKind.checkIn:
        return feedCheckIn(
          item.authorName,
          habitTitle(item.category ?? HabitCategory.custom),
        );
      case ActivityKind.relapse:
        return feedRelapse(
          item.authorName,
          habitTitle(item.category ?? HabitCategory.custom),
        );
      case ActivityKind.start:
        return feedStarted(item.authorName);
      case ActivityKind.ascend:
      case ActivityKind.milestone:
        return feedAscended(item.authorName);
      case ActivityKind.nudge:
        return item.isOwn
            ? feedNudgeSent(item.targetName ?? feedSomeone)
            : feedNudgeReceived(item.authorName);
      case ActivityKind.cheer:
        return item.isOwn
            ? feedCheerSent(item.targetName ?? feedSomeone)
            : feedCheerReceived(item.authorName);
    }
  }

  /// The second line, or null when there is nothing worth adding.
  String? activityDetail(ActivityItem item) {
    switch (item.kind) {
      case ActivityKind.checkIn:
      case ActivityKind.relapse:
        final parts = <String>[
          if (item.streakAtTime != null && item.streakAtTime! > 1)
            feedStreakDetail(item.streakAtTime!),
          if (item.note != null && item.note!.isNotEmpty) item.note!,
          if (!item.isVerifiedLive && item.claimedDay != null)
            feedBackfilled(item.claimedDay.toString()),
        ];
        return parts.isEmpty ? null : parts.join(' · ');
      case ActivityKind.start:
        return item.statement;
      case ActivityKind.ascend:
      case ActivityKind.milestone:
        return item.tierIndex == null
            ? null
            : feedAscendedDetail(tierName(tierForCycle(item.tierIndex!)));
      case ActivityKind.nudge:
      case ActivityKind.cheer:
        return item.message;
    }
  }

  String peerActivityLabel(PeerActivity activity) {
    switch (activity.kind) {
      case PeerActivityKind.none:
        return peerActivityNone;
      case PeerActivityKind.challengeStarted:
        return peerActivityStarted;
      case PeerActivityKind.ascended:
        return peerActivityAscended;
      case PeerActivityKind.checkIn:
        final HabitCategory category = activity.category ?? HabitCategory.custom;
        return peerActivityCheckIn(
          habitDefinition(category).emoji,
          habitTitle(category),
        );
      case PeerActivityKind.relapse:
        return peerActivityRelapse;
      case PeerActivityKind.streakFreeze:
        return peerActivityFreeze;
      case PeerActivityKind.missed:
        return peerActivityMissed;
    }
  }
}
