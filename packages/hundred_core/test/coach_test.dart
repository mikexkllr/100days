import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

final DayKey _start = DayKey(2026, 3, 2);

Challenge _challenge() => Challenge(
      id: 'c1',
      goal: const Goal(
        archetype: GoalArchetype.discipline,
        statement: '100 Tage nicht verhandeln',
      ),
      habits: <Habit>[Habit.fromCategory(HabitCategory.noSugar)],
      startDay: _start,
    );

PeerState _peer(
  String name, {
  required int streak,
  required bool activeToday,
  DateTime? lastActivity,
}) =>
    PeerState(
      profile: PeerProfile(
        did: 'did:key:z$name',
        displayName: name,
        avatarEmoji: '🐺',
      ),
      currentStreak: streak,
      longestStreak: streak,
      lifetimeXp: streak * 60,
      weeklyXp: streak * 10,
      dayNumber: streak,
      tier: tierForCycle(0),
      activeToday: activeToday,
      lastActivityAt: lastActivity ?? DateTime.now(),
      lastActivity: const PeerActivity(
        kind: PeerActivityKind.checkIn,
        category: HabitCategory.gym,
      ),
      headSeq: streak,
    );

CoachContext _context({
  required int currentStreak,
  required bool doneToday,
  int dayNumber = 10,
  List<PeerState> peers = const <PeerState>[],
  int hour = 12,
  DayKey? lastRelapse,
  double completionRate = 1.0,
}) {
  final today = _start.addDays(dayNumber - 1);
  return CoachContext(
    challenge: _challenge(),
    streak: StreakStats(
      current: currentStreak,
      longest: currentStreak,
      completedDays: (dayNumber * completionRate).round(),
      scheduledDays: dayNumber,
      doneToday: doneToday,
      atRisk: !doneToday,
      freezesUsed: 0,
    ),
    today: today,
    todayLog: null,
    peers: peers,
    now: today.toDateTime().add(Duration(hours: hour)),
    habitStreaks: <String, int>{'noSugar': currentStreak},
    lastRelapseDay: lastRelapse,
  );
}

/// Returns canned output so the parsing and fallback paths can be exercised
/// without shipping a model into the test suite.
class _FakeRuntime implements LocalLlmRuntime {
  _FakeRuntime(this._response, {this.ready = true, this.throwOnGenerate = false});

  final String _response;
  final bool ready;
  final bool throwOnGenerate;
  int calls = 0;

  @override
  String get modelName => 'Fake-1B';

  @override
  bool get isReady => ready;

  @override
  int? get sizeBytes => 1024;

  @override
  Future<void> load() async {}

  @override
  Future<String> generate(
    String prompt, {
    int maxTokens = 200,
    double temperature = 0.8,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    calls++;
    if (throwOnGenerate) throw StateError('model crashed');
    return _response;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  const HeuristicCoach coach = HeuristicCoach();

  group('selectTone', () {
    test('welcomes in the first days', () {
      expect(
        selectTone(_context(currentStreak: 1, doneToday: false, dayNumber: 2)),
        CoachTone.welcome,
      );
    });

    test('applies social pressure when friends already went', () {
      final tone = selectTone(_context(
        currentStreak: 5,
        doneToday: false,
        peers: <PeerState>[_peer('Marcel', streak: 9, activeToday: true)],
      ));

      expect(tone, CoachTone.socialPressure);
    });

    test('escalates to urgent in the evening', () {
      final tone = selectTone(_context(
        currentStreak: 5,
        doneToday: false,
        hour: 21,
        peers: <PeerState>[_peer('Marcel', streak: 9, activeToday: true)],
      ));

      expect(tone, CoachTone.urgent);
    });

    test('switches to recovery after a relapse', () {
      final tone = selectTone(_context(
        currentStreak: 0,
        doneToday: false,
        lastRelapse: _start.addDays(8),
        dayNumber: 10,
      ));

      expect(tone, CoachTone.recover);
    });

    test('celebrates a milestone that is already done', () {
      expect(
        selectTone(
            _context(currentStreak: 30, doneToday: true, dayNumber: 30)),
        CoachTone.celebrate,
      );
    });

    test('raises the bar for a long, clean streak', () {
      expect(
        selectTone(_context(
          currentStreak: 40,
          doneToday: true,
          dayNumber: 40,
          completionRate: 0.98,
        )),
        CoachTone.raiseTheBar,
      );
    });
  });

  group('HeuristicCoach', () {
    test('always produces a directive, whatever the state', () async {
      for (final bool done in <bool>[true, false]) {
        for (final int day in <int>[1, 10, 30, 100, 240]) {
          final directive = await coach.dailyBriefing(
              _context(currentStreak: day, doneToday: done, dayNumber: day));
          expect(directive.source, CoachSource.heuristic);
          expect(directive.dayNumber, day);
          expect(directive.streak, day);
        }
      }
    });

    test('names the friends who already went today', () async {
      final directive = await coach.dailyBriefing(_context(
        currentStreak: 4,
        doneToday: false,
        peers: <PeerState>[
          _peer('Marcel', streak: 12, activeToday: true),
          _peer('Lisa', streak: 8, activeToday: true),
        ],
      ));

      expect(directive.tone, CoachTone.socialPressure);
      expect(
        directive.peers.map((PeerMention p) => p.displayName),
        containsAll(<String>['Marcel', 'Lisa']),
      );
      expect(directive.extraPeerCount, 0);
    });

    test('caps the named friends and counts the rest', () async {
      final directive = await coach.dailyBriefing(_context(
        currentStreak: 4,
        doneToday: false,
        peers: <PeerState>[
          for (int i = 0; i < 7; i++)
            _peer('P\$i', streak: 3, activeToday: true),
        ],
      ));

      expect(directive.peers, hasLength(HeuristicCoach.maxNamedPeers));
      expect(directive.extraPeerCount, 7 - HeuristicCoach.maxNamedPeers);
    });

    test('points at the leader when nobody went today', () async {
      final directive = await coach.dailyBriefing(_context(
        currentStreak: 4,
        doneToday: false,
        peers: <PeerState>[
          _peer('Marcel', streak: 30, activeToday: false),
        ],
      ));

      expect(directive.template, CoachTemplate.pressureLeaderAhead);
      expect(directive.peers.single.displayName, 'Marcel');
      expect(directive.peers.single.streak, 30);
    });

    test('is stable within a day', () async {
      final first = await coach
          .dailyBriefing(_context(currentStreak: 9, doneToday: false));
      final again = await coach
          .dailyBriefing(_context(currentStreak: 9, doneToday: false));

      expect(again.template, first.template);
    });

    test('carries the days left to the next milestone', () async {
      final directive = await coach
          .dailyBriefing(_context(currentStreak: 8, doneToday: true, dayNumber: 8));

      expect(directive.tone, CoachTone.steady);
      expect(directive.milestoneDay, 14);
      expect(directive.daysToMilestone, 6);
    });

    test('picks the celebration that matches the day', () async {
      expect(
        (await coach.dailyBriefing(
                _context(currentStreak: 100, doneToday: true, dayNumber: 100)))
            .template,
        CoachTemplate.celebrateHundred,
      );
      expect(
        (await coach.dailyBriefing(
                _context(currentStreak: 7, doneToday: true, dayNumber: 7)))
            .template,
        CoachTemplate.celebrateWeek,
      );
    });

    test('suggests nudges only for friends who are behind', () async {
      final suggestions = await coach.nudgeSuggestions(_context(
        currentStreak: 20,
        doneToday: true,
        peers: <PeerState>[
          _peer('Marcel', streak: 12, activeToday: false),
          _peer('Lisa', streak: 40, activeToday: true),
        ],
      ));

      expect(suggestions, hasLength(1));
      expect(suggestions.single.targetDid, contains('Marcel'));
      expect(suggestions.single.reason, NudgeReason.nothingToday);
      expect(suggestions.single.peerStreak, 12);
    });

    test('tells a solo user to invite someone', () async {
      final advice = await coach
          .planAdjustments(_context(currentStreak: 5, doneToday: true));

      expect(
        advice.map((PlanAdvice a) => a.kind),
        contains(PlanAdviceKind.inviteSomeone),
      );
    });

    test('recommends cutting scope when the hit rate collapses', () async {
      final advice = await coach.planAdjustments(_context(
        currentStreak: 0,
        doneToday: false,
        dayNumber: 20,
        completionRate: 0.3,
      ));

      expect(advice.first.kind, PlanAdviceKind.cutScope);
      expect(advice.first.completionPercent, 30);
    });

    test('pairs a relapse with advice for that specific habit', () async {
      expect(
        recoveryHintFor(HabitCategory.noFap),
        RecoveryHint.digitalTrigger,
      );
      expect(
        recoveryHintFor(HabitCategory.noSugar),
        RecoveryHint.sugarBreakfast,
      );
      expect(
        recoveryHintFor(HabitCategory.reading),
        RecoveryHint.smallestVersion,
      );
    });
  });

  group('LocalLlmCoach', () {
    test('uses the model output when it parses', () async {
      final runtime = _FakeRuntime(
          'TITLE: Today counts\nTEXT: One goal. Go and tick it off.');
      final llm = LocalLlmCoach(runtime: runtime);

      final directive = await llm
          .dailyBriefing(_context(currentStreak: 5, doneToday: false));

      expect(directive.source, CoachSource.llm);
      expect(directive.template, CoachTemplate.freeform);
      expect(directive.freeformHeadline, 'Today counts');
      expect(directive.freeformBody, contains('tick it off'));
      expect(runtime.calls, 1);
    });

    test('accepts a localized TITEL header too', () async {
      final runtime =
          _FakeRuntime('TITEL: Heute zählt\nTEXT: Mach den Haken dran.');
      final llm = LocalLlmCoach(runtime: runtime);

      final directive = await llm
          .dailyBriefing(_context(currentStreak: 5, doneToday: false));

      expect(directive.freeformHeadline, 'Heute zählt');
    });

    test('falls back when the model output is unusable', () async {
      final runtime = _FakeRuntime('...');
      final llm = LocalLlmCoach(runtime: runtime);

      final directive = await llm
          .dailyBriefing(_context(currentStreak: 5, doneToday: false));

      expect(directive.source, CoachSource.heuristic);
      expect(directive.template, isNot(CoachTemplate.freeform));
    });

    test('falls back when the model throws', () async {
      final runtime = _FakeRuntime('x', throwOnGenerate: true);
      final llm = LocalLlmCoach(runtime: runtime);

      final directive = await llm
          .dailyBriefing(_context(currentStreak: 5, doneToday: false));

      expect(directive.source, CoachSource.heuristic);
    });

    test('does not call an unloaded model at all', () async {
      final runtime = _FakeRuntime('x', ready: false);
      final llm = LocalLlmCoach(runtime: runtime);

      await llm.dailyBriefing(_context(currentStreak: 5, doneToday: false));

      expect(runtime.calls, 0);
      expect(llm.modelName, isNull);
    });

    test('never sends anything anywhere but the runtime', () async {
      final runtime = _FakeRuntime('TITLE: A\nTEXT: B');
      final llm = LocalLlmCoach(runtime: runtime);

      // The context carries a personal goal statement; the only sink for it is
      // the on-device runtime, which is what makes the prompt private.
      await llm.dailyBriefing(_context(currentStreak: 5, doneToday: false));
      expect(runtime.calls, 1);
    });
  });
}
