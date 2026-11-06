import '../domain/challenge.dart';
import '../domain/check_in.dart';
import '../domain/habit.dart';
import '../domain/peer.dart';
import '../domain/progression.dart';
import '../domain/schedule.dart';
import '../domain/streak.dart';
import '../domain/workout_log.dart';
import '../feed/event.dart';
import '../nutrition/food_entry.dart';
import '../util/dates.dart';

/// Everything derived from one person's feed.
///
/// The feed is the only source of truth; this is a pure fold over it. That
/// means a peer's streak is computed by *us*, from *their signed events* —
/// they cannot simply claim a number.
class UserProjection {
  UserProjection({
    required this.did,
    required this.profile,
    required this.challenge,
    required this.logsByDay,
    required this.frozenDays,
    required this.streak,
    required this.habitStreaks,
    required this.lifetimeXp,
    required this.xpByDay,
    required this.lastActivityAt,
    required this.lastActivity,
    required this.headSeq,
    required this.lastRelapseDay,
    this.workoutLogs = const <WorkoutLog>[],
    this.foodByDay = const <String, List<FoodEntry>>{},
  });

  final String did;
  final PeerProfile profile;
  final Challenge? challenge;
  final Map<String, DayLog> logsByDay;
  final Set<String> frozenDays;
  final StreakStats streak;
  final Map<String, int> habitStreaks;
  final int lifetimeXp;
  final Map<String, int> xpByDay;
  final DateTime? lastActivityAt;
  final PeerActivity lastActivity;
  final int headSeq;
  final DayKey? lastRelapseDay;

  /// Logged sessions, oldest first.
  final List<WorkoutLog> workoutLogs;

  /// The food diary, keyed by day. Only ever filled for the user's own feed:
  /// a friend's diary arrives sealed.
  final Map<String, List<FoodEntry>> foodByDay;

  DayIntake intakeOn(DayKey day) => DayIntake(
        day: day,
        entries: foodByDay[day.toString()] ?? const <FoodEntry>[],
      );

  WorkoutLog? workoutLogOn(DayKey day) {
    for (final log in workoutLogs.reversed) {
      if (log.day == day) return log;
    }
    return null;
  }

  /// Every logged session of [exerciseId], newest first — what the
  /// progression recommender reads.
  List<ExerciseLog> historyOf(String exerciseId, {DayKey? before}) => <ExerciseLog>[
        for (final log in workoutLogs.reversed)
          if (before == null || log.day.isBefore(before))
            if (log.forExercise(exerciseId) case final ExerciseLog e) e,
      ];

  int xpInWeek(String weekKey) {
    var total = 0;
    xpByDay.forEach((String day, int xp) {
      if (DayKey.parse(day).isoWeekKey == weekKey) total += xp;
    });
    return total;
  }

  int checkInsInWeek(String weekKey) {
    var count = 0;
    logsByDay.forEach((String day, DayLog log) {
      if (DayKey.parse(day).isoWeekKey == weekKey) {
        count += log.entries.where((CheckIn e) => !e.relapse).length;
      }
    });
    return count;
  }

  PeerState toPeerState({DayKey? today}) {
    final now = today ?? DayKey.today();
    return PeerState(
      profile: profile,
      currentStreak: streak.current,
      longestStreak: streak.longest,
      lifetimeXp: lifetimeXp,
      weeklyXp: xpInWeek(now.isoWeekKey),
      dayNumber: challenge?.dayNumber(now) ?? 0,
      tier: challenge?.tier ?? tierForCycle(0),
      activeToday: (logsByDay[now.toString()]?.entries
                  .where((CheckIn e) => !e.relapse)
                  .isNotEmpty ??
              false),
      lastActivityAt: lastActivityAt,
      lastActivity: lastActivity,
      headSeq: headSeq,
      challenge: challenge,
    );
  }
}

/// Folds a single author's events into a projection.
///
/// Events are assumed already validated — [FeedReplicator] is the gate. This
/// function is total: a feed with no challenge, no profile or nothing but a
/// half-written genesis still yields a usable projection.
UserProjection projectUser(
  String did,
  List<FeedEvent> events, {
  DayKey? today,
}) {
  final now = today ?? DayKey.today();
  final ordered = events.where((FeedEvent e) => e.author == did).toList()
    ..sort((FeedEvent a, FeedEvent b) => a.seq.compareTo(b.seq));

  var profile = PeerProfile(did: did, displayName: 'Anonym', avatarEmoji: '🙂');
  Challenge? challenge;
  final logs = <String, List<CheckIn>>{};
  final frozen = <String>{};
  DateTime? lastActivityAt;
  var lastActivity = PeerActivity.none;
  DayKey? lastRelapse;
  final workoutLogs = <WorkoutLog>[];
  final food = <String, FoodEntry>{};

  for (final event in ordered) {
    switch (event.type) {
      case FeedEventType.profile:
        profile = PeerProfile.fromPayload(did, event.payload);

      case FeedEventType.challengeStarted:
        challenge = Challenge.fromJson(
          Map<String, dynamic>.from(event.payload['challenge'] as Map),
        );
        lastActivityAt = event.timestamp;
        lastActivity = const PeerActivity(
          kind: PeerActivityKind.challengeStarted,
        );

      case FeedEventType.challengeAscended:
        final cycle = (event.payload['cycle'] as num?)?.toInt();
        if (challenge != null && cycle != null) {
          challenge = challenge.copyWith(cycle: cycle);
        }
        lastActivityAt = event.timestamp;
        lastActivity = const PeerActivity(kind: PeerActivityKind.ascended);

      case FeedEventType.checkIn:
        final checkIn = CheckIn.fromPayload(
          event.payload,
          loggedAt: event.timestamp,
          eventHash: event.hash,
        );
        logs.putIfAbsent(checkIn.day.toString(), () => <CheckIn>[])
          ..removeWhere((CheckIn e) => e.habitId == checkIn.habitId)
          ..add(checkIn);
        lastActivityAt = event.timestamp;
        lastActivity = PeerActivity(
          kind: checkIn.relapse
              ? PeerActivityKind.relapse
              : PeerActivityKind.checkIn,
          category: checkIn.category,
        );
        if (checkIn.relapse) lastRelapse = checkIn.day;

      case FeedEventType.streakFreeze:
        final day = event.payload['day'] as String?;
        if (day != null) frozen.add(day);
        lastActivityAt = event.timestamp;
        lastActivity = const PeerActivity(
          kind: PeerActivityKind.streakFreeze,
        );

      case FeedEventType.missed:
        lastActivityAt = event.timestamp;
        lastActivity = const PeerActivity(kind: PeerActivityKind.missed);

      case FeedEventType.challengeUpdated:
        final updated = Challenge.fromJson(
          Map<String, dynamic>.from(event.payload['challenge'] as Map),
        );
        // An edit changes what the challenge asks for, never where it is:
        // the start day and the cycle reached stay as they were.
        challenge = challenge == null
            ? updated
            : updated.copyWith(
                startDay: challenge.startDay,
                cycle: challenge.cycle,
              );

      case FeedEventType.workoutLogged:
        workoutLogs.add(WorkoutLog.fromPayload(
          event.payload,
          loggedAt: event.timestamp,
        ));

      case FeedEventType.foodLogged:
        final entry = FoodEntry.fromPayload(event.payload);
        food[entry.id] = entry;

      case FeedEventType.foodRemoved:
        food.remove(event.payload['id'] as String?);

      case FeedEventType.nudge:
      case FeedEventType.cheer:
        lastActivityAt ??= event.timestamp;

      // Sealed events are opened by the owner before projecting; anyone
      // else sees an opaque blob and skips it.
      case FeedEventType.private:
      case FeedEventType.friendRequest:
        break;
    }
  }

  final foodByDay = <String, List<FoodEntry>>{};
  for (final entry in food.values) {
    foodByDay.putIfAbsent(entry.day.toString(), () => <FoodEntry>[]).add(entry);
  }

  final logsByDay = <String, DayLog>{
    for (final MapEntry<String, List<CheckIn>> entry in logs.entries)
      entry.key: DayLog(day: DayKey.parse(entry.key), entries: entry.value),
  };

  final streak = challenge == null
      ? StreakStats.empty
      : computeStreak(
          challenge: challenge,
          logsByDay: logsByDay,
          frozenDays: frozen,
          today: now,
        );

  final habitStreaks = <String, int>{};
  if (challenge != null) {
    for (final habit in challenge.habits) {
      habitStreaks[habit.id] = habitStreak(
        habit: habit,
        logsByDay: logsByDay,
        startDay: challenge.startDay,
        today: now,
      );
    }
  }

  final xpByDay = challenge == null
      ? <String, int>{}
      : _computeXpByDay(challenge, logsByDay, now);

  return UserProjection(
    did: did,
    profile: profile,
    challenge: challenge,
    logsByDay: logsByDay,
    frozenDays: frozen,
    streak: streak,
    habitStreaks: habitStreaks,
    lifetimeXp: xpByDay.values.fold(0, (int a, int b) => a + b),
    xpByDay: xpByDay,
    lastActivityAt: lastActivityAt,
    lastActivity: lastActivity,
    headSeq: ordered.isEmpty ? 0 : ordered.last.seq,
    lastRelapseDay: lastRelapse,
    workoutLogs: workoutLogs,
    foodByDay: foodByDay,
  );
}

/// Replays the challenge day by day so each check-in is scored with the
/// streak the user actually had at that moment — recomputing XP from a
/// *current* streak would retroactively inflate every past day.
Map<String, int> _computeXpByDay(
  Challenge challenge,
  Map<String, DayLog> logsByDay,
  DayKey today,
) {
  final result = <String, int>{};
  final runningStreaks = <String, int>{};
  final totalDays = today.differenceInDays(challenge.startDay) + 1;
  if (totalDays <= 0) return result;

  for (var i = 0; i < totalDays; i++) {
    final day = challenge.startDay.addDays(i);
    final log = logsByDay[day.toString()];
    if (log == null) {
      for (final habit in challenge.habits) {
        if (!habit.isActiveOn(day)) continue;
        if (habit.kind == HabitKind.abstain) {
          runningStreaks[habit.id] = (runningStreaks[habit.id] ?? 0) + 1;
        } else if (isHabitScheduledOn(habit, day)) {
          runningStreaks[habit.id] = 0;
        }
      }
      continue;
    }

    final xp = xpForDay(
      challenge: challenge,
      day: day,
      log: log,
      streakBeforeByHabit: Map<String, int>.from(runningStreaks),
    );
    if (xp > 0) result[day.toString()] = xp;

    for (final habit in challenge.habits) {
      if (!habit.isActiveOn(day)) continue;
      final entry = log.entryFor(habit.id);
      if (entry != null && entry.relapse) {
        runningStreaks[habit.id] = 0;
      } else if (entry != null && entry.value >= habit.target) {
        runningStreaks[habit.id] = (runningStreaks[habit.id] ?? 0) + 1;
      } else if (habit.kind == HabitKind.abstain) {
        runningStreaks[habit.id] = (runningStreaks[habit.id] ?? 0) + 1;
      } else if (isHabitScheduledOn(habit, day)) {
        runningStreaks[habit.id] = 0;
      }
    }
  }
  return result;
}
