import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../data/app_repository.dart';
import '../data/household_backend.dart';
import '../l10n/l10n.dart';
import 'providers.dart';

/// The household backend of the signed-in account. Tests override it.
final Provider<HouseholdBackend> householdBackendProvider =
    Provider<HouseholdBackend>((Ref ref) {
  final String userId = ref.watch(repositoryProvider).userId;
  final SupabaseHouseholdBackend backend = SupabaseHouseholdBackend(
    ref.watch(supabaseClientProvider),
    userId: userId,
  );
  ref.onDispose(() => unawaited(backend.dispose()));
  return backend;
});

/// Bumped on every change anyone in the household makes, so the plan and
/// the list refresh live while the app is open.
final StreamProvider<int> householdChangesProvider =
    StreamProvider<int>((Ref ref) async* {
  final String id = await ref.watch(householdIdProvider.future);
  var tick = 0;
  yield tick;
  await for (final void _ in ref.watch(householdBackendProvider).changes(id)) {
    yield ++tick;
  }
});

/// The user's household. A failure — offline at the first start — stays
/// cached until [retryHousehold], which every "try again" calls.
final FutureProvider<String> householdIdProvider = FutureProvider<String>(
    (Ref ref) => ref.watch(householdBackendProvider).ensureHousehold());

/// Loads the household again from its id up; everything household-shaped
/// depends on it.
void retryHousehold(WidgetRef ref) => ref.invalidate(householdIdProvider);

final FutureProvider<Household> householdProvider =
    FutureProvider<Household>((Ref ref) async {
  ref.watch(householdChangesProvider);
  final String id = await ref.watch(householdIdProvider.future);
  return ref.watch(householdBackendProvider).household(id);
});

final FutureProvider<Map<String, Recipe>> recipesProvider =
    FutureProvider<Map<String, Recipe>>((Ref ref) async {
  ref.watch(householdChangesProvider);
  final String id = await ref.watch(householdIdProvider.future);
  return ref.watch(householdBackendProvider).recipes(id);
});

/// The plan of the week starting on [weekStart].
final FutureProviderFamily<List<PlanEntry>, DayKey> weekPlanProvider =
    FutureProvider.family<List<PlanEntry>, DayKey>(
        (Ref ref, DayKey weekStart) async {
  ref.watch(householdChangesProvider);
  final String id = await ref.watch(householdIdProvider.future);
  return ref
      .watch(householdBackendProvider)
      .plan(id, weekStart, weekStart.addDays(6));
});

final FutureProvider<List<ShoppingListInfo>> openListsProvider =
    FutureProvider<List<ShoppingListInfo>>((Ref ref) async {
  ref.watch(householdChangesProvider);
  final String id = await ref.watch(householdIdProvider.future);
  return ref.watch(householdBackendProvider).openLists(id);
});

final FutureProviderFamily<List<ShoppingLine>, String> listItemsProvider =
    FutureProvider.family<List<ShoppingLine>, String>(
        (Ref ref, String listId) async {
  ref.watch(householdChangesProvider);
  return ref.watch(householdBackendProvider).items(listId);
});

/// The meal planner, or null without a reachable model.
final FutureProvider<MealPlanner?> mealPlannerProvider =
    FutureProvider<MealPlanner?>((Ref ref) async {
  final LlmClient llm = ref.watch(llmClientProvider);
  if (!llm.isReady) return null;
  final AppLocalizations l10n =
      await AppLocalizations.delegate.load(ref.watch(effectiveLocaleProvider));
  return MealPlanner(llm: llm, prompts: LocalizedMealPlanPrompts(l10n));
});

/// How much the user likes to make at home: what "plan the week" and
/// "write the recipe" start from on this phone. Everyday cooking until they
/// have picked something else.
final Provider<CookingLevel> myCookingLevelProvider =
    Provider<CookingLevel>((Ref ref) =>
        ref
            .watch(householdProvider)
            .valueOrNull
            ?.member(ref.watch(repositoryProvider).userId)
            ?.cooking ??
        CookingLevel.everyday);

/// The meals planned up to the next shopping trip whose recipe is only a
/// name so far, with that name. A list made from the plan cannot hold them:
/// what the shopping tab offers to have written first.
final FutureProvider<List<(PlanEntry, Recipe?)>> mealsWithoutRecipeProvider =
    FutureProvider<List<(PlanEntry, Recipe?)>>((Ref ref) async {
  ref.watch(householdChangesProvider);
  final String id = await ref.watch(householdIdProvider.future);
  final Household household = await ref.watch(householdProvider.future);
  final ShoppingPeriod period = household.cadence.periodFrom(DayKey.today());
  final HouseholdBackend backend = ref.watch(householdBackendProvider);
  final Map<String, Recipe> recipes = await ref.watch(recipesProvider.future);
  return <(PlanEntry, Recipe?)>[
    for (final PlanEntry entry in mealsWithoutRecipe(
      entries: await backend.plan(id, period.start, period.end),
      recipes: recipes,
      period: period,
    ))
      (entry, recipes[entry.recipeId]),
  ];
});

/// What "list from plan" did: made [list], or topped up the one already
/// open for those days. [added] is what it put on it.
class ListFromPlan {
  const ListFromPlan({
    required this.list,
    required this.created,
    required this.added,
  });

  final ShoppingListInfo list;
  final bool created;
  final List<ShoppingLine> added;
}

/// What accepting a proposal did to the plan: the meals it [added] and the
/// ones that were in their slots before — enough to take it back.
class PlanChange {
  const PlanChange({required this.added, required this.replaced});

  final List<PlanEntry> added;
  final List<PlanEntry> replaced;
}

/// A recipe written again: what the dish was [before], what it is [now],
/// and the planned meal as it was, whose portions were sized again.
class RecipeRewrite {
  const RecipeRewrite({
    required this.before,
    required this.now,
    required this.entryBefore,
  });

  final Recipe before;
  final Recipe now;
  final PlanEntry entryBefore;
}

/// Everything the plan and list screens do, in one place.
///
/// Each action reloads what it changed once it is through: realtime echoes
/// a write too, but late or — on a shop's bad reception — not at all, and
/// never for a deletion.
class HouseholdActions {
  HouseholdActions(this._ref);

  final Ref _ref;

  HouseholdBackend get _backend => _ref.read(householdBackendProvider);
  Future<String> get _id => _ref.read(householdIdProvider.future);

  /// The household, loaded if no screen has it yet — and listened to while
  /// it loads. A provider nobody listens to is not built again when what
  /// it watches changes under it, and its future then never completes:
  /// what would happen to Funki, asked on a screen without the plan, when
  /// he is the first to need the household.
  Future<Household> get _household async {
    final ProviderSubscription<AsyncValue<Household>> hold =
        _ref.listen(householdProvider, (Object? _, Object? __) {});
    try {
      return await _ref.read(householdProvider.future);
    } finally {
      hold.close();
    }
  }

  void _planChanged() {
    _ref.invalidate(weekPlanProvider);
    _ref.invalidate(recipesProvider);
  }

  void _listsChanged([String? listId]) {
    _ref.invalidate(openListsProvider);
    if (listId != null) _ref.invalidate(listItemsProvider(listId));
  }

  /// Stores [recipe] — or, when the household already has a dish of that
  /// name at that cooking level, that one (see [recipeNamed] and
  /// [reconcileRecipe]): one recipe per name and level, however often it
  /// is planned. [known] is kept up to date for the next call.
  Future<Recipe> _store(
    String householdId,
    Recipe recipe,
    Map<String, Recipe> known, {
    bool fromAi = false,
  }) async {
    final Recipe? same =
        recipeNamed(known.values, recipe.title, level: recipe.level);
    final Recipe wanted = same == null ? recipe : reconcileRecipe(same, recipe);
    if (identical(wanted, same)) return same!;
    final Recipe stored =
        await _backend.saveRecipe(householdId, wanted, fromAi: fromAi);
    known[stored.id] = stored;
    return stored;
  }

  /// Writes accepted proposals: each recipe, then its slot with portions
  /// sized for every member who shares their target. A slot that already
  /// has a meal gets the new one instead — planning a week twice must not
  /// put two dinners on a day — which also makes a retry after a failed
  /// save pick up where it broke off. Returns what changed.
  Future<PlanChange> acceptProposal(List<ProposedMeal> meals) async {
    final List<PlanEntry> added = <PlanEntry>[];
    final List<PlanEntry> replaced = <PlanEntry>[];
    if (meals.isEmpty) return PlanChange(added: added, replaced: replaced);
    final String id = await _id;
    final Household household = await _household;
    final List<DayKey> days = meals.map((ProposedMeal m) => m.day).toList()
      ..sort();
    final List<PlanEntry> before =
        await _backend.plan(id, days.first, days.last);
    final Map<String, Recipe> known =
        Map<String, Recipe>.of(await _backend.recipes(id));
    try {
      for (final ProposedMeal meal in meals) {
        final Recipe recipe =
            await _store(id, meal.recipe, known, fromAi: true);
        final PlanEntry entry = PlanEntry(
          id: newEventId(),
          day: meal.day,
          slot: meal.slot,
          recipeId: recipe.id,
          portions: portionsForHousehold(household, recipe, meal.slot),
        );
        await _backend.saveEntry(id, entry);
        added.add(entry);
        for (final PlanEntry old in before) {
          if (old.day == meal.day && old.slot == meal.slot) {
            await _backend.removeEntry(old.id);
            replaced.add(old);
          }
        }
      }
    } finally {
      _planChanged();
    }
    return PlanChange(added: added, replaced: replaced);
  }

  /// Takes [change] back: the meals it added go, the ones they replaced
  /// return. The recipes stay — a dish written is a dish the household has.
  Future<void> undoPlanChange(PlanChange change) async {
    final String id = await _id;
    try {
      for (final PlanEntry entry in change.added) {
        await _backend.removeEntry(entry.id);
      }
      for (final PlanEntry entry in change.replaced) {
        await _backend.saveEntry(id, entry);
      }
    } finally {
      _planChanged();
    }
  }

  /// Writes the recipe of the meal planned on [entry] — for the first time,
  /// when [recipe] is only a name, or again at another [level]. The dish
  /// keeps its name and its place in the plan (see [Recipe.rewrittenAs]),
  /// aims at the calories it had, and [entry]'s portions are sized to what
  /// came out.
  ///
  /// Null when the model gave nothing usable, or — then [onError] hears
  /// why — could not be asked at all.
  Future<RecipeRewrite?> writeRecipe(
    PlanEntry entry,
    Recipe recipe,
    CookingLevel level, {
    AiErrorCallback? onError,
  }) async {
    final MealPlanner? planner = await _ref.read(mealPlannerProvider.future);
    if (planner == null) return null;
    final Household household = await _household;
    final int kcal = recipe.perServing.kcal.round();
    final ProposedMeal? written = await planner.draftMeal(
      MealDraftRequest(
        day: entry.day,
        slot: entry.slot,
        people: <PlanFor>[
          for (final HouseholdMember m in household.members) m.toPlanFor(),
        ],
        title: recipe.title,
        kcalPerServing: kcal > 0 ? kcal : null,
        level: level,
      ),
      onError: onError,
    );
    if (written == null) return null;
    final String id = await _id;
    try {
      final Recipe now = await _backend.saveRecipe(
          id, recipe.rewrittenAs(written.recipe),
          fromAi: true);
      await _backend.saveEntry(
        id,
        PlanEntry(
          id: entry.id,
          day: entry.day,
          slot: entry.slot,
          recipeId: now.id,
          portions: portionsForHousehold(household, now, entry.slot),
          note: entry.note,
        ),
      );
      return RecipeRewrite(before: recipe, now: now, entryBefore: entry);
    } finally {
      _planChanged();
    }
  }

  /// Puts the recipe back as it was before [rewrite], and the meal's
  /// portions with it.
  Future<void> undoRewrite(RecipeRewrite rewrite) async {
    final String id = await _id;
    try {
      await _backend.saveRecipe(id, rewrite.before,
          fromAi: rewrite.before.isWritten);
      await _backend.saveEntry(id, rewrite.entryBefore);
    } finally {
      _planChanged();
    }
  }

  /// Remembers [level] as how the user likes to cook, so the next plan
  /// starts from it. Quietly: a choice of chips is not worth an error.
  Future<void> rememberCooking(CookingLevel level) async {
    try {
      final Household household = await _household;
      final HouseholdMember? me =
          household.member(_ref.read(repositoryProvider).userId);
      if (me == null || me.cooking == level) return;
      await updateMe(me.withTastes(cooking: level));
    } on Object {
      // Offline: the next choice tries again.
    }
  }

  /// Puts [recipe] on [day]'s [slot] and returns the entry as stored —
  /// with the household's own recipe of that name, if it has one.
  Future<(PlanEntry, Recipe)> setMeal(DayKey day, MealSlotKind slot, Recipe recipe,
      {bool fromAi = false, String? replacing}) async {
    final String id = await _id;
    final Household household = await _household;
    final Recipe stored = await _store(
        id, recipe, Map<String, Recipe>.of(await _backend.recipes(id)),
        fromAi: fromAi);
    if (replacing != null) await _backend.removeEntry(replacing);
    final PlanEntry entry = PlanEntry(
      id: newEventId(),
      day: day,
      slot: slot,
      recipeId: stored.id,
      portions: portionsForHousehold(household, stored, slot),
    );
    await _backend.saveEntry(id, entry);
    _planChanged();
    return (entry, stored);
  }

  Future<void> removeEntry(String entryId) async {
    await _backend.removeEntry(entryId);
    _planChanged();
  }

  /// Puts a removed meal back as it was — the undo of [removeEntry].
  Future<void> restoreEntry(PlanEntry entry) async {
    await _backend.saveEntry(await _id, entry);
    _planChanged();
  }

  /// Moves the meal on [entry] to [day] and [slot]. A meal already there
  /// takes [entry]'s place: moving Wednesday's dinner to Thursday swaps the
  /// two. Returns the entries as they are now, the moved one first.
  Future<List<PlanEntry>> moveEntry(
      PlanEntry entry, DayKey day, MealSlotKind slot) async {
    final String id = await _id;
    final List<PlanEntry> there = (await _backend.plan(id, day, day))
        .where((PlanEntry e) => e.slot == slot && e.id != entry.id)
        .toList();
    PlanEntry at(PlanEntry e, DayKey d, MealSlotKind s) => PlanEntry(
          id: e.id,
          day: d,
          slot: s,
          recipeId: e.recipeId,
          portions: e.portions,
          note: e.note,
        );
    final List<PlanEntry> now = <PlanEntry>[
      at(entry, day, slot),
      for (final PlanEntry other in there) at(other, entry.day, entry.slot),
    ];
    try {
      for (final PlanEntry moved in now) {
        await _backend.saveEntry(id, moved);
      }
    } finally {
      _planChanged();
    }
    return now;
  }

  /// Puts the user's own portion of a planned meal into their diary — the
  /// one place where the plan turns into what was eaten.
  Future<void> eatAsPlanned(PlanEntry entry, Recipe recipe) =>
      _ref.read(appStateProvider.notifier).logFood(FoodEntry(
            id: newEventId(),
            day: entry.day,
            meal: entry.slot,
            name: recipe.title,
            grams: 0,
            nutrients:
                nutrientsFor(entry, recipe, _ref.read(repositoryProvider).userId),
            source: FoodSource.plan,
          ));

  /// The list for the next trip, from the plan for its days. When a list
  /// for that trip is already open, it gets what it still lacks instead of
  /// a second, full list: the plan may have grown since.
  Future<ListFromPlan> listFromPlan({DayKey? from}) async {
    final String id = await _id;
    final Household household = await _household;
    final ShoppingPeriod period =
        household.cadence.periodFrom(from ?? DayKey.today());
    final List<PlanEntry> entries =
        await _backend.plan(id, period.start, period.end);
    final Map<String, Recipe> recipes = await _backend.recipes(id);
    final List<ShoppingItem> wanted = buildShoppingList(
      entries: entries,
      recipes: recipes,
      period: period,
      householdSize: household.members.length,
      pantry: household.pantry.toSet(),
    );
    ShoppingListInfo? open;
    for (final ShoppingListInfo list in await _backend.openLists(id)) {
      if (_sameTrip(list.period, period)) {
        open = list;
        break;
      }
    }
    try {
      if (open == null) {
        final ShoppingListInfo list = await _backend.createList(id, period);
        open = list;
        return ListFromPlan(
          list: list,
          created: true,
          added: await _backend.addItems(id, list.id, wanted),
        );
      }
      final List<ShoppingLine> lines = await _backend.items(open.id);
      final List<ShoppingItem> missing = stillMissing(wanted, <ShoppingItem>[
        for (final ShoppingLine l in lines)
          ShoppingItem(
            name: l.name,
            category: l.category,
            quantity: l.quantity,
            checked: l.checked,
          ),
      ]);
      return ListFromPlan(
        list: open,
        created: false,
        added: await _backend.addItems(id, open.id, missing),
      );
    } finally {
      _listsChanged(open?.id);
    }
  }

  /// Whether an open list is the one for [wanted]'s trip: the same days,
  /// or a longer list that runs through them. A one-day extra list is not.
  static bool _sameTrip(ShoppingPeriod list, ShoppingPeriod wanted) =>
      list == wanted || (list.lengthDays > 1 && list.contains(wanted.start));

  /// An extra list for a quick top-up between trips.
  Future<ShoppingListInfo> emptyList() async {
    final String id = await _id;
    final DayKey today = DayKey.today();
    final ShoppingListInfo list =
        await _backend.createList(id, ShoppingPeriod(today, today));
    _listsChanged(list.id);
    return list;
  }

  /// Adds a line typed by hand, with an amount if one was given. Returns
  /// it as stored.
  Future<List<ShoppingLine>> addItem(String listId, String text,
      {Quantity? quantity}) async {
    final String name = text.trim();
    if (name.isEmpty) return const <ShoppingLine>[];
    try {
      return await _backend.addItems(await _id, listId, <ShoppingItem>[
        ShoppingItem(
            name: name, category: guessCategory(name), quantity: quantity),
      ]);
    } finally {
      _listsChanged(listId);
    }
  }

  Future<void> setChecked(ShoppingLine line, bool checked) async {
    try {
      await _backend.setChecked(line.id, checked: checked);
    } finally {
      _listsChanged(line.listId);
    }
  }

  Future<void> removeItem(ShoppingLine line) async {
    try {
      await _backend.removeItem(line.id);
    } finally {
      _listsChanged(line.listId);
    }
  }

  /// Puts a removed line back, ticked if it was — the undo of
  /// [removeItem]. Returns it as stored now.
  Future<ShoppingLine?> restoreItem(ShoppingLine line) async {
    try {
      final List<ShoppingLine> added =
          await _backend.addItems(await _id, line.listId, <ShoppingItem>[
        ShoppingItem(
          name: line.name,
          category: line.category,
          quantity: line.quantity,
          recipeIds: line.recipeIds.toSet(),
        ),
      ]);
      if (added.isEmpty) return null;
      if (line.checked) {
        await _backend.setChecked(added.single.id, checked: true);
      }
      return added.single;
    } finally {
      _listsChanged(line.listId);
    }
  }

  /// Everything not ticked off moves to the next open list (made if there
  /// is none); this one is closed. An empty list is simply closed.
  Future<void> finishList(ShoppingListInfo list) async {
    final List<ShoppingLine> left = (await _backend.items(list.id))
        .where((ShoppingLine l) => !l.checked)
        .toList();
    if (left.isNotEmpty) {
      String? target;
      for (final ShoppingListInfo open in await _backend.openLists(await _id)) {
        if (open.id != list.id) {
          target = open.id;
          break;
        }
      }
      target ??= (await emptyList()).id;
      await _backend.moveItems(
          left.map((ShoppingLine l) => l.id).toList(), target);
    }
    await _backend.closeList(list.id);
    _listsChanged(list.id);
  }

  /// Settings show at once on this phone — the realtime echo is for the
  /// others.
  Future<void> updateHousehold({String? name, ShoppingCadence? cadence, List<String>? pantry}) async {
    try {
      await _backend.updateHousehold(await _id,
          name: name, cadence: cadence, pantry: pantry);
    } finally {
      _ref.invalidate(householdProvider);
    }
  }

  Future<void> updateMe(HouseholdMember me) async {
    try {
      await _backend.updateMembership(await _id, me);
    } finally {
      _ref.invalidate(householdProvider);
    }
  }

  Future<void> removeMember(String userId) async {
    try {
      await _backend.removeMember(await _id, userId);
    } finally {
      _ref.invalidate(householdProvider);
    }
  }

  /// Leaves the household; what the user sees next is their previous
  /// household, or a new one of their own.
  Future<void> leave() async {
    await _backend.leave(await _id);
    _ref.invalidate(householdIdProvider);
  }
}

final Provider<HouseholdActions> householdActionsProvider =
    Provider<HouseholdActions>(HouseholdActions.new);

/// Keeps the targets the user shares with the household in step with their
/// nutrition plan. The household holds a copy — portions for everyone are
/// sized from it — and the copy went stale whenever the goals changed.
///
/// Alive from the first screen that watches it (plan, list, diary,
/// household) for as long as the app runs.
final Provider<void> sharedTargetsSyncProvider = Provider<void>((Ref ref) {
  var busy = false;
  Future<void> sync() async {
    if (busy) return;
    final NutritionPlan? plan =
        ref.read(appStateProvider).valueOrNull?.plan?.nutrition;
    final HouseholdMember? me = ref
        .read(householdProvider)
        .valueOrNull
        ?.member(ref.read(repositoryProvider).userId);
    if (plan == null || me == null || !me.shareTargets) return;
    if (me.kcalTarget == plan.kcal && me.proteinG == plan.proteinG) return;
    busy = true;
    try {
      await ref.read(householdActionsProvider).updateMe(
          me.withTargets(share: true, kcal: plan.kcal, protein: plan.proteinG));
    } on Object {
      // Offline: the next change to either side tries again.
    } finally {
      busy = false;
    }
  }

  ref.listen<AsyncValue<AppSnapshot>>(
      appStateProvider, (Object? _, Object? __) => unawaited(sync()));
  ref.listen<AsyncValue<Household>>(
      householdProvider, (Object? _, Object? __) => unawaited(sync()),
      fireImmediately: true);
});

/// Portions for everyone in [household]: sized to each member's shared
/// target, one portion for members who keep theirs to themselves.
Map<String, double> portionsForHousehold(
  Household household,
  Recipe recipe,
  MealSlotKind slot,
) =>
    <String, double>{
      for (final HouseholdMember m in household.members)
        m.userId: portionsFor(
          recipe: recipe,
          slot: slot,
          dailyKcal: m.shareTargets ? m.kcalTarget : null,
        ),
    };
