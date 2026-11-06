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
    required this.quantization,
    this.recommendable = true,
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

  /// Physical memory a phone needs before the app offers this model as
  /// fitting. The file sits in RAM, plus the context cache, plus everything
  /// else the phone is running.
  final int minRamMb;

  final String license;

  /// How the weights were squeezed, as shown next to the size.
  final String quantization;

  /// False for variants that are offered but never proposed by default —
  /// a smaller cut of a model the app already recommends elsewhere.
  final bool recommendable;

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
/// Checked in November 2026. Qwen3.5 Small (March 2026) is still Qwen's
/// newest small line — Qwen3.6 and 3.8 only come in large sizes — and
/// Gemma 4 E2B/E4B is still Google's on-device line. Both are multilingual,
/// which matters for an app that speaks German, and Apache 2.0.
///
/// Gemma ships as Google's quantisation-aware-trained (QAT) checkpoints in
/// Unsloth's GGUF builds rather than plain post-training Q4_K_M: smaller
/// files that agree with the full-precision model on the next token about
/// 98 % of the time (Unsloth's measurements). The "mobile" builds mix 2-bit
/// layers in for phones.
///
/// Every architecture here is one the bundled llama.cpp knows (`qwen35`,
/// `gemma4`). Liquid AI's LFM3 (October 2026) needs a newer engine than the
/// one pinned, and is under its own licence rather than Apache 2.0.
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
    quantization: 'Q4_K_M',
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
    quantization: 'Q4_K_M',
  ),
  LocalModelSpec(
    id: 'gemma-4-e2b-qat-mobile',
    name: 'Gemma 4 E2B Mobile',
    tier: ModelTier.balanced,
    repository: 'unsloth/gemma-4-E2B-it-qat-mobile-GGUF',
    revision: '46af839dc23aceb4b965ab640dae7fc1bea39bba',
    fileName: 'gemma-4-E2B-it-qat-UD-Q2_K_XL.gguf',
    sizeBytes: 2186186784,
    sha256:
        '0a5bbc20f91f92da96ab4870fa71b356c45b8500a7b8b9c3e0eb48359b72da28',
    minRamMb: 5 * 1024,
    license: 'Apache-2.0',
    quantization: 'QAT 2-bit mix',
    // Offered as the smaller Gemma, never proposed over Qwen3.5 2B, which
    // is half the size on the phones this would fit.
    recommendable: false,
  ),
  LocalModelSpec(
    id: 'gemma-4-e2b-qat',
    name: 'Gemma 4 E2B',
    tier: ModelTier.strong,
    repository: 'unsloth/gemma-4-E2B-it-qat-GGUF',
    revision: '66a399f68ddd113b06dff02fca9523e55465d11d',
    fileName: 'gemma-4-E2B-it-qat-UD-Q4_K_XL.gguf',
    sizeBytes: 2620370976,
    sha256:
        'e531007218dfab990486a5de7676a6932d6ea8dea233d1f698d7c21cf8a16889',
    // "8 GB" phones report about 7.4 GiB.
    minRamMb: 7 * 1024,
    license: 'Apache-2.0',
    quantization: 'QAT Q4',
  ),
  LocalModelSpec(
    id: 'gemma-4-e4b-qat-mobile',
    name: 'Gemma 4 E4B Mobile',
    tier: ModelTier.max,
    repository: 'unsloth/gemma-4-E4B-it-qat-mobile-GGUF',
    revision: '6a6e7121b977cefd85daa8fbc538fa485e7e8b1b',
    fileName: 'gemma-4-E4B-it-qat-UD-Q2_K_XL.gguf',
    sizeBytes: 3219532192,
    sha256:
        '79dde517866cfbb5c00230b530de17910fc7fc78f8827554d0e14281ce5faf03',
    // Twice the compute of E2B: for "12 GB" flagships (about 11.2 GiB).
    minRamMb: 11 * 1024,
    license: 'Apache-2.0',
    quantization: 'QAT 2-bit mix',
  ),
];

LocalModelSpec? modelById(String id) {
  for (final spec in kModelCatalog) {
    if (spec.id == id) return spec;
  }
  return null;
}

/// The model the app proposes for [device]: the strongest recommendable
/// one that fits.
LocalModelSpec? recommendedModel(DeviceProfile device) {
  LocalModelSpec? best;
  for (final spec in kModelCatalog) {
    if (spec.recommendable && spec.fits(device)) best = spec;
  }
  return best;
}

/// What else the user can pick instead of [shown]: the smaller models that
/// fit (less storage, less battery, quicker answers), the larger ones that
/// still fit, and the ones that are too big for this phone.
({
  List<LocalModelSpec> smaller,
  List<LocalModelSpec> larger,
  List<LocalModelSpec> tooBig,
}) modelAlternatives(DeviceProfile device, LocalModelSpec shown) {
  final smaller = <LocalModelSpec>[];
  final larger = <LocalModelSpec>[];
  final tooBig = <LocalModelSpec>[];
  for (final spec in kModelCatalog) {
    if (spec.id == shown.id) continue;
    if (!spec.fits(device)) {
      tooBig.add(spec);
    } else if (spec.sizeBytes < shown.sizeBytes) {
      smaller.add(spec);
    } else {
      larger.add(spec);
    }
  }
  // Closest to the proposal first: the next size down is the likeliest pick.
  return (
    smaller: smaller.reversed.toList(),
    larger: larger,
    tooBig: tooBig,
  );
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

  /// Deletes every other model, so one model at a time sits on the phone:
  /// switching models must not quietly double the storage used.
  Future<void> keepOnly(LocalModelSpec spec) async {
    for (final other in kModelCatalog) {
      if (other.id != spec.id) await remove(other);
    }
  }

  Future<void> remove(LocalModelSpec spec) async {
    final file = await fileFor(spec);
    if (file != null) await file.delete();
    final partial = File('${(await targetFile(spec)).path}.part');
    if (partial.existsSync()) await partial.delete();
  }
}
