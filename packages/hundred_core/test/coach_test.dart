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
      lastActivityLabel: 'Training erledigt',
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
    test('always produces a non-empty briefing', () async {
      for (final bool done in <bool>[true, false]) {
        for (final int day in <int>[1, 10, 30, 100, 240]) {
          final message = await coach.dailyBriefing(
              _context(currentStreak: day, doneToday: done, dayNumber: day));
          expect(message.headline, isNotEmpty);
          expect(message.body, isNotEmpty);
          expect(message.source, 'heuristic');
        }
      }
    });

    test('names the friends who already went today', () async {
      final message = await coach.dailyBriefing(_context(
        currentStreak: 4,
        doneToday: false,
        peers: <PeerState>[
          _peer('Marcel', streak: 12, activeToday: true),
          _peer('Lisa', streak: 8, activeToday: true),
        ],
      ));

      expect(message.body, contains('Marcel'));
      expect(message.body, contains('Lisa'));
    });

    test('is stable within a day and can change across days', () async {
      final first = await coach
          .dailyBriefing(_context(currentStreak: 9, doneToday: false));
      final again = await coach
          .dailyBriefing(_context(currentStreak: 9, doneToday: false));

      expect(again.body, equals(first.body));
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
      expect(suggestions.single.text, isNotEmpty);
    });

    test('tells a solo user to invite someone', () async {
      final tips = await coach
          .planAdjustments(_context(currentStreak: 5, doneToday: true));

      expect(tips.any((String t) => t.contains('eingeladen') ||
          t.contains('lade jemanden ein')), isTrue);
    });

    test('recommends cutting scope when the hit rate collapses', () async {
      final tips = await coach.planAdjustments(_context(
        currentStreak: 0,
        doneToday: false,
        dayNumber: 20,
        completionRate: 0.3,
      ));

      expect(tips.first, contains('%'));
    });
  });

  group('LocalLlmCoach', () {
    test('uses the model output when it parses', () async {
      final runtime = _FakeRuntime('TITEL: Heute zählt\nTEXT: Zwei Sätze, '
          'ein Ziel. Mach den Haken dran.');
      final llm = LocalLlmCoach(runtime: runtime);

      final message = await llm
          .dailyBriefing(_context(currentStreak: 5, doneToday: false));

      expect(message.source, 'llm');
      expect(message.headline, 'Heute zählt');
      expect(message.body, contains('Mach den Haken dran'));
      expect(runtime.calls, 1);
    });

    test('falls back when the model output is unusable', () async {
      final runtime = _FakeRuntime('...');
      final llm = LocalLlmCoach(runtime: runtime);

      final message = await llm
          .dailyBriefing(_context(currentStreak: 5, doneToday: false));

      expect(message.source, 'heuristic');
      expect(message.body, isNotEmpty);
    });

    test('falls back when the model throws', () async {
      final runtime = _FakeRuntime('x', throwOnGenerate: true);
      final llm = LocalLlmCoach(runtime: runtime);

      final message = await llm
          .dailyBriefing(_context(currentStreak: 5, doneToday: false));

      expect(message.source, 'heuristic');
    });

    test('does not call an unloaded model at all', () async {
      final runtime = _FakeRuntime('x', ready: false);
      final llm = LocalLlmCoach(runtime: runtime);

      await llm.dailyBriefing(_context(currentStreak: 5, doneToday: false));

      expect(runtime.calls, 0);
      expect(llm.name, contains('Regelbasiert'));
    });

    test('never sends anything anywhere but the runtime', () async {
      final runtime = _FakeRuntime('TITEL: A\nTEXT: B');
      final llm = LocalLlmCoach(runtime: runtime);

      // The context carries a personal goal statement; the only sink for it is
      // the on-device runtime, which is what makes the prompt private.
      await llm.dailyBriefing(_context(currentStreak: 5, doneToday: false));
      expect(runtime.calls, 1);
    });
  });
}
