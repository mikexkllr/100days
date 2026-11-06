import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// Every split, the recommended one marked. Picking one replaces the
/// sessions with a fresh suggestion for that split.
class SplitPicker extends StatelessWidget {
  const SplitPicker({
    super.key,
    required this.daysPerWeek,
    required this.selected,
    required this.onSelected,
  });

  final int daysPerWeek;
  final SplitKind selected;
  final ValueChanged<SplitKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SplitKind recommended = recommendedSplit(daysPerWeek);
    return Column(
      children: <Widget>[
        for (final SplitKind split in splitOptions(daysPerWeek))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              key: Key('split-${split.name}'),
              onTap: () => onSelected(split),
              border: split == selected ? AppColors.flame : null,
              color: split == selected
                  ? AppColors.flame.withValues(alpha: 0.08)
                  : AppColors.surface,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 4,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    split == selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: split == selected
                        ? AppColors.flame
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: AppSpacing.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(l10n.splitName(split),
                                style: Theme.of(context).textTheme.titleMedium),
                            if (split == recommended)
                              Pill(l10n.splitRecommended,
                                  color: AppColors.lime),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.splitBlurb(split),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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

/// The sessions of a plan, each with its exercises, all editable: tap an
/// exercise to change sets, reps and effort, swap it for an alternative or
/// remove it; add new ones from the library.
class SessionEditorList extends StatelessWidget {
  const SessionEditorList({
    super.key,
    required this.setup,
    required this.goal,
    required this.onChanged,
  });

  final TrainingSetup setup;

  /// For the equipment filter and the default prescription of new slots.
  final Goal goal;
  final ValueChanged<TrainingSetup> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < setup.sessions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
            child: _SessionCard(
              index: i,
              session: setup.sessions[i],
              goal: goal,
              onChanged: (SessionPlan session) =>
                  onChanged(setup.withSession(i, session)),
            ),
          ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.index,
    required this.session,
    required this.goal,
    required this.onChanged,
  });

  final int index;
  final SessionPlan session;
  final Goal goal;
  final ValueChanged<SessionPlan> onChanged;

  void _replace(int slotIndex, ExerciseSlot? slot) {
    final List<ExerciseSlot> next = session.exercises.toList();
    if (slot == null) {
      next.removeAt(slotIndex);
    } else {
      next[slotIndex] = slot;
    }
    onChanged(session.copyWith(exercises: next));
  }

  void _move(int slotIndex, int delta) {
    final int target = slotIndex + delta;
    if (target < 0 || target >= session.exercises.length) return;
    final List<ExerciseSlot> next = session.exercises.toList();
    final ExerciseSlot moved = next.removeAt(slotIndex);
    next.insert(target, moved);
    onChanged(session.copyWith(exercises: next));
  }

  Future<void> _add(BuildContext context) async {
    final Exercise? picked = await showExercisePicker(
      context,
      equipment: goal.equipment,
      exclude: session.exercises.map((ExerciseSlot s) => s.exerciseId).toSet(),
    );
    if (picked == null) return;
    onChanged(session.copyWith(exercises: <ExerciseSlot>[
      ...session.exercises,
      defaultSlotFor(picked, goal),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceHigh,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.flame),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(l10n.workoutName(session.kind),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Pill(l10n.homeSetsCount(session.totalSets)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (session.exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.editorSessionEmpty,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textTertiary),
              ),
            ),
          for (int i = 0; i < session.exercises.length; i++)
            _SlotRow(
              slot: session.exercises[i],
              onTap: () async {
                final _SlotEdit? edit = await showModalBottomSheet<_SlotEdit>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.surface,
                  builder: (BuildContext context) => _SlotSheet(
                    slot: session.exercises[i],
                    goal: goal,
                    canMoveUp: i > 0,
                    canMoveDown: i < session.exercises.length - 1,
                  ),
                );
                if (edit == null) return;
                switch (edit.action) {
                  case _SlotAction.update:
                    _replace(i, edit.slot);
                  case _SlotAction.remove:
                    _replace(i, null);
                  case _SlotAction.moveUp:
                    _move(i, -1);
                  case _SlotAction.moveDown:
                    _move(i, 1);
                }
              },
            ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            key: Key('add-exercise-$index'),
            onPressed: () => _add(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.editorAddExercise),
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot, required this.onTap});

  final ExerciseSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Exercise? exercise = slot.exercise;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.exerciseName(slot.exerciseId),
                      style: Theme.of(context).textTheme.bodyLarge),
                  if (exercise != null)
                    Text(
                      l10n.muscleName(exercise.primary),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                    ),
                ],
              ),
            ),
            Text(
              l10n.editorSetsReps(
                slot.sets,
                slot.repsLow == slot.repsHigh
                    ? '${slot.repsLow}'
                    : '${slot.repsLow}–${slot.repsHigh}',
                slot.rir,
              ),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

enum _SlotAction { update, remove, moveUp, moveDown }

class _SlotEdit {
  const _SlotEdit(this.action, [this.slot]);

  final _SlotAction action;
  final ExerciseSlot? slot;
}

class _SlotSheet extends StatefulWidget {
  const _SlotSheet({
    required this.slot,
    required this.goal,
    required this.canMoveUp,
    required this.canMoveDown,
  });

  final ExerciseSlot slot;
  final Goal goal;
  final bool canMoveUp;
  final bool canMoveDown;

  @override
  State<_SlotSheet> createState() => _SlotSheetState();
}

class _SlotSheetState extends State<_SlotSheet> {
  late ExerciseSlot _slot = widget.slot;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<Exercise> alternatives =
        alternativesFor(_slot.exerciseId, widget.goal.equipment);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.exerciseName(_slot.exerciseId),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              _Stepper(
                label: l10n.editorSets,
                value: '${_slot.sets}',
                onMinus: () =>
                    setState(() => _slot = _slot.copyWith(sets: _slot.sets - 1)),
                onPlus: () =>
                    setState(() => _slot = _slot.copyWith(sets: _slot.sets + 1)),
              ),
              _Stepper(
                label: l10n.editorRepsLow,
                value: '${_slot.repsLow}',
                onMinus: () => setState(() =>
                    _slot = _slot.copyWith(repsLow: _slot.repsLow - 1)),
                onPlus: () => setState(() =>
                    _slot = _slot.copyWith(repsLow: _slot.repsLow + 1)),
              ),
              _Stepper(
                label: l10n.editorRepsHigh,
                value: '${_slot.repsHigh}',
                onMinus: () => setState(() => _slot = _slot.copyWith(
                    repsHigh: (_slot.repsHigh - 1)
                        .clamp(_slot.repsLow, 50)
                        .toInt())),
                onPlus: () => setState(() =>
                    _slot = _slot.copyWith(repsHigh: _slot.repsHigh + 1)),
              ),
              _Stepper(
                label: l10n.editorRir,
                value: '${_slot.rir}',
                // More reserve is less effort: RIR up means RPE down.
                onMinus: () => setState(
                    () => _slot = _slot.copyWith(rpe: _slot.rpe + 1)),
                onPlus: () => setState(
                    () => _slot = _slot.copyWith(rpe: _slot.rpe - 1)),
              ),
              _Stepper(
                label: l10n.editorRest,
                value: l10n.workoutRestSeconds(_slot.restSeconds),
                onMinus: () => setState(() => _slot =
                    _slot.copyWith(restSeconds: _slot.restSeconds - 15)),
                onPlus: () => setState(() => _slot =
                    _slot.copyWith(restSeconds: _slot.restSeconds + 15)),
              ),
              Text(
                l10n.editorRirHelp,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
              ),
              if (alternatives.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(l10n.editorSwap,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final Exercise e in alternatives.take(8))
                      ActionChip(
                        label: Text(l10n.exerciseName(e.id)),
                        onPressed: () => setState(
                            () => _slot = swapSlot(_slot, e, widget.goal)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: l10n.editorMoveUp,
                    onPressed: widget.canMoveUp
                        ? () => Navigator.of(context)
                            .pop(const _SlotEdit(_SlotAction.moveUp))
                        : null,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: l10n.editorMoveDown,
                    onPressed: widget.canMoveDown
                        ? () => Navigator.of(context)
                            .pop(const _SlotEdit(_SlotAction.moveDown))
                        : null,
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger),
                    onPressed: () => Navigator.of(context)
                        .pop(const _SlotEdit(_SlotAction.remove)),
                    child: Text(l10n.actionRemove),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(100, 44)),
                    onPressed: () => Navigator.of(context)
                        .pop(_SlotEdit(_SlotAction.update, _slot)),
                    child: Text(l10n.actionSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_circle_outline),
            color: AppColors.textSecondary,
          ),
          SizedBox(
            width: 64,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

/// The exercise library for the user's equipment, grouped by muscle.
Future<Exercise?> showExercisePicker(
  BuildContext context, {
  required EquipmentAccess equipment,
  Set<String> exclude = const <String>{},
}) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (BuildContext context) {
      final AppLocalizations l10n = context.l10n;
      final Map<MuscleGroup, List<Exercise>> groups =
          exercisesByMuscle(equipment);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (BuildContext context, ScrollController controller) =>
            ListView(
          controller: controller,
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            Text(l10n.editorAddExercise,
                style: Theme.of(context).textTheme.titleLarge),
            for (final MapEntry<MuscleGroup, List<Exercise>> group
                in groups.entries) ...<Widget>[
              SectionHeader(l10n.muscleName(group.key)),
              for (final Exercise e in group.value)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: !exclude.contains(e.id),
                  title: Text(l10n.exerciseName(e.id)),
                  trailing: exclude.contains(e.id)
                      ? const Icon(Icons.check, color: AppColors.lime)
                      : const Icon(Icons.add),
                  onTap: () => Navigator.of(context).pop(e),
                ),
            ],
          ],
        ),
      );
    },
  );
}
