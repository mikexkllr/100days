import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hundred_core/hundred_core.dart';

import '../motion/motion.dart';
import '../motion/particles.dart';
import 'flame_painter.dart';

export 'mascot_mood.dart';

/// Funki, the flame. Alive while ambient motion is on: it flickers, breathes,
/// blinks — and jumps and throws sparks when you poke it.
///
/// Where he can be touched ([onPoke] set): a tap pokes him, a long press
/// pets him (he purrs in your hand and glows), and pulling while pressing
/// stretches him like rubber until he snaps back with a burst of sparks.
class FlameMascot extends StatefulWidget {
  const FlameMascot({
    super.key,
    required this.stage,
    required this.mood,
    this.size = 200,
    this.onPoke,
    this.onPet,
    this.semanticLabel,
    this.anticipation,
    this.urgency = 0,
  });

  final FlameStage stage;
  final MascotMood mood;
  final double size;

  /// Called on every tap, with how many taps came in quick succession.
  final ValueChanged<int>? onPoke;

  /// Called when a long press starts petting him.
  final VoidCallback? onPet;
  final String? semanticLabel;

  /// How full a held habit row is: he looks at it and opens his mouth.
  final ValueListenable<double>? anticipation;

  /// 0 … 1, how close midnight is on an open day: he trembles.
  final double urgency;

  @override
  State<FlameMascot> createState() => _FlameMascotState();
}

class _FlameMascotState extends State<FlameMascot>
    with TickerProviderStateMixin {
  late final AnimationController _poke = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  int _bursts = 0;
  int _combo = 0;
  DateTime _lastPoke = DateTime.fromMillisecondsSinceEpoch(0);

  /// Petting: a purr of light haptics while the press lasts.
  Timer? _purr;
  bool _petting = false;

  /// How far he is pulled, −0.6 (squashed) … 1 (stretched), and the spring
  /// that brings him back.
  double _pull = 0;
  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  double _pullAtRelease = 0;

  @override
  void dispose() {
    _purr?.cancel();
    _poke.dispose();
    _spring.dispose();
    super.dispose();
  }

  void _startPetting(LongPressStartDetails _) {
    HapticFeedback.mediumImpact();
    widget.onPet?.call();
    setState(() => _petting = true);
    _purr?.cancel();
    _purr = Timer.periodic(const Duration(milliseconds: 110), (_) {
      HapticFeedback.selectionClick();
    });
  }

  void _pullTo(LongPressMoveUpdateDetails details) {
    final double next =
        (-details.offsetFromOrigin.dy / widget.size).clamp(-0.6, 1.0);
    if ((next - _pull).abs() > 0.08) HapticFeedback.selectionClick();
    setState(() => _pull = next);
  }

  void _release(LongPressEndDetails _) {
    _purr?.cancel();
    _purr = null;
    _pullAtRelease = _pull;
    final bool snapped = _pull.abs() > 0.3;
    setState(() {
      _petting = false;
      _pull = 0;
      if (snapped) _bursts++;
    });
    if (snapped) HapticFeedback.heavyImpact();
    _spring.forward(from: 0);
  }

  /// The spring back after a pull: overshoots and wobbles out.
  double _springSquash() {
    if (!_spring.isAnimating && _spring.value >= 1) return 0;
    final double t = _spring.value;
    return _pullAtRelease *
        math.cos(t * math.pi * 3) *
        math.pow(1 - t, 1.4).toDouble();
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

  static const ValueListenable<double> _still = AlwaysStoppedAnimation<double>(0);

  @override
  Widget build(BuildContext context) {
    final Widget painted = AmbientClock(
      builder: (BuildContext context, double seconds, Widget? _) =>
          AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          _poke,
          _spring,
          widget.anticipation ?? _still,
        ]),
        builder: (BuildContext context, Widget? _) {
          final double fed = widget.anticipation?.value ?? 0;
          return CustomPaint(
            size: Size.square(widget.size),
            painter: FlamePainter(
              stage: widget.stage,
              // Petted, anyone grins.
              mood: _petting ? MascotMood.happy : widget.mood,
              seconds: seconds,
              squash: (_squash(_poke.value) + _pull + _springSquash())
                  .clamp(-0.8, 1.2),
              blink: ambientMotionOf(context),
              // The habit rows are below him, a little to the left.
              gaze: fed > 0 ? Offset(-0.5 * fed, 0.9 * fed) : Offset.zero,
              anticipation: fed,
              urgency: widget.urgency,
            ),
          );
        },
      ),
    );

    final bool touchable = widget.onPoke != null;
    return Semantics(
      label: widget.semanticLabel,
      button: touchable,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: touchable ? _onTap : null,
        onLongPressStart: touchable ? _startPetting : null,
        onLongPressMoveUpdate: touchable ? _pullTo : null,
        onLongPressEnd: touchable ? _release : null,
        child: SizedBox.square(
          dimension: widget.size,
          child: ParticleBurst(
            trigger: _bursts == 0 ? null : _bursts,
            origin: const Alignment(0, -0.1),
            count: 22,
            kinds: const <ParticleKind>[ParticleKind.spark, ParticleKind.star],
            power: 0.7,
            upward: true,
            child: AnimatedScale(
              // Petted, he glows up a little.
              scale: _petting ? 1.06 : 1,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: painted,
            ),
          ),
        ),
      ),
    );
  }
}
