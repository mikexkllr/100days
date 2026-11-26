import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/state/providers.dart';
import 'package:hundred_days/ui/home/home_screen.dart';
import 'package:hundred_days/ui/settings/habits_editor_screen.dart';

import 'helpers.dart';

/// Required or optional, and on which weekdays: picked in the habits
/// editor, shown on Today.
void main() {
  late AppRepository repository;

  setUp(() async {
    repository = await testRepository();
    await repository.saveProfile(displayName: 'Mike', avatarEmoji: '🐺');
    await repository.startChallenge(testChallenge(habits: const <HabitCategory>[
      HabitCategory.noSugar,
      HabitCategory.reading,
    ]));
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 7200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrapForTest(repository: repository, child: child));
    await tester.pumpAndSettle();
  }

  /// Opens the editor the way the settings do: pushed, once the state is
  /// loaded, so that saving can close it.
  Future<void> openEditor(WidgetTester tester) async {
    await pump(
      tester,
      Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) =>
            ref.watch(appStateProvider).hasValue
                ? TextButton(
                    key: const Key('open-editor'),
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const HabitsEditorScreen(),
                      ),
                    ),
                    child: const Text('open'),
                  )
                : const SizedBox(),
      ),
    );
    await tester.tap(find.byKey(const Key('open-editor')));
    await tester.pumpAndSettle();
  }

  Future<Habit> habit(String id) async =>
      (await repository.snapshot()).challenge!.habitById(id)!;

  testWidgets('a habit made optional is a bonus on Today, not a duty',
      (WidgetTester tester) async {
    await openEditor(tester);
    await tester.tap(find.descendant(
        of: find.byKey(const Key('required-reading')),
        matching: find.text('Freiwillig')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ein Bonus'), findsOneWidget);
    await tester.tap(find.byKey(const Key('habits-save')));
    await tester.pumpAndSettle();

    final Habit reading = await habit('reading');
    expect(reading.optional, isTrue);
    final Challenge challenge = (await repository.snapshot()).challenge!;
    expect(requiredHabitsOn(challenge, DayKey.today()).map((Habit h) => h.id),
        <String>['noSugar']);

    await pump(tester, const HomeScreen());
    expect(find.text('Freiwillig'), findsOneWidget);
    expect(find.text('Heute keine Pflicht — gibt trotzdem XP.'), findsOneWidget);
  });

  testWidgets('a cheat day is picked on its weekday', (WidgetTester tester) async {
    await openEditor(tester);
    await tester.tap(find.byKey(const Key('day-noSugar-${DateTime.sunday}')));
    await tester.pumpAndSettle();
    expect(find.text('6 Tage pro Woche · frei: SO'), findsOneWidget);
    await tester.tap(find.byKey(const Key('habits-save')));
    await tester.pumpAndSettle();

    final Habit noSugar = await habit('noSugar');
    expect(noSugar.weekdays, <int>[1, 2, 3, 4, 5, 6]);
    expect(noSugar.optional, isFalse);
  });

  testWidgets('the last day cannot be taken away, and not everything can be optional',
      (WidgetTester tester) async {
    await openEditor(tester);
    for (int d = DateTime.monday; d <= DateTime.sunday; d++) {
      await tester.tap(find.byKey(Key('day-reading-$d')));
      await tester.pumpAndSettle();
    }
    // Six days off; the seventh tap is refused.
    expect(find.textContaining('1 Tag pro Woche'), findsOneWidget);

    for (final String id in <String>['reading', 'noSugar']) {
      await tester.tap(find.descendant(
          of: find.byKey(Key('required-$id')), matching: find.text('Freiwillig')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('habits-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mindestens eine Gewohnheit muss Pflicht sein'),
        findsOneWidget);
    expect((await habit('noSugar')).optional, isFalse);
  });
}
