import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/barcode_lookup.dart';

import 'helpers.dart';

const BodyProfile _body = BodyProfile(
  sex: BiologicalSex.male,
  ageYears: 31,
  heightCm: 182,
  weightKg: 84,
  activityLevel: ActivityLevel.moderate,
);

void main() {
  group('barcode lookup', () {
    test('reads an Open Food Facts product', () {
      final BarcodeProduct product = BarcodeLookup.parse('4008400401621', <String, dynamic>{
        'status': 1,
        'product': <String, dynamic>{
          'product_name': 'Haferflocken kernig',
          'brands': 'Kölln, Peter Kölln',
          'serving_quantity': '40',
          'nutriments': <String, dynamic>{
            'energy-kcal_100g': 372,
            'proteins_100g': 13.5,
            'carbohydrates_100g': 58.7,
            'fat_100g': 7,
          },
        },
      });
      expect(product.displayName, 'Haferflocken kernig (Kölln)');
      expect(product.per100g.kcal, 372);
      expect(product.servingG, 40);
    });

    test('falls back to kilojoules and refuses a product without values', () {
      final BarcodeProduct kj = BarcodeLookup.parse('12345678', <String, dynamic>{
        'product': <String, dynamic>{
          'product_name': 'Saft',
          'nutriments': <String, dynamic>{'energy-kj_100g': 188.3},
        },
      });
      expect(kj.per100g.kcal, closeTo(45, 0.1));
      expect(
        () => BarcodeLookup.parse('12345678', <String, dynamic>{'status': 0}),
        throwsA(isA<BarcodeLookupException>()),
      );
      expect(BarcodeLookup.isValid('4008400401621'), isTrue);
      expect(BarcodeLookup.isValid('12ab'), isFalse);
    });
  });

  group('privacy on the wire', () {
    test('friends get neither body stats nor private habits', () async {
      final repository = await testRepository();
      final Challenge challenge = Challenge(
        id: 'c',
        goal: const Goal(
          archetype: GoalArchetype.loseFat,
          statement: '8 kg runter',
          body: _body,
          nutrition: NutritionGoals(kcalTarget: 2100),
        ),
        habits: <Habit>[
          Habit.fromCategory(HabitCategory.noFap),
          Habit.fromCategory(HabitCategory.nutrition),
        ],
        startDay: DayKey.today(),
        sharing: const SharingPrefs(privateHabits: <String>{'noFap'}),
      );
      await repository.startChallenge(challenge);
      await repository.checkIn(
        habit: challenge.habits.first,
        day: DayKey.today(),
        challenge: challenge,
      );
      await repository.logFood(FoodEntry(
        id: 'f1',
        day: DayKey.today(),
        meal: MealSlotKind.lunch,
        name: 'Currywurst',
        grams: 200,
        nutrients: kFoodById['currywurst']!.forGrams(200),
        source: FoodSource.database,
      ));

      final List<FeedEvent> raw =
          await repository.store.eventsOf(repository.userId);
      // Everything a friend can read: what the server's row level security
      // hands them — the events visible to friends.
      final List<FeedEvent> shared = raw
          .where((FeedEvent e) => e.visibility == EventVisibility.friends)
          .toList();
      final String wire =
          shared.map((FeedEvent e) => jsonEncode(e.payload)).join();
      expect(wire, isNot(contains('weightKg')), reason: 'body stats leaked');
      expect(wire, isNot(contains('noFap')), reason: 'private habit leaked');
      expect(wire, isNot(contains('Currywurst')), reason: 'diary leaked');
      expect(wire, isNot(contains('"preset"')), reason: 'targets leaked');
      // What a friend's device computes from those events.
      final UserProjection asFriend = projectUser(repository.userId, shared);
      expect(asFriend.challenge!.habits.map((Habit h) => h.id),
          <String>['nutrition']);
      expect(asFriend.foodByDay, isEmpty);

      // And what the owner sees.
      final AppSnapshot mine = await repository.snapshot();
      expect(mine.challenge!.goal.body!.weightKg, 84);
      expect(mine.me.intakeOn(DayKey.today()).entries.single.name, 'Currywurst');
      expect(mine.me.logsByDay[DayKey.today().toString()]!.entries.single.habitId,
          'noFap');
      expect(mine.plan!.nutrition!.kcal, 2100);

      // The private check-in earns XP at home, but the league ranks by what
      // friends can verify — the same number on every device.
      expect(mine.me.lifetimeXp, greaterThan(0));
      expect(
        mine.league.entries
            .firstWhere((LeagueEntry e) => e.userId == repository.userId)
            .weeklyXp,
        0,
      );
    });
  });
}
