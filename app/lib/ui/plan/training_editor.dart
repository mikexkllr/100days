import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'session_editor.dart';

/// Change the split, the training days and every exercise of a running
/// plan. Saved as a challenge update: the history stays as it was.
class TrainingEditorScreen extends ConsumerStatefulWidget {
  const TrainingEditorScreen({super.key, required this.challenge});

  final Challenge challenge;

  @override
  ConsumerState<TrainingEditorScreen> createState() =>
      _TrainingEditorScreenState();
}

class _TrainingEditorScreenState extends ConsumerState<TrainingEditorScreen> {
  late int _days = widget.challenge.goal.trainingDaysPerWeek.clamp(2, 6);
  late TrainingSetup _setup = widget.challenge.goal.training ??
      suggestTrainingSetup(widget.challenge.goal);
  bool _saving = false;

  Goal get _goal => widget.challenge.goal.copyWith(trainingDaysPerWeek: _days);

  Future<void> _save() async {
    setState(() => _saving = true);
    final DayKey today = DayKey.today();
    final Challenge challenge = widget.challenge;
    final Challenge updated = challenge.copyWith(
      goal: _goal.copyWith(training: _setup, trainingPlanEnabled: true),
      habits: <Habit>[
        for (final Habit h in challenge.habits)
          h.category == HabitCategory.gym
              ? h.withDaysPerWeek(_days, from: today)
              : h,
      ],
    );
    await ref.read(appStateProvider.notifier).updateChallenge(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.editorSaved)),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editorTitle),
        actions: <Widget>[
          TextButton(
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
          SectionHeader(l10n.obTrainingDaysPerWeek,
              subtitle: l10n.editorDaysNote),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final int days in const <int>[2, 3, 4, 5, 6])
                ChoiceChip(
                  label: Text('$days×'),
                  selected: _days == days,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  onSelected: (_) => setState(() => _days = days),
                ),
            ],
          ),
          SectionHeader(l10n.editorSplitTitle),
          SplitPicker(
            daysPerWeek: _days,
            selected: _setup.split,
            onSelected: (SplitKind split) => setState(
              () => _setup = suggestTrainingSetup(_goal, split: split),
            ),
          ),
          SectionHeader(
            l10n.editorSessionsTitle,
            subtitle: l10n.editorSessionsSubtitle,
          ),
          SessionEditorList(
            setup: _setup,
            goal: _goal,
            onChanged: (TrainingSetup setup) =>
                setState(() => _setup = setup),
          ),
          TextButton.icon(
            onPressed: () => setState(
              () => _setup = suggestTrainingSetup(_goal, split: _setup.split),
            ),
            icon: const Icon(Icons.restart_alt, size: 18),
            label: Text(l10n.editorReset),
          ),
        ],
      ),
    );
  }
}
