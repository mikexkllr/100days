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
/// means a friend's streak is computed by *us*, from *their events* — they
/// cannot simply claim a number.
class UserProjection {
  UserProjection({
    required this.userId,
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
    required this.eventCount,
    required this.lastRelapseDay,
    this.workoutLogs = const <WorkoutLog>[],
    this.foodByDay = const <String, List<FoodEntry>>{},
    this.projectedFor,
  });

  final String userId;
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
  final int eventCount;
  final DayKey? lastRelapseDay;

  /// Logged sessions, oldest first.
  final List<WorkoutLog> workoutLogs;

  /// The food diary, keyed by day. Only ever filled for the user's own feed:
  /// diary events are private, so a friend's device never receives them.
  final Map<String, List<FoodEntry>> foodByDay;

  /// The day this projection was folded for — the author's today, which for
  /// a friend in another time zone is not necessarily ours.
  final DayKey? projectedFor;

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
        count +=
            log.entries.where((CheckIn e) => !e.relapse && e.value > 0).length;
      }
    });
    return count;
  }

  PeerState toPeerState({DayKey? today}) {
    final now = today ?? projectedFor ?? DayKey.today();
    return PeerState(
      profile: profile,
      currentStreak: streak.current,
      longestStreak: streak.longest,
      lifetimeXp: lifetimeXp,
      weeklyXp: xpInWeek(now.isoWeekKey),
      dayNumber: challenge?.dayNumber(now) ?? 0,
      tier: challenge?.tier ?? tierForCycle(0),
      activeToday: (logsByDay[now.toString()]
              ?.entries
              .where((CheckIn e) => !e.relapse && e.value > 0)
              .isNotEmpty ??
          false),
      lastActivityAt: lastActivityAt,
      lastActivity: lastActivity,
      eventCount: eventCount,
      challenge: challenge,
    );
  }
}

/// Folds a single author's events into a projection.
///
/// The server has already checked who wrote each event. This function is
/// total: a feed with no challenge, no profile or nothing but a
/// half-written genesis still yields a usable projection.
UserProjection projectUser(
  String userId,
  List<FeedEvent> events, {
  DayKey? today,
}) {
  final now = today ?? DayKey.today();
  final ordered = events.where((FeedEvent e) => e.author == userId).toList()
    ..sort(compareEvents);

  var profile = PeerProfile(userId: userId, displayName: 'Anonym', avatarEmoji: '🙂');
  Challenge? challenge;
  final logs = <String, List<CheckIn>>{};
  final frozen = <String>{};
  DateTime? lastActivityAt;
  var lastActivity = PeerActivity.none;
  DayKey? lastRelapse;
  final workoutLogs = <WorkoutLog>[];
  final food = <String, FoodEntry>{};

  for (final event in ordered) {
    try {
      switch (event.type) {
        case FeedEventType.profile:
          profile = PeerProfile.fromPayload(userId, event.payload);

        case FeedEventType.challengeStarted:
          final started = Challenge.fromJson(
            Map<String, dynamic>.from(event.payload['challenge'] as Map),
          );
          // Only an explicit restart begins again from day one. A second start
          // without it — an onboarding finished before the first sync brought
          // the real challenge down — must not wipe a running streak.
          challenge = challenge == null || event.payload['restart'] == true
              ? started
              : started.copyWith(
                  startDay: challenge.startDay,
                  cycle: challenge.cycle,
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
            loggedAt: event.loggedAt,
            eventId: event.id,
          );
          final entries =
              logs.putIfAbsent(checkIn.day.toString(), () => <CheckIn>[])
                ..removeWhere((CheckIn e) => e.habitId == checkIn.habitId);
          // An undo takes the entry back out: a correction is a new event, and
          // the day reads as if the tick had never happened.
          if (event.payload['undo'] == true) {
            if (entries.isEmpty) logs.remove(checkIn.day.toString());
            break;
          }
          entries.add(checkIn);
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
            loggedAt: event.loggedAt,
          ));

        case FeedEventType.foodLogged:
          final entry = FoodEntry.fromPayload(event.payload);
          food[entry.id] = entry;

        case FeedEventType.foodRemoved:
          food.remove(event.payload['id'] as String?);

        case FeedEventType.nudge:
        case FeedEventType.cheer:
          lastActivityAt ??= event.timestamp;

        // Types written by a newer app version: skipped, not fatal.
        default:
          break;
      }
    } on Object {
      // A payload this version cannot read — written by a newer app, or
      // malformed. One bad event must not take the whole feed down with it.
      continue;
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
    userId: userId,
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
    eventCount: ordered.length,
    lastRelapseDay: lastRelapse,
    workoutLogs: workoutLogs,
    foodByDay: foodByDay,
    projectedFor: now,
  );
}

/// The author's today, by the clock their latest check-in was written on.
///
/// A friend's streak has to be folded with *their* today: folded with ours,
/// a friend eight hours behind would look as if they had missed a day they
/// still have the evening of. Falls back to our today for feeds written
/// before the offset was recorded.
DayKey authorTodayOf(List<FeedEvent> events, {DateTime? now}) {
  DateTime? latestAt;
  int? offset;
  for (final event in events) {
    if (event.type != FeedEventType.checkIn) continue;
    final tz = event.payload['tz'];
    if (tz is! num) continue;
    if (latestAt == null || event.timestamp.isAfter(latestAt)) {
      latestAt = event.timestamp;
      offset = tz.toInt();
    }
  }
  return offset == null
      ? DayKey.fromDateTime(now ?? DateTime.now())
      : DayKey.todayAtOffset(offset, now: now);
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
