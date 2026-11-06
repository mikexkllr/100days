import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

import '../coach/local_llm.dart';
import '../plan/nutrition.dart';
import 'foods.dart';

/// The JSON shape the meal estimate asks for. An object rather than a bare
/// list: a runtime that constrains its output to JSON (llama.cpp's
/// `json_object`) only produces objects.
///
/// The example carries real numbers on purpose: with zeros, small models
/// copied the shape and put the piece count into `grams` ("2 eggs" → 2 g).
const String kFoodEstimateJson =
    '{"foods":[{"name":"Pizza","grams":100,"kcal":266,"protein":11,'
    '"carbs":33,"fat":10}]}';

/// A food the on-device model recognised in free text, with its estimate.
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

/// Nutrition features that need the on-device model: estimating a meal
/// from free text, suggesting meals, proposing new targets.
///
/// Every method returns null on any failure — no model, timeout, output that
/// does not parse, numbers that make no sense — so the caller falls back to
/// the food table and the manual editor. A diary must never show a model's
/// garbage as if it were a measurement.
class NutritionAssistant {
  NutritionAssistant({
    required this.runtime,
    this.prompts = const EnglishNutritionPrompts(),
    this.timeout = const Duration(seconds: 45),
  });

  final LocalLlmRuntime runtime;
  final NutritionPromptBuilder prompts;

  /// The whole budget for one answer, handed down to the runtime — whose
  /// own default (20 s) cut off most meal estimates on a slower CPU.
  final Duration timeout;

  bool get isAvailable => runtime.isReady;

  Future<List<FoodEstimate>?> estimateFoods(String text) async {
    if (!runtime.isReady || text.trim().isEmpty) return null;
    try {
      final raw = await runtime
          .generate(prompts.estimateFoods(text.trim()),
              maxTokens: 400, temperature: 0.2, json: true, timeout: timeout)
          .timeout(timeout);
      final result = <FoodEstimate>[];
      for (final Object? item in _foodItems(raw)) {
        if (item is! Map) continue;
        final name = item['name'];
        final grams = _num(item['grams']);
        final kcal = _num(item['kcal']);
        if (name is! String || name.trim().isEmpty) continue;
        if (grams == null || kcal == null) continue;
        // Plausibility: at most 9 kcal per gram (pure fat) plus a margin,
        // and nothing heavier than a family-size portion.
        if (grams <= 0 || grams > 3000 || kcal < 0) continue;
        if (kcal > grams * 9.5 + 20) continue;
        result.add(FoodEstimate(
          name: name.trim(),
          grams: grams,
          nutrients: Nutrients(
            kcal: kcal,
            proteinG: _num(item['protein']) ?? 0,
            carbsG: _num(item['carbs']) ?? 0,
            fatG: _num(item['fat']) ?? 0,
          ),
        ));
      }
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
    if (!runtime.isReady) return null;
    try {
      final raw = await runtime
          .generate(
            prompts.mealIdeas(
                slot: slot, kcal: kcal, proteinG: proteinG, wish: wish),
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
  }) async {
    if (!runtime.isReady || wish.trim().isEmpty) return null;
    try {
      final raw = await runtime
          .generate(prompts.adjustTargets(plan: plan, wish: wish.trim()),
              maxTokens: 160, temperature: 0.3, json: true, timeout: timeout)
          .timeout(timeout);
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
  /// for `{"foods": [...]}`, a bare list (a runtime without JSON mode), or a
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

  double? _num(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }
}
