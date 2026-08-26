import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// One session, exercise by exercise.
class WorkoutDetailScreen extends StatelessWidget {
  const WorkoutDetailScreen({
    super.key,
    required this.workout,
    this.titleSuffix,
  });

  final Workout workout;
  final String? titleSuffix;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workoutName(workout.kind)),
        actions: <Widget>[
          if (titleSuffix != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(child: Pill(titleSuffix!)),
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
          AppCard(
            color: AppColors.surfaceHigh,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: StatTile(
                    value: '${workout.blocks.length}',
                    label: l10n.workoutExercises,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    value: '${workout.totalSets}',
                    label: l10n.workoutWorkingSets,
                    color: AppColors.flame,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    value: '${workout.estimatedMinutes}',
                    label: l10n.workoutMinutes,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < workout.blocks.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
              child: _ExerciseCard(index: i + 1, block: workout.blocks[i]),
            ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: AppColors.surfaceHigh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.workoutRpeTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.workoutRpeBody,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.index, required this.block});

  final int index;
  final PlannedSet block;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Exercise exercise = block.exercise;
    final String? cue = l10n.exerciseCue(exercise.id);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceHigh,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.flame),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.exerciseName(exercise.id),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      l10n.muscleName(exercise.primary),
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  value: '${block.sets}',
                  label: l10n.workoutSets,
                  color: AppColors.flame,
                ),
              ),
              Expanded(
                child: StatTile(value: block.repRange, label: l10n.workoutReps),
              ),
              Expanded(
                child: StatTile(
                  value: l10n.workoutRpe(block.rpe.toStringAsFixed(1)),
                  label: l10n.workoutIntensity,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: l10n.workoutRestSeconds(block.restSeconds),
                  label: l10n.workoutRest,
                ),
              ),
            ],
          ),
          if (cue != null) ...<Widget>[
            const Divider(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.lightbulb_outline,
                    size: 15, color: AppColors.lime),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    cue,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
