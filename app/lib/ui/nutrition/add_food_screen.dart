import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:image_picker/image_picker.dart';

import '../../ai/meal_photo.dart';

import '../../data/app_repository.dart';
import '../../data/barcode_lookup.dart';
import '../../l10n/food_names.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../funki/funki_widgets.dart';
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

/// The ways into the diary, in the order of their tabs: saying what it was
/// comes first — it needs neither a search nor a number.
enum FoodEntryWay { describe, photo, search, barcode, manual }

/// Five ways to log a meal: describe it in a sentence, take a photo (the
/// language model estimates what is on the plate), search the food table,
/// scan or type a barcode, or enter the numbers yourself.
class AddFoodScreen extends ConsumerStatefulWidget {
  const AddFoodScreen({
    super.key,
    required this.meal,
    required this.day,
    this.prefillText,
    this.startOn = FoodEntryWay.describe,
  });

  final MealSlotKind meal;
  final DayKey day;

  /// Opens on the describe tab with this text — what a tapped suggestion
  /// hands over.
  final String? prefillText;

  /// The tab it opens on, unless [prefillText] asks for the describe tab.
  final FoodEntryWay startOn;

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen> {
  /// Set while entries are being written: a second tap on "Add 5 entries"
  /// would log ten of them and pop the diary as well.
  bool _saving = false;

  Future<void> _log(List<FoodEntry> entries) async {
    if (_saving || entries.isEmpty) return;
    setState(() => _saving = true);
    try {
      for (final FoodEntry entry in entries) {
        await ref.read(appStateProvider.notifier).logFood(entry);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
      length: FoodEntryWay.values.length,
      initialIndex: widget.prefillText == null
          ? widget.startOn.index
          : FoodEntryWay.describe.index,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.foodAddTo(l10n.mealName(widget.meal))),
          bottom: GlassTabBar(
            // Five short labels fit a phone; scrolling would hide the last.
            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
            tabs: <Widget>[
              Tab(text: l10n.foodTabDescribe),
              Tab(text: l10n.foodTabPhoto),
              Tab(text: l10n.foodTabSearch),
              Tab(text: l10n.foodTabBarcode),
              Tab(text: l10n.foodTabManual),
            ],
          ),
        ),
        body: Column(
          children: <Widget>[
            if (_saving) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: AbsorbPointer(
                absorbing: _saving,
                child: TabBarView(
                  children: <Widget>[
                    _DescribeTab(
                      initialText: widget.prefillText,
                      onPick: _log,
                      makeEntry: _entry,
                    ),
                    _PhotoTab(onPick: _log, makeEntry: _entry),
                    _SearchTab(onPick: _log, makeEntry: _entry),
                    _BarcodeTab(onPick: _log, makeEntry: _entry),
                    _ManualTab(onPick: _log, makeEntry: _entry),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A corrected amount and calorie count for a line.
typedef FoodCorrection = ({double grams, double kcal});

/// Lets the user put an estimate right: the amount, which takes the
/// calories along, and the calories themselves. For a draft before it is
/// added and for a line already in the diary.
Future<FoodCorrection?> showFoodEditSheet(
  BuildContext context, {
  required String name,
  required double grams,
  required Nutrients nutrients,
}) =>
    showModalBottomSheet<FoodCorrection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (BuildContext context) =>
          _FoodEditSheet(name: name, grams: grams, nutrients: nutrients),
    );

class _FoodEditSheet extends StatefulWidget {
  const _FoodEditSheet({
    required this.name,
    required this.grams,
    required this.nutrients,
  });

  final String name;
  final double grams;
  final Nutrients nutrients;

  @override
  State<_FoodEditSheet> createState() => _FoodEditSheetState();
}

class _FoodEditSheetState extends State<_FoodEditSheet> {
  late final TextEditingController _grams = TextEditingController(
      text: widget.grams > 0 ? '${widget.grams.round()}' : '');
  late final TextEditingController _kcal =
      TextEditingController(text: '${widget.nutrients.kcal.round()}');

  /// Once the user typed calories themselves, a new amount leaves them be.
  bool _kcalTyped = false;

  @override
  void dispose() {
    _grams.dispose();
    _kcal.dispose();
    super.dispose();
  }

  static double? _read(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _gramsChanged(String _) {
    final double? grams = _read(_grams);
    setState(() {
      if (!_kcalTyped && grams != null && widget.grams > 0) {
        _kcal.text = '${(widget.nutrients.kcal * grams / widget.grams).round()}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final double? grams = _grams.text.trim().isEmpty ? widget.grams : _read(_grams);
    final double? kcal = _read(_kcal);
    final bool valid = grams != null && grams >= 0 && kcal != null && kcal >= 0;
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(widget.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('edit-grams'),
              controller: _grams,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.foodAmountLabel,
                suffixText: 'g',
              ),
              onChanged: _gramsChanged,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('edit-kcal'),
              controller: _kcal,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.foodManualKcal),
              onChanged: (_) => setState(() => _kcalTyped = true),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.foodEditHint,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('edit-save'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: valid
                  ? () => Navigator.of(context).pop((grams: grams, kcal: kcal))
                  : null,
              child: Text(l10n.actionSave),
            ),
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

/// Every tab keeps its state while another is shown: a typed query, a
/// paid estimate, a half-filled form are not thrown away by a swipe.
class _SearchTabState extends ConsumerState<_SearchTab>
    with AutomaticKeepAliveClientMixin<_SearchTab> {
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
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

/// One line of a parsed description or a photo, before it is logged.
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
}

/// A draft: in or out with the checkbox, amount and calories put right
/// with the pencil — "check the amounts" has to be something one can do.
class _DraftTile extends StatelessWidget {
  const _DraftTile({
    required this.draft,
    required this.editKey,
    required this.onChanged,
  });

  final _Draft draft;
  final Key editKey;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: draft.include,
      onChanged: (bool? v) {
        draft.include = v ?? false;
        onChanged();
      },
      title: Text(draft.name),
      subtitle: Text(
        '${draft.grams.round()} g · '
        '${l10n.diaryEntryKcal(draft.nutrients.kcal.round())} · '
        '${l10n.foodSourceLabel(draft.source)}',
      ),
      secondary: IconButton(
        key: editKey,
        tooltip: l10n.foodEditTooltip,
        icon: const Icon(Icons.edit_outlined, size: 20),
        onPressed: () async {
          final FoodCorrection? fix = await showFoodEditSheet(
            context,
            name: draft.name,
            grams: draft.grams,
            nutrients: draft.nutrients,
          );
          if (fix == null) return;
          draft
            ..nutrients = correctNutrients(draft.nutrients,
                fromGrams: draft.grams, toGrams: fix.grams, kcal: fix.kcal)
            ..grams = fix.grams;
          onChanged();
        },
      ),
    );
  }
}

/// What the model estimated, and for which unknown pieces of the text.
class _Estimate {
  _Estimate(this.basis, this.drafts);

  final Set<String> basis;
  final List<_Draft> drafts;
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

class _DescribeTabState extends ConsumerState<_DescribeTab>
    with AutomaticKeepAliveClientMixin<_DescribeTab> {
  late final TextEditingController _text =
      TextEditingController(text: widget.initialText ?? '');

  /// What the food table recognised, as of the last "recognise".
  List<_Draft> _known = <_Draft>[];

  /// What the model estimated. Kept while the text still holds what it
  /// was asked about: an estimate costs allowance, and swiping to another
  /// tab or re-reading the text must not throw it away.
  final List<_Estimate> _estimates = <_Estimate>[];
  List<String> _unknown = <String>[];
  bool _estimating = false;
  String? _problem;
  FoodIndex? _index;
  Locale? _indexLocale;

  @override
  bool get wantKeepAlive => true;

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

  List<_Draft> get _drafts => <_Draft>[
        ..._known,
        for (final _Estimate e in _estimates) ...e.drafts,
      ];

  Set<String> get _estimated => <String>{
        for (final _Estimate e in _estimates) ...e.basis,
      };

  /// The text as it is now, read against the table: the drafts it knows,
  /// and the pieces it does not.
  (List<_Draft>, List<String>) _read() {
    final Locale locale = Localizations.localeOf(context);
    if (_indexLocale != locale) {
      _index = FoodIndex(locale);
      _indexLocale = locale;
    }
    final List<ParsedFood> parsed = parseFoodText(
      _text.text,
      vocabulary: foodVocabularyFor(locale),
      lookup: _index!.lookup,
    );
    return (
      <_Draft>[
        for (final ParsedFood p in parsed.where((ParsedFood p) => p.isRecognised))
          _Draft(
            name: foodName(p.food!.id, locale),
            grams: p.grams,
            nutrients: p.nutrients!,
            source: FoodSource.parsed,
            foodId: p.food!.id,
          ),
      ],
      <String>[
        for (final ParsedFood p in parsed.where((ParsedFood p) => !p.isRecognised))
          p.original,
      ],
    );
  }

  void _parse() {
    final (List<_Draft> known, List<String> unknown) = _read();
    setState(() {
      _problem = null;
      _known = known;
      _estimates.removeWhere((_Estimate e) => !e.basis.any(unknown.contains));
      _unknown = unknown.where((String u) => !_estimated.contains(u)).toList();
    });
  }

  /// One press: the table reads what it knows, Funki estimates the rest.
  Future<void> _compose(NutritionAssistant? assistant) async {
    FocusScope.of(context).unfocus();
    _parse();
    if (assistant != null && _unknown.isNotEmpty) await _estimate(assistant);
  }

  Future<void> _estimate(NutritionAssistant assistant) async {
    if (_estimating) return;
    // Asked about the text as it reads now — not about what it said when
    // "recognise" was last tapped.
    _parse();
    final List<String> pending = _unknown;
    if (pending.isEmpty) return;
    final AppLocalizations l10n = context.l10n;
    setState(() => _estimating = true);
    // Everything when the table knew nothing — the model reads the whole
    // sentence better — otherwise only what the table could not place.
    final String question = _known.isEmpty ? _text.text : pending.join(', ');
    Object? failure;
    final List<FoodEstimate>? estimates = await assistant.estimateFoods(
      question,
      onError: (Object error) => failure = error,
    );
    if (!mounted) return;
    setState(() {
      _estimating = false;
      if (estimates == null) {
        _problem =
            failure != null ? l10n.aiErrorMessage(failure!) : l10n.foodAiFailed;
        return;
      }
      _estimates.add(_Estimate(pending.toSet(), <_Draft>[
        for (final FoodEstimate e in estimates)
          _Draft(
            name: e.name,
            grams: e.grams,
            nutrients: e.nutrients,
            source: FoodSource.ai,
          ),
      ]));
      _unknown = <String>[];
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final AppLocalizations l10n = context.l10n;
    final NutritionAssistant? assistant =
        ref.watch(nutritionAssistantProvider).valueOrNull;
    final List<_Draft> drafts = _drafts;
    final List<_Draft> included =
        drafts.where((_Draft d) => d.include).toList();
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
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _compose(assistant),
        ),
        const SizedBox(height: AppSpacing.sm),
        // With Funki, one button: what the table knows costs nothing, the
        // rest he estimates. Without him, the table alone.
        if (assistant != null)
          FilledButton.icon(
            key: const Key('food-estimate'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _estimating || _text.text.trim().isEmpty
                ? null
                : () => _compose(assistant),
            icon: _estimating
                ? const FunkiThinking(color: AppColors.onPrimary)
                : const FunkiAvatar(size: 26),
            label: Text(_estimating ? l10n.funkiThinking : l10n.foodCompose),
          )
        else
          OutlinedButton.icon(
            key: const Key('food-parse'),
            onPressed: _parse,
            icon: const Icon(Icons.manage_search, size: 18),
            label: Text(l10n.foodRecognise),
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
        if (_problem != null)
          Text(
            _problem!,
            key: const Key('food-describe-problem'),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.danger, fontSize: 12.5),
          ),
        for (int i = 0; i < drafts.length; i++)
          _DraftTile(
            draft: drafts[i],
            editKey: Key('draft-edit-$i'),
            onChanged: () => setState(() {}),
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

/// A photo of the plate, estimated by the language model. The photo is
/// downscaled and stripped of metadata on the phone, sent once, and never
/// stored; what lands in the diary is only the entries the user confirms.
class _PhotoTab extends ConsumerStatefulWidget {
  const _PhotoTab({required this.onPick, required this.makeEntry});

  final _OnPick onPick;
  final _EntryFactory makeEntry;

  @override
  ConsumerState<_PhotoTab> createState() => _PhotoTabState();
}

class _PhotoTabState extends ConsumerState<_PhotoTab>
    with AutomaticKeepAliveClientMixin<_PhotoTab> {
  final TextEditingController _hint = TextEditingController();
  Uint8List? _preview;
  List<_Draft> _drafts = <_Draft>[];
  bool _working = false;

  /// What went wrong, in words that say what to do: no permission, a photo
  /// that cannot be read, no connection, or really nothing recognised.
  String? _problem;

  /// A paid estimate survives swiping to another tab and back.
  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  Future<void> _take(ImageSource source, NutritionAssistant assistant) async {
    final AppLocalizations l10n = context.l10n;
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: kMealPhotoPickSide,
        maxHeight: kMealPhotoPickSide,
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() => _problem = switch (pickProblem(error)) {
              MealPhotoProblem.noPermission => source == ImageSource.camera
                  ? l10n.foodPhotoNoCamera
                  : l10n.foodPhotoNoGallery,
              _ => l10n.foodPhotoPickFailed,
            });
      }
      return;
    }
    if (file == null || !mounted) return;
    setState(() {
      _working = true;
      _problem = null;
      _drafts = <_Draft>[];
    });
    try {
      LlmImage? photo;
      try {
        photo = await prepareMealPhoto(await file.readAsBytes());
      } on Object {
        photo = null;
      }
      if (!mounted) return;
      if (photo == null) {
        setState(() => _problem = l10n.foodPhotoUnreadable);
        return;
      }
      setState(() => _preview = photo!.bytes);
      Object? failure;
      final List<FoodEstimate>? estimates = await assistant.estimateFoodsFromPhoto(
        photo,
        hint: _hint.text,
        onError: (Object error) => failure = error,
      );
      if (!mounted) return;
      setState(() {
        _problem = estimates != null
            ? null
            : failure != null
                ? l10n.aiErrorMessage(failure!)
                : l10n.foodPhotoFailed;
        _drafts = <_Draft>[
          for (final FoodEstimate e in estimates ?? const <FoodEstimate>[])
            _Draft(
              name: e.name,
              grams: e.grams,
              nutrients: e.nutrients,
              source: FoodSource.photo,
            ),
        ];
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final AppLocalizations l10n = context.l10n;
    final NutritionAssistant? assistant =
        ref.watch(nutritionAssistantProvider).valueOrNull;
    final List<_Draft> included =
        _drafts.where((_Draft d) => d.include).toList();
    final double total = included.fold(
        0.0, (double sum, _Draft d) => sum + d.nutrients.kcal);

    if (assistant == null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          EmptyState(
            emoji: '📷',
            title: l10n.foodPhotoTitle,
            body: l10n.foodPhotoNeedsAi,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        if (_preview != null)
          ClipRRect(
            borderRadius: AppRadius.cardAll,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(_preview!, fit: BoxFit.cover),
            ),
          )
        else
          AppCard(
            color: AppColors.surfaceHigh,
            child: Text(
              l10n.foodPhotoIntro,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('food-photo-hint'),
          controller: _hint,
          decoration: InputDecoration(hintText: l10n.foodPhotoHint),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                key: const Key('food-photo-camera'),
                onPressed: _working
                    ? null
                    : () => _take(ImageSource.camera, assistant),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(l10n.foodPhotoCamera),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _working
                    ? null
                    : () => _take(ImageSource.gallery, assistant),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(l10n.foodPhotoGallery),
              ),
            ),
          ],
        ),
        if (_working) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(l10n.foodPhotoWorking,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary)),
          ),
        ],
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              _problem!,
              key: const Key('food-photo-problem'),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.danger, fontSize: 12.5),
            ),
          ),
        for (int i = 0; i < _drafts.length; i++)
          _DraftTile(
            draft: _drafts[i],
            editKey: Key('photo-edit-$i'),
            onChanged: () => setState(() {}),
          ),
        if (included.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.foodPhotoCheck,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('food-add-photo'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => widget.onPick(<FoodEntry>[
              for (final _Draft d in included)
                widget.makeEntry(
                  name: d.name,
                  grams: d.grams,
                  nutrients: d.nutrients,
                  source: d.source,
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

class _BarcodeTabState extends ConsumerState<_BarcodeTab>
    with AutomaticKeepAliveClientMixin<_BarcodeTab> {
  final TextEditingController _code = TextEditingController();
  bool _loading = false;
  BarcodeProblem? _problem;

  @override
  bool get wantKeepAlive => true;

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
    super.build(context);
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

class _ManualTab extends ConsumerStatefulWidget {
  const _ManualTab({required this.onPick, required this.makeEntry});

  final _OnPick onPick;
  final _EntryFactory makeEntry;

  @override
  ConsumerState<_ManualTab> createState() => _ManualTabState();
}

class _ManualTabState extends ConsumerState<_ManualTab>
    with AutomaticKeepAliveClientMixin<_ManualTab> {
  @override
  bool get wantKeepAlive => true;

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

  /// Add was pressed with something missing: the fields say what.
  bool _tried = false;

  double _n(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  Nutrients get _nutrients {
    final Nutrients typed = Nutrients(
      kcal: _n(_kcal),
      proteinG: _n(_protein),
      carbsG: _n(_carbs),
      fatG: _n(_fat),
    );
    // Macros without calories, as on some labels: they add up to them.
    return typed.kcal > 0
        ? typed
        : Nutrients(
            kcal: typed.kcalFromMacros,
            proteinG: typed.proteinG,
            carbsG: typed.carbsG,
            fatG: typed.fatG,
          );
  }

  bool get _hasName => _name.text.trim().isNotEmpty;
  bool get _hasKcal => _nutrients.kcal > 0;

  /// While Funki estimates what has a name but no calories, and what went
  /// wrong if he could not.
  bool _estimating = false;
  String? _problem;

  /// A name without calories: Funki estimates them — nobody knows what a
  /// plate of pasta has. The amount helps him, if it was given.
  Future<void> _estimate(NutritionAssistant assistant) async {
    if (_estimating) return;
    final AppLocalizations l10n = context.l10n;
    FocusScope.of(context).unfocus();
    setState(() {
      _estimating = true;
      _problem = null;
    });
    final double grams = _n(_grams);
    Object? failure;
    final List<FoodEstimate>? estimates = await assistant.estimateFoods(
      grams > 0 ? '${_name.text.trim()}, ${grams.round()} g' : _name.text.trim(),
      onError: (Object error) => failure = error,
    );
    if (!mounted) return;
    if (estimates == null || estimates.isEmpty) {
      setState(() {
        _estimating = false;
        _problem =
            failure != null ? l10n.aiErrorMessage(failure!) : l10n.foodAiFailed;
      });
      return;
    }
    setState(() => _estimating = false);
    widget.onPick(<FoodEntry>[
      for (final FoodEstimate e in estimates)
        widget.makeEntry(
          name: e.name,
          grams: e.grams,
          nutrients: e.nutrients,
          source: FoodSource.ai,
        ),
    ]);
  }

  /// A press always answers: logged, estimated, or the fields say what is
  /// missing.
  void _add(NutritionAssistant? assistant) {
    if (_hasName && !_hasKcal && assistant != null) {
      _estimate(assistant);
      return;
    }
    if (!_hasName || !_hasKcal) {
      setState(() => _tried = true);
      return;
    }
    widget.onPick(<FoodEntry>[
      widget.makeEntry(
        name: _name.text.trim(),
        grams: _n(_grams),
        nutrients: _nutrients,
        source: FoodSource.manual,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final AppLocalizations l10n = context.l10n;
    Widget number(TextEditingController c, String label,
            {Key? key, String? error, String? helper}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: TextField(
            key: key,
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: label,
              errorText: error,
              helperText: helper,
            ),
            onChanged: (_) => setState(() {}),
          ),
        );

    final NutritionAssistant? assistant =
        ref.watch(nutritionAssistantProvider).valueOrNull;
    // With Funki the calories may stay empty; without him they are needed.
    final bool kcalMissing = _tried && !_hasKcal && assistant == null;
    void open(FoodEntryWay way) =>
        DefaultTabController.of(context).animateTo(way.index);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: TextField(
            key: const Key('manual-name'),
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.foodManualName,
              errorText:
                  _tried && !_hasName ? l10n.foodManualNameMissing : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        number(
          _kcal,
          assistant == null ? l10n.foodManualKcal : l10n.foodManualKcalOptional,
          key: const Key('manual-kcal'),
          error: kcalMissing ? l10n.foodManualKcalMissing : null,
          helper: _n(_kcal) == 0 && _hasKcal
              ? l10n.foodManualKcalFromMacros(_nutrients.kcal.round())
              : null,
        ),
        // Not known: the photo or a sentence gets them estimated.
        if (kcalMissing)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const Key('manual-to-photo'),
                  onPressed: () => open(FoodEntryWay.photo),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(l10n.foodTabPhoto),
                ),
                OutlinedButton.icon(
                  key: const Key('manual-to-describe'),
                  onPressed: () => open(FoodEntryWay.describe),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: Text(l10n.foodTabDescribe),
                ),
              ],
            ),
          ),
        number(_grams, l10n.foodManualGrams),
        number(_protein, l10n.foodManualProtein),
        number(_carbs, l10n.foodManualCarbs),
        number(_fat, l10n.foodManualFat),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              _problem!,
              key: const Key('manual-problem'),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.danger),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          key: const Key('manual-add'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _estimating ? null : () => _add(assistant),
          child: _estimating
              ? const FunkiThinking(color: AppColors.onPrimary)
              : Text(_hasName && !_hasKcal && assistant != null
                  ? l10n.foodManualAddEstimated
                  : l10n.foodManualAdd),
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
