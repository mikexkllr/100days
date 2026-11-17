import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/household_backend.dart';
import 'package:hundred_days/data/locale_store.dart';
import 'package:hundred_days/data/social_backend.dart';
import 'package:hundred_days/l10n/l10n.dart';
import 'package:hundred_days/state/household_providers.dart';
import 'package:hundred_days/state/providers.dart';
import 'package:hundred_days/theme/theme.dart';

/// Builds a repository backed entirely by memory, so widget tests never touch
/// sqflite or the network.
Future<AppRepository> testRepository({String userId = 'me'}) async =>
    AppRepository(
      userId: userId,
      store: MemoryFeedStore(),
      social: MemorySocialBackend(userId: userId),
    );

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

/// Seeds a friend's feed into [repository] and befriends them, so the social
/// surfaces have someone to be jealous of. Returns the friend's id.
Future<String> seedFriend(
  AppRepository repository, {
  required String name,
  required String emoji,

  /// 0 = checked in today, 1 = last checked in yesterday, and so on.
  int inactiveDays = 0,
  int daysBack = 5,
}) async {
  final String friend = 'friend-${name.toLowerCase()}';
  final FeedWriter writer = FeedWriter(author: friend, store: repository.store);
  final Challenge challenge =
      testChallenge(startDay: DayKey.today().addDays(-daysBack));

  // The profile and the challenge come first in the friend's feed: they are
  // dated to the start of the challenge, before any of the check-ins below.
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

  (repository.social as MemorySocialBackend).link(FriendLink(
    userId: friend,
    displayName: name,
    emoji: emoji,
    status: FriendStatus.friends,
  ));
  await repository.refreshFriends();
  return friend;
}

/// Keeps widget tests off the platform: no language model to reach, a
/// household that lives in memory.
List<Override> platformFreeOverrides({
  LlmClient llm = const UnavailableLlmClient(),
  HouseholdBackend? household,
  Locale locale = const Locale('de'),
}) =>
    <Override>[
      // Prompts are written in this language; no stored choice to read.
      effectiveLocaleProvider.overrideWithValue(locale),
      llmClientProvider.overrideWithValue(llm),
      householdBackendProvider
          .overrideWithValue(household ?? MemoryHouseholdBackend()),
    ];

/// Widget tests run with the system's "reduce motion" switched on. The
/// flame flickers, embers rise and buttons shimmer for as long as they are on
/// screen, and `pumpAndSettle` would wait for them forever; the app honours
/// the setting for people who ask for less motion, and the tests ride on
/// that. Everything that carries meaning still animates and finishes.
Widget reducedMotion(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    );

/// Wraps [child] in the providers, theme and localizations the real app
/// supplies. Defaults to German so the tests read like the product does; pass
/// [locale] to check the other language.
Widget wrapForTest({
  required AppRepository repository,
  required Widget child,
  Locale locale = const Locale('de'),
  List<Override> overrides = const <Override>[],
  LlmClient llm = const UnavailableLlmClient(),
  HouseholdBackend? household,
}) {
  return ProviderScope(
    overrides: <Override>[
      repositoryProvider.overrideWithValue(repository),
      ...platformFreeOverrides(llm: llm, household: household, locale: locale),
      ...overrides,
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      builder: reducedMotion,
      locale: locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    ),
  );
}

/// Loads the string table for [locale] outside a widget tree, for tests that
/// need to compare what two languages render.
Future<AppLocalizations> localizationsFor(Locale locale) =>
    AppLocalizations.delegate.load(locale);
