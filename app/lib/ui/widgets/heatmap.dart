import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../theme/theme.dart';

/// A GitHub-style contribution grid over the challenge.
///
/// One column per week, seven rows Monday to Sunday, so the shape of a
/// person's week — the missing Sundays, the strong Mondays — is visible at a
/// glance instead of hidden in an average.
class ChallengeHeatmap extends StatelessWidget {
  const ChallengeHeatmap({
    super.key,
    required this.startDay,
    required this.today,
    required this.intensityForDay,
    this.weeks = 16,
    this.cellSize = 14,
    this.onTapDay,
  });

  final DayKey startDay;
  final DayKey today;

  /// 0 (nothing) to 1 (a full day).
  final double Function(DayKey day) intensityForDay;

  final int weeks;
  final double cellSize;
  final void Function(DayKey day)? onTapDay;

  @override
  Widget build(BuildContext context) {
    // Snap to the Monday of the challenge's first week so columns line up
    // with real calendar weeks.
    final DayKey firstColumn =
        startDay.addDays(1 - startDay.toDateTime().weekday);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (final String label in const <String>[
                'Mo', '', 'Mi', '', 'Fr', '', 'So'
              ])
                SizedBox(
                  height: cellSize + 3,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 9,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
          for (int week = 0; week < weeks; week++)
            Column(
              children: <Widget>[
                for (int weekday = 0; weekday < 7; weekday++)
                  _cell(firstColumn.addDays(week * 7 + weekday)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(DayKey day) {
    final bool inRange = !day.isBefore(startDay) && !day.isAfter(today);
    final double intensity = inRange ? intensityForDay(day) : 0;
    final Color color = inRange
        ? AppColors.heat[(intensity * (AppColors.heat.length - 1))
            .round()
            .clamp(0, AppColors.heat.length - 1)]
        : AppColors.heat.first.withValues(alpha: 0.35);

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: GestureDetector(
        onTap: inRange && onTapDay != null ? () => onTapDay!(day) : null,
        child: Container(
          width: cellSize,
          height: cellSize,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3.5),
            border: day == today
                ? Border.all(color: AppColors.textPrimary, width: 1.4)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Legend row for the heatmap.
class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text(
          'weniger',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.textTertiary, fontSize: 9.5),
        ),
        const SizedBox(width: 6),
        for (final Color color in AppColors.heat)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          'mehr',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.textTertiary, fontSize: 9.5),
        ),
      ],
    );
  }
}
