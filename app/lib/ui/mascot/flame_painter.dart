import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../theme/theme.dart';
import 'mascot_mood.dart';

export 'mascot_mood.dart';

/// Colours and proportions of one stage of the flame.
class FlamePalette {
  const FlamePalette({
    required this.outer,
    required this.mid,
    required this.core,
    required this.glow,
    required this.scale,
    required this.tipHeight,
    this.extraTongues = false,
    this.sideTongues = true,
    this.rays = false,
    this.orbit = false,
    this.sparkles = false,
  });

  /// Top and bottom colour of each layer, outside in.
  final List<Color> outer;
  final List<Color> mid;
  final List<Color> core;
  final Color glow;

  /// Size relative to the largest flame.
  final double scale;

  /// Height of the main tongue above the belly, in belly radii.
  final double tipHeight;
  final bool extraTongues;

  /// False for a plain teardrop — the coal before the first day.
  final bool sideTongues;

  /// Sun rays turning behind the flame.
  final bool rays;

  /// Embers circling the flame.
  final bool orbit;

  /// Twinkles around the head.
  final bool sparkles;

  static const List<Color> _fireOuter = <Color>[
    Color(0xFFFF8A2C),
    Color(0xFFFF2E63),
  ];
  static const List<Color> _fireMid = <Color>[
    Color(0xFFFFC93C),
    Color(0xFFFF7A1F),
  ];
  static const List<Color> _fireCore = <Color>[
    Color(0xFFFFF6C8),
    Color(0xFFFFD84D),
  ];

  static FlamePalette of(FlameStage stage) {
    switch (stage) {
      case FlameStage.ember:
        return const FlamePalette(
          outer: <Color>[Color(0xFFFF7043), Color(0xFFB3204A)],
          mid: <Color>[Color(0xFFFFA25C), Color(0xFFF0552E)],
          core: <Color>[Color(0xFFFFEBC2), Color(0xFFFFBE7A)],
          glow: Color(0xFFFF6B2C),
          scale: 0.62,
          tipHeight: 1.5,
          sideTongues: false,
        );
      case FlameStage.spark:
        return const FlamePalette(
          outer: _fireOuter,
          mid: _fireMid,
          core: _fireCore,
          glow: AppColors.flame,
          scale: 0.68,
          tipHeight: 1.6,
        );
      case FlameStage.flicker:
        return const FlamePalette(
          outer: _fireOuter,
          mid: _fireMid,
          core: _fireCore,
          glow: AppColors.flame,
          scale: 0.75,
          tipHeight: 1.85,
        );
      case FlameStage.flame:
        return const FlamePalette(
          outer: <Color>[Color(0xFFFF7A1F), Color(0xFFFF2E63)],
          mid: _fireMid,
          core: _fireCore,
          glow: AppColors.flame,
          scale: 0.83,
          tipHeight: 2.05,
        );
      case FlameStage.blaze:
        return const FlamePalette(
          outer: <Color>[Color(0xFFFF6A1A), Color(0xFFF0174F)],
          mid: <Color>[Color(0xFFFFCF3F), Color(0xFFFF6B1A)],
          core: _fireCore,
          glow: Color(0xFFFF5A2C),
          scale: 0.89,
          tipHeight: 2.15,
          extraTongues: true,
        );
      case FlameStage.inferno:
        return const FlamePalette(
          outer: <Color>[Color(0xFFFF5A1F), Color(0xFFC8102E)],
          mid: <Color>[Color(0xFFFFB627), Color(0xFFFF4D1A)],
          core: <Color>[Color(0xFFFFFFFF), Color(0xFFFFE14D)],
          glow: Color(0xFFFF3D2E),
          scale: 0.95,
          tipHeight: 2.25,
          extraTongues: true,
          orbit: true,
        );
      case FlameStage.blue:
        return const FlamePalette(
          outer: <Color>[Color(0xFF5CC8FF), Color(0xFF2E4BFF)],
          mid: <Color>[Color(0xFFA8E8FF), Color(0xFF4F9BFF)],
          core: <Color>[Color(0xFFFFFFFF), Color(0xFFD6F4FF)],
          glow: Color(0xFF4FA8FF),
          scale: 0.97,
          tipHeight: 2.25,
          extraTongues: true,
          orbit: true,
        );
      case FlameStage.plasma:
        return const FlamePalette(
          outer: <Color>[Color(0xFFD45CFF), Color(0xFF6A2EFF)],
          mid: <Color>[Color(0xFFF2A8FF), Color(0xFFB04DFF)],
          core: <Color>[Color(0xFFFFFFFF), Color(0xFFFFD6FF)],
          glow: Color(0xFFB04DFF),
          scale: 1,
          tipHeight: 2.3,
          extraTongues: true,
          orbit: true,
          sparkles: true,
        );
      case FlameStage.nova:
        return const FlamePalette(
          outer: <Color>[Color(0xFFFFFFFF), Color(0xFFFF5CC8)],
          mid: <Color>[Color(0xFFFFFFFF), Color(0xFFFFB3EC)],
          core: <Color>[Color(0xFFFFFFFF), Color(0xFFFFF0FB)],
          glow: Color(0xFFFF8AE2),
          scale: 1,
          tipHeight: 2.3,
          extraTongues: true,
          orbit: true,
          sparkles: true,
        );
      case FlameStage.sun:
        return const FlamePalette(
          outer: <Color>[Color(0xFFFFE14D), Color(0xFFFF8A00)],
          mid: <Color>[Color(0xFFFFF3B0), Color(0xFFFFC531)],
          core: <Color>[Color(0xFFFFFFFF), Color(0xFFFFF6C8)],
          glow: AppColors.gold,
          scale: 1,
          tipHeight: 2.3,
          extraTongues: true,
          rays: true,
          sparkles: true,
        );
    }
  }
}

/// The flame, with a face. Pure paint: give it a stage, a mood and a moment
/// in [seconds] and it draws that frame — the same frame in the app, in a
/// test, or rendered into the home screen widget.
class FlamePainter extends CustomPainter {
  FlamePainter({
    required this.stage,
    required this.mood,
    required this.seconds,
    this.squash = 0,
    this.blink = true,
  }) : palette = FlamePalette.of(stage);

  final FlameStage stage;
  final MascotMood mood;
  final double seconds;

  /// -1 (squashed flat) … 0 … 1 (stretched tall): the tap bounce.
  final double squash;

  /// Whether the eyes may close now and then. Off for still renders.
  final bool blink;
  final FlamePalette palette;

  double get _energy => switch (mood) {
        MascotMood.hyped => 1.7,
        MascotMood.worried => 1.35,
        MascotMood.happy => 1.15,
        MascotMood.hungry => 1,
        MascotMood.hopeful => 0.6,
        MascotMood.sad => 0.45,
        MascotMood.sleepy => 0.4,
      };

  double get _tempo => switch (mood) {
        MascotMood.hyped => 1.5,
        MascotMood.worried => 1.45,
        MascotMood.sleepy => 0.55,
        MascotMood.sad => 0.7,
        _ => 1,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final double t = seconds * _tempo;
    final double r = 0.255 * s * palette.scale;
    final double bottom = s * (0.9 - 0.06 * (1 - palette.scale));

    // A hyped flame hops; everyone else just breathes.
    final double hop = mood == MascotMood.hyped
        ? -(math.sin(seconds * 7).abs()) * s * 0.045
        : 0;
    final double breath = 1 + 0.025 * math.sin(t * 2.3);
    final Offset foot = Offset(size.width / 2, bottom + hop);

    _paintGlow(canvas, size, foot, r);
    if (palette.rays) _paintRays(canvas, foot.translate(0, -r * 1.2), r, t);
    if (palette.orbit) _paintOrbit(canvas, foot.translate(0, -r * 1.1), r, t, back: true);

    canvas.save();
    // Squash and stretch about the feet, so the flame stays on the ground.
    final double stretch = 1 + squash * 0.18;
    canvas.translate(foot.dx, foot.dy);
    canvas.scale((2 - stretch) * breath, stretch / breath * (1 + 0.02 * math.sin(t * 2.3 + 1)));
    canvas.translate(-foot.dx, -foot.dy);

    final Offset belly = foot.translate(0, -r);
    final double e = _energy;
    double wave(double speed, double phase) => math.sin(t * speed + phase);

    final double tip = palette.tipHeight * (1 + 0.07 * e * wave(3.1, 2.1) + 0.04 * wave(7.9, 1.3));
    final double sway = r * e * (0.11 * wave(5.3, 0) + 0.05 * wave(8.7, 1.1));
    final double left = !palette.sideTongues
        ? 0
        : (palette.extraTongues ? 1.3 : 1.05) * (1 + 0.12 * e * wave(6.1, 0.7));
    final double right = !palette.sideTongues
        ? 0
        : (palette.extraTongues ? 1.5 : 1.25) * (1 + 0.12 * e * wave(5.6, 2.9));

    final Path outer = flamePath(belly, r,
        tip: tip, left: left, right: right, sway: sway,
        swayLeft: r * 0.08 * e * wave(6.6, 0.3),
        swayRight: r * 0.08 * e * wave(5.9, 1.9));
    canvas.drawPath(outer, _fill(outer, palette.outer));

    final Offset midBelly = belly.translate(0, r * 0.16);
    final double rm = r * 0.76;
    final Path mid = flamePath(midBelly, rm,
        tip: tip * 0.82, left: left * 0.7, right: right * 0.72,
        sway: sway * 0.8 + r * 0.03 * wave(9.1, 0.4),
        swayLeft: 0, swayRight: 0);
    canvas.drawPath(mid, _fill(mid, palette.mid));

    final Offset coreBelly = belly.translate(0, r * 0.42);
    final double rc = r * 0.46;
    final Path core = flamePath(coreBelly, rc,
        tip: tip * 0.75, left: 0, right: 0,
        sway: sway * 0.6, swayLeft: 0, swayRight: 0);
    canvas.drawPath(core, _fill(core, palette.core));

    // A glossy highlight on the upper left of the belly.
    canvas.drawOval(
      Rect.fromCenter(
        center: belly.translate(-r * 0.55, -r * 0.35),
        width: r * 0.22,
        height: r * 0.42,
      ),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.18),
    );

    _paintFace(canvas, belly.translate(sway * 0.12, r * 0.05), r);
    canvas.restore();

    if (palette.orbit) _paintOrbit(canvas, foot.translate(0, -r * 1.1), r, t, back: false);
    if (palette.sparkles || mood == MascotMood.hyped) {
      _paintSparkles(canvas, foot.translate(0, -r * 1.6), r, seconds);
    }
    if (mood == MascotMood.sleepy) _paintZs(canvas, belly.translate(r * 0.9, -r * 1.4), r, seconds);
  }

  Paint _fill(Path path, List<Color> colors) {
    final Rect bounds = path.getBounds();
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(bounds);
  }

  void _paintGlow(Canvas canvas, Size size, Offset foot, double r) {
    final double pulse = 0.85 + 0.15 * math.sin(seconds * 2.1);
    final Offset center = foot.translate(0, -r * 1.25);
    final double radius = r * 2.6;
    final double strength = switch (mood) {
      MascotMood.hyped => 0.75,
      MascotMood.happy => 0.6,
      MascotMood.sad || MascotMood.sleepy || MascotMood.hopeful => 0.3,
      _ => 0.48,
    };
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            palette.glow.withValues(alpha: strength * pulse),
            palette.glow.withValues(alpha: strength * 0.35 * pulse),
            palette.glow.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _paintRays(Canvas canvas, Offset center, double r, double t) {
    const int count = 12;
    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          palette.glow.withValues(alpha: 0.55),
          palette.glow.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 3));
    for (int i = 0; i < count; i++) {
      final double a = t * 0.35 + i * math.pi * 2 / count;
      const double spread = math.pi / count * 0.5;
      final Path ray = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + math.cos(a - spread) * r * 3,
            center.dy + math.sin(a - spread) * r * 3)
        ..lineTo(center.dx + math.cos(a + spread) * r * 3,
            center.dy + math.sin(a + spread) * r * 3)
        ..close();
      canvas.drawPath(ray, paint);
    }
  }

  void _paintOrbit(Canvas canvas, Offset center, double r, double t,
      {required bool back}) {
    const int count = 5;
    for (int i = 0; i < count; i++) {
      final double a = t * 1.4 + i * math.pi * 2 / count;
      // Behind the flame on the upper half of the ellipse, in front below.
      final bool isBack = math.sin(a) < 0;
      if (isBack != back) continue;
      final Offset p = center.translate(
          math.cos(a) * r * 1.55, math.sin(a) * r * 0.45);
      final double size = r * (0.05 + 0.025 * (math.sin(a) + 1));
      canvas.drawCircle(
        p,
        size * 2.6,
        Paint()
          ..color = palette.glow.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(p, size, Paint()..color = palette.core.first);
    }
  }

  void _paintSparkles(Canvas canvas, Offset center, double r, double t) {
    const List<List<double>> spots = <List<double>>[
      <double>[-1.35, -0.2, 0],
      <double>[1.25, -0.55, 1.7],
      <double>[0.95, 0.65, 3.1],
      <double>[-1.05, 0.85, 4.4],
    ];
    for (final List<double> spot in spots) {
      final double phase = (t * 1.3 + spot[2]) % 2.4;
      if (phase > 1) continue;
      final double scale = math.sin(phase * math.pi);
      final Offset at = center.translate(spot[0] * r, spot[1] * r);
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(phase * 1.2);
      final double size = r * 0.16 * scale;
      final Path star = Path()
        ..moveTo(0, -size)
        ..quadraticBezierTo(size * 0.12, -size * 0.12, size, 0)
        ..quadraticBezierTo(size * 0.12, size * 0.12, 0, size)
        ..quadraticBezierTo(-size * 0.12, size * 0.12, -size, 0)
        ..quadraticBezierTo(-size * 0.12, -size * 0.12, 0, -size)
        ..close();
      canvas.drawPath(star, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9 * scale));
      canvas.restore();
    }
  }

  void _paintZs(Canvas canvas, Offset at, double r, double t) {
    for (int i = 0; i < 3; i++) {
      final double phase = (t * 0.45 + i / 3) % 1;
      final double size = r * (0.16 + 0.12 * phase);
      final Offset p = at.translate(phase * r * 0.5, -phase * r * 0.9);
      final Paint paint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.75 * math.sin(phase * math.pi))
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.18
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy)
          ..lineTo(p.dx + size, p.dy)
          ..lineTo(p.dx, p.dy + size)
          ..lineTo(p.dx + size, p.dy + size),
        paint,
      );
    }
  }

  void _paintFace(Canvas canvas, Offset center, double r) {
    const Color ink = Color(0xFF3A1300);
    final Paint inkPaint = Paint()..color = ink;
    final Paint stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.075
      ..strokeCap = StrokeCap.round;

    final double eyeY = center.dy - r * 0.08;
    final double eyeDx = r * 0.36;
    final double look = math.sin(seconds * 0.7) * r * 0.03;

    // Blinks every few seconds, on an uneven beat so it never looks mechanical.
    final double beat = seconds % 3.9;
    final bool blinking = blink && beat > 3.72 && _eyesOpen;
    final double eyeOpen = blinking ? 0.12 : 1;

    // Cheeks first, so the eyes sit on top of them.
    if (_blushes) {
      for (final double side in <double>[-1, 1]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx + side * r * 0.56, eyeY + r * 0.27),
            width: r * 0.26,
            height: r * 0.14,
          ),
          Paint()..color = const Color(0xFFFF4F7B).withValues(alpha: 0.45),
        );
      }
    }

    for (final double side in <double>[-1, 1]) {
      final Offset eye = Offset(center.dx + side * eyeDx + look, eyeY);
      switch (mood) {
        case MascotMood.hyped:
          // ^ ^ — squeezed shut with joy.
          canvas.drawPath(
            Path()
              ..moveTo(eye.dx - r * 0.13, eye.dy + r * 0.06)
              ..quadraticBezierTo(eye.dx, eye.dy - r * 0.16, eye.dx + r * 0.13, eye.dy + r * 0.06),
            stroke,
          );
        case MascotMood.sleepy:
          canvas.drawPath(
            Path()
              ..moveTo(eye.dx - r * 0.12, eye.dy)
              ..quadraticBezierTo(eye.dx, eye.dy + r * 0.11, eye.dx + r * 0.12, eye.dy),
            stroke,
          );
        case MascotMood.hopeful:
        case MascotMood.hungry:
        case MascotMood.worried:
        case MascotMood.happy:
        case MascotMood.sad:
          final double big = mood == MascotMood.hungry ? 1.18 : mood == MascotMood.hopeful ? 0.85 : 1;
          final double w = r * 0.25 * big;
          final double h = r * 0.34 * big * eyeOpen;
          canvas.drawOval(Rect.fromCenter(center: eye, width: w, height: h), inkPaint);
          if (!blinking) {
            final Paint shine = Paint()..color = const Color(0xFFFFFFFF);
            canvas.drawCircle(eye.translate(w * 0.18, -h * 0.2), w * 0.2, shine);
            if (mood == MascotMood.hungry || mood == MascotMood.happy) {
              canvas.drawCircle(eye.translate(-w * 0.16, h * 0.18), w * 0.09, shine);
            }
          }
          if (mood == MascotMood.sad) {
            // Heavy lids.
            canvas.drawRect(
              Rect.fromCenter(center: eye.translate(0, -h * 0.42), width: w * 1.3, height: h * 0.35),
              Paint()..color = palette.mid.last,
            );
          }
      }
    }

    if (mood == MascotMood.worried || mood == MascotMood.sad) {
      for (final double side in <double>[-1, 1]) {
        final double x = center.dx + side * eyeDx;
        canvas.drawLine(
          Offset(x - side * r * 0.14, eyeY - r * 0.36),
          Offset(x + side * r * 0.1, eyeY - r * 0.27),
          stroke..strokeWidth = r * 0.06,
        );
      }
      stroke.strokeWidth = r * 0.075;
    }

    final double mouthY = center.dy + r * 0.34;
    switch (mood) {
      case MascotMood.happy:
      case MascotMood.hyped:
        final double w = mood == MascotMood.hyped ? r * 0.5 : r * 0.38;
        final double h = mood == MascotMood.hyped ? r * 0.36 : r * 0.24;
        final Path mouth = Path()
          ..moveTo(center.dx - w / 2, mouthY - h * 0.25)
          ..quadraticBezierTo(center.dx, mouthY - h * 0.45, center.dx + w / 2, mouthY - h * 0.25)
          ..quadraticBezierTo(center.dx + w * 0.42, mouthY + h, center.dx, mouthY + h)
          ..quadraticBezierTo(center.dx - w * 0.42, mouthY + h, center.dx - w / 2, mouthY - h * 0.25)
          ..close();
        canvas.drawPath(mouth, Paint()..color = const Color(0xFF5A1206));
        canvas.save();
        canvas.clipPath(mouth);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(center.dx, mouthY + h * 0.85), width: w * 0.6, height: h * 0.7),
          Paint()..color = const Color(0xFFFF6F91),
        );
        canvas.restore();
      case MascotMood.hungry:
        canvas.drawOval(
          Rect.fromCenter(center: Offset(center.dx, mouthY + r * 0.02), width: r * 0.16, height: r * 0.19),
          Paint()..color = const Color(0xFF5A1206),
        );
      case MascotMood.worried:
        final Path wobble = Path()..moveTo(center.dx - r * 0.18, mouthY + r * 0.04);
        for (int i = 0; i < 4; i++) {
          final double x0 = center.dx - r * 0.18 + i * r * 0.09;
          wobble.quadraticBezierTo(x0 + r * 0.045, mouthY + (i.isEven ? -r * 0.05 : r * 0.13), x0 + r * 0.09, mouthY + r * 0.04);
        }
        canvas.drawPath(wobble, stroke);
        // A sweat drop at the temple.
        final Offset drop = Offset(center.dx + r * 0.78, eyeY - r * 0.22 + (seconds * 0.6 % 1) * r * 0.25);
        canvas.drawPath(
          Path()
            ..moveTo(drop.dx, drop.dy - r * 0.16)
            ..quadraticBezierTo(drop.dx + r * 0.1, drop.dy, drop.dx, drop.dy + r * 0.05)
            ..quadraticBezierTo(drop.dx - r * 0.1, drop.dy, drop.dx, drop.dy - r * 0.16),
          Paint()..color = const Color(0xFFB8ECFF),
        );
      case MascotMood.hopeful:
      case MascotMood.sleepy:
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - r * 0.13, mouthY)
            ..quadraticBezierTo(center.dx, mouthY + r * 0.12, center.dx + r * 0.13, mouthY),
          stroke,
        );
      case MascotMood.sad:
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - r * 0.14, mouthY + r * 0.08)
            ..quadraticBezierTo(center.dx, mouthY - r * 0.06, center.dx + r * 0.14, mouthY + r * 0.08),
          stroke,
        );
    }
  }

  bool get _eyesOpen => mood != MascotMood.hyped && mood != MascotMood.sleepy;

  bool get _blushes =>
      mood == MascotMood.happy ||
      mood == MascotMood.hyped ||
      mood == MascotMood.hungry ||
      mood == MascotMood.hopeful;

  @override
  bool shouldRepaint(FlamePainter oldDelegate) =>
      oldDelegate.seconds != seconds ||
      oldDelegate.stage != stage ||
      oldDelegate.mood != mood ||
      oldDelegate.squash != squash;
}

/// A cartoon flame: a round belly with a tall middle tongue and one on each
/// side. Heights are in belly radii; a side height of 0 leaves a plain
/// teardrop.
Path flamePath(
  Offset belly,
  double r, {
  required double tip,
  required double left,
  required double right,
  required double sway,
  required double swayLeft,
  required double swayRight,
}) {
  final double cx = belly.dx;
  final double cy = belly.dy;
  final Offset top = Offset(cx + sway, cy - r * tip);
  final Path path = Path()..moveTo(cx, cy + r);

  // Left half of the belly.
  path.cubicTo(cx - r * 0.62, cy + r, cx - r * 1.06, cy + r * 0.56, cx - r * 1.02, cy);

  if (left > 0) {
    final Offset l = Offset(cx - r * 0.98 + swayLeft, cy - r * left);
    path.cubicTo(cx - r * 1.0, cy - r * 0.42, l.dx - r * 0.1, l.dy + r * 0.4, l.dx, l.dy);
    path.cubicTo(l.dx + r * 0.2, l.dy + r * 0.38, cx - r * 0.56, cy - r * 0.5, cx - r * 0.46, cy - r * 0.72);
    path.cubicTo(cx - r * 0.42, cy - r * 1.2, top.dx - r * 0.28, top.dy + r * 0.6, top.dx, top.dy);
  } else {
    path.cubicTo(cx - r * 1.0, cy - r * 0.62, top.dx - r * 0.42, top.dy + r * 0.9, top.dx, top.dy);
  }

  if (right > 0) {
    final Offset q = Offset(cx + r * 0.94 + swayRight, cy - r * right);
    path.cubicTo(top.dx + r * 0.16, top.dy + r * 0.62, cx + r * 0.34, cy - r * 1.0, cx + r * 0.44, cy - r * 0.7);
    path.cubicTo(cx + r * 0.56, cy - r * 0.92, q.dx - r * 0.16, q.dy + r * 0.34, q.dx, q.dy);
    path.cubicTo(q.dx + r * 0.12, q.dy + r * 0.52, cx + r * 1.04, cy - r * 0.42, cx + r * 1.02, cy);
  } else {
    path.cubicTo(top.dx + r * 0.42, top.dy + r * 0.9, cx + r * 1.0, cy - r * 0.62, cx + r * 1.02, cy);
  }

  // Right half of the belly, back to the bottom.
  path.cubicTo(cx + r * 1.06, cy + r * 0.56, cx + r * 0.62, cy + r, cx, cy + r);
  path.close();
  return path;
}
