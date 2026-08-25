import 'package:meta/meta.dart';

import 'habit.dart';

/// The single question the app asks before anything else: what are you
/// actually here for? Everything downstream — which plan gets generated, what
/// the coach says, which habits are pre-selected — hangs off this answer.
enum GoalArchetype {
  buildMuscle,
  loseFat,
  getFit,
  discipline,
  clarity,
  sober,
  custom,
}

enum BiologicalSex { male, female }

enum ActivityLevel { sedentary, light, moderate, high, athlete }

enum TrainingExperience { beginner, intermediate, advanced }

enum EquipmentAccess { fullGym, homeBasic, bodyweight }

@immutable
class GoalArchetypeInfo {
  const GoalArchetypeInfo({
    required this.archetype,
    required this.titleDe,
    required this.emoji,
    required this.pitchDe,
    required this.suggestedHabits,
    required this.needsBodyStats,
  });

  final GoalArchetype archetype;
  final String titleDe;
  final String emoji;
  final String pitchDe;
  final List<HabitCategory> suggestedHabits;

  /// Whether the onboarding needs height/weight/age to compute a calorie
  /// target. Pure discipline goals do not, and asking anyway is friction.
  final bool needsBodyStats;
}

const Map<GoalArchetype, GoalArchetypeInfo> kGoalCatalog =
    <GoalArchetype, GoalArchetypeInfo>{
  GoalArchetype.buildMuscle: GoalArchetypeInfo(
    archetype: GoalArchetype.buildMuscle,
    titleDe: 'Muskeln aufbauen',
    emoji: '💪',
    pitchDe: 'Schwerer werden, stärker werden. Plan, Protein, Progression.',
    needsBodyStats: true,
    suggestedHabits: <HabitCategory>[
      HabitCategory.gym,
      HabitCategory.nutrition,
      HabitCategory.sleep,
    ],
  ),
  GoalArchetype.loseFat: GoalArchetypeInfo(
    archetype: GoalArchetype.loseFat,
    titleDe: 'Fett verlieren',
    emoji: '🔥',
    pitchDe: 'Defizit halten, Muskeln behalten, Woche für Woche.',
    needsBodyStats: true,
    suggestedHabits: <HabitCategory>[
      HabitCategory.nutrition,
      HabitCategory.gym,
      HabitCategory.cardio,
      HabitCategory.noSugar,
    ],
  ),
  GoalArchetype.getFit: GoalArchetypeInfo(
    archetype: GoalArchetype.getFit,
    titleDe: 'Fit werden',
    emoji: '🏃',
    pitchDe: 'Kondition, Kraft, Beweglichkeit. Zurück in Form.',
    needsBodyStats: true,
    suggestedHabits: <HabitCategory>[
      HabitCategory.gym,
      HabitCategory.cardio,
      HabitCategory.water,
    ],
  ),
  GoalArchetype.discipline: GoalArchetypeInfo(
    archetype: GoalArchetype.discipline,
    titleDe: 'Disziplin aufbauen',
    emoji: '⚔️',
    pitchDe: '100 Tage nicht verhandeln. Der Streak ist das Ziel.',
    needsBodyStats: false,
    suggestedHabits: <HabitCategory>[
      HabitCategory.coldShower,
      HabitCategory.reading,
      HabitCategory.gym,
      HabitCategory.journaling,
    ],
  ),
  GoalArchetype.clarity: GoalArchetypeInfo(
    archetype: GoalArchetype.clarity,
    titleDe: 'Kopf frei kriegen',
    emoji: '🧠',
    pitchDe: 'Dopamin runter, Fokus rauf. Weniger Reiz, mehr Substanz.',
    needsBodyStats: false,
    suggestedHabits: <HabitCategory>[
      HabitCategory.dopamineDetox,
      HabitCategory.noFap,
      HabitCategory.meditation,
      HabitCategory.reading,
    ],
  ),
  GoalArchetype.sober: GoalArchetypeInfo(
    archetype: GoalArchetype.sober,
    titleDe: 'Clean bleiben',
    emoji: '🛡️',
    pitchDe: 'Alkohol, Nikotin, Zucker — jeder Tag zählt einzeln.',
    needsBodyStats: false,
    suggestedHabits: <HabitCategory>[
      HabitCategory.noAlcohol,
      HabitCategory.noNicotine,
      HabitCategory.noSugar,
    ],
  ),
  GoalArchetype.custom: GoalArchetypeInfo(
    archetype: GoalArchetype.custom,
    titleDe: 'Eigenes Ziel',
    emoji: '⭐',
    pitchDe: 'Du weißt selbst, was ansteht. Bau dir den Plan.',
    needsBodyStats: false,
    suggestedHabits: <HabitCategory>[HabitCategory.custom],
  ),
};

GoalArchetypeInfo goalInfo(GoalArchetype archetype) => kGoalCatalog[archetype]!;

/// Body stats, only collected when the chosen goal actually needs them.
@immutable
class BodyProfile {
  const BodyProfile({
    required this.sex,
    required this.ageYears,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    this.targetWeightKg,
    this.bodyFatPercent,
  });

  factory BodyProfile.fromJson(Map<String, dynamic> json) => BodyProfile(
        sex: BiologicalSex.values.byName(json['sex'] as String),
        ageYears: (json['ageYears'] as num).toInt(),
        heightCm: (json['heightCm'] as num).toDouble(),
        weightKg: (json['weightKg'] as num).toDouble(),
        activityLevel:
            ActivityLevel.values.byName(json['activityLevel'] as String),
        targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
        bodyFatPercent: (json['bodyFatPercent'] as num?)?.toDouble(),
      );

  final BiologicalSex sex;
  final int ageYears;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activityLevel;
  final double? targetWeightKg;
  final double? bodyFatPercent;

  BodyProfile copyWith({
    BiologicalSex? sex,
    int? ageYears,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activityLevel,
    double? targetWeightKg,
    double? bodyFatPercent,
  }) =>
      BodyProfile(
        sex: sex ?? this.sex,
        ageYears: ageYears ?? this.ageYears,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        activityLevel: activityLevel ?? this.activityLevel,
        targetWeightKg: targetWeightKg ?? this.targetWeightKg,
        bodyFatPercent: bodyFatPercent ?? this.bodyFatPercent,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sex': sex.name,
        'ageYears': ageYears,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activityLevel': activityLevel.name,
        if (targetWeightKg != null) 'targetWeightKg': targetWeightKg,
        if (bodyFatPercent != null) 'bodyFatPercent': bodyFatPercent,
      };
}

/// The goal as the user configured it in onboarding.
@immutable
class Goal {
  const Goal({
    required this.archetype,
    required this.statement,
    this.body,
    this.experience = TrainingExperience.beginner,
    this.equipment = EquipmentAccess.fullGym,
    this.trainingDaysPerWeek = 4,
  });

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        archetype: GoalArchetype.values.byName(json['archetype'] as String),
        statement: json['statement'] as String,
        body: json['body'] == null
            ? null
            : BodyProfile.fromJson(
                Map<String, dynamic>.from(json['body'] as Map)),
        experience: TrainingExperience.values
            .byName(json['experience'] as String? ?? 'beginner'),
        equipment: EquipmentAccess.values
            .byName(json['equipment'] as String? ?? 'fullGym'),
        trainingDaysPerWeek:
            (json['trainingDaysPerWeek'] as num?)?.toInt() ?? 4,
      );

  final GoalArchetype archetype;

  /// The user's own words, shown back to them on every hard day. "Ich will in
  /// 100 Tagen 8 kg runter" hits differently than "Fett verlieren".
  final String statement;

  final BodyProfile? body;
  final TrainingExperience experience;
  final EquipmentAccess equipment;
  final int trainingDaysPerWeek;

  GoalArchetypeInfo get info => goalInfo(archetype);

  Goal copyWith({
    GoalArchetype? archetype,
    String? statement,
    BodyProfile? body,
    TrainingExperience? experience,
    EquipmentAccess? equipment,
    int? trainingDaysPerWeek,
  }) =>
      Goal(
        archetype: archetype ?? this.archetype,
        statement: statement ?? this.statement,
        body: body ?? this.body,
        experience: experience ?? this.experience,
        equipment: equipment ?? this.equipment,
        trainingDaysPerWeek: trainingDaysPerWeek ?? this.trainingDaysPerWeek,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'archetype': archetype.name,
        'statement': statement,
        if (body != null) 'body': body!.toJson(),
        'experience': experience.name,
        'equipment': equipment.name,
        'trainingDaysPerWeek': trainingDaysPerWeek,
      };
}
