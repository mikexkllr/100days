import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Whether looping, decorative motion may run here: flickering flames,
/// rising embers, shimmer. Off when the system asks for less motion — and
/// that is also how widget tests keep `pumpAndSettle` from waiting forever.
///
/// One-shot motion that carries meaning (a reel landing on today's number, a
/// burst on check-in) still runs; it just finishes.
bool ambientMotionOf(BuildContext context) =>
    !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

/// Hands its builder a clock in seconds that keeps running while ambient
/// motion is allowed, and stands still at [frozenAt] when it is not.
class AmbientClock extends StatefulWidget {
  const AmbientClock({
    super.key,
    required this.builder,
    this.frozenAt = 1.2,
    this.child,
  });

  final Widget Function(BuildContext context, double seconds, Widget? child)
      builder;

  /// The moment shown when nothing may move — picked to look alive.
  final double frozenAt;
  final Widget? child;

  @override
  State<AmbientClock> createState() => _AmbientClockState();
}

class _AmbientClockState extends State<AmbientClock>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);
  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool shouldRun = ambientMotionOf(context);
    if (shouldRun && !_running) {
      _ticker.start();
    } else if (!shouldRun && _running) {
      _ticker.stop();
    }
    _running = shouldRun;
    if (!shouldRun) _seconds.value = widget.frozenAt;
  }

  void _onTick(Duration elapsed) {
    _seconds.value = widget.frozenAt + elapsed.inMicroseconds / 1e6;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _seconds,
      child: widget.child,
      builder: (BuildContext context, double seconds, Widget? child) =>
          widget.builder(context, seconds, child),
    );
  }
}

/// A one-shot animation that replays whenever [trigger] changes — the shape
/// of every "you did it" moment in the app.
class TriggeredAnimation extends StatefulWidget {
  const TriggeredAnimation({
    super.key,
    required this.trigger,
    required this.duration,
    required this.builder,
    this.child,
    this.playOnFirstBuild = false,
  });

  final Object? trigger;
  final Duration duration;
  final bool playOnFirstBuild;

  /// [t] runs 0 → 1 once per trigger and rests at 1 (or at 0 before the
  /// first trigger).
  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Widget? child;

  @override
  State<TriggeredAnimation> createState() => _TriggeredAnimationState();
}

class _TriggeredAnimationState extends State<TriggeredAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.playOnFirstBuild ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.playOnFirstBuild) _controller.forward();
  }

  @override
  void didUpdateWidget(TriggeredAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (BuildContext context, Widget? child) =>
          widget.builder(context, _controller.value, child),
    );
  }
}

/// A springy scale for 0 → 1: overshoots, settles. For things that land.
double popCurve(double t) => Curves.elasticOut.transform(t.clamp(0.0, 1.0));

/// Squash and stretch over one beat: 1 → 1.18 → 0.94 → 1.
double bounceScale(double t) {
  if (t <= 0 || t >= 1) return 1;
  if (t < 0.25) return 1 + 0.18 * Curves.easeOut.transform(t / 0.25);
  if (t < 0.55) {
    return 1.18 - 0.24 * Curves.easeInOut.transform((t - 0.25) / 0.3);
  }
  return 0.94 + 0.06 * Curves.easeOut.transform((t - 0.55) / 0.45);
}
