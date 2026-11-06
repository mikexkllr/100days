import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'add_food_screen.dart';
import 'nutrition_goals_screen.dart';

/// The food diary as its own screen, for when it is opened from Today.
class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppSnapshot> async = ref.watch(appStateProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.diaryTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Center(child: Text('$error')),
        data: (AppSnapshot snapshot) => snapshot.plan?.nutrition == null
            ? const SizedBox.shrink()
            : NutritionDiaryView(snapshot: snapshot),
      ),
    );
  }
}

/// What was eaten against what was planned, one day at a time.
///
/// Built on the pattern every calorie counter uses: one number that matters
/// — what is left today — then the meals, each with its own add button. The
/// suggestions are only suggestions; nothing lands in the diary unless the
/// user puts it there.
class NutritionDiaryView extends ConsumerStatefulWidget {
  const NutritionDiaryView({super.key, required this.snapshot});

  final AppSnapshot snapshot;

  @override
  ConsumerState<NutritionDiaryView> createState() => _NutritionDiaryViewState();
}

class _NutritionDiaryViewState extends ConsumerState<NutritionDiaryView> {
  late DayKey _day = widget.snapshot.today;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppSnapshot snapshot = widget.snapshot;
    final NutritionPlan plan = snapshot.plan!.nutrition!;
    final DayIntake intake = snapshot.me.intakeOn(_day);
    final Nutrients eaten = intake.total;
    final bool isToday = _day == snapshot.today;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              onPressed: () => setState(() => _day = _day.addDays(-1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                isToday ? l10n.diaryToday : l10n.formatDay(_day),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: isToday
                  ? null
                  : () => setState(() => _day = _day.addDays(1)),
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: l10n.goalsTitle,
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => NutritionGoalsScreen(
                    challenge: snapshot.challenge!,
                  ),
                ),
              ),
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        _Summary(plan: plan, eaten: eaten),
        for (final MealSlot slot in plan.meals)
          _MealCard(
            slot: slot,
            day: _day,
            intake: intake,
            plan: plan,
          ),
        const SizedBox(height: AppSpacing.md),
        _CloseDay(snapshot: snapshot, day: _day, intake: intake, plan: plan),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.plan, required this.eaten});

  final NutritionPlan plan;
  final Nutrients eaten;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final int left = (plan.kcal - eaten.kcal).round();
    final double progress =
        plan.kcal <= 0 ? 0 : (eaten.kcal / plan.kcal).clamp(0, 1.2);
    final bool over = left < 0;

    return AppCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          AppColors.flame.withValues(alpha: 0.14),
          AppColors.surface,
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CircularProgressIndicator(
                      value: math.min(progress, 1),
                      strokeWidth: 9,
                      backgroundColor: AppColors.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          over ? AppColors.danger : AppColors.flame),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '${left.abs()}',
                            key: const Key('kcal-left'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            over ? l10n.diaryKcalOver : l10n.diaryKcalLeft,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.diaryEatenOfTarget(eaten.kcal.round(), plan.kcal),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _MacroBar(
                      label: l10n.planProtein,
                      eaten: eaten.proteinG,
                      target: plan.proteinG.toDouble(),
                      color: AppColors.lime,
                    ),
                    _MacroBar(
                      label: l10n.planCarbsShort,
                      eaten: eaten.carbsG,
                      target: plan.carbsG.toDouble(),
                      color: AppColors.flameSoft,
                    ),
                    _MacroBar(
                      label: l10n.planFat,
                      eaten: eaten.fatG,
                      target: plan.fatG.toDouble(),
                      color: AppColors.violet,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.eaten,
    required this.target,
    required this.color,
  });

  final String label;
  final double eaten;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
              Text(
                '${eaten.round()} / ${target.round()} g',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: AppRadius.pill,
            child: LinearProgressIndicator(
              value: target <= 0 ? 0 : (eaten / target).clamp(0, 1),
              minHeight: 5,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends ConsumerWidget {
  const _MealCard({
    required this.slot,
    required this.day,
    required this.intake,
    required this.plan,
  });

  final MealSlot slot;
  final DayKey day;
  final DayIntake intake;
  final NutritionPlan plan;

  Future<void> _add(BuildContext context, {String? prefill}) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => AddFoodScreen(
            meal: slot.kind,
            day: day,
            prefillText: prefill,
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<FoodEntry> entries = intake.entriesFor(slot.kind);
    final Nutrients mealTotal = intake.totalFor(slot.kind);
    final double dayLeft = plan.kcal - intake.total.kcal;
    final double slotLeft = math.min(slot.kcal - mealTotal.kcal, dayLeft);
    final List<MealIdea> ideas = entries.isEmpty
        ? suggestMeals(
            slot: slot.kind,
            targetKcal: slotLeft,
            targetProteinG: slot.proteinG.toDouble(),
          )
        : const <MealIdea>[];

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm + 2),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l10n.mealName(slot.kind),
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        l10n.diaryMealKcal(mealTotal.kcal.round(), slot.kcal),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  key: Key('add-food-${slot.kind.name}'),
                  onPressed: () => _add(context),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            for (final FoodEntry entry in entries)
              Dismissible(
                key: ValueKey<String>(entry.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  color: AppColors.danger.withValues(alpha: 0.2),
                  child: const Icon(Icons.delete_outline,
                      color: AppColors.danger),
                ),
                onDismissed: (_) =>
                    ref.read(appStateProvider.notifier).removeFood(entry.id),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(entry.name),
                  subtitle: Text(
                    '${entry.grams > 0 ? '${entry.grams.round()} g · ' : ''}'
                    '${l10n.foodSourceLabel(entry.source)}',
                  ),
                  trailing: Text(l10n.diaryEntryKcal(entry.nutrients.kcal.round())),
                ),
              ),
            if (ideas.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.diarySuggestions,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.textTertiary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final MealIdea idea in ideas)
                    ActionChip(
                      avatar: const Icon(Icons.lightbulb_outline, size: 16),
                      label: Text(
                        '${l10n.mealIdeaName(idea)} · ~${idea.kcal} kcal',
                      ),
                      onPressed: () =>
                          _add(context, prefill: l10n.mealIdeaName(idea)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Closing the day turns the diary into the nutrition check-in. On target,
/// it is a tracked check-in worth the plan bonus; off target the user can
/// still tick the habit, just without the bonus.
class _CloseDay extends ConsumerWidget {
  const _CloseDay({
    required this.snapshot,
    required this.day,
    required this.intake,
    required this.plan,
  });

  final AppSnapshot snapshot;
  final DayKey day;
  final DayIntake intake;
  final NutritionPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final Habit? habit = snapshot.challenge!.habits
        .where((Habit h) => h.category == HabitCategory.nutrition)
        .firstOrNull;
    if (habit == null) return const SizedBox.shrink();
    final CheckIn? entry =
        snapshot.me.logsByDay[day.toString()]?.entryFor(habit.id);
    final bool closed = entry != null && !entry.relapse;
    final bool onTarget = intake.isOnTarget(plan);

    if (closed) {
      return AppCard(
        color: AppColors.lime.withValues(alpha: 0.08),
        border: AppColors.lime.withValues(alpha: 0.5),
        child: Row(
          children: <Widget>[
            const Icon(Icons.check_circle, color: AppColors.lime),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Text(entry.tracked
                  ? l10n.diaryClosedTracked
                  : l10n.diaryClosedPlain),
            ),
          ],
        ),
      );
    }

    return FilledButton.icon(
      key: const Key('close-day'),
      onPressed: intake.isEmpty
          ? null
          : () async {
              if (!onTarget) {
                final bool? anyway = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: Text(l10n.diaryOffTargetTitle),
                    content: Text(l10n.diaryOffTargetBody(
                        (intake.total.kcal - plan.kcal).round())),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l10n.actionCancel),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(110, 44)),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(l10n.diaryOffTargetConfirm),
                      ),
                    ],
                  ),
                );
                if (anyway != true) return;
              }
              await ref.read(appStateProvider.notifier).checkIn(
                    habit,
                    day: day,
                    tracked: onTarget,
                  );
            },
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      icon: const Icon(Icons.task_alt),
      label: Text(onTarget ? l10n.diaryCloseOnTarget : l10n.diaryClose),
    );
  }
}
