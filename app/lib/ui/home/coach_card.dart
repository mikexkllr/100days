import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../ai/funki/funki.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../funki/funki_widgets.dart';
import '../mascot/flame_mascot.dart';
import '../widgets/app_card.dart';

/// Funki, the coach, on Today: his line for right now — the rule-based one
/// at once, the model's when it arrives — and, right under it, the way to
/// answer him.
class CoachCard extends ConsumerWidget {
  const CoachCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    // The rule-based line shows at once; the model's version replaces it
    // when (and if) it arrives.
    final CoachDirective? upgraded =
        ref.watch(modelBriefingProvider).valueOrNull;
    final AsyncValue<CoachDirective?> base = ref.watch(briefingProvider);
    final AsyncValue<CoachDirective?> briefing = upgraded != null
        ? AsyncValue<CoachDirective?>.data(upgraded)
        : base;

    final DayKey? today = ref.watch(appStateProvider).valueOrNull?.today;

    return briefing.when(
      loading: () => const _CoachSkeleton(),
      error: (Object _, StackTrace __) => const SizedBox.shrink(),
      data: (CoachDirective? directive) {
        if (directive == null) return const SizedBox.shrink();
        final Color accent = _accentFor(directive.tone);
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FunkiAvatar(size: 52, mood: _moodFor(directive.tone)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(_iconFor(directive.tone),
                                size: 15, color: accent),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                l10n.coachHeadline(directive),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (directive.source == CoachSource.llm)
                              Pill(l10n.coachBadgeLlm,
                                  color: AppColors.textTertiary),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        // Said once: the same line is not typed out again
                        // every time Today is rebuilt.
                        FunkiSpeech(
                          l10n.coachBody(directive),
                          key: ValueKey<String>(l10n.coachBody(directive)),
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 15,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (today != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                FunkiAskButton(
                  key: const Key('funki-ask'),
                  focus: FunkiFocus.home(today),
                  label: l10n.funkiAnswerHint,
                  filled: true,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _accentFor(CoachTone tone) {
    switch (tone) {
      case CoachTone.urgent:
        return AppColors.danger;
      case CoachTone.socialPressure:
        return AppColors.social;
      case CoachTone.celebrate:
        return AppColors.success;
      case CoachTone.recover:
        return AppColors.cool;
      case CoachTone.raiseTheBar:
        return AppColors.success;
      case CoachTone.welcome:
      case CoachTone.steady:
        return AppColors.reward;
    }
  }

  /// How he looks while he says it.
  MascotMood _moodFor(CoachTone tone) {
    switch (tone) {
      case CoachTone.urgent:
        return MascotMood.worried;
      case CoachTone.socialPressure:
        return MascotMood.hungry;
      case CoachTone.celebrate:
      case CoachTone.raiseTheBar:
        return MascotMood.hyped;
      case CoachTone.recover:
      case CoachTone.welcome:
        return MascotMood.hopeful;
      case CoachTone.steady:
        return MascotMood.happy;
    }
  }

  IconData _iconFor(CoachTone tone) {
    switch (tone) {
      case CoachTone.urgent:
        return Icons.timer_outlined;
      case CoachTone.socialPressure:
        return Icons.visibility_outlined;
      case CoachTone.celebrate:
        return Icons.emoji_events_outlined;
      case CoachTone.recover:
        return Icons.restart_alt;
      case CoachTone.raiseTheBar:
        return Icons.trending_up;
      case CoachTone.welcome:
      case CoachTone.steady:
        return Icons.bolt_outlined;
    }
  }
}

class _CoachSkeleton extends StatelessWidget {
  const _CoachSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: SizedBox(
        height: 56,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
