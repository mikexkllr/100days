import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/fire.dart';
import '../../theme/theme.dart';
import 'motion.dart';

/// The night behind every screen — and it is yours.
///
/// Nothing in this sky is decoration. Every star is a day you finished, so a
/// new challenge starts under an almost empty sky and day 100 is under a full
/// one. The aurora is today: it is barely there in the morning, rises with
/// every check-in and fills the top of the sky once the day is done. Its
/// colour is the colour of the flame's current form.
///
/// Painted once, behind the navigator, so every page lies over the same sky
/// and a page transition never reveals a seam. Without ambient motion the
/// lights hold still.
class NightSky extends StatelessWidget {
  const NightSky({
    super.key,
    required this.child,
    this.fire = _defaultFire,
    this.glow = 0.5,
    this.stars = 0,
  });

  static const Fire _defaultFire = Fire(
    light: Color(0xFFF6A8FF),
    main: Color(0xFFE25CFF),
    deep: Color(0xFF8E1FB0),
  );

  final Widget child;

  /// The colour of the aurora.
  final Fire fire;

  /// How much of today is done, 0 to 1: how high the aurora stands.
  final double glow;

  /// Days finished: one star each.
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[AppColors.ink, AppColors.inkDeep],
            ),
          ),
        ),
        RepaintBoundary(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: glow.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double glow, Widget? _) =>
                AmbientClock(
              frozenAt: 3,
              builder: (BuildContext context, double seconds, Widget? _) =>
                  CustomPaint(
                painter: SkyPainter(
                  seconds: seconds,
                  glow: glow,
                  stars: stars,
                  fire: fire,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class SkyPainter extends CustomPainter {
  SkyPainter({
    required this.seconds,
    required this.glow,
    required this.stars,
    required this.fire,
  });

  final double seconds;
  final double glow;
  final int stars;
  final Fire fire;

  /// More than this and the sky stops being a sky.
  static const int maxStars = 260;

  /// A few specks that are always there, so an empty sky is still a sky.
  static const int _dust = 34;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _paintAurora(canvas, size);
    _paintStars(canvas, size);
  }

  void _paintAurora(Canvas canvas, Size size) {
    final double peak = 0.045 + 0.36 * glow;
    final double reach = 0.75 + 0.55 * glow;
    final List<_Curtain> curtains = <_Curtain>[
      _Curtain(fire.main, 0.70, 0.20, 0.78, 0.30, 0.13, 0.6),
      _Curtain(fire.deep, 0.16, 0.10, 0.74, 0.34, 0.10, 2.1),
      _Curtain(
        Color.lerp(fire.far ?? fire.main, AppColors.social, 0.6)!,
        0.45,
        -0.06,
        0.95,
        0.20,
        0.16,
        4.0,
      ),
    ];
    for (final _Curtain c in curtains) {
      final double t = seconds * c.speed + c.phase;
      final Offset center = Offset(
        size.width * (c.x + 0.10 * math.sin(t)),
        size.height * (c.y + 0.025 * math.cos(t * 1.3)),
      );
      final double rx = size.width * c.rx * (0.92 + 0.08 * math.sin(t * 0.7));
      final double ry = size.height * c.ry * reach;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, ry / rx);
      canvas.drawCircle(
        Offset.zero,
        rx,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              c.color.withValues(alpha: peak),
              c.color.withValues(alpha: peak * 0.32),
              c.color.withValues(alpha: 0),
            ],
            stops: const <double>[0, 0.5, 1],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: rx)),
      );
      canvas.restore();
    }
  }

  void _paintStars(Canvas canvas, Size size) {
    final Paint paint = Paint();
    for (int i = 0; i < _dust; i++) {
      paint.color = AppColors.glow.withValues(alpha: 0.14 + 0.16 * _hash(i, 5));
      canvas.drawCircle(
        Offset(_hash(i, 1) * size.width, _hash(i, 2) * size.height),
        0.5 + _hash(i, 4) * 0.4,
        paint,
      );
    }

    final int earned = math.min(stars, maxStars);
    final Paint flare = Paint()..strokeCap = StrokeCap.round;
    for (int i = 0; i < earned; i++) {
      final int k = i + 100;
      final Offset at = Offset(
        (0.03 + 0.94 * _hash(k, 1)) * size.width,
        (0.02 + 0.9 * _hash(k, 2)) * size.height,
      );
      final double twinkle =
          0.6 + 0.4 * math.sin(seconds * (0.5 + _hash(k, 3)) + k);
      // Every seventh day closed a week: a bigger star, with a flare.
      final bool week = (i + 1) % 7 == 0;
      final double r = (week ? 1.5 : 0.7) + _hash(k, 4) * 0.6;
      final Color color = week ? fire.light : AppColors.glow;
      if (week) {
        flare
          ..color = color.withValues(alpha: 0.4 * twinkle)
          ..strokeWidth = 0.8;
        canvas.drawLine(at.translate(-r * 3.2, 0), at.translate(r * 3.2, 0), flare);
        canvas.drawLine(at.translate(0, -r * 3.2), at.translate(0, r * 3.2), flare);
      }
      paint.color = color.withValues(alpha: (0.38 + 0.42 * twinkle).clamp(0, 1));
      canvas.drawCircle(at, r, paint);
    }
  }

  static double _hash(int i, int salt) {
    final double x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  bool shouldRepaint(SkyPainter oldDelegate) =>
      oldDelegate.seconds != seconds ||
      oldDelegate.glow != glow ||
      oldDelegate.stars != stars ||
      oldDelegate.fire != fire;
}

class _Curtain {
  const _Curtain(
      this.color, this.x, this.y, this.rx, this.ry, this.speed, this.phase);

  final Color color;
  final double x;
  final double y;
  final double rx;
  final double ry;
  final double speed;
  final double phase;
}
