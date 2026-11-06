import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

/// The half-finished challenge while the user is still setting it up.
///
/// Kept out of the feed on purpose: an abandoned onboarding should leave no
/// trace, and the first event on a user's permanent, replicated log should be
/// a challenge they actually committed to.
class OnboardingDraft {
  const OnboardingDraft({
    this.archetype,
    this.statement = '',
    this.selectedHabits = const <HabitCategory>{},
    this.habitTargets = const <HabitCategory, num>{},
    this.trainingDaysPerWeek = 4,
    this.experience = TrainingExperience.beginner,
    this.equipment = EquipmentAccess.fullGym,
    this.trainingPlanEnabled = true,
    this.split,
    this.trainingSetup,
    this.nutritionPlanEnabled = true,
    this.nutritionGoals = const NutritionGoals(),
    this.body,
    this.sharing = const SharingPrefs(),
    this.displayName = '',
    this.avatarEmoji = '🔥',
    this.lengthDays = 100,
  });

  final GoalArchetype? archetype;
  final String statement;
  final Set<HabitCategory> selectedHabits;
  final Map<HabitCategory, num> habitTargets;
  final int trainingDaysPerWeek;
  final TrainingExperience experience;
  final EquipmentAccess equipment;

  /// The structured training plan is optional — but worth more XP.
  final bool trainingPlanEnabled;

  /// The split the user picked; null means the recommended one.
  final SplitKind? split;

  /// Exercises the user edited. Null until they touch one: until then the
  /// suggestion follows every change of days, equipment and experience.
  final TrainingSetup? trainingSetup;

  /// Targets and food diary — optional, and also worth more XP.
  final bool nutritionPlanEnabled;
  final NutritionGoals nutritionGoals;

  final BodyProfile? body;
  final SharingPrefs sharing;
  final String displayName;
  final String avatarEmoji;
  final int lengthDays;

  bool get hasTrainingHabit =>
      selectedHabits.contains(HabitCategory.gym) ||
      selectedHabits.contains(HabitCategory.cardio);

  bool get needsTrainingDetails => hasTrainingHabit;

  bool get usesTrainingPlan => hasTrainingHabit && trainingPlanEnabled;

  bool get usesNutritionPlan =>
      selectedHabits.contains(HabitCategory.nutrition) && nutritionPlanEnabled;

  /// Body stats only feed the calorie target, so only the nutrition plan
  /// asks for them. Someone doing a dopamine detox is never asked their
  /// weight.
  bool get needsBodyStats => usesNutritionPlan;

  SplitKind get effectiveSplit =>
      trainingSetup?.split ?? split ?? recommendedSplit(trainingDaysPerWeek);

  bool get isReady =>
      archetype != null &&
      statement.trim().isNotEmpty &&
      selectedHabits.isNotEmpty &&
      displayName.trim().isNotEmpty &&
      (!needsBodyStats || body != null);

  OnboardingDraft copyWith({
    GoalArchetype? archetype,
    String? statement,
    Set<HabitCategory>? selectedHabits,
    Map<HabitCategory, num>? habitTargets,
    int? trainingDaysPerWeek,
    TrainingExperience? experience,
    EquipmentAccess? equipment,
    bool? trainingPlanEnabled,
    SplitKind? split,
    TrainingSetup? trainingSetup,
    bool clearTrainingSetup = false,
    bool? nutritionPlanEnabled,
    NutritionGoals? nutritionGoals,
    BodyProfile? body,
    SharingPrefs? sharing,
    String? displayName,
    String? avatarEmoji,
    int? lengthDays,
  }) =>
      OnboardingDraft(
        archetype: archetype ?? this.archetype,
        statement: statement ?? this.statement,
        selectedHabits: selectedHabits ?? this.selectedHabits,
        habitTargets: habitTargets ?? this.habitTargets,
        trainingDaysPerWeek: trainingDaysPerWeek ?? this.trainingDaysPerWeek,
        experience: experience ?? this.experience,
        equipment: equipment ?? this.equipment,
        trainingPlanEnabled: trainingPlanEnabled ?? this.trainingPlanEnabled,
        split: split ?? this.split,
        trainingSetup: clearTrainingSetup
            ? null
            : trainingSetup ?? this.trainingSetup,
        nutritionPlanEnabled:
            nutritionPlanEnabled ?? this.nutritionPlanEnabled,
        nutritionGoals: nutritionGoals ?? this.nutritionGoals,
        body: body ?? this.body,
        sharing: sharing ?? this.sharing,
        displayName: displayName ?? this.displayName,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        lengthDays: lengthDays ?? this.lengthDays,
      );

  Goal _baseGoal() => Goal(
        archetype: archetype!,
        statement: statement.trim(),
        body: usesNutritionPlan ? body : null,
        experience: experience,
        equipment: equipment,
        trainingDaysPerWeek: trainingDaysPerWeek,
        trainingPlanEnabled: trainingPlanEnabled,
        nutritionPlanEnabled: nutritionPlanEnabled,
        nutrition: usesNutritionPlan ? nutritionGoals : null,
      );

  /// The training plan as it would be saved: the user's edits, or the
  /// suggestion for the chosen split.
  TrainingSetup currentTrainingSetup() =>
      trainingSetup ??
      suggestTrainingSetup(_baseGoal(), split: effectiveSplit);

  Goal toGoal() {
    final goal = _baseGoal();
    if (!usesTrainingPlan) return goal;
    return goal.copyWith(training: currentTrainingSetup());
  }

  List<Habit> toHabits() => <Habit>[
        for (final HabitCategory category in selectedHabits)
          Habit.fromCategory(category).copyWith(
            target: habitTargets[category],
            daysPerWeek: category == HabitCategory.gym
                ? trainingDaysPerWeek
                : null,
          ),
      ];

  Challenge toChallenge({DayKey? startDay}) => Challenge(
        id: 'challenge-1',
        goal: toGoal(),
        habits: toHabits(),
        startDay: startDay ?? DayKey.today(),
        lengthDays: lengthDays,
        sharing: sharing.copyWith(
          // Only keep switches for habits that exist.
          privateHabits: sharing.privateHabits
              .where((String id) =>
                  selectedHabits.any((HabitCategory c) => c.name == id))
              .toSet(),
        ),
      );
}

class OnboardingController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  void chooseArchetype(GoalArchetype archetype) {
    final info = goalInfo(archetype);
    state = state.copyWith(
      archetype: archetype,
      // Pre-select what this goal implies; the user edits from there rather
      // than starting at an empty list.
      selectedHabits: info.suggestedHabits.toSet(),
      // A goal that is not about the body does not default into a calorie
      // plan; the user can still switch it on.
      nutritionPlanEnabled: info.needsBodyStats,
    );
  }

  void setStatement(String statement) =>
      state = state.copyWith(statement: statement);

  void toggleHabit(HabitCategory category) {
    final next = Set<HabitCategory>.from(state.selectedHabits);
    if (!next.remove(category)) next.add(category);
    state = state.copyWith(selectedHabits: next);
  }

  void setTarget(HabitCategory category, num target) {
    state = state.copyWith(
      habitTargets: <HabitCategory, num>{...state.habitTargets, category: target},
    );
  }

  // Days, experience and equipment change what the suggestion would be, so
  // unedited suggestions are rebuilt; an edited plan is kept as it is.
  void setTrainingDays(int days) => state = state.copyWith(
        trainingDaysPerWeek: days,
        clearTrainingSetup: state.trainingSetup == null,
      );

  void setExperience(TrainingExperience experience) =>
      state = state.copyWith(experience: experience);

  void setEquipment(EquipmentAccess equipment) => state = state.copyWith(
        equipment: equipment,
        // Exercises picked for a full gym make no sense at home.
        clearTrainingSetup: true,
      );

  void setTrainingPlanEnabled(bool enabled) =>
      state = state.copyWith(trainingPlanEnabled: enabled);

  void chooseSplit(SplitKind split) => state = state.copyWith(
        split: split,
        clearTrainingSetup: true,
      );

  void setTrainingSetup(TrainingSetup setup) =>
      state = state.copyWith(trainingSetup: setup, split: setup.split);

  void setNutritionPlanEnabled(bool enabled) =>
      state = state.copyWith(nutritionPlanEnabled: enabled);

  void setNutritionGoals(NutritionGoals goals) =>
      state = state.copyWith(nutritionGoals: goals);

  void setBody(BodyProfile body) => state = state.copyWith(body: body);

  void setSharing(SharingPrefs sharing) =>
      state = state.copyWith(sharing: sharing);

  void setIdentity({String? displayName, String? avatarEmoji}) => state =
      state.copyWith(displayName: displayName, avatarEmoji: avatarEmoji);

  void setLength(int days) => state = state.copyWith(lengthDays: days);

  void reset() => state = const OnboardingDraft();
}

final NotifierProvider<OnboardingController, OnboardingDraft>
    onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingDraft>(
        OnboardingController.new);
