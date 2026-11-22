import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/household_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/household_providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'household_load_error.dart';
import 'household_screen.dart';
import 'plan_week_sheet.dart';
import 'planner_chat_screen.dart';
import 'recipe_sheet.dart';

/// The household's week of meals: day by day, slot by slot. Everyone in the
/// household sees and changes the same plan, live.
class WeekPlanView extends ConsumerStatefulWidget {
  const WeekPlanView({super.key, this.leading});

  /// Shown above the household: the user's own nutrition target, or the
  /// offer to set one.
  final Widget? leading;

  @override
  ConsumerState<WeekPlanView> createState() => _WeekPlanViewState();
}

class _WeekPlanViewState extends ConsumerState<WeekPlanView> {
  DayKey _weekStart = DayKey.today().weekStart;

  static const List<MealSlotKind> _slots = <MealSlotKind>[
    MealSlotKind.breakfast,
    MealSlotKind.lunch,
    MealSlotKind.dinner,
    MealSlotKind.snack,
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    ref.watch(sharedTargetsSyncProvider);
    final AsyncValue<List<PlanEntry>> plan =
        ref.watch(weekPlanProvider(_weekStart));
    final Map<String, Recipe> recipes =
        ref.watch(recipesProvider).valueOrNull ?? const <String, Recipe>{};
    final Household? household = ref.watch(householdProvider).valueOrNull;
    final bool canPlan = ref.watch(mealPlannerProvider).valueOrNull != null;
    final DayKey today = DayKey.today();

    return RefreshIndicator(
      onRefresh: () async {
        // A household that failed to load stays failed until asked again.
        if (ref.read(householdIdProvider).hasError) retryHousehold(ref);
        ref.invalidate(weekPlanProvider(_weekStart));
        try {
          await ref.read(weekPlanProvider(_weekStart).future);
        } on Object {
          // The error shows in the list.
        }
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md,
            AppSpacing.xxl + MediaQuery.paddingOf(context).bottom),
        children: <Widget>[
          if (widget.leading != null) ...<Widget>[
            widget.leading!,
            const SizedBox(height: AppSpacing.sm),
          ],
          if (household != null) _HouseholdBar(household: household),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              IconButton(
                onPressed: () =>
                    setState(() => _weekStart = _weekStart.addDays(-7)),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  l10n.periodLabel(
                      ShoppingPeriod(_weekStart, _weekStart.addDays(6))),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _weekStart = _weekStart.addDays(7)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  key: const Key('plan-week'),
                  onPressed: canPlan
                      ? () => showPlanWeekSheet(context, ref, _weekStart)
                      : null,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(l10n.planWeekAi),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('plan-chat'),
                  onPressed: canPlan
                      ? () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) =>
                                  PlannerChatScreen(weekStart: _weekStart),
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.forum_outlined, size: 18),
                  label: Text(l10n.planChat),
                ),
              ),
            ],
          ),
          if (!canPlan)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                l10n.planNeedsAi,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          // A realtime tick reloads the week; the old one stays on screen
          // meanwhile instead of a spinner that throws the scroll away.
          plan.when(
            skipLoadingOnReload: true,
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object error, StackTrace _) => const HouseholdLoadError(),
            data: (List<PlanEntry> entries) => Column(
              children: <Widget>[
                for (int i = 0; i < 7; i++)
                  _DayCard(
                    day: _weekStart.addDays(i),
                    isToday: _weekStart.addDays(i) == today,
                    slots: _slots,
                    entries: entries
                        .where((PlanEntry e) => e.day == _weekStart.addDays(i))
                        .toList(),
                    recipes: recipes,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HouseholdBar extends StatelessWidget {
  const _HouseholdBar({required this.household});

  final Household household;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCard(
      key: const Key('household-bar'),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const HouseholdScreen(),
        ),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          for (final HouseholdMember m in household.members.take(5))
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: EmojiAvatar(m.emoji, size: 28),
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              household.members.length == 1
                  ? l10n.householdJustYou
                  : (household.name.isEmpty
                      ? l10n.householdMembers(household.members.length)
                      : household.name),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Text(
            household.members.length == 1
                ? l10n.householdInviteShort
                : l10n.cadenceLabel(household.cadence),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.social),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({
    required this.day,
    required this.isToday,
    required this.slots,
    required this.entries,
    required this.recipes,
  });

  final DayKey day;
  final bool isToday;
  final List<MealSlotKind> slots;
  final List<PlanEntry> entries;
  final Map<String, Recipe> recipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    // Slots without a meal stay out of the way, except dinner — the one
    // households plan most — which offers itself.
    final List<MealSlotKind> shown = <MealSlotKind>[
      for (final MealSlotKind slot in slots)
        if (slot == MealSlotKind.dinner ||
            entries.any((PlanEntry e) => e.slot == slot))
          slot,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        color: isToday ? AppColors.surfaceHigh : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(l10n.formatDay(day), style: text.titleMedium),
                if (isToday) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  Text(l10n.planToday,
                      style: text.labelSmall?.copyWith(color: AppColors.success)),
                ],
                const Spacer(),
                PopupMenuButton<MealSlotKind>(
                  tooltip: l10n.planAddMeal,
                  icon: const Icon(Icons.add, size: 20),
                  onSelected: (MealSlotKind slot) =>
                      showAddMealSheet(context, ref, day, slot),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<MealSlotKind>>[
                    for (final MealSlotKind slot in slots)
                      PopupMenuItem<MealSlotKind>(
                        value: slot,
                        child: Text(l10n.mealName(slot)),
                      ),
                  ],
                ),
              ],
            ),
            for (final MealSlotKind slot in shown)
              for (final PlanEntry? entry in entries
                  .where((PlanEntry e) => e.slot == slot)
                  .toList()
                  .followedByEmptyIfNone())
                _SlotRow(
                  day: day,
                  slot: slot,
                  entry: entry,
                  recipe: entry == null ? null : recipes[entry.recipeId],
                ),
          ],
        ),
      ),
    );
  }
}

extension on List<PlanEntry> {
  /// The entries, or a single null to draw an empty slot.
  List<PlanEntry?> followedByEmptyIfNone() =>
      isEmpty ? <PlanEntry?>[null] : List<PlanEntry?>.of(this);
}

class _SlotRow extends ConsumerWidget {
  const _SlotRow({
    required this.day,
    required this.slot,
    required this.entry,
    required this.recipe,
  });

  final DayKey day;
  final MealSlotKind slot;
  final PlanEntry? entry;
  final Recipe? recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final Recipe? recipe = this.recipe;
    final PlanEntry? entry = this.entry;
    return InkWell(
      borderRadius: AppRadius.cardAll,
      onTap: () => entry == null || recipe == null
          ? showAddMealSheet(context, ref, day, slot)
          : showRecipeSheet(context, ref, entry, recipe),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 88,
              child: Text(l10n.mealName(slot),
                  style: text.bodySmall?.copyWith(color: AppColors.textTertiary)),
            ),
            Expanded(
              child: recipe == null
                  ? Text(l10n.planEmptySlot,
                      style: text.bodyMedium
                          ?.copyWith(color: AppColors.textTertiary))
                  : Text(recipe.title, style: text.bodyMedium),
            ),
            if (recipe != null && recipe.minutes != null)
              Text(l10n.planMinutes(recipe.minutes!),
                  style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
