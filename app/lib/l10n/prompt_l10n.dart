import 'package:hundred_core/hundred_core.dart';

import 'core_l10n.dart';
import 'generated/app_localizations.dart';

/// Builds the on-device model's prompts in the language the user reads.
///
/// Asking a model for German output from an English prompt works badly, so the
/// prompt itself has to be localized — which is why the core package exposes
/// this as a port instead of hardcoding either language.
class LocalizedCoachPrompts implements CoachPromptBuilder {
  const LocalizedCoachPrompts(this.l10n);

  final AppLocalizations l10n;

  @override
  String briefing(CoachContext c, CoachTone tone) {
    final String habits = c.challenge.habits
        .map((Habit h) => l10n.promptHabitLine(
              h.emoji,
              l10n.habitLabel(h),
              c.habitStreaks[h.id] ?? 0,
              h.kind == HabitKind.abstain
                  ? l10n.promptUnitClean
                  : l10n.promptUnitStreak,
            ))
        .join('\n');

    final String peers = c.peers.isEmpty
        ? l10n.promptNoFriends
        : c.peers
            .take(5)
            .map((PeerState p) => l10n.promptPeerLine(
                  p.profile.displayName,
                  p.currentStreak,
                  p.activeToday
                      ? l10n.promptPeerActive
                      : l10n.promptPeerInactive,
                ))
            .join('\n');

    return l10n.promptBriefing(
      _persona(tone),
      c.challenge.goal.statement,
      c.dayNumber,
      c.challenge.lengthDays,
      l10n.tierName(c.challenge.tier),
      c.streak.current,
      c.streak.longest,
      c.streak.doneToday ? l10n.promptYes : l10n.promptNo,
      '${c.now.hour}',
      habits,
      peers,
    );
  }

  @override
  String nudge(CoachContext c, PeerState peer) => l10n.promptNudge(
        peer.profile.displayName,
        c.dayNumber,
        c.streak.current,
      );

  @override
  String adjustments(CoachContext c) {
    final String habits = c.challenge.habits
        .map((Habit h) => l10n.promptAdjustHabitLine(
              l10n.habitLabel(h),
              '${h.target}',
              h.daysPerWeek,
              c.habitStreaks[h.id] ?? 0,
            ))
        .join('\n');
    return l10n.promptAdjustments(
      c.dayNumber,
      c.challenge.lengthDays,
      c.completionPercent,
      c.challenge.goal.statement,
      habits,
    );
  }

  String _persona(CoachTone tone) {
    switch (tone) {
      case CoachTone.recover:
        return l10n.promptPersonaRecover;
      case CoachTone.celebrate:
        return l10n.promptPersonaCelebrate;
      case CoachTone.urgent:
      case CoachTone.socialPressure:
        return l10n.promptPersonaDirect;
      case CoachTone.raiseTheBar:
        return l10n.promptPersonaDemanding;
      case CoachTone.welcome:
      case CoachTone.steady:
        return l10n.promptPersonaCalm;
    }
  }
}
