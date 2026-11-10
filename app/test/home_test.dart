import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/l10n/l10n.dart';
import 'package:hundred_days/ui/celebration/day_complete.dart';
import 'package:hundred_days/ui/home/home_screen.dart';
import 'package:hundred_days/ui/home/day_sheet.dart';
import 'package:hundred_days/ui/home/streak_hero.dart';
import 'package:hundred_days/ui/home/today.dart';
import 'package:hundred_days/ui/home/week_strip.dart';
import 'package:hundred_days/ui/mascot/flame_mascot.dart';
import 'package:hundred_days/ui/motion/rolling_number.dart';
import 'package:hundred_days/ui/widgets/day_board.dart';
import 'package:hundred_days/ui/widgets/habit_tile.dart';
import 'package:hundred_days/ui/widgets/hold_button.dart';
import 'package:hundred_days/ui/widgets/pressure_banner.dart';
import 'package:hundred_days/ui/widgets/streak_ring.dart';

import 'helpers.dart';

void main() {
  late AppRepository repository;

  Future<void> startChallenge({
    List<HabitCategory> habits = const <HabitCategory>[
      HabitCategory.noSugar,
      HabitCategory.reading,
    ],
  }) async {
    await repository.saveProfile(displayName: 'Mike', avatarEmoji: '🐺');
    await repository.startChallenge(testChallenge(habits: habits));
  }

  setUp(() async {
    repository = await testRepository();
  });

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('de'),
  }) async {
    // Taller than any phone on purpose: the home screen is a lazily built
    // scroll view, so whatever lies below the fold is unbuilt or offstage and
    // invisible to finders — the coach card and the board at the bottom.
    tester.view.physicalSize = const Size(1080, 7200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapForTest(
      repository: repository,
      locale: locale,
      child: const HomeScreen(),
    ));
    await tester.pumpAndSettle();
  }

  /// Press and hold until the bar is full, the way a person checks in.
  Future<void> holdToIgnite(WidgetTester tester, String label) async {
    final Finder button = find.widgetWithText(HoldButton, label);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(button));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('shows Funki in the ring of today and today\'s habits',
      (WidgetTester tester) async {
    await startChallenge();
    await pump(tester);

    expect(find.byType(TodayRing), findsOneWidget);
    expect(find.byType(FlameMascot), findsOneWidget);
    expect(find.text('Tag 1 / 100'), findsOneWidget);
    expect(find.byType(HabitTile), findsNWidgets(2));
    expect(find.text('Kein Zucker'), findsOneWidget);
    expect(find.text('Lesen'), findsOneWidget);
  });

  testWidgets('checking in writes a signed event and updates the tile',
      (WidgetTester tester) async {
    await startChallenge(habits: <HabitCategory>[HabitCategory.noSugar]);
    await pump(tester);

    await holdToIgnite(tester, 'Heute clean');

    final List<FeedEvent> all =
        await repository.store.eventsOf(repository.did);
    final List<FeedEvent> checkIns = all
        .where((FeedEvent e) => e.type == FeedEventType.checkIn)
        .toList();
    expect(checkIns, hasLength(1));
    expect(checkIns.single.payload['habitId'], 'noSugar');

    // The whole chain has to verify, not just the new link: that is what a
    // friend's device will do when it replicates this feed.
    for (int i = 0; i < all.length; i++) {
      final EventValidationResult result = await validateEvent(
        all[i],
        previous: i == 0 ? null : all[i - 1],
      );
      expect(result.isValid, isTrue, reason: 'event ${all[i].type} at $i');
    }

    expect(find.widgetWithText(DoneBadge, 'Erledigt'), findsOneWidget);
  });

  testWidgets('a completed day is reflected in the streak',
      (WidgetTester tester) async {
    await startChallenge(habits: <HabitCategory>[HabitCategory.noSugar]);
    await pump(tester);

    expect(find.text('0'), findsWidgets);

    await holdToIgnite(tester, 'Heute clean');

    final AppSnapshot snapshot = await repository.snapshot();
    expect(snapshot.me.streak.doneToday, isTrue);
    expect(snapshot.me.streak.current, 1);
    expect(snapshot.me.lifetimeXp, greaterThan(0));
  });

  testWidgets('names the friends who already trained today',
      (WidgetTester tester) async {
    await startChallenge();
    await seedFriend(repository, name: 'Marcel', emoji: '🦍');
    await pump(tester);

    expect(find.byType(PressureBanner), findsOneWidget);
    expect(find.textContaining('Marcel'), findsWidgets);
    expect(
      find.textContaining('Du stehst heute noch auf null'),
      findsOneWidget,
    );
  });

  testWidgets('shows no pressure banner when nobody has been active',
      (WidgetTester tester) async {
    await startChallenge();
    await seedFriend(
      repository,
      name: 'Lisa',
      emoji: '🦊',
      inactiveDays: 1,
    );
    await pump(tester);

    expect(
      find.descendant(
        of: find.byType(PressureBanner),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });

  testWidgets('the whole screen renders in English for an English phone',
      (WidgetTester tester) async {
    await startChallenge();
    await seedFriend(repository, name: 'Marcel', emoji: '🦍');
    await pump(tester, locale: const Locale('en'));

    expect(find.text('No sugar'), findsOneWidget);
    expect(find.text('Reading'), findsOneWidget);
    expect(find.text("Today's quests"), findsOneWidget);
    expect(find.textContaining('Day 1 / 100'), findsOneWidget);
    expect(find.textContaining('still on zero'), findsOneWidget);

    // And nothing German is left behind on the same screen.
    expect(find.text('Kein Zucker'), findsNothing);
    expect(find.text('Quests für heute'), findsNothing);
  });

  testWidgets('the same state reads differently in the two languages',
      (WidgetTester tester) async {
    await startChallenge(habits: <HabitCategory>[HabitCategory.noSugar]);

    await pump(tester);
    expect(find.widgetWithText(HoldButton, 'Heute clean'), findsOneWidget);

    await pump(tester, locale: const Locale('en'));
    expect(find.widgetWithText(HoldButton, 'Clean today'), findsOneWidget);
    expect(find.widgetWithText(HoldButton, 'Heute clean'), findsNothing);
  });

  testWidgets('the coach speaks on the home screen',
      (WidgetTester tester) async {
    await startChallenge();
    await pump(tester);

    expect(find.text('COACH'), findsOneWidget);
    expect(find.textContaining('Tag 1 von 100'), findsWidgets);
  });

  testWidgets('rest days are labelled instead of shown as failures',
      (WidgetTester tester) async {
    // Gym runs four days a week (Mon, Tue, Thu, Fri), so whether today is a
    // training day depends on the calendar — assert whichever case applies.
    await startChallenge(habits: <HabitCategory>[HabitCategory.gym]);
    await pump(tester);

    final bool isTrainingDay = const <int>[
      DateTime.monday,
      DateTime.tuesday,
      DateTime.thursday,
      DateTime.friday,
    ].contains(DayKey.today().toDateTime().weekday);

    if (isTrainingDay) {
      expect(find.byType(HabitTile), findsWidgets);
      expect(find.textContaining('Pausentag'), findsNothing);
    } else {
      expect(find.textContaining('Pausentag laut Plan'), findsOneWidget);
      // The habit is still offered as an optional extra rather than hidden.
      expect(find.text('Freiwillig'), findsOneWidget);
    }
  });

  testWidgets('completing the day rolls the machine with the real numbers',
      (WidgetTester tester) async {
    await startChallenge(habits: <HabitCategory>[HabitCategory.noSugar]);
    await pump(tester);

    await holdToIgnite(tester, 'Heute clean');

    expect(find.byType(DayCompleteCelebration), findsOneWidget);
    final AppSnapshot snapshot = await repository.snapshot();
    final Finder machine = find.byType(DayCompleteCelebration);
    // The reels land on what the feed proves: a one-day streak and exactly
    // the XP the day scored.
    expect(
      find.descendant(of: machine, matching: find.text('1')),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: machine,
        matching: find.text('+${snapshot.me.xpByDay[snapshot.today.toString()]}'),
      ),
      findsOneWidget,
    );
    // Day 1 is a milestone and the ember's first evolution: a real jackpot.
    expect(find.text('JACKPOT!'), findsOneWidget);
    expect(find.text('Meilenstein: Tag 1'), findsOneWidget);
    expect(find.text('Neue Form: Funke'), findsOneWidget);

    await tester.tap(find.byKey(const Key('celebration-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(DayCompleteCelebration), findsNothing);
    expect(find.widgetWithText(DoneBadge, 'Erledigt'), findsOneWidget);
  });

  testWidgets('a check-in that leaves the day open rolls nothing',
      (WidgetTester tester) async {
    await startChallenge();
    await pump(tester);

    await holdToIgnite(tester, 'Heute clean');

    expect(find.byType(DayCompleteCelebration), findsNothing);
    expect(find.text('1 von 2 erledigt'), findsOneWidget);
  });

  testWidgets('Funki waits on an open day and grins when it is done',
      (WidgetTester tester) async {
    await startChallenge(habits: <HabitCategory>[HabitCategory.noSugar]);
    await pump(tester);

    FlameMascot mascot() =>
        tester.widget<FlameMascot>(find.byType(FlameMascot).first);
    // No streak yet: a small ember, hoping.
    expect(mascot().stage, FlameStage.ember);
    expect(mascot().mood, MascotMood.hopeful);
    expect(find.byType(DayCountdown), findsOneWidget);

    await holdToIgnite(tester, 'Heute clean');
    await tester.tap(find.byKey(const Key('celebration-continue')));
    await tester.pumpAndSettle();

    expect(mascot().mood, MascotMood.happy);
    expect(mascot().stage, FlameStage.spark);
    expect(find.byType(DayCountdown), findsNothing);
    expect(find.text('Heute gefüttert. Bis morgen.'), findsOneWidget);
  });

  testWidgets('the week strip shows today and the days around it',
      (WidgetTester tester) async {
    await startChallenge();
    await pump(tester);

    final WeekStrip strip = tester.widget<WeekStrip>(find.byType(WeekStrip));
    final int todayIndex = DayKey.today().toDateTime().weekday - 1;
    expect(strip.marks[todayIndex], DayMark.open);
    for (int i = 0; i < todayIndex; i++) {
      expect(strip.marks[i], DayMark.none, reason: 'before the start');
    }
  });

  testWidgets('poking Funki gets an answer', (WidgetTester tester) async {
    await startChallenge();
    await pump(tester);

    final List<String> pokes = (await localizationsFor(const Locale('de')))
        .mascotPokes;
    await tester.tap(find.byType(FlameMascot).first);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(
      pokes.any((String line) => find.text(line).evaluate().isNotEmpty),
      isTrue,
    );
    // The line goes back to the day's own after a moment.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(
      pokes.any((String line) => find.text(line).evaluate().isNotEmpty),
      isFalse,
    );
  });

  testWidgets('letting go early logs nothing', (WidgetTester tester) async {
    await startChallenge(habits: <HabitCategory>[HabitCategory.noSugar]);
    await pump(tester);

    final Finder button = find.widgetWithText(HoldButton, 'Heute clean');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.up();
    await tester.pumpAndSettle();

    final List<FeedEvent> checkIns = (await repository.store
            .eventsOf(repository.did))
        .where((FeedEvent e) => e.type == FeedEventType.checkIn)
        .toList();
    expect(checkIns, isEmpty);
    expect(find.widgetWithText(HoldButton, 'Heute clean'), findsOneWidget);
  });

  testWidgets('a screen reader checks in with a plain tap',
      (WidgetTester tester) async {
    await startChallenge(habits: <HabitCategory>[HabitCategory.noSugar]);
    await pump(tester);

    final SemanticsHandle semantics = tester.ensureSemantics();
    final Finder button = find.widgetWithText(HoldButton, 'Heute clean');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final SemanticsNode node = tester.getSemantics(button);
    expect(node.label, contains('Heute clean'));
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    semantics.dispose();

    final AppSnapshot snapshot = await repository.snapshot();
    expect(snapshot.me.streak.doneToday, isTrue);
  });

  testWidgets('the ring has a segment per habit and closes with the day',
      (WidgetTester tester) async {
    await startChallenge();
    await pump(tester);

    TodayRing ring() => tester.widget<TodayRing>(find.byType(TodayRing));
    expect(ring().parts, <double>[0, 0]);

    await holdToIgnite(tester, 'Heute clean');
    expect(ring().parts, <double>[1, 0]);
  });

  testWidgets('the streak is hollow while today is open and lit once it is safe',
      (WidgetTester tester) async {
    // A streak that is alive and at stake: every day before today done.
    final Challenge challenge = testChallenge(
      startDay: DayKey.today().addDays(-3),
      habits: <HabitCategory>[HabitCategory.noSugar],
    );
    await repository.saveProfile(displayName: 'Mike', avatarEmoji: '🐺');
    await repository.startChallenge(challenge);
    for (int i = 3; i >= 1; i--) {
      await repository.checkIn(
        habit: challenge.habits.single,
        day: DayKey.today().addDays(-i),
        challenge: challenge,
      );
    }
    await pump(tester);

    RollingNumber number() => tester.widget<RollingNumber>(
          find.descendant(
            of: find.byType(StreakHero),
            matching: find.byType(RollingNumber),
          ),
        );
    expect(number().value, 3);
    expect(number().stroke, isNotNull, reason: 'at stake: an outline');
    expect(number().gradient, isNull);

    await holdToIgnite(tester, 'Heute clean');
    await tester.tap(find.byKey(const Key('celebration-continue')));
    await tester.pumpAndSettle();

    expect(number().value, 4);
    expect(number().stroke, isNull);
    expect(number().gradient, isNotNull, reason: 'safe: filled with fire');
  });

  testWidgets('a tap on a row opens what else it can do',
      (WidgetTester tester) async {
    await startChallenge();
    await pump(tester);

    // A relapse is not on the row itself: one tap away.
    expect(find.text('Rückfall'), findsNothing);
    await tester.tap(find.text('Kein Zucker'));
    await tester.pumpAndSettle();
    expect(find.text('Rückfall'), findsOneWidget);

    // Reading takes a number: the stepper and a button to log it.
    await tester.tap(find.text('Lesen'));
    await tester.pumpAndSettle();
    expect(find.text('20 Seiten'), findsWidgets);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eintragen'));
    await tester.pumpAndSettle();

    final AppSnapshot snapshot = await repository.snapshot();
    final CheckIn entry =
        snapshot.me.logsByDay[snapshot.today.toString()]!.entryFor('reading')!;
    expect(entry.value, 25);
    // And nothing was logged for the row that was only opened.
    expect(
      snapshot.me.logsByDay[snapshot.today.toString()]!.entryFor('noSugar'),
      isNull,
    );
  });

  testWidgets('less than the target is progress, not a finished habit',
      (WidgetTester tester) async {
    await startChallenge(habits: <HabitCategory>[HabitCategory.reading]);
    await pump(tester);

    await tester.tap(find.text('Lesen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.remove));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eintragen'));
    await tester.pumpAndSettle();

    expect(find.byType(DayCompleteCelebration), findsNothing);
    expect(find.text('10 / 20 Seiten'), findsOneWidget);
    expect(tester.widget<TodayRing>(find.byType(TodayRing)).parts, <double>[0.5]);
    expect(find.byType(DoneBadge), findsNothing);
  });

  testWidgets('a day of the week opens what was logged on it',
      (WidgetTester tester) async {
    await startChallenge(habits: <HabitCategory>[HabitCategory.noSugar]);
    await pump(tester);
    await holdToIgnite(tester, 'Heute clean');
    await tester.tap(find.byKey(const Key('celebration-continue')));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(WeekStrip),
      matching: find.byIcon(Icons.check_rounded),
    ));
    await tester.pumpAndSettle();

    final Finder sheet = find.byType(DaySheet);
    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Tag geschafft')),
        findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Kein Zucker')),
        findsOneWidget);
  });

  testWidgets('the cycle is a board with a lamp for every day',
      (WidgetTester tester) async {
    await startChallenge(habits: <HabitCategory>[HabitCategory.noSugar]);
    await pump(tester);

    DayBoard board() => tester.widget<DayBoard>(find.byType(DayBoard));
    expect(board().marks, hasLength(100));
    expect(board().marks.first, DayMark.open);
    expect(board().todayIndex, 0);
    expect(find.text('Deine 100 Tage'), findsOneWidget);

    await holdToIgnite(tester, 'Heute clean');
    await tester.tap(find.byKey(const Key('celebration-continue')));
    await tester.pumpAndSettle();
    expect(board().marks.first, DayMark.done);
    expect(board().marks.skip(1).toSet(), <DayMark>{DayMark.upcoming});
  });

  test('the aurora stands as high as today is done', () async {
    await startChallenge();
    TodayState of(AppSnapshot snapshot) => TodayState.of(snapshot);

    final TodayState open = of(await repository.snapshot());
    expect(open.glow, 0);
    expect(open.complete, isFalse);

    final Challenge challenge = (await repository.snapshot()).challenge!;
    await repository.checkIn(
      habit: challenge.habits.first,
      day: DayKey.today(),
      challenge: challenge,
    );
    final TodayState half = of(await repository.snapshot());
    expect(half.parts, <double>[1, 0]);
    expect(half.glow, greaterThan(0));
    expect(half.glow, lessThan(1));

    await repository.checkIn(
      habit: challenge.habits.last,
      day: DayKey.today(),
      challenge: challenge,
    );
    final TodayState done = of(await repository.snapshot());
    expect(done.complete, isTrue);
    expect(done.glow, 1);
    // One finished day, one star.
    expect((await repository.snapshot()).me.streak.completedDays, 1);
  });
}
