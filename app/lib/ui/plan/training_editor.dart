import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'session_editor.dart';
import 'training_form.dart';

/// Change the days, experience, equipment, split and every exercise of a
/// running plan — or switch the plan off, and on again. Saved as a
/// challenge update: the history stays as it was.
///
/// Also the way into a plan that comes later — switched on, or a training
/// habit added — so it asks what onboarding asks, and an answer changes the
/// plan by the same rule (`retargetTraining`).
class TrainingEditorScreen extends ConsumerStatefulWidget {
  const TrainingEditorScreen({super.key, required this.challenge});

  final Challenge challenge;

  @override
  ConsumerState<TrainingEditorScreen> createState() =>
      _TrainingEditorScreenState();
}

class _TrainingEditorScreenState extends ConsumerState<TrainingEditorScreen> {
  late final int _initialDays =
      widget.challenge.goal.trainingDaysPerWeek.clamp(2, 6);
  late final TrainingExperience _initialExperience =
      widget.challenge.goal.experience;
  late final EquipmentAccess _initialEquipment =
      widget.challenge.goal.equipment;
  late final TrainingSetup _initialSetup =
      widget.challenge.goal.training ?? suggestTrainingSetup(_goal);
  late int _days = _initialDays;
  late TrainingExperience _experience = _initialExperience;
  late EquipmentAccess _equipment = _initialEquipment;
  late TrainingSetup _setup = _initialSetup;
  bool _saving = false;

  /// Starts on even when the stored plan is off: the editor is opened to
  /// edit a plan or to switch one on, and saving does the latter.
  bool _enabled = true;

  /// Set once a save was refused for an empty session.
  bool _flagEmpty = false;

  /// What the user made of each split they tried, so looking at another
  /// one and coming back does not cost the edits.
  final Map<SplitKind, TrainingSetup> _bySplit = <SplitKind, TrainingSetup>{};

  Goal get _goal => widget.challenge.goal.copyWith(
        trainingDaysPerWeek: _days,
        experience: _experience,
        equipment: _equipment,
      );

  bool get _dirty =>
      !_enabled ||
      _days != _initialDays ||
      _experience != _initialExperience ||
      _equipment != _initialEquipment ||
      _setup != _initialSetup;

  /// Days, experience or equipment changed: the plan follows as it does in
  /// onboarding — and so do the ones parked under other splits.
  void _changeGoal({
    int? days,
    TrainingExperience? experience,
    EquipmentAccess? equipment,
  }) {
    final Goal from = _goal;
    setState(() {
      _days = days ?? _days;
      _experience = experience ?? _experience;
      _equipment = equipment ?? _equipment;
      final Goal to = _goal;
      _setup = retargetTraining(_setup, from: from, to: to);
      _bySplit.updateAll((SplitKind _, TrainingSetup parked) =>
          retargetTraining(parked, from: from, to: to));
    });
  }

  Future<bool> _confirmDiscard() async {
    final AppLocalizations l10n = context.l10n;
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.editorDiscardTitle),
        content: Text(l10n.editorDiscardBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const Key('editor-discard'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(110, 44),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.editorDiscard),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _save() async {
    // A session with nothing in it would be a workout that can never be
    // finished. Say which one, rather than save it.
    if (_enabled && !_setup.isTrainable) {
      setState(() => _flagEmpty = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.editorEmptySession)),
      );
      return;
    }
    setState(() => _saving = true);
    final DayKey today = DayKey.today();
    final Challenge challenge = widget.challenge;
    // The habit the plan checks in follows its days — gym, or cardio for a
    // challenge without gym — or the workout card turns up on days that
    // habit does not expect.
    final Habit? planHabit = trainingHabitOf(challenge.habits);
    final Challenge updated = _enabled
        ? challenge.copyWith(
            goal: _goal.copyWith(training: _setup, trainingPlanEnabled: true),
            habits: <Habit>[
              for (final Habit h in challenge.habits)
                h.id == planHabit?.id
                    ? h.withDaysPerWeek(_days, from: today)
                    : h,
            ],
          )
        // Off keeps everything else as it was: the split and exercises
        // wait for the plan to come back, logged workouts stay logged.
        : challenge.copyWith(
            goal: challenge.goal.copyWith(trainingPlanEnabled: false),
          );
    await ref.read(appStateProvider.notifier).updateChallenge(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_enabled
            ? context.l10n.editorSaved
            : context.l10n.editorPlanSwitchedOff),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final int bonus = ((kTrackedMultiplier - 1) * 100).round();
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.editorTitle),
          actions: <Widget>[
            TextButton(
              key: const Key('editor-save'),
              onPressed: _saving ? null : _save,
              child: Text(l10n.actionSave),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: SwitchListTile(
                key: const Key('training-plan-switch'),
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                onChanged: (bool on) => setState(() => _enabled = on),
                title: Text(l10n.editorPlanSwitch,
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(
                  _enabled
                      ? l10n.editorPlanOnBody(bonus)
                      : l10n.editorPlanOffBody(bonus),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ),
            if (_enabled) ..._planSections(l10n),
          ],
        ),
      ),
    );
  }

  /// Funki, days, experience, equipment, split and exercises: only while
  /// the plan is on.
  List<Widget> _planSections(AppLocalizations l10n) => <Widget>[
        const SizedBox(height: AppSpacing.md),
        FunkiTrainingLine(
          goal: _goal,
          setup: _setup,
          onChanged: (EquipmentAccess equipment, TrainingSetup setup) =>
              setState(() {
            _equipment = equipment;
            _setup = setup;
          }),
        ),
        SectionHeader(l10n.obTrainingDaysPerWeek,
            subtitle: l10n.editorDaysNote),
        TrainingDaysPicker(
          value: _days,
          onChanged: (int days) => _changeGoal(days: days),
        ),
        SectionHeader(l10n.obTrainingExperience),
        ExperiencePicker(
          value: _experience,
          onChanged: (TrainingExperience level) =>
              _changeGoal(experience: level),
        ),
        SectionHeader(l10n.obTrainingEquipment),
        EquipmentPicker(
          value: _equipment,
          onChanged: (EquipmentAccess access) =>
              _changeGoal(equipment: access),
        ),
        SectionHeader(l10n.editorSplitTitle),
        SplitPicker(
          daysPerWeek: _days,
          selected: _setup.split,
          onSelected: (SplitKind split) => setState(() {
            _bySplit[_setup.split] = _setup;
            _setup =
                _bySplit[split] ?? suggestTrainingSetup(_goal, split: split);
          }),
        ),
        SectionHeader(
          l10n.editorSessionsTitle,
          subtitle: l10n.editorSessionsSubtitle,
        ),
        SessionEditorList(
          setup: _setup,
          goal: _goal,
          flagEmpty: _flagEmpty,
          onChanged: (TrainingSetup setup) => setState(() => _setup = setup),
        ),
        TextButton.icon(
          onPressed: () => setState(
            () => _setup = suggestTrainingSetup(_goal, split: _setup.split),
          ),
          icon: const Icon(Icons.restart_alt, size: 18),
          label: Text(l10n.editorReset),
        ),
      ];
}
