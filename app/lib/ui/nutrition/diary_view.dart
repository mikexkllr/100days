import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/household_providers.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'add_food_screen.dart';
import 'nutrition_goals_screen.dart';

/// The food diary. It is opened from Today, because it is part of checking
/// the day in: what was eaten, and closing the day on it. What to eat and
/// what to buy are planned under Plan.
class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key, this.day});

  /// The day it opens on; today when null or not yet gone by.
  final DayKey? day;

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
            : NutritionDiaryView(snapshot: snapshot, initialDay: day),
      ),
    );
  }
}

/// What was eaten against the target, one day at a time.
///
/// Built on the pattern every calorie counter uses: one number that matters
/// — what is left today — then the meals, each with its own add button.
/// What the household planned for a meal waits next to it, one tap from
/// the diary — but nothing lands in it unless the user puts it there.
class NutritionDiaryView extends ConsumerStatefulWidget {
  const NutritionDiaryView({
    super.key,
    required this.snapshot,
    this.initialDay,
  });

  final AppSnapshot snapshot;

  /// A day gone by to open on, from the day sheet; null follows today.
  final DayKey? initialDay;

  @override
  ConsumerState<NutritionDiaryView> createState() => _NutritionDiaryViewState();
}

class _NutritionDiaryViewState extends ConsumerState<NutritionDiaryView> {
  /// The day the user went back to, or null to follow today — a diary left
  /// open overnight must log breakfast on the new day, not on yesterday.
  late DayKey? _picked = widget.initialDay;

  /// Lines swiped away and not yet gone from the snapshot. A dismissed
  /// row must leave the tree at once.
  final Set<String> _removing = <String>{};

  DayKey get _day {
    final DayKey today = widget.snapshot.today;
    final DayKey? picked = _picked;
    return picked == null || !picked.isBefore(today) ? today : picked;
  }

  void _go(int days) {
    final DayKey next = _day.addDays(days);
    setState(() => _picked =
        next.isBefore(widget.snapshot.today) ? next : null);
  }

  @override
  void didUpdateWidget(NutritionDiaryView old) {
    super.didUpdateWidget(old);
    _removing.removeWhere((String id) => !widget.snapshot.me.foodByDay.values
        .any((List<FoodEntry> day) => day.any((FoodEntry e) => e.id == id)));
  }

  /// Takes a line out — a `food.removed` in the feed — with the way back in
  /// the snackbar: the same line, logged again.
  Future<void> _remove(FoodEntry entry) async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppController diary = ref.read(appStateProvider.notifier);
    setState(() => _removing.add(entry.id));
    await diary.removeFood(entry.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.diaryEntryRemoved(entry.name)),
        // An undo is offered for a moment; with an action a snackbar
        // would otherwise stay until dismissed.
        persist: false,
        action: SnackBarAction(
          label: l10n.actionUndo,
          onPressed: () {
            if (mounted) setState(() => _removing.remove(entry.id));
            diary.logFood(entry);
          },
        ),
      ));
  }

  /// Puts amount and calories right: the line is logged again under its
  /// id, which replaces it.
  Future<void> _edit(FoodEntry entry) async {
    final AppController diary = ref.read(appStateProvider.notifier);
    final FoodCorrection? fix = await showFoodEditSheet(
      context,
      name: entry.name,
      grams: entry.grams,
      nutrients: entry.nutrients,
    );
    if (fix == null) return;
    await diary.logFood(entry.corrected(grams: fix.grams, kcal: fix.kcal));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    ref.watch(sharedTargetsSyncProvider);
    final AppSnapshot snapshot = widget.snapshot;
    final NutritionPlan plan = snapshot.plan!.nutrition!;
    final DayKey day = _day;
    final DayIntake all = snapshot.me.intakeOn(day);
    final DayIntake intake = DayIntake(
      day: day,
      entries: all.entries
          .where((FoodEntry e) => !_removing.contains(e.id))
          .toList(),
    );
    final Nutrients eaten = intake.total;
    final bool isToday = day == snapshot.today;
    final String me = ref.watch(repositoryProvider).userId;
    // The household's plan for the day, if it can be had: the diary works
    // without it, offline included.
    final List<PlanEntry> week =
        ref.watch(weekPlanProvider(day.weekStart)).valueOrNull ??
            const <PlanEntry>[];
    final Map<String, Recipe> recipes =
        ref.watch(recipesProvider).valueOrNull ?? const <String, Recipe>{};
    List<(PlanEntry, Recipe)> plannedFor(MealSlotKind slot) =>
        <(PlanEntry, Recipe)>[
          for (final PlanEntry entry in week)
            if (entry.day == day &&
                entry.slot == slot &&
                entry.portionFor(me) > 0)
              if (recipes[entry.recipeId] case final Recipe recipe)
                if (!eatenAsPlanned(intake, entry, recipe)) (entry, recipe),
        ];

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        // The dock floats over the end of the list.
        AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              key: const Key('diary-previous-day'),
              onPressed: () => _go(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                isToday ? l10n.diaryToday : l10n.formatDay(day),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: const Key('diary-next-day'),
              onPressed: isToday ? null : () => _go(1),
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
            day: day,
            intake: intake,
            planned: plannedFor(slot.kind),
            me: me,
            onRemove: _remove,
            onEdit: _edit,
          ),
        const SizedBox(height: AppSpacing.md),
        _CloseDay(snapshot: snapshot, day: day, intake: intake, plan: plan),
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
          AppColors.primary.withValues(alpha: 0.14),
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
                          over ? AppColors.danger : AppColors.primary),
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
                      color: AppColors.success,
                    ),
                    _MacroBar(
                      label: l10n.planCarbsShort,
                      eaten: eaten.carbsG,
                      target: plan.carbsG.toDouble(),
                      color: AppColors.primarySoft,
                    ),
                    _MacroBar(
                      label: l10n.planFat,
                      eaten: eaten.fatG,
                      target: plan.fatG.toDouble(),
                      color: AppColors.social,
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

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.slot,
    required this.day,
    required this.intake,
    required this.planned,
    required this.me,
    required this.onRemove,
    required this.onEdit,
  });

  final MealSlot slot;
  final DayKey day;
  final DayIntake intake;

  /// What the household planned for this meal and the user has not logged.
  final List<(PlanEntry, Recipe)> planned;
  final String me;
  final void Function(FoodEntry entry) onRemove;
  final void Function(FoodEntry entry) onEdit;

  Future<void> _add(BuildContext context) => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => AddFoodScreen(
            meal: slot.kind,
            day: day,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<FoodEntry> entries = intake.entriesFor(slot.kind);
    final Nutrients mealTotal = intake.totalFor(slot.kind);

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
                onDismissed: (_) => onRemove(entry),
                child: ListTile(
                  key: Key('diary-entry-${entry.id}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  onTap: () => onEdit(entry),
                  title: Text(entry.name),
                  subtitle: Text(
                    '${entry.grams > 0 ? '${entry.grams.round()} g · ' : ''}'
                    '${l10n.foodSourceLabel(entry.source)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(l10n.diaryEntryKcal(entry.nutrients.kcal.round())),
                      const SizedBox(width: AppSpacing.xs),
                      Tooltip(
                        message: l10n.foodEditTooltip,
                        child: const Icon(Icons.edit_outlined,
                            size: 16, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
            for (final (PlanEntry entry, Recipe recipe) in planned)
              _PlannedMeal(
                entry: entry,
                recipe: recipe,
                kcal: nutrientsFor(entry, recipe, me).kcal.round(),
              ),
          ],
        ),
      ),
    );
  }
}

/// A meal from the household's plan, not yet in the diary: the user's own
/// portion of it, one tap away.
class _PlannedMeal extends ConsumerStatefulWidget {
  const _PlannedMeal({
    required this.entry,
    required this.recipe,
    required this.kcal,
  });

  final PlanEntry entry;
  final Recipe recipe;
  final int kcal;

  @override
  ConsumerState<_PlannedMeal> createState() => _PlannedMealState();
}

class _PlannedMealState extends ConsumerState<_PlannedMeal> {
  /// A second tap before the diary has it would log the meal twice.
  bool _busy = false;

  Future<void> _eat() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(householdActionsProvider)
          .eatAsPlanned(widget.entry, widget.recipe);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardAll,
          border: Border.all(color: AppColors.social.withValues(alpha: 0.35)),
          color: AppColors.social.withValues(alpha: 0.06),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm + 4, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
          child: Row(
            children: <Widget>[
              const Icon(Icons.event_note_outlined,
                  size: 18, color: AppColors.social),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(widget.recipe.title, style: text.bodyMedium),
                    Text(
                      l10n.diaryPlanned(widget.kcal),
                      style: text.bodySmall
                          ?.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                key: Key('eat-planned-${widget.entry.slot.name}'),
                onPressed: _busy ? null : _eat,
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.social),
                icon: const Icon(Icons.check, size: 18),
                label: Text(l10n.diaryEatPlanned),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Closing the day turns the diary into the nutrition check-in. On target,
/// it is a tracked check-in worth the plan bonus; off target the user can
/// still tick the habit, just without the bonus — and a day ticked plainly
/// (here, or on Today) can still be closed on target later: the new
/// check-in replaces the old one.
class _CloseDay extends ConsumerStatefulWidget {
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
  ConsumerState<_CloseDay> createState() => _CloseDayState();
}

class _CloseDayState extends ConsumerState<_CloseDay> {
  bool _busy = false;

  Future<void> _close(Habit habit, {required bool tracked}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(appStateProvider.notifier).checkIn(
            habit,
            day: widget.day,
            tracked: tracked,
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Under" or "over", never "-1500 kcal off".
  String _offBy(AppLocalizations l10n) {
    final int delta = (widget.intake.total.kcal - widget.plan.kcal).round();
    return delta < 0
        ? l10n.diaryOffTargetUnder(-delta)
        : l10n.diaryOffTargetOver(delta);
  }

  Future<void> _closeAnyway(Habit habit) async {
    final AppLocalizations l10n = context.l10n;
    final bool? anyway = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.diaryOffTargetTitle),
        content: Text(_offBy(l10n)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const Key('close-day-anyway'),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.diaryOffTargetConfirm),
          ),
        ],
      ),
    );
    if (anyway == true) await _close(habit, tracked: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Habit? habit = widget.snapshot.challenge!.habits
        .where((Habit h) => h.category == HabitCategory.nutrition)
        .firstOrNull;
    if (habit == null) return const SizedBox.shrink();
    final CheckIn? entry = widget.snapshot.me.logsByDay[widget.day.toString()]
        ?.entryFor(habit.id);
    final bool closed = entry != null && !entry.relapse;
    final bool onTarget = widget.intake.isOnTarget(widget.plan);

    if (closed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppCard(
            color: AppColors.success.withValues(alpha: 0.08),
            border: AppColors.success.withValues(alpha: 0.5),
            child: Row(
              children: <Widget>[
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Text(entry.tracked
                      ? l10n.diaryClosedTracked
                      : l10n.diaryClosedPlain),
                ),
              ],
            ),
          ),
          if (!entry.tracked && onTarget) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('close-day-tracked'),
              onPressed: _busy ? null : () => _close(habit, tracked: true),
              icon: const Icon(Icons.task_alt, size: 18),
              label: Text(l10n.diaryCountOnTarget),
            ),
          ],
        ],
      );
    }

    return FilledButton.icon(
      key: const Key('close-day'),
      onPressed: widget.intake.isEmpty || _busy
          ? null
          : () => onTarget
              ? _close(habit, tracked: true)
              : _closeAnyway(habit),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      icon: const Icon(Icons.task_alt),
      label: Text(onTarget ? l10n.diaryCloseOnTarget : l10n.diaryClose),
    );
  }
}
