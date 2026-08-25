import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import '../widgets/heatmap.dart';

/// The receipts.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppSnapshot> async = ref.watch(appStateProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) => Center(child: Text('$error')),
      data: (AppSnapshot snapshot) {
        final Challenge challenge = snapshot.challenge!;
        final StreakStats streak = snapshot.me.streak;
        final int xp = snapshot.me.lifetimeXp;
        final int level = levelForXp(xp);

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: StatTile(
                          value: '${streak.current}',
                          label: 'Aktueller Streak',
                          color: AppColors.flame,
                          icon: Icons.local_fire_department,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${streak.longest}',
                          label: 'Längster Streak',
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.lg),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: StatTile(
                          value: '${streak.completedDays}',
                          label: 'Volle Tage',
                          color: AppColors.lime,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value:
                              '${(streak.completionRate * 100).round()} %',
                          label: 'Trefferquote',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SectionHeader('Level'),
            _LevelCard(xp: xp, level: level),
            SectionHeader(
              'Verlauf',
              subtitle: 'Seit ${challenge.startDay}',
            ),
            AppCard(
              child: Column(
                children: <Widget>[
                  ChallengeHeatmap(
                    startDay: challenge.startDay,
                    today: snapshot.today,
                    weeks: math.max(
                      16,
                      (snapshot.today.differenceInDays(challenge.startDay) ~/ 7)
                          + 2,
                    ),
                    intensityForDay: (DayKey day) =>
                        _intensity(snapshot, challenge, day),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const HeatmapLegend(),
                ],
              ),
            ),
            const SectionHeader('XP der letzten Wochen'),
            AppCard(child: _WeeklyXpChart(snapshot: snapshot)),
            const SectionHeader('Pro Gewohnheit'),
            for (final Habit habit in challenge.habits)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _HabitStatRow(
                  habit: habit,
                  streak: snapshot.me.habitStreaks[habit.id] ?? 0,
                  totalDone: _countDone(snapshot, habit),
                  challenge: challenge,
                  today: snapshot.today,
                ),
              ),
          ],
        );
      },
    );
  }

  double _intensity(AppSnapshot snapshot, Challenge challenge, DayKey day) {
    final DayLog? log = snapshot.me.logsByDay[day.toString()];
    if (log == null || log.entries.isEmpty) return 0;
    if (log.hasRelapse) return 0.25;
    final List<Habit> required = requiredHabitsOn(challenge, day);
    final int denominator =
        required.isEmpty ? challenge.habits.length : required.length;
    if (denominator == 0) return 0;
    final int done = log.entries.where((CheckIn e) => !e.relapse).length;
    return (done / denominator).clamp(0.25, 1.0);
  }

  int _countDone(AppSnapshot snapshot, Habit habit) {
    var count = 0;
    for (final DayLog log in snapshot.me.logsByDay.values) {
      final CheckIn? entry = log.entryFor(habit.id);
      if (entry != null && !entry.relapse && entry.value >= habit.target) {
        count++;
      }
    }
    return count;
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.xp, required this.level});

  final int xp;
  final int level;

  @override
  Widget build(BuildContext context) {
    final int floor = xpRequiredForLevel(level);
    final int ceil = xpRequiredForLevel(level + 1);
    final double progress = levelProgress(xp);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Level $level',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              Pill('$xp XP', color: AppColors.lime, filled: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadius.pill,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.surfaceHigh,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.lime),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Noch ${ceil - xp} XP bis Level ${level + 1} '
            '(${xp - floor} / ${ceil - floor})',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _WeeklyXpChart extends StatelessWidget {
  const _WeeklyXpChart({required this.snapshot});

  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    // Last eight ISO weeks, oldest first.
    final List<String> weeks = <String>[
      for (int i = 7; i >= 0; i--)
        snapshot.today.addDays(-i * 7).isoWeekKey,
    ];
    final List<int> values =
        weeks.map(snapshot.me.xpInWeek).toList(growable: false);
    final int max = values.fold(0, math.max);

    if (max == 0) {
      return Text(
        'Noch keine XP. Die kommen mit dem ersten Haken.',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.textSecondary),
      );
    }

    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < weeks.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      values[i] == 0 ? '' : '${values[i]}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 9,
                          ),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: values[i] / max),
                      duration: Duration(milliseconds: 400 + i * 60),
                      curve: Curves.easeOutCubic,
                      builder:
                          (BuildContext context, double value, Widget? _) =>
                              Container(
                        height: math.max(4, value * 84),
                        decoration: BoxDecoration(
                          color: i == weeks.length - 1
                              ? AppColors.flame
                              : AppColors.flame.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      weeks[i].split('-W').last,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 9,
                          ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HabitStatRow extends StatelessWidget {
  const _HabitStatRow({
    required this.habit,
    required this.streak,
    required this.totalDone,
    required this.challenge,
    required this.today,
  });

  final Habit habit;
  final int streak;
  final int totalDone;
  final Challenge challenge;
  final DayKey today;

  @override
  Widget build(BuildContext context) {
    final int elapsed =
        math.max(1, today.differenceInDays(challenge.startDay) + 1);
    final int scheduled = habit.kind == HabitKind.abstain
        ? elapsed
        : math.max(1, (elapsed * habit.daysPerWeek / 7).round());
    final double rate = (totalDone / scheduled).clamp(0.0, 1.0);

    return AppCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(habit.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Text(habit.displayTitle,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Text(
                '$streak 🔥',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          ClipRRect(
            borderRadius: AppRadius.pill,
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 7,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation<Color>(
                rate > 0.75
                    ? AppColors.lime
                    : rate > 0.4
                        ? AppColors.flame
                        : AppColors.danger,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$totalDone von $scheduled geplanten Tagen '
              '(${(rate * 100).round()} %)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
