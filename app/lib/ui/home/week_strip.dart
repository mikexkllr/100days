import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../theme/theme.dart';
import '../motion/motion.dart';

/// Monday to Sunday as a row of gems. Done days glow in plasma and are
/// linked by a neon wire, so the one gap you are about to leave is
/// impossible to miss.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.marks,
    required this.monday,
    required this.today,
    this.cell = 38,
  });

  final List<DayMark> marks;
  final DayKey monday;
  final DayKey today;
  final double cell;

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
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                          fontSize: 10.5,
                        ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: cell + 8,
          child: CustomPaint(
            painter: _WirePainter(
              links: <bool>[
                for (int i = 0; i < 6; i++)
                  _chains(marks[i]) && _chains(marks[i + 1]),
              ],
            ),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: _Gem(
                        mark: marks[i],
                        size: cell,
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

class _WirePainter extends CustomPainter {
  _WirePainter({required this.links});

  final List<bool> links;

  @override
  void paint(Canvas canvas, Size size) {
    final double cell = size.width / 7;
    final double y = size.height / 2;
    for (int i = 0; i < links.length; i++) {
      if (!links[i]) continue;
      final Rect wire =
          Rect.fromLTRB(cell * (i + 0.5), y - 2.5, cell * (i + 1.5), y + 2.5);
      final Shader shader = const LinearGradient(
        colors: <Color>[AppColors.hot, AppColors.primary],
      ).createShader(wire);
      canvas.drawRRect(
        RRect.fromRectAndRadius(wire.inflate(3), const Radius.circular(6)),
        Paint()
          ..shader = shader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(wire, const Radius.circular(3)),
        Paint()..shader = shader,
      );
    }
  }

  @override
  bool shouldRepaint(_WirePainter oldDelegate) =>
      oldDelegate.links.toString() != links.toString();
}

class _Gem extends StatelessWidget {
  const _Gem({required this.mark, required this.size, required this.isToday});

  final DayMark mark;
  final double size;
  final bool isToday;

  BorderRadius get _radius => BorderRadius.circular(size * 0.34);

  @override
  Widget build(BuildContext context) {
    final double s = isToday ? size + 4 : size;
    switch (mark) {
      case DayMark.done:
        return _lit(s, AppGradients.plasma, Icons.local_fire_department,
            AppColors.primary);
      case DayMark.frozen:
        return _lit(s, AppGradients.cool, Icons.ac_unit, AppColors.cool);
      case DayMark.missed:
        return _glass(s, Icons.close, AppColors.danger.withValues(alpha: 0.8));
      case DayMark.rest:
        return _glass(s, Icons.bedtime_outlined, AppColors.textTertiary);
      case DayMark.open:
        return AmbientClock(
          builder: (BuildContext context, double seconds, Widget? _) {
            final double pulse = 0.5 + 0.5 * math.sin(seconds * 4);
            return Container(
              width: s,
              height: s,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: _radius,
                gradient: SweepGradient(
                  transform: GradientRotation(seconds * 2),
                  colors: const <Color>[
                    AppColors.hot,
                    AppColors.primary,
                    AppColors.social,
                    AppColors.hot,
                  ],
                ),
                boxShadow: AppShadows.glow(AppColors.primary, strength: 0.4 + 0.6 * pulse),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: _radius,
                  color: AppColors.surface,
                ),
                child: Icon(Icons.local_fire_department_outlined,
                    size: s * 0.5, color: AppColors.primarySoft),
              ),
            );
          },
        );
      case DayMark.upcoming:
        return Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            borderRadius: _radius,
            color: AppColors.glass,
            border: Border.all(color: AppColors.glassEdge),
          ),
        );
      case DayMark.none:
        return Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.glassEdge,
          ),
        );
    }
  }

  Widget _lit(double s, Gradient gradient, IconData icon, Color glow) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        borderRadius: _radius,
        gradient: gradient,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: AppShadows.glow(glow, strength: isToday ? 1.2 : 0.7),
      ),
      child: Icon(icon, size: s * 0.52, color: Colors.white),
    );
  }

  Widget _glass(double s, IconData icon, Color fg) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        borderRadius: _radius,
        color: AppColors.glass,
        border: Border.all(color: AppColors.glassEdge),
      ),
      child: Icon(icon, size: s * 0.45, color: fg),
    );
  }
}
