import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

const BodyProfile _body = BodyProfile(
  sex: BiologicalSex.male,
  ageYears: 30,
  heightCm: 180,
  weightKg: 85,
  activityLevel: ActivityLevel.moderate,
);

void main() {
  group('nutrition', () {
    test('Mifflin-St Jeor matches the published formula', () {
      // 10*85 + 6.25*180 - 5*30 + 5 = 1830
      expect(basalMetabolicRate(_body), 1830);
    });

    test('subtracts 161 instead of adding 5 for female profiles', () {
      final female = _body.copyWith(sex: BiologicalSex.female);
      expect(basalMetabolicRate(female), 1830 - 5 - 161);
    });

    test('a mindset goal is flagged as not driven by nutrition', () {
      final plan = buildNutritionPlan(const Goal(
        archetype: GoalArchetype.clarity,
        statement: 'x',
        body: _body,
      ));

      expect(plan.strategy, NutritionStrategy.maintenance);
      expect(plan.goalDrivesNutrition, isFalse);
    });

    test('a fat-loss goal produces a deficit and high protein', () {
      final plan = buildNutritionPlan(const Goal(
        archetype: GoalArchetype.loseFat,
        statement: '8 kg runter',
        body: _body,
      ));

      expect(plan.kcal, lessThan(plan.tdee));
      expect(plan.strategy, NutritionStrategy.deficit);
      expect(plan.deltaPercent, 20);
      expect(plan.proteinG, (85 * 2.2).round());
      expect(plan.weeklyWeightChangeKg, lessThan(0));
    });

    test('a muscle goal produces a modest surplus', () {
      final plan = buildNutritionPlan(const Goal(
        archetype: GoalArchetype.buildMuscle,
        statement: 'Masse aufbauen',
        body: _body,
      ));

      expect(plan.kcal, greaterThan(plan.tdee));
      expect(plan.strategy, NutritionStrategy.surplus);
      expect(plan.kcal - plan.tdee, lessThan(plan.tdee * 0.2));
    });

    test('never prescribes a starvation floor', () {
      final tiny = _body.copyWith(
        sex: BiologicalSex.female,
        weightKg: 45,
        heightCm: 150,
        ageYears: 60,
        activityLevel: ActivityLevel.sedentary,
      );
      final plan = buildNutritionPlan(Goal(
        archetype: GoalArchetype.loseFat,
        statement: 'abnehmen',
        body: tiny,
      ));

      expect(plan.kcal, greaterThanOrEqualTo(1300));
    });

    test('macros add up to the calorie target', () {
      final plan = buildNutritionPlan(const Goal(
        archetype: GoalArchetype.loseFat,
        statement: 'x',
        body: _body,
      ));
      final fromMacros =
          plan.proteinG * 4 + plan.carbsG * 4 + plan.fatG * 9;

      expect((fromMacros - plan.kcal).abs(), lessThan(20));
    });

    test('every meal slot appears exactly once', () {
      final plan = buildNutritionPlan(const Goal(
        archetype: GoalArchetype.getFit,
        statement: 'x',
        body: _body,
      ));

      expect(
        plan.meals.map((MealSlot m) => m.kind),
        MealSlotKind.values,
      );
    });

    test('meal shares sum to the whole day', () {
      final plan = buildNutritionPlan(const Goal(
        archetype: GoalArchetype.getFit,
        statement: 'x',
        body: _body,
      ));
      final shares =
          plan.meals.fold<double>(0, (double a, MealSlot m) => a + m.share);

      expect(shares, closeTo(1.0, 0.001));
    });

    test('refuses to guess without body stats', () {
      expect(
        () => buildNutritionPlan(
            const Goal(archetype: GoalArchetype.loseFat, statement: 'x')),
        throwsArgumentError,
      );
    });
  });

  group('training', () {
    test('a four-day week produces an upper/lower split', () {
      final plan = buildTrainingPlan(const Goal(
        archetype: GoalArchetype.buildMuscle,
        statement: 'x',
        trainingDaysPerWeek: 4,
      ));

      expect(plan.split, SplitKind.upperLower);
      expect(plan.weeks.first.workouts, hasLength(4));
    });

    test('every fourth week is a deload with less volume', () {
      final plan = buildTrainingPlan(const Goal(
        archetype: GoalArchetype.buildMuscle,
        statement: 'x',
        experience: TrainingExperience.intermediate,
      ));

      expect(plan.weeks[3].isDeload, isTrue);
      expect(plan.weeks[3].weekInBlock, 4);
      expect(plan.weeks[3].blockNumber, 1);
      expect(plan.weeks[7].isDeload, isTrue);
      expect(plan.weeks[7].blockNumber, 2);
      expect(
        plan.weeks[3].workouts.first.totalSets,
        lessThan(plan.weeks[2].workouts.first.totalSets),
      );
    });

    test('volume climbs across an accumulation block', () {
      final plan = buildTrainingPlan(const Goal(
        archetype: GoalArchetype.buildMuscle,
        statement: 'x',
      ));

      final week1 = plan.weeks[0].workouts.first.totalSets;
      final week3 = plan.weeks[2].workouts.first.totalSets;
      expect(week3, greaterThan(week1));
    });

    test('a bodyweight user only gets bodyweight exercises', () {
      final plan = buildTrainingPlan(const Goal(
        archetype: GoalArchetype.getFit,
        statement: 'x',
        equipment: EquipmentAccess.bodyweight,
      ));

      for (final TrainingWeek week in plan.weeks) {
        for (final Workout workout in week.workouts) {
          for (final PlannedSet block in workout.blocks) {
            expect(
              block.exercise.minEquipment,
              EquipmentAccess.bodyweight,
              reason: '${block.exerciseId} needs equipment',
            );
          }
        }
      }
    });

    test('no session repeats the same exercise twice', () {
      final plan = buildTrainingPlan(const Goal(
        archetype: GoalArchetype.buildMuscle,
        statement: 'x',
        trainingDaysPerWeek: 6,
      ));

      for (final Workout workout in plan.weeks.first.workouts) {
        final ids = workout.blocks.map((PlannedSet b) => b.exerciseId).toList();
        expect(ids.toSet(), hasLength(ids.length));
      }
    });

    test('finds the workout for a given calendar day', () {
      final start = DayKey(2026, 3, 2); // Monday
      final plan = buildTrainingPlan(const Goal(
        archetype: GoalArchetype.buildMuscle,
        statement: 'x',
        trainingDaysPerWeek: 3,
      ));

      expect(plan.workoutFor(start, start), isNotNull);
      expect(plan.workoutFor(start, start.addDays(1)), isNull); // Tuesday
      expect(plan.workoutFor(start, start.addDays(2)), isNotNull); // Wednesday
    });
  });

  group('buildPlan', () {
    test('a pure abstinence challenge gets neither sub-plan', () {
      final plan = buildPlan(Challenge(
        id: 'c',
        goal: const Goal(
          archetype: GoalArchetype.clarity,
          statement: 'Kopf frei',
        ),
        habits: <Habit>[
          Habit.fromCategory(HabitCategory.noFap),
          Habit.fromCategory(HabitCategory.dopamineDetox),
        ],
        startDay: DayKey(2026, 3, 2),
      ));

      expect(plan.hasTraining, isFalse);
      expect(plan.hasNutrition, isFalse);
    });

    test('a gym plus nutrition challenge gets both', () {
      final plan = buildPlan(Challenge(
        id: 'c',
        goal: const Goal(
          archetype: GoalArchetype.buildMuscle,
          statement: 'Masse',
          body: _body,
        ),
        habits: <Habit>[
          Habit.fromCategory(HabitCategory.gym),
          Habit.fromCategory(HabitCategory.nutrition),
        ],
        startDay: DayKey(2026, 3, 2),
      ));

      expect(plan.hasTraining, isTrue);
      expect(plan.hasNutrition, isTrue);
    });
  });

  group('abstinence milestones', () {
    test('reports the milestone just passed and the next one', () {
      expect(currentMilestone(HabitCategory.noAlcohol, 8)!.day, 7);
      expect(currentMilestone(HabitCategory.noAlcohol, 8)!.id, 'alcohol_7');
      expect(nextMilestone(HabitCategory.noAlcohol, 8)!.day, 14);
    });

    test('maps each abstinence habit to its own track', () {
      expect(trackFor(HabitCategory.noFap), AbstinenceTrack.noFap);
      expect(trackFor(HabitCategory.reading), AbstinenceTrack.generic);
    });

    test('has no current milestone on day zero', () {
      expect(currentMilestone(HabitCategory.noFap, 0), isNull);
    });

    test('falls back to generic milestones for unlisted habits', () {
      expect(milestonesFor(HabitCategory.reading), isNotEmpty);
    });
  });
}
