import 'package:hundred_core/hundred_core.dart';
import 'package:intl/intl.dart';

import 'core_l10n.dart';
import 'generated/app_localizations.dart';
import 'plan_l10n.dart';

/// Wording for the meal plan, the shopping list and the household.
extension MealPlanL10n on AppLocalizations {
  String shopCategoryName(ShopCategory category) => switch (category) {
        ShopCategory.produce => shopProduce,
        ShopCategory.bakery => shopBakery,
        ShopCategory.dairy => shopDairy,
        ShopCategory.meat => shopMeat,
        ShopCategory.fish => shopFish,
        ShopCategory.pantry => shopPantry,
        ShopCategory.frozen => shopFrozen,
        ShopCategory.drinks => shopDrinks,
        ShopCategory.household => shopHousehold,
        ShopCategory.other => shopOther,
        ShopCategory.staples => shopStaples,
      };

  /// "Quick & ready", "Everyday", "From scratch".
  String cookingLevelName(CookingLevel level) => switch (level) {
        CookingLevel.convenience => cookingConvenience,
        CookingLevel.everyday => cookingEveryday,
        CookingLevel.scratch => cookingScratch,
      };

  /// One line on what a level means for the shopping and the cooking.
  String cookingLevelHint(CookingLevel level) => switch (level) {
        CookingLevel.convenience => cookingConvenienceHint,
        CookingLevel.everyday => cookingEverydayHint,
        CookingLevel.scratch => cookingScratchHint,
      };

  /// What the model is told about a level.
  String promptCookingLevel(CookingLevel level) => switch (level) {
        CookingLevel.convenience => promptCookConvenience,
        CookingLevel.everyday => promptCookEveryday,
        CookingLevel.scratch => promptCookScratch,
      };

  /// "380 g", "1,5 l", "3 Stk.", "2 EL", "1 Prise".
  String quantityLabel(Quantity q) {
    final NumberFormat number = NumberFormat.decimalPattern(localeName)
      ..maximumFractionDigits = 1;
    return switch (q.unit) {
      QtyUnit.g when q.amount >= 1000 => '${number.format(q.amount / 1000)} kg',
      QtyUnit.g => '${number.format(q.amount)} g',
      QtyUnit.ml when q.amount >= 1000 => '${number.format(q.amount / 1000)} l',
      QtyUnit.ml => '${number.format(q.amount)} ml',
      QtyUnit.piece => qtyPieces(number.format(q.amount)),
      QtyUnit.tbsp => qtyTbsp(number.format(q.amount)),
      // "0,3 TL Pfeffer" is not how anyone measures pepper.
      QtyUnit.tsp when q.amount < 0.4 => qtyPinch,
      QtyUnit.tsp => qtyTsp(number.format(q.amount)),
    };
  }

  /// "Every Saturday", "Every 3 days", "Whenever you like".
  String cadenceLabel(ShoppingCadence cadence) => switch (cadence) {
        WeeklyShopping(:final int weekday) => cadenceWeekly(weekdayLong(weekday)),
        EveryNDays(:final int days) => cadenceEveryNDays(days),
        ManualShopping() => cadenceManual,
      };

  String weekdayLong(int weekday) =>
      DateFormat.EEEE(localeName).format(DateTime(2026, 11, 16 + weekday - 1));

  /// "Sa, 21.11. – Fr, 27.11."
  String periodLabel(ShoppingPeriod period) => period.lengthDays == 1
      ? formatDay(period.start)
      : '${formatDay(period.start)} – ${formatDay(period.end)}';

  /// "1,25 portions" — for the portion chips.
  String portionLabel(double portions) {
    final NumberFormat number = NumberFormat.decimalPattern(localeName)
      ..maximumFractionDigits = 2;
    return portionsCount(number.format(portions));
  }
}

/// The meal plan prompt, in the language the user reads.
class LocalizedMealPlanPrompts implements MealPlanPromptBuilder {
  const LocalizedMealPlanPrompts(this.l10n);

  final AppLocalizations l10n;

  @override
  String proposeWeek(MealPlanRequest request) {
    final String days = request.days
        .map((DayKey d) =>
            '- $d (${l10n.weekdayShort(d.toDateTime().weekday)}): '
            '${request.slots.map((MealSlotKind s) => '${s.name} (${l10n.mealName(s)})').join(', ')}')
        .join('\n');
    final String people = request.people.map(_person).join('\n');
    final List<String> extra = <String>[
      if (request.wish != null && request.wish!.trim().isNotEmpty)
        l10n.promptPlanWish(request.wish!.trim()),
      if (request.maxMinutes != null) l10n.promptPlanMinutes(request.maxMinutes!),
      if (request.plannedTitles.isNotEmpty)
        l10n.promptPlanAlreadyPlanned(request.plannedTitles.join(', ')),
      if (request.avoidTitles.isNotEmpty)
        l10n.promptPlanAvoid(request.avoidTitles.join(', ')),
      l10n.promptCookingLevel(request.level),
    ];
    return l10n.promptMealPlan(
      days,
      people,
      extra.join('\n'),
      l10n.promptRecipeRules,
      kMealPlanJson,
    );
  }

  @override
  String draftMeal(MealDraftRequest request) {
    final List<String> extra = <String>[
      if (request.hasTitle)
        l10n.promptMealDraftTitle(request.title!.trim())
      else
        l10n.promptMealDraftAny,
      if (request.kcalPerServing != null)
        l10n.promptMealDraftKcal(request.kcalPerServing!),
      if (request.maxMinutes != null) l10n.promptPlanMinutes(request.maxMinutes!),
      l10n.promptCookingLevel(request.level),
    ];
    return l10n.promptMealDraft(
      '${request.slot.name} (${l10n.mealName(request.slot)})',
      '${request.day} (${l10n.weekdayShort(request.day.toDateTime().weekday)})',
      request.people.map(_person).join('\n'),
      extra.join('\n'),
      l10n.promptRecipeRules,
      kMealPlanJson,
    );
  }

  String _person(PlanFor p) {
    final List<String> parts = <String>[p.name];
    if (p.dailyKcal != null) parts.add(l10n.promptPlanKcal(p.dailyKcal!));
    if (p.proteinG != null) parts.add(l10n.promptPlanProtein(p.proteinG!));
    if (p.diet != null && p.diet!.isNotEmpty) parts.add(p.diet!);
    if (p.allergies.isNotEmpty) {
      parts.add(l10n.promptPlanAllergies(p.allergies.join(', ')));
    }
    if (p.dislikes.isNotEmpty) {
      parts.add(l10n.promptPlanDislikes(p.dislikes.join(', ')));
    }
    return '- ${parts.join('; ')}';
  }
}
