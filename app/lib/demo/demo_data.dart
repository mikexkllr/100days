import 'package:flutter/widgets.dart';
import 'package:hundred_core/hundred_core.dart';

import '../data/app_repository.dart';
import '../data/household_backend.dart';
import '../data/social_backend.dart';

/// A believable account for store screenshots and demos: day 24 of a
/// challenge with an unbroken streak, three friends, a planned week and a
/// shopping list. Everything lives in memory; nothing touches a server.
Future<(AppRepository, MemoryHouseholdBackend)> seedDemo(Locale locale) async {
  final bool de = locale.languageCode == 'de';
  const String me = 'demo-me';
  final AppRepository repository = AppRepository(
    userId: me,
    store: MemoryFeedStore(),
    social: MemorySocialBackend(userId: me),
  );

  await _seedFeed(repository, me, de ? 'Mike' : 'Mike', '🔥',
      daysBack: 23, inactiveDays: 1, statement: de ? 'Fitter in 100 Tagen' : 'Fitter in 100 days');
  for (final (String name, String emoji, int days, int idle) in <(String, String, int, int)>[
    ('Lena', '🦊', 31, 0),
    ('Sophie', '🐼', 41, 0),
    ('Marcel', '🐻', 12, 1),
  ]) {
    final String id = 'demo-${name.toLowerCase()}';
    await _seedFeed(repository, id, name, emoji,
        daysBack: days, inactiveDays: idle, statement: '100');
    (repository.social as MemorySocialBackend).link(FriendLink(
      userId: id,
      displayName: name,
      emoji: emoji,
      status: FriendStatus.friends,
    ));
  }
  await repository.refreshFriends();

  final MemoryHouseholdBackend household =
      MemoryHouseholdBackend(userId: me, displayName: 'Mike');
  final String home = await household.ensureHousehold();
  final DayKey monday = DayKey.today().weekStart;
  final List<(String, String, int, int)> meals = <(String, String, int, int)>[
    ('Hähnchen-Curry mit Reis', 'Chicken curry with rice', 640, 42),
    ('Linsen-Dal', 'Lentil dal', 520, 24),
    ('Lachs mit Ofengemüse', 'Salmon with roast vegetables', 580, 38),
    ('Vollkorn-Pasta mit Pesto', 'Wholegrain pasta with pesto', 610, 22),
    ('Chili sin Carne', 'Chili sin carne', 540, 26),
    ('Shakshuka', 'Shakshuka', 450, 25),
  ];
  for (int i = 0; i < meals.length; i++) {
    final Recipe recipe = await household.saveRecipe(
      home,
      Recipe(
        id: newEventId(),
        title: de ? meals[i].$1 : meals[i].$2,
        servings: 2,
        minutes: 25,
        perServing: Nutrients(
          kcal: meals[i].$3.toDouble(),
          proteinG: meals[i].$4.toDouble(),
          carbsG: 60,
          fatG: 16,
        ),
        ingredients: const <Ingredient>[],
      ),
    );
    await household.saveEntry(
      home,
      PlanEntry(
        id: newEventId(),
        day: monday.addDays(i),
        slot: MealSlotKind.dinner,
        recipeId: recipe.id,
      ),
    );
  }
  final ShoppingListInfo list = await household.createList(
      home, ShoppingPeriod(monday, monday.addDays(6)));
  await household.addItems(home, list.id, <ShoppingItem>[
    for (final (String d, String e, ShopCategory c) in <(String, String, ShopCategory)>[
      ('Hähnchenbrust', 'Chicken breast', ShopCategory.meat),
      ('Lachsfilet', 'Salmon fillet', ShopCategory.meat),
      ('Rote Linsen', 'Red lentils', ShopCategory.pantry),
      ('Basmatireis', 'Basmati rice', ShopCategory.pantry),
      ('Brokkoli', 'Broccoli', ShopCategory.produce),
      ('Paprika', 'Peppers', ShopCategory.produce),
      ('Tomaten', 'Tomatoes', ShopCategory.produce),
      ('Joghurt', 'Yoghurt', ShopCategory.dairy),
      ('Eier', 'Eggs', ShopCategory.dairy),
    ])
      ShoppingItem(name: de ? d : e, category: c),
  ]);
  return (repository, household);
}

Future<void> _seedFeed(
  AppRepository repository,
  String author,
  String name,
  String emoji, {
  required int daysBack,
  required int inactiveDays,
  required String statement,
}) async {
  final FeedWriter writer = FeedWriter(author: author, store: repository.store);
  final Challenge challenge = Challenge(
    id: 'challenge-$author',
    goal: Goal(archetype: GoalArchetype.discipline, statement: statement),
    habits: <Habit>[
      Habit.fromCategory(HabitCategory.noSugar),
      Habit.fromCategory(HabitCategory.reading),
      Habit.fromCategory(HabitCategory.gym),
    ],
    startDay: DayKey.today().addDays(-daysBack),
  );
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
      'statement': statement,
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
}
