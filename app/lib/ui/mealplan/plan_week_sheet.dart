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
  bool _saving = false;

  /// Why the last attempt gave nothing — offline, allowance, no usable
  /// plan, a save that failed — or null.
  String? _problem;
  List<ProposedMeal>? _proposal;
  final Set<int> _rejected = <int>{};

  @override
  void dispose() {
    _wish.dispose();
    super.dispose();
  }

  /// The dishes planned most recently, around and in this week — what the
  /// draft should not repeat — and those on this week's slots that the
  /// draft leaves alone, which it must not repeat. Without them it is still
  /// a plan.
  Future<({List<String> recent, List<String> planned})> _dishes(
      Set<String> requested) async {
    try {
      final String id = await ref.read(householdIdProvider.future);
      final List<PlanEntry> entries = await ref
          .read(householdBackendProvider)
          .plan(id, widget.weekStart.addDays(-28), widget.weekStart.addDays(6));
      final Map<String, Recipe> recipes = await ref.read(recipesProvider.future);
      final List<PlanEntry> thisWeekKept = <PlanEntry>[
        for (final PlanEntry e in entries)
          if (!e.day.isBefore(widget.weekStart) &&
              !requested.contains('${e.day}/${e.slot.name}'))
            e,
      ];
      return (
        recent: recentTitles(entries, recipes),
        planned: recentTitles(thisWeekKept, recipes, limit: 40),
      );
    } on Object {
      return (recent: const <String>[], planned: const <String>[]);
    }
  }

  Future<void> _propose() async {
    if (_working) return;
    // The wish is typed; the keyboard has done its job and would cover the
    // draft.
    FocusScope.of(context).unfocus();
    final AppLocalizations l10n = context.l10n;
    // "Again" means something else: the last draft is not repeated either.
    final List<String> lastDraft = <String>[
      for (final ProposedMeal m in _proposal ?? const <ProposedMeal>[])
        m.recipe.title,
    ];
    setState(() {
      _working = true;
      _problem = null;
      _proposal = null;
      _rejected.clear();
    });
    try {
      final MealPlanner? planner = await ref.read(mealPlannerProvider.future);
      if (planner == null) return;
      final Household household = await ref.read(householdProvider.future);
      final List<DayKey> days = _days.toList()..sort();
      final List<MealSlotKind> slots =
          MealSlotKind.values.where(_slots.contains).toList();
      final dishes = await _dishes(<String>{
        for (final DayKey d in days)
          for (final MealSlotKind s in slots) '$d/${s.name}',
      });
      Object? failure;
      final List<ProposedMeal>? meals = await planner.proposeWeek(
        MealPlanRequest(
          days: days,
          slots: slots,
          people: household.members.map((HouseholdMember m) => m.toPlanFor()).toList(),
          wish: _wish.text,
          maxMinutes: _maxMinutes,
          avoidTitles: <String>[...lastDraft, ...dishes.recent],
          plannedTitles: dishes.planned,
        ),
        onError: (Object error) => failure = error,
      );
      if (!mounted) return;
      setState(() {
        _proposal = meals;
        _problem = meals != null
            ? null
            : failure != null
                ? l10n.aiErrorMessage(failure!)
                : l10n.planWeekFailed;
      });
    } on Object {
      // The household itself could not be read: offline.
      if (mounted) setState(() => _problem = l10n.aiUnreachable);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Saves the meals kept. A failure leaves the draft where it was, with
  /// the reason: what was already saved is replaced again on the retry.
  Future<void> _accept() async {
    if (_saving) return;
    final List<ProposedMeal> chosen = <ProposedMeal>[
      for (int i = 0; i < _proposal!.length; i++)
        if (!_rejected.contains(i)) _proposal![i],
    ];
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _saving = true;
      _problem = null;
    });
    try {
      await ref.read(householdActionsProvider).acceptProposal(chosen);
    } on Object {
      if (mounted) setState(() => _problem = l10n.planSaveFailed);
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.planAccepted(chosen.length))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final List<ProposedMeal>? proposal = _proposal;

    return ListView(
      controller: widget.scroll,
      // The keyboard goes as soon as the sheet is scrolled, and the end of
      // the sheet can be scrolled above it while it is up.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
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
          textCapitalization: TextCapitalization.sentences,
          // One wish, not a letter: the return key closes the keyboard
          // instead of starting a line that hides the button beneath.
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(hintText: l10n.planWeekWishHint),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const Key('plan-propose'),
          onPressed: _working || _saving || _days.isEmpty || _slots.isEmpty
              ? null
              : _propose,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: Text(proposal == null ? l10n.planWeekPropose : l10n.planWeekAgain),
        ),
        if (_working) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: AppSpacing.sm),
          Center(child: Text(l10n.planWeekWorking, style: text.bodySmall)),
        ],
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(_problem!,
                key: const Key('plan-problem'),
                style: text.bodyMedium?.copyWith(color: AppColors.danger)),
          ),
        if (proposal != null && !_working) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          for (int i = 0; i < proposal.length; i++)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: !_rejected.contains(i),
              onChanged: _saving
                  ? null
                  : (bool? keep) => setState(
                      () => keep == true ? _rejected.remove(i) : _rejected.add(i)),
              title: Text(proposal[i].recipe.title),
              subtitle: Text(
                '${l10n.formatDay(proposal[i].day)} · ${l10n.mealName(proposal[i].slot)} · '
                '${l10n.diaryEntryKcal(proposal[i].recipe.perServing.kcal.round())}'
                '${proposal[i].recipe.minutes == null ? '' : ' · ${l10n.planMinutes(proposal[i].recipe.minutes!)}'}',
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const Key('plan-accept'),
            onPressed:
                _saving || _rejected.length == proposal.length ? null : _accept,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, size: 18),
            label: Text(l10n.planWeekAccept(proposal.length - _rejected.length)),
          ),
        ],
      ],
    );
  }
}
