import 'dart:async';

import 'package:hundred_core/hundred_core.dart';

import 'feed_sync.dart';
import 'social_backend.dart';

export 'social_backend.dart'
    show FriendLink, FriendStatus, InvitePreview, InviteProblem, InviteRejection;

/// One consistent read of everything the UI needs.
class AppSnapshot {
  const AppSnapshot({
    required this.userId,
    required this.me,
    required this.friends,
    required this.activity,
    required this.league,
    required this.today,
    required this.nudgedToday,
    required this.cheeredEvents,
    this.incomingRequests = const <FriendLink>[],
    this.outgoingRequests = const <FriendLink>[],
    this.plan,
  });

  /// The signed-in account.
  final String userId;
  final UserProjection me;
  final List<UserProjection> friends;
  final List<ActivityItem> activity;
  final LeagueStanding league;
  final ChallengePlan? plan;
  final DayKey today;

  /// People who asked to be friends and wait for an answer.
  final List<FriendLink> incomingRequests;

  /// People the user asked, who have not answered yet.
  final List<FriendLink> outgoingRequests;

  /// Friends already nudged today, derived from the feed rather than held in
  /// widget state — a list that rebuilds must not forget what you sent.
  final Set<String> nudgedToday;

  /// Ids of the check-in events already cheered.
  final Set<String> cheeredEvents;

  bool get hasChallenge => me.challenge != null;

  Challenge? get challenge => me.challenge;

  List<PeerState> get peerStates =>
      friends.map((UserProjection f) => f.toPeerState(today: today)).toList();

  Map<String, PeerProfile> get profiles => <String, PeerProfile>{
        me.userId: me.profile,
        for (final UserProjection f in friends) f.userId: f.profile,
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
/// Everything a user does becomes an event on their own feed; nothing is
/// stored "beside" the log. Events land in the local store first, so the app
/// works without a signal, and the sync sends them on. That constraint is
/// what lets a friend's device reconstruct the exact same streak from the
/// same events.
class AppRepository {
  AppRepository({
    required this.userId,
    required this.store,
    SocialBackend? social,
    FeedSync? sync,
  })  : social = social ?? MemorySocialBackend(userId: userId),
        sync = sync ?? OfflineFeedSync() {
    writer = FeedWriter(
      author: userId,
      store: store,
      onWritten: (FeedEvent _) => this.sync.schedulePush(),
    );
  }

  /// The signed-in account. Events are written under it.
  final String userId;
  final FeedStore store;
  final SocialBackend social;
  final FeedSync sync;
  late final FeedWriter writer;

  List<FriendLink> _links = const <FriendLink>[];
  ChallengePlan? _cachedPlan;
  String? _cachedPlanFor;

  /// Accepted friends: the feeds this device folds besides the user's own.
  Set<String> get follows => <String>{
        for (final FriendLink l in _links)
          if (l.status == FriendStatus.friends) l.userId,
      };

  Stream<FeedEvent> get changes => store.changes;

  /// Reads the friend list from the server and tells the sync whose feeds
  /// belong on this device. Keeps the last known list when offline.
  Future<void> refreshFriends() async {
    try {
      _links = await social.friendships();
    } on Object {
      return;
    }
    await sync.setAuthors(<String>{userId, ...follows});
  }

  /// Friends first, then the feeds: a friend accepted a minute ago must be
  /// in the set before their events are pulled.
  Future<SyncReport> syncNow() async {
    await refreshFriends();
    return sync.syncNow();
  }

  Future<AppSnapshot> snapshot({DayKey? today}) async {
    final day = today ?? DayKey.today();

    final myEvents = await store.eventsOf(userId);
    final me = projectUser(userId, myEvents, today: day);
    // The league ranks everyone by what everyone can verify. Friends only
    // receive our shared events, so our own row is computed the same way —
    // otherwise every device would rank us differently.
    final meAsFriendsSeeMe = projectUser(
      userId,
      myEvents
          .where((FeedEvent e) => e.visibility == EventVisibility.friends)
          .toList(),
      today: day,
    );

    final friends = <UserProjection>[];
    for (final friendId in follows) {
      friends.add(projectUser(
        friendId,
        await store.eventsOf(friendId),
        today: day,
      ));
    }
    friends.sort((UserProjection a, UserProjection b) =>
        b.streak.current.compareTo(a.streak.current));

    final activity = buildActivityFeed(
      await store.recent(limit: 300),
      profiles: <String, PeerProfile>{
        me.userId: me.profile,
        for (final UserProjection f in friends) f.userId: f.profile,
      },
      selfId: userId,
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
        final cheered = event.payload['event'] as String?;
        if (cheered != null) cheeredEvents.add(cheered);
      }
    }

    return AppSnapshot(
      userId: userId,
      me: me,
      friends: friends,
      activity: activity,
      league: league,
      today: day,
      nudgedToday: nudgedToday,
      cheeredEvents: cheeredEvents,
      incomingRequests: <FriendLink>[
        for (final FriendLink l in _links)
          if (l.status == FriendStatus.incoming) l,
      ],
      outgoingRequests: <FriendLink>[
        for (final FriendLink l in _links)
          if (l.status == FriendStatus.outgoing) l,
      ],
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
  }) async {
    await writer.append(
        FeedEventType.profile,
        PeerProfile(
          userId: userId,
          displayName: displayName,
          avatarEmoji: avatarEmoji,
          goalStatement: goalStatement == null || goalStatement.isEmpty
              ? null
              : goalStatement,
        ).toPayload(),
      );
    // The name people see in a friend request, before they are friends and
    // can read the feed.
    try {
      await social.updateProfile(displayName: displayName, emoji: avatarEmoji);
    } on Object {
      // Offline: the profile event above carries it; the next save retries.
    }
  }

  /// Appends [payload] as [type] — for friends, or only for the user when
  /// [private].
  Future<FeedEvent> _append(
    String type,
    Map<String, dynamic> payload, {
    bool private = false,
  }) =>
      writer.append(
        type,
        payload,
        visibility:
            private ? EventVisibility.private : EventVisibility.friends,
      );

  /// Two events: what friends may see, then the full challenge, private. The
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

  /// A finished session: the log (shared or private, as the user chose), then
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

  /// The food diary is always private: what someone eats is nobody's
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

  Future<FeedEvent> nudge(String targetId, String text) => writer.append(
        FeedEventType.nudge,
        <String, dynamic>{'target': targetId, 'text': text},
      );

  Future<FeedEvent> cheer(
    String targetId,
    String text, {
    String? eventId,
  }) =>
      writer.append(
        FeedEventType.cheer,
        <String, dynamic>{
          'target': targetId,
          'text': text,
          if (eventId != null) 'event': eventId,
        },
      );

  /// The code behind the user's QR code and invite link.
  Future<String> myInviteCode() => social.myInviteCode();

  Future<InvitePreview?> previewInvite(String code) =>
      social.previewInvite(code);

  /// Redeems someone's invite: both are friends straight away, because
  /// whoever shared the code already said yes. Throws [InviteRejection].
  Future<String> redeemInvite(String code) async {
    final String owner;
    try {
      owner = await social.redeemInvite(code);
    } on InviteRejection {
      rethrow;
    } on Object {
      throw const InviteRejection(InviteProblem.offline);
    }
    await syncNow();
    return owner;
  }

  Future<void> sendFriendRequest(String otherId) async {
    final bool friendsNow = await social.sendFriendRequest(otherId);
    if (!friendsNow) unawaited(social.notify(friendRequestTo: otherId));
    await syncNow();
  }

  /// Sends [event] now and asks the server to tell the friends it concerns
  /// — a nudge's target, or friends who have not shown up yet. Best effort.
  Future<void> notifyFriends(FeedEvent event) async {
    if (event.visibility != EventVisibility.friends) return;
    try {
      await sync.syncNow();
      await social.notify(eventId: event.id);
    } on Object {
      // Offline: the event goes out with the next sync; the push does not.
    }
  }

  int? _reportedXp;
  String? _reportedWeek;

  /// Tells the public league this week's XP — the number friends can verify
  /// from the shared events, so the user ranks the same everywhere.
  Future<void> reportLeagueXp(AppSnapshot snapshot) async {
    final String week = snapshot.today.isoWeekKey;
    final int xp = snapshot.league.entries
            .where((LeagueEntry e) => e.userId == userId)
            .firstOrNull
            ?.weeklyXp ??
        0;
    if (week == _reportedWeek && xp == _reportedXp) return;
    try {
      await social.reportWeekXp(week, xp);
      _reportedWeek = week;
      _reportedXp = xp;
    } on Object {
      // Next snapshot tries again.
    }
  }

  Future<void> respondToRequest(String requesterId, {required bool accept}) async {
    await social.respondToRequest(requesterId, accept: accept);
    await syncNow();
  }

  /// Ends the friendship on the server and drops their feed from this
  /// device.
  Future<void> removeFriend(String friendId) async {
    await social.removeFriend(friendId);
    _links = _links.where((FriendLink l) => l.userId != friendId).toList();
    await store.removeAuthor(friendId);
    await sync.setAuthors(<String>{userId, ...follows});
  }

  /// Forgets everything on this device, e.g. on sign-out. The account and
  /// its feed stay on the server.
  Future<void> clearLocal() async {
    await store.clear();
    _links = const <FriendLink>[];
    _cachedPlan = null;
    _cachedPlanFor = null;
  }

  Future<void> close() async {
    await sync.dispose();
    await social.dispose();
    await store.close();
  }
}
