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

  final wantsTraining = categories.contains(HabitCategory.gym) ||
      categories.contains(HabitCategory.cardio);
  final wantsNutrition = categories.contains(HabitCategory.nutrition) &&
      goal.body != null;

  return ChallengePlan(
    generatedAt: DateTime.now(),
    training: wantsTraining ? buildTrainingPlan(goal) : null,
    nutrition: wantsNutrition ? buildNutritionPlan(goal) : null,
  );
}
