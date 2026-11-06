import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/llama_runtime.dart';
import 'package:hundred_days/data/llm_runtime.dart';
import 'package:hundred_days/data/model_download.dart';
import 'package:hundred_days/l10n/l10n.dart';
import 'package:hundred_days/l10n/prompt_l10n.dart';

import 'helpers.dart';

/// Downloads real models from the catalog and runs them with the app's own
/// code: the pinned download and its SHA-256 check, llama.cpp through
/// llamadart, the German coach prompt and the meal estimate.
///
/// Off by default — it moves gigabytes. Run it by naming the models:
///
///     LLM_SMOKE_MODELS=qwen3.5-0.8b-q4,gemma-4-e2b-qat flutter test test/llm_smoke_test.dart
///
/// `LLM_SMOKE_DIR` picks the download folder, `LLM_SMOKE_KEEP=1` keeps the
/// files afterwards.
void main() {
  final String? ids = Platform.environment['LLM_SMOKE_MODELS'];

  test(
    'catalog models download, load and answer in German',
    () async {
      final Directory dir = Directory(
        Platform.environment['LLM_SMOKE_DIR'] ??
            '${Directory.systemTemp.path}/hundred-days-models',
      )..createSync(recursive: true);
      final AppLocalizations de =
          await AppLocalizations.delegate.load(const Locale('de'));

      final AppRepository repository = await testRepository();
      await repository.saveProfile(displayName: 'Mia', avatarEmoji: '🦊');
      await repository.startChallenge(testChallenge(
        habits: <HabitCategory>[HabitCategory.gym, HabitCategory.noSugar],
      ));
      final CoachContext context = (await repository.snapshot())
          .toCoachContext(now: DateTime(2026, 11, 6, 20));

      for (final String id in ids!.split(',')) {
        final LocalModelSpec spec = modelById(id.trim())!;
        final File target = File('${dir.path}/${spec.fileName}');

        final Stopwatch clock = Stopwatch()..start();
        if (!target.existsSync()) {
          await ModelDownloader(clientFactory: _clientFromEnvironment)
              .download(spec, target);
        }
        _log('${spec.name}: file ready after ${clock.elapsed.inSeconds} s '
            '(${(spec.sizeBytes / 1e9).toStringAsFixed(2)} GB, sha256 ok)');

        final LlamaCppRuntime runtime =
            LlamaCppRuntime(spec: spec, file: target);
        clock.reset();
        await runtime.load();
        expect(runtime.isReady, isTrue, reason: '${spec.id} did not load');
        _log('${spec.name}: loaded in ${clock.elapsedMilliseconds} ms');

        clock.reset();
        final String line = await runtime.generate(
          'Antworte auf Deutsch in genau einem Satz: Warum hilft Schlaf '
          'beim Muskelaufbau?',
          maxTokens: 60,
          temperature: 0.3,
          timeout: const Duration(minutes: 3),
        );
        _log('${spec.name}: plain answer in ${clock.elapsedMilliseconds} ms:'
            ' ${line.trim()}');
        expect(line.trim(), isNotEmpty, reason: '${spec.id} said nothing');

        clock.reset();
        final CoachDirective directive = await LocalLlmCoach(
          runtime: runtime,
          prompts: LocalizedCoachPrompts(de),
          timeout: const Duration(minutes: 3),
        ).dailyBriefing(context);
        _log('${spec.name}: coach (${directive.source.name}) in '
            '${clock.elapsedMilliseconds} ms: '
            '${directive.freeformHeadline} — ${directive.freeformBody}');

        const String meal =
            '2 Rühreier und eine Scheibe Vollkornbrot mit Butter';
        clock.reset();
        final String raw = await runtime.generate(
          LocalizedNutritionPrompts(de).estimateFoods(meal),
          maxTokens: 400,
          temperature: 0.2,
          json: true,
          timeout: const Duration(minutes: 3),
        );
        _log('${spec.name}: raw meal answer in ${clock.elapsedMilliseconds} '
            'ms: ${raw.replaceAll('\n', ' ')}');

        clock.reset();
        final List<FoodEstimate>? foods = await NutritionAssistant(
          runtime: runtime,
          prompts: LocalizedNutritionPrompts(de),
          timeout: const Duration(minutes: 3),
        ).estimateFoods(meal);
        _log('${spec.name}: meal estimate in ${clock.elapsedMilliseconds} ms:'
            ' ${foods?.map((FoodEstimate f) => '${f.name} ${f.grams.round()} g '
                '${f.nutrients.kcal.round()} kcal').join('; ') ?? 'none'}');

        await runtime.dispose();
        if (Platform.environment['LLM_SMOKE_KEEP'] != '1') {
          await target.delete();
        }
      }
    },
    skip: ids == null
        ? 'Set LLM_SMOKE_MODELS to download and run real models.'
        : false,
    timeout: const Timeout(Duration(hours: 2)),
  );
}

/// Honours HTTPS_PROXY and SSL_CERT_FILE, for running behind a proxy.
HttpClient _clientFromEnvironment() {
  final String? ca = Platform.environment['SSL_CERT_FILE'];
  final SecurityContext context = SecurityContext(withTrustedRoots: true);
  if (ca != null && File(ca).existsSync()) context.setTrustedCertificates(ca);
  return HttpClient(context: context)
    ..findProxy = HttpClient.findProxyFromEnvironment;
}

void _log(String message) {
  // ignore: avoid_print
  print(message);
}
