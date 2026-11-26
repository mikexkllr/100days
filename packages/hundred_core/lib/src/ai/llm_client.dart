import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// What a request is for. The server books every request against the
/// user's monthly AI allowance and may treat purposes differently; the app
/// also uses it to decide what a free account gets.
enum LlmPurpose {
  /// The coach's daily line and nudge texts.
  coach,

  /// Estimating a meal from text or a photo, meal ideas, targets.
  food,

  /// Generating a meal plan or a shopping list.
  plan,

  /// The planning chat.
  chat,
}

/// An image attached to a prompt, already downscaled and stripped of
/// metadata by the app.
@immutable
class LlmImage {
  const LlmImage({required this.bytes, this.mimeType = 'image/jpeg'});

  final Uint8List bytes;
  final String mimeType;
}

/// Port for a language model. The app binds it to a cloud model — through
/// the project's own gateway, or straight to a provider with the user's own
/// key. The core only builds prompts and checks answers; it never assumes a
/// particular model or vendor.
abstract class LlmClient {
  /// Human-readable model name for the settings screen.
  String get modelName;

  /// False when no model can be reached: signed out, no allowance left,
  /// no key configured.
  bool get isReady;

  /// Completes [prompt] as a single user turn, with [images] attached.
  ///
  /// With [json] set, the model is asked for a JSON object; callers still
  /// parse defensively, because not every model complies.
  ///
  /// [schema] is a JSON Schema for that object. A client that can pass it
  /// on asks the provider to answer in exactly that shape (structured
  /// output); one that cannot treats it as [json]. Either way the answer is
  /// still checked by the caller.
  Future<String> generate(
    String prompt, {
    List<LlmImage> images = const <LlmImage>[],
    LlmPurpose purpose = LlmPurpose.food,
    int maxTokens = 400,
    double temperature = 0.7,
    Duration timeout = const Duration(seconds: 30),
    bool json = false,
    Map<String, Object?>? schema,
  });
}

/// Stand-in used when no model is reachable. Every call fails fast so the
/// caller falls back to the rule-based coach or the food table instead of
/// hanging.
class UnavailableLlmClient implements LlmClient {
  const UnavailableLlmClient();

  @override
  String get modelName => 'none';

  @override
  bool get isReady => false;

  @override
  Future<String> generate(
    String prompt, {
    List<LlmImage> images = const <LlmImage>[],
    LlmPurpose purpose = LlmPurpose.food,
    int maxTokens = 400,
    double temperature = 0.7,
    Duration timeout = const Duration(seconds: 30),
    bool json = false,
    Map<String, Object?>? schema,
  }) =>
      Future<String>.error(StateError('No language model available'));
}
