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
    this.body,
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
  final BodyProfile? body;
  final String displayName;
  final String avatarEmoji;
  final int lengthDays;

  bool get needsBodyStats =>
      archetype != null && goalInfo(archetype!).needsBodyStats;

  bool get needsTrainingDetails =>
      selectedHabits.contains(HabitCategory.gym) ||
      selectedHabits.contains(HabitCategory.cardio);

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
    BodyProfile? body,
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
        body: body ?? this.body,
        displayName: displayName ?? this.displayName,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        lengthDays: lengthDays ?? this.lengthDays,
      );

  Goal toGoal() => Goal(
        archetype: archetype!,
        statement: statement.trim(),
        body: body,
        experience: experience,
        equipment: equipment,
        trainingDaysPerWeek: trainingDaysPerWeek,
      );

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

  void setTrainingDays(int days) =>
      state = state.copyWith(trainingDaysPerWeek: days);

  void setExperience(TrainingExperience experience) =>
      state = state.copyWith(experience: experience);

  void setEquipment(EquipmentAccess equipment) =>
      state = state.copyWith(equipment: equipment);

  void setBody(BodyProfile body) => state = state.copyWith(body: body);

  void setIdentity({String? displayName, String? avatarEmoji}) => state =
      state.copyWith(displayName: displayName, avatarEmoji: avatarEmoji);

  void setLength(int days) => state = state.copyWith(lengthDays: days);

  void reset() => state = const OnboardingDraft();
}

final NotifierProvider<OnboardingController, OnboardingDraft>
    onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingDraft>(
        OnboardingController.new);
