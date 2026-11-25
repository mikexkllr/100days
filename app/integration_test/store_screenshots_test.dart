// Walks the demo (lib/main_demo.dart) through the screens the stores show.
// Run by tool/store_screenshots.sh, which reads the SHOT: lines and takes
// the simulator's own screenshot each time — with the real status bar, which
// a Flutter screenshot would not have.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_days/l10n/generated/app_localizations.dart';
import 'package:hundred_days/main_demo.dart' as demo;
import 'package:integration_test/integration_test.dart';

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Every frame, as on a phone: Funki, the stars and the ring animate.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('store screenshots', (WidgetTester tester) async {
    await demo.main();
    await _wait(tester, 5);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );

    Future<void> open(String label) async {
      final Finder target = find.text(label).last;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await _wait(tester, 2);
    }

    await _shot(tester, '01_today');
    await open(l10n.navPlan);
    await open(l10n.planTabTraining);
    await _shot(tester, '02_training');
    await open(l10n.planTabMeals);
    await _shot(tester, '03_meals');
    await open(l10n.planTabShopping);
    await _shot(tester, '04_shopping');
    await open(l10n.navFriends);
    await open(l10n.socialTabFeed);
    await _shot(tester, '05_friends');
    await open(l10n.socialTabLeague);
    await _shot(tester, '06_league');
    await open(l10n.navStats);
    await _shot(tester, '07_stats');
    // Not for the listing: the review screenshot App Store Connect wants
    // for each subscription.
    await open(l10n.navMore);
    // Further down the settings list, which builds rows as they scroll in.
    await tester.scrollUntilVisible(
      find.text(l10n.setAi),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await open(l10n.setAi);
    await _shot(tester, 'iap_premium');
  });
}

/// Lets real time pass while the app keeps drawing.
Future<void> _wait(WidgetTester tester, int seconds) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(seconds: seconds)));
  await tester.pump();
}

/// Tells the script to take a screenshot now, and holds still for it.
Future<void> _shot(WidgetTester tester, String name) async {
  // ignore: avoid_print
  print('SHOT:$name');
  await _wait(tester, 6);
}
