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
  })  : writer = FeedWriter(identity: identity, store: store),
        replicator = FeedReplicator(store);

  final Identity identity;
  final FeedStore store;
  final KeyStore keyStore;
  final FeedWriter writer;
  final FeedReplicator replicator;

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

    final me = projectUser(did, await store.eventsOf(did), today: day);

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
        me.toPeerState(today: day).toLeagueEntry(
              checkInsThisWeek: me.checkInsInWeek(weekKey),
            ),
        for (final UserProjection f in friends)
          f.toPeerState(today: day).toLeagueEntry(
                checkInsThisWeek: f.checkInsInWeek(weekKey),
              ),
      ],
    );

    final myEvents = await store.eventsOf(
      did,
      types: <String>{FeedEventType.nudge, FeedEventType.cheer},
    );
    final nudgedToday = <String>{};
    final cheeredEvents = <String>{};
    for (final event in myEvents) {
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
          goalStatement: goalStatement,
        ).toPayload(),
      );

  Future<void> startChallenge(Challenge challenge) => writer.append(
        FeedEventType.challengeStarted,
        <String, dynamic>{
          'challenge': challenge.toJson(),
          'statement': challenge.goal.statement,
        },
      );

  /// Logs a habit for a day. Re-logging the same habit and day overwrites the
  /// earlier entry at projection time, so a user can correct a number without
  /// the feed growing a contradiction.
  Future<FeedEvent> checkIn({
    required Habit habit,
    required DayKey day,
    num? value,
    String? note,
    int? streak,
  }) =>
      writer.append(
        FeedEventType.checkIn,
        <String, dynamic>{
          ...CheckIn(
            habitId: habit.id,
            category: habit.category,
            day: day,
            value: value ?? habit.target,
            loggedAt: DateTime.now(),
            note: note,
          ).toPayload(),
          if (streak != null) 'streak': streak,
        },
      );

  Future<FeedEvent> logRelapse({
    required Habit habit,
    required DayKey day,
    String? note,
  }) =>
      writer.append(
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
