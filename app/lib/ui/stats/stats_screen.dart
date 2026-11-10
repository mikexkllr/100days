import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/fire.dart';
import '../../theme/theme.dart';
import '../home/day_sheet.dart';
import '../home/flame_evolution_sheet.dart';
import '../home/week_strip.dart';
import '../mascot/flame_painter.dart';
import '../widgets/app_card.dart';
import '../widgets/day_board.dart';

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
        final AppLocalizations l10n = context.l10n;
        final Challenge challenge = snapshot.challenge!;
        final StreakStats streak = snapshot.me.streak;
        final int xp = snapshot.me.lifetimeXp;
        final int level = levelForXp(xp);

        final Fire fire = Fire.ofStreak(streak.current);

        return ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            _FlameCard(streak: streak.current, fire: fire),
            const SizedBox(height: AppSpacing.md),
            _BoardCard(snapshot: snapshot, fire: fire),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: StatTile(
                          value: '${streak.current}',
                          label: l10n.statsCurrentStreak,
                          color: fire.light,
                          icon: Icons.local_fire_department,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${streak.longest}',
                          label: l10n.statsLongestStreak,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.lg + 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: StatTile(
                          value: '${streak.completedDays}',
                          label: l10n.statsFullDays,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: l10n.statsPercent(
                              '${(streak.completionRate * 100).round()}'),
                          label: l10n.statsHitRate,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SectionHeader(l10n.statsLevel),
            _LevelCard(xp: xp, level: level),
            SectionHeader(l10n.statsWeeklyXp),
            AppCard(child: _WeeklyXpChart(snapshot: snapshot)),
            SectionHeader(l10n.statsPerHabit),
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

/// The current form of the flame and the way to the next one.
class _FlameCard extends StatelessWidget {
  const _FlameCard({required this.streak, required this.fire});

  final int streak;
  final Fire fire;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final FlameStage stage = flameStageFor(streak);
    final FlameStage? next = stage.next;
    final int? toNext = daysToNextStage(streak);
    return AppCard(
      onTap: () => showFlameEvolution(context, streak: streak),
      child: Row(
        children: <Widget>[
          CustomPaint(
            size: const Size.square(84),
            painter: FlamePainter(
              stage: stage,
              mood: MascotMood.happy,
              seconds: 1.2,
              blink: false,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.statsFlameTitle.toUpperCase(), style: labelStyle()),
                const SizedBox(height: 2),
                Text(l10n.stageName(stage),
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  next == null || toNext == null
                      ? l10n.stageFinal
                      : l10n.stageNext(l10n.stageName(next), toNext),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                FireBar(value: stageProgress(streak), fire: fire),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

/// A bar that fills with fire.
class FireBar extends StatelessWidget {
  const FireBar({
    super.key,
    required this.value,
    required this.fire,
    this.height = 6,
  });

  final double value;
  final Fire fire;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.pill,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const ColoredBox(color: AppColors.glassHigh),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.02, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: fire.sweep),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The cycle as a board of lamps, ten by ten, with what the marks mean and
/// the next milestone on the way. Tap a day to see what was logged on it.
class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.snapshot, required this.fire});

  final AppSnapshot snapshot;
  final Fire fire;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Challenge challenge = snapshot.challenge!;
    final List<DayMark> marks = cycleMarks(snapshot);
    final int done = marks.where((DayMark m) => m == DayMark.done).length;
    final int dayInCycle = challenge.dayInCycle(snapshot.today);
    final DayKey first = cycleStart(challenge, snapshot.today);
    int? milestone;
    for (final int m in kMilestoneDays) {
      if (m > dayInCycle && m <= challenge.lengthDays) {
        milestone = m;
        break;
      }
    }
    final TextStyle? note = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.35,
        );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.boardTitle(challenge.lengthDays),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Flexible(
                child: Text(
                  l10n.boardSummary(
                      done, math.max(0, challenge.lengthDays - dayInCycle)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: note?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DayBoard(
            marks: marks,
            fire: fire,
            todayIndex: dayInCycle - 1,
            onTapDay: (int index) => showDaySheet(
              context,
              snapshot: snapshot,
              day: first.addDays(index),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final DayMark mark in const <DayMark>[
                DayMark.done,
                DayMark.frozen,
                DayMark.missed,
                DayMark.rest,
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox.square(
                      dimension: 16,
                      child: Center(
                        child: mark == DayMark.done
                            ? Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: fire.gradient,
                                ),
                              )
                            : DayLamp(mark: mark, fire: fire, size: 16),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(l10n.dayMarkLabel(mark),
                        style: note?.copyWith(fontSize: 12)),
                  ],
                ),
            ],
          ),
          const Divider(height: AppSpacing.lg + 4),
          if (milestone != null) ...<Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.flag_outlined,
                    size: 17, color: AppColors.textPrimary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.boardMilestone(milestone, milestone - dayInCycle),
                    style: note?.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.auto_awesome,
                    size: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.skyStars(snapshot.me.streak.completedDays),
                  style: note,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.xp, required this.level});

  final int xp;
  final int level;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final int floor = xpRequiredForLevel(level);
    final int ceil = xpRequiredForLevel(level + 1);
    final double progress = levelProgress(xp);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(l10n.statsLevelNumber(level),
                  style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              Pill(l10n.homeXp(xp), color: AppColors.reward, filled: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadius.pill,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.glassHigh,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.reward),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.statsXpToNextLevel(
                ceil - xp, level + 1, xp - floor, ceil - floor),
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
        context.l10n.statsNoXpYet,
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
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(6),
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
    final AppLocalizations l10n = context.l10n;
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
                child: Text(l10n.habitLabel(habit),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              StreakCount(streak),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          ClipRRect(
            borderRadius: AppRadius.pill,
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 7,
              backgroundColor: AppColors.glassHigh,
              valueColor: AlwaysStoppedAnimation<Color>(
                rate > 0.75
                    ? AppColors.success
                    : rate > 0.4
                        ? AppColors.primarySoft
                        : AppColors.danger,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.statsHabitProgress(
                  totalDone, scheduled, (rate * 100).round()),
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
