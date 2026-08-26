import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../../l10n/l10n.dart';
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
    final AppLocalizations l10n = context.l10n;
    final draft = ref.watch(onboardingProvider);
    if (!draft.isReady) {
      return OnboardingScaffold(
        title: l10n.obSummaryAlmostDone,
        subtitle: l10n.obSummaryMissing,
        child: const SizedBox.shrink(),
      );
    }

    final challenge = draft.toChallenge();
    final plan = buildPlan(challenge);
    final firstWeek = plan.training?.weeks.first;

    return OnboardingScaffold(
      eyebrow: l10n.obSummaryEyebrow,
      title: l10n.obSummaryTitle(draft.lengthDays),
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
                        l10n.obSummaryDayOne(
                          goalInfo(draft.archetype!).emoji,
                          l10n.goalTitle(draft.archetype!),
                          draft.lengthDays,
                        ),
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
          SectionHeader(l10n.obSummaryDailySection),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final Habit habit in challenge.habits)
                Chip(
                  avatar: Text(habit.emoji),
                  label: Text(
                    '${l10n.habitLabel(habit)} · ${l10n.formatTarget(habit)}',
                  ),
                ),
            ],
          ),
          if (plan.hasNutrition) ...<Widget>[
            SectionHeader(l10n.obSummaryNutritionSection),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: StatTile(
                          value: '${plan.nutrition!.kcal}',
                          label: l10n.planKcalPerDayShort,
                          color: AppColors.flame,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${plan.nutrition!.proteinG} g',
                          label: l10n.planProtein,
                          color: AppColors.lime,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${plan.nutrition!.carbsG} g',
                          label: l10n.planCarbsShort,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${plan.nutrition!.fatG} g',
                          label: l10n.planFat,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.nutritionRationale(plan.nutrition!),
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
              l10n.obSummaryTrainingSection,
              subtitle: l10n.splitName(plan.training!.split),
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
                              l10n.weekdayShort(workout.weekday),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppColors.flame),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              l10n.workoutName(workout.kind),
                              style:
                                  Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            l10n.obSetsAndMinutes(
                                workout.totalSets, workout.estimatedMinutes),
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
                    l10n.trainingPlanRationale(plan.training!),
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
                    l10n.obSummaryFriendsNote,
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
}
