import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../theme/theme.dart';
import '../mascot/flame_mascot.dart';
import '../motion/motion.dart';

/// The cycle as a ring of fire around Funki.
///
/// The arc is how far through the current cycle you are; the dots on it are
/// the milestone days — gold once passed, the next one pulsing. The flame in
/// the middle is the streak itself.
class StreakRing extends StatelessWidget {
  const StreakRing({
    super.key,
    required this.progress,
    required this.dayInCycle,
    required this.cycleLength,
    required this.stage,
    required this.mood,
    this.atRisk = false,
    this.size = 260,
    this.onPoke,
    this.mascotLabel,
  });

  /// 0..1 through the current cycle.
  final double progress;
  final int dayInCycle;
  final int cycleLength;
  final FlameStage stage;
  final MascotMood mood;
  final bool atRisk;
  final double size;
  final ValueChanged<int>? onPoke;
  final String? mascotLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double value, Widget? _) =>
                  AmbientClock(
                builder: (BuildContext context, double seconds, Widget? _) =>
                    CustomPaint(
                  painter: _RingPainter(
                    progress: value,
                    dayInCycle: dayInCycle,
                    cycleLength: cycleLength,
                    seconds: seconds,
                    headColor: atRisk ? AppColors.danger : AppColors.spark,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: size * 0.04),
            child: FlameMascot(
              stage: stage,
              mood: mood,
              size: size * 0.74,
              onPoke: onPoke,
              semanticLabel: mascotLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.dayInCycle,
    required this.cycleLength,
    required this.seconds,
    required this.headColor,
  });

  final double progress;
  final int dayInCycle;
  final int cycleLength;
  final double seconds;
  final Color headColor;

  static const double _stroke = 13;
  static const double _start = -math.pi / 2;

  Offset _onRing(Offset center, double radius, double fraction) {
    final double a = _start + math.pi * 2 * fraction;
    return center + Offset(math.cos(a), math.sin(a)) * radius;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2 - _stroke;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = AppColors.surfaceHigh,
    );
    // A thin inner rim, so the track reads as a groove.
    canvas.drawCircle(
      center,
      radius - _stroke / 2 - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.outline.withValues(alpha: 0.6),
    );

    if (progress > 0) {
      final Shader shader = const SweepGradient(
        transform: GradientRotation(_start),
        colors: <Color>[
          AppColors.flameHot,
          AppColors.flame,
          AppColors.amber,
          AppColors.spark,
        ],
        stops: <double>[0, 0.35, 0.75, 1],
      ).createShader(rect);
      final double sweep = math.pi * 2 * progress;
      canvas.drawArc(
        rect,
        _start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke + 8
          ..strokeCap = StrokeCap.round
          ..shader = shader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawArc(
        rect,
        _start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..shader = shader,
      );
    }

    // Milestones on the ring: gold when passed, the next one pulsing.
    int? next;
    for (final int m in kMilestoneDays) {
      if (m > cycleLength) break;
      if (m > dayInCycle && next == null) next = m;
    }
    final double pulse = 0.5 + 0.5 * math.sin(seconds * 4);
    for (final int m in kMilestoneDays) {
      if (m > cycleLength) break;
      final Offset p = _onRing(center, radius, m / cycleLength);
      if (m <= dayInCycle) {
        canvas.drawCircle(
            p,
            7,
            Paint()
              ..color = AppColors.gold.withValues(alpha: 0.6)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        canvas.drawCircle(p, 4.2, Paint()..color = const Color(0xFFFFF4C2));
      } else if (m == next) {
        canvas.drawCircle(
          p,
          5.5 + pulse * 2.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.35 + 0.5 * pulse),
        );
        canvas.drawCircle(p, 3.2, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(p, 2.6, Paint()..color = AppColors.textTertiary);
      }
    }

    // The comet head where the arc ends.
    if (progress > 0) {
      final Offset head = _onRing(center, radius, progress);
      canvas.drawCircle(
        head,
        11 + pulse * 3,
        Paint()
          ..color = headColor.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(head, 5.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.seconds != seconds ||
      oldDelegate.dayInCycle != dayInCycle ||
      oldDelegate.headColor != headColor;
}
