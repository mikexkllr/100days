import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../motion/motion.dart';

/// What Funki says: a quiet dark bubble that pops in and types its line
/// out, its tail pointing at Funki.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.text,
    this.maxWidth = 340,
    this.accent = AppColors.primary,
    this.tailAt = 0.5,
  });

  final String text;
  final double maxWidth;

  /// The colour of the rim — set when the line is urgent.
  final Color accent;

  /// Where along the bottom edge the tail sits, 0 (left) to 1 (right).
  final double tailAt;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = Theme.of(context).textTheme.bodyLarge!.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
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
            scale: 0.75 + 0.25 * pop,
            alignment: Alignment(tailAt * 2 - 1, 1),
            child: CustomPaint(
              painter: _BubblePainter(accent: accent, tailAt: tailAt),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 9 + _tail),
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
                  textAlign: TextAlign.left,
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

const double _tail = 10;

class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.accent, required this.tailAt});

  final Color accent;
  final double tailAt;

  Path _outline(Size size) {
    final Rect body = Rect.fromLTRB(0, 0, size.width, size.height - _tail);
    final double x = (size.width * tailAt).clamp(28.0, size.width - 28);
    final Path tail = Path()
      ..moveTo(x - 10, body.bottom - 1)
      ..quadraticBezierTo(x - 1, body.bottom + 2, x + 3, size.height)
      ..quadraticBezierTo(x + 4, body.bottom + 3, x + 12, body.bottom - 1)
      ..close();
    return Path.combine(
      PathOperation.union,
      Path()
        ..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(17))),
      tail,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _outline(size);
    canvas.drawPath(
      path,
      Paint()..color = AppColors.surfaceHigh.withValues(alpha: 0.94),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent.withValues(alpha: accent == AppColors.primary ? 0.16 : 0.7),
    );
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.tailAt != tailAt;
}
