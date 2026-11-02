import 'package:meta/meta.dart';

import 'foods.dart';

/// How an amount in free text is measured.
enum FoodUnit {
  grams,
  kilograms,
  millilitres,
  litres,
  piece,
  slice,
  portion,
  tablespoon,
  teaspoon,
  cup,
  glass,
  handful,
}

/// The words a language uses for numbers, units and glue.
///
/// This package holds no display language, so the app hands one of these in
/// per locale — "zwei Scheiben" and "two slices" go through the same parser.
@immutable
class FoodVocabulary {
  const FoodVocabulary({
    required this.numberWords,
    required this.unitWords,
    required this.separators,
    this.fillerWords = const <String>{},
  });

  /// `"ein" → 1`, `"half" → 0.5`, lower case.
  final Map<String, double> numberWords;

  /// `"g" → grams`, `"scheiben" → slice`, lower case.
  final Map<String, FoodUnit> unitWords;

  /// Words that split one item from the next: `und`, `and`, `mit`, `with`.
  /// Commas, semicolons, plus signs and line breaks always split.
  final List<String> separators;

  /// Words dropped before the food is looked up: `ich`, `hatte`, `of`.
  final Set<String> fillerWords;
}

/// Maps the food words of one item ("eier", "griechischer joghurt") to a
/// table entry, or null. Supplied by the app, which owns the names.
typedef FoodLookup = FoodItem? Function(String phrase);

/// One item recognised in a free-text meal description.
@immutable
class ParsedFood {
  const ParsedFood({
    required this.original,
    required this.phrase,
    required this.amount,
    required this.unit,
    required this.grams,
    this.food,
  });

  /// The piece of text this item came from, e.g. `2 Eier`.
  final String original;

  /// The words that name the food, e.g. `eier`.
  final String phrase;

  final double amount;
  final FoodUnit unit;

  /// Resolved weight. For an unrecognised food only mass units resolve.
  final double grams;

  /// Null when nothing in the table matched.
  final FoodItem? food;

  bool get isRecognised => food != null && grams > 0;

  Nutrients? get nutrients => food?.forGrams(grams);
}

final RegExp _numberGlued = RegExp(r'(\d+(?:[.,]\d+)?)([^\d\s.,]+)');
final RegExp _number = RegExp(r'^\d+(?:[.,]\d+)?$');
final RegExp _fraction = RegExp(r'^(\d+)/(\d+)$');

/// Splits a sentence like "2 Eier, 1 Scheibe Vollkornbrot und Kaffee mit
/// Milch" into items, reads the amount of each and looks the food up.
///
/// Deterministic and offline: this is the floor the on-device model improves
/// on, and what runs when no model is installed. Items it cannot place come
/// back with [ParsedFood.food] null so the UI can ask instead of guessing.
List<ParsedFood> parseFoodText(
  String text, {
  required FoodVocabulary vocabulary,
  required FoodLookup lookup,
}) {
  final separators = vocabulary.separators
      .map((String s) => RegExp.escape(s.trim().toLowerCase()))
      .where((String s) => s.isNotEmpty)
      .join('|');
  final splitter = RegExp(
    separators.isEmpty
        ? r'[,;+\n&]'
        : '[,;+\\n&]|\\s(?:$separators)\\s',
    caseSensitive: false,
  );

  // A decimal comma ("1,5 l") is not a list comma.
  final normalised = text
      .toLowerCase()
      .replaceAllMapped(RegExp(r'(\d),(\d)'), (Match m) => '${m[1]}.${m[2]}');

  final results = <ParsedFood>[];
  for (final String raw in ' $normalised '.split(splitter)) {
    final chunk = raw.trim();
    if (chunk.isEmpty) continue;
    final item = _parseChunk(chunk, vocabulary, lookup);
    if (item != null) results.add(item);
  }
  return results;
}

ParsedFood? _parseChunk(
  String chunk,
  FoodVocabulary vocabulary,
  FoodLookup lookup,
) {
  final spaced = chunk
      .replaceAllMapped(_numberGlued, (Match m) => '${m[1]} ${m[2]}')
      .replaceAll(RegExp(r'[()"!?:]'), ' ');
  final tokens = spaced
      .split(RegExp(r'\s+'))
      .map((String t) => t.replaceAll(RegExp(r'\.$'), ''))
      .where((String t) => t.isNotEmpty)
      .toList();

  double? amount;
  FoodUnit? unit;
  final words = <String>[];
  for (final String token in tokens) {
    final number = _readNumber(token, vocabulary);
    if (number != null && amount == null) {
      amount = number;
      continue;
    }
    final unitWord = vocabulary.unitWords[token];
    if (unitWord != null && unit == null) {
      unit = unitWord;
      continue;
    }
    if (vocabulary.fillerWords.contains(token)) continue;
    words.add(token);
  }
  final phrase = words.join(' ').trim();
  if (phrase.isEmpty) return null;

  final food = lookup(phrase);
  final resolvedAmount = amount ?? 1;
  final resolvedUnit = unit ??
      (amount == null
          ? (food?.pieceG != null ? FoodUnit.piece : FoodUnit.portion)
          : food?.pieceG != null && resolvedAmount < 10
              ? FoodUnit.piece
              : resolvedAmount >= 10
                  ? FoodUnit.grams
                  : FoodUnit.portion);

  return ParsedFood(
    original: chunk,
    phrase: phrase,
    amount: resolvedAmount,
    unit: resolvedUnit,
    grams: gramsFor(resolvedUnit, resolvedAmount, food),
    food: food,
  );
}

double? _readNumber(String token, FoodVocabulary vocabulary) {
  if (_number.hasMatch(token)) {
    return double.tryParse(token.replaceAll(',', '.'));
  }
  final fraction = _fraction.firstMatch(token);
  if (fraction != null) {
    final denominator = int.parse(fraction[2]!);
    if (denominator == 0) return null;
    return int.parse(fraction[1]!) / denominator;
  }
  if (token == '½') return 0.5;
  return vocabulary.numberWords[token];
}

/// Weight of [amount] [unit] of [food]. Units that need to know the food
/// (a piece, a slice, a portion) resolve to 0 when [food] is null.
double gramsFor(FoodUnit unit, double amount, FoodItem? food) {
  switch (unit) {
    case FoodUnit.grams:
    case FoodUnit.millilitres:
      return amount;
    case FoodUnit.kilograms:
    case FoodUnit.litres:
      return amount * 1000;
    case FoodUnit.tablespoon:
      return amount * 15;
    case FoodUnit.teaspoon:
      return amount * 5;
    case FoodUnit.cup:
    case FoodUnit.glass:
      return amount * 200;
    case FoodUnit.handful:
      return amount * 30;
    case FoodUnit.piece:
      if (food == null) return 0;
      return amount * (food.pieceG ?? food.portionG);
    case FoodUnit.slice:
      if (food == null) return 0;
      return amount * (food.sliceG ?? food.pieceG ?? 30);
    case FoodUnit.portion:
      if (food == null) return 0;
      return amount * food.portionG;
  }
}
