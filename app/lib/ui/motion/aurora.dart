import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import 'motion.dart';

/// The night behind every screen: four slow lights drifting through a
/// violet-black sky, and a scatter of stars.
///
/// Painted once, behind the navigator, so every page is glass over the same
/// sky and a page transition never reveals a seam. Without ambient motion
/// the lights hold still.
class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop({super.key, required this.child, this.intensity = 1});

  final Widget child;

  /// 1 for the app; more for celebrations.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const ColoredBox(color: AppColors.ink),
        RepaintBoundary(
          child: AmbientClock(
            frozenAt: 3,
            builder: (BuildContext context, double seconds, Widget? _) =>
                CustomPaint(
              painter: AuroraPainter(seconds: seconds, intensity: intensity),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class AuroraPainter extends CustomPainter {
  AuroraPainter({required this.seconds, this.intensity = 1});

  final double seconds;
  final double intensity;

  static const List<_Light> _lights = <_Light>[
    _Light(AppColors.auroraViolet, 0.2, 0.12, 0.95, 0.16, 0.6),
    _Light(AppColors.auroraBlue, 0.85, 0.3, 0.8, 0.12, 2.1),
    _Light(AppColors.auroraRose, 0.15, 0.78, 0.75, 0.14, 4.0),
    _Light(AppColors.auroraCyan, 0.8, 0.92, 0.7, 0.1, 5.3),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double side = math.max(size.width, size.height);
    for (final _Light light in _lights) {
      final double t = seconds * light.speed + light.phase;
      final Offset center = Offset(
        size.width * (light.x + 0.12 * math.sin(t)),
        size.height * (light.y + 0.06 * math.cos(t * 1.3)),
      );
      final double radius = side * light.radius * (0.9 + 0.1 * math.sin(t * 0.7));
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              light.color.withValues(alpha: (0.42 * intensity).clamp(0, 1)),
              light.color.withValues(alpha: (0.14 * intensity).clamp(0, 1)),
              light.color.withValues(alpha: 0),
            ],
            stops: const <double>[0, 0.45, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // Stars: fixed places, each twinkling on its own beat.
    final Paint star = Paint();
    for (int i = 0; i < 46; i++) {
      final double x = _hash(i, 1) * size.width;
      final double y = _hash(i, 2) * size.height;
      final double twinkle =
          0.35 + 0.65 * (0.5 + 0.5 * math.sin(seconds * (0.6 + _hash(i, 3)) + i));
      final double r = 0.5 + _hash(i, 4) * 1.1;
      star.color = AppColors.glow.withValues(alpha: 0.5 * twinkle);
      canvas.drawCircle(Offset(x, y), r, star);
    }
  }

  static double _hash(int i, int salt) {
    final double x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  bool shouldRepaint(AuroraPainter oldDelegate) =>
      oldDelegate.seconds != seconds || oldDelegate.intensity != intensity;
}

class _Light {
  const _Light(this.color, this.x, this.y, this.radius, this.speed, this.phase);

  final Color color;
  final double x;
  final double y;
  final double radius;
  final double speed;
  final double phase;
}
