import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:intl/intl.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// One session, logged set by set.
///
/// Every exercise shows what was lifted last time and what to try today —
/// double progression: more reps at the same weight until the top of the
/// range, then more weight. Finishing writes the log and a tracked gym
/// check-in, which is worth more XP than a tick.
class WorkoutLoggerScreen extends ConsumerStatefulWidget {
  const WorkoutLoggerScreen({
    super.key,
    required this.workout,
    required this.day,
  });

  final Workout workout;
  final DayKey day;

  @override
  ConsumerState<WorkoutLoggerScreen> createState() =>
      _WorkoutLoggerScreenState();
}

class _SetRow {
  _SetRow({String weight = '', String reps = ''})
      : weight = TextEditingController(text: weight),
        reps = TextEditingController(text: reps);

  final TextEditingController weight;
  final TextEditingController reps;
  bool done = false;

  void dispose() {
    weight.dispose();
    reps.dispose();
  }
}

class _ExerciseState {
  _ExerciseState({
    required this.block,
    required this.history,
    required this.recommendation,
    required this.rows,
  });

  final PlannedSet block;
  final List<ExerciseLog> history;
  final SetRecommendation recommendation;
  final List<_SetRow> rows;
}

class _WorkoutLoggerScreenState extends ConsumerState<WorkoutLoggerScreen> {
  final DateTime _startedAt = DateTime.now();
  List<_ExerciseState>? _exercises;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _exercises ??= _build(Localizations.localeOf(context).toString());
  }

  List<_ExerciseState> _build(String locale) {
    final AppSnapshot? snapshot = ref.read(appStateProvider).valueOrNull;
    final format = NumberFormat.decimalPattern(locale)
      ..maximumFractionDigits = 2;
    return <_ExerciseState>[
      for (final PlannedSet block in widget.workout.blocks)
        () {
          final List<ExerciseLog> history = snapshot?.me
                  .historyOf(block.exerciseId, before: widget.day) ??
              const <ExerciseLog>[];
          final SetRecommendation rec =
              recommendNext(target: block, history: history);
          return _ExerciseState(
            block: block,
            history: history,
            recommendation: rec,
            rows: <_SetRow>[
              for (int i = 0; i < block.sets; i++)
                _SetRow(
                  weight: rec.weightKg == null || rec.weightKg == 0
                      ? ''
                      : format.format(rec.weightKg),
                  reps: '${rec.reps[i.clamp(0, rec.reps.length - 1)]}',
                ),
            ],
          );
        }(),
    ];
  }

  @override
  void dispose() {
    for (final _ExerciseState e in _exercises ?? const <_ExerciseState>[]) {
      for (final _SetRow r in e.rows) {
        r.dispose();
      }
    }
    super.dispose();
  }

  bool get _anyDone =>
      _exercises?.any((_ExerciseState e) => e.rows.any((_SetRow r) => r.done)) ??
      false;

  double _parse(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _finish() async {
    final AppLocalizations l10n = context.l10n;
    if (!_anyDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loggerFinishNoSets)),
      );
      return;
    }
    final AppSnapshot? snapshot = ref.read(appStateProvider).valueOrNull;
    final Habit? habit = snapshot?.challenge?.habits
            .where((Habit h) => h.category == HabitCategory.gym)
            .firstOrNull ??
        snapshot?.challenge?.habits
            .where((Habit h) => h.category == HabitCategory.cardio)
            .firstOrNull;
    if (habit == null) return;

    setState(() => _saving = true);
    final WorkoutLog log = WorkoutLog(
      day: widget.day,
      kind: widget.workout.kind,
      sessionIndex: widget.workout.sessionIndex,
      loggedAt: DateTime.now(),
      durationMinutes: DateTime.now().difference(_startedAt).inMinutes,
      exercises: <ExerciseLog>[
        for (final _ExerciseState e in _exercises!)
          ExerciseLog(
            exerciseId: e.block.exerciseId,
            sets: <LoggedSet>[
              for (final _SetRow r in e.rows)
                if (r.done && _parse(r.reps.text) > 0)
                  LoggedSet(
                    weightKg: _parse(r.weight.text),
                    reps: _parse(r.reps.text).round(),
                  ),
            ],
          ),
      ],
    );
    await ref.read(appStateProvider.notifier).logWorkout(log, habit);
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.loggerSaved)),
    );
    Navigator.of(context).pop(true);
  }

  Future<bool> _confirmDiscard() async {
    if (!_anyDone) return true;
    final AppLocalizations l10n = context.l10n;
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.loggerDiscardTitle),
        content: Text(l10n.loggerDiscardBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(110, 44),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.loggerDiscard),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<_ExerciseState> exercises = _exercises!;
    return PopScope(
      canPop: !_anyDone || _saving,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.workoutName(widget.workout.kind))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.xxl + 40,
          ),
          children: <Widget>[
            AppCard(
              color: AppColors.surfaceHigh,
              child: Row(
                children: <Widget>[
                  const Icon(Icons.trending_up,
                      size: 19, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Text(
                      l10n.loggerIntro,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (int i = 0; i < exercises.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                child: _ExerciseCard(
                  state: exercises[i],
                  onChanged: () => setState(() {}),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: FilledButton.icon(
              key: const Key('finish-workout'),
              onPressed: _saving ? null : _finish,
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              icon: const Icon(Icons.flag),
              label: Text(l10n.loggerFinish),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.state, required this.onChanged});

  final _ExerciseState state;
  final VoidCallback onChanged;

  String _adviceText(AppLocalizations l10n, NumberFormat format) {
    final SetRecommendation rec = state.recommendation;
    switch (rec.advice) {
      case ProgressionAdvice.firstTime:
        return l10n.loggerAdviceFirst(state.block.rir);
      case ProgressionAdvice.addWeight:
        return l10n.loggerAdviceAddWeight(format.format(rec.weightKg ?? 0));
      case ProgressionAdvice.addReps:
        return l10n.loggerAdviceAddReps;
      case ProgressionAdvice.hold:
        return l10n.loggerAdviceHold;
      case ProgressionAdvice.reduce:
        return l10n.loggerAdviceReduce(format.format(rec.weightKg ?? 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final format = NumberFormat.decimalPattern(l10n.localeName)
      ..maximumFractionDigits = 2;
    final ExerciseLog? last =
        state.history.isEmpty ? null : state.history.first;
    final bool bodyweight =
        kExerciseById[state.block.exerciseId]?.minEquipment ==
            EquipmentAccess.bodyweight;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.exerciseName(state.block.exerciseId),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            l10n.loggerTarget(state.block.repRange, state.block.rir),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (last != null)
            Text(
              l10n.loggerLastTime(last.sets
                  .map((LoggedSet s) => s.weightKg > 0
                      ? '${format.format(s.weightKg)} × ${s.reps}'
                      : '${s.reps}')
                  .join(', ')),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.trending_up, size: 16, color: AppColors.success),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  _adviceText(l10n, format),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.success, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (int i = 0; i < state.rows.length; i++)
            _SetRowView(
              index: i,
              row: state.rows[i],
              showWeight: !bodyweight,
              onChanged: onChanged,
            ),
          TextButton.icon(
            onPressed: () {
              final _SetRow previous = state.rows.last;
              state.rows.add(_SetRow(
                weight: previous.weight.text,
                reps: previous.reps.text,
              ));
              onChanged();
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.loggerAddSet),
          ),
        ],
      ),
    );
  }
}

class _SetRowView extends StatelessWidget {
  const _SetRowView({
    required this.index,
    required this.row,
    required this.showWeight,
    required this.onChanged,
  });

  final int index;
  final _SetRow row;
  final bool showWeight;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    InputDecoration decoration(String suffix) => InputDecoration(
          isDense: true,
          suffixText: suffix,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          border: const OutlineInputBorder(),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 52,
            child: Text(
              l10n.loggerSet(index + 1),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.textTertiary),
            ),
          ),
          if (showWeight) ...<Widget>[
            Expanded(
              child: TextField(
                controller: row.weight,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: decoration(l10n.loggerKg),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: TextField(
              controller: row.reps,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: decoration(l10n.loggerReps),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filledTonal(
            key: Key('set-done-${row.hashCode}'),
            isSelected: row.done,
            selectedIcon: const Icon(Icons.check, color: AppColors.ink),
            style: IconButton.styleFrom(
              backgroundColor:
                  row.done ? AppColors.success : AppColors.surfaceHigh,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              row.done = !row.done;
              onChanged();
            },
            icon: const Icon(Icons.check),
          ),
        ],
      ),
    );
  }
}
