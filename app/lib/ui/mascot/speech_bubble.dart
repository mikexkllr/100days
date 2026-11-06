import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../motion/motion.dart';

/// What Funki says: a comic bubble that pops in and types its line out.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.text,
    this.maxWidth = 300,
    this.accent = AppColors.flame,
  });

  final String text;
  final double maxWidth;

  /// The colour of the bubble's rim.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = Theme.of(context).textTheme.bodyLarge!.copyWith(
          color: const Color(0xFF241018),
          fontWeight: FontWeight.w800,
          fontSize: 15.5,
          height: 1.3,
        );
    final int ms = (text.length * 28).clamp(350, 1300);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: TriggeredAnimation(
        trigger: text,
        playOnFirstBuild: true,
        duration: Duration(milliseconds: ms + 250),
        builder: (BuildContext context, double t, Widget? _) {
          final double pop = popCurve((t * (ms + 250) / 450).clamp(0, 1));
          final double typing = ((t * (ms + 250) - 150) / ms).clamp(0, 1);
          final int shown = (text.length * typing).ceil();
          return Transform.scale(
            scale: 0.7 + 0.3 * pop,
            alignment: Alignment.bottomCenter,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: const Color(0xFFFFF7F0),
                shape: _BubbleBorder(rim: accent),
                shadows: AppShadows.glow(accent, strength: 0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 11, 16, 11 + 10),
                // The whole line is laid out from the first frame, so the
                // bubble does not grow while it types; the rest is clear.
                child: Text.rich(
                  TextSpan(
                    children: <TextSpan>[
                      TextSpan(text: text.substring(0, shown)),
                      TextSpan(
                        text: text.substring(shown),
                        style: const TextStyle(color: Colors.transparent),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: style,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A rounded box with a tail pointing down at the speaker.
class _BubbleBorder extends ShapeBorder {
  const _BubbleBorder({required this.rim});

  final Color rim;
  static const double _tail = 10;
  static const double _radius = 18;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final Rect body = Rect.fromLTRB(
        rect.left, rect.top, rect.right, rect.bottom - _tail);
    final double mid = body.center.dx;
    final Path tail = Path()
      ..moveTo(mid - 11, body.bottom - 1)
      ..quadraticBezierTo(mid - 2, body.bottom + 2, mid + 1, rect.bottom)
      ..quadraticBezierTo(mid + 3, body.bottom + 3, mid + 12, body.bottom - 1)
      ..close();
    // One outline, so the rim runs around the tail instead of across it.
    return Path.combine(
      PathOperation.union,
      Path()
        ..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(_radius))),
      tail,
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    canvas.drawPath(
      getOuterPath(rect),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = rim,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}
