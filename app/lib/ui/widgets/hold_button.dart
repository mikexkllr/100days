import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Press and hold to check in.
///
/// A check-in should feel like something you do, not something you brush
/// past: holding fills whatever [builder] draws, the phone ticks in your
/// hand at every quarter, and the moment it is full it fires with a hard
/// knock. Let go early and it drains away — nothing is logged. A quick tap
/// is not a check-in either; it is handed to [onTap]. Screen readers get a
/// plain tap action instead of the hold.
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    required this.builder,
    this.onTap,
    this.holdFor = const Duration(milliseconds: 620),
  });

  /// What a screen reader says, and what its tap confirms.
  final String label;

  /// Null turns the hold off: only [onTap] is left.
  final VoidCallback? onConfirmed;

  /// Pressed and let go at once.
  final VoidCallback? onTap;
  final Duration holdFor;

  /// Draws the surface; [fill] runs 0 → 1 while it is held.
  final Widget Function(BuildContext context, double fill) builder;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton>
    with SingleTickerProviderStateMixin {
  /// Let go before the fill has come this far and it was a tap.
  static const double _tap = 0.38;

  /// The first stretch of a press shows nothing, so that a tap or the start
  /// of a scroll does not flash the fill.
  static const Curve _visible = Interval(0.14, 1, curve: Curves.easeInOut);

  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: widget.holdFor,
    reverseDuration: const Duration(milliseconds: 240),
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

  void _down() {
    if (!_enabled) return;
    _fired = false;
    _quarter = 0;
    _fill.forward();
  }

  void _up() {
    if (_fired) return;
    // With nothing to hold for, every press is a tap.
    final bool tapped = !_enabled || _fill.value < _tap;
    _fill.reverse();
    if (tapped) widget.onTap?.call();
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
    return Semantics(
      button: true,
      enabled: _enabled || widget.onTap != null,
      label: widget.label,
      onTap: _enabled
          ? (_fired ? null : _fire)
          : widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _down(),
        onTapUp: (_) => _up(),
        onTapCancel: _cancel,
        child: AnimatedBuilder(
          animation: _fill,
          builder: (BuildContext context, Widget? _) =>
              widget.builder(context, _visible.transform(_fill.value)),
        ),
      ),
    );
  }
}
