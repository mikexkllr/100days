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

// A slash stays with its number: "1/2" is a half, not 1 of "/2".
final RegExp _numberGlued = RegExp(r'(\d+(?:[.,]\d+)?)([^\d\s.,/]+)');
final RegExp _number = RegExp(r'^\d+(?:[.,]\d+)?$');
final RegExp _fraction = RegExp(r'^(\d+)/(\d+)$');
final RegExp _sentenceEnd = RegExp(r'(\S*?)([.!?]+)(?=\s|$)');

const Map<String, double> _fractionGlyphs = <String, double>{
  '¼': 0.25,
  '½': 0.5,
  '¾': 0.75,
  '⅓': 1 / 3,
  '⅔': 2 / 3,
};

/// Splits a sentence like "2 Eier, 1 Scheibe Vollkornbrot und Kaffee mit
/// Milch" into items, reads the amount of each and looks the food up.
///
/// Deterministic and offline: this is the floor the language model improves
/// on, and what runs when no model is installed. Items it cannot place come
/// back with [ParsedFood.food] null so the UI can ask instead of guessing.
List<ParsedFood> parseFoodText(
  String text, {
  required FoodVocabulary vocabulary,
  required FoodLookup lookup,
}) {
  // Longest first, so "and then" is taken whole before "and".
  final words = vocabulary.separators
      .map((String s) => s.trim().toLowerCase())
      .where((String s) => s.isNotEmpty)
      .toList()
    ..sort((String a, String b) => b.length.compareTo(a.length));
  final separators = words.map(RegExp.escape).join('|');
  // The spaces around a separator are looked at, not taken, so two in a row
  // ("und dann") both split.
  final splitter = RegExp(
    separators.isEmpty
        ? r'[,;+\n&]'
        : '[,;+\\n&]|(?<=\\s)(?:$separators)(?=\\s)',
    caseSensitive: false,
  );

  // A decimal comma ("1,5 l") is not a list comma, and "1½" is one and a
  // half.
  final normalised = text
      .toLowerCase()
      .replaceAllMapped(RegExp(r'(\d),(\d)'), (Match m) => '${m[1]}.${m[2]}')
      .replaceAllMapped(
          RegExp('[${_fractionGlyphs.keys.join()}]'), (Match m) => ' ${m[0]} ')
      // A sentence ends an item too: "2 Eier. Danach eine Banane" is two of
      // them — but not the dot of "ca." or "Stk.", which the vocabulary
      // knows as words.
      .replaceAllMapped(_sentenceEnd, (Match m) {
    final word = m[1]!;
    final abbreviation = m[2] == '.' &&
        (vocabulary.unitWords.containsKey(word) ||
            vocabulary.fillerWords.contains(word) ||
            vocabulary.fillerWords.contains('$word.'));
    return abbreviation ? '$word ' : '$word\n';
  });

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
  _NumberKind? amountKind;
  var afterNumber = false;
  FoodUnit? unit;
  final words = <String>[];
  for (final String token in tokens) {
    final number = _readNumber(token, vocabulary);
    if (number != null && amount == null) {
      (amount, amountKind) = number;
      afterNumber = true;
      continue;
    }
    // Two numbers in a row are one amount: "eine halbe" is a half, "ein
    // paar" a couple, "1 1/2" one and a half.
    if (number != null && afterNumber) {
      final (double value, _NumberKind kind) = number;
      if (amountKind == _NumberKind.whole && kind == _NumberKind.fraction) {
        amount = amount! + value;
        amountKind = _NumberKind.decimal;
        continue;
      }
      if (amountKind == _NumberKind.word || kind == _NumberKind.word) {
        amount = amount! * value;
        amountKind = _NumberKind.word;
        continue;
      }
    }
    afterNumber = false;
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
  final resolvedUnit = unit ?? _unitFor(amount, food);

  return ParsedFood(
    original: chunk,
    phrase: phrase,
    amount: resolvedAmount,
    unit: resolvedUnit,
    grams: gramsFor(resolvedUnit, resolvedAmount, food),
    food: food,
  );
}

/// The unit of an amount written without one: "2 Eier" are pieces, "200
/// Reis" grams, "Pizza" one of whatever the food comes in.
FoodUnit _unitFor(double? amount, FoodItem? food) {
  final pieceG = food?.pieceG;
  if (amount == null) return pieceG != null ? FoodUnit.piece : FoodUnit.portion;
  if (pieceG != null && _isCount(amount, pieceG)) return FoodUnit.piece;
  return amount >= 10 ? FoodUnit.grams : FoodUnit.portion;
}

/// Whether a bare number before a countable food counts pieces. Small
/// numbers always do. A larger one does when, read as grams, it would be
/// less than one piece ("12 Sushi" is not 12 g) and, read as pieces, it is
/// still a meal ("150 Banane" is 150 g, not 18 kg).
bool _isCount(double amount, double pieceG) =>
    amount < 10 || (amount <= pieceG && amount * pieceG <= 1500);

/// How a number was written, which decides how two in a row combine.
enum _NumberKind { whole, decimal, fraction, word }

(double, _NumberKind)? _readNumber(String token, FoodVocabulary vocabulary) {
  if (_number.hasMatch(token)) {
    final value = double.tryParse(token.replaceAll(',', '.'));
    if (value == null) return null;
    return (
      value,
      token.contains(RegExp('[.,]')) ? _NumberKind.decimal : _NumberKind.whole,
    );
  }
  final fraction = _fraction.firstMatch(token);
  if (fraction != null) {
    final denominator = int.parse(fraction[2]!);
    if (denominator == 0) return null;
    return (int.parse(fraction[1]!) / denominator, _NumberKind.fraction);
  }
  final glyph = _fractionGlyphs[token];
  if (glyph != null) return (glyph, _NumberKind.fraction);
  final word = vocabulary.numberWords[token];
  return word == null ? null : (word, _NumberKind.word);
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
