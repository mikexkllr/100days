import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'workout_detail.dart';

/// Training, nutrition and abstinence milestones — whatever the goal produced.
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
        final List<_Tab> tabs = <_Tab>[
          if (snapshot.plan?.training != null)
            _Tab(l10n.planTabTraining, _TrainingTab(snapshot: snapshot)),
          if (snapshot.plan?.nutrition != null)
            _Tab(l10n.planTabNutrition,
                _NutritionTab(plan: snapshot.plan!.nutrition!)),
          if (snapshot.challenge!.habits
              .any((Habit h) => h.kind == HabitKind.abstain))
            _Tab(l10n.planTabAbstinence, _AbstinenceTab(snapshot: snapshot)),
          _Tab(l10n.planTabAdjustments, const _AdjustmentsTab()),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Column(
            children: <Widget>[
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.flame,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.flame,
                dividerColor: AppColors.outline,
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
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
                  color: AppColors.flame, filled: true)
              : week.isDeload
                  ? Pill(l10n.planDeloadBadge, color: AppColors.violet)
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
                          ?.copyWith(color: AppColors.flame),
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

class _NutritionTab extends StatelessWidget {
  const _NutritionTab({required this.plan});

  final NutritionPlan plan;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        AppCard(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.flame.withValues(alpha: 0.16),
              AppColors.surface,
            ],
          ),
          border: AppColors.flame.withValues(alpha: 0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.planKcalPerDay(plan.kcal),
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.nutritionRationale(plan),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: StatTile(
                      value: '${plan.proteinG}g',
                      label: l10n.planProtein,
                      color: AppColors.lime,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                        value: '${plan.carbsG}g', label: l10n.planCarbs),
                  ),
                  Expanded(
                    child: StatTile(
                        value: '${plan.fatG}g', label: l10n.planFat),
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionHeader(l10n.planContext),
        AppCard(
          child: Column(
            children: <Widget>[
              _Row(label: l10n.planBmr, value: '${plan.bmr} kcal'),
              const Divider(height: AppSpacing.lg),
              _Row(label: l10n.planTdee, value: '${plan.tdee} kcal'),
              const Divider(height: AppSpacing.lg),
              _Row(
                label: l10n.planExpectedChange,
                value: l10n.planPerWeek(
                  '${plan.weeklyWeightChangeKg >= 0 ? '+' : ''}'
                  '${plan.weeklyWeightChangeKg.toStringAsFixed(2)}',
                ),
              ),
              const Divider(height: AppSpacing.lg),
              _Row(label: l10n.planFiber, value: '${plan.fiberG} g'),
              const Divider(height: AppSpacing.lg),
              _Row(
                label: l10n.planWater,
                value: '${(plan.waterMl / 1000).toStringAsFixed(1)} l',
              ),
            ],
          ),
        ),
        SectionHeader(l10n.planMeals),
        for (final MealSlot meal in plan.meals)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(l10n.mealName(meal.kind),
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      Pill(l10n.planMealMacros(meal.kcal, meal.proteinG)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final String idea in l10n.mealIdeas(meal.kind))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('· ',
                              style: TextStyle(color: AppColors.textTertiary)),
                          Expanded(
                            child: Text(
                              idea,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
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

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
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
                  ? AppColors.lime.withValues(alpha: 0.07)
                  : AppColors.surface,
              border: milestone.day <= streak
                  ? AppColors.lime.withValues(alpha: 0.5)
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
                        ? AppColors.lime
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

class _AdjustmentsTab extends ConsumerWidget {
  const _AdjustmentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<PlanAdvice>> tips =
        ref.watch(planAdjustmentsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        AppCard(
          color: AppColors.surfaceHigh,
          child: Row(
            children: <Widget>[
              const Icon(Icons.memory, size: 19, color: AppColors.violet),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  l10n.planAdjustmentsNote,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        tips.when(
          loading: () =>
              const Center(child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: CircularProgressIndicator(),
          )),
          error: (Object error, StackTrace _) => Text('$error'),
          data: (List<PlanAdvice> items) => Column(
            children: <Widget>[
              for (final PlanAdvice tip in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.arrow_forward,
                            size: 16, color: AppColors.flame),
                        const SizedBox(width: AppSpacing.sm + 2),
                        Expanded(
                          child: Text(l10n.adviceText(tip),
                              style: Theme.of(context).textTheme.bodyLarge),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
