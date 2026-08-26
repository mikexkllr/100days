import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../../l10n/l10n.dart';
import '../../../state/onboarding_state.dart';
import '../../../theme/theme.dart';
import '../../widgets/app_card.dart';
import '../onboarding_flow.dart';

/// Step one, and the reason the app can generate anything at all.
class GoalStep extends ConsumerWidget {
  const GoalStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final draft = ref.watch(onboardingProvider);

    return OnboardingScaffold(
      eyebrow: l10n.obStep1,
      title: l10n.obGoalTitle,
      subtitle: l10n.obGoalSubtitle,
      child: Column(
        children: <Widget>[
          for (final GoalArchetypeInfo info in kGoalCatalog.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
              child: _GoalCard(
                info: info,
                selected: draft.archetype == info.archetype,
                onTap: () => ref
                    .read(onboardingProvider.notifier)
                    .chooseArchetype(info.archetype),
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final GoalArchetypeInfo info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCard(
      onTap: onTap,
      border: selected ? AppColors.flame : null,
      color: selected
          ? AppColors.flame.withValues(alpha: 0.08)
          : AppColors.surface,
      child: Row(
        children: <Widget>[
          Text(info.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.goalTitle(info.archetype),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.goalPitch(info.archetype),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.flame : Colors.transparent,
              border: Border.all(
                color: selected ? AppColors.flame : AppColors.outline,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, size: 14, color: Color(0xFF1A0A02))
                : null,
          ),
        ],
      ),
    );
  }
}
