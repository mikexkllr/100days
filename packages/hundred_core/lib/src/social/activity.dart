import '../domain/check_in.dart';
import '../domain/habit.dart';
import '../domain/peer.dart';
import '../feed/event.dart';
import '../util/dates.dart';

enum ActivityKind { checkIn, relapse, milestone, start, ascend, nudge, cheer }

/// One row in the social timeline, as data.
///
/// No sentence is assembled here — the app builds "Marcel: Training erledigt"
/// or "Marcel: workout done" from these fields. What *is* here is everything
/// that cannot be recovered later: which event, whose, when, and whether it
/// was a live proof or a backfill.
class ActivityItem {
  const ActivityItem({
    required this.eventHash,
    required this.author,
    required this.authorName,
    required this.authorEmoji,
    required this.timestamp,
    required this.emoji,
    required this.kind,
    required this.isVerifiedLive,
    this.category,
    this.claimedDay,
    this.isOwn = false,
    this.streakAtTime,
    this.note,
    this.message,
    this.targetName,
    this.statement,
    this.tierIndex,
  });

  final String eventHash;
  final String author;
  final String authorName;
  final String authorEmoji;
  final DateTime timestamp;
  final String emoji;
  final ActivityKind kind;

  /// The event was published on the day it claims, so it is a live proof
  /// rather than a backfill. Shown as a small badge — this is the feature that
  /// makes the leaderboard mean anything.
  final bool isVerifiedLive;

  /// Set for [ActivityKind.checkIn] and [ActivityKind.relapse].
  final HabitCategory? category;

  /// The day the check-in claims, shown when it differs from the day it was
  /// written.
  final DayKey? claimedDay;

  final bool isOwn;
  final int? streakAtTime;

  /// User-authored text. Never translated, never rewritten.
  final String? note;

  /// The nudge or cheer message, also user-authored.
  final String? message;

  /// Display name of the person a nudge or cheer was aimed at.
  final String? targetName;

  /// The goal sentence, for [ActivityKind.start].
  final String? statement;

  /// The tier reached, for [ActivityKind.ascend].
  final int? tierIndex;
}

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
    final name = profile?.displayName ?? '';
    final emoji = profile?.avatarEmoji ?? '🙂';
    final isOwn = event.author == selfDid;

    switch (event.type) {
      case FeedEventType.checkIn:
        final checkIn = CheckIn.fromPayload(
          event.payload,
          loggedAt: event.timestamp,
          eventHash: event.hash,
        );
        items.add(ActivityItem(
          eventHash: event.hash,
          author: event.author,
          authorName: name,
          authorEmoji: emoji,
          timestamp: event.timestamp,
          emoji: habitDefinition(checkIn.category).emoji,
          kind: checkIn.relapse ? ActivityKind.relapse : ActivityKind.checkIn,
          category: checkIn.category,
          claimedDay: checkIn.day,
          streakAtTime: (event.payload['streak'] as num?)?.toInt(),
          note: checkIn.note,
          isVerifiedLive: checkIn.isLive,
          isOwn: isOwn,
        ));

      case FeedEventType.challengeStarted:
        items.add(ActivityItem(
          eventHash: event.hash,
          author: event.author,
          authorName: name,
          authorEmoji: emoji,
          timestamp: event.timestamp,
          emoji: '🚀',
          kind: ActivityKind.start,
          statement: event.payload['statement'] as String?,
          isVerifiedLive: true,
          isOwn: isOwn,
        ));

      case FeedEventType.challengeAscended:
        items.add(ActivityItem(
          eventHash: event.hash,
          author: event.author,
          authorName: name,
          authorEmoji: emoji,
          timestamp: event.timestamp,
          emoji: '👑',
          kind: ActivityKind.ascend,
          tierIndex: (event.payload['cycle'] as num?)?.toInt(),
          isVerifiedLive: true,
          isOwn: isOwn,
        ));

      case FeedEventType.nudge:
      case FeedEventType.cheer:
        final target = event.payload['target'] as String?;
        if (target != selfDid && !isOwn) continue;
        final isNudge = event.type == FeedEventType.nudge;
        items.add(ActivityItem(
          eventHash: event.hash,
          author: event.author,
          authorName: name,
          authorEmoji: emoji,
          timestamp: event.timestamp,
          emoji: isNudge ? '👀' : '🔥',
          kind: isNudge ? ActivityKind.nudge : ActivityKind.cheer,
          message: event.payload['text'] as String?,
          targetName: profiles[target]?.displayName,
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
