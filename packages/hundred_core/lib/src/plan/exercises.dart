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

@immutable
class Exercise {
  const Exercise({
    required this.id,
    required this.nameDe,
    required this.pattern,
    required this.primary,
    required this.minEquipment,
    this.isCompound = true,
    this.cueDe,
  });

  final String id;
  final String nameDe;
  final MovementPattern pattern;
  final MuscleGroup primary;

  /// The least equipment this movement needs. A full-gym user can do
  /// everything; a bodyweight user only sees bodyweight entries.
  final EquipmentAccess minEquipment;

  final bool isCompound;
  final String? cueDe;

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
    nameDe: 'Kniebeuge (Langhantel)',
    pattern: MovementPattern.squat,
    primary: MuscleGroup.quads,
    minEquipment: EquipmentAccess.fullGym,
    cueDe: 'Brust hoch, Knie über die Fußspitzen, kontrolliert runter.',
  ),
  Exercise(
    id: 'goblet_squat',
    nameDe: 'Goblet Squat',
    pattern: MovementPattern.squat,
    primary: MuscleGroup.quads,
    minEquipment: EquipmentAccess.homeBasic,
    cueDe: 'Kurzhantel vor der Brust, tief und aufrecht.',
  ),
  Exercise(
    id: 'bw_squat',
    nameDe: 'Körpergewicht-Kniebeuge',
    pattern: MovementPattern.squat,
    primary: MuscleGroup.quads,
    minEquipment: EquipmentAccess.bodyweight,
    cueDe: 'Langsam runter, unten kurz halten.',
  ),
  Exercise(
    id: 'leg_press',
    nameDe: 'Beinpresse',
    pattern: MovementPattern.squat,
    primary: MuscleGroup.quads,
    minEquipment: EquipmentAccess.fullGym,
  ),
  // Hinge
  Exercise(
    id: 'deadlift',
    nameDe: 'Kreuzheben',
    pattern: MovementPattern.hinge,
    primary: MuscleGroup.hamstrings,
    minEquipment: EquipmentAccess.fullGym,
    cueDe: 'Rücken gerade, Hantel am Schienbein entlang.',
  ),
  Exercise(
    id: 'rdl',
    nameDe: 'Rumänisches Kreuzheben',
    pattern: MovementPattern.hinge,
    primary: MuscleGroup.hamstrings,
    minEquipment: EquipmentAccess.homeBasic,
    cueDe: 'Hüfte nach hinten, Dehnung in den Beinbeugern spüren.',
  ),
  Exercise(
    id: 'hip_thrust',
    nameDe: 'Hip Thrust',
    pattern: MovementPattern.hinge,
    primary: MuscleGroup.glutes,
    minEquipment: EquipmentAccess.homeBasic,
  ),
  Exercise(
    id: 'glute_bridge',
    nameDe: 'Glute Bridge',
    pattern: MovementPattern.hinge,
    primary: MuscleGroup.glutes,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  Exercise(
    id: 'nordic_curl',
    nameDe: 'Nordic Curl (assistiert)',
    pattern: MovementPattern.hinge,
    primary: MuscleGroup.hamstrings,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  // Horizontal push
  Exercise(
    id: 'bench_press',
    nameDe: 'Bankdrücken',
    pattern: MovementPattern.horizontalPush,
    primary: MuscleGroup.chest,
    minEquipment: EquipmentAccess.fullGym,
    cueDe: 'Schulterblätter zusammen, Stange zur unteren Brust.',
  ),
  Exercise(
    id: 'db_bench',
    nameDe: 'Kurzhantel-Bankdrücken',
    pattern: MovementPattern.horizontalPush,
    primary: MuscleGroup.chest,
    minEquipment: EquipmentAccess.homeBasic,
  ),
  Exercise(
    id: 'pushup',
    nameDe: 'Liegestütz',
    pattern: MovementPattern.horizontalPush,
    primary: MuscleGroup.chest,
    minEquipment: EquipmentAccess.bodyweight,
    cueDe: 'Körper bleibt ein Brett, Ellbogen 45 Grad.',
  ),
  Exercise(
    id: 'dip',
    nameDe: 'Dips',
    pattern: MovementPattern.horizontalPush,
    primary: MuscleGroup.chest,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  // Vertical push
  Exercise(
    id: 'ohp',
    nameDe: 'Schulterdrücken (Langhantel)',
    pattern: MovementPattern.verticalPush,
    primary: MuscleGroup.shoulders,
    minEquipment: EquipmentAccess.fullGym,
  ),
  Exercise(
    id: 'db_ohp',
    nameDe: 'Schulterdrücken (Kurzhantel)',
    pattern: MovementPattern.verticalPush,
    primary: MuscleGroup.shoulders,
    minEquipment: EquipmentAccess.homeBasic,
  ),
  Exercise(
    id: 'pike_pushup',
    nameDe: 'Pike Push-up',
    pattern: MovementPattern.verticalPush,
    primary: MuscleGroup.shoulders,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  // Horizontal pull
  Exercise(
    id: 'barbell_row',
    nameDe: 'Langhantelrudern',
    pattern: MovementPattern.horizontalPull,
    primary: MuscleGroup.back,
    minEquipment: EquipmentAccess.fullGym,
  ),
  Exercise(
    id: 'db_row',
    nameDe: 'Kurzhantelrudern',
    pattern: MovementPattern.horizontalPull,
    primary: MuscleGroup.back,
    minEquipment: EquipmentAccess.homeBasic,
  ),
  Exercise(
    id: 'inverted_row',
    nameDe: 'Australian Pull-up',
    pattern: MovementPattern.horizontalPull,
    primary: MuscleGroup.back,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  Exercise(
    id: 'cable_row',
    nameDe: 'Rudern am Kabelzug',
    pattern: MovementPattern.horizontalPull,
    primary: MuscleGroup.back,
    minEquipment: EquipmentAccess.fullGym,
  ),
  // Vertical pull
  Exercise(
    id: 'pullup',
    nameDe: 'Klimmzug',
    pattern: MovementPattern.verticalPull,
    primary: MuscleGroup.back,
    minEquipment: EquipmentAccess.bodyweight,
    cueDe: 'Schultern runter, Brust zur Stange.',
  ),
  Exercise(
    id: 'lat_pulldown',
    nameDe: 'Latzug',
    pattern: MovementPattern.verticalPull,
    primary: MuscleGroup.back,
    minEquipment: EquipmentAccess.fullGym,
  ),
  Exercise(
    id: 'band_pulldown',
    nameDe: 'Latzug mit Band',
    pattern: MovementPattern.verticalPull,
    primary: MuscleGroup.back,
    minEquipment: EquipmentAccess.homeBasic,
  ),
  // Lunge
  Exercise(
    id: 'walking_lunge',
    nameDe: 'Ausfallschritte',
    pattern: MovementPattern.lunge,
    primary: MuscleGroup.quads,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  Exercise(
    id: 'bulgarian_split_squat',
    nameDe: 'Bulgarian Split Squat',
    pattern: MovementPattern.lunge,
    primary: MuscleGroup.quads,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  Exercise(
    id: 'step_up',
    nameDe: 'Step-up',
    pattern: MovementPattern.lunge,
    primary: MuscleGroup.glutes,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  // Core
  Exercise(
    id: 'plank',
    nameDe: 'Unterarmstütz',
    pattern: MovementPattern.core,
    primary: MuscleGroup.core,
    minEquipment: EquipmentAccess.bodyweight,
    isCompound: false,
  ),
  Exercise(
    id: 'hanging_leg_raise',
    nameDe: 'Hängendes Beinheben',
    pattern: MovementPattern.core,
    primary: MuscleGroup.core,
    minEquipment: EquipmentAccess.bodyweight,
    isCompound: false,
  ),
  Exercise(
    id: 'ab_wheel',
    nameDe: 'Bauchroller',
    pattern: MovementPattern.core,
    primary: MuscleGroup.core,
    minEquipment: EquipmentAccess.homeBasic,
    isCompound: false,
  ),
  Exercise(
    id: 'dead_bug',
    nameDe: 'Dead Bug',
    pattern: MovementPattern.core,
    primary: MuscleGroup.core,
    minEquipment: EquipmentAccess.bodyweight,
    isCompound: false,
  ),
  // Carry
  Exercise(
    id: 'farmers_walk',
    nameDe: 'Farmer\'s Walk',
    pattern: MovementPattern.carry,
    primary: MuscleGroup.fullBody,
    minEquipment: EquipmentAccess.homeBasic,
  ),
  // Isolation
  Exercise(
    id: 'biceps_curl',
    nameDe: 'Bizepscurls',
    pattern: MovementPattern.isolationArms,
    primary: MuscleGroup.biceps,
    minEquipment: EquipmentAccess.homeBasic,
    isCompound: false,
  ),
  Exercise(
    id: 'hammer_curl',
    nameDe: 'Hammercurls',
    pattern: MovementPattern.isolationArms,
    primary: MuscleGroup.biceps,
    minEquipment: EquipmentAccess.homeBasic,
    isCompound: false,
  ),
  Exercise(
    id: 'triceps_pushdown',
    nameDe: 'Trizepsdrücken am Kabel',
    pattern: MovementPattern.isolationArms,
    primary: MuscleGroup.triceps,
    minEquipment: EquipmentAccess.fullGym,
    isCompound: false,
  ),
  Exercise(
    id: 'diamond_pushup',
    nameDe: 'Diamond Push-up',
    pattern: MovementPattern.isolationArms,
    primary: MuscleGroup.triceps,
    minEquipment: EquipmentAccess.bodyweight,
    isCompound: false,
  ),
  Exercise(
    id: 'lateral_raise',
    nameDe: 'Seitheben',
    pattern: MovementPattern.isolationShoulders,
    primary: MuscleGroup.shoulders,
    minEquipment: EquipmentAccess.homeBasic,
    isCompound: false,
  ),
  Exercise(
    id: 'face_pull',
    nameDe: 'Face Pull',
    pattern: MovementPattern.isolationShoulders,
    primary: MuscleGroup.shoulders,
    minEquipment: EquipmentAccess.homeBasic,
    isCompound: false,
  ),
  Exercise(
    id: 'leg_curl',
    nameDe: 'Beinbeuger',
    pattern: MovementPattern.isolationLegs,
    primary: MuscleGroup.hamstrings,
    minEquipment: EquipmentAccess.fullGym,
    isCompound: false,
  ),
  Exercise(
    id: 'calf_raise',
    nameDe: 'Wadenheben',
    pattern: MovementPattern.isolationLegs,
    primary: MuscleGroup.calves,
    minEquipment: EquipmentAccess.bodyweight,
    isCompound: false,
  ),
  // Conditioning
  Exercise(
    id: 'burpee',
    nameDe: 'Burpees',
    pattern: MovementPattern.conditioning,
    primary: MuscleGroup.fullBody,
    minEquipment: EquipmentAccess.bodyweight,
  ),
  Exercise(
    id: 'kb_swing',
    nameDe: 'Kettlebell Swing',
    pattern: MovementPattern.conditioning,
    primary: MuscleGroup.fullBody,
    minEquipment: EquipmentAccess.homeBasic,
  ),
  Exercise(
    id: 'jump_rope',
    nameDe: 'Seilspringen',
    pattern: MovementPattern.conditioning,
    primary: MuscleGroup.fullBody,
    minEquipment: EquipmentAccess.homeBasic,
  ),
  Exercise(
    id: 'rowing_erg',
    nameDe: 'Rudergerät',
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
