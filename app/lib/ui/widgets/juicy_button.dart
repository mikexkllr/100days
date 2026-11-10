import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/theme.dart';
import '../motion/motion.dart';

enum JuicyHaptic { none, light, medium, heavy }

/// The button that wants to be pressed.
///
/// A raised face of light on a darker lip, so it looks like something you
/// push in; it sinks under the finger and springs back with a buzz. The
/// main call to action can breathe and catch a sheen every few seconds.
class JuicyButton extends StatefulWidget {
  const JuicyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient = AppGradients.primary,
    this.lipColor = const Color(0xFF9399AE),
    this.foreground = AppColors.onPrimary,
    this.height = 54,
    this.shimmer = false,
    this.pulse = false,
    this.haptic = JuicyHaptic.medium,
    this.fontSize = 17,
    this.glow,
  });

  /// Success green: what a done button looks like.
  const JuicyButton.success({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 54,
    this.shimmer = false,
    this.pulse = false,
    this.haptic = JuicyHaptic.medium,
    this.fontSize = 17,
    this.glow,
  })  : gradient = AppGradients.success,
        lipColor = const Color(0xFF1B8E70),
        foreground = const Color(0xFF032019);

  /// Holographic foil: rewards and "keep going".
  const JuicyButton.holo({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 58,
    this.shimmer = true,
    this.pulse = false,
    this.haptic = JuicyHaptic.heavy,
    this.fontSize = 18,
    this.glow = AppColors.reward,
  })  : gradient = AppGradients.holo,
        lipColor = const Color(0xFF6A5BC4),
        foreground = const Color(0xFF14102E);

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient gradient;
  final Color lipColor;
  final Color foreground;
  final double height;
  final bool shimmer;
  final bool pulse;
  final JuicyHaptic haptic;
  final double fontSize;
  final Color? glow;

  @override
  State<JuicyButton> createState() => _JuicyButtonState();
}

class _JuicyButtonState extends State<JuicyButton>
    with SingleTickerProviderStateMixin {
  static const double _lip = 4;
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 260),
  );

  bool get _enabled => widget.onPressed != null;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _buzz() {
    switch (widget.haptic) {
      case JuicyHaptic.none:
        break;
      case JuicyHaptic.light:
        HapticFeedback.lightImpact();
      case JuicyHaptic.medium:
        HapticFeedback.mediumImpact();
      case JuicyHaptic.heavy:
        HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Gradient face = _enabled
        ? widget.gradient
        : const LinearGradient(
            colors: <Color>[AppColors.surfaceHigh, AppColors.surfaceHigh],
          );
    final Color lip = _enabled ? widget.lipColor : AppColors.outline;
    final Color foreground =
        _enabled ? widget.foreground : AppColors.textTertiary;
    final bool ambient = ambientMotionOf(context);

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (widget.icon != null) ...<Widget>[
          Icon(widget.icon, size: widget.fontSize + 3, color: foreground),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: kTextFont,
              fontSize: widget.fontSize * 0.95,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
              color: foreground,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _press.forward() : null,
        onTapCancel: _enabled ? () => _press.reverse() : null,
        onTapUp: _enabled ? (_) => _press.reverse() : null,
        onTap: _enabled
            ? () {
                _buzz();
                widget.onPressed!();
              }
            : null,
        child: AnimatedBuilder(
          animation: _press,
          builder: (BuildContext context, Widget? child) {
            final double sink = _press.value * (_lip - 1);
            return SizedBox(
              height: widget.height + _lip,
              child: Stack(
                children: <Widget>[
                  // The lip: what the face sinks into.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _lip,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: lip,
                        borderRadius: AppRadius.pill,
                        boxShadow: _enabled && widget.glow != null
                            ? AppShadows.glow(widget.glow!, strength: 0.8)
                            : null,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: sink,
                    height: widget.height,
                    child: child!,
                  ),
                ],
              ),
            );
          },
          child: _Face(
            gradient: face,
            shimmer: widget.shimmer && _enabled && ambient,
            pulse: widget.pulse && _enabled && ambient,
            child: content,
          ),
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.gradient,
    required this.shimmer,
    required this.pulse,
    required this.child,
  });

  final Gradient gradient;
  final bool shimmer;
  final bool pulse;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Widget face = DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: AppRadius.pill,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(child: child),
          ),
        ],
      ),
    );
    if (!shimmer && !pulse) return face;
    return AmbientClock(
      child: face,
      builder: (BuildContext context, double seconds, Widget? face) {
        // A sheen sweeps across every 3.2 s; a slow breath in between.
        final double phase = (seconds % 3.2) / 3.2;
        final double breath =
            pulse ? 1 + 0.025 * math.sin(seconds * math.pi * 1.3) : 1;
        Widget result = face!;
        if (shimmer && phase < 0.35) {
          final double x = -1.6 + (phase / 0.35) * 3.2;
          result = ClipRRect(
            borderRadius: AppRadius.pill,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                result,
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(x - 0.5, -1),
                        end: Alignment(x + 0.5, 1),
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.5),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Transform.scale(scale: breath, child: result);
      },
    );
  }
}
