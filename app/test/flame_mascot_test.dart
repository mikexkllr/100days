import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/ui/mascot/flame_mascot.dart';

void main() {
  // His drawing sits under a LayoutBuilder, so it is built at layout. A
  // Funki taken out of the tree before his first layout (the app shell does
  // that on start) used to build his animation controllers in dispose(), on
  // an element already gone. That threw while Flutter finalized the tree,
  // the rest of the unmount was skipped, and a dead Scaffold stayed
  // registered: every snackbar after it failed.
  testWidgets('Funki removed before his first layout leaves cleanly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: FlameMascot(
              stage: FlameStage.ember,
              mood: MascotMood.hopeful,
            ),
          ),
        ),
      ),
      phase: EnginePhase.build,
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(tester.takeException(), isNull);
  });
}
