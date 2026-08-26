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

/// Which sentence to say. Each phrasing is its own value rather than a
/// "variant index" into a list the app owns, so a translation with a different
/// number of phrasings cannot silently pick the wrong one.
enum CoachTemplate {
  welcomeCheckOffOneThing,
  welcomeYourOwnWords,
  welcomeNobodySeesDayOne,
  steadyToNextMilestone,
  steadyConsistencyBeatsIntensity,
  steadyPlanWorksIfYouDo,
  steadyRunning,
  pressureFriendsWereActive,
  pressureTheySeeYourFeed,
  pressureTwoHoursLeft,
  pressureLeaderAhead,
  pressureYouLead,
  urgentLastChance,
  urgentSmallestVersion,
  celebrateWeek,
  celebrateMonth,
  celebrateHabitFormed,
  celebrateHundred,
  celebrateYear,
  celebrateGeneric,
  recoverStreakLost,
  recoverRelapse,
  raiseBarHarderTarget,
  raiseBarNoEffortNoGain,
  raiseBarSecondFront,

  /// The text came from a language model and is carried verbatim.
  freeform,
}

/// The button under the message.
enum CoachCta { checkInNow, keepGoing, rescue, share, restart, adjustGoal }

/// Where a message came from, surfaced in the UI so the user always knows
/// whether a model wrote it.
enum CoachSource { heuristic, llm }

/// Concrete advice after a relapse, chosen by habit type.
enum RecoveryHint {
  digitalTrigger,
  alcoholPattern,
  sugarBreakfast,
  smallestVersion,
}

/// The minimum a template needs to name a person.
@immutable
class PeerMention {
  const PeerMention({
    required this.did,
    required this.displayName,
    required this.avatarEmoji,
    required this.streak,
  });

  factory PeerMention.of(PeerState peer) => PeerMention(
        did: peer.did,
        displayName: peer.profile.displayName,
        avatarEmoji: peer.profile.avatarEmoji,
        streak: peer.currentStreak,
      );

  final String did;
  final String displayName;
  final String avatarEmoji;
  final int streak;
}

/// What to say and everything needed to say it — in any language.
///
/// The coach decides *which* message fits the situation and supplies the
/// numbers and names; the app owns the wording. That split is what lets the
/// same rules drive a German and an English user, and it keeps the selection
/// logic unit-testable without asserting on prose.
@immutable
class CoachDirective {
  const CoachDirective({
    required this.tone,
    required this.template,
    required this.cta,
    required this.dayNumber,
    required this.totalDays,
    required this.streak,
    required this.completionPercent,
    this.source = CoachSource.heuristic,
    this.cycleIndex = 0,
    this.milestoneDay,
    this.daysToMilestone,
    this.hoursLeft,
    this.peers = const <PeerMention>[],
    this.extraPeerCount = 0,
    this.habitCategory,
    this.recoveryHint,
    this.statement,
    this.freeformHeadline,
    this.freeformBody,
  });

  final CoachTone tone;
  final CoachTemplate template;
  final CoachCta cta;
  final CoachSource source;

  final int dayNumber;
  final int totalDays;
  final int streak;
  final int completionPercent;
  final int cycleIndex;

  final int? milestoneDay;
  final int? daysToMilestone;

  /// Hours until midnight, for the late-evening rescue message.
  final int? hoursLeft;

  /// Named in the message, most relevant first.
  final List<PeerMention> peers;

  /// People beyond the ones named, for "and 4 others".
  final int extraPeerCount;

  final HabitCategory? habitCategory;
  final RecoveryHint? recoveryHint;

  /// The user's own goal sentence, shown back to them verbatim.
  final String? statement;

  final String? freeformHeadline;
  final String? freeformBody;
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

  int get completionPercent => (streak.completionRate * 100).round();
}

/// Why a peer is worth poking.
enum NudgeReason { inactiveTwoDays, nothingToday }

/// Which jab to send.
enum NudgeTemplate {
  iWentDidYou,
  yourStreakIsWatching,
  youWereInForDays,
  noPressureButISeeYourFeed,

  /// Wording produced by a language model, carried in [NudgeSuggestion.text].
  freeform,
}

/// A message aimed at a *peer* — the "hey, you were the one talking big"
/// mechanic. Nudges are signed feed events, so they cannot be spoofed.
@immutable
class NudgeSuggestion {
  const NudgeSuggestion({
    required this.targetDid,
    required this.template,
    required this.reason,
    required this.dayNumber,
    required this.peerStreak,
    this.text,
  });

  final String targetDid;
  final NudgeTemplate template;
  final NudgeReason reason;
  final int dayNumber;
  final int peerStreak;

  /// Set only for [NudgeTemplate.freeform].
  final String? text;
}

/// What kind of plan tweak the coach is proposing.
enum PlanAdviceKind {
  /// Hit rate has collapsed: drop a habit rather than keep failing.
  cutScope,

  /// An abstinence milestone is within reach.
  milestoneAhead,

  /// A habit has run long enough to make harder.
  raiseTarget,

  /// A habit is not happening at all; halve it until it does.
  halveTarget,

  /// Nobody is connected yet.
  inviteSomeone,

  /// Produced by a language model, carried in [PlanAdvice.text].
  freeform,
}

@immutable
class PlanAdvice {
  const PlanAdvice({
    required this.kind,
    this.habitCategory,
    this.completionPercent,
    this.daysToMilestone,
    this.milestone,
    this.streak,
    this.text,
  });

  final PlanAdviceKind kind;
  final HabitCategory? habitCategory;
  final int? completionPercent;
  final int? daysToMilestone;

  /// Milestone identifier, e.g. `alcohol_14`, for the app to look up.
  final String? milestone;

  final int? streak;
  final String? text;
}

/// The port every coach implementation satisfies.
abstract class CoachEngine {
  /// Whether this engine can answer right now (a model may still be loading).
  bool get isReady;

  /// Identifies the engine for the settings screen: either a model name or
  /// null, meaning "the rule-based one" — the app names that itself.
  String? get modelName;

  Future<CoachDirective> dailyBriefing(CoachContext context);

  /// Nudges the user could fire at friends who are slipping.
  Future<List<NudgeSuggestion>> nudgeSuggestions(CoachContext context);

  /// Concrete, actionable tweaks to the plan based on the last weeks.
  Future<List<PlanAdvice>> planAdjustments(CoachContext context);
}

/// Picks the tone. Kept separate from message selection so both the
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

/// The default call to action for a tone.
CoachCta ctaForTone(CoachTone tone) {
  switch (tone) {
    case CoachTone.celebrate:
      return CoachCta.share;
    case CoachTone.recover:
      return CoachCta.restart;
    case CoachTone.raiseTheBar:
      return CoachCta.adjustGoal;
    case CoachTone.urgent:
      return CoachCta.rescue;
    case CoachTone.steady:
      return CoachCta.keepGoing;
    case CoachTone.welcome:
    case CoachTone.socialPressure:
      return CoachCta.checkInNow;
  }
}

/// Concrete advice for the habit that was just broken.
RecoveryHint recoveryHintFor(HabitCategory category) {
  switch (category) {
    case HabitCategory.noFap:
    case HabitCategory.dopamineDetox:
      return RecoveryHint.digitalTrigger;
    case HabitCategory.noAlcohol:
      return RecoveryHint.alcoholPattern;
    case HabitCategory.noSugar:
      return RecoveryHint.sugarBreakfast;
    default:
      return RecoveryHint.smallestVersion;
  }
}
