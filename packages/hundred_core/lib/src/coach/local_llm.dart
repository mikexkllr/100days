import 'dart:async';

/// Port for an on-device text model.
///
/// The app is designed so that no prompt ever leaves the phone: the whole
/// point of pairing a habit tracker with a coach is that the coach knows about
/// your relapses, your weight and your friends — data that has no business on
/// someone else's server. Implementations bind whatever local runtime is
/// available (llama.cpp via FFI, MediaPipe LLM Inference, Core ML …).
abstract class LocalLlmRuntime {
  /// Human-readable model name for the settings screen.
  String get modelName;

  /// False while the model is missing or still loading.
  bool get isReady;

  /// Approximate on-disk size, for the download screen.
  int? get sizeBytes;

  Future<void> load();

  /// Completes [prompt] as a single user turn.
  ///
  /// With [json] set, a runtime that can constrain its output to JSON does
  /// so; callers still parse defensively, because not every runtime can.
  Future<String> generate(
    String prompt, {
    int maxTokens = 200,
    double temperature = 0.8,
    Duration timeout = const Duration(seconds: 20),
    bool json = false,
  });

  Future<void> dispose();
}

/// Stand-in used when no model is installed. Every call fails fast so the
/// caller falls back to the rule-based coach instead of hanging.
class UnavailableLlmRuntime implements LocalLlmRuntime {
  const UnavailableLlmRuntime();

  @override
  String get modelName => 'none';

  @override
  bool get isReady => false;

  @override
  int? get sizeBytes => null;

  @override
  Future<void> load() async {}

  @override
  Future<String> generate(
    String prompt, {
    int maxTokens = 200,
    double temperature = 0.8,
    Duration timeout = const Duration(seconds: 20),
    bool json = false,
  }) =>
      Future<String>.error(StateError('No local model available'));

  @override
  Future<void> dispose() async {}
}
