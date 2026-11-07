import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../theme/theme.dart';
import '../mascot/flame_mascot.dart';
import '../motion/motion.dart';

/// Funki in orbit.
///
/// Funki floats in a glowing orb. Around it runs the orbit of the current
/// cycle: the comet is today, its trail is how far you have come, and the
/// planets on the orbit are the milestone days — lit once passed, the next
/// one pulsing. A dashed inner ring turns slowly, so the whole thing hums.
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
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 1600),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double value, Widget? _) =>
            AmbientClock(
          builder: (BuildContext context, double seconds, Widget? mascot) =>
              Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _OrbitPainter(
                    progress: value,
                    dayInCycle: dayInCycle,
                    cycleLength: cycleLength,
                    seconds: seconds,
                    atRisk: atRisk,
                  ),
                ),
              ),
              // Funki floats: a slow bob inside the orb.
              Transform.translate(
                offset: Offset(0, math.sin(seconds * 1.6) * size * 0.015),
                child: mascot,
              ),
            ],
          ),
          child: FlameMascot(
            stage: stage,
            mood: mood,
            size: size * 0.66,
            onPoke: onPoke,
            semanticLabel: mascotLabel,
          ),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({
    required this.progress,
    required this.dayInCycle,
    required this.cycleLength,
    required this.seconds,
    required this.atRisk,
  });

  final double progress;
  final int dayInCycle;
  final int cycleLength;
  final double seconds;
  final bool atRisk;

  static const double _start = -math.pi / 2;

  Offset _on(Offset center, double radius, double fraction) {
    final double a = _start + math.pi * 2 * fraction;
    return center + Offset(math.cos(a), math.sin(a)) * radius;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double orbit = size.width / 2 - 9;
    final double pulse = 0.5 + 0.5 * math.sin(seconds * 3.2);

    // The orb Funki floats in.
    final double orb = size.width * 0.37;
    canvas.drawCircle(
      center,
      orb,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            AppColors.primary.withValues(alpha: 0.42),
            AppColors.hot.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.65, 1],
        ).createShader(Rect.fromCircle(center: center, radius: orb)),
    );
    canvas.drawCircle(
      center,
      orb,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = SweepGradient(
          transform: GradientRotation(seconds * 0.4),
          colors: <Color>[
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.02),
            Colors.white.withValues(alpha: 0.35),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: orb)),
    );

    // The dashed inner ring, turning.
    final double dashes = size.width * 0.43;
    final Paint dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primarySoft.withValues(alpha: 0.28);
    const int count = 36;
    for (int i = 0; i < count; i++) {
      final double a = seconds * 0.18 + i * math.pi * 2 / count;
      canvas.drawArc(Rect.fromCircle(center: center, radius: dashes), a,
          math.pi * 2 / count * 0.45, false, dash);
    }

    // The orbit track.
    canvas.drawCircle(
      center,
      orbit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = Colors.white.withValues(alpha: 0.07),
    );

    final Rect rect = Rect.fromCircle(center: center, radius: orbit);
    if (progress > 0) {
      final Shader shader = const SweepGradient(
        transform: GradientRotation(_start),
        colors: <Color>[
          AppColors.hot,
          Color(0xFFD946EF),
          AppColors.primary,
          AppColors.social,
          AppColors.reward,
        ],
        stops: <double>[0, 0.25, 0.5, 0.75, 1],
      ).createShader(rect);
      final double sweep = math.pi * 2 * progress;
      canvas.drawArc(
        rect,
        _start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..shader = shader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawArc(
        rect,
        _start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..shader = shader,
      );
    }

    // Milestones as planets.
    int? next;
    for (final int m in kMilestoneDays) {
      if (m > cycleLength) break;
      if (m > dayInCycle && next == null) next = m;
    }
    for (final int m in kMilestoneDays) {
      if (m > cycleLength) break;
      final Offset p = _on(center, orbit, m / cycleLength);
      if (m <= dayInCycle) {
        canvas.drawCircle(
          p,
          8,
          Paint()
            ..color = AppColors.reward.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawCircle(
          p,
          4.6,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.4, -0.4),
              colors: <Color>[Colors.white, AppColors.reward],
            ).createShader(Rect.fromCircle(center: p, radius: 4.6)),
        );
      } else if (m == next) {
        canvas.drawCircle(
          p,
          6 + pulse * 3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = AppColors.glow.withValues(alpha: 0.3 + 0.6 * pulse),
        );
        canvas.drawCircle(p, 3.4, Paint()..color = AppColors.glow);
      } else {
        canvas.drawCircle(
            p, 2.8, Paint()..color = Colors.white.withValues(alpha: 0.25));
      }
    }

    // The comet: today, with a trail of sparks behind it.
    if (progress > 0) {
      final Color head = atRisk ? AppColors.hot : AppColors.glow;
      for (int i = 6; i >= 1; i--) {
        final double back = progress - i * 0.008;
        if (back <= 0) continue;
        canvas.drawCircle(
          _on(center, orbit, back),
          4.5 - i * 0.5,
          Paint()..color = head.withValues(alpha: 0.5 - i * 0.07),
        );
      }
      final Offset p = _on(center, orbit, progress);
      canvas.drawCircle(
        p,
        13 + pulse * 4,
        Paint()
          ..color = head.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawCircle(p, 6, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.seconds != seconds ||
      oldDelegate.dayInCycle != dayInCycle ||
      oldDelegate.atRisk != atRisk;
}
