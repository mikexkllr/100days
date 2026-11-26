import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

import '../ai/llm_client.dart';
import '../plan/nutrition.dart';
import 'foods.dart';

/// The JSON shape the meal estimate asks for. An object rather than a bare
/// list: a model that constrains its output to JSON only produces objects.
///
/// The example carries real numbers on purpose: with zeros, small models
/// copied the shape and put the piece count into `grams` ("2 eggs" → 2 g).
const String kFoodEstimateJson =
    '{"foods":[{"name":"Pizza","grams":100,"kcal":266,"protein":11,'
    '"carbs":33,"fat":10}]}';

/// [kFoodEstimateJson] as a JSON Schema, for structured output. The checks
/// on every food still apply.
const Map<String, Object?> kFoodEstimateSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'foods': <String, Object?>{
      'type': 'array',
      'items': <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'name': <String, Object?>{'type': 'string'},
          'grams': <String, Object?>{'type': 'number'},
          'kcal': <String, Object?>{'type': 'number'},
          'protein': <String, Object?>{'type': 'number'},
          'carbs': <String, Object?>{'type': 'number'},
          'fat': <String, Object?>{'type': 'number'},
        },
        'required': <String>['name', 'grams', 'kcal', 'protein', 'carbs', 'fat'],
      },
    },
  },
  'required': <String>['foods'],
};

/// A food the language model recognised in a description or a photo, with
/// its estimate.
@immutable
class FoodEstimate {
  const FoodEstimate({
    required this.name,
    required this.grams,
    required this.nutrients,
  });

  final String name;
  final double grams;
  final Nutrients nutrients;
}

/// One food as a model writes it — `name`, `grams`, `kcal`, `protein`,
/// `carbs`, `fat` — or null when it does not hold up: at most 9 kcal a gram
/// (pure fat) plus a margin, and nothing heavier than a family-size
/// portion. What an estimate and Funki's diary entries both go through.
FoodEstimate? foodEstimateFrom(Object? item) {
  if (item is! Map) return null;
  final name = item['name'];
  final grams = _num(item['grams']);
  final kcal = _num(item['kcal']);
  if (name is! String || name.trim().isEmpty) return null;
  if (grams == null || kcal == null) return null;
  if (grams <= 0 || grams > 3000 || kcal < 0) return null;
  if (kcal > grams * 9.5 + 20) return null;
  return FoodEstimate(
    name: name.trim(),
    grams: grams,
    nutrients: Nutrients(
      kcal: kcal,
      proteinG: _num(item['protein']) ?? 0,
      carbsG: _num(item['carbs']) ?? 0,
      fatG: _num(item['fat']) ?? 0,
    ),
  );
}

/// New targets the model proposes from a wish like "fewer carbs, I train in
/// the evening". Never applied by itself: the user sees it and confirms.
@immutable
class TargetProposal {
  const TargetProposal({
    required this.kcal,
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatPercent,
    this.reason,
  });

  final int kcal;
  final int proteinPercent;
  final int carbsPercent;
  final int fatPercent;

  /// The model's one-line explanation, in the user's language. Carried
  /// verbatim and labelled as model output.
  final String? reason;

  NutritionGoals toGoals() => NutritionGoals(
        kcalTarget: kcal,
        preset: MacroPreset.custom,
        proteinPercent: proteinPercent,
        carbsPercent: carbsPercent,
        fatPercent: fatPercent,
      );
}

/// The prompts the nutrition assistant sends. A port, for the same reason as
/// the coach's: the prompt has to be in the language the user reads.
abstract class NutritionPromptBuilder {
  String estimateFoods(String text);

  /// The question that goes with a photo of a meal. [hint] is what the user
  /// typed next to it ("only half of it", "with oat milk"), or null.
  String estimateFoodsFromPhoto(String? hint);

  String mealIdeas({
    required MealSlotKind slot,
    required int kcal,
    required int proteinG,
    String? wish,
  });

  String adjustTargets({required NutritionPlan plan, required String wish});
}

class EnglishNutritionPrompts implements NutritionPromptBuilder {
  const EnglishNutritionPrompts();

  @override
  String estimateFoods(String text) => '''
You are a nutrition assistant. Estimate what this person ate:
"$text"

For each food, estimate the total weight in grams (2 eggs are about 110 g,
not 2) and the calories and macros of that whole amount.
Answer with JSON only, in this form:
$kFoodEstimateJson
''';

  @override
  String estimateFoodsFromPhoto(String? hint) => '''
You are a nutrition assistant. The photo shows what this person is about to
eat.${hint == null || hint.trim().isEmpty ? '' : ' They add: "${hint.trim()}".'}

List every food you can see. For each, estimate the weight in grams from the
plate, the cutlery and the packaging around it, and the calories and macros
of that whole amount. Leave out anything you cannot see. If the photo shows
no food, answer {"foods":[]}.
Answer with JSON only, in this form:
$kFoodEstimateJson
''';

  @override
  String mealIdeas({
    required MealSlotKind slot,
    required int kcal,
    required int proteinG,
    String? wish,
  }) =>
      '''
Suggest 3 simple ${slot.name} ideas with about $kcal kcal and at least
$proteinG g protein each.${wish == null || wish.isEmpty ? '' : ' Wish: "$wish".'}
One idea per line, at most 12 words each, with the estimated kcal at the end.
No numbering, no preamble.
''';

  @override
  String adjustTargets({required NutritionPlan plan, required String wish}) =>
      '''
You are a nutrition coach. Current daily target: ${plan.kcal} kcal,
${plan.proteinG} g protein, ${plan.carbsG} g carbs, ${plan.fatG} g fat.
Energy expenditure: ${plan.tdee} kcal.
The user wants: "$wish"

Propose new targets. Stay between $kMinCustomKcal and $kMaxCustomKcal kcal
and never more than 25% below the expenditure.
Answer with JSON only, exactly in this form:
{"kcal":0,"protein_pct":0,"carbs_pct":0,"fat_pct":0,"reason":"one short sentence"}
''';
}

/// Told why a model call failed before it had an answer: no network, a
/// timeout, an allowance used up. Not called when the model answered with
/// something unusable — that is a different thing to tell the user.
typedef AiErrorCallback = void Function(Object error);

/// The model's raw answer, or null when [call] failed or took longer than
/// [timeout] — which [onError] hears about. A failing callback cannot turn
/// the null into an exception.
Future<String?> askModel(
  Future<String> Function() call, {
  required Duration timeout,
  AiErrorCallback? onError,
}) async {
  try {
    return await call().timeout(timeout);
  } on Object catch (error) {
    try {
      onError?.call(error);
    } on Object {
      // The callback is the caller's; the answer is still null.
    }
    return null;
  }
}

/// Nutrition features that need the language model: estimating a meal
/// from free text, suggesting meals, proposing new targets.
///
/// Every method returns null on any failure — no model, timeout, output that
/// does not parse, numbers that make no sense — so the caller falls back to
/// the food table and the manual editor. A diary must never show a model's
/// garbage as if it were a measurement. Where the caller passes `onError`,
/// it also learns when the call itself failed, so "offline" does not read
/// as "nothing recognised".
class NutritionAssistant {
  NutritionAssistant({
    required this.llm,
    this.prompts = const EnglishNutritionPrompts(),
    this.timeout = const Duration(seconds: 45),
  });

  final LlmClient llm;
  final NutritionPromptBuilder prompts;

  /// The whole budget for one answer, handed down to the client.
  final Duration timeout;

  bool get isAvailable => llm.isReady;

  Future<List<FoodEstimate>?> estimateFoods(
    String text, {
    AiErrorCallback? onError,
  }) async {
    if (!llm.isReady || text.trim().isEmpty) return null;
    final raw = await askModel(
      () => llm.generate(prompts.estimateFoods(text.trim()),
          purpose: LlmPurpose.food,
          maxTokens: 400,
          temperature: 0.2,
          json: true,
          schema: kFoodEstimateSchema,
          timeout: timeout),
      timeout: timeout,
      onError: onError,
    );
    return raw == null ? null : _parseEstimates(raw);
  }

  /// What is on the plate in [photo] — the same checks as for a typed
  /// description: implausible foods are dropped, and nothing reaches the
  /// diary until the user confirms it.
  Future<List<FoodEstimate>?> estimateFoodsFromPhoto(
    LlmImage photo, {
    String? hint,
    AiErrorCallback? onError,
  }) async {
    if (!llm.isReady || photo.bytes.isEmpty) return null;
    final raw = await askModel(
      () => llm.generate(prompts.estimateFoodsFromPhoto(hint),
          images: <LlmImage>[photo],
          purpose: LlmPurpose.food,
          maxTokens: 600,
          temperature: 0.2,
          json: true,
          schema: kFoodEstimateSchema,
          timeout: timeout),
      timeout: timeout,
      onError: onError,
    );
    return raw == null ? null : _parseEstimates(raw);
  }

  List<FoodEstimate>? _parseEstimates(String raw) {
    try {
      final result = <FoodEstimate>[
        for (final Object? item in _foodItems(raw))
          if (foodEstimateFrom(item) case final FoodEstimate food) food,
      ];
      return result.isEmpty ? null : result;
    } on Object {
      return null;
    }
  }

  Future<List<String>?> mealIdeas({
    required MealSlotKind slot,
    required int kcal,
    required int proteinG,
    String? wish,
  }) async {
    if (!llm.isReady) return null;
    try {
      final raw = await llm
          .generate(
            prompts.mealIdeas(
                slot: slot, kcal: kcal, proteinG: proteinG, wish: wish),
            purpose: LlmPurpose.food,
            maxTokens: 160,
            temperature: 0.7,
            timeout: timeout,
          )
          .timeout(timeout);
      final lines = raw
          .split('\n')
          .map((String l) =>
              l.replaceFirst(RegExp(r'^\s*[-*\d.)]+\s*'), '').trim())
          .where((String l) => l.length > 6)
          .take(3)
          .toList();
      return lines.isEmpty ? null : lines;
    } on Object {
      return null;
    }
  }

  Future<TargetProposal?> adjustTargets({
    required NutritionPlan plan,
    required String wish,
    AiErrorCallback? onError,
  }) async {
    if (!llm.isReady || wish.trim().isEmpty) return null;
    final raw = await askModel(
      () => llm.generate(prompts.adjustTargets(plan: plan, wish: wish.trim()),
          purpose: LlmPurpose.food,
          maxTokens: 160,
          temperature: 0.3,
          json: true,
          timeout: timeout),
      timeout: timeout,
      onError: onError,
    );
    if (raw == null) return null;
    try {
      final decoded = _decode(raw, '{', '}');
      if (decoded is! Map) return null;
      final kcal = _num(decoded['kcal'])?.round();
      final p = _num(decoded['protein_pct'])?.round();
      final c = _num(decoded['carbs_pct'])?.round();
      final f = _num(decoded['fat_pct'])?.round();
      if (kcal == null || p == null || c == null || f == null) return null;
      if (kcal < kMinCustomKcal || kcal > kMaxCustomKcal) return null;
      // The same guard rail the computed plan has: no crash diets, whatever
      // the wish was.
      if (kcal < plan.tdee * 0.75) return null;
      final sum = p + c + f;
      if (p < 10 || c < 5 || f < 15 || sum < 95 || sum > 105) return null;
      final reason = decoded['reason'];
      return TargetProposal(
        kcal: kcal,
        proteinPercent: p,
        carbsPercent: c,
        fatPercent: 100 - p - c,
        reason: reason is String && reason.trim().isNotEmpty
            ? reason.trim()
            : null,
      );
    } on Object {
      return null;
    }
  }

  /// The food objects in [raw], whichever shape the model chose: the asked
  /// for `{"foods": [...]}`, a bare list (a llm without JSON mode), or a
  /// single food object (a JSON mode that forces one object).
  List<Object?> _foodItems(String raw) {
    final start = raw.indexOf(RegExp(r'[\[{]'));
    if (start < 0) return const <Object?>[];
    final Object? decoded = raw[start] == '['
        ? _decode(raw, '[', ']')
        : _decode(raw, '{', '}');
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final String key in const <String>['foods', 'items', 'food']) {
        final Object? list = decoded[key];
        if (list is List) return list;
      }
      if (decoded.containsKey('name')) return <Object?>[decoded];
    }
    return const <Object?>[];
  }

  /// Small models wrap JSON in prose or code fences; take the outermost
  /// bracketed span and decode that.
  Object? _decode(String raw, String open, String close) {
    final start = raw.indexOf(open);
    final end = raw.lastIndexOf(close);
    if (start < 0 || end <= start) return null;
    return jsonDecode(raw.substring(start, end + 1));
  }

}

double? _num(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}
