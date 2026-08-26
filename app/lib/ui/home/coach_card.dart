import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// The coach's line for right now, produced entirely on this device.
class CoachCard extends ConsumerWidget {
  const CoachCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<CoachDirective?> briefing = ref.watch(briefingProvider);

    return briefing.when(
      loading: () => const _CoachSkeleton(),
      error: (Object _, StackTrace __) => const SizedBox.shrink(),
      data: (CoachDirective? directive) {
        if (directive == null) return const SizedBox.shrink();
        final Color accent = _accentFor(directive.tone);
        return AppCard(
          border: accent.withValues(alpha: 0.45),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              accent.withValues(alpha: 0.14),
              AppColors.surface,
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(_iconFor(directive.tone), size: 17, color: accent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.coachHeadline(directive),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: accent),
                    ),
                  ),
                  Pill(
                    directive.source == CoachSource.llm
                        ? l10n.coachBadgeLlm
                        : l10n.coachBadgeRule,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.coachBody(directive),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
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
        return AppColors.violet;
      case CoachTone.celebrate:
        return AppColors.lime;
      case CoachTone.recover:
        return AppColors.flameSoft;
      case CoachTone.raiseTheBar:
        return AppColors.lime;
      case CoachTone.welcome:
      case CoachTone.steady:
        return AppColors.flame;
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
