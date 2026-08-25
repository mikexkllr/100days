import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// The number the whole app exists to make go up.
class StreakRing extends StatelessWidget {
  const StreakRing({
    super.key,
    required this.streak,
    required this.progress,
    required this.dayNumber,
    required this.totalDays,
    this.atRisk = false,
    this.size = 210,
  });

  final int streak;
  final double progress;
  final int dayNumber;
  final int totalDays;
  final bool atRisk;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color accent = atRisk ? AppColors.danger : AppColors.flame;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double value, Widget? _) =>
                CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(progress: value, accent: accent),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                streak.toString(),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: accent,
                      fontSize: size * 0.34,
                    ),
              ),
              Text(
                streak == 1 ? 'Tag Streak' : 'Tage Streak',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: AppRadius.pill,
                ),
                child: Text(
                  'Tag $dayNumber / $totalDays',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2 - 12;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    const double start = -math.pi / 2;

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = AppColors.surfaceHigh;
    canvas.drawArc(rect, start, math.pi * 2, false, track);

    if (progress <= 0) return;

    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: const GradientRotation(start),
        colors: <Color>[
          accent.withValues(alpha: 0.35),
          accent,
          AppColors.flameSoft,
        ],
        stops: const <double>[0, 0.6, 1],
      ).createShader(rect);

    canvas.drawArc(rect, start, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}
