import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

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

final FutureProvider<String> householdIdProvider = FutureProvider<String>(
    (Ref ref) => ref.watch(householdBackendProvider).ensureHousehold());

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

/// Everything the plan and list screens do, in one place.
class HouseholdActions {
  HouseholdActions(this._ref);

  final Ref _ref;

  HouseholdBackend get _backend => _ref.read(householdBackendProvider);
  Future<String> get _id => _ref.read(householdIdProvider.future);

  /// Writes accepted proposals: each recipe, then its slot with portions
  /// sized for every member who shares their target.
  Future<void> acceptProposal(List<ProposedMeal> meals) async {
    final String id = await _id;
    final Household household = await _ref.read(householdProvider.future);
    for (final ProposedMeal meal in meals) {
      final Recipe recipe =
          await _backend.saveRecipe(id, meal.recipe, fromAi: true);
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
    }
  }

  Future<void> setMeal(DayKey day, MealSlotKind slot, Recipe recipe,
      {bool fromAi = false, String? replacing}) async {
    final String id = await _id;
    final Household household = await _ref.read(householdProvider.future);
    final Recipe stored = await _backend.saveRecipe(id, recipe, fromAi: fromAi);
    if (replacing != null) await _backend.removeEntry(replacing);
    await _backend.saveEntry(
      id,
      PlanEntry(
        id: newEventId(),
        day: day,
        slot: slot,
        recipeId: stored.id,
        portions: portionsForHousehold(household, stored, slot),
      ),
    );
  }

  Future<void> removeEntry(String entryId) => _backend.removeEntry(entryId);

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

  /// A list for the next trip, filled from the plan for its days. Returns
  /// the list.
  Future<ShoppingListInfo> listFromPlan({DayKey? from}) async {
    final String id = await _id;
    final Household household = await _ref.read(householdProvider.future);
    final ShoppingPeriod period =
        household.cadence.periodFrom(from ?? DayKey.today());
    final List<PlanEntry> entries =
        await _backend.plan(id, period.start, period.end);
    final Map<String, Recipe> recipes = await _backend.recipes(id);
    final ShoppingListInfo list = await _backend.createList(id, period);
    await _backend.addItems(
      id,
      list.id,
      buildShoppingList(
        entries: entries,
        recipes: recipes,
        period: period,
        householdSize: household.members.length,
        pantry: household.pantry.toSet(),
      ),
    );
    return list;
  }

  /// An extra list for a quick top-up between trips.
  Future<ShoppingListInfo> emptyList() async {
    final String id = await _id;
    final DayKey today = DayKey.today();
    return _backend.createList(id, ShoppingPeriod(today, today));
  }

  Future<void> addItem(String listId, String text) async {
    final String name = text.trim();
    if (name.isEmpty) return;
    await _backend.addItems(await _id, listId, <ShoppingItem>[
      ShoppingItem(name: name, category: guessCategory(name)),
    ]);
  }

  Future<void> setChecked(ShoppingLine line, bool checked) =>
      _backend.setChecked(line.id, checked: checked);

  Future<void> removeItem(ShoppingLine line) => _backend.removeItem(line.id);

  /// Everything not ticked off moves to the next open list (made if there
  /// is none); this one is closed.
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
  }

  Future<void> updateHousehold({String? name, ShoppingCadence? cadence, List<String>? pantry}) async =>
      _backend.updateHousehold(await _id, name: name, cadence: cadence, pantry: pantry);

  Future<void> updateMe(HouseholdMember me) async =>
      _backend.updateMembership(await _id, me);

  Future<void> removeMember(String userId) async =>
      _backend.removeMember(await _id, userId);
}

final Provider<HouseholdActions> householdActionsProvider =
    Provider<HouseholdActions>(HouseholdActions.new);

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
