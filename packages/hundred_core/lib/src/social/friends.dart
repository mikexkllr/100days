import 'package:meta/meta.dart';

import '../domain/schedule.dart';
import '../domain/streak.dart';
import '../util/dates.dart';
import 'projection.dart';

/// Days in a row on which two friends both showed up — the streak they keep
/// together, and lose together.
///
/// A day counts when each of them either completed it or had nothing
/// scheduled (a rest day), and at least one of them completed it. Today
/// counts once both are done; until then it is open and breaks nothing.
///
/// A streak freeze works here as it does alone: a day either of them froze
/// holds the shared streak without counting for it. Both phones compute this
/// from what friends can see — pass each side's public projection, never the
/// owner's full one, or the two would disagree.
int friendStreak({
  required UserProjection a,
  required UserProjection b,
  required DayKey today,
}) {
  final challengeA = a.challenge;
  final challengeB = b.challenge;
  if (challengeA == null || challengeB == null) return 0;

  // 0: broken, 1: counts, 2: held — nobody had anything, or a freeze
  // covered a miss — neither counts nor breaks.
  int status(DayKey day) {
    final key = day.toString();
    final requiredA = requiredHabitsOn(challengeA, day).isNotEmpty;
    final requiredB = requiredHabitsOn(challengeB, day).isNotEmpty;
    if (!requiredA && !requiredB) return 2;
    final missedA =
        requiredA && !isDayComplete(challengeA, day, a.logsByDay[key]);
    final missedB =
        requiredB && !isDayComplete(challengeB, day, b.logsByDay[key]);
    if ((missedA && !a.frozenDays.contains(key)) ||
        (missedB && !b.frozenDays.contains(key))) {
      return 0;
    }
    if (missedA || missedB) return 2;
    return 1;
  }

  final start = challengeA.startDay.isAfter(challengeB.startDay)
      ? challengeA.startDay
      : challengeB.startDay;
  var streak = 0;
  var day = today;
  if (status(today) != 1) day = today.addDays(-1);
  for (var i = 0; i < 1000 && !day.isBefore(start); i++, day = day.addDays(-1)) {
    final s = status(day);
    if (s == 0) break;
    if (s == 1) streak++;
  }
  return streak;
}

/// A goal two friends reach together within one week.
@immutable
class FriendQuest {
  const FriendQuest({
    required this.weekKey,
    required this.target,
    required this.mine,
    required this.theirs,
  });

  final String weekKey;

  /// Check-ins the two need together.
  final int target;
  final int mine;
  final int theirs;

  int get progress => mine + theirs;
  bool get done => progress >= target;
  double get fraction => target == 0 ? 0 : (progress / target).clamp(0.0, 1.0);
}

/// This week's quest for [me] and [friend]: together, about as many
/// check-ins as two steady people manage in five days — achievable, but
/// only if both show up.
FriendQuest friendQuest({
  required UserProjection me,
  required UserProjection friend,
  required DayKey today,
}) {
  final week = today.isoWeekKey;
  int habitsPerDay(UserProjection p) =>
      (p.challenge?.habits.length ?? 1).clamp(1, 4);
  final target = 5 * (habitsPerDay(me) + habitsPerDay(friend));
  return FriendQuest(
    weekKey: week,
    target: target,
    mine: me.checkInsInWeek(week),
    theirs: friend.checkInsInWeek(week),
  );
}

/// How many people of a weekly league group move up. Mirrors
/// `close_league_week` on the server: seven of a full group of 30, fewer in
/// small groups, nobody where a rank says nothing.
int promotionSlots(int groupSize) {
  if (groupSize < 5) return groupSize >= 2 ? 1 : 0;
  if (groupSize < 10) return 2;
  if (groupSize < 20) return 4;
  return 7;
}

/// How many move down. Nobody in groups under five.
int demotionSlots(int groupSize) {
  if (groupSize < 5) return 0;
  if (groupSize < 10) return 1;
  if (groupSize < 20) return 3;
  return 5;
}

/// The most XP a day can plausibly earn: five demanding habits with a long
/// streak, tracked and live, plus the perfect-day bonus. The server caps
/// what a phone reports for the public league at this per day of the week
/// so far.
const int kMaxDailyXp = 1000;
