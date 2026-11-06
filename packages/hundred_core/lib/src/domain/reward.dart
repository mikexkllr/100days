import '../util/dates.dart';
import 'challenge.dart';
import 'flame.dart';
import 'progression.dart';
import 'streak.dart';

/// What a completed day earned, loudest first.
///
/// Every value is a fact about the day the feed already proves. The
/// celebration decides how big to make the moment — never what happened.
enum RewardHighlight {
  /// Day 100 of the cycle (or 200, 300 …).
  cycleComplete,

  /// A milestone day (1, 3, 7, 14, 21, 30 …).
  milestone,

  /// The flame reached its next stage.
  evolution,

  /// The streak just passed the best run that came before it.
  record,

  /// Lifetime XP crossed into a new level.
  levelUp,

  /// Every habit scheduled today is done. True of every completed day.
  perfectDay,
}

/// The facts the day-complete celebration reveals.
class DayReward {
  const DayReward({
    required this.dayNumber,
    required this.streakBefore,
    required this.streak,
    required this.xpToday,
    required this.levelBefore,
    required this.level,
    required this.stageBefore,
    required this.stage,
    required this.highlights,
  });

  final int dayNumber;
  final int streakBefore;
  final int streak;

  /// Everything the day scored, bonuses included.
  final int xpToday;
  final int levelBefore;
  final int level;
  final FlameStage stageBefore;
  final FlameStage stage;

  /// Loudest first; never empty, always ends with [RewardHighlight.perfectDay].
  final List<RewardHighlight> highlights;

  RewardHighlight get top => highlights.first;

  /// Something happened today that does not happen every day.
  bool get isJackpot => top != RewardHighlight.perfectDay;
}

/// The reward for completing [today], from the streak and lifetime XP just
/// before and just after the check-in that completed it.
DayReward rewardForDay({
  required Challenge challenge,
  required DayKey today,
  required StreakStats before,
  required StreakStats after,
  required int xpBefore,
  required int xpAfter,
  required int xpToday,
}) {
  final dayNumber = challenge.dayNumber(today);
  final levelBefore = levelForXp(xpBefore);
  final level = levelForXp(xpAfter);
  final stageBefore = flameStageFor(before.current);
  final stage = flameStageFor(after.current);

  final highlights = <RewardHighlight>[
    if (challenge.dayInCycle(today) == challenge.lengthDays)
      RewardHighlight.cycleComplete,
    if (kMilestoneDays.contains(dayNumber)) RewardHighlight.milestone,
    if (stage.index > stageBefore.index) RewardHighlight.evolution,
    if (after.beatPreviousBestToday) RewardHighlight.record,
    if (level > levelBefore) RewardHighlight.levelUp,
    RewardHighlight.perfectDay,
  ];

  return DayReward(
    dayNumber: dayNumber,
    streakBefore: before.current,
    streak: after.current,
    xpToday: xpToday,
    levelBefore: levelBefore,
    level: level,
    stageBefore: stageBefore,
    stage: stage,
    highlights: highlights,
  );
}
