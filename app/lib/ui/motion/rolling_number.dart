import 'package:flutter/material.dart';

import 'motion.dart';

/// A number that counts its way to a new value instead of jumping there,
/// and gives a little pop when it lands. Number goes up; you see it go up.
class RollingNumber extends StatefulWidget {
  const RollingNumber({
    super.key,
    required this.value,
    required this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 900),
    this.countFromZero = false,
    this.gradient,
    this.glow,
    this.textAlign = TextAlign.center,
  });

  final int value;
  final TextStyle style;
  final String prefix;
  final String suffix;
  final Duration duration;

  /// Count up from zero the first time it is shown.
  final bool countFromZero;
  final Gradient? gradient;
  final Color? glow;
  final TextAlign textAlign;

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late int _from = widget.countFromZero ? 0 : widget.value;
  late int _to = widget.value;

  @override
  void initState() {
    super.initState();
    if (_from != _to) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(RollingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _from = _current;
      _to = widget.value;
      _controller.forward(from: 0);
    }
  }

  int get _current {
    final double t = Curves.easeOutCubic.transform(_controller.value);
    return (_from + (_to - _from) * t).round();
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
      builder: (BuildContext context, Widget? _) {
        final double t = _controller.value;
        // The pop lands with the last digit.
        final double scale =
            _from == _to ? 1 : bounceScale(((t - 0.62) / 0.38).clamp(0, 1));
        return Transform.scale(
          scale: scale,
          child: GlowText(
            '${widget.prefix}$_current${widget.suffix}',
            style: widget.style.copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
            gradient: widget.gradient,
            glow: widget.glow,
            textAlign: widget.textAlign,
          ),
        );
      },
    );
  }
}

/// Text that glows, optionally filled with a gradient — for the numbers the
/// whole app exists to make go up.
class GlowText extends StatelessWidget {
  const GlowText(
    this.text, {
    super.key,
    required this.style,
    this.gradient,
    this.glow,
    this.textAlign = TextAlign.center,
    this.maxLines,
  });

  final String text;
  final TextStyle style;
  final Gradient? gradient;
  final Color? glow;
  final TextAlign textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final List<Shadow>? shadows = glow == null
        ? style.shadows
        : <Shadow>[
            Shadow(color: glow!.withValues(alpha: 0.85), blurRadius: 18),
            Shadow(color: glow!.withValues(alpha: 0.45), blurRadius: 42),
          ];
    final Widget text = Text(
      this.text,
      style: style.copyWith(
        shadows: shadows,
        color: gradient == null ? style.color : const Color(0xFFFFFFFF),
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
    if (gradient == null) return text;
    // The mask is measured on the laid-out text, so the gradient runs over
    // the glyphs wherever they sit on screen.
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) => gradient!.createShader(bounds),
      child: text,
    );
  }
}
