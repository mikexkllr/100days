import 'package:meta/meta.dart';

import '../util/dates.dart';
import 'challenge.dart';
import 'progression.dart';

/// The public profile a peer publishes on their own feed. Everything here is
/// self-asserted, which is fine — the numbers that matter (streak, XP) are
/// derived from their signed check-ins, not from what they claim.
@immutable
class PeerProfile {
  const PeerProfile({
    required this.did,
    required this.displayName,
    required this.avatarEmoji,
    this.goalStatement,
    this.accentColor,
  });

  factory PeerProfile.fromPayload(String did, Map<String, dynamic> payload) =>
      PeerProfile(
        did: did,
        displayName: payload['displayName'] as String? ?? 'Anonym',
        avatarEmoji: payload['avatarEmoji'] as String? ?? '🙂',
        goalStatement: payload['goalStatement'] as String?,
        accentColor: (payload['accentColor'] as num?)?.toInt(),
      );

  final String did;
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
        did: did,
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
    required this.lastActivityLabel,
    required this.headSeq,
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
  final String lastActivityLabel;
  final int headSeq;
  final Challenge? challenge;

  String get did => profile.did;

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
        did: did,
        displayName: profile.displayName,
        avatarEmoji: profile.avatarEmoji,
        weeklyXp: weeklyXp,
        currentStreak: currentStreak,
        checkInsThisWeek: checkInsThisWeek,
        activeToday: activeToday,
      );
}
