import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

const BodyProfile _body = BodyProfile(
  sex: BiologicalSex.female,
  ageYears: 34,
  heightCm: 168,
  weightKg: 71,
  activityLevel: ActivityLevel.light,
);

Challenge _challenge({SharingPrefs sharing = const SharingPrefs()}) =>
    Challenge(
      id: 'c',
      goal: const Goal(
        archetype: GoalArchetype.loseFat,
        statement: '6 kg runter bis zum Sommer',
        body: _body,
        nutrition: NutritionGoals(kcalTarget: 1800),
      ),
      habits: <Habit>[
        Habit.fromCategory(HabitCategory.gym),
        Habit.fromCategory(HabitCategory.noFap),
        Habit.fromCategory(HabitCategory.nutrition),
      ],
      startDay: DayKey.parse('2026-10-01'),
      sharing: sharing,
    );

class _Node {
  _Node(this.identity, this.store)
      : writer = FeedWriter(identity: identity, store: store),
        replicator = FeedReplicator(store);

  static Future<_Node> create() async =>
      _Node(await Identity.generate(), MemoryFeedStore());

  final Identity identity;
  final MemoryFeedStore store;
  final FeedWriter writer;
  final FeedReplicator replicator;

  Syncer syncer({Set<String>? follows}) => Syncer(
        identity: identity,
        store: store,
        replicator: replicator,
        localDisplayName: 'peer',
        localAvatarEmoji: '🦊',
        followedDids: follows,
        timeout: const Duration(seconds: 5),
      );
}

Future<List<SyncResult>> _sync(
  _Node a,
  _Node b, {
  Set<String>? aFollows,
  Set<String>? bFollows,
}) {
  final (PeerSession left, PeerSession right) = LoopbackSession.pair();
  return Future.wait(<Future<SyncResult>>[
    a.syncer(follows: aFollows).run(left),
    b.syncer(follows: bFollows).run(right),
  ]);
}

void main() {
  group('public view', () {
    test('body stats and nutrition targets never leave the device', () {
      final public = publicViewOf(_challenge());
      expect(public.goal.body, isNull);
      expect(public.goal.nutrition, isNull);
      expect(public.toJson().toString(), isNot(contains('71')));
      // The full copy still has them.
      expect(_challenge().goal.body, isNotNull);
    });

    test('a private habit disappears from what friends see', () {
      final public = publicViewOf(_challenge(
        sharing: const SharingPrefs(privateHabits: <String>{'noFap'}),
      ));
      expect(public.habits.map((Habit h) => h.id), <String>['gym', 'nutrition']);
      expect(public.toJson().containsKey('sharing'), isFalse);
    });

    test('a habit shared later only counts for friends from that day', () {
      final since = DayKey.parse('2026-10-20');
      final prefs = const SharingPrefs(privateHabits: <String>{'noFap'})
          .withHabitShared('noFap', true, since: since);
      final full = _challenge(sharing: prefs);
      final public = publicViewOf(full);
      expect(public.habits.firstWhere((Habit h) => h.id == 'noFap').activeFrom,
          since);
      // The owner's own copy is untouched.
      expect(full.habits.firstWhere((Habit h) => h.id == 'noFap').activeFrom,
          isNull);
      expect(Challenge.fromJson(full.toJson()).sharing.sharedSince['noFap'],
          since);
    });

    test('the goal sentence is only shared when the user says so', () {
      expect(publicViewOf(_challenge()).goal.statement, isNotEmpty);
      expect(
        publicViewOf(_challenge(
          sharing: const SharingPrefs(shareStatement: false),
        )).goal.statement,
        isEmpty,
      );
    });

    test('sharing prefs survive the challenge JSON', () {
      final copy = Challenge.fromJson(_challenge(
        sharing: const SharingPrefs(
          privateHabits: <String>{'noFap'},
          shareWorkouts: false,
        ),
      ).toJson());
      expect(copy.sharing.privateHabits, <String>{'noFap'});
      expect(copy.sharing.shareWorkouts, isFalse);
    });
  });

  group('private box', () {
    test('only the author can open a sealed event', () async {
      final alice = await Identity.generate();
      final mallory = await Identity.generate();
      final box = await PrivateBox.forIdentity(alice);
      final sealed = await box.seal(FeedEventType.checkIn,
          <String, dynamic>{'habitId': 'noFap', 'day': '2026-11-02'});

      expect(sealed.toString(), isNot(contains('noFap')));
      final opened = await box.open(sealed);
      expect(opened!.type, FeedEventType.checkIn);
      expect(opened.payload['habitId'], 'noFap');

      final other = await PrivateBox.forIdentity(mallory);
      expect(await other.open(sealed), isNull);
    });

    test('the same seed derives the same key after a restore', () async {
      final alice = await Identity.generate();
      final sealed = await (await PrivateBox.forIdentity(alice))
          .seal('x', <String, dynamic>{'a': 1});
      final restored = await Identity.fromRecoveryKey(await alice.recoveryKey);
      final opened = await (await PrivateBox.forIdentity(restored)).open(sealed);
      expect(opened!.payload['a'], 1);
    });

    test('a tampered box does not open', () async {
      final alice = await Identity.generate();
      final box = await PrivateBox.forIdentity(alice);
      final sealed = await box.seal('x', <String, dynamic>{'a': 1});
      final tampered = Map<String, dynamic>.from(sealed)
        ..['c'] = 'AAAA${(sealed['c'] as String).substring(4)}';
      expect(await box.open(tampered), isNull);
    });

    test('the owner folds sealed events, a friend only the public ones',
        () async {
      final alice = await _Node.create();
      final box = await PrivateBox.forIdentity(alice.identity);
      final full = _challenge(
        sharing: const SharingPrefs(privateHabits: <String>{'noFap'}),
      );

      await alice.writer.append(FeedEventType.challengeStarted,
          <String, dynamic>{'challenge': publicViewOf(full).toJson()});
      await alice.writer.append(
        FeedEventType.private,
        await box.seal(FeedEventType.challengeStarted,
            <String, dynamic>{'challenge': full.toJson()}),
      );
      await alice.writer.append(
        FeedEventType.private,
        await box.seal(FeedEventType.checkIn, CheckIn(
          habitId: 'noFap',
          category: HabitCategory.noFap,
          day: DayKey.parse('2026-10-01'),
          value: 1,
          loggedAt: _epoch,
        ).toPayload()),
      );

      final raw = await alice.store.eventsOf(alice.identity.did);
      // Every event, sealed or not, still verifies on a friend's device.
      for (var i = 0; i < raw.length; i++) {
        expect(
          (await validateEvent(raw[i], previous: i == 0 ? null : raw[i - 1]))
              .isValid,
          isTrue,
        );
      }

      final asFriend = projectUser(alice.identity.did, raw,
          today: DayKey.parse('2026-10-01'));
      expect(asFriend.challenge!.habits.map((Habit h) => h.id),
          isNot(contains('noFap')));
      expect(asFriend.challenge!.goal.body, isNull);
      expect(asFriend.logsByDay, isEmpty);

      final asOwner = projectUser(
        alice.identity.did,
        await box.openAll(raw),
        today: DayKey.parse('2026-10-01'),
      );
      expect(asOwner.challenge!.habits.map((Habit h) => h.id),
          contains('noFap'));
      expect(asOwner.challenge!.goal.body!.weightKg, 71);
      expect(asOwner.logsByDay['2026-10-01']!.entries.single.habitId, 'noFap');
    });
  });

  group('friends-only sync', () {
    test('a stranger gets nothing, and is reported as a request', () async {
      final alice = await _Node.create();
      final stranger = await _Node.create();
      await alice.writer.append(
          FeedEventType.profile, <String, dynamic>{'displayName': 'Alice'});

      final results = await _sync(
        alice,
        stranger,
        aFollows: <String>{alice.identity.did},
        bFollows: <String>{stranger.identity.did, alice.identity.did},
      );

      expect(await stranger.store.head(alice.identity.did), isNull);
      expect(results[0].status, SyncOutcome.refusedStranger);
      expect(results[0].peerDid, stranger.identity.did);
      expect(results[0].peerEmoji, '🦊');
      expect(results[1].status, SyncOutcome.notFriendsYet);
    });

    test('once both follow each other, they replicate', () async {
      final alice = await _Node.create();
      final bob = await _Node.create();
      await alice.writer.append(
          FeedEventType.profile, <String, dynamic>{'displayName': 'Alice'});
      final follows = <String>{alice.identity.did, bob.identity.did};

      final results =
          await _sync(alice, bob, aFollows: follows, bFollows: follows);

      expect(results.every((SyncResult r) => r.status == SyncOutcome.synced),
          isTrue);
      expect(await bob.store.head(alice.identity.did), isNotNull);
    });

    test('claiming a friend\'s DID without the key gets nothing', () async {
      final alice = await _Node.create();
      final bob = await _Node.create();
      final mallory = await _Node.create();
      await alice.writer.append(
          FeedEventType.profile, <String, dynamic>{'displayName': 'Alice'});

      final (PeerSession left, PeerSession right) = LoopbackSession.pair();
      final aliceRound = alice
          .syncer(follows: <String>{alice.identity.did, bob.identity.did})
          .run(left);
      final received = <Map<String, dynamic>>[];
      right.messages.listen(received.add);
      // Mallory says hello as Bob and signs with her own key.
      await right.send(HelloMessage(
        did: bob.identity.did,
        displayName: 'Bob',
        nonce: 'bWFsbG9yeS1ub25jZS0xMjM0NTY3OA==',
      ).toJson());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final aliceNonce = (received.firstWhere(
              (Map<String, dynamic> m) => m['t'] == 'hello'))['nonce']
          as String;
      await right.send(AuthMessage(await mallory.identity.sign(authChallenge(
        nonce: aliceNonce,
        signerDid: bob.identity.did,
        verifierDid: alice.identity.did,
      ))).toJson());
      // And asks for everything anyway.
      await right.send(WantMessage(<WantRange>[
        WantRange(did: alice.identity.did, fromSeq: 0),
      ]).toJson());

      final result = await aliceRound;
      expect(result.status, SyncOutcome.authFailed);
      expect(received.where((Map<String, dynamic> m) => m['t'] == 'events'),
          isEmpty);
    });
  });

  group('editing a running challenge', () {
    test('an update keeps the start day and the cycle reached', () {
      final alice = _challenge();
      final events = <FeedEvent>[
        _fake(1, FeedEventType.challengeStarted,
            <String, dynamic>{'challenge': alice.toJson()}),
        _fake(2, FeedEventType.challengeAscended, <String, dynamic>{'cycle': 1}),
        _fake(3, FeedEventType.challengeUpdated, <String, dynamic>{
          'challenge': alice
              .copyWith(
                startDay: DayKey.parse('2027-01-01'),
                goal: alice.goal.copyWith(trainingDaysPerWeek: 5),
              )
              .toJson(),
        }),
      ];
      final projection =
          projectUser('did:x', events, today: DayKey.parse('2026-10-05'));
      expect(projection.challenge!.startDay, DayKey.parse('2026-10-01'));
      expect(projection.challenge!.cycle, 1);
      expect(projection.challenge!.goal.trainingDaysPerWeek, 5);
    });

    test('changing training days does not break past days', () {
      final start = DayKey.parse('2026-10-05'); // a Monday
      final gym = Habit.fromCategory(HabitCategory.gym); // Mon Tue Thu Fri
      final changed = gym.withDaysPerWeek(5, from: start.addDays(7));
      // Wednesday of week one was a rest day and stays one.
      expect(isHabitScheduledOn(changed, start.addDays(2)), isFalse);
      // Wednesday of week two is a training day now.
      expect(isHabitScheduledOn(changed, start.addDays(9)), isTrue);
      final copy = Habit.fromJson(changed.toJson());
      expect(copy.daysPerWeekOn(start), 4);
      expect(copy.daysPerWeekOn(start.addDays(9)), 5);
    });

    test('a habit added later neither breaks nor builds the past', () {
      final start = DayKey.parse('2026-10-05');
      final reading = Habit.fromCategory(HabitCategory.reading)
          .copyWith(activeFrom: start.addDays(3));
      final challenge = Challenge(
        id: 'c',
        goal: const Goal(archetype: GoalArchetype.discipline, statement: 'x'),
        habits: <Habit>[Habit.fromCategory(HabitCategory.noSugar), reading],
        startDay: start,
      );
      final logs = <String, DayLog>{
        for (var i = 0; i < 3; i++)
          start.addDays(i).toString(): DayLog(
            day: start.addDays(i),
            entries: <CheckIn>[
              CheckIn(
                habitId: 'noSugar',
                category: HabitCategory.noSugar,
                day: start.addDays(i),
                value: 1,
                loggedAt: start.addDays(i).toDateTime(),
              ),
            ],
          ),
      };
      final streak = computeStreak(
        challenge: challenge,
        logsByDay: logs,
        frozenDays: const <String>{},
        today: start.addDays(3),
      );
      expect(streak.current, 3);
      expect(streak.atRisk, isTrue);
    });
  });

  group('tracked XP', () {
    test('a tracked workout is worth more than a tick', () {
      final gym = Habit.fromCategory(HabitCategory.gym);
      final day = DayKey.today();
      int xp({required bool tracked}) => xpForCheckIn(
            habit: gym,
            checkIn: CheckIn(
              habitId: 'gym',
              category: HabitCategory.gym,
              day: day,
              value: 1,
              loggedAt: DateTime.now(),
              tracked: tracked,
            ),
            streakBefore: 0,
          );
      expect(xp(tracked: true), (xp(tracked: false) * kTrackedMultiplier).round());
    });

    test('the bonus only exists where there is a plan behind it', () {
      final reading = Habit.fromCategory(HabitCategory.reading);
      final day = DayKey.today();
      int xp({required bool tracked}) => xpForCheckIn(
            habit: reading,
            checkIn: CheckIn(
              habitId: 'reading',
              category: HabitCategory.reading,
              day: day,
              value: 20,
              loggedAt: DateTime.now(),
              tracked: tracked,
            ),
            streakBefore: 0,
          );
      expect(xp(tracked: true), xp(tracked: false));
    });

    test('the tracked flag survives the payload', () {
      final payload = CheckIn(
        habitId: 'nutrition',
        category: HabitCategory.nutrition,
        day: DayKey.today(),
        value: 1,
        loggedAt: DateTime.now(),
        tracked: true,
      ).toPayload();
      expect(
          CheckIn.fromPayload(payload, loggedAt: DateTime.now()).tracked, isTrue);
    });
  });

  group('food diary projection', () {
    test('logged entries land on their day and removals take them out', () {
      FoodEntry entry(String id) => FoodEntry(
            id: id,
            day: DayKey.parse('2026-11-02'),
            meal: MealSlotKind.lunch,
            name: 'Reis',
            grams: 180,
            nutrients: kFoodById['rice']!.forGrams(180),
            source: FoodSource.database,
            foodId: 'rice',
          );
      final projection = projectUser('did:x', <FeedEvent>[
        _fake(1, FeedEventType.foodLogged, entry('a').toPayload()),
        _fake(2, FeedEventType.foodLogged, entry('b').toPayload()),
        _fake(3, FeedEventType.foodRemoved, <String, dynamic>{'id': 'a'}),
      ]);
      final intake = projection.intakeOn(DayKey.parse('2026-11-02'));
      expect(intake.entries.single.id, 'b');
      expect(intake.total.kcal, closeTo(234, 1));
    });
  });
}

final DateTime _epoch = DateTime.utc(2026, 10, 1, 9);

FeedEvent _fake(int seq, String type, Map<String, dynamic> payload) =>
    FeedEvent(
      author: 'did:x',
      seq: seq,
      prevHash: null,
      timestamp: DateTime.utc(2026, 10, 1).add(Duration(minutes: seq)),
      type: type,
      payload: payload,
      hash: 'h$seq',
      signature: 's$seq',
    );
