import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../data/household_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/household_providers.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// A planned meal: what is in it, who eats how much, and — for someone who
/// keeps a diary — "eaten as planned", one tap into it with their own
/// portion. The diary offers the same tap next to the meal.
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
    final AppSnapshot? snapshot = ref.watch(appStateProvider).valueOrNull;
    // Only for a diary there is somewhere to see it, a day that has come,
    // and a meal not yet in it.
    final bool canLog = snapshot?.plan?.nutrition != null &&
        mine > 0 &&
        !entry.day.isAfter(snapshot!.today);
    final bool logged = snapshot != null &&
        eatenAsPlanned(snapshot.me.intakeOn(entry.day), entry, recipe);

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
        if (canLog) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          if (logged)
            Center(
              child: Pill(l10n.recipeInDiary,
                  color: AppColors.success, icon: Icons.check_circle),
            )
          else
            FilledButton.icon(
              key: const Key('eaten-as-planned'),
              onPressed: () async {
                await ref
                    .read(householdActionsProvider)
                    .eatAsPlanned(entry, recipe);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.recipeLogged)),
                );
              },
              icon: const Icon(Icons.check, size: 18),
              label: Text(l10n.recipeEatenAsPlanned),
            ),
        ],
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

/// Adds a meal to a slot by hand: one of the app's meal ideas in a tap, or
/// a title and, if known, the calories of a portion. The planner and the
/// chat fill recipes in full; this is for "pizza on Friday".
Future<void> showAddMealSheet(
  BuildContext context,
  WidgetRef ref,
  DayKey day,
  MealSlotKind slot,
) async {
  // Ranked against the user's own target for the slot when they have one.
  final MealSlot? target = ref
      .read(appStateProvider)
      .valueOrNull
      ?.plan
      ?.nutrition
      ?.meals
      .where((MealSlot m) => m.kind == slot)
      .firstOrNull;
  final List<MealIdea> ideas = target == null
      ? kMealIdeas.where((MealIdea i) => i.slot == slot).take(4).toList()
      : suggestMeals(
          slot: slot,
          targetKcal: target.kcal.toDouble(),
          targetProteinG: target.proteinG.toDouble(),
          count: 4,
        );
  final Recipe? chosen = await showModalBottomSheet<Recipe>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) =>
        _AddMealSheet(day: day, slot: slot, ideas: ideas),
  );
  if (chosen != null) {
    await ref.read(householdActionsProvider).setMeal(day, slot, chosen);
  }
}

class _AddMealSheet extends StatefulWidget {
  const _AddMealSheet({
    required this.day,
    required this.slot,
    required this.ideas,
  });

  final DayKey day;
  final MealSlotKind slot;
  final List<MealIdea> ideas;

  @override
  State<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends State<_AddMealSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _kcal = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _kcal.dispose();
    super.dispose();
  }

  void _pick(String name, {double kcal = 0, double proteinG = 0}) =>
      Navigator.of(context).pop(Recipe(
        id: newEventId(),
        title: name,
        servings: 1,
        ingredients: const <Ingredient>[],
        perServing:
            Nutrients(kcal: kcal, proteinG: proteinG, carbsG: 0, fatG: 0),
      ));

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('${l10n.mealName(widget.slot)} · ${l10n.formatDay(widget.day)}',
              style: Theme.of(context).textTheme.titleLarge),
          if (widget.ideas.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.addMealIdeas,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final MealIdea idea in widget.ideas)
              InkWell(
                key: Key('meal-idea-${idea.id}'),
                borderRadius: AppRadius.cardAll,
                onTap: () => _pick(
                  l10n.mealIdeaName(idea),
                  kcal: idea.kcal.toDouble(),
                  proteinG: idea.proteinG.toDouble(),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.lightbulb_outline,
                          size: 18, color: AppColors.textTertiary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(l10n.mealIdeaName(idea),
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '~${l10n.diaryEntryKcal(idea.kcal)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('add-meal-title'),
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.addMealTitle),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _kcal,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.addMealKcal),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const Key('add-meal-save'),
            onPressed: () => _title.text.trim().isEmpty
                ? Navigator.of(context).pop()
                : _pick(_title.text.trim(),
                    kcal: double.tryParse(_kcal.text.trim()) ?? 0),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );
  }
}
