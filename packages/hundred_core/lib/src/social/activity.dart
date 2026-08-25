import '../domain/check_in.dart';
import '../domain/habit.dart';
import '../domain/peer.dart';
import '../feed/event.dart';
import '../util/dates.dart';

/// One row in the social timeline.
class ActivityItem {
  const ActivityItem({
    required this.eventHash,
    required this.author,
    required this.authorName,
    required this.authorEmoji,
    required this.timestamp,
    required this.headline,
    required this.detail,
    required this.emoji,
    required this.kind,
    required this.isVerifiedLive,
    this.isOwn = false,
    this.streakAtTime,
  });

  final String eventHash;
  final String author;
  final String authorName;
  final String authorEmoji;
  final DateTime timestamp;
  final String headline;
  final String? detail;
  final String emoji;
  final ActivityKind kind;

  /// The event was published on the day it claims, so it is a live proof
  /// rather than a backfill. Shown as a small badge — this is the feature that
  /// makes the leaderboard mean anything.
  final bool isVerifiedLive;

  final bool isOwn;
  final int? streakAtTime;
}

enum ActivityKind { checkIn, relapse, milestone, start, ascend, nudge, cheer }

/// Turns raw feed events into a readable timeline.
///
/// Nudges addressed to other people are filtered out: seeing that someone
/// poked a third party is noise, and forwarding it would leak a private jab.
List<ActivityItem> buildActivityFeed(
  List<FeedEvent> events, {
  required Map<String, PeerProfile> profiles,
  required String selfDid,
  int limit = 100,
}) {
  final items = <ActivityItem>[];

  for (final event in events) {
    final profile = profiles[event.author];
    final name = profile?.displayName ?? 'Anonym';
    final emoji = profile?.avatarEmoji ?? '🙂';
    final isOwn = event.author == selfDid;

    switch (event.type) {
      case FeedEventType.checkIn:
        final checkIn = CheckIn.fromPayload(
          event.payload,
          loggedAt: event.timestamp,
          eventHash: event.hash,
        );
        final def = habitDefinition(checkIn.category);
        final streak = (event.payload['streak'] as num?)?.toInt();
        items.add(ActivityItem(
          eventHash: event.hash,
          author: event.author,
          authorName: name,
          authorEmoji: emoji,
          timestamp: event.timestamp,
          emoji: def.emoji,
          kind: checkIn.relapse ? ActivityKind.relapse : ActivityKind.checkIn,
          headline: checkIn.relapse
              ? '$name hatte einen Rückfall bei ${def.titleDe}'
              : '$name: ${def.titleDe} erledigt',
          detail: _checkInDetail(checkIn, streak),
          isVerifiedLive: checkIn.isLive,
          isOwn: isOwn,
          streakAtTime: streak,
        ));

      case FeedEventType.challengeStarted:
        final statement = event.payload['statement'] as String?;
        items.add(ActivityItem(
          eventHash: event.hash,
          author: event.author,
          authorName: name,
          authorEmoji: emoji,
          timestamp: event.timestamp,
          emoji: '🚀',
          kind: ActivityKind.start,
          headline: '$name hat die Challenge gestartet',
          detail: statement,
          isVerifiedLive: true,
          isOwn: isOwn,
        ));

      case FeedEventType.challengeAscended:
        final tier = event.payload['tierName'] as String?;
        items.add(ActivityItem(
          eventHash: event.hash,
          author: event.author,
          authorName: name,
          authorEmoji: emoji,
          timestamp: event.timestamp,
          emoji: '👑',
          kind: ActivityKind.ascend,
          headline: '$name ist auf die nächste Stufe',
          detail: tier == null ? null : 'Neue Stufe: $tier',
          isVerifiedLive: true,
          isOwn: isOwn,
        ));

      case FeedEventType.nudge:
        final target = event.payload['target'] as String?;
        if (target != selfDid && !isOwn) continue;
        items.add(ActivityItem(
          eventHash: event.hash,
          author: event.author,
          authorName: name,
          authorEmoji: emoji,
          timestamp: event.timestamp,
          emoji: '👀',
          kind: ActivityKind.nudge,
          headline: isOwn
              ? 'Du hast ${_shortName(profiles[target])} angestupst'
              : '$name stupst dich an',
          detail: event.payload['text'] as String?,
          isVerifiedLive: true,
          isOwn: isOwn,
        ));

      case FeedEventType.cheer:
        final target = event.payload['target'] as String?;
        if (target != selfDid && !isOwn) continue;
        items.add(ActivityItem(
          eventHash: event.hash,
          author: event.author,
          authorName: name,
          authorEmoji: emoji,
          timestamp: event.timestamp,
          emoji: '🔥',
          kind: ActivityKind.cheer,
          headline: isOwn
              ? 'Du hast ${_shortName(profiles[target])} gefeiert'
              : '$name feiert dich',
          detail: event.payload['text'] as String?,
          isVerifiedLive: true,
          isOwn: isOwn,
        ));

      case FeedEventType.profile:
      case FeedEventType.missed:
      case FeedEventType.streakFreeze:
      case FeedEventType.friendRequest:
        continue;
    }
  }

  items.sort((ActivityItem a, ActivityItem b) =>
      b.timestamp.compareTo(a.timestamp));
  return items.take(limit).toList();
}

String? _checkInDetail(CheckIn checkIn, int? streak) {
  final parts = <String>[];
  if (streak != null && streak > 1) parts.add('$streak Tage Streak');
  if (checkIn.note != null && checkIn.note!.isNotEmpty) {
    parts.add(checkIn.note!);
  }
  if (!checkIn.isLive) {
    parts.add('nachgetragen für ${checkIn.day}');
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

String _shortName(PeerProfile? profile) => profile?.displayName ?? 'jemanden';

/// Relative time in German, for feed rows.
String formatRelative(DateTime timestamp, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(timestamp);
  if (diff.inMinutes < 1) return 'gerade eben';
  if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min';
  if (diff.inHours < 24) return 'vor ${diff.inHours} Std';
  if (diff.inDays == 1) return 'gestern';
  if (diff.inDays < 7) return 'vor ${diff.inDays} Tagen';
  return DayKey.fromDateTime(timestamp).toString();
}
