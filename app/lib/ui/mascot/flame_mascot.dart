import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hundred_core/hundred_core.dart';

import '../motion/motion.dart';
import '../motion/particles.dart';
import 'flame_painter.dart';

export 'mascot_mood.dart';

/// Funki, the flame. Alive while ambient motion is on: it flickers, breathes,
/// blinks — and jumps and throws sparks when you poke it.
class FlameMascot extends StatefulWidget {
  const FlameMascot({
    super.key,
    required this.stage,
    required this.mood,
    this.size = 200,
    this.onPoke,
    this.semanticLabel,
  });

  final FlameStage stage;
  final MascotMood mood;
  final double size;

  /// Called on every tap, with how many taps came in quick succession.
  final ValueChanged<int>? onPoke;
  final String? semanticLabel;

  @override
  State<FlameMascot> createState() => _FlameMascotState();
}

class _FlameMascotState extends State<FlameMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _poke = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  int _bursts = 0;
  int _combo = 0;
  DateTime _lastPoke = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _poke.dispose();
    super.dispose();
  }

  void _onTap() {
    final DateTime now = DateTime.now();
    _combo = now.difference(_lastPoke) < const Duration(milliseconds: 900)
        ? _combo + 1
        : 1;
    _lastPoke = now;
    HapticFeedback.lightImpact();
    _poke.forward(from: 0);
    setState(() => _bursts++);
    widget.onPoke?.call(_combo);
  }

  /// The tap bounce: a squash, a stretch, settling with a wobble.
  double _squash(double t) {
    if (t <= 0 || t >= 1) return 0;
    if (t < 0.15) return -0.6 * (t / 0.15);
    return 0.9 * math.sin((t - 0.15) / 0.85 * math.pi * 2.5) *
        math.pow(1 - (t - 0.15) / 0.85, 1.6);
  }

  @override
  Widget build(BuildContext context) {
    final Widget painted = AmbientClock(
      builder: (BuildContext context, double seconds, Widget? _) =>
          AnimatedBuilder(
        animation: _poke,
        builder: (BuildContext context, Widget? _) => CustomPaint(
          size: Size.square(widget.size),
          painter: FlamePainter(
            stage: widget.stage,
            mood: widget.mood,
            seconds: seconds,
            squash: _squash(_poke.value),
            blink: ambientMotionOf(context),
          ),
        ),
      ),
    );

    return Semantics(
      label: widget.semanticLabel,
      button: widget.onPoke != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPoke == null ? null : _onTap,
        child: SizedBox.square(
          dimension: widget.size,
          child: ParticleBurst(
            trigger: _bursts == 0 ? null : _bursts,
            origin: const Alignment(0, -0.1),
            count: 22,
            kinds: const <ParticleKind>[ParticleKind.spark, ParticleKind.star],
            power: 0.7,
            upward: true,
            child: painted,
          ),
        ),
      ),
    );
  }
}
