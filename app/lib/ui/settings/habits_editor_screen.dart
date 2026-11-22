import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// The habits of a running challenge: add one, change a target or how often,
/// take one out. Nothing here rewrites the past — a new target, a new
/// frequency and a habit taken out all apply from a day on, and the days
/// before keep counting by the rules they were counted with.
class HabitsEditorScreen extends ConsumerStatefulWidget {
  const HabitsEditorScreen({super.key});

  @override
  ConsumerState<HabitsEditorScreen> createState() => _HabitsEditorState();
}

class _Draft {
  _Draft(this.habit)
      : target = habit.target,
        days = habit.daysPerWeek;

  _Draft.added(this.habit)
      : target = habit.target,
        days = habit.daysPerWeek,
        isNew = true;

  final Habit habit;
  num target;
  int days;
  bool removed = false;
  bool isNew = false;
}

class _HabitsEditorState extends ConsumerState<HabitsEditorScreen> {
  late final AppSnapshot _snapshot = ref.read(appStateProvider).requireValue;
  late final List<_Draft> _drafts = <_Draft>[
    for (final Habit h in _snapshot.challenge!.habits)
      if (!h.isRetiredOn(_snapshot.today)) _Draft(h),
  ];
  bool _saving = false;

  /// Changes land today — unless today is already done, where a new habit
  /// or a higher target would take back a day that is finished.
  DayKey get _from => _snapshot.me.streak.doneToday
      ? _snapshot.today.addDays(1)
      : _snapshot.today;

  bool get _dirty => _drafts.any((_Draft d) =>
      d.removed || d.isNew || d.target != d.habit.target || d.days != d.habit.daysPerWeek);

  num _step(Habit habit) {
    final num target = habit.definition.defaultTarget;
    if (target >= 100) return 15;
    if (target >= 20) return 5;
    return 1;
  }

  Future<void> _remove(_Draft draft) async {
    final AppLocalizations l10n = context.l10n;
    if (_drafts.where((_Draft d) => !d.removed).length <= 1) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.habitsKeepOne)));
      return;
    }
    if (draft.isNew) {
      setState(() => _drafts.remove(draft));
      return;
    }
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.habitsRemoveTitle(l10n.habitLabel(draft.habit))),
        content: Text(l10n.habitsRemoveBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.ink,
              minimumSize: const Size(110, 44),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.habitsRemove),
          ),
        ],
      ),
    );
    if (ok == true) setState(() => draft.removed = true);
  }

  Future<void> _add() async {
    final AppLocalizations l10n = context.l10n;
    final Challenge challenge = _snapshot.challenge!;
    final Set<String> present = <String>{
      for (final _Draft d in _drafts)
        if (!d.removed) d.habit.id,
    };
    final List<HabitCategory> choices = <HabitCategory>[
      for (final HabitCategory c in HabitCategory.values)
        if (c != HabitCategory.custom && !present.contains(c.name)) c,
    ];
    final Object? picked = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            Text(l10n.habitsAdd,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            for (final HabitCategory c in choices)
              ListTile(
                key: Key('add-${c.name}'),
                leading: Text(habitDefinition(c).emoji,
                    style: const TextStyle(fontSize: 22)),
                title: Text(l10n.habitTitle(c)),
                onTap: () => Navigator.of(context).pop(c),
              ),
            ListTile(
              key: const Key('add-custom'),
              leading: const Text('⭐', style: TextStyle(fontSize: 22)),
              title: Text(l10n.habitsAddCustom),
              onTap: () => Navigator.of(context).pop('custom'),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    Habit habit;
    if (picked is HabitCategory) {
      // Taken out earlier and back now: a new habit beside the old one, so
      // the days the old one was out of the challenge stay out of it.
      habit = challenge.habitById(picked.name) == null
          ? Habit.fromCategory(picked)
          : Habit.fromCategory(
              picked,
              id: '${picked.name}-${DateTime.now().millisecondsSinceEpoch}',
            );
    } else {
      final String? name = await _askName();
      if (name == null || name.trim().isEmpty) return;
      habit = Habit.fromCategory(
        HabitCategory.custom,
        id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      ).copyWith(title: name.trim());
    }
    setState(() => _drafts.add(_Draft.added(habit)));
  }

  Future<String?> _askName() async {
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(context.l10n.habitsCustomName),
        content: TextField(
          key: const Key('custom-name'),
          controller: controller,
          autofocus: true,
          maxLength: 32,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.l10n.habitsAdd),
          ),
        ],
      ),
    );
    controller.dispose();
    return name;
  }

  Future<void> _save() async {
    final Challenge challenge = _snapshot.challenge!;
    final DayKey from = _from;
    final DayKey tomorrow = _snapshot.today.addDays(1);
    final Map<String, Habit> byId = <String, Habit>{
      for (final Habit h in challenge.habits) h.id: h,
    };
    for (final _Draft d in _drafts) {
      Habit h = d.habit;
      if (d.isNew) {
        h = Habit(
          id: h.id,
          category: h.category,
          target: d.target,
          daysPerWeek: d.days,
          title: h.title,
          note: h.note,
          activeFrom: from,
        );
      } else if (d.removed) {
        h = h.retiredFrom(tomorrow);
      } else {
        h = h.withTarget(d.target, from: from).withDaysPerWeek(d.days, from: from);
      }
      byId[h.id] = h;
    }
    setState(() => _saving = true);
    try {
      await ref.read(appStateProvider.notifier).updateChallenge(
            challenge.copyWith(habits: byId.values.toList()),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.habitsSaved)));
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorGeneric('$error'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextStyle? note = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: AppColors.textSecondary, fontSize: 12.5);
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop) return;
        final bool? leave = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(l10n.loggerDiscardTitle),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.loggerDiscard),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.habitsEditTitle)),
        body: ListView(
          padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md,
              AppSpacing.md, AppSpacing.xl + MediaQuery.paddingOf(context).bottom),
          children: <Widget>[
            Text(l10n.habitsEditSub, style: note),
            if (_snapshot.me.streak.doneToday) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.habitsFromTomorrow, style: note),
            ],
            const SizedBox(height: AppSpacing.md),
            for (final _Draft d in _drafts)
              if (!d.removed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _HabitEditCard(
                    draft: d,
                    step: _step(d.habit),
                    onChanged: () => setState(() {}),
                    onRemove: () => _remove(d),
                    trainingNote: d.habit.category == HabitCategory.gym &&
                            _snapshot.plan?.training != null
                        ? l10n.habitsTrainingNote
                        : null,
                  ),
                ),
            OutlinedButton.icon(
              key: const Key('habits-add'),
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(l10n.habitsAdd),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('habits-save'),
              onPressed: _dirty && !_saving ? _save : null,
              child: Text(l10n.habitsSave),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitEditCard extends StatelessWidget {
  const _HabitEditCard({
    required this.draft,
    required this.step,
    required this.onChanged,
    required this.onRemove,
    this.trainingNote,
  });

  final _Draft draft;
  final num step;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final String? trainingNote;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Habit habit = draft.habit;
    final bool amount = habit.definition.unit != HabitUnit.done;
    final bool weekly =
        habit.kind == HabitKind.build && trainingNote == null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(habit.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(l10n.habitLabel(habit),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton(
                key: Key('remove-${habit.id}'),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: onRemove,
                child: Text(l10n.habitsRemove),
              ),
            ],
          ),
          if (amount)
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: draft.target - step <= 0
                      ? null
                      : () {
                          draft.target = draft.target - step;
                          onChanged();
                        },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      l10n.formatTarget(habit, value: draft.target),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    draft.target = draft.target + step;
                    onChanged();
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          if (weekly) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (int d = 1; d <= 7; d++)
                  ChoiceChip(
                    label: Text('$d'),
                    selected: draft.days == d,
                    onSelected: (_) {
                      draft.days = d;
                      onChanged();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              draft.days >= 7
                  ? l10n.habitsEveryDay
                  : l10n.habitsDaysPerWeek(draft.days),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
            ),
          ],
          if (trainingNote != null)
            Text(
              trainingNote!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
            ),
        ],
      ),
    );
  }
}
