import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../theme/fire.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'week_strip.dart';

/// What happened on one day: its mark, every habit that was scheduled and
/// what was logged for it, and the XP the day scored.
Future<void> showDaySheet(
  BuildContext context, {
  required AppSnapshot snapshot,
  required DayKey day,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => DaySheet(snapshot: snapshot, day: day),
    );

class DaySheet extends StatelessWidget {
  const DaySheet({super.key, required this.snapshot, required this.day});

  final AppSnapshot snapshot;
  final DayKey day;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Challenge challenge = snapshot.challenge!;
    final DayLog? log = snapshot.me.logsByDay[day.toString()];
    final DayMark mark = dayMarkFor(
      challenge: challenge,
      day: day,
      today: snapshot.today,
      logsByDay: snapshot.me.logsByDay,
      frozenDays: snapshot.me.frozenDays,
    );
    final Fire fire = Fire.ofStreak(snapshot.me.streak.current);
    final List<Habit> scheduled = requiredHabitsOn(challenge, day);
    // What was logged on top of the plan still belongs to the day.
    final List<Habit> extra = <Habit>[
      for (final Habit habit in challenge.habits)
        if (!scheduled.contains(habit) && log?.entryFor(habit.id) != null)
          habit,
    ];
    final int xp = snapshot.me.xpByDay[day.toString()] ?? 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox.square(
                  dimension: 40,
                  child: Center(
                    child: DayLamp(mark: mark, fire: fire, size: 36),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.dayMarkLabel(mark),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${l10n.friendsDayNumber(challenge.dayNumber(day))} · '
                        '${MaterialLocalizations.of(context).formatFullDate(day.toDateTime())}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                      ),
                    ],
                  ),
                ),
                if (xp > 0)
                  Pill(l10n.homeXp(xp), color: AppColors.reward, filled: true),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (scheduled.isEmpty && extra.isEmpty)
              Text(
                l10n.homeRestDay,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            for (final Habit habit in <Habit>[...scheduled, ...extra])
              _HabitLine(habit: habit, entry: log?.entryFor(habit.id), fire: fire),
          ],
        ),
      ),
    );
  }
}

class _HabitLine extends StatelessWidget {
  const _HabitLine({
    required this.habit,
    required this.entry,
    required this.fire,
  });

  final Habit habit;
  final CheckIn? entry;
  final Fire fire;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool relapse = entry?.relapse ?? false;
    final bool done = entry != null && !relapse && entry!.value >= habit.target;
    final bool amount = habit.definition.unit != HabitUnit.done;
    final String detail = relapse
        ? l10n.tileRelapse
        : entry == null
            ? l10n.dayNotLogged
            : amount
                ? l10n.formatTarget(habit, value: entry!.value)
                : l10n.tileDone;
    final Color color = relapse
        ? AppColors.danger
        : done
            ? fire.light
            : AppColors.textTertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 30,
            child: Text(habit.emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.habitLabel(habit),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 6),
          Icon(
            relapse
                ? Icons.restart_alt
                : done
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
            size: 20,
            color: color,
          ),
        ],
      ),
    );
  }
}
