import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../ai/funki/funki.dart';
import '../../data/household_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/household_providers.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../funki/funki_widgets.dart';
import '../widgets/app_card.dart';
import 'household_load_error.dart';
import 'write_recipes_sheet.dart';

/// The household's shopping list, by aisle, ticked off live by everyone.
///
/// What is bought stands with its amount, aisle by aisle; the kitchen
/// basics the recipes take a little of — oil, salt, spices — stand at the
/// end without one, to check at home. A planned meal that has no recipe
/// yet cannot be on the list, and the view says so and offers to have it
/// written.
class ShoppingView extends ConsumerStatefulWidget {
  const ShoppingView({super.key});

  @override
  ConsumerState<ShoppingView> createState() => _ShoppingViewState();
}

class _ShoppingViewState extends ConsumerState<ShoppingView> {
  String? _selected;
  final TextEditingController _add = TextEditingController();
  bool _working = false;

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } on Object {
      if (mounted) showHouseholdSaveFailed(context);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Has the recipes of [meals] written and, when a list is open, puts on
  /// it what they add: the list was waiting for exactly that.
  Future<void> _writeRecipes(
      List<(PlanEntry, Recipe)> meals, {required bool topUp}) async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final int written = await showWriteRecipesSheet(context, meals);
    if (written == 0 || !mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.writeRecipesDone(written))));
    if (!topUp) return;
    await _run(() async {
      final ListFromPlan made =
          await ref.read(householdActionsProvider).listFromPlan();
      if (mounted) setState(() => _selected = made.list.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    ref.watch(sharedTargetsSyncProvider);
    final AsyncValue<List<ShoppingListInfo>> lists = ref.watch(openListsProvider);
    final Household? household = ref.watch(householdProvider).valueOrNull;
    // Only dishes with a name can have their recipe written.
    final List<(PlanEntry, Recipe)> unwritten = <(PlanEntry, Recipe)>[
      for (final (PlanEntry entry, Recipe? recipe)
          in ref.watch(mealsWithoutRecipeProvider).valueOrNull ??
              const <(PlanEntry, Recipe?)>[])
        if (recipe != null) (entry, recipe),
    ];
    final bool canWrite = ref.watch(mealPlannerProvider).valueOrNull != null;

    // Every realtime tick reloads the lists; the old ones stay on screen
    // meanwhile, so the scroll position and the typed line survive it.
    return lists.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) => const HouseholdLoadError(),
      data: (List<ShoppingListInfo> open) {
        final ShoppingListInfo? list = open.isEmpty
            ? null
            : open.firstWhere((ShoppingListInfo l) => l.id == _selected,
                orElse: () => open.first);
        return ListView(
          padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md,
              AppSpacing.md, AppSpacing.xxl + MediaQuery.paddingOf(context).bottom),
          children: <Widget>[
            if (household != null)
              Text(
                l10n.shopCadenceLine(l10n.cadenceLabel(household.cadence)),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('list-from-plan'),
                    onPressed: _working
                        ? null
                        : () => _run(() async {
                              final ScaffoldMessengerState messenger =
                                  ScaffoldMessenger.of(context);
                              final ListFromPlan made = await ref
                                  .read(householdActionsProvider)
                                  .listFromPlan();
                              if (!mounted) return;
                              setState(() => _selected = made.list.id);
                              // Made again for the same trip: say what it
                              // did, since no new list appeared.
                              if (!made.created) {
                                messenger.showSnackBar(SnackBar(
                                    content:
                                        Text(l10n.shopTopUp(made.added.length))));
                              }
                            }),
                    icon: const Icon(Icons.playlist_add, size: 18),
                    label: Text(l10n.shopFromPlan),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('list-extra'),
                    onPressed: _working
                        ? null
                        : () => _run(() async {
                              final ShoppingListInfo made = await ref
                                  .read(householdActionsProvider)
                                  .emptyList();
                              if (mounted) setState(() => _selected = made.id);
                            }),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: Text(l10n.shopExtraList),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FunkiAskButton(
              key: const Key('shop-funki'),
              focus: FunkiFocus.shopping(DayKey.today()),
              label: l10n.funkiHintShopping,
              filled: true,
            ),
            if (unwritten.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                key: const Key('shop-no-recipe'),
                color: AppColors.surfaceHigh,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.shopNoRecipe(
                        unwritten.length,
                        unwritten
                            .map(((PlanEntry, Recipe) m) => m.$2.title)
                            .toSet()
                            .join(', '),
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (canWrite)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: const Key('shop-write-recipes'),
                          onPressed: _working
                              ? null
                              : () => _writeRecipes(unwritten,
                                  topUp: open.isNotEmpty),
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: Text(l10n.shopWriteRecipes),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (open.length > 1) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                children: <Widget>[
                  for (final ShoppingListInfo l in open)
                    ChoiceChip(
                      label: Text(l.title.isNotEmpty ? l.title : l10n.periodLabel(l.period)),
                      selected: l.id == list?.id,
                      onSelected: (_) => setState(() => _selected = l.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (list == null)
              EmptyState(
                emoji: '🛒',
                title: l10n.shopEmptyTitle,
                body: l10n.shopEmptyBody,
              )
            else
              _ListBody(
                key: ValueKey<String>(list.id),
                list: list,
                addController: _add,
                working: _working,
                onFinish: () => _run(
                    () => ref.read(householdActionsProvider).finishList(list)),
              ),
          ],
        );
      },
    );
  }
}

/// One list, changed optimistically: a tick, a swipe or a new line shows at
/// once and goes to the server behind it. In a shop with bad reception the
/// checkbox must move when tapped; if the write fails it moves back and
/// the user is told.
class _ListBody extends ConsumerStatefulWidget {
  const _ListBody({
    super.key,
    required this.list,
    required this.addController,
    required this.working,
    required this.onFinish,
  });

  final ShoppingListInfo list;
  final TextEditingController addController;
  final bool working;
  final VoidCallback onFinish;

  @override
  ConsumerState<_ListBody> createState() => _ListBodyState();
}

class _ListBodyState extends ConsumerState<_ListBody> {
  /// Ticks shown before a load confirms them: line id → shown value.
  final Map<String, bool> _ticks = <String, bool>{};

  /// Lines swiped away, hidden until a load no longer has them.
  final Set<String> _removed = <String>{};

  /// Lines typed in (or put back), shown until a load has them.
  final List<ShoppingLine> _adding = <ShoppingLine>[];

  final List<Timer> _timers = <Timer>[];
  int _pendingIds = 0;

  @override
  void dispose() {
    for (final Timer timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  /// After a write went through, its stand-in goes as soon as a load shows
  /// the result — or after a while at the latest, so a change someone else
  /// made in between is not hidden for good.
  void _settleLater(void Function() forget) {
    _timers.add(Timer(const Duration(seconds: 3), () {
      if (mounted) setState(forget);
    }));
  }

  void _reconcile(List<ShoppingLine> server) {
    final Map<String, ShoppingLine> byId = <String, ShoppingLine>{
      for (final ShoppingLine l in server) l.id: l,
    };
    _ticks.removeWhere((String id, bool on) => byId[id]?.checked == on);
    _removed.removeWhere((String id) => !byId.containsKey(id));
    _adding.removeWhere((ShoppingLine l) => byId.containsKey(l.id));
  }

  HouseholdActions get _actions => ref.read(householdActionsProvider);

  Future<void> _tick(ShoppingLine line, bool on) async {
    setState(() => _ticks[line.id] = on);
    try {
      await _actions.setChecked(line, on);
    } on Object {
      if (!mounted) return;
      setState(() {
        if (_ticks[line.id] == on) _ticks.remove(line.id);
      });
      showHouseholdSaveFailed(context);
      return;
    }
    _settleLater(() {
      if (_ticks[line.id] == on) _ticks.remove(line.id);
    });
  }

  /// Shows [shown] at once and stores it with [write]; [onFailed] runs when
  /// the write does not go through.
  Future<void> _addLine(
    ShoppingLine shown,
    Future<List<ShoppingLine>> Function() write, {
    VoidCallback? onFailed,
  }) async {
    setState(() => _adding.add(shown));
    final List<ShoppingLine> stored;
    try {
      stored = await write();
    } on Object {
      if (!mounted) return;
      setState(() => _adding.remove(shown));
      onFailed?.call();
      showHouseholdSaveFailed(context);
      return;
    }
    if (!mounted) return;
    final List<ShoppingLine> server =
        ref.read(listItemsProvider(widget.list.id)).valueOrNull ??
            const <ShoppingLine>[];
    setState(() {
      _adding
        ..remove(shown)
        ..addAll(stored.where((ShoppingLine s) =>
            !server.any((ShoppingLine l) => l.id == s.id)));
    });
    _settleLater(() => _adding.removeWhere(
        (ShoppingLine p) => stored.any((ShoppingLine s) => s.id == p.id)));
  }

  void _submit() {
    final String text = widget.addController.text.trim();
    if (text.isEmpty) return;
    widget.addController.clear();
    final HouseholdActions actions = _actions;
    unawaited(_addLine(
      ShoppingLine(
        id: 'pending-${_pendingIds++}',
        listId: widget.list.id,
        name: text,
        category: guessCategory(text),
      ),
      () => actions.addItem(widget.list.id, text),
      // Typed in vain: give the words back.
      onFailed: () {
        if (widget.addController.text.isEmpty) widget.addController.text = text;
      },
    ));
  }

  void _remove(ShoppingLine line) {
    final AppLocalizations l10n = context.l10n;
    final HouseholdActions actions = _actions;
    setState(() => _removed.add(line.id));
    final Future<bool> deleted = () async {
      try {
        await actions.removeItem(line);
      } on Object {
        if (mounted) {
          setState(() => _removed.remove(line.id));
          showHouseholdSaveFailed(context);
        }
        return false;
      }
      _settleLater(() => _removed.remove(line.id));
      return true;
    }();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.shopItemRemoved(line.name)),
        // An undo is offered for a moment; with an action a snackbar
        // would otherwise stay until dismissed.
        persist: false,
        action: SnackBarAction(
          label: l10n.actionUndo,
          onPressed: () async {
            // Only once the deletion is through: a failed one already put
            // the line back, and a second copy would be one too many.
            if (!await deleted || !mounted) return;
            await _addLine(
              ShoppingLine(
                id: 'pending-${_pendingIds++}',
                listId: line.listId,
                name: line.name,
                category: line.category,
                quantity: line.quantity,
                checked: line.checked,
                checkedBy: line.checkedBy,
                recipeIds: line.recipeIds,
              ),
              () async {
                final ShoppingLine? back = await actions.restoreItem(line);
                return back == null ? const <ShoppingLine>[] : <ShoppingLine>[back];
              },
            );
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    ref.listen<AsyncValue<List<ShoppingLine>>>(listItemsProvider(widget.list.id),
        (AsyncValue<List<ShoppingLine>>? _, AsyncValue<List<ShoppingLine>> next) {
      final List<ShoppingLine>? server = next.valueOrNull;
      if (server != null && !next.isLoading) setState(() => _reconcile(server));
    });
    final List<ShoppingLine> server =
        ref.watch(listItemsProvider(widget.list.id)).valueOrNull ??
            const <ShoppingLine>[];
    final String me = ref.watch(repositoryProvider).userId;
    final List<ShoppingLine> lines = <ShoppingLine>[
      for (final ShoppingLine l in server)
        if (!_removed.contains(l.id))
          if (_ticks[l.id] case final bool on) l.ticked(on, by: me) else l,
      for (final ShoppingLine l in _adding)
        if (!server.any((ShoppingLine s) => s.id == l.id)) l,
    ];
    final Household? household = ref.watch(householdProvider).valueOrNull;
    final int done = lines.where((ShoppingLine l) => l.checked).length;

    final Map<ShopCategory, List<ShoppingLine>> byAisle =
        <ShopCategory, List<ShoppingLine>>{};
    for (final ShoppingLine line in lines) {
      byAisle.putIfAbsent(line.category, () => <ShoppingLine>[]).add(line);
    }
    final List<ShopCategory> aisles = byAisle.keys.toList()
      ..sort((ShopCategory a, ShopCategory b) => a.index.compareTo(b.index));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                widget.list.title.isNotEmpty
                    ? widget.list.title
                    : l10n.periodLabel(widget.list.period),
                style: text.titleMedium,
              ),
            ),
            Text(l10n.shopProgress(done, lines.length),
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('shop-add'),
          controller: widget.addController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: l10n.shopAddHint,
            suffixIcon: IconButton(onPressed: _submit, icon: const Icon(Icons.add)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final ShopCategory aisle in aisles) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 2),
            child: Text(l10n.shopCategoryName(aisle).toUpperCase(),
                style: text.labelSmall?.copyWith(
                    color: AppColors.textTertiary, letterSpacing: 1.2)),
          ),
          // Not an aisle: what to look for at home before the trip.
          if (aisle == ShopCategory.staples)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                l10n.shopStaplesHint,
                key: const Key('shop-staples-hint'),
                style:
                    text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Column(
              children: <Widget>[
                for (final ShoppingLine line in byAisle[aisle]!
                  ..sort((ShoppingLine a, ShoppingLine b) {
                    if (a.checked != b.checked) return a.checked ? 1 : -1;
                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  }))
                  _line(context, line, household,
                      stored: !line.id.startsWith('pending-')),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        // An empty list can be closed too — an extra list made by mistake
        // would otherwise stay for good.
        OutlinedButton.icon(
          key: const Key('shop-finish'),
          onPressed: widget.working ? null : widget.onFinish,
          icon: const Icon(Icons.done_all, size: 18),
          label: Text(lines.isEmpty
              ? l10n.shopCloseEmpty
              : done == lines.length
                  ? l10n.shopFinish
                  : l10n.shopFinishMoving(lines.length - done)),
        ),
      ],
    );
  }

  /// A line not [stored] yet is shown faded and cannot be ticked or swiped:
  /// the server has no row for it to change.
  Widget _line(BuildContext context, ShoppingLine line, Household? household,
      {required bool stored}) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    return Opacity(
      key: ValueKey<String>('row-${line.id}'),
      opacity: stored ? 1 : 0.55,
      child: Dismissible(
        key: ValueKey<String>(line.id),
        direction:
            stored ? DismissDirection.endToStart : DismissDirection.none,
        onDismissed: (_) => _remove(line),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: const Icon(Icons.delete_outline, color: AppColors.danger),
        ),
        child: CheckboxListTile(
          key: Key('shop-item-${line.name}'),
          dense: true,
          value: line.checked,
          onChanged: stored ? (bool? on) => _tick(line, on ?? false) : null,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            line.name,
            style: line.checked
                ? text.bodyMedium?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: AppColors.textTertiary)
                : text.bodyMedium,
          ),
          subtitle: line.checked && line.checkedBy != null && household != null
              ? Text(l10n.shopCheckedBy(
                  household.member(line.checkedBy!)?.displayName ?? ''))
              : null,
          secondary: line.quantity == null
              ? null
              : Text(l10n.quantityLabel(line.quantity!),
                  style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ),
      ),
    );
  }
}
