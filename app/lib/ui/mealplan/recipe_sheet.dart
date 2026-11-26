import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../data/household_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/household_providers.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../funki/funki_widgets.dart';
import '../nutrition/add_food_screen.dart';
import '../nutrition/food_compose.dart';
import '../widgets/app_card.dart';
import 'household_load_error.dart';

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

class _RecipeSheet extends ConsumerStatefulWidget {
  const _RecipeSheet({
    required this.entry,
    required this.recipe,
    required this.scroll,
  });

  final PlanEntry entry;
  final Recipe recipe;
  final ScrollController scroll;

  @override
  ConsumerState<_RecipeSheet> createState() => _RecipeSheetState();
}

class _RecipeSheetState extends ConsumerState<_RecipeSheet> {
  /// One write at a time: a second tap on "eaten" would log the meal twice
  /// and pop the screen under the sheet.
  bool _busy = false;

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object {
      if (mounted) showHouseholdSaveFailed(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _eaten() => _guard(() async {
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        final String done = context.l10n.recipeLogged;
        await ref
            .read(householdActionsProvider)
            .eatAsPlanned(widget.entry, widget.recipe);
        if (!mounted) return;
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(content: Text(done)));
      });

  /// Off the plan at once, with the way back in the snackbar.
  Future<void> _remove() => _guard(() async {
        final AppLocalizations l10n = context.l10n;
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        final HouseholdActions actions = ref.read(householdActionsProvider);
        final PlanEntry entry = widget.entry;
        await actions.removeEntry(entry.id);
        if (!mounted) return;
        Navigator.of(context).pop();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(l10n.planMealRemoved(widget.recipe.title)),
            // An undo is offered for a moment; with an action a snackbar
            // would otherwise stay until dismissed.
            persist: false,
            action: SnackBarAction(
              label: l10n.actionUndo,
              onPressed: () => actions.restoreEntry(entry).catchError(
                  (Object _) => messenger.showSnackBar(
                      SnackBar(content: Text(l10n.householdSaveFailed)))),
            ),
          ));
      });

  @override
  Widget build(BuildContext context) {
    final PlanEntry entry = widget.entry;
    final Recipe recipe = widget.recipe;
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
      controller: widget.scroll,
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
              onPressed: _busy ? null : _eaten,
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
          key: const Key('recipe-remove'),
          onPressed: _busy ? null : _remove,
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: Text(l10n.recipeRemove),
        ),
      ],
    );
  }
}

/// A meal for a slot — eaten or planned, and the sheet asks which only
/// when both can be.
///
/// Eaten ("what did you eat?"): the user describes it, calories are theirs
/// to give or leave out, and Funki makes diary entries of it — amounts,
/// calories, macros. Nothing is suggested and nothing is discussed; a photo
/// of the plate does the same.
///
/// Planned ("what's for dinner?"): a name and, if known, the calories of a
/// portion — Funki writes the full recipe of it, with ingredients for the
/// list — or one of the app's meal ideas in a tap.
///
/// Either way the entry can be saved as typed, without Funki.
Future<void> showAddMealSheet(
  BuildContext context,
  WidgetRef ref,
  DayKey day,
  MealSlotKind slot,
) async {
  final AppSnapshot? snapshot = ref.read(appStateProvider).valueOrNull;
  // Ranked against the user's own target for the slot when they have one.
  final MealSlot? target = snapshot?.plan?.nutrition?.meals
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
  final bool canLogEaten = snapshot?.plan?.nutrition != null &&
      !day.isAfter(snapshot!.today);
  // The row that opened the sheet may be rebuilt away while it is open — a
  // realtime tick is enough — and its ref with it: take what is needed now.
  final HouseholdActions actions = ref.read(householdActionsProvider);
  final AppController diary = ref.read(appStateProvider.notifier);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final NavigatorState navigator = Navigator.of(context);
  final AppLocalizations l10n = context.l10n;
  final Locale locale = Localizations.localeOf(context);
  final MealPlanner? planner =
      await ref.read(mealPlannerProvider.future).catchError((Object _) => null);
  final NutritionAssistant? assistant = await ref
      .read(nutritionAssistantProvider.future)
      .catchError((Object _) => null);
  final List<PlanFor> people = <PlanFor>[
    for (final HouseholdMember m
        in ref.read(householdProvider).valueOrNull?.members ??
            const <HouseholdMember>[])
      m.toPlanFor(),
  ];
  if (!context.mounted) return;
  final Object? chosen = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    // Tall with the keyboard up: it stops below the status bar.
    useSafeArea: true,
    builder: (BuildContext context) => _AddMealSheet(
      day: day,
      slot: slot,
      ideas: ideas,
      canLogEaten: canLogEaten,
      funkiEstimates: assistant != null,
      composeEaten: (String text, double? kcal) async {
        final ComposedFood food = await composeFood(text,
            locale: locale, assistant: assistant, kcal: kcal);
        if (food.items.isNotEmpty) return (items: food.items, problem: null);
        return (
          items: null,
          problem: food.failure != null
              ? l10n.aiErrorMessage(food.failure!)
              : assistant == null
                  ? l10n.foodQuickNeedsAi(food.unknown.join(', '))
                  : l10n.foodAiFailed,
        );
      },
      askFunki: planner == null
          ? null
          : (String title, int? kcal) async {
              Object? failure;
              final ProposedMeal? meal = await planner.draftMeal(
                MealDraftRequest(
                  day: day,
                  slot: slot,
                  people: people,
                  title: title,
                  kcalPerServing: kcal,
                ),
                onError: (Object error) => failure = error,
              );
              if (meal != null) return (recipe: meal.recipe, problem: null);
              return (
                recipe: null,
                problem: failure != null
                    ? l10n.aiErrorMessage(failure!)
                    : l10n.addMealFunkiFailed,
              );
            },
    ),
  );
  if (identical(chosen, _AddMealSheet.toDiary)) {
    await navigator.push<void>(MaterialPageRoute<void>(
      builder: (BuildContext context) => AddFoodScreen(
        meal: slot,
        day: day,
        startOn: FoodEntryWay.photo,
      ),
    ));
    return;
  }
  // Eaten: into the diary as it was eaten — not onto the household's plan,
  // where it would be portioned for everyone.
  if (chosen is _EatenMeal) {
    for (final ComposedItem item in chosen.items) {
      await diary.logFood(item.toEntry(day, slot));
    }
    messenger.showSnackBar(SnackBar(
      content: Text(l10n.addMealInDiary(
          chosen.items.map((ComposedItem i) => i.name).join(', '))),
    ));
    return;
  }
  if (chosen is! _AddedMeal) return;
  try {
    await actions.setMeal(day, slot, chosen.recipe, fromAi: chosen.fromAi);
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.householdSaveFailed)));
  }
}

/// A planned meal the sheet hands back, and whether Funki wrote it.
class _AddedMeal {
  const _AddedMeal(this.recipe, {this.fromAi = false});

  final Recipe recipe;
  final bool fromAi;
}

/// What was eaten, as diary lines.
class _EatenMeal {
  const _EatenMeal(this.items);

  final List<ComposedItem> items;
}

/// Funki's recipe for a name and calories — or why there is none.
typedef FunkiRecipe = Future<({Recipe? recipe, String? problem})> Function(
    String title, int? kcal);

/// Diary lines for a description and, if known, its calories — or why
/// there are none.
typedef EatenComposer
    = Future<({List<ComposedItem>? items, String? problem})> Function(
        String text, double? kcal);

class _AddMealSheet extends StatefulWidget {
  const _AddMealSheet({
    required this.day,
    required this.slot,
    required this.ideas,
    required this.canLogEaten,
    required this.composeEaten,
    required this.funkiEstimates,
    this.askFunki,
  });

  /// What the sheet hands back for "a photo instead".
  static const Object toDiary = Object();

  final DayKey day;
  final MealSlotKind slot;
  final List<MealIdea> ideas;

  /// The user keeps a diary and the day has come.
  final bool canLogEaten;

  final EatenComposer composeEaten;

  /// Whether Funki can estimate what the food table does not know.
  final bool funkiEstimates;

  /// Null without a reachable model: planned meals are saved as typed.
  final FunkiRecipe? askFunki;

  @override
  State<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends State<_AddMealSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _kcal = TextEditingController();

  /// A second tap while the sheet closes would pop the screen beneath it.
  bool _closing = false;

  /// Asked to save without a name, or — eaten, without Funki — without
  /// calories: the fields say so.
  bool _titleMissing = false;
  bool _kcalMissing = false;

  /// Eaten already, so it is a diary entry: a day gone by was; today's
  /// meal was if its time has passed.
  late bool _eaten = widget.canLogEaten &&
      (widget.day.isBefore(DayKey.today()) ||
          mealLikelyEaten(widget.slot, DateTime.now()));

  /// While Funki works, and what went wrong if he could not.
  bool _asking = false;
  String? _funkiProblem;

  /// Whether Funki has a part in what the main button does.
  bool get _withFunki =>
      _eaten ? widget.funkiEstimates : widget.askFunki != null;

  @override
  void dispose() {
    _title.dispose();
    _kcal.dispose();
    super.dispose();
  }

  void _close([Object? result]) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(result);
  }

  void _pick(String name, {double kcal = 0, double proteinG = 0}) =>
      _close(_AddedMeal(
        Recipe(
          id: newEventId(),
          title: name,
          servings: 1,
          ingredients: const <Ingredient>[],
          perServing:
              Nutrients(kcal: kcal, proteinG: proteinG, carbsG: 0, fatG: 0),
        ),
      ));

  // A German keyboard types "650,5".
  double? get _typedKcal {
    final double? typed =
        double.tryParse(_kcal.text.trim().replaceAll(',', '.'));
    return typed == null || typed <= 0 ? null : typed;
  }

  bool _named() {
    if (_title.text.trim().isNotEmpty) return true;
    setState(() => _titleMissing = true);
    return false;
  }

  /// The main button. Eaten: diary entries of what was described, the
  /// calories estimated when they were left out. Planned: Funki's recipe
  /// of it — or, without him, the meal as typed.
  Future<void> _go() async {
    if (_asking || _closing) return;
    if (_eaten) {
      if (!_named()) return;
      await _compose();
    } else if (widget.askFunki != null) {
      await _askFunki();
    } else {
      _saveAsTyped();
    }
  }

  Future<void> _compose() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _asking = true;
      _funkiProblem = null;
    });
    final ({List<ComposedItem>? items, String? problem}) answer =
        await widget.composeEaten(_title.text.trim(), _typedKcal);
    if (!mounted) return;
    if (answer.items != null) {
      _close(_EatenMeal(answer.items!));
      return;
    }
    setState(() {
      _asking = false;
      _funkiProblem = answer.problem;
    });
  }

  /// As typed, without Funki. The calories stay optional for a planned
  /// meal; a diary line needs them.
  void _saveAsTyped() {
    if (!_named()) return;
    final String title = _title.text.trim();
    final double? kcal = _typedKcal;
    if (!_eaten) {
      _pick(title, kcal: kcal ?? 0);
      return;
    }
    if (kcal == null) {
      setState(() => _kcalMissing = true);
      return;
    }
    _close(_EatenMeal(<ComposedItem>[
      ComposedItem(
        name: title,
        grams: 0,
        nutrients: Nutrients(kcal: kcal, proteinG: 0, carbsG: 0, fatG: 0),
        source: FoodSource.manual,
      ),
    ]));
  }

  /// What was typed, to Funki: a full recipe of it. Without a name he picks
  /// something for the slot.
  Future<void> _askFunki() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _asking = true;
      _funkiProblem = null;
      _titleMissing = false;
    });
    final ({Recipe? recipe, String? problem}) answer = await widget.askFunki!(
      _title.text.trim(),
      _typedKcal?.round(),
    );
    if (!mounted) return;
    if (answer.recipe != null) {
      _close(_AddedMeal(answer.recipe!, fromAi: true));
      return;
    }
    setState(() {
      _asking = false;
      _funkiProblem = answer.problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final bool withFunki = _withFunki;
    // The fields scroll and the buttons stay put above the keyboard: on a
    // phone the keyboard takes half the screen, and a button pushed under
    // it cannot be pressed.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                        '${l10n.mealName(widget.slot)} · ${l10n.formatDay(widget.day)}',
                        style: text.titleLarge),
                    if (widget.canLogEaten) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      SegmentedButton<bool>(
                        key: const Key('add-meal-eaten'),
                        showSelectedIcon: false,
                        segments: <ButtonSegment<bool>>[
                          ButtonSegment<bool>(
                              value: true, label: Text(l10n.addMealModeEaten)),
                          ButtonSegment<bool>(
                              value: false,
                              label: Text(l10n.addMealModePlanned)),
                        ],
                        selected: <bool>{_eaten},
                        onSelectionChanged: _asking
                            ? null
                            : (Set<bool> picked) => setState(() {
                                  _eaten = picked.first;
                                  _funkiProblem = null;
                                  _kcalMissing = false;
                                }),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      key: const Key('add-meal-title'),
                      controller: _title,
                      autofocus: true,
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (_titleMissing) {
                          setState(() => _titleMissing = false);
                        }
                      },
                      decoration: InputDecoration(
                        labelText:
                            _eaten ? l10n.addMealEatenTitle : l10n.addMealTitle,
                        hintText: _eaten ? l10n.addMealEatenHint : null,
                        errorText: _titleMissing
                            ? (_eaten
                                ? l10n.foodManualNameMissing
                                : l10n.addMealTitleMissing)
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      key: const Key('add-meal-kcal'),
                      controller: _kcal,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (_kcalMissing) setState(() => _kcalMissing = false);
                      },
                      onSubmitted: (_) => _go(),
                      decoration: InputDecoration(
                        labelText: withFunki
                            ? l10n.addMealKcalFunki
                            : (_eaten ? l10n.addMealKcalEaten : l10n.addMealKcal),
                        errorText:
                            _kcalMissing ? l10n.addMealKcalMissing : null,
                      ),
                    ),
                    // Ideas are for planning; what was eaten is not up for
                    // suggestions.
                    if (!_eaten && widget.ideas.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.addMealIdeas,
                        style: text.labelSmall
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
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs + 2),
                            child: Row(
                              children: <Widget>[
                                const Icon(Icons.lightbulb_outline,
                                    size: 18, color: AppColors.textTertiary),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(l10n.mealIdeaName(idea),
                                      style: text.bodyMedium),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  '~${l10n.diaryEntryKcal(idea.kcal)}',
                                  style: text.bodySmall?.copyWith(
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            if (_funkiProblem != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                child: Text(
                  _funkiProblem!,
                  key: const Key('add-meal-funki-problem'),
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: AppColors.danger),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: FilledButton.icon(
                key: const Key('add-meal-save'),
                onPressed: _asking ? null : _go,
                icon: _asking
                    ? const FunkiThinking(color: AppColors.onPrimary)
                    : withFunki
                        ? const FunkiAvatar(size: 26)
                        : const Icon(Icons.check, size: 18),
                label: Text(_asking
                    ? (_eaten ? l10n.funkiThinking : l10n.addMealFunkiWorking)
                    : _eaten
                        ? l10n.addMealGoEaten
                        : withFunki
                            ? l10n.addMealFunki
                            : l10n.actionSave),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 0),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                children: <Widget>[
                  if (widget.canLogEaten && _eaten)
                    TextButton.icon(
                      key: const Key('add-meal-to-diary'),
                      onPressed:
                          _asking ? null : () => _close(_AddMealSheet.toDiary),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: Text(l10n.addMealToDiary),
                    ),
                  if (withFunki)
                    TextButton(
                      key: const Key('add-meal-manual'),
                      onPressed: _asking ? null : _saveAsTyped,
                      child: Text(l10n.addMealAsTyped),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
