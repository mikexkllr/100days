import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/food_names.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../funki/funki_widgets.dart';
import '../mascot/flame_mascot.dart';
import '../widgets/app_card.dart';
import 'add_food_screen.dart' show newFoodEntryId;

/// One food of what was described, ready for the diary.
@immutable
class ComposedItem {
  const ComposedItem({
    required this.name,
    required this.grams,
    required this.nutrients,
    required this.source,
    this.foodId,
  });

  final String name;
  final double grams;
  final Nutrients nutrients;
  final FoodSource source;
  final String? foodId;

  FoodEntry toEntry(DayKey day, MealSlotKind meal) => FoodEntry(
        id: newFoodEntryId(),
        day: day,
        meal: meal,
        name: name,
        grams: grams,
        nutrients: nutrients,
        source: source,
        foodId: foodId,
      );
}

/// What became of a description: the foods, or why there are none.
@immutable
class ComposedFood {
  const ComposedFood(this.items, {this.failure, this.unknown = const <String>[]});

  final List<ComposedItem> items;

  /// What the model call failed with, if it did.
  final Object? failure;

  /// What the food table could not place, with no model to ask.
  final List<String> unknown;

  Nutrients get total => items.fold(
      Nutrients.zero, (Nutrients sum, ComposedItem i) => sum + i.nutrients);
}

/// Makes diary entries of a sentence — "2 pretzels with butter and a
/// cappuccino". The way every "what did you eat?" field in the app works:
/// the user describes, and calories are theirs to give or leave out.
///
/// The food table reads it first: what it knows in full costs nothing and
/// works offline. Anything else goes to Funki ([assistant]) as the whole
/// sentence, which a model reads better than its pieces. With [kcal] given
/// the user knows the total; the foods are scaled to it.
///
/// Without a model, a name and [kcal] still make a line; a name alone that
/// the table does not know comes back as [ComposedFood.unknown].
Future<ComposedFood> composeFood(
  String text, {
  required Locale locale,
  NutritionAssistant? assistant,
  double? kcal,
}) async {
  final String said = text.trim();
  if (said.isEmpty) return const ComposedFood(<ComposedItem>[]);
  final double? known = kcal != null && kcal > 0 ? kcal : null;
  final FoodIndex index = FoodIndex(locale);
  final List<ParsedFood> parsed = parseFoodText(
    said,
    vocabulary: foodVocabularyFor(locale),
    lookup: index.lookup,
  );
  final List<String> unknown = <String>[
    for (final ParsedFood p in parsed)
      if (!p.isRecognised) p.original,
  ];

  List<ComposedItem> items;
  if (parsed.isNotEmpty && unknown.isEmpty) {
    items = <ComposedItem>[
      for (final ParsedFood p in parsed)
        ComposedItem(
          name: foodName(p.food!.id, locale),
          grams: p.grams,
          nutrients: p.nutrients!,
          source: FoodSource.parsed,
          foodId: p.food!.id,
        ),
    ];
  } else if (assistant != null) {
    Object? failure;
    final List<FoodEstimate>? estimates = await assistant.estimateFoods(
      known == null ? said : '$said (${known.round()} kcal)',
      onError: (Object error) => failure = error,
    );
    if (estimates == null || estimates.isEmpty) {
      return ComposedFood(const <ComposedItem>[],
          failure: failure ?? StateError('no estimate'));
    }
    items = <ComposedItem>[
      for (final FoodEstimate e in estimates)
        ComposedItem(
          name: e.name,
          grams: e.grams,
          nutrients: e.nutrients,
          source: FoodSource.ai,
        ),
    ];
  } else if (known != null) {
    // No model, but the number is there: the line as written.
    return ComposedFood(<ComposedItem>[
      ComposedItem(
        name: said[0].toUpperCase() + said.substring(1),
        grams: 0,
        nutrients:
            Nutrients(kcal: known, proteinG: 0, carbsG: 0, fatG: 0),
        source: FoodSource.manual,
      ),
    ]);
  } else {
    return ComposedFood(const <ComposedItem>[], unknown: unknown);
  }

  final double sum =
      items.fold(0.0, (double s, ComposedItem i) => s + i.nutrients.kcal);
  if (known != null && sum > 0) {
    final double factor = known / sum;
    items = <ComposedItem>[
      for (final ComposedItem i in items)
        ComposedItem(
          name: i.name,
          grams: i.grams * factor,
          nutrients: i.nutrients.scaled(factor),
          source: i.source,
          foodId: i.foodId,
        ),
    ];
  }
  return ComposedFood(items);
}

/// Whether [slot] of today has most likely been eaten by [now].
bool mealLikelyEaten(MealSlotKind slot, DateTime now) => switch (slot) {
      MealSlotKind.breakfast => now.hour >= 9,
      MealSlotKind.lunch => now.hour >= 13,
      MealSlotKind.snack => now.hour >= 16,
      MealSlotKind.dinner => now.hour >= 19,
    };

/// The meal a line belongs to: the one it names ("… for breakfast"), else
/// the one the clock points at today, else — a day gone by — the first
/// meal still empty.
MealSlotKind mealSlotFor(
  String text, {
  required AppLocalizations l10n,
  required List<MealSlotKind> slots,
  required bool isToday,
  required DateTime now,
  required DayIntake intake,
}) {
  final String lower = text.toLowerCase();
  for (final MealSlotKind slot in slots) {
    if (lower.contains(l10n.mealName(slot).toLowerCase())) return slot;
  }
  if (isToday) {
    final MealSlotKind byClock = now.hour < 11
        ? MealSlotKind.breakfast
        : now.hour < 15
            ? MealSlotKind.lunch
            : now.hour < 18
                ? MealSlotKind.snack
                : MealSlotKind.dinner;
    if (slots.contains(byClock)) return byClock;
    // No snack in this plan: the afternoon counts towards dinner.
    return slots.contains(MealSlotKind.dinner) ? MealSlotKind.dinner : slots.last;
  }
  return slots.firstWhere(
    (MealSlotKind s) => intake.entriesFor(s).isEmpty,
    orElse: () => slots.last,
  );
}

/// The diary's first line: "what did you eat?" — typed, and it is in the
/// diary, with amounts and calories. No conversation: Funki composes the
/// entries, says what he put where, and it can be taken back.
class FoodQuickAdd extends ConsumerStatefulWidget {
  const FoodQuickAdd({
    super.key,
    required this.day,
    required this.slots,
    required this.intake,
    required this.isToday,
  });

  final DayKey day;
  final List<MealSlotKind> slots;
  final DayIntake intake;
  final bool isToday;

  @override
  ConsumerState<FoodQuickAdd> createState() => _FoodQuickAddState();
}

class _FoodQuickAddState extends ConsumerState<FoodQuickAdd> {
  final TextEditingController _text = TextEditingController();
  bool _working = false;
  String? _problem;

  /// What went in last, to say so and to take it back.
  List<FoodEntry> _added = const <FoodEntry>[];
  int _gulps = 0;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String said = _text.text.trim();
    if (said.isEmpty || _working) return;
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _working = true;
      _problem = null;
      _added = const <FoodEntry>[];
    });
    final NutritionAssistant? assistant = await ref
        .read(nutritionAssistantProvider.future)
        .catchError((Object _) => null);
    final ComposedFood food =
        await composeFood(said, locale: locale, assistant: assistant);
    if (!mounted) return;
    if (food.items.isEmpty) {
      setState(() {
        _working = false;
        _problem = food.failure != null
            ? l10n.aiErrorMessage(food.failure!)
            : assistant == null
                ? l10n.foodQuickNeedsAi(food.unknown.join(', '))
                : l10n.foodAiFailed;
      });
      return;
    }
    final MealSlotKind slot = mealSlotFor(
      said,
      l10n: l10n,
      slots: widget.slots,
      isToday: widget.isToday,
      now: DateTime.now(),
      intake: widget.intake,
    );
    final List<FoodEntry> entries = <FoodEntry>[
      for (final ComposedItem i in food.items) i.toEntry(widget.day, slot),
    ];
    for (final FoodEntry entry in entries) {
      await ref.read(appStateProvider.notifier).logFood(entry);
    }
    if (!mounted) return;
    _text.clear();
    setState(() {
      _working = false;
      _added = entries;
      _gulps++;
    });
  }

  Future<void> _undo() async {
    final List<FoodEntry> entries = _added;
    setState(() => _added = const <FoodEntry>[]);
    for (final FoodEntry entry in entries) {
      await ref.read(appStateProvider.notifier).removeFood(entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final List<FoodEntry> added = _added;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: const Key('food-quick'),
          controller: _text,
          enabled: !_working,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _send(),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            isDense: true,
            hintText: l10n.foodQuickHint,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: FunkiAvatar(
                size: 34,
                mood: _working ? MascotMood.hungry : MascotMood.happy,
                gulps: _gulps,
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 46, minHeight: 46),
            suffixIcon: _working
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: FunkiThinking(),
                  )
                : IconButton(
                    key: const Key('food-quick-send'),
                    tooltip: l10n.foodQuickSend,
                    onPressed: _send,
                    icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                  ),
          ),
        ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              _problem!,
              key: const Key('food-quick-problem'),
              style: text.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ),
        if (added.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: AppCard(
              key: const Key('food-quick-done'),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.check_circle_outline,
                      size: 18, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.funkiLogged(
                        l10n.mealName(added.first.meal),
                        added.map((FoodEntry e) => e.name).join(', '),
                        added
                            .fold(0.0,
                                (double s, FoodEntry e) => s + e.nutrients.kcal)
                            .round(),
                      ),
                      style: text.bodySmall,
                    ),
                  ),
                  TextButton(
                    key: const Key('food-quick-undo'),
                    onPressed: _undo,
                    child: Text(l10n.plannerUndo),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
