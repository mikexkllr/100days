import 'dart:async';
import 'dart:io';

import 'package:hundred_core/hundred_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Describes an on-device model the user can install.
class LocalModelSpec {
  const LocalModelSpec({
    required this.id,
    required this.name,
    required this.fileName,
    required this.approxBytes,
    required this.sourceUrl,
  });

  /// Stable identifier; the app's localizations describe the model under it.
  final String id;

  /// The model's own name, which is not translated.
  final String name;

  final String fileName;
  final int approxBytes;

  /// Where a user can get the weights. The app never downloads a model on its
  /// own: pulling a gigabyte over someone's mobile data without asking is not
  /// something a "local-first, no surprises" app gets to do.
  final String sourceUrl;
}

/// Small instruction-tuned models that fit comfortably on a phone.
const List<LocalModelSpec> kSupportedModels = <LocalModelSpec>[
  LocalModelSpec(
    id: 'qwen2.5-1.5b-instruct-q4',
    name: 'Qwen2.5 1.5B Instruct (Q4)',
    fileName: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
    approxBytes: 1_100_000_000,
    sourceUrl: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF',
  ),
  LocalModelSpec(
    id: 'gemma-2-2b-it-q4',
    name: 'Gemma 2 2B IT (Q4)',
    fileName: 'gemma-2-2b-it-q4_k_m.gguf',
    approxBytes: 1_600_000_000,
    sourceUrl: 'https://huggingface.co/google/gemma-2-2b-it-GGUF',
  ),
  LocalModelSpec(
    id: 'smollm2-360m-instruct-q8',
    name: 'SmolLM2 360M Instruct (Q8)',
    fileName: 'smollm2-360m-instruct-q8_0.gguf',
    approxBytes: 400_000_000,
    sourceUrl: 'https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF',
  ),
];

/// Locates model files the user has placed in the app's model directory.
///
/// Binding an actual inference engine (llama.cpp through FFI, MediaPipe's LLM
/// Inference API, Core ML) is a platform-channel concern; this class owns the
/// part that is the same either way — is a model present, how big is it, and
/// which spec does it correspond to.
class LocalModelManager {
  Directory? _directory;

  Future<Directory> directory() async {
    final existing = _directory;
    if (existing != null) return existing;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'models'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return _directory = dir;
  }

  Future<File?> fileFor(LocalModelSpec spec) async {
    final file = File(p.join((await directory()).path, spec.fileName));
    return file.existsSync() ? file : null;
  }

  Future<LocalModelSpec?> installedModel() async {
    for (final spec in kSupportedModels) {
      if (await fileFor(spec) != null) return spec;
    }
    return null;
  }

  Future<void> remove(LocalModelSpec spec) async {
    final file = await fileFor(spec);
    if (file != null) await file.delete();
  }
}

/// Bridges an installed model file to the [LocalLlmRuntime] port.
///
/// Ships without an inference backend: [attachBackend] is the single seam an
/// engine plugs into, so the rest of the app can be written, tested and
/// shipped against the real coach interface today and get better output the
/// day a backend lands.
class GgufLlmRuntime implements LocalLlmRuntime {
  GgufLlmRuntime({required this.spec, required this.file});

  final LocalModelSpec spec;
  final File file;

  /// `(prompt, maxTokens, temperature) -> completion`
  static Future<String> Function(String, int, double)? _backend;

  static void attachBackend(
    Future<String> Function(String prompt, int maxTokens, double temperature)
        backend,
  ) {
    _backend = backend;
  }

  static bool get hasBackend => _backend != null;

  bool _loaded = false;

  @override
  String get modelName => spec.name;

  @override
  bool get isReady => _loaded && _backend != null;

  @override
  int? get sizeBytes => file.existsSync() ? file.lengthSync() : null;

  @override
  Future<void> load() async {
    _loaded = file.existsSync();
  }

  @override
  Future<String> generate(
    String prompt, {
    int maxTokens = 200,
    double temperature = 0.8,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final backend = _backend;
    if (backend == null || !_loaded) {
      throw StateError('No inference backend attached');
    }
    return backend(prompt, maxTokens, temperature).timeout(timeout);
  }

  @override
  Future<void> dispose() async {
    _loaded = false;
  }
}
