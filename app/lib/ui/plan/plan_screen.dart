import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../mealplan/shopping_view.dart';
import '../mealplan/week_plan_view.dart';
import '../nutrition/diary_view.dart';
import '../nutrition/nutrition_goals_screen.dart';
import '../widgets/app_card.dart';
import 'training_editor.dart';
import 'workout_detail.dart';

/// Training, nutrition and abstinence milestones — whatever the goal produced.
///
/// Every tab is something the user acts on: edit the plan, log a session,
/// log a meal. There is no tab of advice to read and nothing to do with.
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
        final List<_Tab> tabs = <_Tab>[
          if (has(HabitCategory.gym) || has(HabitCategory.cardio))
            _Tab(
              l10n.planTabTraining,
              snapshot.plan?.training != null
                  ? _TrainingTab(snapshot: snapshot)
                  : _EnablePlanCard(
                      emoji: '🏋️',
                      title: l10n.planEnableTraining,
                      body: l10n.planEnableTrainingBody(
                          ((kTrackedMultiplier - 1) * 100).round()),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              TrainingEditorScreen(
                                  challenge: snapshot.challenge!),
                        ),
                      ),
                    ),
            ),
          if (has(HabitCategory.nutrition))
            _Tab(
              l10n.planTabNutrition,
              snapshot.plan?.nutrition != null
                  ? NutritionDiaryView(snapshot: snapshot)
                  : _EnablePlanCard(
                      emoji: '🥗',
                      title: l10n.planEnableNutrition,
                      body: l10n.planEnableNutritionBody(
                          ((kTrackedMultiplier - 1) * 100).round()),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              NutritionGoalsScreen(
                                  challenge: snapshot.challenge!),
                        ),
                      ),
                    ),
            ),
          // The household's meals and shopping: for everyone, whatever the
          // habits — a week of dinners helps a reading streak too.
          _Tab(l10n.planTabMeals, const WeekPlanView()),
          _Tab(l10n.planTabShopping, const ShoppingView()),
          if (habits.any((Habit h) => h.kind == HabitKind.abstain))
            _Tab(l10n.planTabAbstinence, _AbstinenceTab(snapshot: snapshot)),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Column(
            children: <Widget>[
              PlanTabBar(
                labels: <String>[for (final _Tab tab in tabs) tab.label],
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

/// The plan's sub-tabs, fitted to the width they get.
///
/// Up to five tabs share a phone's width. Spread evenly they cut the last
/// label off at the edge ("Clean bleit"), which reads as a bug rather than
/// as more to scroll to. So the labels are measured at the user's text
/// size: when they fit, the spare room goes into the padding and every tab
/// is whole; when they do not — large system text — the bar scrolls and
/// fades out at the edge where more tabs wait.
class PlanTabBar extends StatefulWidget {
  const PlanTabBar({super.key, required this.labels});

  final List<String> labels;

  @override
  State<PlanTabBar> createState() => _PlanTabBarState();
}

class _PlanTabBarState extends State<PlanTabBar> {
  /// What [GlassTabBar] puts around the tabs: its side padding, the
  /// track's inset and its hairline.
  static const double _frame = 2 * AppSpacing.md + 2 * 4 + 2 * 1;

  /// Less than this beside a label and the selected pill hugs the text.
  static const double _minPadding = 6;
  static const double _scrollPadding = 12;
  static const double _fade = 28;

  bool _moreBefore = false;
  bool _moreAfter = true;

  double _labelWidth(String label, TabBarThemeData theme, TextScaler scaler) {
    double widest = 0;
    // Selected labels are bolder; leave room for either.
    for (final TextStyle? style in <TextStyle?>[
      theme.labelStyle,
      theme.unselectedLabelStyle,
    ]) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return widest;
  }

  bool _onScroll(ScrollMetrics metrics) {
    final bool before = metrics.extentBefore > 0.5;
    final bool after = metrics.extentAfter > 0.5;
    if (before != _moreBefore || after != _moreAfter) {
      setState(() {
        _moreBefore = before;
        _moreAfter = after;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final TabBarThemeData theme = TabBarTheme.of(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double room = constraints.maxWidth - _frame;
        final double text = widget.labels.fold(
            0.0,
            (double sum, String label) =>
                sum + _labelWidth(label, theme, scaler));
        // A pixel to spare, so rounding never tips it into scrolling.
        final double padding =
            ((room - text - 1) / (2 * widget.labels.length)).floorToDouble();
        final bool fits = padding >= _minPadding;
        final Widget bar = GlassTabBar(
          key: const Key('plan-tabs'),
          isScrollable: true,
          labelPadding: EdgeInsets.symmetric(
              horizontal: fits ? padding : _scrollPadding),
          tabs: <Widget>[
            for (final String label in widget.labels) Tab(text: label),
          ],
        );
        if (fits) return bar;
        return NotificationListener<ScrollMetricsNotification>(
          onNotification: (ScrollMetricsNotification n) =>
              _onScroll(n.metrics),
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification n) => _onScroll(n.metrics),
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (Rect bounds) {
                final double inset = AppSpacing.md / bounds.width;
                final double fade = _fade / bounds.width;
                return LinearGradient(
                  colors: <Color>[
                    _moreBefore ? Colors.transparent : Colors.white,
                    Colors.white,
                    Colors.white,
                    _moreAfter ? Colors.transparent : Colors.white,
                  ],
                  stops: <double>[
                    inset,
                    inset + fade,
                    1 - inset - fade,
                    1 - inset,
                  ],
                ).createShader(bounds);
              },
              child: bar,
            ),
          ),
        );
      },
    );
  }
}

class _TrainingTab extends StatelessWidget {
  const _TrainingTab({required this.snapshot});

  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TrainingPlan plan = snapshot.plan!.training!;
    final Challenge challenge = snapshot.challenge!;
    final DayKey today = snapshot.today;
    final int current = plan.weekNumberFor(challenge.startDay, today);

    // The weeks of the cycle the user is in: 1–15 for the first 100 days,
    // then on from there — the plan does not start over.
    final DayKey cycleStart = challenge.startDay
        .addDays(challenge.cycleOf(today) * challenge.lengthDays);
    final int first = plan.weekNumberFor(challenge.startDay, cycleStart);
    final int last = plan.weekNumberFor(
      challenge.startDay,
      cycleStart.addDays(challenge.lengthDays - 1),
    );

    // Opens on the current week rather than on week 1: the list is centred
    // on it, with the weeks before (and the plan's header) above.
    const Key currentWeek = Key('plan-current-week');
    const EdgeInsets sides = EdgeInsets.symmetric(horizontal: AppSpacing.md);
    return CustomScrollView(
      center: current > first ? currentWeek : null,
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          sliver: SliverToBoxAdapter(
            child: AppCard(
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
          ),
        ),
        for (final TrainingWeek week in plan.weeksBetween(first, last))
          SliverPadding(
            key: week.weekNumber == current ? currentWeek : null,
            padding: sides,
            sliver: SliverToBoxAdapter(
              child: _WeekSection(
                week: week,
                isCurrent: week.weekNumber == current,
              ),
            ),
          ),
        // The dock floats over the end of the list.
        SliverToBoxAdapter(
          child: SizedBox(
              height: AppSpacing.lg + MediaQuery.paddingOf(context).bottom),
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

/// Offered where an optional plan is switched off: what it adds, and what
/// it is worth.
class _EnablePlanCard extends StatelessWidget {
  const _EnablePlanCard({
    required this.emoji,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        AppCard(
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
        ),
      ],
    );
  }
}
