import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../theme/fire.dart';
import '../mascot/flame_mascot.dart';
import '../motion/motion.dart';

/// Feeding Funki: an ember leaves the habit just checked in and arcs into
/// his mouth. Only when ambient motion is allowed; it never blocks a tap.
void flyEmber(
  BuildContext context, {
  required Offset from,
  required Offset to,
  required Fire fire,
  required VoidCallback onArrive,
}) {
  if (!ambientMotionOf(context)) {
    onArrive();
    return;
  }
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    onArrive();
    return;
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) => _Ember(
      from: from,
      to: to,
      fire: fire,
      onDone: () {
        entry.remove();
        onArrive();
      },
    ),
  );
  overlay.insert(entry);
}

/// Funki scrolled out of sight: a small one peeks in at the top, catches the
/// ember and is gone again.
void showMiniFunki(
  BuildContext context, {
  required Offset at,
  required FlameStage stage,
}) {
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || !ambientMotionOf(context)) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) => _MiniFunki(
      at: at,
      stage: stage,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _Ember extends StatefulWidget {
  const _Ember({
    required this.from,
    required this.to,
    required this.fire,
    required this.onDone,
  });

  final Offset from;
  final Offset to;
  final Fire fire;
  final VoidCallback onDone;

  @override
  State<_Ember> createState() => _EmberState();
}

class _EmberState extends State<_Ember> with SingleTickerProviderStateMixin {
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  /// A quadratic arc that rises above both ends, like something tossed.
  Offset _at(double t) {
    final Offset control = Offset(
      (widget.from.dx + widget.to.dx) / 2,
      math.min(widget.from.dy, widget.to.dy) - 120,
    );
    final double u = 1 - t;
    return widget.from * (u * u) + control * (2 * u * t) + widget.to * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _flight,
        builder: (BuildContext context, Widget? _) {
          final double t = Curves.easeInOutCubic.transform(_flight.value);
          final List<Widget> trail = <Widget>[
            for (int i = 4; i >= 0; i--)
              _dot(_at(math.max(0, t - i * 0.035)), 14 - i * 2.4,
                  1 - i * 0.18),
          ];
          return Stack(children: trail);
        },
      ),
    );
  }

  Widget _dot(Offset at, double size, double opacity) => Positioned(
        left: at.dx - size / 2,
        top: at.dy - size / 2,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                Colors.white.withValues(alpha: opacity),
                widget.fire.light.withValues(alpha: opacity),
                widget.fire.main.withValues(alpha: 0),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.fire.main.withValues(alpha: 0.6 * opacity),
                blurRadius: 12,
              ),
            ],
          ),
        ),
      );
}

class _MiniFunki extends StatefulWidget {
  const _MiniFunki({
    required this.at,
    required this.stage,
    required this.onDone,
  });

  final Offset at;
  final FlameStage stage;
  final VoidCallback onDone;

  @override
  State<_MiniFunki> createState() => _MiniFunkiState();
}

class _MiniFunkiState extends State<_MiniFunki>
    with SingleTickerProviderStateMixin {
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward().whenComplete(widget.onDone);

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double size = 64;
    return Positioned(
      left: widget.at.dx - size / 2,
      top: widget.at.dy - size / 2,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _life,
          builder: (BuildContext context, Widget? child) {
            final double t = _life.value;
            // Pops in, gulps, sinks back out.
            final double scale = t < 0.3
                ? popCurve(t / 0.3)
                : t > 0.8
                    ? 1 - (t - 0.8) / 0.2
                    : 1;
            return Transform.scale(scale: scale.clamp(0.0, 1.2), child: child);
          },
          child: FlameMascot(
            stage: widget.stage,
            mood: MascotMood.happy,
            size: size,
          ),
        ),
      ),
    );
  }
}
