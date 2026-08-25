import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/key_store.dart';
import 'package:hundred_days/state/providers.dart';
import 'package:hundred_days/theme/theme.dart';

/// Builds a repository backed entirely by memory, so widget tests never touch
/// sqflite or the platform keystore.
Future<AppRepository> testRepository({Identity? identity}) async {
  final KeyStore keyStore = InMemoryKeyStore(identity);
  return AppRepository.open(keyStore: keyStore, store: MemoryFeedStore());
}

Challenge testChallenge({
  DayKey? startDay,
  List<HabitCategory> habits = const <HabitCategory>[
    HabitCategory.noSugar,
    HabitCategory.reading,
  ],
  GoalArchetype archetype = GoalArchetype.discipline,
}) =>
    Challenge(
      id: 'test-challenge',
      goal: Goal(archetype: archetype, statement: '100 Tage durchziehen'),
      habits: <Habit>[
        for (final HabitCategory category in habits)
          Habit.fromCategory(category),
      ],
      startDay: startDay ?? DayKey.today(),
    );

/// Seeds a peer's feed into [repository] and follows them, so the social
/// surfaces have someone to be jealous of.
Future<Identity> seedFriend(
  AppRepository repository, {
  required String name,
  required String emoji,

  /// 0 = checked in today, 1 = last checked in yesterday, and so on.
  int inactiveDays = 0,
  int daysBack = 5,
}) async {
  final Identity friend = await Identity.generate();
  final FeedWriter writer =
      FeedWriter(identity: friend, store: repository.store);
  final Challenge challenge =
      testChallenge(startDay: DayKey.today().addDays(-daysBack));

  // Timestamps must never move backwards within a feed, or the chain fails
  // validation on a peer's device — so the genesis events are dated to the
  // start of the challenge, before any of the check-ins below.
  final DateTime start =
      challenge.startDay.toDateTime().add(const Duration(hours: 8));
  await writer.append(
    FeedEventType.profile,
    <String, dynamic>{'displayName': name, 'avatarEmoji': emoji},
    timestamp: start,
  );
  await writer.append(
    FeedEventType.challengeStarted,
    <String, dynamic>{
      'challenge': challenge.toJson(),
      'statement': challenge.goal.statement,
    },
    timestamp: start.add(const Duration(minutes: 5)),
  );

  for (int i = daysBack; i >= inactiveDays; i--) {
    final DayKey day = DayKey.today().addDays(-i);
    for (final Habit habit in challenge.habits) {
      await writer.append(
        FeedEventType.checkIn,
        <String, dynamic>{
          ...CheckIn(
            habitId: habit.id,
            category: habit.category,
            day: day,
            value: habit.target,
            loggedAt: day.toDateTime(),
          ).toPayload(),
          'streak': daysBack - i + 1,
        },
        timestamp: day.toDateTime().add(const Duration(hours: 9)),
      );
    }
  }

  await repository.addFriend(Invite(
    did: friend.did,
    displayName: name,
    avatarEmoji: emoji,
  ));
  return friend;
}

/// Wraps [child] in the providers and theme the real app supplies.
Widget wrapForTest({
  required AppRepository repository,
  required Widget child,
  List<Override> overrides = const <Override>[],
}) {
  return ProviderScope(
    overrides: <Override>[
      repositoryProvider.overrideWithValue(repository),
      ...overrides,
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: child),
    ),
  );
}
