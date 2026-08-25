import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../util/dates.dart';
import 'challenge.dart';
import 'check_in.dart';
import 'habit.dart';
import 'schedule.dart';

/// XP awarded for a single check-in.
///
/// Three things scale it, in this order of importance: how hard the habit is,
/// how long the streak already is (so quitting hurts more the longer you go),
/// and whether it was logged on the day rather than backfilled.
int xpForCheckIn({
  required Habit habit,
  required CheckIn checkIn,
  required int streakBefore,
}) {
  if (checkIn.relapse) return 0;
  final base = habit.definition.difficulty * 10;
  final streakMultiplier = 1 + math.min(streakBefore, 50) / 50.0;
  final liveMultiplier = checkIn.isLive ? 1.2 : 1.0;
  return (base * streakMultiplier * liveMultiplier).round();
}

/// Bonus for closing out every habit scheduled today.
const int kPerfectDayBonus = 25;

/// Bonus at a milestone day (day 7, 30, 100, 365 …).
int milestoneBonus(int dayNumber) =>
    kMilestoneDays.contains(dayNumber) ? dayNumber * 5 : 0;

/// Total XP for a completed day.
int xpForDay({
  required Challenge challenge,
  required DayKey day,
  required DayLog? log,
  required Map<String, int> streakBeforeByHabit,
}) {
  if (log == null) return 0;
  var total = 0;
  for (final entry in log.entries) {
    final habit = challenge.habitById(entry.habitId);
    if (habit == null) continue;
    total += xpForCheckIn(
      habit: habit,
      checkIn: entry,
      streakBefore: streakBeforeByHabit[entry.habitId] ?? 0,
    );
  }
  final required = requiredHabitsOn(challenge, day);
  final allDone = required.isNotEmpty &&
      required.every((Habit h) {
        final e = log.entryFor(h.id);
        return e != null && !e.relapse && e.value >= h.target;
      });
  if (allDone) {
    total += kPerfectDayBonus + milestoneBonus(challenge.dayNumber(day));
  }
  return total;
}

/// Level thresholds. Growth is roughly quadratic, so early levels come fast
/// (the first week should feel like progress) and later ones take real weeks.
int xpRequiredForLevel(int level) {
  if (level <= 1) return 0;
  return (50 * (level - 1) * (level - 1) + 150 * (level - 1)).round();
}

int levelForXp(int xp) {
  var level = 1;
  while (xpRequiredForLevel(level + 1) <= xp) {
    level++;
    if (level > 500) break;
  }
  return level;
}

double levelProgress(int xp) {
  final level = levelForXp(xp);
  final floor = xpRequiredForLevel(level);
  final ceil = xpRequiredForLevel(level + 1);
  if (ceil <= floor) return 1;
  return ((xp - floor) / (ceil - floor)).clamp(0.0, 1.0);
}

/// Weekly leagues, straight out of the Duolingo playbook: a small pool of
/// people, one week, promotion at the top and demotion at the bottom. The
/// pressure comes from the pool being your actual friends.
enum League { holz, bronze, silber, gold, platin, diamant, obsidian }

extension LeagueInfo on League {
  String get nameDe {
    switch (this) {
      case League.holz:
        return 'Holz';
      case League.bronze:
        return 'Bronze';
      case League.silber:
        return 'Silber';
      case League.gold:
        return 'Gold';
      case League.platin:
        return 'Platin';
      case League.diamant:
        return 'Diamant';
      case League.obsidian:
        return 'Obsidian';
    }
  }

  String get emoji {
    switch (this) {
      case League.holz:
        return '🪵';
      case League.bronze:
        return '🥉';
      case League.silber:
        return '🥈';
      case League.gold:
        return '🥇';
      case League.platin:
        return '💠';
      case League.diamant:
        return '💎';
      case League.obsidian:
        return '🖤';
    }
  }

  League get next =>
      League.values[math.min(index + 1, League.values.length - 1)];

  League get previous => League.values[math.max(index - 1, 0)];
}

/// One row of the weekly leaderboard.
@immutable
class LeagueEntry {
  const LeagueEntry({
    required this.did,
    required this.displayName,
    required this.avatarEmoji,
    required this.weeklyXp,
    required this.currentStreak,
    required this.checkInsThisWeek,
    required this.activeToday,
  });

  final String did;
  final String displayName;
  final String avatarEmoji;
  final int weeklyXp;
  final int currentStreak;
  final int checkInsThisWeek;
  final bool activeToday;
}

@immutable
class LeagueStanding {
  const LeagueStanding({
    required this.entries,
    required this.weekKey,
    required this.league,
  });

  final List<LeagueEntry> entries;
  final String weekKey;
  final League league;

  int rankOf(String did) {
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].did == did) return i + 1;
    }
    return -1;
  }

  /// Top three go up, bottom three go down — but only once the pool is big
  /// enough that a rank means anything.
  int get promotionCutoff => entries.length >= 6 ? 3 : 1;

  int get demotionCutoff =>
      entries.length >= 6 ? entries.length - 2 : entries.length + 1;

  bool isPromoting(String did) {
    final rank = rankOf(did);
    return rank > 0 && rank <= promotionCutoff;
  }

  bool isDemoting(String did) {
    final rank = rankOf(did);
    return rank > 0 && rank >= demotionCutoff;
  }
}

/// Builds the standing for [weekKey] from already-projected peer stats.
LeagueStanding buildLeagueStanding({
  required List<LeagueEntry> entries,
  required String weekKey,
  required League league,
}) {
  final sorted = entries.toList()
    ..sort((LeagueEntry a, LeagueEntry b) {
      final byXp = b.weeklyXp.compareTo(a.weeklyXp);
      if (byXp != 0) return byXp;
      final byStreak = b.currentStreak.compareTo(a.currentStreak);
      if (byStreak != 0) return byStreak;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
  return LeagueStanding(entries: sorted, weekKey: weekKey, league: league);
}

/// League derived from lifetime XP, so a fresh install cannot land in Diamant.
League leagueForXp(int lifetimeXp) {
  const List<int> thresholds = <int>[0, 500, 1500, 3500, 7000, 13000, 25000];
  var league = League.holz;
  for (var i = 0; i < thresholds.length; i++) {
    if (lifetimeXp >= thresholds[i]) league = League.values[i];
  }
  return league;
}
