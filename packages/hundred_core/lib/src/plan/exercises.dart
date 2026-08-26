import 'package:meta/meta.dart';

import '../domain/goal.dart';

enum MovementPattern {
  squat,
  hinge,
  horizontalPush,
  verticalPush,
  horizontalPull,
  verticalPull,
  lunge,
  core,
  carry,
  isolationArms,
  isolationShoulders,
  isolationLegs,
  conditioning,
}

enum MuscleGroup {
  quads,
  hamstrings,
  glutes,
  calves,
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  core,
  fullBody,
}

/// A movement, identified by [id]. Its name and coaching cue live in the
/// app's localizations under that id — an exercise library that hardcodes
/// German names cannot be shown to an English user.
@immutable
class Exercise {
  const Exercise({
    required this.id,
    required this.pattern,
    required this.primary,
    required this.minEquipment,
    this.isCompound = true,
    this.hasCue = false,
  });

  final String id;
  final MovementPattern pattern;
  final MuscleGroup primary;

  /// The least equipment this movement needs. A full-gym user can do
  /// everything; a bodyweight user only sees bodyweight entries.
  final EquipmentAccess minEquipment;

  final bool isCompound;

  /// Whether the localizations carry a form cue for this movement.
  final bool hasCue;

  bool availableWith(EquipmentAccess access) {
    switch (access) {
      case EquipmentAccess.fullGym:
        return true;
      case EquipmentAccess.homeBasic:
        return minEquipment != EquipmentAccess.fullGym;
      case EquipmentAccess.bodyweight:
        return minEquipment == EquipmentAccess.bodyweight;
    }
  }
}

const List<Exercise> kExerciseLibrary = <Exercise>[
  // Squat
  Exercise(
    id: 'back_squat',
    pattern: MovementPattern.squat,
    primary: MuscleGroup.quads,
    minEquipment: EquipmentAccess.fullGym,
    hasCue: true,
  ),
  Exercise(
    id: 'goblet_squat',
    pattern: MovementPattern.squat,
    primary: MuscleGroup.quads,
    minEquipment: EquipmentAccess.homeBasic,
    hasCue: true,
  ),
  Exercise(
    id: 'bw_squat',
    pattern: MovementPattern.squat,
    primary: MuscleGroup.quads,
    minEquipment: EquipmentAccess.bodyweight,
    hasCue: true,
  ),
  Exercise(
    id: 'leg_press',
    pattern: MovementPattern.squat,
    primary: MuscleGroup.quads,
    minEquipment: EquipmentAccess.fullGym,
  ),
  // Hinge
  Exercise(
    id: 'deadlift',
    pattern: MovementPattern.hinge,
    primary: MuscleGroup.hamstrings,
    minEquipment: EquipmentAccess.fullGym,
    hasCue: true,
  ),
  Exercise(
    id: 'rdl',
    pattern: MovementPattern.hinge,
    primary: MuscleGroup.hamstrings,
    minEquipment: EquipmentAccess.homeBasic,
    hasCue: true,
  ),
  Exercise(
    id: 'hip_thrust',
    pattern: MovementPattern.hinge,
    primary: MuscleGroup.glutes,
    minEquipment: EquipmentAccess.homeBasic,
  ),
  Exercise(
    id: 'glute_bridge',
    pattern: MovementPattern.hinge,
    primary: MuscleGroup.glutes,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  Exercise(
    id: 'nordic_curl',
    pattern: MovementPattern.hinge,
    primary: MuscleGroup.hamstrings,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  // Horizontal push
  Exercise(
    id: 'bench_press',
    pattern: MovementPattern.horizontalPush,
    primary: MuscleGroup.chest,
    minEquipment: EquipmentAccess.fullGym,
    hasCue: true,
  ),
  Exercise(
    id: 'db_bench',
    pattern: MovementPattern.horizontalPush,
    primary: MuscleGroup.chest,
    minEquipment: EquipmentAccess.homeBasic,
  ),
  Exercise(
    id: 'pushup',
    pattern: MovementPattern.horizontalPush,
    primary: MuscleGroup.chest,
    minEquipment: EquipmentAccess.bodyweight,
    hasCue: true,
  ),
  Exercise(
    id: 'dip',
    pattern: MovementPattern.horizontalPush,
    primary: MuscleGroup.chest,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  // Vertical push
  Exercise(
    id: 'ohp',
    pattern: MovementPattern.verticalPush,
    primary: MuscleGroup.shoulders,
    minEquipment: EquipmentAccess.fullGym,
  ),
  Exercise(
    id: 'db_ohp',
    pattern: MovementPattern.verticalPush,
    primary: MuscleGroup.shoulders,
    minEquipment: EquipmentAccess.homeBasic,
  ),
  Exercise(
    id: 'pike_pushup',
    pattern: MovementPattern.verticalPush,
    primary: MuscleGroup.shoulders,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  // Horizontal pull
  Exercise(
    id: 'barbell_row',
    pattern: MovementPattern.horizontalPull,
    primary: MuscleGroup.back,
    minEquipment: EquipmentAccess.fullGym,
  ),
  Exercise(
    id: 'db_row',
    pattern: MovementPattern.horizontalPull,
    primary: MuscleGroup.back,
    minEquipment: EquipmentAccess.homeBasic,
  ),
  Exercise(
    id: 'inverted_row',
    pattern: MovementPattern.horizontalPull,
    primary: MuscleGroup.back,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  Exercise(
    id: 'cable_row',
    pattern: MovementPattern.horizontalPull,
    primary: MuscleGroup.back,
    minEquipment: EquipmentAccess.fullGym,
  ),
  // Vertical pull
  Exercise(
    id: 'pullup',
    pattern: MovementPattern.verticalPull,
    primary: MuscleGroup.back,
    minEquipment: EquipmentAccess.bodyweight,
    hasCue: true,
  ),
  Exercise(
    id: 'lat_pulldown',
    pattern: MovementPattern.verticalPull,
    primary: MuscleGroup.back,
    minEquipment: EquipmentAccess.fullGym,
  ),
  Exercise(
    id: 'band_pulldown',
    pattern: MovementPattern.verticalPull,
    primary: MuscleGroup.back,
    minEquipment: EquipmentAccess.homeBasic,
  ),
  // Lunge
  Exercise(
    id: 'walking_lunge',
    pattern: MovementPattern.lunge,
    primary: MuscleGroup.quads,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  Exercise(
    id: 'bulgarian_split_squat',
    pattern: MovementPattern.lunge,
    primary: MuscleGroup.quads,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  Exercise(
    id: 'step_up',
    pattern: MovementPattern.lunge,
    primary: MuscleGroup.glutes,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  // Core
  Exercise(
    id: 'plank',
    pattern: MovementPattern.core,
    primary: MuscleGroup.core,
    minEquipment: EquipmentAccess.bodyweight,
    isCompound: false,
  ),
  Exercise(
    id: 'hanging_leg_raise',
    pattern: MovementPattern.core,
    primary: MuscleGroup.core,
    minEquipment: EquipmentAccess.bodyweight,
    isCompound: false,
  ),
  Exercise(
    id: 'ab_wheel',
    pattern: MovementPattern.core,
    primary: MuscleGroup.core,
    minEquipment: EquipmentAccess.homeBasic,
    isCompound: false,
  ),
  Exercise(
    id: 'dead_bug',
    pattern: MovementPattern.core,
    primary: MuscleGroup.core,
    minEquipment: EquipmentAccess.bodyweight,
    isCompound: false,
  ),
  // Carry
  Exercise(
    id: 'farmers_walk',
    pattern: MovementPattern.carry,
    primary: MuscleGroup.fullBody,
    minEquipment: EquipmentAccess.homeBasic,
  ),
  // Isolation
  Exercise(
    id: 'biceps_curl',
    pattern: MovementPattern.isolationArms,
    primary: MuscleGroup.biceps,
    minEquipment: EquipmentAccess.homeBasic,
    isCompound: false,
  ),
  Exercise(
    id: 'hammer_curl',
    pattern: MovementPattern.isolationArms,
    primary: MuscleGroup.biceps,
    minEquipment: EquipmentAccess.homeBasic,
    isCompound: false,
  ),
  Exercise(
    id: 'triceps_pushdown',
    pattern: MovementPattern.isolationArms,
    primary: MuscleGroup.triceps,
    minEquipment: EquipmentAccess.fullGym,
    isCompound: false,
  ),
  Exercise(
    id: 'diamond_pushup',
    pattern: MovementPattern.isolationArms,
    primary: MuscleGroup.triceps,
    minEquipment: EquipmentAccess.bodyweight,
    isCompound: false,
  ),
  Exercise(
    id: 'lateral_raise',
    pattern: MovementPattern.isolationShoulders,
    primary: MuscleGroup.shoulders,
    minEquipment: EquipmentAccess.homeBasic,
    isCompound: false,
  ),
  Exercise(
    id: 'face_pull',
    pattern: MovementPattern.isolationShoulders,
    primary: MuscleGroup.shoulders,
    minEquipment: EquipmentAccess.homeBasic,
    isCompound: false,
  ),
  Exercise(
    id: 'leg_curl',
    pattern: MovementPattern.isolationLegs,
    primary: MuscleGroup.hamstrings,
    minEquipment: EquipmentAccess.fullGym,
    isCompound: false,
  ),
  Exercise(
    id: 'calf_raise',
    pattern: MovementPattern.isolationLegs,
    primary: MuscleGroup.calves,
    minEquipment: EquipmentAccess.bodyweight,
    isCompound: false,
  ),
  // Conditioning
  Exercise(
    id: 'burpee',
    pattern: MovementPattern.conditioning,
    primary: MuscleGroup.fullBody,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  Exercise(
    id: 'kb_swing',
    pattern: MovementPattern.conditioning,
    primary: MuscleGroup.fullBody,
    minEquipment: EquipmentAccess.homeBasic,
  ),
  Exercise(
    id: 'jump_rope',
    pattern: MovementPattern.conditioning,
    primary: MuscleGroup.fullBody,
    minEquipment: EquipmentAccess.homeBasic,
  ),
  Exercise(
    id: 'rowing_erg',
    pattern: MovementPattern.conditioning,
    primary: MuscleGroup.fullBody,
    minEquipment: EquipmentAccess.fullGym,
  ),
];

final Map<String, Exercise> kExerciseById = <String, Exercise>{
  for (final Exercise e in kExerciseLibrary) e.id: e,
};

/// The best available exercise for [pattern] given the user's equipment.
///
/// Falls back through the equipment tiers rather than returning null, so a
/// bodyweight-only user still gets a complete plan instead of gaps.
Exercise? pickExercise(
  MovementPattern pattern,
  EquipmentAccess access, {
  Set<String> exclude = const <String>{},
}) {
  final candidates = kExerciseLibrary
      .where((Exercise e) =>
          e.pattern == pattern &&
          e.availableWith(access) &&
          !exclude.contains(e.id))
      .toList();
  if (candidates.isEmpty) return null;
  // EquipmentAccess is ordered fullGym → homeBasic → bodyweight, so the
  // lowest index is the most equipment-hungry — and the best variant for
  // someone who has that equipment. Filtering already removed the rest.
  candidates.sort((Exercise a, Exercise b) =>
      a.minEquipment.index.compareTo(b.minEquipment.index));
  return candidates.first;
}
