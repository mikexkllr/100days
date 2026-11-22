import 'package:meta/meta.dart';

import '../domain/challenge.dart';
import '../domain/habit.dart';
import '../util/dates.dart';
import 'nutrition.dart';
import 'training.dart';

/// Everything the on-device planner produced for one challenge.
///
/// Both sub-plans are optional: someone doing a pure dopamine detox gets
/// neither, and the app must not pretend otherwise.
@immutable
class ChallengePlan {
  const ChallengePlan({
    required this.generatedAt,
    this.training,
    this.nutrition,
  });

  final DateTime generatedAt;
  final TrainingPlan? training;
  final NutritionPlan? nutrition;

  bool get hasTraining => training != null;

  bool get hasNutrition => nutrition != null;

  Workout? workoutFor(DayKey startDay, DayKey day) =>
      training?.workoutFor(startDay, day);
}

/// Generates the plan for a challenge, entirely on device.
///
/// This is deliberately deterministic rather than model-driven: a plan you can
/// recompute from the same inputs is a plan you can trust, and it works on a
/// phone in a basement gym with no signal. The [CoachEngine] layer on top is
/// where an on-device LLM adds language and adaptation.
ChallengePlan buildPlan(Challenge challenge) {
  final goal = challenge.goal;
  final categories =
      challenge.habits.map((Habit h) => h.category).toSet();

  // Both plans are opt-in: without them the habit is a plain tick.
  final wantsTraining = goal.trainingPlanEnabled &&
      (categories.contains(HabitCategory.gym) ||
          categories.contains(HabitCategory.cardio));
  final wantsNutrition = goal.nutritionPlanEnabled &&
      categories.contains(HabitCategory.nutrition) &&
      goal.body != null;

  return ChallengePlan(
    generatedAt: DateTime.now(),
    training: wantsTraining
        ? buildTrainingPlan(
            goal,
            startWeekday: challenge.startDay.toDateTime().weekday,
          )
        : null,
    nutrition: wantsNutrition ? buildNutritionPlan(goal) : null,
  );
}

/// The habit a logged workout checks in, and so the one whose weekly days
/// the training plan sets: the gym habit, or cardio for a challenge without
/// one. The two must agree, or the workout card shows up on days the habit
/// does not expect it.
Habit? trainingHabitOf(Iterable<Habit> habits) {
  Habit? cardio;
  for (final habit in habits) {
    if (habit.category == HabitCategory.gym) return habit;
    if (habit.category == HabitCategory.cardio) cardio ??= habit;
  }
  return cardio;
}
