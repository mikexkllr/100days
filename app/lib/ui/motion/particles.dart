import 'dart:math' as math;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import 'motion.dart';

enum ParticleKind { spark, ember, confetti, star, coin, gem }

const List<Color> kPlasmaParticles = <Color>[
  AppColors.hot,
  AppColors.primary,
  AppColors.attention,
  AppColors.glow,
  Color(0xFFFFFFFF),
];

/// Holographic foil, for jackpots.
const List<Color> kHoloParticles = <Color>[
  Color(0xFFC4B5FD),
  Color(0xFF67E8F9),
  Color(0xFFF9A8D4),
  Color(0xFFA78BFA),
  Color(0xFFFFFFFF),
];

const List<Color> kPartyParticles = <Color>[
  AppColors.primary,
  AppColors.reward,
  AppColors.success,
  AppColors.social,
  AppColors.cool,
  AppColors.hot,
];

class _Particle {
  _Particle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.color,
    required this.life,
    required this.kind,
    required this.rotation,
    required this.spin,
    required this.flicker,
  });

  Offset position;
  Offset velocity;
  final double size;
  final Color color;
  final double life;
  final ParticleKind kind;
  double rotation;
  final double spin;
  final double flicker;
  double age = 0;

  bool get dead => age >= life;
}

/// A burst of sparks, confetti or coins from [origin], every time [trigger]
/// changes. Paints over [child] and never takes a tap from it.
class ParticleBurst extends StatefulWidget {
  const ParticleBurst({
    super.key,
    required this.trigger,
    this.child,
    this.origin = Alignment.center,
    this.count = 28,
    this.kinds = const <ParticleKind>[ParticleKind.spark],
    this.colors = kPlasmaParticles,
    this.power = 1,
    this.gravity = 700,
    this.upward = false,
    this.sizeScale = 1,
    this.burstOnMount = false,
  });

  final Object? trigger;

  /// Fire once as soon as the widget is laid out, without a trigger change.
  final bool burstOnMount;
  final Widget? child;
  final Alignment origin;
  final int count;
  final List<ParticleKind> kinds;
  final List<Color> colors;

  /// Scales launch speed; 1 throws particles about a third of a phone width.
  final double power;
  final double gravity;

  /// Fountain upwards instead of exploding in every direction.
  final bool upward;
  final double sizeScale;

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<ParticleBurst>
    with SingleTickerProviderStateMixin {
  final List<_Particle> _particles = <_Particle>[];
  final math.Random _random = math.Random();
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    if (widget.burstOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _spawn();
      });
    }
  }

  @override
  void didUpdateWidget(ParticleBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger && widget.trigger != null) {
      _spawn();
    }
  }

  void _spawn() {
    if (_size.isEmpty) {
      // Not laid out yet; try again once there is a size to burst from.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_size.isEmpty) _spawn();
      });
      return;
    }
    final Offset origin = widget.origin.alongSize(_size);
    final double base = math.min(_size.shortestSide, 420) * 1.6 * widget.power;
    for (int i = 0; i < widget.count; i++) {
      final double angle = widget.upward
          ? -math.pi / 2 + (_random.nextDouble() - 0.5) * math.pi * 0.9
          : _random.nextDouble() * math.pi * 2;
      final double speed = base * (0.35 + _random.nextDouble() * 0.75);
      final ParticleKind kind =
          widget.kinds[_random.nextInt(widget.kinds.length)];
      _particles.add(_Particle(
        position: origin,
        velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
        size: widget.sizeScale *
            switch (kind) {
              ParticleKind.spark => 2.2 + _random.nextDouble() * 2.6,
              ParticleKind.ember => 2.5 + _random.nextDouble() * 3,
              ParticleKind.confetti => 5 + _random.nextDouble() * 5,
              ParticleKind.star => 5 + _random.nextDouble() * 6,
              ParticleKind.coin => 6 + _random.nextDouble() * 5,
              ParticleKind.gem => 6 + _random.nextDouble() * 6,
            },
        color: widget.colors[_random.nextInt(widget.colors.length)],
        life: 0.7 + _random.nextDouble() * 0.9,
        kind: kind,
        rotation: _random.nextDouble() * math.pi * 2,
        spin: (_random.nextDouble() - 0.5) * 14,
        flicker: _random.nextDouble() * 10,
      ));
    }
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final double dt =
        ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    for (final _Particle p in _particles) {
      p.age += dt;
      final double drag = p.kind == ParticleKind.confetti ? 2.6 : 1.4;
      p.velocity = p.velocity * math.pow(1 / (1 + drag), dt).toDouble() +
          Offset(0, widget.gravity * dt * (p.kind == ParticleKind.confetti
              ? 0.45
              : p.kind == ParticleKind.ember
                  ? -0.25
                  : 1));
      p.position += p.velocity * dt;
      p.rotation += p.spin * dt;
    }
    _particles.removeWhere((_Particle p) => p.dead);
    if (_particles.isEmpty) _ticker.stop();
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _size = constraints.biggest.isFinite
            ? constraints.biggest
            : const Size(300, 300);
        return CustomPaint(
          foregroundPainter: _BurstPainter(_particles, _frame),
          child: widget.child ?? const SizedBox.expand(),
        );
      },
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.particles, Listenable repaint) : super(repaint: repaint);

  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final _Particle p in particles) {
      final double t = (p.age / p.life).clamp(0.0, 1.0);
      final double fade = t < 0.7 ? 1 : 1 - (t - 0.7) / 0.3;
      paintParticle(canvas, p.kind, p.position, p.size, p.color, fade,
          p.rotation, p.velocity, p.age * 20 + p.flicker);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) => true;
}

final Paint _glowPaint = Paint()
  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
final Paint _solidPaint = Paint();

/// One particle, drawn the same way by bursts and by ambient fields.
void paintParticle(
  Canvas canvas,
  ParticleKind kind,
  Offset at,
  double size,
  Color color,
  double opacity,
  double rotation,
  Offset velocity,
  double flickerPhase,
) {
  if (opacity <= 0) return;
  switch (kind) {
    case ParticleKind.spark:
      final double speed = velocity.distance;
      if (speed > 30) {
        final Offset tail = at - velocity / speed * math.min(speed * 0.04, 18);
        canvas.drawLine(
          tail,
          at,
          _solidPaint
            ..color = color.withValues(alpha: 0.55 * opacity)
            ..strokeWidth = size * 0.9
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawCircle(
          at, size * 1.8, _glowPaint..color = color.withValues(alpha: 0.5 * opacity));
      canvas.drawCircle(at, size * 0.7,
          _solidPaint..color = const Color(0xFFFFFFFF).withValues(alpha: opacity));
    case ParticleKind.ember:
      final double flicker = 0.65 + 0.35 * math.sin(flickerPhase);
      canvas.drawCircle(at, size * 2,
          _glowPaint..color = color.withValues(alpha: 0.45 * opacity * flicker));
      canvas.drawCircle(at, size * 0.6,
          _solidPaint..color = color.withValues(alpha: opacity * flicker));
    case ParticleKind.confetti:
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(rotation);
      // A paper strip turning in the air: its width breathes with the spin.
      final double flip = math.cos(rotation * 1.7).abs() * 0.8 + 0.2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: size * flip, height: size * 0.55),
          Radius.circular(size * 0.12),
        ),
        _solidPaint..color = color.withValues(alpha: opacity),
      );
      canvas.restore();
    case ParticleKind.star:
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(rotation * 0.4);
      canvas.drawCircle(Offset.zero, size * 0.9,
          _glowPaint..color = color.withValues(alpha: 0.4 * opacity));
      canvas.drawPath(sparklePath(size),
          _solidPaint..color = color.withValues(alpha: opacity));
      canvas.restore();
    case ParticleKind.gem:
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(rotation * 0.5);
      // A cut stone: a light facet and a dark one, turning in the air.
      final double flip = math.cos(rotation).abs() * 0.7 + 0.3;
      canvas.scale(flip, 1);
      final Path left = Path()
        ..moveTo(0, -size)
        ..lineTo(-size * 0.75, -size * 0.2)
        ..lineTo(0, size)
        ..close();
      final Path right = Path()
        ..moveTo(0, -size)
        ..lineTo(size * 0.75, -size * 0.2)
        ..lineTo(0, size)
        ..close();
      canvas.drawCircle(Offset.zero, size * 1.3,
          _glowPaint..color = color.withValues(alpha: 0.35 * opacity));
      canvas.drawPath(left,
          _solidPaint..color = Color.lerp(color, Colors.white, 0.45)!.withValues(alpha: opacity));
      canvas.drawPath(right, _solidPaint..color = color.withValues(alpha: opacity));
      canvas.restore();
    case ParticleKind.coin:
      canvas.save();
      canvas.translate(at.dx, at.dy);
      final double flip = math.cos(rotation).abs() * 0.85 + 0.15;
      canvas.scale(flip, 1);
      canvas.drawCircle(Offset.zero, size,
          _solidPaint..color = const Color(0xFFFF9F1C).withValues(alpha: opacity));
      canvas.drawCircle(Offset.zero, size * 0.78,
          _solidPaint..color = AppColors.reward.withValues(alpha: opacity));
      canvas.drawCircle(Offset(-size * 0.25, -size * 0.25), size * 0.22,
          _solidPaint..color = const Color(0xFFFFF6C9).withValues(alpha: opacity));
      canvas.restore();
  }
}

/// A four-pointed twinkle, centred on the origin.
Path sparklePath(double size) {
  final double r = size;
  final double w = size * 0.28;
  return Path()
    ..moveTo(0, -r)
    ..quadraticBezierTo(w * 0.35, -w * 0.35, r, 0)
    ..quadraticBezierTo(w * 0.35, w * 0.35, 0, r)
    ..quadraticBezierTo(-w * 0.35, w * 0.35, -r, 0)
    ..quadraticBezierTo(-w * 0.35, -w * 0.35, 0, -r)
    ..close();
}

/// Embers drifting up through an area, forever — or, without ambient
/// motion, a still scatter of them.
class EmberField extends StatelessWidget {
  const EmberField({
    super.key,
    this.count = 18,
    this.color = AppColors.primary,
    this.colors,
    this.speed = 1,
    this.intensity = 1,
  });

  final int count;
  final Color color;
  final List<Color>? colors;
  final double speed;

  /// 0 hides the field, 1 is the normal glow; above 1 for a party.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0) return const SizedBox.expand();
    return IgnorePointer(
      child: AmbientClock(
        builder: (BuildContext context, double seconds, Widget? _) =>
            CustomPaint(
          size: Size.infinite,
          painter: _EmberFieldPainter(
            seconds: seconds,
            count: count,
            colors: colors ?? <Color>[color, AppColors.attention, AppColors.glow],
            speed: speed,
            intensity: intensity,
          ),
        ),
      ),
    );
  }
}

class _EmberFieldPainter extends CustomPainter {
  _EmberFieldPainter({
    required this.seconds,
    required this.count,
    required this.colors,
    required this.speed,
    required this.intensity,
  });

  final double seconds;
  final int count;
  final List<Color> colors;
  final double speed;
  final double intensity;

  /// Stable per-ember randomness, so the field needs no state.
  static double _hash(int i, int salt) {
    final double x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    for (int i = 0; i < count; i++) {
      final double rise = 0.08 + _hash(i, 1) * 0.16;
      final double progress =
          (seconds * rise * speed + _hash(i, 2)) % 1.0;
      final double x = size.width * (0.08 + 0.84 * _hash(i, 3)) +
          math.sin(seconds * (0.8 + _hash(i, 4)) + i) * 14;
      final double y = size.height * (1.05 - progress * 1.1);
      final double fade = math.sin(progress * math.pi);
      paintParticle(
        canvas,
        ParticleKind.ember,
        Offset(x, y),
        (1.2 + _hash(i, 5) * 2.4) * (0.7 + 0.3 * intensity),
        colors[i % colors.length],
        (fade * 0.9 * intensity).clamp(0.0, 1.0),
        0,
        Offset.zero,
        seconds * 6 + i * 1.7,
      );
    }
  }

  @override
  bool shouldRepaint(_EmberFieldPainter oldDelegate) =>
      oldDelegate.seconds != seconds ||
      oldDelegate.intensity != intensity ||
      oldDelegate.count != count;
}
