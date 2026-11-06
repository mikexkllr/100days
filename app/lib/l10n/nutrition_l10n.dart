import 'package:hundred_core/hundred_core.dart';

import 'generated/app_localizations.dart';

/// Wording for the food diary, the nutrition targets and their prompts.
extension NutritionL10n on AppLocalizations {
  String mealIdeaName(MealIdea idea) {
    switch (idea.id) {
      case 'breakfast1':
        return mealIdeaBreakfast1;
      case 'breakfast2':
        return mealIdeaBreakfast2;
      case 'breakfast3':
        return mealIdeaBreakfast3;
      case 'breakfast4':
        return mealIdeaBreakfast4;
      case 'breakfast5':
        return mealIdeaBreakfast5;
      case 'lunch1':
        return mealIdeaLunch1;
      case 'lunch2':
        return mealIdeaLunch2;
      case 'lunch3':
        return mealIdeaLunch3;
      case 'lunch4':
        return mealIdeaLunch4;
      case 'lunch5':
        return mealIdeaLunch5;
      case 'snack1':
        return mealIdeaSnack1;
      case 'snack2':
        return mealIdeaSnack2;
      case 'snack3':
        return mealIdeaSnack3;
      case 'snack4':
        return mealIdeaSnack4;
      case 'snack5':
        return mealIdeaSnack5;
      case 'snack6':
        return mealIdeaSnack6;
      case 'dinner1':
        return mealIdeaDinner1;
      case 'dinner2':
        return mealIdeaDinner2;
      case 'dinner3':
        return mealIdeaDinner3;
      case 'dinner4':
        return mealIdeaDinner4;
      case 'dinner5':
        return mealIdeaDinner5;
      case 'dinner6':
        return mealIdeaDinner6;
      default:
        return idea.id;
    }
  }

  String macroPresetName(MacroPreset preset) {
    switch (preset) {
      case MacroPreset.auto:
        return macroPresetAuto;
      case MacroPreset.balanced:
        return macroPresetBalanced;
      case MacroPreset.highProtein:
        return macroPresetHighProtein;
      case MacroPreset.lowCarb:
        return macroPresetLowCarb;
      case MacroPreset.custom:
        return macroPresetCustom;
    }
  }

  String macroPresetBlurb(MacroPreset preset) {
    switch (preset) {
      case MacroPreset.auto:
        return macroPresetAutoBlurb;
      case MacroPreset.balanced:
        return macroPresetBalancedBlurb;
      case MacroPreset.highProtein:
        return macroPresetHighProteinBlurb;
      case MacroPreset.lowCarb:
        return macroPresetLowCarbBlurb;
      case MacroPreset.custom:
        return macroPresetCustomBlurb;
    }
  }

  String foodSourceLabel(FoodSource source) {
    switch (source) {
      case FoodSource.manual:
        return foodSourceManual;
      case FoodSource.database:
        return foodSourceDatabase;
      case FoodSource.parsed:
        return foodSourceParsed;
      case FoodSource.ai:
        return foodSourceAi;
      case FoodSource.barcode:
        return foodSourceBarcode;
    }
  }

  String dietName(FoodDiet diet) {
    switch (diet) {
      case FoodDiet.vegan:
        return dietVegan;
      case FoodDiet.vegetarian:
        return dietVegetarian;
      case FoodDiet.omnivore:
        return dietOmnivore;
    }
  }
}

/// The JSON shapes the prompts ask for. Kept out of the translations: they
/// are code, not language, and ICU would read their braces as placeholders.
/// The meal estimate's shape comes from the core, which parses it.
const String kFoodEstimateFormat = kFoodEstimateJson;
const String kTargetProposalFormat =
    '{"kcal":0,"protein_pct":0,"carbs_pct":0,"fat_pct":0,"reason":"..."}';

/// The nutrition assistant's prompts in the language the user reads.
class LocalizedNutritionPrompts implements NutritionPromptBuilder {
  const LocalizedNutritionPrompts(this.l10n);

  final AppLocalizations l10n;

  @override
  String estimateFoods(String text) =>
      l10n.promptFoodEstimate(text, kFoodEstimateFormat);

  @override
  String mealIdeas({
    required MealSlotKind slot,
    required int kcal,
    required int proteinG,
    String? wish,
  }) =>
      l10n.promptMealIdeas(
        _slotName(slot),
        kcal,
        proteinG,
        wish == null || wish.trim().isEmpty ? '-' : wish.trim(),
      );

  @override
  String adjustTargets({required NutritionPlan plan, required String wish}) =>
      l10n.promptAdjustTargets(
        plan.kcal,
        plan.proteinG,
        plan.carbsG,
        plan.fatG,
        plan.tdee,
        wish,
        kMinCustomKcal,
        kMaxCustomKcal,
        kTargetProposalFormat,
      );

  String _slotName(MealSlotKind slot) {
    switch (slot) {
      case MealSlotKind.breakfast:
        return l10n.mealBreakfast;
      case MealSlotKind.lunch:
        return l10n.mealLunch;
      case MealSlotKind.snack:
        return l10n.mealSnack;
      case MealSlotKind.dinner:
        return l10n.mealDinner;
    }
  }
}
