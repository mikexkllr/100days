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

/// Households the user is still in besides the one the app shows. Someone
/// who joined before the app asked what to do with their own plan has it
/// waiting here; for everyone else this is empty.
final FutureProvider<List<OtherHousehold>> otherHouseholdsProvider =
    FutureProvider<List<OtherHousehold>>((Ref ref) async {
  final String id = await ref.watch(householdIdProvider.future);
  return ref.watch(householdBackendProvider).householdsBesides(id);
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

  void _planChanged() {
    _ref.invalidate(weekPlanProvider);
    _ref.invalidate(recipesProvider);
  }

  void _listsChanged([String? listId]) {
    _ref.invalidate(openListsProvider);
    if (listId != null) _ref.invalidate(listItemsProvider(listId));
  }

  /// Stores [recipe] — or, when the household already has a dish of that
  /// name, that one (see [reconcileRecipe]): one recipe per name, however
  /// often it is planned. [known] is kept up to date for the next call.
  Future<Recipe> _store(
    String householdId,
    Recipe recipe,
    Map<String, Recipe> known, {
    bool fromAi = false,
  }) async {
    final Recipe? same = recipeNamed(known.values, recipe.title);
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
  /// save pick up where it broke off.
  Future<void> acceptProposal(List<ProposedMeal> meals) async {
    if (meals.isEmpty) return;
    final String id = await _id;
    final Household household = await _ref.read(householdProvider.future);
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
        await _backend.saveEntry(
          id,
          PlanEntry(
            id: newEventId(),
            day: meal.day,
            slot: meal.slot,
            recipeId: recipe.id,
            portions: portionsForHousehold(household, recipe, meal.slot),
          ),
        );
        for (final PlanEntry old in before) {
          if (old.day == meal.day && old.slot == meal.slot) {
            await _backend.removeEntry(old.id);
          }
        }
      }
    } finally {
      _planChanged();
    }
  }

  /// Puts [recipe] on [day]'s [slot] and returns the entry as stored —
  /// with the household's own recipe of that name, if it has one.
  Future<(PlanEntry, Recipe)> setMeal(DayKey day, MealSlotKind slot, Recipe recipe,
      {bool fromAi = false, String? replacing}) async {
    final String id = await _id;
    final Household household = await _ref.read(householdProvider.future);
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
    final Household household = await _ref.read(householdProvider.future);
    final ShoppingPeriod period =
        household.cadence.periodFrom(from ?? DayKey.today());
    final List<PlanEntry> entries =
        await _backend.plan(id, period.start, period.end);
    final Map<String, Recipe> recipes = await _backend.recipes(id);
    final List<ShoppingItem> wanted = buildShoppingList(
      entries: entries,
      recipes: recipes,
      period: period,
      members: household.members.map((HouseholdMember m) => m.userId),
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

  /// Adds a line typed by hand. Returns it as stored.
  Future<List<ShoppingLine>> addItem(String listId, String text) async {
    final String name = text.trim();
    if (name.isEmpty) return const <ShoppingLine>[];
    try {
      return await _backend.addItems(await _id, listId, <ShoppingItem>[
        ShoppingItem(name: name, category: guessCategory(name)),
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

  /// Stores the user's own membership. When what they share of their
  /// targets changed, the meals still to come are sized again: sharing a
  /// target is for portions that fit, and those were worked out before.
  Future<void> updateMe(HouseholdMember me) async {
    final HouseholdMember? before = _ref
        .read(householdProvider)
        .valueOrNull
        ?.member(_ref.read(repositoryProvider).userId);
    try {
      await _backend.updateMembership(await _id, me);
    } finally {
      _ref.invalidate(householdProvider);
    }
    if (before != null &&
        (before.shareTargets != me.shareTargets ||
            before.kcalTarget != me.kcalTarget)) {
      await _fitQuietly();
    }
  }

  /// How far ahead meals are sized again when the household changes.
  static const int _fitDays = 60;

  /// Sizes the meals from today on for the household as it is now: a
  /// portion for everyone in it, fitted to the targets they share. A meal
  /// planned before someone joined, or brought along from a household of
  /// one, knew only who was there then.
  Future<void> fitPortions() async {
    final String id = await _id;
    final Household household = await _backend.household(id);
    final DayKey today = DayKey.today();
    final List<PlanEntry> entries =
        await _backend.plan(id, today, today.addDays(_fitDays));
    if (entries.isEmpty) return;
    final Map<String, Recipe> recipes = await _backend.recipes(id);
    try {
      for (final PlanEntry entry in entries) {
        final Recipe? recipe = recipes[entry.recipeId];
        if (recipe == null) continue;
        final Map<String, double> wanted =
            portionsForHousehold(household, recipe, entry.slot);
        if (_samePortions(wanted, entry.portions)) continue;
        await _backend.saveEntry(id, entry.withPortions(wanted));
      }
    } finally {
      _planChanged();
    }
  }

  static bool _samePortions(Map<String, double> a, Map<String, double> b) =>
      a.length == b.length &&
      a.entries.every((MapEntry<String, double> e) => b[e.key] == e.value);

  /// [fitPortions] after something else already went through. Until it
  /// does, everyone counts for one portion, so a failure here costs
  /// precision, not a meal — and is not worth reporting as the failure of
  /// what was asked for.
  Future<void> _fitQuietly() async {
    try {
      await fitPortions();
    } on Object {
      // Offline: the next change to the household sizes them.
    }
  }

  /// Joins the household behind [code]; it becomes the user's only one.
  /// With [bring], what they had planned alone comes along (see
  /// [HouseholdBackend.join]). With [shareTargets], the household gets
  /// their calorie and protein target at once, so the meals already
  /// planned there are sized for them too.
  Future<void> join(String code,
      {required bool bring, bool shareTargets = false}) async {
    final String id = await _backend.join(code, bring: bring);
    _ref.invalidate(householdIdProvider);
    final NutritionPlan? plan =
        _ref.read(appStateProvider).valueOrNull?.plan?.nutrition;
    try {
      if (shareTargets && plan != null) {
        final HouseholdMember? me = (await _backend.household(id))
            .member(_ref.read(repositoryProvider).userId);
        if (me != null && !me.shareTargets) {
          await _backend.updateMembership(
              id,
              me.withTargets(
                  share: true, kcal: plan.kcal, protein: plan.proteinG));
          _ref.invalidate(householdProvider);
        }
      }
    } on Object {
      // The join went through; the switch on the household screen is
      // still there.
    }
    await _fitQuietly();
  }

  /// Clears up what an earlier join left behind: the household the app
  /// shows becomes the user's only one, with [bring] after taking in what
  /// they had planned alone.
  Future<void> settle({required bool bring}) async {
    try {
      await _backend.settle(await _id, bring: bring);
    } finally {
      _ref.invalidate(otherHouseholdsProvider);
      _planChanged();
      _listsChanged();
    }
    if (bring) await _fitQuietly();
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
