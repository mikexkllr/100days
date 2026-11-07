import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/theme.dart';
import '../motion/motion.dart';

/// Press and hold to ignite.
///
/// A check-in should feel like something you do, not something you brush
/// past: holding fills the bar with plasma, the phone ticks in your hand at
/// every quarter, and the moment it is full it fires with a hard knock. Let
/// go early and it drains away — nothing is logged. Screen readers get a
/// plain tap action instead of the hold.
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.hint,
    this.icon,
    this.height = 56,
    this.holdFor = const Duration(milliseconds: 550),
    this.gradient = AppGradients.plasma,
    this.compact = false,
  });

  final String label;

  /// A short word at the end, like "hold".
  final String? hint;
  final IconData? icon;
  final VoidCallback? onConfirmed;
  final double height;
  final Duration holdFor;
  final Gradient gradient;

  /// Tighter padding and a smaller face, for buttons next to a stepper.
  final bool compact;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill =
      AnimationController(
          vsync: this,
          duration: widget.holdFor,
          reverseDuration: const Duration(milliseconds: 260),
        )
        ..addListener(_onFill)
        ..addStatusListener(_onStatus);
  int _quarter = 0;
  bool _fired = false;
  Timer? _reset;

  bool get _enabled => widget.onConfirmed != null;

  void _onFill() {
    final int quarter = (_fill.value * 4).floor();
    if (_fill.status == AnimationStatus.forward &&
        quarter > _quarter &&
        quarter < 4) {
      HapticFeedback.selectionClick();
    }
    _quarter = quarter;
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_fired) _fire();
  }

  void _fire() {
    _fired = true;
    HapticFeedback.heavyImpact();
    widget.onConfirmed?.call();
    // Let the full bar be seen for a beat, then reset for the next time.
    _reset?.cancel();
    _reset = Timer(const Duration(milliseconds: 380), () {
      if (mounted) _fill.reverse();
    });
  }

  void _start() {
    if (!_enabled) return;
    _fired = false;
    _quarter = 0;
    HapticFeedback.lightImpact();
    _fill.forward();
  }

  void _cancel() {
    if (!_fired) _fill.reverse();
  }

  @override
  void dispose() {
    _reset?.cancel();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double radius = widget.height / 2;
    final bool ambient = ambientMotionOf(context);
    final TextStyle labelStyle = displayStyle(
      widget.compact ? 12 : 13.5,
      color: Colors.white,
      weight: FontWeight.w700,
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      onTap: _enabled && !_fired ? _fire : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _start(),
        onTapUp: (_) => _cancel(),
        onTapCancel: _cancel,
        child: AnimatedBuilder(
          animation: _fill,
          builder: (BuildContext context, Widget? _) {
            final double t = _fill.value;
            return Transform.scale(
              scale: 1 - 0.035 * t,
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: _enabled
                      ? AppGradients.edge(AppColors.primary)
                      : AppGradients.edge(),
                  boxShadow: t > 0
                      ? AppShadows.glow(AppColors.hot, strength: 0.4 + t)
                      : null,
                ),
                padding: const EdgeInsets.all(1.5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius - 1.5),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ColoredBox(
                        color: _enabled
                            ? AppColors.surfaceHigh.withValues(alpha: 0.85)
                            : AppColors.glass,
                      ),
                      // An idle shimmer, so the bar asks to be pressed.
                      if (_enabled && ambient && t == 0)
                        AmbientClock(
                          builder: (BuildContext context, double s, Widget? _) {
                            final double phase = (s % 2.6) / 2.6;
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment(-2 + phase * 4, 0),
                                    end: Alignment(-1 + phase * 4, 0),
                                    colors: <Color>[
                                      Colors.white.withValues(alpha: 0),
                                      AppColors.primary.withValues(alpha: 0.28),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: t,
                        child: DecoratedBox(
                          decoration: BoxDecoration(gradient: widget.gradient),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints box) {
                          // Narrow: the hint keeps only its finger, the
                          // compact face drops its icon — the label wins.
                          final bool roomy = box.maxWidth >= 250;
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.compact ? 10 : 16,
                            ),
                            child: Row(
                              mainAxisAlignment: widget.compact
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: <Widget>[
                                if (widget.icon != null &&
                                    !widget.compact) ...<Widget>[
                                  Icon(
                                    widget.icon,
                                    size: widget.compact ? 17 : 20,
                                    color: _enabled
                                        ? Colors.white
                                        : AppColors.textTertiary,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  fit: widget.compact
                                      ? FlexFit.loose
                                      : FlexFit.tight,
                                  child: Text(
                                    widget.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: labelStyle.copyWith(
                                      color: _enabled
                                          ? Colors.white
                                          : AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                                if (widget.hint != null && _enabled)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: AppRadius.pill,
                                      color: Colors.black.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        const Icon(
                                          Icons.touch_app,
                                          size: 12,
                                          color: Colors.white70,
                                        ),
                                        if (roomy) ...<Widget>[
                                          const SizedBox(width: 3),
                                          Text(
                                            widget.hint!.toUpperCase(),
                                            style: const TextStyle(
                                              fontFamily: kTextFont,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.8,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
