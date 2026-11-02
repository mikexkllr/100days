import 'dart:async';
import 'dart:io';

import 'package:hundred_core/hundred_core.dart';
import 'package:llamadart/llamadart.dart';

import 'llm_runtime.dart';

/// Runs an installed GGUF model with llama.cpp, through llamadart.
///
/// The prompt never leaves the phone: llamadart loads the file from the
/// model directory and runs it in a worker isolate; there is no network path
/// in here at all. One model, one context, so generations are queued rather
/// than run side by side.
class LlamaCppRuntime implements LocalLlmRuntime {
  LlamaCppRuntime({required this.spec, required this.file});

  final LocalModelSpec spec;
  final File file;

  LlamaEngine? _engine;
  Future<void>? _loading;
  Future<void> _queue = Future<void>.value();
  bool _supportsJson = false;

  @override
  String get modelName => spec.name;

  @override
  bool get isReady => _engine != null;

  @override
  int? get sizeBytes => file.existsSync() ? file.lengthSync() : null;

  @override
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    // A 2 k context covers every prompt the app writes with room for the
    // answer, at a fraction of the memory the 4 k default takes.
    final engine = await LlamaEngine.load(
      LlamaModel(ModelSource.path(file.path)),
      params: const ModelParams(contextSize: 2048),
    );
    try {
      _supportsJson = (await engine.capabilities).supportsStructuredOutput;
    } on Object {
      _supportsJson = false;
    }
    _engine = engine;
  }

  @override
  Future<String> generate(
    String prompt, {
    int maxTokens = 200,
    double temperature = 0.8,
    Duration timeout = const Duration(seconds: 20),
    bool json = false,
  }) {
    final engine = _engine;
    if (engine == null) {
      return Future<String>.error(StateError('Model not loaded'));
    }
    final result = Completer<String>();
    _queue = _queue.then((_) async {
      try {
        final stream = engine.create(
          <LlamaChatMessage>[
            LlamaChatMessage.fromText(
              role: LlamaChatRole.user,
              text: prompt,
            ),
          ],
          params: GenerationParams(
            maxTokens: maxTokens,
            temp: temperature,
          ),
          // A coach line or a calorie estimate does not need a visible
          // chain of thought — and on a phone it would triple the wait.
          enableThinking: false,
          responseFormat: json && _supportsJson
              ? const <String, dynamic>{'type': 'json_object'}
              : null,
        );
        // Leaving the loop cancels the subscription, which stops the
        // generation — a timed-out request must not keep the queue busy.
        final deadline = DateTime.now().add(timeout);
        final buffer = StringBuffer();
        await for (final LlamaCompletionChunk chunk
            in stream.timeout(timeout)) {
          buffer.write(chunk.text);
          if (DateTime.now().isAfter(deadline)) {
            throw TimeoutException('Generation took too long', timeout);
          }
        }
        result.complete(buffer.toString());
      } on Object catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  @override
  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    _loading = null;
    await engine?.dispose();
  }
}
