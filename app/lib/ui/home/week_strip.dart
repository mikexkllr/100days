import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../theme/theme.dart';
import '../motion/motion.dart';

/// Monday to Sunday as a chain of flames. Consecutive done days are linked,
/// so the one gap you are about to leave is impossible to miss.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.marks,
    required this.monday,
    required this.today,
    this.bubble = 36,
  });

  final List<DayMark> marks;
  final DayKey monday;
  final DayKey today;
  final double bubble;

  static bool _chains(DayMark mark) =>
      mark == DayMark.done || mark == DayMark.frozen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (int i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    l10n.weekdayLetters(monday.addDays(i).toDateTime().weekday),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: monday.addDays(i) == today
                              ? AppColors.flameSoft
                              : AppColors.textTertiary,
                          fontSize: 11,
                        ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: bubble + 6,
          child: CustomPaint(
            painter: _ChainPainter(
              links: <bool>[
                for (int i = 0; i < 6; i++)
                  _chains(marks[i]) && _chains(marks[i + 1]),
              ],
              bubble: bubble,
            ),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: _DayBubble(
                        mark: marks[i],
                        size: bubble,
                        isToday: monday.addDays(i) == today,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChainPainter extends CustomPainter {
  _ChainPainter({required this.links, required this.bubble});

  final List<bool> links;
  final double bubble;

  @override
  void paint(Canvas canvas, Size size) {
    final double cell = size.width / 7;
    final double y = size.height / 2;
    for (int i = 0; i < links.length; i++) {
      if (!links[i]) continue;
      final Rect bar = Rect.fromLTRB(
          cell * (i + 0.5), y - 4, cell * (i + 1.5), y + 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(4)),
        Paint()
          ..shader = const LinearGradient(
            colors: <Color>[AppColors.flame, AppColors.amber],
          ).createShader(bar),
      );
    }
  }

  @override
  bool shouldRepaint(_ChainPainter oldDelegate) =>
      oldDelegate.links.toString() != links.toString();
}

class _DayBubble extends StatelessWidget {
  const _DayBubble({
    required this.mark,
    required this.size,
    required this.isToday,
  });

  final DayMark mark;
  final double size;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final double s = isToday ? size + 4 : size;
    switch (mark) {
      case DayMark.done:
        return _filled(s, AppGradients.fire, Icons.local_fire_department,
            Colors.white, AppColors.flame);
      case DayMark.frozen:
        return _filled(s, AppGradients.ice, Icons.ac_unit, Colors.white,
            AppColors.ice);
      case DayMark.missed:
        return _plain(s, AppColors.surfaceHigh, Icons.close,
            AppColors.danger.withValues(alpha: 0.75));
      case DayMark.rest:
        return _plain(s, AppColors.surface, Icons.bedtime_outlined,
            AppColors.textTertiary);
      case DayMark.open:
        return AmbientClock(
          builder: (BuildContext context, double seconds, Widget? _) {
            final double pulse = 0.5 + 0.5 * math.sin(seconds * 4);
            return Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.flame.withValues(alpha: 0.08 + 0.08 * pulse),
                border: Border.all(color: AppColors.flame, width: 2.2),
                boxShadow: AppShadows.glow(AppColors.flame, strength: pulse),
              ),
              child: const Icon(Icons.local_fire_department_outlined,
                  size: 19, color: AppColors.flameSoft),
            );
          },
        );
      case DayMark.upcoming:
        return Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outline, width: 1.5),
          ),
        );
      case DayMark.none:
        return Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.outline,
          ),
        );
    }
  }

  Widget _filled(
      double s, Gradient gradient, IconData icon, Color fg, Color glow) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: AppShadows.glow(glow, strength: isToday ? 1.2 : 0.6),
      ),
      child: Icon(icon, size: s * 0.55, color: fg),
    );
  }

  Widget _plain(double s, Color fill, IconData icon, Color fg) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: AppColors.outline),
      ),
      child: Icon(icon, size: s * 0.45, color: fg),
    );
  }
}
