import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_days/ui/mascot/speech_bubble.dart';

Future<void> _paintAt(WidgetTester tester, double width, double tailAt) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: SpeechBubble(text: 'Weiter so!', tailAt: tailAt),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // With the keyboard up a bubble can be squeezed narrower than the 56 px
  // its tail keeps clear of the corners. Placing the tail then clamped
  // against an upper limit below the lower one, which threw while painting
  // (Sentry 100DAYS-4).
  for (final double width in <double>[40, 12, 0]) {
    testWidgets('a bubble $width px wide paints', (WidgetTester tester) async {
      for (final double tailAt in <double>[0, 0.5, 1]) {
        await _paintAt(tester, width, tailAt);
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(SpeechBubble)).width, width);
      }
    });
  }

  testWidgets('a normal bubble still paints its tail anywhere', (
    WidgetTester tester,
  ) async {
    for (final double tailAt in <double>[0, 0.5, 1]) {
      await _paintAt(tester, 240, tailAt);
      expect(tester.takeException(), isNull);
    }
  });
}
