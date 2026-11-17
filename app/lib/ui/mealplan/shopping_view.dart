import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/household_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/household_providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// The household's shopping list, by aisle, ticked off live by everyone.
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
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<ShoppingListInfo>> lists = ref.watch(openListsProvider);
    final Household? household = ref.watch(householdProvider).valueOrNull;

    return lists.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) =>
          Center(child: Text(l10n.planLoadFailed)),
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
                              final ShoppingListInfo made = await ref
                                  .read(householdActionsProvider)
                                  .listFromPlan();
                              setState(() => _selected = made.id);
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
                              setState(() => _selected = made.id);
                            }),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: Text(l10n.shopExtraList),
                  ),
                ),
              ],
            ),
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
                list: list,
                addController: _add,
                onFinish: () => _run(
                    () => ref.read(householdActionsProvider).finishList(list)),
              ),
          ],
        );
      },
    );
  }
}

class _ListBody extends ConsumerWidget {
  const _ListBody({
    required this.list,
    required this.addController,
    required this.onFinish,
  });

  final ShoppingListInfo list;
  final TextEditingController addController;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final List<ShoppingLine> lines =
        ref.watch(listItemsProvider(list.id)).valueOrNull ?? const <ShoppingLine>[];
    final Household? household = ref.watch(householdProvider).valueOrNull;
    final HouseholdActions actions = ref.read(householdActionsProvider);
    final int done = lines.where((ShoppingLine l) => l.checked).length;

    final Map<ShopCategory, List<ShoppingLine>> byAisle =
        <ShopCategory, List<ShoppingLine>>{};
    for (final ShoppingLine line in lines) {
      byAisle.putIfAbsent(line.category, () => <ShoppingLine>[]).add(line);
    }
    final List<ShopCategory> aisles = byAisle.keys.toList()
      ..sort((ShopCategory a, ShopCategory b) => a.index.compareTo(b.index));

    void submit() {
      final String text = addController.text;
      addController.clear();
      actions.addItem(list.id, text);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                list.title.isNotEmpty ? list.title : l10n.periodLabel(list.period),
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
          controller: addController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          decoration: InputDecoration(
            hintText: l10n.shopAddHint,
            suffixIcon: IconButton(onPressed: submit, icon: const Icon(Icons.add)),
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
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Column(
              children: <Widget>[
                for (final ShoppingLine line in byAisle[aisle]!
                  ..sort((ShoppingLine a, ShoppingLine b) {
                    if (a.checked != b.checked) return a.checked ? 1 : -1;
                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  }))
                  Dismissible(
                    key: ValueKey<String>(line.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => actions.removeItem(line),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: const Icon(Icons.delete_outline, color: AppColors.danger),
                    ),
                    child: CheckboxListTile(
                      key: Key('shop-item-${line.name}'),
                      dense: true,
                      value: line.checked,
                      onChanged: (bool? on) => actions.setChecked(line, on ?? false),
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
                              style: text.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary)),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (lines.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            key: const Key('shop-finish'),
            onPressed: onFinish,
            icon: const Icon(Icons.done_all, size: 18),
            label: Text(done == lines.length
                ? l10n.shopFinish
                : l10n.shopFinishMoving(lines.length - done)),
          ),
        ],
      ],
    );
  }
}
