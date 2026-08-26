import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/llm_runtime.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// On-device model management.
///
/// The app never downloads weights by itself and never sends a prompt off the
/// device. Both are deliberate: a coach that knows about your relapses is
/// exactly the kind of thing that must not have a network path.
class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  LocalModelSpec? _installed;
  String? _directory;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final LocalModelManager manager = ref.read(modelManagerProvider);
    try {
      final LocalModelSpec? installed = await manager.installedModel();
      final String path = (await manager.directory()).path;
      if (!mounted) return;
      setState(() {
        _installed = installed;
        _directory = path;
        _loading = false;
      });
    } on Object {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<CoachEngine> coach = ref.watch(coachEngineProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          AppCard(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.violet.withValues(alpha: 0.18),
                AppColors.surface,
              ],
            ),
            border: AppColors.violet.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.memory, color: AppColors.violet),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Text(
                        coach.maybeWhen(
                          data: (CoachEngine engine) => engine.modelName == null
                              ? l10n.coachEngineRuleBased
                              : l10n.coachEngineModel(engine.modelName!),
                          orElse: () => l10n.aiLoading,
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  GgufLlmRuntime.hasBackend
                      ? l10n.aiBackendPresent
                      : l10n.aiBackendMissing,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          SectionHeader(l10n.aiSupportedModels),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(),
              ),
            )
          else
            for (final LocalModelSpec spec in kSupportedModels)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ModelCard(
                  spec: spec,
                  installed: _installed?.id == spec.id,
                ),
              ),
          SectionHeader(l10n.aiInstallTitle),
          AppCard(
            color: AppColors.surfaceHigh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.aiInstallBody,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                SelectableText(
                  _directory ?? '…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.aiNoAutoDownload,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 12.5,
                      ),
                ),
              ],
            ),
          ),
          SectionHeader(l10n.aiWhatItSeesTitle),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.aiWhatItSeesBody,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Pill(l10n.aiNoNetworkBadge,
                    color: AppColors.lime, filled: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.spec, required this.installed});

  final LocalModelSpec spec;
  final bool installed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCard(
      border: installed ? AppColors.lime : null,
      color: installed
          ? AppColors.lime.withValues(alpha: 0.06)
          : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(spec.name,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (installed)
                Pill(l10n.aiInstalled, color: AppColors.lime, filled: true)
              else
                Pill(l10n.aiGigabytes(
                    (spec.approxBytes / 1e9).toStringAsFixed(1))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.modelDescription(spec.id),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: SelectableText(
                  spec.fileName,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                      ),
                ),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(spec.sourceUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(l10n.aiSource),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
