import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/household_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/household_providers.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// A planned meal: what is in it, who eats how much, and "eaten as
/// planned" — one tap into the diary with the user's own portion.
Future<void> showRecipeSheet(
  BuildContext context,
  WidgetRef ref,
  PlanEntry entry,
  Recipe recipe,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (BuildContext context, ScrollController scroll) =>
            _RecipeSheet(entry: entry, recipe: recipe, scroll: scroll),
      ),
    );

class _RecipeSheet extends ConsumerWidget {
  const _RecipeSheet({
    required this.entry,
    required this.recipe,
    required this.scroll,
  });

  final PlanEntry entry;
  final Recipe recipe;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final Household? household = ref.watch(householdProvider).valueOrNull;
    final String me = ref.watch(repositoryProvider).userId;
    final double mine = entry.portionFor(me);
    final Nutrients myShare = recipe.perServing.scaled(mine);

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text(recipe.title, style: text.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${l10n.mealName(entry.slot)} · ${l10n.formatDay(entry.day)}'
          '${recipe.minutes == null ? '' : ' · ${l10n.planMinutes(recipe.minutes!)}'}',
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        if (household != null && household.members.length > 1)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final HouseholdMember m in household.members)
                Chip(
                  avatar: Text(m.emoji),
                  label: Text(
                      '${m.displayName} · ${l10n.portionLabel(entry.portionFor(m.userId))}'),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          color: AppColors.surfaceHigh,
          child: Text(
            l10n.recipeYourShare(
              l10n.portionLabel(mine),
              myShare.kcal.round(),
              myShare.proteinG.round(),
            ),
            style: text.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const Key('eaten-as-planned'),
          onPressed: mine <= 0
              ? null
              : () async {
                  await ref.read(appStateProvider.notifier).logFood(FoodEntry(
                        id: newEventId(),
                        day: entry.day,
                        meal: entry.slot,
                        name: recipe.title,
                        grams: 0,
                        nutrients: myShare,
                        source: FoodSource.plan,
                      ));
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.recipeLogged)),
                  );
                },
          icon: const Icon(Icons.check, size: 18),
          label: Text(l10n.recipeEatenAsPlanned),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.recipeIngredients(recipe.servings), style: text.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        for (final Ingredient i in recipe.ingredients)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 90,
                  child: Text(l10n.quantityLabel(i.quantity),
                      style:
                          text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                ),
                Expanded(child: Text(i.name, style: text.bodyMedium)),
              ],
            ),
          ),
        if (recipe.steps.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.recipeSteps, style: text.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          for (int n = 0; n < recipe.steps.length; n++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('${n + 1}. ${recipe.steps[n]}', style: text.bodyMedium),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.recipePerServing(
            recipe.perServing.kcal.round(),
            recipe.perServing.proteinG.round(),
            recipe.perServing.carbsG.round(),
            recipe.perServing.fatG.round(),
          ),
          style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton.icon(
          onPressed: () async {
            await ref.read(householdActionsProvider).removeEntry(entry.id);
            if (context.mounted) Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: Text(l10n.recipeRemove),
        ),
      ],
    );
  }
}

/// Adds a meal to a slot by hand: a title and, if known, the calories of a
/// portion. The planner and the chat fill recipes in full; this is for
/// "pizza on Friday".
Future<void> showAddMealSheet(
  BuildContext context,
  WidgetRef ref,
  DayKey day,
  MealSlotKind slot,
) async {
  final AppLocalizations l10n = context.l10n;
  final TextEditingController title = TextEditingController();
  final TextEditingController kcal = TextEditingController();
  final bool? saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('${l10n.mealName(slot)} · ${l10n.formatDay(day)}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('add-meal-title'),
            controller: title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.addMealTitle),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: kcal,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.addMealKcal),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const Key('add-meal-save'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    ),
  );
  if (saved == true && title.text.trim().isNotEmpty) {
    await ref.read(householdActionsProvider).setMeal(
          day,
          slot,
          Recipe(
            id: newEventId(),
            title: title.text.trim(),
            servings: 1,
            ingredients: const <Ingredient>[],
            perServing: Nutrients(
              kcal: double.tryParse(kcal.text.trim()) ?? 0,
              proteinG: 0,
              carbsG: 0,
              fatG: 0,
            ),
          ),
        );
  }
  title.dispose();
  kcal.dispose();
}
