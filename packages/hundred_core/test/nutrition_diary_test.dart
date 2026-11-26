import 'dart:async';
import 'dart:typed_data';

import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

const BodyProfile _body = BodyProfile(
  sex: BiologicalSex.male,
  ageYears: 30,
  heightCm: 180,
  weightKg: 80,
  activityLevel: ActivityLevel.moderate,
);

Goal _goal({NutritionGoals? nutrition}) => Goal(
      archetype: GoalArchetype.loseFat,
      statement: '8 kg runter',
      body: _body,
      nutrition: nutrition,
    );

/// A tiny English vocabulary, standing in for the one the app supplies.
const FoodVocabulary _english = FoodVocabulary(
  numberWords: <String, double>{
    'a': 1,
    'an': 1,
    'one': 1,
    'two': 2,
    'half': 0.5,
    'couple': 2,
  },
  unitWords: <String, FoodUnit>{
    'g': FoodUnit.grams,
    'ml': FoodUnit.millilitres,
    'l': FoodUnit.litres,
    'slice': FoodUnit.slice,
    'slices': FoodUnit.slice,
    'tbsp': FoodUnit.tablespoon,
    'cup': FoodUnit.cup,
    'pcs': FoodUnit.piece,
  },
  separators: <String>['and', 'with', 'then', 'after that'],
  fillerWords: <String>{'of', 'i', 'had', 'approx'},
);

FoodItem? _lookup(String phrase) {
  const names = <String, String>{
    'egg': 'egg',
    'eggs': 'egg',
    'toast': 'toast',
    'coffee': 'coffee',
    'milk': 'milk',
    'chicken breast': 'chicken_breast',
    'banana': 'banana',
    'bananas': 'banana',
    'olive oil': 'olive_oil',
    'avocado': 'avocado',
    'rice': 'rice',
    'pizza': 'pizza',
    'sushi': 'sushi',
    'milk chocolate': 'milk_chocolate',
  };
  final id = names[phrase];
  return id == null ? null : kFoodById[id];
}

class _FakeRuntime implements LlmClient {
  _FakeRuntime(this.response);

  final String response;
  Duration? lastTimeout;
  List<LlmImage> lastImages = const <LlmImage>[];

  @override
  String get modelName => 'fake';

  @override
  bool get isReady => true;

  @override
  Future<String> generate(
    String prompt, {
    List<LlmImage> images = const <LlmImage>[],
    LlmPurpose purpose = LlmPurpose.food,
    int maxTokens = 400,
    double temperature = 0.7,
    Duration timeout = const Duration(seconds: 30),
    bool json = false,
  }) async {
    lastTimeout = timeout;
    lastImages = images;
    return response;
  }
}

void main() {
  group('own nutrition targets', () {
    test('a custom calorie target wins and keeps the suggestion visible', () {
      final computed = buildNutritionPlan(_goal());
      final plan = buildNutritionPlan(
          _goal(nutrition: const NutritionGoals(kcalTarget: 2000)));
      expect(plan.kcal, 2000);
      expect(plan.suggestedKcal, computed.kcal);
      expect(plan.isCustomTarget, isTrue);
      expect(plan.strategy, NutritionStrategy.deficit);
    });

    test('a target equal to maintenance reads as maintenance', () {
      final tdee = buildNutritionPlan(_goal()).tdee;
      final plan =
          buildNutritionPlan(_goal(nutrition: NutritionGoals(kcalTarget: tdee)));
      expect(plan.strategy, NutritionStrategy.maintenance);
      expect(plan.deltaPercent, 0);
    });

    test('an absurd target is clamped into the safe range', () {
      final plan = buildNutritionPlan(
          _goal(nutrition: const NutritionGoals(kcalTarget: 400)));
      expect(plan.kcal, kMinCustomKcal);
    });

    test('every macro preset adds up to the calorie target', () {
      for (final MacroPreset preset in MacroPreset.values) {
        final plan = buildNutritionPlan(_goal(
          nutrition: NutritionGoals(
            kcalTarget: 2200,
            preset: preset,
            proteinPercent: 30,
            carbsPercent: 40,
            fatPercent: 30,
          ),
        ));
        final fromMacros =
            plan.proteinG * 4 + plan.carbsG * 4 + plan.fatG * 9;
        expect((fromMacros - plan.kcal).abs(), lessThan(40),
            reason: preset.name);
      }
    });

    test('custom percentages that do not add up are normalised', () {
      const goals = NutritionGoals(
        preset: MacroPreset.custom,
        proteinPercent: 30,
        carbsPercent: 40,
        fatPercent: 29,
      );
      final p = goals.percentages!;
      expect(p.protein + p.carbs + p.fat, 100);
    });

    test('nutrition goals survive the goal JSON', () {
      final goal = Goal.fromJson(_goal(
        nutrition: const NutritionGoals(
          kcalTarget: 2100,
          preset: MacroPreset.highProtein,
        ),
      ).toJson());
      expect(goal.nutrition!.kcalTarget, 2100);
      expect(goal.nutrition!.preset, MacroPreset.highProtein);
    });

    test('a challenge without the nutrition plan gets no nutrition plan', () {
      final challenge = Challenge(
        id: 'c',
        goal: _goal().copyWith(nutritionPlanEnabled: false),
        habits: <Habit>[Habit.fromCategory(HabitCategory.nutrition)],
        startDay: DayKey.today(),
      );
      expect(buildPlan(challenge).hasNutrition, isFalse);
    });
  });

  group('macros', () {
    test('add up to their calories, 4 / 4 / 9 per gram', () {
      const Nutrients n =
          Nutrients(kcal: 0, proteinG: 30, carbsG: 50, fatG: 10);
      expect(n.kcalFromMacros, 30 * 4 + 50 * 4 + 10 * 9);
      expect(Nutrients.zero.kcalFromMacros, 0);
    });
  });

  group('food table', () {
    test('ids are unique and values are plausible', () {
      expect(kFoodById, hasLength(kFoodLibrary.length));
      // Alcohol has energy of its own (7 kcal/g) that no macro accounts for.
      const alcoholic = <String>{'beer', 'wine'};
      for (final FoodItem food in kFoodLibrary) {
        if (alcoholic.contains(food.id)) continue;
        final fromMacros = food.proteinG * 4 + food.carbsG * 4 + food.fatG * 9;
        // Alcohol and fibre make labels drift from the 4/4/9 rule; anything
        // further off than this is a typo.
        expect(food.kcal, lessThanOrEqualTo(900), reason: food.id);
        expect((fromMacros - food.kcal).abs(), lessThan(food.kcal * 0.35 + 25),
            reason: food.id);
        expect(food.portionG, greaterThan(0), reason: food.id);
      }
    });
  });

  group('free-text parser', () {
    test('reads amounts, pieces and slices', () {
      final items = parseFoodText(
        'I had 2 eggs, 2 slices of toast and coffee with milk',
        vocabulary: _english,
        lookup: _lookup,
      );
      expect(items.map((ParsedFood p) => p.food?.id),
          <String?>['egg', 'toast', 'coffee', 'milk']);
      expect(items[0].unit, FoodUnit.piece);
      expect(items[0].grams, 110);
      expect(items[1].grams, 50);
      expect(items[2].unit, FoodUnit.portion);
    });

    test('a glued unit and a trailing amount both work', () {
      final items = parseFoodText(
        '200g chicken breast + banana 150 g',
        vocabulary: _english,
        lookup: _lookup,
      );
      expect(items[0].grams, 200);
      expect(items[0].nutrients!.proteinG, closeTo(62, 0.1));
      expect(items[1].food!.id, 'banana');
      expect(items[1].grams, 150);
    });

    test('a decimal comma is not a list comma', () {
      final items = parseFoodText(
        '1,5 l milk',
        vocabulary: _english,
        lookup: _lookup,
      );
      expect(items.single.grams, 1500);
    });

    test('tablespoons resolve without knowing the food', () {
      final items = parseFoodText(
        'one tbsp olive oil',
        vocabulary: _english,
        lookup: _lookup,
      );
      expect(items.single.grams, 15);
      expect(items.single.nutrients!.kcal, closeTo(132.6, 0.1));
    });

    test('an unknown food comes back unrecognised instead of guessed', () {
      final items = parseFoodText(
        '2 dragonfruit smoothies',
        vocabulary: _english,
        lookup: _lookup,
      );
      expect(items.single.food, isNull);
      expect(items.single.isRecognised, isFalse);
      expect(items.single.phrase, 'dragonfruit smoothies');
    });

    ParsedFood one(String text) => parseFoodText(
          text,
          vocabulary: _english,
          lookup: _lookup,
        ).single;

    test('fractions are amounts, not a number and a stray word', () {
      // Half an avocado (a piece is 150 g), not a whole one.
      expect(one('1/2 avocado').amount, 0.5);
      expect(one('1/2 avocado').grams, 75);
      expect(one('1/2avocado').grams, 75);
      // Three quarters of a cup, not three cups.
      expect(one('3/4 cup rice').amount, 0.75);
      expect(one('3/4 cup rice').grams, 150);
      expect(one('½ avocado').grams, 75);
      expect(one('1½ bananas').amount, 1.5);
      expect(one('1 1/2 bananas').amount, 1.5);
      expect(one('1 1/2 bananas').grams, 180);
    });

    test('number words in a row make one amount', () {
      expect(one('half a pizza').amount, 0.5);
      expect(one('a half pizza').grams, 175);
      expect(one('a couple of eggs').amount, 2);
      expect(one('a couple of eggs').unit, FoodUnit.piece);
    });

    test('a count of a countable food is pieces, a weight stays grams', () {
      // 12 pieces of sushi, not 12 g.
      final sushi = one('12 sushi');
      expect(sushi.unit, FoodUnit.piece);
      expect(sushi.grams, 360);
      // 150 bananas would be 18 kg: that is grams.
      expect(one('150 bananas').unit, FoodUnit.grams);
      expect(one('banana 150').grams, 150);
      // 100 of a 6 g square is a bar's weight, not 100 squares.
      expect(one('100 milk chocolate').grams, 100);
      expect(one('2 eggs').unit, FoodUnit.piece);
    });

    test('a sentence end and "then" end an item', () {
      for (final String text in <String>[
        '2 eggs. Then a banana',
        '2 eggs and then a banana',
        '2 eggs! After that a banana',
        '2 eggs then a banana.',
      ]) {
        final items = parseFoodText(text, vocabulary: _english, lookup: _lookup);
        expect(items.map((ParsedFood p) => p.food?.id), <String>['egg', 'banana'],
            reason: text);
        expect(items[0].amount, 2, reason: text);
        expect(items[1].amount, 1, reason: text);
      }
      // A dot after an abbreviation the vocabulary knows, or inside a
      // number, is no sentence end.
      final items = parseFoodText('approx. 1.5 l milk, 2 pcs. bananas',
          vocabulary: _english, lookup: _lookup);
      expect(items.map((ParsedFood p) => p.grams), <double>[1500, 240]);
    });
  });

  group('meal suggestions', () {
    test('ranks ideas by fit and respects the diet', () {
      final ideas = suggestMeals(
        slot: MealSlotKind.lunch,
        targetKcal: 600,
        targetProteinG: 45,
      );
      expect(ideas.first.id, 'lunch1');
      final vegan = suggestMeals(
        slot: MealSlotKind.lunch,
        targetKcal: 600,
        targetProteinG: 30,
        diet: FoodDiet.vegan,
      );
      expect(vegan.every((MealIdea m) => m.diet == FoodDiet.vegan), isTrue);
      expect(vegan, isNotEmpty);
    });

    test('suggests nothing when the day is already full', () {
      expect(
        suggestMeals(
            slot: MealSlotKind.dinner, targetKcal: 50, targetProteinG: 10),
        isEmpty,
      );
    });
  });

  group('diary', () {
    test('a day on target is within ten percent of the plan', () {
      final plan = buildNutritionPlan(
          _goal(nutrition: const NutritionGoals(kcalTarget: 2000)));
      FoodEntry entry(double kcal) => FoodEntry(
            id: 'e$kcal',
            day: DayKey.parse('2026-11-02'),
            meal: MealSlotKind.lunch,
            name: 'x',
            grams: 100,
            nutrients:
                Nutrients(kcal: kcal, proteinG: 0, carbsG: 0, fatG: 0),
            source: FoodSource.manual,
          );
      final day = DayKey.parse('2026-11-02');
      expect(DayIntake(day: day, entries: <FoodEntry>[entry(1900)])
          .isOnTarget(plan), isTrue);
      expect(DayIntake(day: day, entries: <FoodEntry>[entry(1500)])
          .isOnTarget(plan), isFalse);
      expect(DayIntake(day: day, entries: const <FoodEntry>[]).isOnTarget(plan),
          isFalse);
    });

    test('an entry round-trips through its payload', () {
      final entry = FoodEntry(
        id: 'abc',
        day: DayKey.parse('2026-11-02'),
        meal: MealSlotKind.breakfast,
        name: 'Skyr',
        grams: 150,
        nutrients: kFoodById['skyr']!.forGrams(150),
        source: FoodSource.barcode,
        barcode: '4001234567890',
      );
      final copy = FoodEntry.fromPayload(entry.toPayload());
      expect(copy.meal, MealSlotKind.breakfast);
      expect(copy.nutrients.kcal, closeTo(95, 0.6));
      expect(copy.source, FoodSource.barcode);
      expect(copy.barcode, '4001234567890');
    });

    test('a corrected entry keeps its id and scales its macros', () {
      final estimate = FoodEntry(
        id: 'photo-1',
        day: DayKey.parse('2026-11-02'),
        meal: MealSlotKind.dinner,
        name: 'Lasagne',
        grams: 400,
        nutrients: const Nutrients(kcal: 600, proteinG: 32, carbsG: 52, fatG: 28),
        source: FoodSource.photo,
      );
      // Half of it, the calories as the amount says.
      final half = estimate.corrected(grams: 200, kcal: 300);
      expect(half.id, 'photo-1');
      expect(half.source, FoodSource.photo);
      expect(half.nutrients.proteinG, 16);
      // The amount was right, the estimate too low.
      final more = estimate.corrected(grams: 400, kcal: 750);
      expect(more.nutrients.fatG, 35);
      expect(more.grams, 400);
      // A line without calories to go by follows its amount.
      expect(
          correctNutrients(const Nutrients(kcal: 0, proteinG: 10, carbsG: 0, fatG: 0),
                  fromGrams: 100, toGrams: 200, kcal: 0)
              .proteinG,
          20);
    });
  });

  group('nutrition assistant', () {
    test('reads JSON wrapped in prose', () async {
      final assistant = NutritionAssistant(
        llm: _FakeRuntime('Sure! Here you go:\n```json\n'
            '[{"name":"Porridge","grams":300,"kcal":320,"protein":12,'
            '"carbs":50,"fat":7}]\n```'),
      );
      final result = await assistant.estimateFoods('porridge');
      expect(result!.single.name, 'Porridge');
      expect(result.single.nutrients.kcal, 320);
    });

    test('gives the runtime the whole time budget, not its default', () async {
      final runtime = _FakeRuntime(
          '{"foods":[{"name":"Rührei","grams":120,"kcal":180}]}');
      await NutritionAssistant(
        llm: runtime,
        timeout: const Duration(seconds: 45),
      ).estimateFoods('Rührei');
      expect(runtime.lastTimeout, const Duration(seconds: 45));
    });

    test('reads every shape a model answers in', () async {
      for (final String answer in <String>[
        '{"foods":[{"name":"Rührei","grams":120,"kcal":180,"protein":12}]}',
        '{"name":"Rührei","grams":120,"kcal":180,"protein":12}',
        '[{"name":"Rührei","grams":120,"kcal":180,"protein":12}]',
      ]) {
        final result = await NutritionAssistant(llm: _FakeRuntime(answer))
            .estimateFoods('Rührei');
        expect(result!.single.name, 'Rührei', reason: answer);
        expect(result.single.nutrients.proteinG, 12, reason: answer);
      }
    });

    test('drops estimates that break physics', () async {
      final assistant = NutritionAssistant(
        llm: _FakeRuntime(
            '[{"name":"Apple","grams":100,"kcal":5000,"protein":0}]'),
      );
      expect(await assistant.estimateFoods('apple'), isNull);
    });

    test('a meal photo goes to the model with the photo attached', () async {
      final runtime = _FakeRuntime('{"foods":[{"name":"Spaghetti Bolognese",'
          '"grams":420,"kcal":610,"protein":28,"carbs":78,"fat":19}]}');
      final photo = LlmImage(bytes: Uint8List.fromList(<int>[0xff, 0xd8, 1]));
      final result = await NutritionAssistant(llm: runtime)
          .estimateFoodsFromPhoto(photo, hint: 'nur die Hälfte');
      expect(result!.single.name, 'Spaghetti Bolognese');
      expect(result.single.grams, 420);
      expect(runtime.lastImages.single.mimeType, 'image/jpeg');
    });

    test('a photo estimate gets the same physics check', () async {
      final result = await NutritionAssistant(
        llm: _FakeRuntime('{"foods":[{"name":"Salat","grams":50,"kcal":2000},'
            '{"name":"Brot","grams":60,"kcal":150}]}'),
      ).estimateFoodsFromPhoto(
          LlmImage(bytes: Uint8List.fromList(<int>[1, 2, 3])));
      expect(result!.map((FoodEstimate e) => e.name), <String>['Brot']);
    });

    test('a photo without food or without bytes yields nothing', () async {
      final empty = await NutritionAssistant(llm: _FakeRuntime('{"foods":[]}'))
          .estimateFoodsFromPhoto(LlmImage(bytes: Uint8List.fromList(<int>[1])));
      expect(empty, isNull);
      final noBytes = await NutritionAssistant(llm: _FakeRuntime('{}'))
          .estimateFoodsFromPhoto(LlmImage(bytes: Uint8List(0)));
      expect(noBytes, isNull);
    });

    test('the photo prompt carries the hint and the JSON shape', () {
      const prompts = EnglishNutritionPrompts();
      expect(prompts.estimateFoodsFromPhoto('with oat milk'),
          contains('with oat milk'));
      expect(prompts.estimateFoodsFromPhoto(null), contains(kFoodEstimateJson));
    });

    test('a proposal below the guard rail is refused', () async {
      final plan = buildNutritionPlan(_goal());
      final assistant = NutritionAssistant(
        llm: _FakeRuntime(
            '{"kcal":1000,"protein_pct":40,"carbs_pct":30,"fat_pct":30}'),
      );
      expect(await assistant.adjustTargets(plan: plan, wish: 'fast'), isNull);
    });

    test('a sensible proposal becomes custom goals', () async {
      final plan = buildNutritionPlan(_goal());
      final assistant = NutritionAssistant(
        llm: _FakeRuntime('{"kcal":${plan.kcal - 100},"protein_pct":35,'
            '"carbs_pct":30,"fat_pct":35,"reason":"Less carbs."}'),
      );
      final proposal =
          await assistant.adjustTargets(plan: plan, wish: 'less carbs');
      expect(proposal!.reason, 'Less carbs.');
      final goals = proposal.toGoals();
      expect(goals.preset, MacroPreset.custom);
      expect(goals.percentages!.carbs, 30);
    });

    test('a hanging model times out to null', () async {
      final assistant = NutritionAssistant(
        llm: _HangingRuntime(),
        timeout: const Duration(milliseconds: 20),
      );
      expect(await assistant.estimateFoods('x'), isNull);
    });

    test('a failed call is told apart from an answer that held nothing',
        () async {
      final List<Object> errors = <Object>[];
      final offline = NutritionAssistant(llm: _FailingRuntime());
      expect(await offline.estimateFoods('Rührei', onError: errors.add), isNull);
      expect(
          await offline.estimateFoodsFromPhoto(
              LlmImage(bytes: Uint8List.fromList(<int>[1])),
              onError: errors.add),
          isNull);
      expect(
          await offline.adjustTargets(
              plan: buildNutritionPlan(_goal()), wish: 'less', onError: errors.add),
          isNull);
      expect(errors, hasLength(3));
      expect(errors.first, isA<StateError>());

      // A timeout is a failed call too.
      errors.clear();
      await NutritionAssistant(
        llm: _HangingRuntime(),
        timeout: const Duration(milliseconds: 20),
      ).estimateFoods('x', onError: errors.add);
      expect(errors.single, isA<TimeoutException>());

      // Nonsense from the model is not.
      errors.clear();
      expect(
          await NutritionAssistant(llm: _FakeRuntime('no idea'))
              .estimateFoods('x', onError: errors.add),
          isNull);
      expect(errors, isEmpty);
    });
  });
}

class _FailingRuntime extends _FakeRuntime {
  _FailingRuntime() : super('');

  @override
  Future<String> generate(
    String prompt, {
    List<LlmImage> images = const <LlmImage>[],
    LlmPurpose purpose = LlmPurpose.food,
    int maxTokens = 400,
    double temperature = 0.7,
    Duration timeout = const Duration(seconds: 30),
    bool json = false,
  }) async =>
      throw StateError('no network');
}

class _HangingRuntime extends _FakeRuntime {
  _HangingRuntime() : super('');

  @override
  Future<String> generate(
    String prompt, {
    List<LlmImage> images = const <LlmImage>[],
    LlmPurpose purpose = LlmPurpose.food,
    int maxTokens = 400,
    double temperature = 0.7,
    Duration timeout = const Duration(seconds: 30),
    bool json = false,
  }) =>
      Completer<String>().future;
}
