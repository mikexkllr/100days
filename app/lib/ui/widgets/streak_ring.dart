import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../theme/fire.dart';
import '../../theme/theme.dart';
import '../mascot/flame_mascot.dart';
import '../motion/motion.dart';

/// Funki inside the ring of today.
///
/// The ring has one segment for every habit scheduled today. A segment
/// lights when its habit is done — and shows how far along it is before
/// that — so one look says how much of today is left. When the last one
/// lights, the ring is closed and the flame is safe until tomorrow. On a
/// day with nothing scheduled the ring is a dotted line: nothing to close.
class TodayRing extends StatelessWidget {
  const TodayRing({
    super.key,
    required this.parts,
    required this.fire,
    required this.stage,
    required this.mood,
    this.held = false,
    this.size = 168,
    this.onPoke,
    this.mascotLabel,
  });

  /// How far each of today's habits is, 0 to 1. Empty on a rest day.
  final List<double> parts;
  final Fire fire;
  final FlameStage stage;
  final MascotMood mood;

  /// A freeze holds the day: the ring is closed in ice.
  final bool held;
  final double size;
  final ValueChanged<int>? onPoke;
  final String? mascotLabel;

  bool get _closed => parts.isNotEmpty && parts.every((double p) => p >= 1);

  @override
  Widget build(BuildContext context) {
    final int n = parts.length;
    // Room between segments for their round caps.
    final double gap = n <= 1 ? 0 : math.min(0.26, math.pi * 2 / n * 0.3);
    final double sweep = math.pi * 2 / math.max(n, 1) - gap;

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // The light Funki gives off — brighter once the ring is closed.
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _closed ? 1 : 0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double lit, Widget? _) =>
                  AmbientClock(
                builder: (BuildContext context, double seconds, Widget? _) =>
                    CustomPaint(
                  painter: _HaloPainter(
                    color: held ? AppColors.cool : fire.main,
                    lit: lit,
                    breath: 0.5 + 0.5 * math.sin(seconds * 1.8),
                  ),
                ),
              ),
            ),
          ),
          if (n == 0 || held)
            Positioned.fill(
              child: CustomPaint(
                painter: _RestPainter(
                  color: held ? AppColors.cool : AppColors.textTertiary,
                  solid: held,
                ),
              ),
            )
          else
            for (int i = 0; i < n; i++)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: parts[i].clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double part, Widget? _) =>
                      CustomPaint(
                    painter: _SegmentPainter(
                      start: -math.pi / 2 + gap / 2 + i * (sweep + gap),
                      sweep: sweep,
                      part: part,
                      fire: fire,
                    ),
                  ),
                ),
              ),
          // Funki floats: a slow bob inside the ring.
          AmbientClock(
            builder: (BuildContext context, double seconds, Widget? mascot) =>
                Transform.translate(
              offset: Offset(0, math.sin(seconds * 1.6) * size * 0.014),
              child: mascot,
            ),
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

const double _stroke = 7;

class _SegmentPainter extends CustomPainter {
  _SegmentPainter({
    required this.start,
    required this.sweep,
    required this.part,
    required this.fire,
  });

  final double start;
  final double sweep;
  final double part;
  final Fire fire;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final Rect rect =
        Rect.fromCircle(center: center, radius: size.width / 2 - _stroke);
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.1),
    );
    if (part <= 0) return;
    final double lit = math.max(sweep * part, 0.001);
    final Shader shader = SweepGradient(
      transform: GradientRotation(start - 0.2),
      colors: <Color>[fire.main, fire.light, fire.far ?? fire.light],
      stops: <double>[0, (sweep + 0.2) / (math.pi * 2) * 0.6, 1],
    ).createShader(rect);
    // Only a finished segment gives off light.
    if (part >= 1) {
      canvas.drawArc(
        rect,
        start,
        lit,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke + 6
          ..strokeCap = StrokeCap.round
          ..color = fire.main.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.drawArc(
      rect,
      start,
      lit,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_SegmentPainter oldDelegate) =>
      oldDelegate.part != part ||
      oldDelegate.start != start ||
      oldDelegate.sweep != sweep ||
      oldDelegate.fire != fire;
}

class _RestPainter extends CustomPainter {
  _RestPainter({required this.color, required this.solid});

  final Color color;
  final bool solid;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final Rect rect =
        Rect.fromCircle(center: center, radius: size.width / 2 - _stroke);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (solid) {
      canvas.drawCircle(
        center,
        rect.width / 2,
        paint
          ..strokeWidth = _stroke
          ..color = color.withValues(alpha: 0.85),
      );
      return;
    }
    paint
      ..strokeWidth = 2.4
      ..color = color.withValues(alpha: 0.7);
    const int dots = 44;
    for (int i = 0; i < dots; i++) {
      canvas.drawArc(rect, i * math.pi * 2 / dots, 0.012, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RestPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.solid != solid;
}

class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.color, required this.lit, required this.breath});

  final Color color;
  final double lit;
  final double breath;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width * (0.40 + 0.08 * lit);
    final double alpha = 0.16 + 0.22 * lit + 0.05 * breath;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.35),
            color.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_HaloPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.lit != lit ||
      oldDelegate.breath != breath;
}
