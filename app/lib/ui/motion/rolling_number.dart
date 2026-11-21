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
    this.stroke,
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

  /// Draws the number hollow, as an outline in this colour.
  final Color? stroke;
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
            stroke: widget.stroke,
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
    this.stroke,
    this.textAlign = TextAlign.center,
    this.maxLines,
  });

  final String text;
  final TextStyle style;
  final Gradient? gradient;
  final Color? glow;

  /// Hollow type: an outline in this colour over a breath of fill. Wins
  /// over [gradient] and [glow].
  final Color? stroke;
  final TextAlign textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    if (stroke != null) {
      // The glyphs are laid out by a real Text — invisible, but there for
      // layout, semantics and finders — and the outline is painted over it.
      final TextStyle resolved =
          DefaultTextStyle.of(context).style.merge(style);
      return CustomPaint(
        foregroundPainter: _OutlinePainter(
          text: text,
          style: resolved,
          color: stroke!,
          textAlign: textAlign,
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
        ),
        child: Text(
          text,
          style: style.copyWith(color: const Color(0x00000000)),
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
        ),
      );
    }
    if (gradient == null) {
      return Text(
        text,
        style: style.copyWith(
          shadows: glow == null
              ? style.shadows
              : <Shadow>[
                  Shadow(color: glow!.withValues(alpha: 0.55), blurRadius: 22),
                ],
        ),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      );
    }
    final Widget label = Text(
      text,
      style: style.copyWith(shadows: const <Shadow>[], color: const Color(0xFFFFFFFF)),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
    // The mask is measured on the laid-out text, so the gradient runs over
    // the glyphs wherever they sit on screen.
    final Widget masked = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) => gradient!.createShader(bounds),
      child: label,
    );
    if (glow == null) return masked;
    // The glow is painted underneath, blurred glyphs of its own. As a text
    // shadow inside the mask it was tinted only within the text's box, and
    // the box showed as a lighter rectangle behind the number.
    return CustomPaint(
      painter: _GlowPainter(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
        color: glow!,
        textAlign: textAlign,
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      ),
      child: masked,
    );
  }
}

/// A soft glow behind gradient text: the glyphs again, blurred, in [color].
class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.text,
    required this.style,
    required this.color,
    required this.textAlign,
    required this.textScaler,
    required this.textDirection,
  });

  final String text;
  final TextStyle style;
  final Color color;
  final TextAlign textAlign;
  final TextScaler textScaler;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          inherit: false,
          fontFamily: style.fontFamily,
          fontFamilyFallback: style.fontFamilyFallback,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          height: style.height,
          letterSpacing: style.letterSpacing,
          fontFeatures: style.fontFeatures,
          textBaseline: style.textBaseline ?? TextBaseline.alphabetic,
          foreground: Paint()
            ..color = color.withValues(alpha: 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
        ),
      ),
      textAlign: textAlign,
      textDirection: textDirection,
      textScaler: textScaler,
    )
      ..layout(minWidth: size.width, maxWidth: size.width)
      ..paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) =>
      oldDelegate.text != text ||
      oldDelegate.color != color ||
      oldDelegate.style != style;
}

/// Hollow type. A stroked glyph shows every seam where the font's own
/// contours overlap, so the outline is cut instead: the text is drawn fat,
/// and then its own fill is punched out of the middle.
class _OutlinePainter extends CustomPainter {
  _OutlinePainter({
    required this.text,
    required this.style,
    required this.color,
    required this.textAlign,
    required this.textScaler,
    required this.textDirection,
  });

  final String text;
  final TextStyle style;
  final Color color;
  final TextAlign textAlign;
  final TextScaler textScaler;
  final TextDirection textDirection;

  static const double _width = 1.7;

  TextPainter _layout(Paint foreground, Size size) {
    final TextStyle base = style.copyWith(shadows: const <Shadow>[]);
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          inherit: false,
          fontFamily: base.fontFamily,
          fontFamilyFallback: base.fontFamilyFallback,
          fontSize: base.fontSize,
          fontWeight: base.fontWeight,
          height: base.height,
          letterSpacing: base.letterSpacing,
          fontFeatures: base.fontFeatures,
          textBaseline: base.textBaseline ?? TextBaseline.alphabetic,
          foreground: foreground,
        ),
      ),
      textAlign: textAlign,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(minWidth: size.width, maxWidth: size.width);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = (Offset.zero & size).inflate(_width * 2);
    // A breath of fill, so the number has a body.
    _layout(Paint()..color = color.withValues(alpha: 0.06), size)
        .paint(canvas, Offset.zero);
    canvas.saveLayer(bounds, Paint());
    _layout(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _width * 2
        ..strokeJoin = StrokeJoin.round
        ..color = color,
      size,
    ).paint(canvas, Offset.zero);
    _layout(
      Paint()
        ..blendMode = BlendMode.dstOut
        ..color = const Color(0xFF000000),
      size,
    ).paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OutlinePainter oldDelegate) =>
      oldDelegate.text != text ||
      oldDelegate.color != color ||
      oldDelegate.style != style;
}
