import 'package:hundred_core/hundred_core.dart';

import 'generated/app_localizations.dart';

/// Wording for the generated plans.
extension PlanL10n on AppLocalizations {
  String workoutName(WorkoutKind kind) {
    switch (kind) {
      case WorkoutKind.fullBodyA:
        return workoutFullBodyA;
      case WorkoutKind.fullBodyB:
        return workoutFullBodyB;
      case WorkoutKind.fullBodyC:
        return workoutFullBodyC;
      case WorkoutKind.push:
        return workoutPush;
      case WorkoutKind.pull:
        return workoutPull;
      case WorkoutKind.legs:
        return workoutLegs;
      case WorkoutKind.upper:
        return workoutUpper;
      case WorkoutKind.lower:
        return workoutLower;
    }
  }

  String workoutFocus(WorkoutKind kind) {
    switch (kind) {
      case WorkoutKind.fullBodyA:
        return workoutFullBodyAFocus;
      case WorkoutKind.fullBodyB:
        return workoutFullBodyBFocus;
      case WorkoutKind.fullBodyC:
        return workoutFullBodyCFocus;
      case WorkoutKind.push:
        return workoutPushFocus;
      case WorkoutKind.pull:
        return workoutPullFocus;
      case WorkoutKind.legs:
        return workoutLegsFocus;
      case WorkoutKind.upper:
        return workoutUpperFocus;
      case WorkoutKind.lower:
        return workoutLowerFocus;
    }
  }

  String splitName(SplitKind split) {
    switch (split) {
      case SplitKind.fullBodyTwice:
        return splitFullBodyTwice;
      case SplitKind.fullBodyThrice:
        return splitFullBodyThrice;
      case SplitKind.upperLower:
        return splitUpperLower;
      case SplitKind.pplPlusUpperLower:
        return splitPplPlusUpperLower;
      case SplitKind.pplTwice:
        return splitPplTwice;
    }
  }

  /// One-line preview shown while the user is still picking training days.
  String splitPreview(int daysPerWeek) {
    switch (daysPerWeek) {
      case 2:
        return splitPreview2;
      case 3:
        return splitPreview3;
      case 4:
        return splitPreview4;
      case 5:
        return splitPreview5;
      default:
        return splitPreview6;
    }
  }

  String trainingPhase(TrainingWeek week) => week.isDeload
      ? trainingPhaseDeload
      : trainingPhaseBuild(week.weekInBlock, week.blockNumber);

  String trainingPlanRationale(TrainingPlan plan) =>
      trainingRationale(plan.daysPerWeek, splitName(plan.split));

  String mealName(MealSlotKind kind) {
    switch (kind) {
      case MealSlotKind.breakfast:
        return mealBreakfast;
      case MealSlotKind.lunch:
        return mealLunch;
      case MealSlotKind.snack:
        return mealSnack;
      case MealSlotKind.dinner:
        return mealDinner;
    }
  }

  List<String> mealIdeas(MealSlotKind kind) {
    switch (kind) {
      case MealSlotKind.breakfast:
        return <String>[
          mealIdeaBreakfast1,
          mealIdeaBreakfast2,
          mealIdeaBreakfast3,
          mealIdeaBreakfast4,
        ];
      case MealSlotKind.lunch:
        return <String>[
          mealIdeaLunch1,
          mealIdeaLunch2,
          mealIdeaLunch3,
          mealIdeaLunch4,
        ];
      case MealSlotKind.snack:
        return <String>[
          mealIdeaSnack1,
          mealIdeaSnack2,
          mealIdeaSnack3,
          mealIdeaSnack4,
        ];
      case MealSlotKind.dinner:
        return <String>[
          mealIdeaDinner1,
          mealIdeaDinner2,
          mealIdeaDinner3,
          mealIdeaDinner4,
        ];
    }
  }

  /// Why the calorie target is what it is.
  String nutritionRationale(NutritionPlan plan) {
    if (!plan.goalDrivesNutrition) return planNutritionSideGoal(plan.tdee);
    switch (plan.strategy) {
      case NutritionStrategy.deficit:
        return planNutritionDeficit(plan.deltaPercent, plan.tdee);
      case NutritionStrategy.surplus:
        return planNutritionSurplus(plan.deltaPercent, plan.tdee);
      case NutritionStrategy.maintenance:
        return planNutritionMaintain(plan.tdee);
    }
  }

  String milestoneTitle(AbstinenceMilestone milestone) {
    switch (milestone.id) {
      case 'alcohol_1':
        return milestoneAlcohol1Title;
      case 'alcohol_3':
        return milestoneAlcohol3Title;
      case 'alcohol_7':
        return milestoneAlcohol7Title;
      case 'alcohol_14':
        return milestoneAlcohol14Title;
      case 'alcohol_30':
        return milestoneAlcohol30Title;
      case 'alcohol_90':
        return milestoneAlcohol90Title;
      case 'dopamine_1':
        return milestoneDopamine1Title;
      case 'dopamine_3':
        return milestoneDopamine3Title;
      case 'dopamine_7':
        return milestoneDopamine7Title;
      case 'dopamine_21':
        return milestoneDopamine21Title;
      case 'dopamine_60':
        return milestoneDopamine60Title;
      case 'noFap_3':
        return milestoneNoFap3Title;
      case 'noFap_7':
        return milestoneNoFap7Title;
      case 'noFap_14':
        return milestoneNoFap14Title;
      case 'noFap_30':
        return milestoneNoFap30Title;
      case 'noFap_90':
        return milestoneNoFap90Title;
      case 'sugar_2':
        return milestoneSugar2Title;
      case 'sugar_5':
        return milestoneSugar5Title;
      case 'sugar_14':
        return milestoneSugar14Title;
      case 'sugar_30':
        return milestoneSugar30Title;
      case 'nicotine_1':
        return milestoneNicotine1Title;
      case 'nicotine_3':
        return milestoneNicotine3Title;
      case 'nicotine_14':
        return milestoneNicotine14Title;
      case 'nicotine_90':
        return milestoneNicotine90Title;
      case 'generic_3':
        return milestoneGeneric3Title;
      case 'generic_21':
        return milestoneGeneric21Title;
      default:
        return milestoneGeneric66Title;
    }
  }

  String milestoneBody(AbstinenceMilestone milestone) {
    switch (milestone.id) {
      case 'alcohol_1':
        return milestoneAlcohol1Body;
      case 'alcohol_3':
        return milestoneAlcohol3Body;
      case 'alcohol_7':
        return milestoneAlcohol7Body;
      case 'alcohol_14':
        return milestoneAlcohol14Body;
      case 'alcohol_30':
        return milestoneAlcohol30Body;
      case 'alcohol_90':
        return milestoneAlcohol90Body;
      case 'dopamine_1':
        return milestoneDopamine1Body;
      case 'dopamine_3':
        return milestoneDopamine3Body;
      case 'dopamine_7':
        return milestoneDopamine7Body;
      case 'dopamine_21':
        return milestoneDopamine21Body;
      case 'dopamine_60':
        return milestoneDopamine60Body;
      case 'noFap_3':
        return milestoneNoFap3Body;
      case 'noFap_7':
        return milestoneNoFap7Body;
      case 'noFap_14':
        return milestoneNoFap14Body;
      case 'noFap_30':
        return milestoneNoFap30Body;
      case 'noFap_90':
        return milestoneNoFap90Body;
      case 'sugar_2':
        return milestoneSugar2Body;
      case 'sugar_5':
        return milestoneSugar5Body;
      case 'sugar_14':
        return milestoneSugar14Body;
      case 'sugar_30':
        return milestoneSugar30Body;
      case 'nicotine_1':
        return milestoneNicotine1Body;
      case 'nicotine_3':
        return milestoneNicotine3Body;
      case 'nicotine_14':
        return milestoneNicotine14Body;
      case 'nicotine_90':
        return milestoneNicotine90Body;
      case 'generic_3':
        return milestoneGeneric3Body;
      case 'generic_21':
        return milestoneGeneric21Body;
      default:
        return milestoneGeneric66Body;
    }
  }
}
