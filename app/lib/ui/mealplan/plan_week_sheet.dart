import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/household_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/household_providers.dart';
import '../../theme/theme.dart';

/// "Plan the week": which days and meals, any wishes — then a draft from the
/// model that the user takes as a whole, or meal by meal.
Future<void> showPlanWeekSheet(
  BuildContext context,
  WidgetRef ref,
  DayKey weekStart,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (BuildContext context, ScrollController scroll) =>
            _PlanWeekSheet(weekStart: weekStart, scroll: scroll),
      ),
    );

class _PlanWeekSheet extends ConsumerStatefulWidget {
  const _PlanWeekSheet({required this.weekStart, required this.scroll});

  final DayKey weekStart;
  final ScrollController scroll;

  @override
  ConsumerState<_PlanWeekSheet> createState() => _PlanWeekSheetState();
}

class _PlanWeekSheetState extends ConsumerState<_PlanWeekSheet> {
  final TextEditingController _wish = TextEditingController();
  late final Set<DayKey> _days = <DayKey>{
    for (int i = 0; i < 7; i++)
      if (!widget.weekStart.addDays(i).isBefore(DayKey.today()))
        widget.weekStart.addDays(i),
  };
  final Set<MealSlotKind> _slots = <MealSlotKind>{MealSlotKind.dinner};
  int? _maxMinutes = 30;
  bool _working = false;
  bool _failed = false;
  List<ProposedMeal>? _proposal;
  final Set<int> _rejected = <int>{};

  @override
  void dispose() {
    _wish.dispose();
    super.dispose();
  }

  Future<void> _propose() async {
    final MealPlanner? planner = await ref.read(mealPlannerProvider.future);
    final Household household = await ref.read(householdProvider.future);
    final Map<String, Recipe> recipes = await ref.read(recipesProvider.future);
    if (planner == null) return;
    setState(() {
      _working = true;
      _failed = false;
      _proposal = null;
      _rejected.clear();
    });
    final List<ProposedMeal>? meals = await planner.proposeWeek(MealPlanRequest(
      days: _days.toList()..sort(),
      slots: MealSlotKind.values.where(_slots.contains).toList(),
      people: household.members.map((HouseholdMember m) => m.toPlanFor()).toList(),
      wish: _wish.text,
      maxMinutes: _maxMinutes,
      avoidTitles: recipes.values.map((Recipe r) => r.title).take(20).toList(),
    ));
    if (!mounted) return;
    setState(() {
      _working = false;
      _failed = meals == null;
      _proposal = meals;
    });
  }

  Future<void> _accept() async {
    final List<ProposedMeal> chosen = <ProposedMeal>[
      for (int i = 0; i < _proposal!.length; i++)
        if (!_rejected.contains(i)) _proposal![i],
    ];
    setState(() => _working = true);
    await ref.read(householdActionsProvider).acceptProposal(chosen);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.planAccepted(chosen.length))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final List<ProposedMeal>? proposal = _proposal;

    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text(l10n.planWeekAi, style: text.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.planWeekDays, style: text.titleSmall),
        Wrap(
          spacing: AppSpacing.xs,
          children: <Widget>[
            for (int i = 0; i < 7; i++)
              FilterChip(
                label: Text(l10n.weekdayShort(widget.weekStart.addDays(i).toDateTime().weekday)),
                selected: _days.contains(widget.weekStart.addDays(i)),
                onSelected: (bool on) => setState(() => on
                    ? _days.add(widget.weekStart.addDays(i))
                    : _days.remove(widget.weekStart.addDays(i))),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.planWeekSlots, style: text.titleSmall),
        Wrap(
          spacing: AppSpacing.xs,
          children: <Widget>[
            for (final MealSlotKind slot in MealSlotKind.values)
              FilterChip(
                label: Text(l10n.mealName(slot)),
                selected: _slots.contains(slot),
                onSelected: (bool on) =>
                    setState(() => on ? _slots.add(slot) : _slots.remove(slot)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.planWeekTime, style: text.titleSmall),
        Wrap(
          spacing: AppSpacing.xs,
          children: <Widget>[
            for (final int? minutes in <int?>[20, 30, 45, null])
              ChoiceChip(
                label: Text(minutes == null ? l10n.planWeekAnyTime : l10n.planMinutes(minutes)),
                selected: _maxMinutes == minutes,
                onSelected: (_) => setState(() => _maxMinutes = minutes),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('plan-wish'),
          controller: _wish,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(hintText: l10n.planWeekWishHint),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const Key('plan-propose'),
          onPressed: _working || _days.isEmpty || _slots.isEmpty ? null : _propose,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: Text(proposal == null ? l10n.planWeekPropose : l10n.planWeekAgain),
        ),
        if (_working) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: AppSpacing.sm),
          Center(child: Text(l10n.planWeekWorking, style: text.bodySmall)),
        ],
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(l10n.planWeekFailed,
                style: text.bodyMedium?.copyWith(color: AppColors.danger)),
          ),
        if (proposal != null && !_working) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          for (int i = 0; i < proposal.length; i++)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: !_rejected.contains(i),
              onChanged: (bool? keep) =>
                  setState(() => keep == true ? _rejected.remove(i) : _rejected.add(i)),
              title: Text(proposal[i].recipe.title),
              subtitle: Text(
                '${l10n.formatDay(proposal[i].day)} · ${l10n.mealName(proposal[i].slot)} · '
                '${l10n.diaryEntryKcal(proposal[i].recipe.perServing.kcal.round())}'
                '${proposal[i].recipe.minutes == null ? '' : ' · ${l10n.planMinutes(proposal[i].recipe.minutes!)}'}',
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('plan-accept'),
            onPressed: _rejected.length == proposal.length ? null : _accept,
            child: Text(l10n.planWeekAccept(proposal.length - _rejected.length)),
          ),
        ],
      ],
    );
  }
}
