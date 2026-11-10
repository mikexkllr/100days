import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../data/barcode_lookup.dart';
import '../../l10n/food_names.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'barcode_scan_screen.dart';

/// The barcode lookup, overridable in tests.
final Provider<BarcodeLookup> barcodeLookupProvider =
    Provider<BarcodeLookup>((Ref ref) => BarcodeLookup());

String newFoodEntryId() {
  final Random random = Random.secure();
  return List<String>.generate(
          12, (int _) => random.nextInt(16).toRadixString(16))
      .join();
}

/// Four ways to log a meal: search the food table, describe it in a
/// sentence (the on-device model estimates what the table does not know),
/// scan or type a barcode, or enter the numbers yourself.
class AddFoodScreen extends ConsumerStatefulWidget {
  const AddFoodScreen({
    super.key,
    required this.meal,
    required this.day,
    this.prefillText,
  });

  final MealSlotKind meal;
  final DayKey day;

  /// Opens on the describe tab with this text — what a tapped suggestion
  /// hands over.
  final String? prefillText;

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen> {
  Future<void> _log(List<FoodEntry> entries) async {
    for (final FoodEntry entry in entries) {
      await ref.read(appStateProvider.notifier).logFood(entry);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.l10n.foodAdded(entries.length)),
      duration: const Duration(seconds: 2),
    ));
    Navigator.of(context).pop();
  }

  FoodEntry _entry({
    required String name,
    required double grams,
    required Nutrients nutrients,
    required FoodSource source,
    String? foodId,
    String? barcode,
  }) =>
      FoodEntry(
        id: newFoodEntryId(),
        day: widget.day,
        meal: widget.meal,
        name: name,
        grams: grams,
        nutrients: nutrients,
        source: source,
        foodId: foodId,
        barcode: barcode,
      );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return DefaultTabController(
      length: 4,
      initialIndex: widget.prefillText == null ? 0 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.foodAddTo(l10n.mealName(widget.meal))),
          bottom: GlassTabBar(
            // Four short labels fit a phone; scrolling would hide the last.
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            tabs: <Widget>[
              Tab(text: l10n.foodTabSearch),
              Tab(text: l10n.foodTabDescribe),
              Tab(text: l10n.foodTabBarcode),
              Tab(text: l10n.foodTabManual),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _SearchTab(onPick: _log, makeEntry: _entry),
            _DescribeTab(
              initialText: widget.prefillText,
              onPick: _log,
              makeEntry: _entry,
            ),
            _BarcodeTab(onPick: _log, makeEntry: _entry),
            _ManualTab(onPick: _log, makeEntry: _entry),
          ],
        ),
      ),
    );
  }
}

typedef _EntryFactory = FoodEntry Function({
  required String name,
  required double grams,
  required Nutrients nutrients,
  required FoodSource source,
  String? foodId,
  String? barcode,
});

typedef _OnPick = Future<void> Function(List<FoodEntry> entries);

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab({required this.onPick, required this.makeEntry});

  final _OnPick onPick;
  final _EntryFactory makeEntry;

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final FoodIndex index = FoodIndex(locale);
    final List<FoodItem> results = index.search(_query);

    // Recently logged, newest first, one row per name — the shortcut most
    // diary entries take.
    final AppSnapshot? snapshot = ref.watch(appStateProvider).valueOrNull;
    final List<FoodEntry> recent = <FoodEntry>[];
    final Set<String> seen = <String>{};
    final List<String> days = (snapshot?.me.foodByDay.keys.toList() ??
        <String>[])
      ..sort((String a, String b) => b.compareTo(a));
    for (final String day in days) {
      for (final FoodEntry e in snapshot!.me.foodByDay[day]!.reversed) {
        if (seen.add(e.name.toLowerCase())) recent.add(e);
        if (recent.length >= 12) break;
      }
      if (recent.length >= 12) break;
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        TextField(
          key: const Key('food-search'),
          autofocus: false,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l10n.foodSearchHint,
          ),
          onChanged: (String v) => setState(() => _query = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_query.trim().isEmpty && recent.isNotEmpty) ...<Widget>[
          SectionHeader(l10n.foodRecent),
          for (final FoodEntry e in recent)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.name),
              subtitle: Text(
                  '${e.grams.round()} g · ${l10n.diaryEntryKcal(e.nutrients.kcal.round())}'),
              trailing: const Icon(Icons.add),
              onTap: () => widget.onPick(<FoodEntry>[
                widget.makeEntry(
                  name: e.name,
                  grams: e.grams,
                  nutrients: e.nutrients,
                  source: e.source,
                  foodId: e.foodId,
                  barcode: e.barcode,
                ),
              ]),
            ),
        ],
        if (_query.trim().isNotEmpty && results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              l10n.foodSearchNothing,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        for (final FoodItem food in results)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(foodName(food.id, locale)),
            subtitle: Text(l10n.foodPer100(food.kcal.round(),
                food.proteinG.round(), food.carbsG.round(), food.fatG.round())),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final double? grams = await showAmountSheet(
                context,
                title: foodName(food.id, locale),
                per100g: food.forGrams(100),
                portionG: food.portionG,
                pieceG: food.pieceG,
              );
              if (grams == null) return;
              await widget.onPick(<FoodEntry>[
                widget.makeEntry(
                  name: foodName(food.id, locale),
                  grams: grams,
                  nutrients: food.forGrams(grams),
                  source: FoodSource.database,
                  foodId: food.id,
                ),
              ]);
            },
          ),
      ],
    );
  }
}

/// One line of a parsed description, before it is logged.
class _Draft {
  _Draft({
    required this.name,
    required this.grams,
    required this.nutrients,
    required this.source,
    this.foodId,
  });

  String name;
  double grams;
  Nutrients nutrients;
  FoodSource source;
  String? foodId;
  bool include = true;

  bool get isKnown => nutrients.kcal > 0 || grams > 0;
}

class _DescribeTab extends ConsumerStatefulWidget {
  const _DescribeTab({
    required this.onPick,
    required this.makeEntry,
    this.initialText,
  });

  final _OnPick onPick;
  final _EntryFactory makeEntry;
  final String? initialText;

  @override
  ConsumerState<_DescribeTab> createState() => _DescribeTabState();
}

class _DescribeTabState extends ConsumerState<_DescribeTab> {
  late final TextEditingController _text =
      TextEditingController(text: widget.initialText ?? '');
  List<_Draft> _drafts = <_Draft>[];
  List<String> _unknown = <String>[];
  bool _estimating = false;
  bool _aiFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _parse());
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _parse() {
    final Locale locale = Localizations.localeOf(context);
    final FoodIndex index = FoodIndex(locale);
    final List<ParsedFood> parsed = parseFoodText(
      _text.text,
      vocabulary: foodVocabularyFor(locale),
      lookup: index.lookup,
    );
    setState(() {
      _aiFailed = false;
      _drafts = <_Draft>[
        for (final ParsedFood p in parsed.where((ParsedFood p) => p.isRecognised))
          _Draft(
            name: foodName(p.food!.id, locale),
            grams: p.grams,
            nutrients: p.nutrients!,
            source: FoodSource.parsed,
            foodId: p.food!.id,
          ),
      ];
      _unknown = <String>[
        for (final ParsedFood p in parsed.where((ParsedFood p) => !p.isRecognised))
          p.original,
      ];
    });
  }

  Future<void> _estimate(NutritionAssistant assistant) async {
    setState(() {
      _estimating = true;
      _aiFailed = false;
    });
    // Ask about everything when nothing was recognised, otherwise only
    // about what the table could not place.
    final String question =
        _drafts.isEmpty ? _text.text : _unknown.join(', ');
    final List<FoodEstimate>? estimates =
        await assistant.estimateFoods(question);
    if (!mounted) return;
    setState(() {
      _estimating = false;
      if (estimates == null) {
        _aiFailed = true;
        return;
      }
      _drafts = <_Draft>[
        ..._drafts,
        for (final FoodEstimate e in estimates)
          _Draft(
            name: e.name,
            grams: e.grams,
            nutrients: e.nutrients,
            source: FoodSource.ai,
          ),
      ];
      _unknown = <String>[];
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final NutritionAssistant? assistant =
        ref.watch(nutritionAssistantProvider).valueOrNull;
    final List<_Draft> included =
        _drafts.where((_Draft d) => d.include).toList();
    final double total = included.fold(
        0.0, (double sum, _Draft d) => sum + d.nutrients.kcal);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        TextField(
          key: const Key('food-describe'),
          controller: _text,
          minLines: 2,
          maxLines: 5,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(hintText: l10n.foodDescribeHint),
          onSubmitted: (_) => _parse(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('food-parse'),
                onPressed: _parse,
                icon: const Icon(Icons.manage_search, size: 18),
                label: Text(l10n.foodRecognise),
              ),
            ),
            if (assistant != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _estimating || _text.text.trim().isEmpty
                      ? null
                      : () => _estimate(assistant),
                  icon: _estimating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(l10n.foodAskAi),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (assistant == null)
          Text(
            l10n.foodAiNotInstalled,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
          ),
        if (_aiFailed)
          Text(
            l10n.foodAiFailed,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.danger, fontSize: 12.5),
          ),
        for (final _Draft draft in _drafts)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: draft.include,
            onChanged: (bool? v) => setState(() => draft.include = v ?? false),
            title: Text(draft.name),
            subtitle: Text(
              '${draft.grams.round()} g · '
              '${l10n.diaryEntryKcal(draft.nutrients.kcal.round())} · '
              '${l10n.foodSourceLabel(draft.source)}',
            ),
          ),
        if (_unknown.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            color: AppColors.surfaceHigh,
            child: Text(
              l10n.foodNotRecognised(_unknown.join(', ')),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
        if (included.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('food-add-parsed'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => widget.onPick(<FoodEntry>[
              for (final _Draft d in included)
                widget.makeEntry(
                  name: d.name,
                  grams: d.grams,
                  nutrients: d.nutrients,
                  source: d.source,
                  foodId: d.foodId,
                ),
            ]),
            child: Text(l10n.foodAddAll(included.length, total.round())),
          ),
        ],
      ],
    );
  }
}

class _BarcodeTab extends ConsumerStatefulWidget {
  const _BarcodeTab({required this.onPick, required this.makeEntry});

  final _OnPick onPick;
  final _EntryFactory makeEntry;

  @override
  ConsumerState<_BarcodeTab> createState() => _BarcodeTabState();
}

class _BarcodeTabState extends ConsumerState<_BarcodeTab> {
  final TextEditingController _code = TextEditingController();
  bool _loading = false;
  BarcodeProblem? _problem;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookup(String code) async {
    setState(() {
      _loading = true;
      _problem = null;
    });
    try {
      final BarcodeProduct product =
          await ref.read(barcodeLookupProvider).lookup(code);
      if (!mounted) return;
      setState(() => _loading = false);
      final double? grams = await showAmountSheet(
        context,
        title: product.displayName,
        per100g: product.per100g,
        portionG: product.servingG ?? 100,
        pieceG: product.servingG,
      );
      if (grams == null) return;
      await widget.onPick(<FoodEntry>[
        widget.makeEntry(
          name: product.displayName,
          grams: grams,
          nutrients: product.per100g.scaled(grams / 100),
          source: FoodSource.barcode,
          barcode: product.barcode,
        ),
      ]);
    } on BarcodeLookupException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _problem = error.problem;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _loading
              ? null
              : () async {
                  final String? code =
                      await Navigator.of(context).push<String>(
                    MaterialPageRoute<String>(
                      builder: (BuildContext context) =>
                          const BarcodeScanScreen(),
                    ),
                  );
                  if (code != null) {
                    _code.text = code;
                    await _lookup(code);
                  }
                },
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(l10n.foodScanButton),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('barcode-field'),
          controller: _code,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            labelText: l10n.foodBarcodeLabel,
            suffixIcon: IconButton(
              onPressed: _loading ? null : () => _lookup(_code.text),
              icon: const Icon(Icons.search),
            ),
          ),
          onSubmitted: _lookup,
        ),
        const SizedBox(height: AppSpacing.md),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_problem != null)
          Text(
            switch (_problem!) {
              BarcodeProblem.notFound => l10n.foodBarcodeNotFound,
              BarcodeProblem.noNutrition => l10n.foodBarcodeNoNutrition,
              BarcodeProblem.offline => l10n.foodBarcodeOffline,
            },
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.danger),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.foodBarcodePrivacy,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
        ),
      ],
    );
  }
}

class _ManualTab extends StatefulWidget {
  const _ManualTab({required this.onPick, required this.makeEntry});

  final _OnPick onPick;
  final _EntryFactory makeEntry;

  @override
  State<_ManualTab> createState() => _ManualTabState();
}

class _ManualTabState extends State<_ManualTab> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _grams = TextEditingController();
  final TextEditingController _kcal = TextEditingController();
  final TextEditingController _protein = TextEditingController();
  final TextEditingController _carbs = TextEditingController();
  final TextEditingController _fat = TextEditingController();

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _name,
      _grams,
      _kcal,
      _protein,
      _carbs,
      _fat,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _n(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    Widget number(TextEditingController c, String label, {Key? key}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: TextField(
            key: key,
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(labelText: label),
            onChanged: (_) => setState(() {}),
          ),
        );

    final bool valid = _name.text.trim().isNotEmpty && _n(_kcal) > 0;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: TextField(
            key: const Key('manual-name'),
            controller: _name,
            decoration: InputDecoration(labelText: l10n.foodManualName),
            onChanged: (_) => setState(() {}),
          ),
        ),
        number(_kcal, l10n.foodManualKcal, key: const Key('manual-kcal')),
        number(_grams, l10n.foodManualGrams),
        number(_protein, l10n.foodManualProtein),
        number(_carbs, l10n.foodManualCarbs),
        number(_fat, l10n.foodManualFat),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          key: const Key('manual-add'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: valid
              ? () => widget.onPick(<FoodEntry>[
                    widget.makeEntry(
                      name: _name.text.trim(),
                      grams: _n(_grams),
                      nutrients: Nutrients(
                        kcal: _n(_kcal),
                        proteinG: _n(_protein),
                        carbsG: _n(_carbs),
                        fatG: _n(_fat),
                      ),
                      source: FoodSource.manual,
                    ),
                  ])
              : null,
          child: Text(l10n.foodManualAdd),
        ),
      ],
    );
  }
}

/// Asks how much was eaten, with the usual amounts one tap away.
Future<double?> showAmountSheet(
  BuildContext context, {
  required String title,
  required Nutrients per100g,
  required double portionG,
  double? pieceG,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (BuildContext context) => _AmountSheet(
      title: title,
      per100g: per100g,
      portionG: portionG,
      pieceG: pieceG,
    ),
  );
}

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({
    required this.title,
    required this.per100g,
    required this.portionG,
    this.pieceG,
  });

  final String title;
  final Nutrients per100g;
  final double portionG;
  final double? pieceG;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late final TextEditingController _grams =
      TextEditingController(text: '${widget.portionG.round()}');

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  double get _value =>
      double.tryParse(_grams.text.trim().replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Nutrients n = widget.per100g.scaled(_value / 100);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('amount-grams'),
              controller: _grams,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.foodAmountLabel,
                suffixText: 'g',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                ActionChip(
                  label: Text(l10n.foodAmountPortion(widget.portionG.round())),
                  onPressed: () => setState(
                      () => _grams.text = '${widget.portionG.round()}'),
                ),
                if (widget.pieceG != null && widget.pieceG != widget.portionG)
                  ActionChip(
                    label: Text(l10n.foodAmountPiece(widget.pieceG!.round())),
                    onPressed: () => setState(
                        () => _grams.text = '${widget.pieceG!.round()}'),
                  ),
                ActionChip(
                  label: const Text('100 g'),
                  onPressed: () => setState(() => _grams.text = '100'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.foodAmountResult(n.kcal.round(), n.proteinG.round(),
                  n.carbsG.round(), n.fatG.round()),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('amount-add'),
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _value > 0
                  ? () => Navigator.of(context).pop(_value)
                  : null,
              child: Text(l10n.foodManualAdd),
            ),
          ],
        ),
      ),
    );
  }
}
