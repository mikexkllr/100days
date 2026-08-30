import 'package:hundred_core/hundred_core.dart';

import 'generated/app_localizations.dart';

/// Names for the language-free identifiers the core package deals in.
///
/// Everything the user reads that originates in `hundred_core` passes through
/// here. The rule is one-directional: core never imports this, so no piece of
/// logic can accidentally depend on the display language.
extension CoreL10n on AppLocalizations {
  String habitTitle(HabitCategory category) {
    switch (category) {
      case HabitCategory.gym:
        return habitGym;
      case HabitCategory.cardio:
        return habitCardio;
      case HabitCategory.steps:
        return habitSteps;
      case HabitCategory.nutrition:
        return habitNutrition;
      case HabitCategory.noAlcohol:
        return habitNoAlcohol;
      case HabitCategory.noSugar:
        return habitNoSugar;
      case HabitCategory.dopamineDetox:
        return habitDopamineDetox;
      case HabitCategory.noFap:
        return habitNoFap;
      case HabitCategory.noNicotine:
        return habitNoNicotine;
      case HabitCategory.reading:
        return habitReading;
      case HabitCategory.meditation:
        return habitMeditation;
      case HabitCategory.sleep:
        return habitSleep;
      case HabitCategory.coldShower:
        return habitColdShower;
      case HabitCategory.water:
        return habitWater;
      case HabitCategory.journaling:
        return habitJournaling;
      case HabitCategory.custom:
        return habitCustom;
    }
  }

  String habitBlurb(HabitCategory category) {
    switch (category) {
      case HabitCategory.gym:
        return habitGymBlurb;
      case HabitCategory.cardio:
        return habitCardioBlurb;
      case HabitCategory.steps:
        return habitStepsBlurb;
      case HabitCategory.nutrition:
        return habitNutritionBlurb;
      case HabitCategory.noAlcohol:
        return habitNoAlcoholBlurb;
      case HabitCategory.noSugar:
        return habitNoSugarBlurb;
      case HabitCategory.dopamineDetox:
        return habitDopamineDetoxBlurb;
      case HabitCategory.noFap:
        return habitNoFapBlurb;
      case HabitCategory.noNicotine:
        return habitNoNicotineBlurb;
      case HabitCategory.reading:
        return habitReadingBlurb;
      case HabitCategory.meditation:
        return habitMeditationBlurb;
      case HabitCategory.sleep:
        return habitSleepBlurb;
      case HabitCategory.coldShower:
        return habitColdShowerBlurb;
      case HabitCategory.water:
        return habitWaterBlurb;
      case HabitCategory.journaling:
        return habitJournalingBlurb;
      case HabitCategory.custom:
        return habitCustomBlurb;
    }
  }

  /// A user-supplied title always wins: they named it, we do not translate it.
  String habitLabel(Habit habit) => habit.title ?? habitTitle(habit.category);

  String goalTitle(GoalArchetype archetype) {
    switch (archetype) {
      case GoalArchetype.buildMuscle:
        return goalBuildMuscle;
      case GoalArchetype.loseFat:
        return goalLoseFat;
      case GoalArchetype.getFit:
        return goalGetFit;
      case GoalArchetype.discipline:
        return goalDiscipline;
      case GoalArchetype.clarity:
        return goalClarity;
      case GoalArchetype.sober:
        return goalSober;
      case GoalArchetype.custom:
        return goalCustom;
    }
  }

  String goalPitch(GoalArchetype archetype) {
    switch (archetype) {
      case GoalArchetype.buildMuscle:
        return goalBuildMusclePitch;
      case GoalArchetype.loseFat:
        return goalLoseFatPitch;
      case GoalArchetype.getFit:
        return goalGetFitPitch;
      case GoalArchetype.discipline:
        return goalDisciplinePitch;
      case GoalArchetype.clarity:
        return goalClarityPitch;
      case GoalArchetype.sober:
        return goalSoberPitch;
      case GoalArchetype.custom:
        return goalCustomPitch;
    }
  }

  /// Example goal sentences offered as chips during onboarding.
  List<String> goalExamples(GoalArchetype archetype) {
    switch (archetype) {
      case GoalArchetype.buildMuscle:
        return <String>[obExample1Muscle, obExample2Muscle];
      case GoalArchetype.loseFat:
        return <String>[obExample1Fat, obExample2Fat];
      case GoalArchetype.getFit:
        return <String>[obExample1Fit, obExample2Fit];
      case GoalArchetype.discipline:
        return <String>[obExample1Discipline, obExample2Discipline];
      case GoalArchetype.clarity:
        return <String>[obExample1Clarity, obExample2Clarity];
      case GoalArchetype.sober:
        return <String>[obExample1Sober, obExample2Sober];
      case GoalArchetype.custom:
        return <String>[obExample1Custom];
    }
  }

  String tierName(ChallengeTier tier) {
    if (tier.isNumbered) return tierNumbered(tier.numberedRank);
    switch (tier.index) {
      case 0:
        return tier0;
      case 1:
        return tier1;
      case 2:
        return tier2;
      case 3:
        return tier3;
      case 4:
        return tier4;
      default:
        return tier5;
    }
  }

  String leagueName(League league) {
    switch (league) {
      case League.wood:
        return leagueWood;
      case League.bronze:
        return leagueBronze;
      case League.silver:
        return leagueSilver;
      case League.gold:
        return leagueGold;
      case League.platinum:
        return leaguePlatinum;
      case League.diamond:
        return leagueDiamond;
      case League.obsidian:
        return leagueObsidian;
    }
  }

  String experienceTitle(TrainingExperience experience) {
    switch (experience) {
      case TrainingExperience.beginner:
        return obExperienceBeginner;
      case TrainingExperience.intermediate:
        return obExperienceIntermediate;
      case TrainingExperience.advanced:
        return obExperienceAdvanced;
    }
  }

  String experienceBody(TrainingExperience experience) {
    switch (experience) {
      case TrainingExperience.beginner:
        return obExperienceBeginnerBody;
      case TrainingExperience.intermediate:
        return obExperienceIntermediateBody;
      case TrainingExperience.advanced:
        return obExperienceAdvancedBody;
    }
  }

  String equipmentTitle(EquipmentAccess equipment) {
    switch (equipment) {
      case EquipmentAccess.fullGym:
        return obEquipmentFullGym;
      case EquipmentAccess.homeBasic:
        return obEquipmentHome;
      case EquipmentAccess.bodyweight:
        return obEquipmentBodyweight;
    }
  }

  String equipmentBody(EquipmentAccess equipment) {
    switch (equipment) {
      case EquipmentAccess.fullGym:
        return obEquipmentFullGymBody;
      case EquipmentAccess.homeBasic:
        return obEquipmentHomeBody;
      case EquipmentAccess.bodyweight:
        return obEquipmentBodyweightBody;
    }
  }

  String activityLevelTitle(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return obActivitySedentary;
      case ActivityLevel.light:
        return obActivityLight;
      case ActivityLevel.moderate:
        return obActivityModerate;
      case ActivityLevel.high:
        return obActivityHigh;
      case ActivityLevel.athlete:
        return obActivityAthlete;
    }
  }

  /// The habit's target, formatted for its unit — "20 pages", "30 min",
  /// "clean" for an abstinence habit.
  String formatTarget(Habit habit, {num? value}) {
    final amount = (value ?? habit.target).round();
    switch (habit.definition.unit) {
      case HabitUnit.done:
        return habit.kind == HabitKind.abstain ? targetClean : targetDone;
      case HabitUnit.minutes:
        return targetMinutes(amount);
      case HabitUnit.count:
        return targetCount(amount);
      case HabitUnit.pages:
        return targetPages(amount);
      case HabitUnit.grams:
        return targetGrams(amount);
      case HabitUnit.kilocalories:
        return targetKcal(amount);
      case HabitUnit.steps:
        return targetSteps(amount);
    }
  }

  /// Upper-case weekday abbreviation, `DateTime.monday`-based.
  String weekdayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return weekdayMon;
      case DateTime.tuesday:
        return weekdayTue;
      case DateTime.wednesday:
        return weekdayWed;
      case DateTime.thursday:
        return weekdayThu;
      case DateTime.friday:
        return weekdayFri;
      case DateTime.saturday:
        return weekdaySat;
      default:
        return weekdaySun;
    }
  }

  /// Description of a downloadable model, keyed by its id.
  String modelDescription(String modelId) {
    if (modelId.startsWith('qwen')) return aiModelQwenDesc;
    if (modelId.startsWith('gemma')) return aiModelGemmaDesc;
    return aiModelSmolDesc;
  }

  /// Relative time for feed rows.
  String formatRelative(DateTime timestamp, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(timestamp);
    if (diff.inMinutes < 1) return relativeJustNow;
    if (diff.inMinutes < 60) return relativeMinutes(diff.inMinutes);
    if (diff.inHours < 24) return relativeHours(diff.inHours);
    if (diff.inDays == 1) return relativeYesterday;
    if (diff.inDays < 7) return relativeDays(diff.inDays);
    return DayKey.fromDateTime(timestamp).toString();
  }
}
