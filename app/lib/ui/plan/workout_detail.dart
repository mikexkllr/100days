import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(workout.nameDe),
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
                    label: 'Übungen',
                  ),
                ),
                Expanded(
                  child: StatTile(
                    value: '${workout.totalSets}',
                    label: 'Arbeitssätze',
                    color: AppColors.flame,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    value: '${workout.estimatedMinutes}',
                    label: 'Minuten',
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
                Text('RPE verstehen',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'RPE 8 heißt: nach dem Satz hättest du noch zwei saubere '
                  'Wiederholungen geschafft. Wähle das Gewicht so, dass das '
                  'stimmt — nicht das, was letzte Woche im Plan stand.',
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
    final Exercise exercise = block.exercise;
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
                    Text(exercise.nameDe,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      _muscleLabel(exercise.primary),
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
                  label: 'Sätze',
                  color: AppColors.flame,
                ),
              ),
              Expanded(
                child: StatTile(value: block.repRange, label: 'Wdh.'),
              ),
              Expanded(
                child: StatTile(
                  value: 'RPE ${block.rpe.toStringAsFixed(1)}',
                  label: 'Intensität',
                ),
              ),
              Expanded(
                child: StatTile(
                  value: '${block.restSeconds}s',
                  label: 'Pause',
                ),
              ),
            ],
          ),
          if (exercise.cueDe != null) ...<Widget>[
            const Divider(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.lightbulb_outline,
                    size: 15, color: AppColors.lime),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    exercise.cueDe!,
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

  String _muscleLabel(MuscleGroup group) {
    switch (group) {
      case MuscleGroup.quads:
        return 'Quadrizeps';
      case MuscleGroup.hamstrings:
        return 'Beinbeuger';
      case MuscleGroup.glutes:
        return 'Gesäß';
      case MuscleGroup.calves:
        return 'Waden';
      case MuscleGroup.chest:
        return 'Brust';
      case MuscleGroup.back:
        return 'Rücken';
      case MuscleGroup.shoulders:
        return 'Schultern';
      case MuscleGroup.biceps:
        return 'Bizeps';
      case MuscleGroup.triceps:
        return 'Trizeps';
      case MuscleGroup.core:
        return 'Rumpf';
      case MuscleGroup.fullBody:
        return 'Ganzkörper';
    }
  }
}
