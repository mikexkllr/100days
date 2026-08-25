import 'package:meta/meta.dart';

import '../domain/challenge.dart';
import '../domain/check_in.dart';
import '../domain/habit.dart';
import '../domain/peer.dart';
import '../domain/streak.dart';
import '../util/dates.dart';

/// How the coach is allowed to talk right now.
///
/// The tone is picked from state, not at random: congratulating someone who
/// just relapsed reads as mockery, and being gentle with someone who is
/// coasting is exactly why habit apps stop working after two weeks.
enum CoachTone {
  /// First days, fresh start.
  welcome,

  /// On track, nothing dramatic.
  steady,

  /// Friends moved, you did not. The core mechanic of this app.
  socialPressure,

  /// The day is nearly over and the streak is about to die.
  urgent,

  /// A milestone was reached.
  celebrate,

  /// A relapse or a broken streak. Rebuild, do not pile on.
  recover,

  /// Long streak, high consistency — raise the bar.
  raiseTheBar,
}

@immutable
class CoachMessage {
  const CoachMessage({
    required this.tone,
    required this.headline,
    required this.body,
    this.ctaLabel,
    this.source = 'heuristic',
  });

  final CoachTone tone;
  final String headline;
  final String body;
  final String? ctaLabel;

  /// `heuristic` or `llm` — surfaced in the UI so the user always knows
  /// whether a model wrote this.
  final String source;
}

/// The full picture handed to the coach. Assembled on device; never leaves it.
@immutable
class CoachContext {
  const CoachContext({
    required this.challenge,
    required this.streak,
    required this.today,
    required this.todayLog,
    required this.peers,
    required this.now,
    required this.habitStreaks,
    this.lastRelapseDay,
  });

  final Challenge challenge;
  final StreakStats streak;
  final DayKey today;
  final DayLog? todayLog;
  final List<PeerState> peers;
  final DateTime now;
  final Map<String, int> habitStreaks;
  final DayKey? lastRelapseDay;

  int get dayNumber => challenge.dayNumber(today);

  List<PeerState> get peersActiveToday =>
      peers.where((PeerState p) => p.activeToday).toList();

  List<PeerState> get peersAhead => peers
      .where((PeerState p) => p.currentStreak > streak.current)
      .toList()
    ..sort((PeerState a, PeerState b) =>
        b.currentStreak.compareTo(a.currentStreak));

  bool get isEvening => now.hour >= 19;

  bool get isLateNight => now.hour >= 22;

  bool get justRelapsed =>
      lastRelapseDay != null && lastRelapseDay!.differenceInDays(today) >= -1;
}

/// A message aimed at a *peer* — the "hey, you were the one talking big"
/// mechanic. Nudges are signed feed events, so they cannot be spoofed.
@immutable
class NudgeSuggestion {
  const NudgeSuggestion({
    required this.targetDid,
    required this.text,
    required this.reason,
  });

  final String targetDid;
  final String text;
  final String reason;
}

/// The port every coach implementation satisfies.
abstract class CoachEngine {
  /// Whether this engine can answer right now (a model may still be loading).
  bool get isReady;

  /// Short label for the UI: "Regelbasiert" or the model name.
  String get name;

  Future<CoachMessage> dailyBriefing(CoachContext context);

  /// Nudges the user could fire at friends who are slipping.
  Future<List<NudgeSuggestion>> nudgeSuggestions(CoachContext context);

  /// Concrete, actionable tweaks to the plan based on the last weeks.
  Future<List<String>> planAdjustments(CoachContext context);
}

/// Picks the tone. Kept separate from message generation so both the
/// rule-based and the model-based coach agree on *what the situation is*,
/// and only differ in how they say it.
CoachTone selectTone(CoachContext c) {
  if (c.justRelapsed || (c.streak.current == 0 && c.dayNumber > 3)) {
    return CoachTone.recover;
  }
  if (kMilestoneDays.contains(c.dayNumber) && c.streak.doneToday) {
    return CoachTone.celebrate;
  }
  if (c.dayNumber <= 3) return CoachTone.welcome;
  if (c.streak.atRisk && c.isEvening) return CoachTone.urgent;
  if (c.streak.atRisk && c.peersActiveToday.isNotEmpty) {
    return CoachTone.socialPressure;
  }
  if (c.streak.current >= 21 && c.streak.completionRate > 0.9) {
    return CoachTone.raiseTheBar;
  }
  if (c.streak.atRisk) return CoachTone.socialPressure;
  return CoachTone.steady;
}

/// Human-readable summary of one habit's state, reused by both engines.
String describeHabitState(Habit habit, int streakDays) {
  final unit = habit.kind == HabitKind.abstain ? 'Tage clean' : 'Tage Streak';
  return '${habit.emoji} ${habit.displayTitle}: $streakDays $unit';
}
