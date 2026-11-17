import 'package:meta/meta.dart';

import '../util/dates.dart';
import 'challenge.dart';
import 'habit.dart';
import 'progression.dart';

/// What a peer did most recently, as data rather than as a sentence.
///
/// The app turns this into "Marcel: Training erledigt" or "Marcel: workout
/// done" — the projection has no business knowing which.
enum PeerActivityKind {
  none,
  challengeStarted,
  ascended,
  checkIn,
  relapse,
  streakFreeze,
  missed,
}

@immutable
class PeerActivity {
  const PeerActivity({required this.kind, this.category});

  static const PeerActivity none = PeerActivity(kind: PeerActivityKind.none);

  final PeerActivityKind kind;

  /// Set for [PeerActivityKind.checkIn] and [PeerActivityKind.relapse].
  final HabitCategory? category;
}

/// The public profile a peer publishes on their own feed. Everything here is
/// self-asserted, which is fine — the numbers that matter (streak, XP) are
/// derived from their check-ins, not from what they claim.
@immutable
class PeerProfile {
  const PeerProfile({
    required this.userId,
    required this.displayName,
    required this.avatarEmoji,
    this.goalStatement,
    this.accentColor,
  });

  factory PeerProfile.fromPayload(String userId, Map<String, dynamic> payload) =>
      PeerProfile(
        userId: userId,
        displayName: payload['displayName'] as String? ?? 'Anonym',
        avatarEmoji: payload['avatarEmoji'] as String? ?? '🙂',
        goalStatement: payload['goalStatement'] as String?,
        accentColor: (payload['accentColor'] as num?)?.toInt(),
      );

  final String userId;
  final String displayName;
  final String avatarEmoji;
  final String? goalStatement;
  final int? accentColor;

  Map<String, dynamic> toPayload() => <String, dynamic>{
        'displayName': displayName,
        'avatarEmoji': avatarEmoji,
        if (goalStatement != null) 'goalStatement': goalStatement,
        if (accentColor != null) 'accentColor': accentColor,
      };

  PeerProfile copyWith({
    String? displayName,
    String? avatarEmoji,
    String? goalStatement,
    int? accentColor,
  }) =>
      PeerProfile(
        userId: userId,
        displayName: displayName ?? this.displayName,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        goalStatement: goalStatement ?? this.goalStatement,
        accentColor: accentColor ?? this.accentColor,
      );
}

/// Everything the app knows about one peer after folding their feed.
@immutable
class PeerState {
  const PeerState({
    required this.profile,
    required this.currentStreak,
    required this.longestStreak,
    required this.lifetimeXp,
    required this.weeklyXp,
    required this.dayNumber,
    required this.tier,
    required this.activeToday,
    required this.lastActivityAt,
    required this.lastActivity,
    required this.eventCount,
    this.challenge,
  });

  final PeerProfile profile;
  final int currentStreak;
  final int longestStreak;
  final int lifetimeXp;
  final int weeklyXp;
  final int dayNumber;
  final ChallengeTier tier;
  final bool activeToday;
  final DateTime? lastActivityAt;
  final PeerActivity lastActivity;
  final int eventCount;
  final Challenge? challenge;

  String get userId => profile.userId;

  League get league => leagueForXp(lifetimeXp);

  int get level => levelForXp(lifetimeXp);

  /// True when the peer has done nothing for two days or more — the state that
  /// earns them a nudge.
  bool get isSlipping {
    final last = lastActivityAt;
    if (last == null) return true;
    return DayKey.fromDateTime(last).differenceInDays(DayKey.today()) <= -2;
  }

  LeagueEntry toLeagueEntry({required int checkInsThisWeek}) => LeagueEntry(
        userId: userId,
        displayName: profile.displayName,
        avatarEmoji: profile.avatarEmoji,
        weeklyXp: weeklyXp,
        currentStreak: currentStreak,
        checkInsThisWeek: checkInsThisWeek,
        activeToday: activeToday,
      );
}
