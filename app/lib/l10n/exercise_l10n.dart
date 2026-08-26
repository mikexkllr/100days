import 'package:hundred_core/hundred_core.dart';

import 'generated/app_localizations.dart';

/// Names and form cues for the exercise library.
///
/// The core package ships movements as ids; this is the only place that knows
/// what to call them, so adding a language means adding an ARB file rather
/// than touching the training generator.
extension ExerciseL10n on AppLocalizations {
  String exerciseName(String exerciseId) {
    switch (exerciseId) {
      case 'back_squat':
        return exerciseBackSquat;
      case 'goblet_squat':
        return exerciseGobletSquat;
      case 'bw_squat':
        return exerciseBwSquat;
      case 'leg_press':
        return exerciseLegPress;
      case 'deadlift':
        return exerciseDeadlift;
      case 'rdl':
        return exerciseRdl;
      case 'hip_thrust':
        return exerciseHipThrust;
      case 'glute_bridge':
        return exerciseGluteBridge;
      case 'nordic_curl':
        return exerciseNordicCurl;
      case 'bench_press':
        return exerciseBenchPress;
      case 'db_bench':
        return exerciseDbBench;
      case 'pushup':
        return exercisePushup;
      case 'dip':
        return exerciseDip;
      case 'ohp':
        return exerciseOhp;
      case 'db_ohp':
        return exerciseDbOhp;
      case 'pike_pushup':
        return exercisePikePushup;
      case 'barbell_row':
        return exerciseBarbellRow;
      case 'db_row':
        return exerciseDbRow;
      case 'inverted_row':
        return exerciseInvertedRow;
      case 'cable_row':
        return exerciseCableRow;
      case 'pullup':
        return exercisePullup;
      case 'lat_pulldown':
        return exerciseLatPulldown;
      case 'band_pulldown':
        return exerciseBandPulldown;
      case 'walking_lunge':
        return exerciseWalkingLunge;
      case 'bulgarian_split_squat':
        return exerciseBulgarianSplitSquat;
      case 'step_up':
        return exerciseStepUp;
      case 'plank':
        return exercisePlank;
      case 'hanging_leg_raise':
        return exerciseHangingLegRaise;
      case 'ab_wheel':
        return exerciseAbWheel;
      case 'dead_bug':
        return exerciseDeadBug;
      case 'farmers_walk':
        return exerciseFarmersWalk;
      case 'biceps_curl':
        return exerciseBicepsCurl;
      case 'hammer_curl':
        return exerciseHammerCurl;
      case 'triceps_pushdown':
        return exerciseTricepsPushdown;
      case 'diamond_pushup':
        return exerciseDiamondPushup;
      case 'lateral_raise':
        return exerciseLateralRaise;
      case 'face_pull':
        return exerciseFacePull;
      case 'leg_curl':
        return exerciseLegCurl;
      case 'calf_raise':
        return exerciseCalfRaise;
      case 'burpee':
        return exerciseBurpee;
      case 'kb_swing':
        return exerciseKbSwing;
      case 'jump_rope':
        return exerciseJumpRope;
      case 'rowing_erg':
        return exerciseRowingErg;
      default:
        return exerciseId;
    }
  }

  /// Null when the movement has no cue in this language.
  String? exerciseCue(String exerciseId) {
    switch (exerciseId) {
      case 'back_squat':
        return exerciseCueBackSquat;
      case 'goblet_squat':
        return exerciseCueGobletSquat;
      case 'bw_squat':
        return exerciseCueBwSquat;
      case 'deadlift':
        return exerciseCueDeadlift;
      case 'rdl':
        return exerciseCueRdl;
      case 'bench_press':
        return exerciseCueBenchPress;
      case 'pushup':
        return exerciseCuePushup;
      case 'pullup':
        return exerciseCuePullup;
      default:
        return null;
    }
  }

  String muscleName(MuscleGroup group) {
    switch (group) {
      case MuscleGroup.quads:
        return muscleQuads;
      case MuscleGroup.hamstrings:
        return muscleHamstrings;
      case MuscleGroup.glutes:
        return muscleGlutes;
      case MuscleGroup.calves:
        return muscleCalves;
      case MuscleGroup.chest:
        return muscleChest;
      case MuscleGroup.back:
        return muscleBack;
      case MuscleGroup.shoulders:
        return muscleShoulders;
      case MuscleGroup.biceps:
        return muscleBiceps;
      case MuscleGroup.triceps:
        return muscleTriceps;
      case MuscleGroup.core:
        return muscleCore;
      case MuscleGroup.fullBody:
        return muscleFullBody;
    }
  }
}
