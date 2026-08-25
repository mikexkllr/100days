import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../../state/onboarding_state.dart';
import '../../../theme/theme.dart';
import '../../widgets/app_card.dart';
import '../onboarding_flow.dart';

/// The generated plan, shown before the user commits to it.
///
/// Generated on device, deterministically, from the answers above — the user
/// sees exactly what they are signing up for rather than a promise that a plan
/// will appear later.
class SummaryStep extends ConsumerWidget {
  const SummaryStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingProvider);
    if (!draft.isReady) {
      return const OnboardingScaffold(
        title: 'Fast fertig',
        subtitle: 'Ein paar Angaben fehlen noch.',
        child: SizedBox.shrink(),
      );
    }

    final challenge = draft.toChallenge();
    final plan = buildPlan(challenge);
    final firstWeek = plan.training?.weeks.first;

    return OnboardingScaffold(
      eyebrow: 'Dein Plan',
      title: '${draft.lengthDays} Tage, ab heute.',
      subtitle: '"${draft.statement.trim()}"',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppCard(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.flame.withValues(alpha: 0.18),
                AppColors.surface,
              ],
            ),
            border: AppColors.flame.withValues(alpha: 0.4),
            child: Row(
              children: <Widget>[
                EmojiAvatar(draft.avatarEmoji, size: 48),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(draft.displayName.trim(),
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        '${goalInfo(draft.archetype!).emoji} '
                        '${goalInfo(draft.archetype!).titleDe} · '
                        'Tag 1 von ${draft.lengthDays}',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Das zählt täglich'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final Habit habit in challenge.habits)
                Chip(
                  avatar: Text(habit.emoji),
                  label: Text(
                    '${habit.displayTitle} · ${formatHabitTarget(habit)}',
                  ),
                ),
            ],
          ),
          if (plan.hasNutrition) ...<Widget>[
            const SectionHeader('Ernährungsplan'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: StatTile(
                          value: '${plan.nutrition!.kcal}',
                          label: 'kcal / Tag',
                          color: AppColors.flame,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${plan.nutrition!.proteinG} g',
                          label: 'Protein',
                          color: AppColors.lime,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${plan.nutrition!.carbsG} g',
                          label: 'Carbs',
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${plan.nutrition!.fatG} g',
                          label: 'Fett',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    plan.nutrition!.rationaleDe,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                  ),
                ],
              ),
            ),
          ],
          if (firstWeek != null) ...<Widget>[
            SectionHeader(
              'Trainingsplan',
              subtitle: plan.training!.splitNameDe,
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final Workout workout in firstWeek.workouts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 34,
                            child: Text(
                              _weekdayShort(workout.weekday),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppColors.flame),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              workout.nameDe,
                              style:
                                  Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            '${workout.totalSets} Sätze · '
                            '${workout.estimatedMinutes} Min',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 12,
                                ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: AppSpacing.lg),
                  Text(
                    plan.training!.rationaleDe,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            color: AppColors.surfaceHigh,
            child: Row(
              children: <Widget>[
                const Text('👥', style: TextStyle(fontSize: 20)),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Text(
                    'Danach: Freunde verbinden. Allein hält es kaum jemand '
                    '100 Tage durch — mit Publikum schon.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayShort(int weekday) => const <String>[
        'MO', 'DI', 'MI', 'DO', 'FR', 'SA', 'SO'
      ][(weekday - 1).clamp(0, 6)];
}
