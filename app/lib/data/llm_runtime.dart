import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'device_profile.dart';

/// How capable a model is — and how much phone it needs.
enum ModelTier { light, balanced, strong, max }

/// An on-device model the app can download and run.
///
/// Pinned to a repository revision and a SHA-256, so the file that lands on
/// the phone is exactly the file that was reviewed — not whatever the
/// repository holds the day someone taps download.
class LocalModelSpec {
  const LocalModelSpec({
    required this.id,
    required this.name,
    required this.tier,
    required this.repository,
    required this.revision,
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
    required this.minRamMb,
    required this.license,
  });

  /// Stable identifier; the app's localizations describe the model under it.
  final String id;

  /// The model's own name, which is not translated.
  final String name;
  final ModelTier tier;

  /// Hugging Face repository holding the GGUF file.
  final String repository;
  final String revision;
  final String fileName;
  final int sizeBytes;
  final String sha256;

  /// Physical memory a phone needs before the app suggests this model. The
  /// file sits in RAM, plus the context cache, plus everything else running.
  final int minRamMb;

  final String license;

  Uri get downloadUri => Uri.parse(
      'https://huggingface.co/$repository/resolve/$revision/$fileName');

  Uri get pageUri => Uri.parse('https://huggingface.co/$repository');

  double get sizeGb => sizeBytes / 1e9;

  bool fits(DeviceProfile device) {
    final ram = device.ramMb;
    if (!device.supportsLocalAi) return false;
    // Unknown memory: only the smallest model is a safe bet.
    if (ram == null) return tier == ModelTier.light;
    return ram >= minRamMb;
  }
}

/// Small instruction-tuned models that run on a phone, smallest first.
///
/// Chosen for 2026 phones: Qwen3.5 (0.8B, 2B) and Gemma 4 (E2B, E4B) are the
/// strongest open models at these sizes, both multilingual — which matters,
/// because this app talks German as well as English — and both under
/// Apache 2.0. Q4_K_M quantisation is the usual phone trade-off between
/// size, speed and quality.
const List<LocalModelSpec> kModelCatalog = <LocalModelSpec>[
  LocalModelSpec(
    id: 'qwen3.5-0.8b-q4',
    name: 'Qwen3.5 0.8B',
    tier: ModelTier.light,
    repository: 'unsloth/Qwen3.5-0.8B-GGUF',
    revision: '6ab461498e2023f6e3c1baea90a8f0fe38ab64d0',
    fileName: 'Qwen3.5-0.8B-Q4_K_M.gguf',
    sizeBytes: 532517120,
    sha256:
        'bd258782e35f7f458f8aced1adc053e6e92e89bc735ba3be89d38a06121dc517',
    // "3 GB" phones report about 2.7 GiB.
    minRamMb: 2560,
    license: 'Apache-2.0',
  ),
  LocalModelSpec(
    id: 'qwen3.5-2b-q4',
    name: 'Qwen3.5 2B',
    tier: ModelTier.balanced,
    repository: 'unsloth/Qwen3.5-2B-GGUF',
    revision: 'f6d5376be1edb4d416d56da11e5397a961aca8ae',
    fileName: 'Qwen3.5-2B-Q4_K_M.gguf',
    sizeBytes: 1280835840,
    sha256:
        'aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223',
    // "6 GB" phones report about 5.5 GiB.
    minRamMb: 5 * 1024,
    license: 'Apache-2.0',
  ),
  LocalModelSpec(
    id: 'gemma-4-e2b-q4',
    name: 'Gemma 4 E2B',
    tier: ModelTier.strong,
    repository: 'unsloth/gemma-4-E2B-it-GGUF',
    revision: '0314792d7f1f7e229411f620751375812bb9faf2',
    fileName: 'gemma-4-E2B-it-Q4_K_M.gguf',
    sizeBytes: 3106738272,
    sha256:
        '740185b21d22ceb83a11c3aa62ad5842ef32c70f6096d756bbee85a1e4ec34b8',
    // "8 GB" phones report about 7.4 GiB.
    minRamMb: 7 * 1024,
    license: 'Apache-2.0',
  ),
  LocalModelSpec(
    id: 'gemma-4-e4b-q4',
    name: 'Gemma 4 E4B',
    tier: ModelTier.max,
    repository: 'unsloth/gemma-4-E4B-it-GGUF',
    revision: 'bfc15c382204943c3a8fff0c750b94ae2364d7a3',
    fileName: 'gemma-4-E4B-it-Q4_K_M.gguf',
    sizeBytes: 4977171584,
    sha256:
        '85a896a047553e842f25297ee5b031d64ff30147d9c4af17b1e4b394cd1fab87',
    minRamMb: 11 * 1024,
    license: 'Apache-2.0',
  ),
];

LocalModelSpec? modelById(String id) {
  for (final spec in kModelCatalog) {
    if (spec.id == id) return spec;
  }
  return null;
}

/// The model the app proposes for [device]: the strongest one that fits,
/// but never the five-gigabyte one by default — that is an opt-in for
/// people who know they want it.
LocalModelSpec? recommendedModel(DeviceProfile device) {
  LocalModelSpec? best;
  for (final spec in kModelCatalog) {
    if (spec.tier == ModelTier.max) continue;
    if (spec.fits(device)) best = spec;
  }
  return best;
}

/// Finds model files in the app's model directory.
class LocalModelManager {
  LocalModelManager({Future<Directory> Function()? baseDirectory})
      : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _baseDirectory;
  Directory? _directory;

  Future<Directory> directory() async {
    final existing = _directory;
    if (existing != null) return existing;
    final support = await _baseDirectory();
    final dir = Directory(p.join(support.path, 'models'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return _directory = dir;
  }

  Future<File> targetFile(LocalModelSpec spec) async =>
      File(p.join((await directory()).path, spec.fileName));

  Future<File?> fileFor(LocalModelSpec spec) async {
    final file = await targetFile(spec);
    return file.existsSync() ? file : null;
  }

  /// The installed model, strongest first — if a user has two, they
  /// downloaded the second one on purpose.
  Future<LocalModelSpec?> installedModel() async {
    for (final spec in kModelCatalog.reversed) {
      if (await fileFor(spec) != null) return spec;
    }
    return null;
  }

  Future<void> remove(LocalModelSpec spec) async {
    final file = await fileFor(spec);
    if (file != null) await file.delete();
    final partial = File('${(await targetFile(spec)).path}.part');
    if (partial.existsSync()) await partial.delete();
  }
}
