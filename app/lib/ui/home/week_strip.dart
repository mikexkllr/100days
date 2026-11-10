import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../theme/fire.dart';
import '../../theme/theme.dart';
import '../motion/motion.dart';

/// Monday to Sunday as a row of lamps. A finished day is lit, and lit days
/// next to each other are joined into one chain — so the gap you are about
/// to leave is impossible to miss. Tap a day to see what was logged on it.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.marks,
    required this.monday,
    required this.today,
    this.fire = const Fire(
      light: Color(0xFFFFA3BC),
      main: Color(0xFFFF5C8A),
      deep: Color(0xFFB3184A),
    ),
    this.lamp = 30,
    this.onTapDay,
  });

  final List<DayMark> marks;
  final DayKey monday;
  final DayKey today;
  final Fire fire;
  final double lamp;
  final ValueChanged<DayKey>? onTapDay;

  static bool _chains(DayMark mark) =>
      mark == DayMark.done || mark == DayMark.frozen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SizedBox(
      height: lamp + 26,
      child: CustomPaint(
        painter: _ChainPainter(
          links: <bool>[
            for (int i = 0; i < 6; i++)
              _chains(marks[i]) && _chains(marks[i + 1]),
          ],
          color: fire.main,
          lamp: lamp,
        ),
        child: Row(
          children: <Widget>[
            for (int i = 0; i < 7; i++)
              Expanded(
                child: _Day(
                  label: l10n
                      .weekdayLetters(monday.addDays(i).toDateTime().weekday),
                  mark: marks[i],
                  isToday: monday.addDays(i) == today,
                  fire: fire,
                  lamp: lamp,
                  onTap: onTapDay == null ||
                          marks[i] == DayMark.none ||
                          marks[i] == DayMark.upcoming
                      ? null
                      : () => onTapDay!(monday.addDays(i)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChainPainter extends CustomPainter {
  _ChainPainter({required this.links, required this.color, required this.lamp});

  final List<bool> links;
  final Color color;
  final double lamp;

  @override
  void paint(Canvas canvas, Size size) {
    final double cell = size.width / 7;
    final double y = size.height - lamp / 2;
    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.42)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < links.length; i++) {
      if (!links[i]) continue;
      canvas.drawLine(
        Offset(cell * (i + 0.5) + lamp / 2, y),
        Offset(cell * (i + 1.5) - lamp / 2, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ChainPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.links.toString() != links.toString();
}

class _Day extends StatelessWidget {
  const _Day({
    required this.label,
    required this.mark,
    required this.isToday,
    required this.fire,
    required this.lamp,
    required this.onTap,
  });

  final String label;
  final DayMark mark;
  final bool isToday;
  final Fire fire;
  final double lamp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: labelStyle(
              color: isToday ? AppColors.textPrimary : AppColors.textTertiary,
              size: 10.5,
            ),
          ),
          SizedBox.square(
            dimension: lamp,
            child: Center(child: DayLamp(mark: mark, fire: fire, size: lamp)),
          ),
        ],
      ),
    );
  }
}

/// One day as a lamp: lit, held in ice, missed, resting, waiting or still
/// to come.
class DayLamp extends StatelessWidget {
  const DayLamp({
    super.key,
    required this.mark,
    required this.fire,
    this.size = 30,
  });

  final DayMark mark;
  final Fire fire;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (mark) {
      case DayMark.done:
        return _filled(fire.gradient, fire.main, Icons.check_rounded, fire.on);
      case DayMark.frozen:
        return _filled(
            AppGradients.cool, AppColors.cool, Icons.ac_unit, AppColors.ink);
      case DayMark.missed:
        return _hollow(
          AppColors.danger.withValues(alpha: 0.5),
          Icon(Icons.close_rounded,
              size: size * 0.5, color: AppColors.danger.withValues(alpha: 0.9)),
        );
      case DayMark.rest:
        return Icon(Icons.bedtime_outlined,
            size: size * 0.52, color: AppColors.textTertiary);
      case DayMark.open:
        return AmbientClock(
          builder: (BuildContext context, double seconds, Widget? _) {
            final double pulse = 0.5 + 0.5 * math.sin(seconds * 3.2);
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: fire.main, width: 2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: fire.main.withValues(alpha: 0.15 + 0.3 * pulse),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: size * 0.2,
                  height: size * 0.2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fire.main.withValues(alpha: 0.5 + 0.5 * pulse),
                  ),
                ),
              ),
            );
          },
        );
      case DayMark.upcoming:
        return _hollow(Colors.white.withValues(alpha: 0.16), null);
      case DayMark.none:
        return Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.18),
          ),
        );
    }
  }

  Widget _filled(Gradient gradient, Color glow, IconData icon, Color on) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: <BoxShadow>[
          BoxShadow(color: glow.withValues(alpha: 0.4), blurRadius: 10),
        ],
      ),
      child: Icon(icon, size: size * 0.6, color: on),
    );
  }

  Widget _hollow(Color border, Widget? child) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.4),
      ),
      child: child,
    );
  }
}
