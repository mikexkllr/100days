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
  for (int i = 0; i < _demoMeals.length; i++) {
    final _DemoMeal meal = _demoMeals[i];
    final Recipe recipe = await household.saveRecipe(
      home,
      Recipe(
        id: newEventId(),
        title: de ? meal.de : meal.en,
        servings: 2,
        minutes: meal.minutes,
        level: meal.level,
        perServing: Nutrients(
          kcal: meal.kcal.toDouble(),
          proteinG: meal.protein.toDouble(),
          carbsG: 60,
          fatG: 16,
        ),
        ingredients: <Ingredient>[
          for (final _DemoIngredient i in meal.ingredients)
            Ingredient(
              name: de ? i.de : i.en,
              quantity: Quantity(i.amount, i.unit),
              category: i.category,
              staple: i.staple,
            ),
        ],
        steps: de ? meal.stepsDe : meal.stepsEn,
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
  // The week's list as the app makes it from those recipes: what is
  // bought with its amount, by aisle, and the kitchen basics at the end.
  final ShoppingPeriod week = ShoppingPeriod(monday, monday.addDays(6));
  final ShoppingListInfo list = await household.createList(home, week);
  await household.addItems(
    home,
    list.id,
    buildShoppingList(
      entries: await household.plan(home, week.start, week.end),
      recipes: await household.recipes(home),
      period: week,
      householdSize: 1,
    ),
  );
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

/// One line of a demo recipe, in both languages.
class _DemoIngredient {
  const _DemoIngredient(this.de, this.en, this.amount, this.unit, this.category,
      {this.staple = false});

  final String de;
  final String en;
  final double amount;
  final QtyUnit unit;
  final ShopCategory category;
  final bool staple;
}

/// A dinner of the demo week: a recipe as the planner writes one.
class _DemoMeal {
  const _DemoMeal({
    required this.de,
    required this.en,
    required this.kcal,
    required this.protein,
    required this.minutes,
    required this.level,
    required this.ingredients,
    required this.stepsDe,
    required this.stepsEn,
  });

  final String de;
  final String en;
  final int kcal;
  final int protein;
  final int minutes;
  final CookingLevel level;
  final List<_DemoIngredient> ingredients;
  final List<String> stepsDe;
  final List<String> stepsEn;
}

const _DemoIngredient _oil = _DemoIngredient(
    'Olivenöl', 'Olive oil', 2, QtyUnit.tbsp, ShopCategory.pantry,
    staple: true);
const _DemoIngredient _salt = _DemoIngredient(
    'Salz', 'Salt', 1, QtyUnit.tsp, ShopCategory.pantry,
    staple: true);
const _DemoIngredient _onion = _DemoIngredient(
    'Zwiebeln', 'Onions', 1, QtyUnit.piece, ShopCategory.produce);

const List<_DemoMeal> _demoMeals = <_DemoMeal>[
  _DemoMeal(
    de: 'Hähnchen-Curry mit Reis',
    en: 'Chicken curry with rice',
    kcal: 640,
    protein: 42,
    minutes: 30,
    level: CookingLevel.everyday,
    ingredients: <_DemoIngredient>[
      _DemoIngredient('Hähnchenbrust', 'Chicken breast', 300, QtyUnit.g, ShopCategory.meat),
      _DemoIngredient('Basmatireis', 'Basmati rice', 150, QtyUnit.g, ShopCategory.pantry),
      _DemoIngredient('Kokosmilch', 'Coconut milk', 200, QtyUnit.ml, ShopCategory.pantry),
      _onion,
      _DemoIngredient('Currypulver', 'Curry powder', 2, QtyUnit.tsp, ShopCategory.pantry, staple: true),
      _oil,
      _salt,
    ],
    stepsDe: <String>[
      'Den Reis in 300 ml Salzwasser zugedeckt 12 Minuten köcheln lassen.',
      'Zwiebel und Hähnchen würfeln, das Hähnchen im Öl bei starker Hitze 5 Minuten anbraten.',
      'Zwiebel und Curry 2 Minuten mitbraten, mit Kokosmilch ablöschen und 8 Minuten köcheln lassen.',
    ],
    stepsEn: <String>[
      'Simmer the rice in 300 ml salted water, lid on, for 12 minutes.',
      'Dice the onion and the chicken; fry the chicken in the oil over high heat for 5 minutes.',
      'Fry the onion and the curry powder along for 2 minutes, pour in the coconut milk and simmer for 8 minutes.',
    ],
  ),
  _DemoMeal(
    de: 'Linsen-Dal',
    en: 'Lentil dal',
    kcal: 520,
    protein: 24,
    minutes: 25,
    level: CookingLevel.everyday,
    ingredients: <_DemoIngredient>[
      _DemoIngredient('Rote Linsen', 'Red lentils', 200, QtyUnit.g, ShopCategory.pantry),
      _DemoIngredient('Tomaten', 'Tomatoes', 2, QtyUnit.piece, ShopCategory.produce),
      _onion,
      _DemoIngredient('Kreuzkümmel', 'Cumin', 1, QtyUnit.tsp, ShopCategory.pantry, staple: true),
      _oil,
      _salt,
    ],
    stepsDe: <String>[
      'Die Zwiebel würfeln und im Öl mit dem Kreuzkümmel 3 Minuten glasig dünsten.',
      'Linsen, gewürfelte Tomaten und 600 ml Wasser dazugeben und 15 Minuten köcheln lassen.',
      'Salzen und sämig rühren.',
    ],
    stepsEn: <String>[
      'Dice the onion and sweat it in the oil with the cumin for 3 minutes.',
      'Add the lentils, the diced tomatoes and 600 ml water and simmer for 15 minutes.',
      'Salt and stir until creamy.',
    ],
  ),
  _DemoMeal(
    de: 'Lachs mit Ofengemüse',
    en: 'Salmon with roast vegetables',
    kcal: 580,
    protein: 38,
    minutes: 35,
    level: CookingLevel.convenience,
    ingredients: <_DemoIngredient>[
      _DemoIngredient('Lachsfilet', 'Salmon fillet', 300, QtyUnit.g, ShopCategory.fish),
      _DemoIngredient('Brokkoli', 'Broccoli', 400, QtyUnit.g, ShopCategory.produce),
      _DemoIngredient('Paprika', 'Peppers', 2, QtyUnit.piece, ShopCategory.produce),
      _oil,
      _salt,
    ],
    stepsDe: <String>[
      'Den Ofen auf 200 °C vorheizen, das Gemüse in Stücke schneiden und mit Öl und Salz auf einem Blech 15 Minuten rösten.',
      'Den Lachs dazulegen und alles weitere 12 Minuten garen.',
    ],
    stepsEn: <String>[
      'Heat the oven to 200 °C, cut the vegetables into pieces and roast them on a tray with the oil and salt for 15 minutes.',
      'Add the salmon and cook everything for another 12 minutes.',
    ],
  ),
  _DemoMeal(
    de: 'Vollkorn-Pasta mit Pesto',
    en: 'Wholegrain pasta with pesto',
    kcal: 610,
    protein: 22,
    minutes: 15,
    level: CookingLevel.convenience,
    ingredients: <_DemoIngredient>[
      _DemoIngredient('Vollkorn-Pasta', 'Wholegrain pasta', 250, QtyUnit.g, ShopCategory.pantry),
      _DemoIngredient('Pesto (Glas)', 'Pesto (jar)', 100, QtyUnit.g, ShopCategory.pantry),
      _DemoIngredient('Kirschtomaten', 'Cherry tomatoes', 200, QtyUnit.g, ShopCategory.produce),
      _salt,
    ],
    stepsDe: <String>[
      'Die Pasta in reichlich Salzwasser nach Packung bissfest kochen.',
      'Abgießen, mit dem Pesto und den halbierten Tomaten mischen.',
    ],
    stepsEn: <String>[
      'Cook the pasta in plenty of salted water until al dente, as the pack says.',
      'Drain and toss with the pesto and the halved tomatoes.',
    ],
  ),
  _DemoMeal(
    de: 'Chili sin Carne',
    en: 'Chili sin carne',
    kcal: 540,
    protein: 26,
    minutes: 30,
    level: CookingLevel.everyday,
    ingredients: <_DemoIngredient>[
      _DemoIngredient('Kidneybohnen (Dose)', 'Kidney beans (can)', 400, QtyUnit.g, ShopCategory.pantry),
      _DemoIngredient('Gehackte Tomaten (Dose)', 'Chopped tomatoes (can)', 400, QtyUnit.g, ShopCategory.pantry),
      _DemoIngredient('Paprika', 'Peppers', 1, QtyUnit.piece, ShopCategory.produce),
      _onion,
      _DemoIngredient('Chiliflocken', 'Chili flakes', 1, QtyUnit.tsp, ShopCategory.pantry, staple: true),
      _oil,
      _salt,
    ],
    stepsDe: <String>[
      'Zwiebel und Paprika würfeln und im Öl 5 Minuten anbraten.',
      'Bohnen, Tomaten und Chili dazugeben und 20 Minuten bei kleiner Hitze köcheln lassen.',
      'Mit Salz abschmecken.',
    ],
    stepsEn: <String>[
      'Dice the onion and the pepper and fry them in the oil for 5 minutes.',
      'Add the beans, the tomatoes and the chili and simmer over low heat for 20 minutes.',
      'Season with salt.',
    ],
  ),
  _DemoMeal(
    de: 'Shakshuka',
    en: 'Shakshuka',
    kcal: 450,
    protein: 25,
    minutes: 25,
    level: CookingLevel.everyday,
    ingredients: <_DemoIngredient>[
      _DemoIngredient('Eier', 'Eggs', 4, QtyUnit.piece, ShopCategory.dairy),
      _DemoIngredient('Gehackte Tomaten (Dose)', 'Chopped tomatoes (can)', 400, QtyUnit.g, ShopCategory.pantry),
      _DemoIngredient('Paprika', 'Peppers', 1, QtyUnit.piece, ShopCategory.produce),
      _onion,
      _DemoIngredient('Kreuzkümmel', 'Cumin', 1, QtyUnit.tsp, ShopCategory.pantry, staple: true),
      _oil,
      _salt,
    ],
    stepsDe: <String>[
      'Zwiebel und Paprika in Streifen schneiden und im Öl mit dem Kreuzkümmel 5 Minuten anbraten.',
      'Die Tomaten dazugeben, salzen und 10 Minuten einkochen.',
      'Vier Mulden formen, die Eier hineinschlagen und zugedeckt 6 Minuten stocken lassen.',
    ],
    stepsEn: <String>[
      'Slice the onion and the pepper and fry them in the oil with the cumin for 5 minutes.',
      'Add the tomatoes, salt and reduce for 10 minutes.',
      'Make four hollows, crack the eggs into them and let them set under a lid for 6 minutes.',
    ],
  ),
];
