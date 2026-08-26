import 'package:hundred_core/hundred_core.dart';

import 'core_l10n.dart';
import 'plan_l10n.dart';
import 'generated/app_localizations.dart';

/// Turns the coach's directives, nudges and advice into sentences.
///
/// The coach decides *what* to say from the user's state; this decides how it
/// reads. Keeping the two apart is what lets the identical rules drive a
/// German and an English user.
extension CoachL10n on AppLocalizations {
  String coachHeadline(CoachDirective d) {
    if (d.template == CoachTemplate.freeform) {
      return d.freeformHeadline ?? coachHeadStreak(d.streak);
    }
    switch (d.template) {
      case CoachTemplate.welcomeCheckOffOneThing:
      case CoachTemplate.welcomeYourOwnWords:
      case CoachTemplate.welcomeNobodySeesDayOne:
        return coachHeadDayOf(d.dayNumber, d.totalDays);

      case CoachTemplate.pressureFriendsWereActive:
      case CoachTemplate.pressureTheySeeYourFeed:
      case CoachTemplate.pressureTwoHoursLeft:
        final int total = d.peers.length + d.extraPeerCount;
        return total == 1
            ? coachHeadFriendActive(d.peers.first.displayName)
            : coachHeadFriendsActive(total);

      case CoachTemplate.pressureLeaderAhead:
        return coachHeadLeaderAhead(d.peers.first.displayName);

      case CoachTemplate.pressureYouLead:
        return coachHeadDayStillOpen;

      case CoachTemplate.urgentLastChance:
        return coachHeadLastChance;

      case CoachTemplate.urgentSmallestVersion:
        return coachHeadAtStake(d.streak);

      case CoachTemplate.celebrateWeek:
      case CoachTemplate.celebrateMonth:
      case CoachTemplate.celebrateHabitFormed:
      case CoachTemplate.celebrateHundred:
      case CoachTemplate.celebrateYear:
      case CoachTemplate.celebrateGeneric:
        return coachHeadCelebrate(d.milestoneDay ?? d.dayNumber);

      case CoachTemplate.recoverStreakLost:
      case CoachTemplate.recoverRelapse:
        return coachHeadNewDayOne;

      case CoachTemplate.raiseBarHarderTarget:
      case CoachTemplate.raiseBarNoEffortNoGain:
      case CoachTemplate.raiseBarSecondFront:
        return coachHeadTooSmooth(d.streak);

      case CoachTemplate.steadyToNextMilestone:
      case CoachTemplate.steadyConsistencyBeatsIntensity:
      case CoachTemplate.steadyPlanWorksIfYouDo:
      case CoachTemplate.steadyRunning:
      case CoachTemplate.freeform:
        return coachHeadStreak(d.streak);
    }
  }

  String coachBody(CoachDirective d) {
    switch (d.template) {
      case CoachTemplate.freeform:
        return d.freeformBody ?? coachSteadyRunning;
      case CoachTemplate.welcomeCheckOffOneThing:
        return coachWelcomeCheckOff;
      case CoachTemplate.welcomeYourOwnWords:
        return coachWelcomeYourWords(d.statement ?? '');
      case CoachTemplate.welcomeNobodySeesDayOne:
        return coachWelcomeNobodySees(d.dayNumber);
      case CoachTemplate.steadyToNextMilestone:
        return coachSteadyMilestoneNothingSpectacular(
            d.daysToMilestone ?? 0, d.milestoneDay ?? 0);
      case CoachTemplate.steadyConsistencyBeatsIntensity:
        return coachSteadyMilestoneConsistency(
            d.daysToMilestone ?? 0, d.milestoneDay ?? 0);
      case CoachTemplate.steadyPlanWorksIfYouDo:
        return coachSteadyMilestonePlanWorks(
            d.daysToMilestone ?? 0, d.milestoneDay ?? 0);
      case CoachTemplate.steadyRunning:
        return coachSteadyRunning;
      case CoachTemplate.pressureFriendsWereActive:
        return coachPressureLeaveIt(peerNames(d));
      case CoachTemplate.pressureTheySeeYourFeed:
        return coachPressureTheySee(peerNames(d));
      case CoachTemplate.pressureTwoHoursLeft:
        return coachPressureHoursLeft(peerNames(d));
      case CoachTemplate.pressureLeaderAhead:
        final PeerMention leader = d.peers.first;
        return coachPressureLeaderBody(
            leader.avatarEmoji, leader.displayName, leader.streak, d.streak);
      case CoachTemplate.pressureYouLead:
        return coachPressureYouLead;
      case CoachTemplate.urgentLastChance:
        return coachUrgentLastChance(d.hoursLeft ?? 1, d.streak);
      case CoachTemplate.urgentSmallestVersion:
        return coachUrgentSmallestVersion;
      case CoachTemplate.celebrateWeek:
        return coachCelebrateWeek;
      case CoachTemplate.celebrateMonth:
        return coachCelebrateMonth;
      case CoachTemplate.celebrateHabitFormed:
        return coachCelebrateHabitFormed;
      case CoachTemplate.celebrateHundred:
        // The tier you are moving *into*, not the one you just finished.
        return coachCelebrateHundred(tierName(tierForCycle(d.cycleIndex + 1)));
      case CoachTemplate.celebrateYear:
        return coachCelebrateYear;
      case CoachTemplate.celebrateGeneric:
        return coachCelebrateGeneric(d.milestoneDay ?? d.dayNumber);
      case CoachTemplate.recoverStreakLost:
        return coachRecoverStreakLost;
      case CoachTemplate.recoverRelapse:
        return coachRecoverRelapse(
          habitTitle(d.habitCategory ?? HabitCategory.custom),
          recoveryHintText(d.recoveryHint ?? RecoveryHint.smallestVersion),
        );
      case CoachTemplate.raiseBarHarderTarget:
        return coachRaiseBarHarder(d.completionPercent);
      case CoachTemplate.raiseBarNoEffortNoGain:
        return coachRaiseBarNoEffort(d.completionPercent);
      case CoachTemplate.raiseBarSecondFront:
        return coachRaiseBarSecondFront(d.completionPercent);
    }
  }

  /// "🐺 Marcel, 🦊 Lisa and 4 others", in the local joining style.
  String peerNames(CoachDirective d) {
    final List<String> names = d.peers
        .map((PeerMention p) => '${p.avatarEmoji} ${p.displayName}')
        .toList();
    if (names.isEmpty) return '';
    if (d.extraPeerCount > 0) {
      return coachNamesMore(names.join(', '), d.extraPeerCount);
    }
    if (names.length == 1) return names.first;
    return coachNamesTwo(
      names.sublist(0, names.length - 1).join(', '),
      names.last,
    );
  }

  String recoveryHintText(RecoveryHint hint) {
    switch (hint) {
      case RecoveryHint.digitalTrigger:
        return coachHintDigitalTrigger;
      case RecoveryHint.alcoholPattern:
        return coachHintAlcoholPattern;
      case RecoveryHint.sugarBreakfast:
        return coachHintSugarBreakfast;
      case RecoveryHint.smallestVersion:
        return coachHintSmallestVersion;
    }
  }

  String ctaLabel(CoachCta cta) {
    switch (cta) {
      case CoachCta.checkInNow:
        return ctaCheckInNow;
      case CoachCta.keepGoing:
        return ctaKeepGoing;
      case CoachCta.rescue:
        return ctaRescue;
      case CoachCta.share:
        return ctaShare;
      case CoachCta.restart:
        return ctaRestart;
      case CoachCta.adjustGoal:
        return ctaAdjustGoal;
    }
  }

  String nudgeText(NudgeSuggestion nudge) {
    switch (nudge.template) {
      case NudgeTemplate.iWentDidYou:
        return nudgeIWentDidYou;
      case NudgeTemplate.yourStreakIsWatching:
        return nudgeStreakWatching(nudge.dayNumber);
      case NudgeTemplate.youWereInForDays:
        return nudgeYouWereInForDays(nudge.peerStreak);
      case NudgeTemplate.noPressureButISeeYourFeed:
        return nudgeNoPressure;
      case NudgeTemplate.freeform:
        return nudge.text ?? nudgeIWentDidYou;
    }
  }

  String nudgeReasonText(NudgeReason reason) {
    switch (reason) {
      case NudgeReason.inactiveTwoDays:
        return nudgeReasonInactive;
      case NudgeReason.nothingToday:
        return nudgeReasonNothingToday;
    }
  }

  String adviceText(PlanAdvice advice) {
    final String emoji = advice.habitCategory == null
        ? ''
        : habitDefinition(advice.habitCategory!).emoji;
    final String habit = advice.habitCategory == null
        ? ''
        : habitTitle(advice.habitCategory!);
    switch (advice.kind) {
      case PlanAdviceKind.cutScope:
        return adviceCutScope(advice.completionPercent ?? 0);
      case PlanAdviceKind.milestoneAhead:
        return adviceMilestoneAhead(
          emoji,
          habit,
          advice.daysToMilestone ?? 0,
          _milestoneNameFromId(advice.milestone),
        );
      case PlanAdviceKind.raiseTarget:
        return adviceRaiseTarget(emoji, habit, advice.streak ?? 0);
      case PlanAdviceKind.halveTarget:
        return adviceHalveTarget(emoji, habit);
      case PlanAdviceKind.inviteSomeone:
        return adviceInviteSomeone;
      case PlanAdviceKind.freeform:
        return advice.text ?? '';
    }
  }

  String _milestoneNameFromId(String? id) {
    if (id == null) return '';
    final parts = id.split('_');
    if (parts.length != 2) return '';
    final track = AbstinenceTrack.values
        .where((AbstinenceTrack t) => t.name == parts[0])
        .firstOrNull;
    final day = int.tryParse(parts[1]);
    if (track == null || day == null) return '';
    return milestoneTitle(AbstinenceMilestone(track: track, day: day));
  }
}
