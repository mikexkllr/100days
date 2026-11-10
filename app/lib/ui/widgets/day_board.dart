import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../theme/fire.dart';
import '../../theme/theme.dart';
import '../motion/motion.dart';

/// The days of the cycle [today] falls in, first to last, marked by the
/// same rules the streak counts with.
List<DayMark> cycleMarks(AppSnapshot snapshot) {
  final Challenge challenge = snapshot.challenge!;
  final DayKey first = cycleStart(challenge, snapshot.today);
  return <DayMark>[
    for (int i = 0; i < challenge.lengthDays; i++)
      dayMarkFor(
        challenge: challenge,
        day: first.addDays(i),
        today: snapshot.today,
        logsByDay: snapshot.me.logsByDay,
        frozenDays: snapshot.me.frozenDays,
      ),
  ];
}

/// Day 1 of the cycle [day] falls in.
DayKey cycleStart(Challenge challenge, DayKey day) => challenge.startDay
    .addDays(math.max(0, challenge.cycleOf(day)) * challenge.lengthDays);

/// The whole challenge on one board: a lamp for every day of the cycle.
///
/// A hundred lamps, lit one by one. A finished day burns in the colour of
/// the flame, a frozen one in ice, a missed one stays dark with a red rim,
/// and the days still to come wait as dim dots — with the milestone days
/// ringed, so you can see what you are walking towards.
class DayBoard extends StatelessWidget {
  const DayBoard({
    super.key,
    required this.marks,
    required this.fire,
    this.todayIndex,
    this.columns = 10,
    this.gap = 5,
    this.onTapDay,
  });

  final List<DayMark> marks;
  final Fire fire;

  /// Where today is on the board, or null if it is not on it.
  final int? todayIndex;
  final int columns;
  final double gap;

  /// Called with the index of a day that has happened.
  final ValueChanged<int>? onTapDay;

  @override
  Widget build(BuildContext context) {
    final int rows = (marks.length / columns).ceil();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double cell = (box.maxWidth - gap * (columns - 1)) / columns;
        final double height = rows * cell + (rows - 1) * gap;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: onTapDay == null
              ? null
              : (TapUpDetails details) {
                  final int column =
                      (details.localPosition.dx / (cell + gap)).floor();
                  final int row =
                      (details.localPosition.dy / (cell + gap)).floor();
                  final int index = row * columns + column;
                  if (column < 0 || column >= columns) return;
                  if (index < 0 || index >= marks.length) return;
                  final DayMark mark = marks[index];
                  if (mark == DayMark.upcoming || mark == DayMark.none) return;
                  onTapDay!(index);
                },
          child: AmbientClock(
            builder: (BuildContext context, double seconds, Widget? _) =>
                CustomPaint(
              size: Size(box.maxWidth, height),
              painter: _BoardPainter(
                marks: marks,
                fire: fire,
                todayIndex: todayIndex,
                columns: columns,
                gap: gap,
                pulse: 0.5 + 0.5 * math.sin(seconds * 3.2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.marks,
    required this.fire,
    required this.todayIndex,
    required this.columns,
    required this.gap,
    required this.pulse,
  });

  final List<DayMark> marks;
  final Fire fire;
  final int? todayIndex;
  final int columns;
  final double gap;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final double cell = (size.width - gap * (columns - 1)) / columns;
    final double r = cell / 2;
    // One gradient over the whole board, so the lit days read as one fire.
    final Paint lit = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[fire.light, fire.main, fire.far ?? fire.main],
      ).createShader(Offset.zero & size);
    final Paint ice = Paint()..color = AppColors.cool;
    final Paint dim = Paint()..color = Colors.white.withValues(alpha: 0.08);
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    for (int i = 0; i < marks.length; i++) {
      final Offset c = Offset(
        (i % columns) * (cell + gap) + r,
        (i ~/ columns) * (cell + gap) + r,
      );
      final bool milestone = kMilestoneDays.contains(i + 1);
      switch (marks[i]) {
        case DayMark.done:
          canvas.drawCircle(c, r, lit);
          if (milestone) {
            canvas.drawCircle(c, r * 0.36, Paint()..color = fire.on);
          }
        case DayMark.frozen:
          canvas.drawCircle(c, r, ice);
        case DayMark.missed:
          canvas.drawCircle(
            c,
            r - 0.7,
            ring..color = AppColors.danger.withValues(alpha: 0.6),
          );
        case DayMark.rest:
          canvas.drawCircle(
              c, r * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.3));
        case DayMark.open:
          break;
        case DayMark.upcoming:
        case DayMark.none:
          canvas.drawCircle(c, milestone ? r * 0.5 : r * 0.34, dim);
          if (milestone) {
            canvas.drawCircle(
              c,
              r - 0.7,
              ring..color = Colors.white.withValues(alpha: 0.26),
            );
          }
      }
      if (i == todayIndex && marks[i] != DayMark.done) {
        canvas.drawCircle(
          c,
          r - 1,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = fire.main.withValues(alpha: 0.6 + 0.4 * pulse),
        );
        canvas.drawCircle(
          c,
          r * 0.26,
          Paint()..color = fire.main.withValues(alpha: 0.5 + 0.5 * pulse),
        );
      } else if (i == todayIndex) {
        canvas.drawCircle(
          c,
          r + 2.2,
          ring..color = AppColors.textPrimary.withValues(alpha: 0.9),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) =>
      oldDelegate.pulse != pulse ||
      oldDelegate.fire != fire ||
      oldDelegate.todayIndex != todayIndex ||
      oldDelegate.marks.toString() != marks.toString();
}
