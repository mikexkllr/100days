import 'dart:math' as math;

import '../domain/habit.dart';
import '../domain/peer.dart';
import '../plan/abstinence.dart';
import 'coach.dart';

/// The always-available coach: pure rules, zero model, zero network.
///
/// This is the floor of the product. If the on-device model is missing, still
/// downloading, or too slow, the user must never get a blank screen where the
/// motivation is supposed to be — so every path here terminates in a real
/// directive.
class HeuristicCoach implements CoachEngine {
  const HeuristicCoach();

  @override
  bool get isReady => true;

  @override
  String? get modelName => null;

  /// How many friends a message names before it says "and N others".
  static const int maxNamedPeers = 3;

  @override
  Future<CoachDirective> dailyBriefing(CoachContext c) async {
    final tone = selectTone(c);
    // Seeded by the day so the choice is stable within a day: re-opening the
    // app should not reroll the pep talk.
    final random = math.Random(c.today.toString().hashCode ^ tone.index);

    switch (tone) {
      case CoachTone.welcome:
        return _base(
          c,
          tone,
          _pick(random, <CoachTemplate>[
            CoachTemplate.welcomeCheckOffOneThing,
            CoachTemplate.welcomeYourOwnWords,
            CoachTemplate.welcomeNobodySeesDayOne,
          ]),
          statement: c.challenge.goal.statement,
        );

      case CoachTone.steady:
        final next = c.challenge.nextMilestone(c.dayNumber);
        if (next == null) {
          return _base(c, tone, CoachTemplate.steadyRunning);
        }
        return _base(
          c,
          tone,
          _pick(random, <CoachTemplate>[
            CoachTemplate.steadyToNextMilestone,
            CoachTemplate.steadyConsistencyBeatsIntensity,
            CoachTemplate.steadyPlanWorksIfYouDo,
          ]),
          milestoneDay: next,
          daysToMilestone: next - c.dayNumber,
        );

      case CoachTone.socialPressure:
        final active = c.peersActiveToday;
        if (active.isNotEmpty) {
          return _base(
            c,
            tone,
            _pick(random, <CoachTemplate>[
              CoachTemplate.pressureFriendsWereActive,
              CoachTemplate.pressureTheySeeYourFeed,
              CoachTemplate.pressureTwoHoursLeft,
            ]),
            peers: active,
          );
        }
        final ahead = c.peersAhead;
        if (ahead.isEmpty) {
          return _base(c, tone, CoachTemplate.pressureYouLead);
        }
        return _base(
          c,
          tone,
          CoachTemplate.pressureLeaderAhead,
          peers: <PeerState>[ahead.first],
        );

      case CoachTone.urgent:
        return _base(
          c,
          tone,
          c.isLateNight
              ? CoachTemplate.urgentLastChance
              : CoachTemplate.urgentSmallestVersion,
          hoursLeft: math.max(1, 24 - c.now.hour),
        );

      case CoachTone.celebrate:
        return _base(
          c,
          tone,
          _celebrationFor(c.dayNumber),
          milestoneDay: c.dayNumber,
        );

      case CoachTone.recover:
        final relapsed = _relapsedHabit(c);
        if (relapsed == null) {
          return _base(c, tone, CoachTemplate.recoverStreakLost);
        }
        return _base(
          c,
          tone,
          CoachTemplate.recoverRelapse,
          habitCategory: relapsed.category,
          recoveryHint: recoveryHintFor(relapsed.category),
        );

      case CoachTone.raiseTheBar:
        return _base(
          c,
          tone,
          _pick(random, <CoachTemplate>[
            CoachTemplate.raiseBarHarderTarget,
            CoachTemplate.raiseBarNoEffortNoGain,
            CoachTemplate.raiseBarSecondFront,
          ]),
        );
    }
  }

  @override
  Future<List<NudgeSuggestion>> nudgeSuggestions(CoachContext c) async {
    final suggestions = <NudgeSuggestion>[];
    for (final peer in c.peers) {
      if (peer.activeToday) continue;
      // Never taunt someone who is ahead of you and merely has not gone yet.
      if (!peer.isSlipping && c.streak.current <= peer.currentStreak) continue;
      final random = math.Random(peer.did.hashCode ^ c.today.hashCode);
      suggestions.add(NudgeSuggestion(
        targetDid: peer.did,
        template: _pick(random, <NudgeTemplate>[
          NudgeTemplate.iWentDidYou,
          NudgeTemplate.yourStreakIsWatching,
          NudgeTemplate.youWereInForDays,
          NudgeTemplate.noPressureButISeeYourFeed,
        ]),
        reason: peer.isSlipping
            ? NudgeReason.inactiveTwoDays
            : NudgeReason.nothingToday,
        dayNumber: c.dayNumber,
        peerStreak: peer.currentStreak,
      ));
    }
    suggestions.sort((NudgeSuggestion a, NudgeSuggestion b) =>
        a.targetDid.compareTo(b.targetDid));
    return suggestions.take(5).toList();
  }

  @override
  Future<List<PlanAdvice>> planAdjustments(CoachContext c) async {
    final advice = <PlanAdvice>[];

    if (c.streak.completionRate < 0.6 && c.streak.scheduledDays >= 7) {
      advice.add(PlanAdvice(
        kind: PlanAdviceKind.cutScope,
        completionPercent: c.completionPercent,
      ));
    }

    for (final habit in c.challenge.habits) {
      final streak = c.habitStreaks[habit.id] ?? 0;
      if (habit.kind == HabitKind.abstain) {
        final next = nextMilestone(habit.category, streak);
        if (next != null) {
          advice.add(PlanAdvice(
            kind: PlanAdviceKind.milestoneAhead,
            habitCategory: habit.category,
            milestone: next.id,
            daysToMilestone: next.day - streak,
          ));
        }
      } else if (streak >= 21) {
        advice.add(PlanAdvice(
          kind: PlanAdviceKind.raiseTarget,
          habitCategory: habit.category,
          streak: streak,
        ));
      } else if (streak == 0 && c.dayNumber > 7) {
        advice.add(PlanAdvice(
          kind: PlanAdviceKind.halveTarget,
          habitCategory: habit.category,
        ));
      }
    }

    if (c.peers.isEmpty) {
      advice.add(const PlanAdvice(kind: PlanAdviceKind.inviteSomeone));
    }

    return advice.take(6).toList();
  }

  CoachDirective _base(
    CoachContext c,
    CoachTone tone,
    CoachTemplate template, {
    List<PeerState> peers = const <PeerState>[],
    int? milestoneDay,
    int? daysToMilestone,
    int? hoursLeft,
    HabitCategory? habitCategory,
    RecoveryHint? recoveryHint,
    String? statement,
  }) {
    return CoachDirective(
      tone: tone,
      template: template,
      cta: ctaForTone(tone),
      dayNumber: c.dayNumber,
      totalDays: c.challenge.lengthDays,
      streak: c.streak.current,
      completionPercent: c.completionPercent,
      cycleIndex: c.challenge.cycle,
      milestoneDay: milestoneDay,
      daysToMilestone: daysToMilestone,
      hoursLeft: hoursLeft,
      peers: peers.take(maxNamedPeers).map(PeerMention.of).toList(),
      extraPeerCount: math.max(0, peers.length - maxNamedPeers),
      habitCategory: habitCategory,
      recoveryHint: recoveryHint,
      statement: statement,
    );
  }

  CoachTemplate _celebrationFor(int day) {
    switch (day) {
      case 7:
        return CoachTemplate.celebrateWeek;
      case 30:
        return CoachTemplate.celebrateMonth;
      case 66:
        return CoachTemplate.celebrateHabitFormed;
      case 100:
        return CoachTemplate.celebrateHundred;
      case 365:
        return CoachTemplate.celebrateYear;
      default:
        return CoachTemplate.celebrateGeneric;
    }
  }

  Habit? _relapsedHabit(CoachContext c) {
    final log = c.todayLog;
    if (log == null) return null;
    for (final entry in log.entries) {
      if (entry.relapse) return c.challenge.habitById(entry.habitId);
    }
    return null;
  }

  T _pick<T>(math.Random random, List<T> options) =>
      options[random.nextInt(options.length)];
}
