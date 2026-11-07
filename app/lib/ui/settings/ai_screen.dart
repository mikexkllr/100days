import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/device_profile.dart';
import '../../data/llm_runtime.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

String _gb(num bytes) => (bytes / 1e9).toStringAsFixed(1);

/// Which phone this is, which model fits it, and the button that fetches
/// it. The same card in onboarding and in settings.
///
/// The download is the only network traffic the AI ever causes, and only on
/// a tap: the weights come from a pinned Hugging Face revision, are checked
/// against their SHA-256, and from then on everything runs offline.
class ModelSetupCard extends ConsumerWidget {
  const ModelSetupCard({super.key, this.showAlternatives = true});

  /// Settings show every model; onboarding keeps it to the proposal and the
  /// smaller ones that fit.
  final bool showAlternatives;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final DeviceProfile device =
        ref.watch(deviceProfileProvider).valueOrNull ?? DeviceProfile.unknown;
    final LocalModelSpec? installed =
        ref.watch(installedModelProvider).valueOrNull;
    final ModelDownloadState download = ref.watch(modelDownloadProvider);
    final LocalModelSpec? recommended = recommendedModel(device);

    final String deviceLine = device.model.isEmpty
        ? l10n.aiDeviceUnknown
        : device.advertisedRamGb == null
            ? device.model
            : l10n.aiDeviceLine(device.model, device.advertisedRamGb!);

    final LocalModelSpec? downloading =
        download.isActive ? download.spec : null;
    // What the big card shows: the model being downloaded, the one on the
    // phone, or the proposal — in that order.
    final LocalModelSpec? shown = downloading ?? installed ?? recommended;

    Widget alternative(LocalModelSpec spec, {required bool fits}) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _ModelTile(
            key: Key('ai-option-${spec.id}'),
            spec: spec,
            badge: !fits
                ? l10n.aiTooBig
                : spec.id == recommended?.id
                    ? l10n.aiRecommended
                    : l10n.aiFits,
            badgeColor: fits ? AppColors.textSecondary : AppColors.danger,
            trailing: TextButton(
              onPressed: download.isActive
                  ? null
                  : () => ref.read(modelDownloadProvider.notifier).start(spec),
              child: Text(l10n.aiDownloadThis(_gb(spec.sizeBytes))),
            ),
          ),
        );

    final alternatives = modelAlternatives(device, shown);
    final bool nothingFits = !device.supportsLocalAi ||
        (shown == null && alternatives.smaller.isEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppCard(
          color: AppColors.surfaceHigh,
          child: Row(
            children: <Widget>[
              const Icon(Icons.smartphone, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(deviceLine,
                    key: const Key('ai-device-line'),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (nothingFits)
          AppCard(
            child: Text(
              l10n.aiDeviceUnsupported,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          )
        else if (shown == null)
          // Something fits, but nothing worth proposing: say so, and leave
          // the choice to the user.
          AppCard(
            key: const Key('ai-no-recommendation'),
            child: Text(
              l10n.aiNoRecommendation,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          )
        else if (downloading == null && installed != null)
          _ModelTile(
            key: const Key('ai-installed'),
            spec: installed,
            badge: l10n.aiInstalled,
            badgeColor: AppColors.success,
            trailing: TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () async {
                await ref.read(modelManagerProvider).remove(installed);
                ref.invalidate(installedModelProvider);
              },
              child: Text(l10n.aiRemove),
            ),
          )
        else
          _ModelTile(
            key: const Key('ai-recommended'),
            spec: shown,
            badge: shown.id == recommended?.id
                ? l10n.aiRecommended
                : l10n.aiFits,
            badgeColor: AppColors.primary,
            footer: _DownloadControls(spec: shown, state: download),
          ),
        if (device.supportsLocalAi) ...<Widget>[
          if (alternatives.smaller.isNotEmpty) ...<Widget>[
            SectionHeader(
              shown == null
                  ? l10n.aiOptionalModels
                  : installed != null
                      ? l10n.aiSwitchSmaller
                      : l10n.aiSmallerModels,
              subtitle: l10n.aiSmallerModelsSub,
            ),
            for (final LocalModelSpec spec in alternatives.smaller)
              alternative(spec, fits: true),
          ],
          if (showAlternatives && alternatives.larger.isNotEmpty) ...<Widget>[
            SectionHeader(l10n.aiLargerModels,
                subtitle: l10n.aiLargerModelsSub),
            for (final LocalModelSpec spec in alternatives.larger)
              alternative(spec, fits: true),
          ],
          if (showAlternatives && alternatives.tooBig.isNotEmpty) ...<Widget>[
            SectionHeader(l10n.aiTooBigModels,
                subtitle: l10n.aiTooBigModelsSub),
            for (final LocalModelSpec spec in alternatives.tooBig)
              alternative(spec, fits: false),
          ],
          if (alternatives.smaller.isNotEmpty ||
              (showAlternatives && alternatives.larger.isNotEmpty))
            Text(
              l10n.aiOneAtATime,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
            ),
        ],
      ],
    );
  }
}

class _DownloadControls extends ConsumerWidget {
  const _DownloadControls({required this.spec, required this.state});

  final LocalModelSpec spec;
  final ModelDownloadState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ModelDownloadController controller =
        ref.read(modelDownloadProvider.notifier);
    switch (state.phase) {
      case DownloadPhase.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LinearProgressIndicator(
              value: state.fraction,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.aiDownloading(_gb(state.received), _gb(state.total)),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: controller.cancel,
                  child: Text(l10n.actionCancel),
                ),
              ],
            ),
          ],
        );
      case DownloadPhase.verifying:
        return Row(
          children: <Widget>[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(l10n.aiVerifying),
          ],
        );
      case DownloadPhase.idle:
      case DownloadPhase.done:
      case DownloadPhase.failed:
      case DownloadPhase.cancelled:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (state.phase == DownloadPhase.failed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  l10n.aiDownloadFailed,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.danger, fontSize: 12.5),
                ),
              ),
            FilledButton.icon(
              key: const Key('ai-download'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              onPressed: () => controller.start(spec),
              icon: const Icon(Icons.download),
              label: Text(state.phase == DownloadPhase.idle
                  ? l10n.aiDownloadNow(_gb(spec.sizeBytes))
                  : l10n.aiDownloadResume),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.aiDownloadNote,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
            ),
          ],
        );
    }
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    super.key,
    required this.spec,
    required this.badge,
    required this.badgeColor,
    this.trailing,
    this.footer,
  });

  final LocalModelSpec spec;
  final String badge;
  final Color badgeColor;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Name and badge get the whole width: on a narrow phone a button
          // in the same row squeezed the badge until it overflowed.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(spec.name, style: Theme.of(context).textTheme.titleMedium),
              Pill(badge, color: badgeColor),
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
          const SizedBox(height: 4),
          Text(
            '${l10n.aiGigabytes(_gb(spec.sizeBytes))} · '
            '${spec.quantization} · ${spec.license}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
          // A Wrap, not a Row: two buttons side by side do not fit every
          // phone in every language, and then the second moves down.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 40),
                ),
                onPressed: () => launchUrl(
                  spec.pageUri,
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(l10n.aiSource),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (footer != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// Settings → on-device AI.
class AiScreen extends ConsumerWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<CoachEngine> coach = ref.watch(coachEngineProvider);
    final LocalModelSpec? installed =
        ref.watch(installedModelProvider).valueOrNull;

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
                AppColors.social.withValues(alpha: 0.18),
                AppColors.surface,
              ],
            ),
            border: AppColors.social.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.memory, color: AppColors.social),
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
                  coach.maybeWhen(
                    data: (CoachEngine engine) => engine.modelName != null
                        ? l10n.aiBackendPresent
                        : installed != null
                            ? l10n.aiCoachStaysRuleBased(installed.name)
                            : l10n.aiBackendMissing,
                    orElse: () => '',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          SectionHeader(l10n.aiSupportedModels),
          const ModelSetupCard(),
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
                    color: AppColors.success, filled: true),
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
        ],
      ),
    );
  }
}
