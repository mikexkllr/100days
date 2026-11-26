import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/l10n/l10n.dart';
import 'package:hundred_days/ui/celebration/day_complete.dart';
import 'package:hundred_days/ui/home/coach_card.dart';
import 'package:hundred_days/ui/home/home_screen.dart';
import 'package:hundred_days/ui/home/day_sheet.dart';
import 'package:hundred_days/ui/home/streak_hero.dart';
import 'package:hundred_days/ui/home/today.dart';
import 'package:hundred_days/ui/home/week_strip.dart';
import 'package:hundred_days/ui/mascot/flame_mascot.dart';
import 'package:hundred_days/ui/motion/rolling_number.dart';
import 'package:hundred_days/ui/nutrition/diary_view.dart';
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
    expect(
      find.descendant(
          of: find.byType(TodayRing), matching: find.byType(FlameMascot)),
      findsOneWidget,
    );
    expect(find.text('Tag 1 / 100'), findsOneWidget);
    expect(find.byType(HabitTile), findsNWidgets(2));
    expect(find.text('Kein Zucker'), findsOneWidget);
    expect(find.text('Lesen'), findsOneWidget);
  });

  testWidgets('checking in writes an event and updates the tile',
      (WidgetTester tester) async {
    await startChallenge(habits: <HabitCategory>[HabitCategory.noSugar]);
    await pump(tester);

    await holdToIgnite(tester, 'Heute clean');

    final List<FeedEvent> all =
        await repository.store.eventsOf(repository.userId);
    final List<FeedEvent> checkIns = all
        .where((FeedEvent e) => e.type == FeedEventType.checkIn)
        .toList();
    expect(checkIns, hasLength(1));
    expect(checkIns.single.payload['habitId'], 'noSugar');

    // Shared with friends, and waiting for the sync to send it.
    expect(checkIns.single.visibility, EventVisibility.friends);
    expect(checkIns.single.isPending, isTrue);

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

    // Funki says it himself: his face next to his line.
    expect(
      find.descendant(
          of: find.byType(CoachCard), matching: find.byType(FlameMascot)),
      findsOneWidget,
    );
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
            .eventsOf(repository.userId))
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

  testWidgets('a done row still answers a tap, and the tick can be taken back',
      (WidgetTester tester) async {
    await startChallenge();
    await pump(tester);

    await holdToIgnite(tester, 'Heute clean');
    expect(find.widgetWithText(DoneBadge, 'Erledigt'), findsOneWidget);

    // Before the fix the row swallowed every tap after a hold.
    await tester.tap(find.text('Kein Zucker'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tile-undo-noSugar')));
    await tester.pumpAndSettle();

    final AppSnapshot snapshot = await repository.snapshot();
    expect(snapshot.me.logsByDay[snapshot.today.toString()], isNull);
    expect(find.widgetWithText(DoneBadge, 'Erledigt'), findsNothing);
  });

  testWidgets('every habit can be checked in without holding',
      (WidgetTester tester) async {
    await startChallenge();
    await pump(tester);

    await tester.tap(find.text('Kein Zucker'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tile-plain-noSugar')));
    await tester.pumpAndSettle();

    final AppSnapshot snapshot = await repository.snapshot();
    expect(
      snapshot.me.logsByDay[snapshot.today.toString()]!.entryFor('noSugar'),
      isNotNull,
    );
  });

  testWidgets('a freeze asks first and holds the day only when confirmed',
      (WidgetTester tester) async {
    final Challenge challenge = testChallenge(
      startDay: DayKey.today().addDays(-2),
      habits: const <HabitCategory>[HabitCategory.reading],
    );
    await repository.saveProfile(displayName: 'Mike', avatarEmoji: '🐺');
    await repository.startChallenge(challenge);
    for (int i = 2; i >= 1; i--) {
      await repository.checkIn(
        habit: challenge.habits.first,
        day: DayKey.today().addDays(-i),
      );
    }
    await pump(tester);

    await tester.tap(find.byKey(const Key('freeze-use')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect((await repository.snapshot()).me.frozenDays, isEmpty);

    await tester.tap(find.byKey(const Key('freeze-use')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('freeze-confirm')));
    await tester.pumpAndSettle();
    expect((await repository.snapshot()).me.frozenDays,
        <String>{DayKey.today().toString()});
  });

  testWidgets('a missed yesterday can be logged late', (WidgetTester tester) async {
    final Challenge challenge = testChallenge(
      startDay: DayKey.today().addDays(-3),
      habits: const <HabitCategory>[HabitCategory.reading],
    );
    await repository.saveProfile(displayName: 'Mike', avatarEmoji: '🐺');
    await repository.startChallenge(challenge);
    for (int i = 3; i >= 2; i--) {
      await repository.checkIn(
        habit: challenge.habits.first,
        day: DayKey.today().addDays(-i),
      );
    }
    await pump(tester);

    expect(find.text('Gestern ist durchgerutscht'), findsOneWidget);
    await tester.tap(find.byKey(const Key('yesterday-log')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('log-late-reading')));
    await tester.pumpAndSettle();

    final AppSnapshot snapshot = await repository.snapshot();
    expect(snapshot.me.streak.current, 3);
  });

  group('the day sheet', () {
    const BodyProfile body = BodyProfile(
      sex: BiologicalSex.female,
      ageYears: 29,
      heightCm: 170,
      weightKg: 66,
      activityLevel: ActivityLevel.moderate,
    );

    Future<Challenge> start({bool diary = false}) async {
      final Challenge challenge = Challenge(
        id: 'sheet',
        goal: Goal(
          archetype: GoalArchetype.discipline,
          statement: 'Jeden Tag',
          body: diary ? body : null,
          nutritionPlanEnabled: diary,
        ),
        habits: <Habit>[
          Habit.fromCategory(HabitCategory.journaling),
          Habit.fromCategory(HabitCategory.nutrition),
        ],
        startDay: DayKey.today().addDays(-4),
      );
      await repository.saveProfile(displayName: 'Mike', avatarEmoji: '🐺');
      await repository.startChallenge(challenge);
      return challenge;
    }

    /// Opens the sheet of [day] from a button, as the week strip and the
    /// board do.
    Future<void> openDay(WidgetTester tester, DayKey day) async {
      tester.view.physicalSize = const Size(1080, 4200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final AppSnapshot snapshot = await repository.snapshot();
      await tester.pumpWidget(wrapForTest(
        repository: repository,
        child: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () =>
                showDaySheet(context, snapshot: snapshot, day: day),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('today, every open habit can be checked in from it',
        (WidgetTester tester) async {
      await start();
      await openDay(tester, DayKey.today());

      await tester.tap(find.byKey(const Key('day-check-in-journaling')));
      await tester.pumpAndSettle();

      final AppSnapshot after = await repository.snapshot();
      expect(after.me.logsByDay[DayKey.today().toString()]
          ?.entryFor('journaling'), isNotNull);
      // Done now: the row shows it and offers nothing more.
      expect(find.byKey(const Key('day-check-in-journaling')), findsNothing);
      expect(find.descendant(
              of: find.byType(DaySheet), matching: find.text('Erledigt')),
          findsOneWidget);
    });

    testWidgets('a day long gone says it is over instead of ignoring taps',
        (WidgetTester tester) async {
      await start();
      await openDay(tester, DayKey.today().addDays(-3));

      expect(find.byKey(const Key('day-check-in-journaling')), findsNothing);
      expect(find.byKey(const Key('log-late-journaling')), findsNothing);
      expect(find.text('Dieser Tag ist vorbei. Nachtragen geht nur für gestern.'),
          findsOneWidget);
    });

    testWidgets('nutrition opens the diary of that day',
        (WidgetTester tester) async {
      await start(diary: true);
      final DayKey day = DayKey.today().addDays(-3);
      await openDay(tester, day);

      await tester.tap(find.byKey(const Key('day-diary-nutrition')));
      await tester.pumpAndSettle();

      final DiaryScreen diary =
          tester.widget<DiaryScreen>(find.byType(DiaryScreen));
      expect(diary.day, day);
      expect(find.text('Ernährungstagebuch'), findsOneWidget);
    });

    testWidgets('without a diary, nutrition yesterday is logged late like any',
        (WidgetTester tester) async {
      await start();
      final DayKey yesterday = DayKey.today().addDays(-1);
      await openDay(tester, yesterday);

      expect(find.byKey(const Key('day-diary-nutrition')), findsNothing);
      await tester.tap(find.byKey(const Key('log-late-nutrition')));
      await tester.pumpAndSettle();
      expect((await repository.snapshot()).me.logsByDay[yesterday.toString()]
          ?.entryFor('nutrition'), isNotNull);
    });

    testWidgets('with a diary, today offers both the tick and the meals',
        (WidgetTester tester) async {
      await start(diary: true);
      await openDay(tester, DayKey.today());

      expect(find.byKey(const Key('day-check-in-nutrition')), findsOneWidget);
      await tester.tap(find.byKey(const Key('day-diary-nutrition')));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryScreen), findsOneWidget);
    });
  });

  group('nutrition on Today', () {
    const BodyProfile body = BodyProfile(
      sex: BiologicalSex.female,
      ageYears: 29,
      heightCm: 170,
      weightKg: 66,
      activityLevel: ActivityLevel.moderate,
    );

    Future<void> startDiet() async {
      await repository.saveProfile(displayName: 'Mike', avatarEmoji: '🐺');
      await repository.startChallenge(Challenge(
        id: 'diet',
        goal: const Goal(
          archetype: GoalArchetype.loseFat,
          statement: 'Leichter werden',
          body: body,
          nutritionPlanEnabled: true,
        ),
        // A second habit keeps the day open when nutrition is ticked: no
        // celebration in the way.
        habits: <Habit>[
          Habit.fromCategory(HabitCategory.nutrition),
          Habit.fromCategory(HabitCategory.reading),
        ],
        startDay: DayKey.today().addDays(-2),
      ));
    }

    testWidgets('the nutrition row says where the diary stands and leads into it',
        (WidgetTester tester) async {
      await startDiet();
      await repository.logFood(FoodEntry(
        id: 'lunch',
        day: DayKey.today(),
        meal: MealSlotKind.lunch,
        name: 'Eintopf',
        grams: 400,
        nutrients: const Nutrients(kcal: 600, proteinG: 30, carbsG: 60, fatG: 20),
        source: FoodSource.manual,
      ));
      await pump(tester);
      final int target =
          (await repository.snapshot()).plan!.nutrition!.kcal;
      expect(find.text('Tagebuch: 600 / $target kcal'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tile-diary-nutrition')));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryScreen), findsOneWidget);
    });

    testWidgets('ticking the row opens the diary, and closing the day there is the tick',
        (WidgetTester tester) async {
      await startDiet();
      final NutritionPlan plan = (await repository.snapshot()).plan!.nutrition!;
      await repository.logFood(FoodEntry(
        id: 'day',
        day: DayKey.today(),
        meal: MealSlotKind.dinner,
        name: 'Alles',
        grams: 1500,
        nutrients: Nutrients(
          kcal: plan.kcal.toDouble(),
          proteinG: plan.proteinG.toDouble(),
          carbsG: plan.carbsG.toDouble(),
          fatG: plan.fatG.toDouble(),
        ),
        source: FoodSource.manual,
      ));
      await pump(tester);

      // One tap: nothing is committed by opening the diary.
      await tester.tap(find.text('Abhaken').first);
      await tester.pumpAndSettle();
      expect(find.byType(DiaryScreen), findsOneWidget);
      expect(
        (await repository.snapshot())
            .me
            .logsByDay[DayKey.today().toString()]
            ?.entryFor('nutrition'),
        isNull,
      );

      await tester.tap(find.byKey(const Key('close-day')));
      await tester.pumpAndSettle();
      final CheckIn entry = (await repository.snapshot())
          .me
          .logsByDay[DayKey.today().toString()]!
          .entryFor('nutrition')!;
      expect(entry.tracked, isTrue);
    });
  });
}
