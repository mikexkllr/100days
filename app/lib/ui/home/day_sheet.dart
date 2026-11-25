import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/fire.dart';
import '../../theme/theme.dart';
import '../nutrition/diary_view.dart';
import '../widgets/app_card.dart';
import 'today.dart';
import 'week_strip.dart';

/// What happened on one day: its mark, every habit that was scheduled and
/// what was logged for it, and the XP the day scored.
///
/// Every row that can still change offers how: today's habits a plain
/// check-in, yesterday's a late one, and nutrition the food diary of that
/// day. A day that is over says so, instead of rows that ignore a tap.
Future<void> showDaySheet(
  BuildContext context, {
  required AppSnapshot snapshot,
  required DayKey day,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => DaySheet(snapshot: snapshot, day: day),
    );

class DaySheet extends ConsumerWidget {
  const DaySheet({super.key, required this.snapshot, required this.day});

  final AppSnapshot snapshot;
  final DayKey day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    // Live, so a habit logged late from here shows at once.
    final AppSnapshot snapshot =
        ref.watch(appStateProvider).valueOrNull ?? this.snapshot;
    final bool isToday = day == snapshot.today;
    // Yesterday — and only yesterday — can still be logged: done, but not
    // ticked before midnight. Friends see it as logged late.
    final bool canLogLate = day == snapshot.today.addDays(-1) &&
        !day.isBefore(snapshot.challenge!.startDay);
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
    final bool hasDiary = snapshot.plan?.nutrition != null;
    final AppController controller = ref.read(appStateProvider.notifier);

    /// What a row offers, if anything can still be done about it.
    _RowAction? actionFor(Habit habit) {
      if (isHabitDone(habit, log)) return null;
      // An admitted relapse stands; the row on Today can take it back.
      if (isToday && !(log?.entryFor(habit.id)?.relapse ?? false)) {
        return _RowAction(
          key: Key('day-check-in-${habit.id}'),
          label: habit.kind == HabitKind.abstain
              ? l10n.tileCleanToday
              : l10n.tileCheckOff,
          onPressed: () => controller.checkIn(habit),
        );
      }
      if (canLogLate) {
        return _RowAction(
          key: Key('log-late-${habit.id}'),
          label: l10n.dayLogLate,
          onPressed: () => controller.checkInOn(habit, day),
        );
      }
      return null;
    }

    /// Meals are logged in the diary — a photo is enough — and the diary
    /// closes the day: the nutrition row leads there, on any day.
    VoidCallback? diaryFor(Habit habit) =>
        habit.category == HabitCategory.nutrition && hasDiary
            ? () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => DiaryScreen(day: day),
                  ),
                )
            : null;

    final bool openLeft = scheduled.any((Habit h) => !isHabitDone(h, log));
    final int xp = snapshot.me.xpByDay[day.toString()] ?? 0;

    // Scrolls when a long list of habits is taller than the sheet may be.
    return SafeArea(
      child: SingleChildScrollView(
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
              _HabitLine(
                habit: habit,
                entry: log?.entryFor(habit.id),
                fire: fire,
                action: actionFor(habit),
                onOpenDiary: diaryFor(habit),
              ),
            if (openLeft && !isToday) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                canLogLate ? l10n.dayLogLateNote : l10n.dayOverNote,
                key: const Key('day-note'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 12.5,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A button beside a row: what can still be done for that habit that day.
class _RowAction {
  const _RowAction({
    required this.key,
    required this.label,
    required this.onPressed,
  });

  final Key key;
  final String label;
  final VoidCallback onPressed;
}

class _HabitLine extends StatelessWidget {
  const _HabitLine({
    required this.habit,
    required this.entry,
    required this.fire,
    this.action,
    this.onOpenDiary,
  });

  final Habit habit;
  final CheckIn? entry;
  final Fire fire;

  /// Set when something can still be done for the habit on this day.
  final _RowAction? action;

  /// Set on the nutrition row of someone who keeps a diary.
  final VoidCallback? onOpenDiary;

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
          // A long label on a narrow phone gives way to the habit's name
          // rather than pushing the row off the screen.
          if (action != null)
            Flexible(
              child: TextButton(
                key: action!.key,
                onPressed: action!.onPressed,
                child: Text(
                  action!.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          else if (onOpenDiary != null)
            Flexible(
              child: TextButton.icon(
                key: Key('day-diary-${habit.id}'),
                onPressed: onOpenDiary,
                icon: const Icon(Icons.restaurant_menu, size: 18),
                label: Text(
                  l10n.dayOpenDiary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          else
            Text(
              detail,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          // Beside a check-in, the way to the meals is the icon alone.
          if (action != null && onOpenDiary != null)
            IconButton(
              key: Key('day-diary-${habit.id}'),
              tooltip: l10n.dayOpenDiary,
              onPressed: onOpenDiary,
              icon: const Icon(Icons.restaurant_menu, size: 20),
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
