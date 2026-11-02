import 'dart:async';

import 'package:hundred_core/hundred_core.dart';

import 'key_store.dart';
import 'sqlite_feed_store.dart';

/// Why an invite was refused.
enum InviteProblem { malformed, self }

class InviteRejection implements Exception {
  const InviteRejection(this.problem);

  final InviteProblem problem;

  @override
  String toString() => 'InviteRejection(${problem.name})';
}

/// One consistent read of everything the UI needs.
class AppSnapshot {
  const AppSnapshot({
    required this.identity,
    required this.me,
    required this.friends,
    required this.activity,
    required this.league,
    required this.today,
    required this.nudgedToday,
    required this.cheeredEvents,
    this.plan,
  });

  final Identity identity;
  final UserProjection me;
  final List<UserProjection> friends;
  final List<ActivityItem> activity;
  final LeagueStanding league;
  final ChallengePlan? plan;
  final DayKey today;

  /// Peers already nudged today, derived from the feed rather than held in
  /// widget state — a list that rebuilds must not forget what you sent.
  final Set<String> nudgedToday;

  /// Hashes of the check-in events already cheered.
  final Set<String> cheeredEvents;

  bool get hasChallenge => me.challenge != null;

  Challenge? get challenge => me.challenge;

  List<PeerState> get peerStates =>
      friends.map((UserProjection f) => f.toPeerState(today: today)).toList();

  Map<String, PeerProfile> get profiles => <String, PeerProfile>{
        me.did: me.profile,
        for (final UserProjection f in friends) f.did: f.profile,
      };

  /// Friends who already logged something today and you have not. The single
  /// number the home screen leads with when the streak is at risk.
  int get friendsAheadToday {
    if (me.streak.doneToday) return 0;
    return peerStates.where((PeerState p) => p.activeToday).length;
  }

  CoachContext toCoachContext({DateTime? now}) => CoachContext(
        challenge: me.challenge!,
        streak: me.streak,
        today: today,
        todayLog: me.logsByDay[today.toString()],
        peers: peerStates,
        now: now ?? DateTime.now(),
        habitStreaks: me.habitStreaks,
        lastRelapseDay: me.lastRelapseDay,
      );
}

/// The single place the UI talks to.
///
/// Everything a user does becomes a signed event on their own feed; nothing is
/// stored "beside" the log. That constraint is what lets a friend's device
/// reconstruct the exact same streak from the same bytes.
class AppRepository {
  AppRepository({
    required this.identity,
    required this.store,
    required this.keyStore,
    required this.box,
  })  : writer = FeedWriter(identity: identity, store: store),
        replicator = FeedReplicator(store);

  final Identity identity;
  final FeedStore store;
  final KeyStore keyStore;
  final FeedWriter writer;
  final FeedReplicator replicator;

  /// Seals what friends must not read. See `PrivateBox`.
  final PrivateBox box;

  final Set<String> _follows = <String>{};
  ChallengePlan? _cachedPlan;
  String? _cachedPlanFor;

  String get did => identity.did;

  Set<String> get follows => Set<String>.unmodifiable(_follows);

  Stream<FeedEvent> get changes => store.changes;

  static Future<AppRepository> open({
    required KeyStore keyStore,
    FeedStore? store,
  }) async {
    final identity = await keyStore.readOrCreate();
    final feedStore = store ?? await SqliteFeedStore.open();
    final repository = AppRepository(
      identity: identity,
      store: feedStore,
      keyStore: keyStore,
      box: await PrivateBox.forIdentity(identity),
    );
    await repository.reloadFollows();
    return repository;
  }

  Future<void> reloadFollows() async {
    _follows.clear();
    final store = this.store;
    if (store is SqliteFeedStore) {
      for (final FollowRecord record in await store.follows()) {
        _follows.add(record.did);
      }
    } else {
      // Any store: infer follows from whose feeds we already replicate.
      for (final FeedHead head in await store.heads()) {
        if (head.did != did) _follows.add(head.did);
      }
    }
  }

  Future<AppSnapshot> snapshot({DayKey? today}) async {
    final day = today ?? DayKey.today();

    // Our own sealed events are opened before folding; a friend's stay
    // sealed and are skipped by the projection.
    final myEvents = await store.eventsOf(did);
    final me = projectUser(did, await box.openAll(myEvents), today: day);
    // The league ranks everyone by what everyone can verify. Friends only
    // see our public events, so our own row is computed the same way —
    // otherwise every device would rank us differently.
    final meAsFriendsSeeMe = projectUser(did, myEvents, today: day);

    final friends = <UserProjection>[];
    for (final friendDid in _follows) {
      friends.add(projectUser(
        friendDid,
        await store.eventsOf(friendDid),
        today: day,
      ));
    }
    friends.sort((UserProjection a, UserProjection b) =>
        b.streak.current.compareTo(a.streak.current));

    final activity = buildActivityFeed(
      await store.recent(limit: 300),
      profiles: <String, PeerProfile>{
        me.did: me.profile,
        for (final UserProjection f in friends) f.did: f.profile,
      },
      selfDid: did,
    );

    final weekKey = day.isoWeekKey;
    final league = buildLeagueStanding(
      weekKey: weekKey,
      league: leagueForXp(me.lifetimeXp),
      entries: <LeagueEntry>[
        meAsFriendsSeeMe.toPeerState(today: day).toLeagueEntry(
              checkInsThisWeek: meAsFriendsSeeMe.checkInsInWeek(weekKey),
            ),
        for (final UserProjection f in friends)
          f.toPeerState(today: day).toLeagueEntry(
                checkInsThisWeek: f.checkInsInWeek(weekKey),
              ),
      ],
    );

    final nudgedToday = <String>{};
    final cheeredEvents = <String>{};
    for (final event in myEvents.where((FeedEvent e) =>
        e.type == FeedEventType.nudge || e.type == FeedEventType.cheer)) {
      final target = event.payload['target'] as String?;
      if (event.type == FeedEventType.nudge) {
        if (target != null && DayKey.fromDateTime(event.timestamp) == day) {
          nudgedToday.add(target);
        }
      } else {
        final hash = event.payload['event'] as String?;
        if (hash != null) cheeredEvents.add(hash);
      }
    }

    return AppSnapshot(
      identity: identity,
      me: me,
      friends: friends,
      activity: activity,
      league: league,
      today: day,
      nudgedToday: nudgedToday,
      cheeredEvents: cheeredEvents,
      plan: me.challenge == null ? null : _planFor(me.challenge!),
    );
  }

  ChallengePlan _planFor(Challenge challenge) {
    // The plan is a pure function of the challenge, so it only needs
    // regenerating when the challenge itself changes.
    final key = canonicalJson(challenge.toJson());
    if (_cachedPlanFor == key && _cachedPlan != null) return _cachedPlan!;
    _cachedPlanFor = key;
    return _cachedPlan = buildPlan(challenge);
  }

  Future<void> saveProfile({
    required String displayName,
    required String avatarEmoji,
    String? goalStatement,
  }) =>
      writer.append(
        FeedEventType.profile,
        PeerProfile(
          did: did,
          displayName: displayName,
          avatarEmoji: avatarEmoji,
          goalStatement: goalStatement == null || goalStatement.isEmpty
              ? null
              : goalStatement,
        ).toPayload(),
      );

  /// Appends [payload] as [type] — in the clear, or sealed when [private].
  Future<FeedEvent> _append(
    String type,
    Map<String, dynamic> payload, {
    bool private = false,
  }) async {
    if (!private) return writer.append(type, payload);
    return writer.append(FeedEventType.private, await box.seal(type, payload));
  }

  /// Two events: what friends may see, then the full challenge sealed. The
  /// owner's projection folds both in order, so the full one wins at home
  /// while friends only ever get the public view.
  Future<void> _publishChallenge(String type, Challenge challenge) async {
    final public = publicViewOf(challenge);
    await writer.append(type, <String, dynamic>{
      'challenge': public.toJson(),
      if (public.goal.statement.isNotEmpty) 'statement': public.goal.statement,
    });
    await _append(
      type,
      <String, dynamic>{'challenge': challenge.toJson()},
      private: true,
    );
  }

  Future<void> startChallenge(Challenge challenge) =>
      _publishChallenge(FeedEventType.challengeStarted, challenge);

  /// A new split, own nutrition targets, a sharing change. History stays.
  Future<void> updateChallenge(Challenge challenge) =>
      _publishChallenge(FeedEventType.challengeUpdated, challenge);

  bool _isPrivate(Habit habit, Challenge? challenge) =>
      !(challenge?.sharing.isHabitShared(habit.id) ?? true);

  Future<Challenge?> _currentChallenge() async =>
      (await snapshot()).challenge;

  /// Logs a habit for a day. Re-logging the same habit and day overwrites the
  /// earlier entry at projection time, so a user can correct a number without
  /// the feed growing a contradiction.
  Future<FeedEvent> checkIn({
    required Habit habit,
    required DayKey day,
    num? value,
    String? note,
    int? streak,
    bool tracked = false,
    Challenge? challenge,
  }) async =>
      _append(
        FeedEventType.checkIn,
        <String, dynamic>{
          ...CheckIn(
            habitId: habit.id,
            category: habit.category,
            day: day,
            value: value ?? habit.target,
            loggedAt: DateTime.now(),
            note: note,
            tracked: tracked,
          ).toPayload(),
          if (streak != null) 'streak': streak,
        },
        private: _isPrivate(habit, challenge ?? await _currentChallenge()),
      );

  Future<FeedEvent> logRelapse({
    required Habit habit,
    required DayKey day,
    String? note,
    Challenge? challenge,
  }) async =>
      _append(
        FeedEventType.checkIn,
        CheckIn(
          habitId: habit.id,
          category: habit.category,
          day: day,
          value: 0,
          loggedAt: DateTime.now(),
          note: note,
          relapse: true,
        ).toPayload(),
        private: _isPrivate(habit, challenge ?? await _currentChallenge()),
      );

  /// A finished session: the log (shared or sealed, as the user chose), then
  /// the gym check-in it backs — marked tracked, which is what earns the
  /// plan bonus.
  Future<void> logWorkout({
    required WorkoutLog log,
    required Habit habit,
    required Challenge challenge,
    int? streak,
  }) async {
    final hideDetails =
        !challenge.sharing.shareWorkouts || _isPrivate(habit, challenge);
    await _append(
      FeedEventType.workoutLogged,
      log.toPayload(),
      private: hideDetails,
    );
    await checkIn(
      habit: habit,
      day: log.day,
      streak: streak,
      tracked: true,
      challenge: challenge,
    );
  }

  /// The food diary is always sealed: what someone eats is nobody's
  /// business but theirs.
  Future<void> logFood(FoodEntry entry) =>
      _append(FeedEventType.foodLogged, entry.toPayload(), private: true);

  Future<void> removeFood(String entryId) => _append(
        FeedEventType.foodRemoved,
        <String, dynamic>{'id': entryId},
        private: true,
      );

  Future<void> useStreakFreeze(DayKey day) => writer.append(
        FeedEventType.streakFreeze,
        <String, dynamic>{'day': day.toString()},
      );

  /// Day 100 is not the end. Ascending starts the next cycle without resetting
  /// anything the user built.
  Future<void> ascend(Challenge challenge) {
    final next = challenge.cycle + 1;
    // Only the cycle index goes on the wire: a friend's device renders the
    // tier name in *their* language, so a localized string in the payload
    // would show up untranslated on the other side.
    return writer.append(
      FeedEventType.challengeAscended,
      <String, dynamic>{'cycle': next},
    );
  }

  Future<void> nudge(String targetDid, String text) => writer.append(
        FeedEventType.nudge,
        <String, dynamic>{'target': targetDid, 'text': text},
      );

  Future<void> cheer(
    String targetDid,
    String text, {
    String? eventHash,
  }) =>
      writer.append(
        FeedEventType.cheer,
        <String, dynamic>{
          'target': targetDid,
          'text': text,
          if (eventHash != null) 'event': eventHash,
        },
      );

  /// Throws [InviteRejection] so the caller can render the reason in the
  /// user's language.
  Future<void> addFriend(Invite invite) async {
    if (!invite.isWellFormed) {
      throw const InviteRejection(InviteProblem.malformed);
    }
    if (invite.did == did) {
      throw const InviteRejection(InviteProblem.self);
    }
    final store = this.store;
    if (store is SqliteFeedStore) {
      await store.addFollow(
        invite.did,
        name: invite.displayName,
        emoji: invite.avatarEmoji,
      );
    }
    _follows.add(invite.did);
  }

  Future<void> removeFriend(String friendDid) async {
    final store = this.store;
    if (store is SqliteFeedStore) await store.removeFollow(friendDid);
    _follows.remove(friendDid);
  }

  Invite inviteForMe({
    required String displayName,
    required String avatarEmoji,
    List<String> addresses = const <String>[],
  }) =>
      Invite(
        did: did,
        displayName: displayName,
        avatarEmoji: avatarEmoji,
        addresses: addresses,
      );

  Future<String> recoveryKey() => identity.recoveryKey;

  Future<void> wipeEverything() async {
    final store = this.store;
    if (store is SqliteFeedStore) await store.wipe();
    await keyStore.clear();
    _follows.clear();
    _cachedPlan = null;
    _cachedPlanFor = null;
  }
}
