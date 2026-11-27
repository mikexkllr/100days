import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../state/household_providers.dart';
import '../../theme/theme.dart';
import '../funki/funki_widgets.dart';
import 'cooking_level_picker.dart';

/// The recipes a shopping list is waiting for: the planned [meals] that are
/// only a name so far, written by Funki one after the other at the cooking
/// level picked. Returns how many were written.
Future<int> showWriteRecipesSheet(
  BuildContext context,
  List<(PlanEntry, Recipe)> meals,
) async =>
    await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Closed by its button, the back gesture or a tap beside it — all of
      // which hand back what was written. A drag would not.
      enableDrag: false,
      builder: (BuildContext context) => _WriteRecipesSheet(meals: meals),
    ) ??
    0;

class _WriteRecipesSheet extends ConsumerStatefulWidget {
  const _WriteRecipesSheet({required this.meals});

  final List<(PlanEntry, Recipe)> meals;

  @override
  ConsumerState<_WriteRecipesSheet> createState() => _WriteRecipesSheetState();
}

class _WriteRecipesSheetState extends ConsumerState<_WriteRecipesSheet> {
  late CookingLevel _level = ref.read(myCookingLevelProvider);

  /// The meal being written, counted from one; zero while nothing is.
  int _working = 0;
  int _written = 0;
  String? _problem;

  /// The ids of the dishes that have their recipe: one dish planned on two
  /// days is written once.
  final Set<String> _done = <String>{};

  Future<void> _go() async {
    if (_working > 0) return;
    final AppLocalizations l10n = context.l10n;
    final HouseholdActions actions = ref.read(householdActionsProvider);
    final CookingLevel level = _level;
    unawaited(actions.rememberCooking(level));
    setState(() => _problem = null);
    String? problem;
    for (int i = 0; i < widget.meals.length; i++) {
      final (PlanEntry entry, Recipe recipe) = widget.meals[i];
      if (_done.contains(recipe.id)) continue;
      if (!mounted) return;
      setState(() => _working = i + 1);
      Object? failure;
      try {
        final RecipeRewrite? written = await actions.writeRecipe(
            entry, recipe, level,
            onError: (Object error) => failure = error);
        if (written != null) {
          _done.add(recipe.id);
          _written++;
          continue;
        }
      } on Object {
        problem = l10n.householdSaveFailed;
        break;
      }
      // Could not be asked at all — offline, the allowance used up: the
      // next dish would fare no better.
      if (failure != null) {
        problem = l10n.aiErrorMessage(failure!);
        break;
      }
      problem = l10n.recipeWriteFailed;
    }
    if (!mounted) return;
    // Everything written: back to the list. Otherwise what is missing can
    // be tried again from here.
    if (problem == null) {
      Navigator.of(context).pop(_written);
      return;
    }
    setState(() {
      _working = 0;
      _problem = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final int left = widget.meals
        .map(((PlanEntry, Recipe) m) => m.$2.id)
        .toSet()
        .difference(_done)
        .length;
    return PopScope(
      // What was written stays written, however the sheet is closed.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop && _working == 0) Navigator.of(context).pop(_written);
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l10n.writeRecipesTitle, style: text.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.writeRecipesBody,
                  style:
                      text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final (PlanEntry entry, Recipe recipe) in widget.meals)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              _done.contains(recipe.id)
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 16,
                              color: _done.contains(recipe.id)
                                  ? AppColors.success
                                  : AppColors.textTertiary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child:
                                  Text(recipe.title, style: text.bodyMedium),
                            ),
                            Text(
                              l10n.formatDay(entry.day),
                              style: text.bodySmall
                                  ?.copyWith(color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              CookingLevelPicker(
                level: _level,
                onChanged: _working > 0
                    ? null
                    : (CookingLevel level) => setState(() => _level = level),
              ),
              if (_problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _problem!,
                    key: const Key('write-recipes-problem'),
                    style: text.bodySmall?.copyWith(color: AppColors.danger),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: const Key('write-recipes-go'),
                onPressed: _working > 0 || left == 0 ? null : _go,
                icon: _working > 0
                    ? const FunkiThinking(color: AppColors.onPrimary)
                    : const FunkiAvatar(size: 26),
                label: Text(_working > 0
                    ? l10n.writeRecipesProgress(_working, widget.meals.length)
                    : l10n.writeRecipesGo(left)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
