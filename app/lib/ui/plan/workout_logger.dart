import 'dart:async';

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
import 'workout_draft.dart';

/// One session, logged set by set.
///
/// Every exercise shows what was lifted last time and what to try today —
/// double progression: more reps at the same weight until the top of the
/// range, then more weight. Finishing writes the log and a tracked gym
/// check-in, which is worth more XP than a tick.
///
/// Until then the workout is a [WorkoutDraft] on the device, rewritten on
/// every change and offered again when the logger reopens.
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
  _SetRow({String weight = '', String reps = '', this.planned = true})
      : weight = TextEditingController(text: weight),
        reps = TextEditingController(text: reps),
        _prefillWeight = weight,
        _prefillReps = reps;

  final TextEditingController weight;
  final TextEditingController reps;
  bool done = false;

  /// False for a row added with "Add a set".
  final bool planned;

  /// What the logger proposed. Anything else in the fields is the user's.
  final String _prefillWeight;
  final String _prefillReps;

  /// Whether leaving now would lose something the user did.
  bool get edited =>
      done ||
      !planned ||
      weight.text != _prefillWeight ||
      reps.text != _prefillReps;

  DraftSet toDraft() =>
      DraftSet(weight: weight.text, reps: reps.text, done: done);

  void restore(DraftSet set) {
    weight.text = set.weight;
    reps.text = set.reps;
    done = set.done;
  }

  void dispose() {
    weight.dispose();
    reps.dispose();
  }
}

enum _Leave { stay, keep, discard }

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
  DateTime _startedAt = DateTime.now();
  List<_ExerciseState>? _exercises;
  bool _saving = false;

  late final WorkoutDraftStore _drafts = ref.read(workoutDraftStoreProvider);
  late final String _userId = ref.read(repositoryProvider).userId;

  /// Set once a stored draft was offered (or there was none). Until then
  /// nothing is written, so a draft from before cannot be overwritten by
  /// the prefill before the user had a say.
  bool _draftChecked = false;

  int get _session => widget.workout.sessionIndex;

  @override
  void initState() {
    super.initState();
    unawaited(_drafts.prune(_userId, widget.day.addDays(-1)));
  }

  List<_ExerciseState> _build(AppSnapshot? snapshot, String locale) {
    final format = NumberFormat.decimalPattern(locale)
      ..maximumFractionDigits = 2;
    return <_ExerciseState>[
      for (final PlannedSet block in widget.workout.blocks)
        () {
          final List<ExerciseLog> history = snapshot?.me
                  .historyOf(block.exerciseId, before: widget.day) ??
              const <ExerciseLog>[];
          final SetRecommendation rec = recommendNext(
            target: block,
            history: history,
            deload: widget.workout.isDeload,
          );
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

  /// Anything typed, ticked or added — ticked or not, it is the user's work.
  bool get _edited =>
      _exercises?.any((_ExerciseState e) => e.rows.any((_SetRow r) => r.edited)) ??
      false;

  double _parse(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.')) ?? 0;

  /// After every change: the draft on the device follows the screen.
  void _changed() {
    setState(() {});
    if (!_draftChecked) return;
    if (_edited) {
      unawaited(_drafts.save(_userId, widget.day, _session, _toDraft()));
    } else {
      unawaited(_drafts.clear(_userId, widget.day, _session));
    }
  }

  WorkoutDraft _toDraft() => WorkoutDraft(
        startedAt: _startedAt,
        exercises: <DraftExercise>[
          for (final _ExerciseState e in _exercises!)
            DraftExercise(
              exerciseId: e.block.exerciseId,
              sets: e.rows.map((_SetRow r) => r.toDraft()).toList(),
            ),
        ],
      );

  /// Offers a workout left unfinished on this day, for this session — the
  /// app was closed, or Android killed it in the background.
  Future<void> _offerDraft() async {
    final WorkoutDraft? draft =
        await _drafts.load(_userId, widget.day, _session);
    if (!mounted) return;
    if (draft == null || draft.exercises.isEmpty) {
      _draftChecked = true;
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool? resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.loggerResumeTitle),
        content: Text(l10n.loggerResumeBody(
          MaterialLocalizations.of(context)
              .formatTimeOfDay(TimeOfDay.fromDateTime(draft.startedAt)),
          draft.doneSets,
        )),
        actions: <Widget>[
          TextButton(
            key: const Key('draft-start-over'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.loggerStartOver),
          ),
          FilledButton(
            key: const Key('draft-resume'),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.loggerResume),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _draftChecked = true;
    if (resume ?? false) {
      setState(() => _restore(draft));
    } else {
      await _drafts.clear(_userId, widget.day, _session);
    }
  }

  void _restore(WorkoutDraft draft) {
    _startedAt = draft.startedAt;
    final List<DraftExercise> left = draft.exercises.toList();
    for (final _ExerciseState e in _exercises!) {
      // By movement, not position: the plan may have been edited since.
      final int at = left.indexWhere(
          (DraftExercise d) => d.exerciseId == e.block.exerciseId);
      if (at < 0) continue;
      final DraftExercise saved = left.removeAt(at);
      for (int i = 0; i < saved.sets.length; i++) {
        if (i >= e.rows.length) e.rows.add(_SetRow(planned: false));
        e.rows[i].restore(saved.sets[i]);
      }
    }
  }

  Future<void> _finish() async {
    final AppLocalizations l10n = context.l10n;
    if (!_anyDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loggerFinishNoSets)),
      );
      return;
    }
    final AppSnapshot? snapshot = ref.read(appStateProvider).valueOrNull;
    final Habit? habit =
        trainingHabitOf(snapshot?.challenge?.habits ?? const <Habit>[]);
    if (habit == null) return;

    setState(() => _saving = true);
    final WorkoutLog log = WorkoutLog(
      day: widget.day,
      kind: widget.workout.kind,
      sessionIndex: widget.workout.sessionIndex,
      deload: widget.workout.isDeload,
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
    await _drafts.clear(_userId, widget.day, _session);
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.loggerSaved)),
    );
    Navigator.of(context).pop(true);
  }

  /// Leaving with something entered: keep it for later (the default — it
  /// is on the device already), throw it away, or stay.
  Future<_Leave> _confirmLeave() async {
    final AppLocalizations l10n = context.l10n;
    final _Leave? choice = await showDialog<_Leave>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.loggerLeaveTitle),
        content: Text(l10n.loggerLeaveBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(_Leave.stay),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            key: const Key('logger-discard'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(_Leave.discard),
            child: Text(l10n.loggerDiscard),
          ),
          FilledButton(
            key: const Key('logger-keep'),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.of(context).pop(_Leave.keep),
            child: Text(l10n.loggerKeepForLater),
          ),
        ],
      ),
    );
    return choice ?? _Leave.stay;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<AppSnapshot> app = ref.watch(appStateProvider);
    // The prefill comes from the history: wait for it rather than settle
    // for "first time" on every exercise and never look again.
    if (_exercises == null && app.isLoading && !app.hasValue) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.workoutName(widget.workout.kind))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_exercises == null) {
      _exercises = _build(app.valueOrNull, l10n.localeName);
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerDraft());
    }
    final List<_ExerciseState> exercises = _exercises!;
    return PopScope(
      canPop: !_edited || _saving,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop) return;
        final _Leave choice = await _confirmLeave();
        if (choice == _Leave.stay || !context.mounted) return;
        if (choice == _Leave.discard) {
          await _drafts.clear(_userId, widget.day, _session);
        }
        if (context.mounted) Navigator.of(context).pop();
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
            if (widget.workout.isDeload)
              AppCard(
                key: const Key('logger-deload'),
                color: AppColors.social,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.self_improvement,
                        size: 20, color: AppColors.social),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(l10n.loggerDeloadTitle,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            l10n.loggerDeloadBody,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12.5,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
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
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                  onChanged: _changed,
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
    final double? weight = rec.weightKg;
    switch (rec.advice) {
      case ProgressionAdvice.firstTime:
        return l10n.loggerAdviceFirst(state.block.rir);
      case ProgressionAdvice.addWeight:
        return l10n.loggerAdviceAddWeight(format.format(weight ?? 0));
      case ProgressionAdvice.addReps:
        return weight == null
            ? l10n.loggerAdviceAddRepsBodyweight
            : l10n.loggerAdviceAddReps;
      case ProgressionAdvice.beyondRange:
        return l10n.loggerAdviceBeyondRange;
      case ProgressionAdvice.hold:
        return l10n.loggerAdviceHold;
      case ProgressionAdvice.reduce:
        return weight == null
            ? l10n.loggerAdviceReduceBodyweight
            : l10n.loggerAdviceReduce(format.format(weight));
      case ProgressionAdvice.deload:
        return weight == null
            ? l10n.loggerAdviceDeloadBodyweight
            : l10n.loggerAdviceDeload(format.format(weight));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final format = NumberFormat.decimalPattern(l10n.localeName)
      ..maximumFractionDigits = 2;
    final ExerciseLog? last =
        state.history.isEmpty ? null : state.history.first;
    // Body weight is the load; a weight entered is carried on top of it.
    final bool bodyweight =
        kExerciseById[state.block.exerciseId]?.isBodyweight ?? false;
    final bool deload =
        state.recommendation.advice == ProgressionAdvice.deload;
    final Color adviceColor = deload ? AppColors.social : AppColors.success;

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
                  .map((LoggedSet s) => s.weightKg <= 0
                      ? '${s.reps}'
                      : bodyweight
                          ? '+${format.format(s.weightKg)} × ${s.reps}'
                          : '${format.format(s.weightKg)} × ${s.reps}')
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
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  deload ? Icons.self_improvement : Icons.trending_up,
                  size: 16,
                  color: adviceColor,
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  _adviceText(l10n, format),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: adviceColor, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (int i = 0; i < state.rows.length; i++)
            _SetRowView(
              index: i,
              row: state.rows[i],
              addedLoad: bodyweight,
              onChanged: onChanged,
            ),
          TextButton.icon(
            onPressed: () {
              final _SetRow previous = state.rows.last;
              state.rows.add(_SetRow(
                weight: previous.weight.text,
                reps: previous.reps.text,
                planned: false,
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
    required this.addedLoad,
    required this.onChanged,
  });

  final int index;
  final _SetRow row;

  /// A bodyweight movement: the weight is optional and goes on top of the
  /// body — a belt on dips, dumbbells on lunges — so the empty field reads
  /// "+ kg" rather than asking for a number.
  final bool addedLoad;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    InputDecoration decoration(String suffix, {String? hint}) =>
        InputDecoration(
          isDense: true,
          suffixText: suffix,
          hintText: hint,
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
          Expanded(
            child: TextField(
              controller: row.weight,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (_) => onChanged(),
              decoration: decoration(
                l10n.loggerKg,
                hint: addedLoad ? l10n.loggerAddedLoadHint : l10n.loggerKg,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: row.reps,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (_) => onChanged(),
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
