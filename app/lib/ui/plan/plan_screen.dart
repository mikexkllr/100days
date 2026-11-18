import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../mealplan/shopping_view.dart';
import '../mealplan/week_plan_view.dart';
import '../nutrition/nutrition_goals_screen.dart';
import '../widgets/app_card.dart';
import 'training_editor.dart';
import 'workout_detail.dart';

/// What lies ahead: the training plan, the week of meals with the nutrition
/// target it is portioned for, the shopping list, the abstinence milestones.
///
/// Every tab is something the user acts on — there is no tab of advice to
/// read and nothing to do with. What was done is checked in under Today:
/// the habits, today's workout and the food diary.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppSnapshot> async = ref.watch(appStateProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) => Center(child: Text('$error')),
      data: (AppSnapshot snapshot) {
        final AppLocalizations l10n = context.l10n;
        final List<Habit> habits = snapshot.challenge!.habits;
        bool has(HabitCategory c) => habits.any((Habit h) => h.category == c);
        final Challenge challenge = snapshot.challenge!;
        void openGoals() => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    NutritionGoalsScreen(challenge: challenge),
              ),
            );
        final NutritionPlan? nutrition = snapshot.plan?.nutrition;
        final List<_Tab> tabs = <_Tab>[
          if (has(HabitCategory.gym) || has(HabitCategory.cardio))
            _Tab(
              l10n.planTabTraining,
              snapshot.plan?.training != null
                  ? _TrainingTab(snapshot: snapshot)
                  : _CardList(
                      child: _EnablePlanCard(
                        emoji: '🏋️',
                        title: l10n.planEnableTraining,
                        body: l10n.planEnableTrainingBody(
                            ((kTrackedMultiplier - 1) * 100).round()),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                TrainingEditorScreen(challenge: challenge),
                          ),
                        ),
                      ),
                    ),
            ),
          // The household's meals and shopping: for everyone, whatever the
          // habits — a week of dinners helps a reading streak too. The
          // nutrition target sits on top of the meals it portions.
          _Tab(
            l10n.planTabMeals,
            WeekPlanView(
              leading: nutrition != null
                  ? _NutritionTargetCard(plan: nutrition, onTap: openGoals)
                  : has(HabitCategory.nutrition)
                      ? _EnablePlanCard(
                          key: const Key('enable-nutrition'),
                          emoji: '🥗',
                          title: l10n.planEnableNutrition,
                          body: l10n.planEnableNutritionBody(
                              ((kTrackedMultiplier - 1) * 100).round()),
                          onTap: openGoals,
                          compact: true,
                        )
                      : null,
            ),
          ),
          _Tab(l10n.planTabShopping, const ShoppingView()),
          if (habits.any((Habit h) => h.kind == HabitKind.abstain))
            _Tab(l10n.planTabAbstinence, _AbstinenceTab(snapshot: snapshot)),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Column(
            children: <Widget>[
              GlassTabBar(
                isScrollable: true,
                tabs: <Widget>[
                  for (final _Tab tab in tabs) Tab(text: tab.label),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    for (final _Tab tab in tabs) tab.child,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tab {
  const _Tab(this.label, this.child);
  final String label;
  final Widget child;
}

class _TrainingTab extends StatelessWidget {
  const _TrainingTab({required this.snapshot});

  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TrainingPlan plan = snapshot.plan!.training!;
    final Challenge challenge = snapshot.challenge!;
    final TrainingWeek currentWeek =
        plan.weekFor(challenge.startDay, snapshot.today);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        // The dock floats over the end of the list.
        AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        AppCard(
          color: AppColors.surfaceHigh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.splitName(plan.split),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.trainingPlanRationale(plan),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('edit-training-plan'),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        TrainingEditorScreen(challenge: challenge),
                  ),
                ),
                icon: const Icon(Icons.edit, size: 18),
                label: Text(l10n.planEditTraining),
              ),
            ],
          ),
        ),
        for (final TrainingWeek week in plan.weeks)
          _WeekSection(
            week: week,
            isCurrent: week.weekNumber == currentWeek.weekNumber,
          ),
      ],
    );
  }
}

class _WeekSection extends StatelessWidget {
  const _WeekSection({required this.week, required this.isCurrent});

  final TrainingWeek week;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          l10n.planWeekNumber(week.weekNumber),
          subtitle: l10n.trainingPhase(week),
          action: isCurrent
              ? Pill(l10n.planCurrentBadge,
                  color: AppColors.primary, filled: true)
              : week.isDeload
                  ? Pill(l10n.planDeloadBadge, color: AppColors.social)
                  : null,
        ),
        for (final Workout workout in week.workouts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      WorkoutDetailScreen(workout: workout),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 4,
              ),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 34,
                    child: Text(
                      l10n.weekdayShort(workout.weekday),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l10n.workoutName(workout.kind),
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          l10n.planWorkoutSummary(
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
                  const Icon(Icons.chevron_right,
                      color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AbstinenceTab extends StatelessWidget {
  const _AbstinenceTab({required this.snapshot});

  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final List<Habit> habits = snapshot.challenge!.habits
        .where((Habit h) => h.kind == HabitKind.abstain)
        .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        // The dock floats over the end of the list.
        AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        for (final Habit habit in habits)
          _MilestoneTrack(
            habit: habit,
            streak: snapshot.me.habitStreaks[habit.id] ?? 0,
          ),
      ],
    );
  }
}

class _MilestoneTrack extends StatelessWidget {
  const _MilestoneTrack({required this.habit, required this.streak});

  final Habit habit;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AbstinenceMilestone> milestones = milestonesFor(habit.category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          '${habit.emoji} ${l10n.habitLabel(habit)}',
          subtitle: l10n.planCleanDays(streak),
        ),
        for (final AbstinenceMilestone milestone in milestones)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              color: milestone.day <= streak
                  ? AppColors.success.withValues(alpha: 0.07)
                  : AppColors.surface,
              border: milestone.day <= streak
                  ? AppColors.success.withValues(alpha: 0.5)
                  : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    milestone.day <= streak
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 19,
                    color: milestone.day <= streak
                        ? AppColors.success
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l10n.milestoneTitle(milestone),
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          l10n.milestoneBody(milestone),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A tab that is only one card.
class _CardList extends StatelessWidget {
  const _CardList({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[child],
    );
  }
}

/// The nutrition plan's daily target, above the meals it portions. Changing
/// it is one tap; eating against it happens in the diary under Today.
class _NutritionTargetCard extends StatelessWidget {
  const _NutritionTargetCard({required this.plan, required this.onTap});

  final NutritionPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    return AppCard(
      key: const Key('nutrition-target'),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: Row(
        children: <Widget>[
          const Text('🥗', style: TextStyle(fontSize: 24)),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.planNutritionTarget, style: text.titleMedium),
                Text(
                  l10n.planNutritionTargetLine(
                      plan.kcal, plan.proteinG, plan.carbsG, plan.fatG),
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: l10n.goalsTitle,
            child: const Icon(Icons.tune, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Offered where an optional plan is switched off: what it adds, and what
/// it is worth. [compact] where it sits above something else that is the
/// point of the tab.
class _EnablePlanCard extends StatelessWidget {
  const _EnablePlanCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.body,
    required this.onTap,
    this.compact = false,
  });

  final String emoji;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return AppCard(
        border: AppColors.success.withValues(alpha: 0.5),
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Row(
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppColors.success),
                  ),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.success),
          ],
        ),
      );
    }
    return AppCard(
      border: AppColors.success.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.ink,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: onTap,
            child: Text(title),
          ),
        ],
      ),
    );
  }
}
