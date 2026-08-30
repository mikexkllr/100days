import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_repository.dart';
import '../../data/health_import_service.dart';
import '../../l10n/health_l10n.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// Where the watch gets connected.
///
/// The screen is built around one promise: nothing is read that the user did
/// not release, and nothing that is read goes anywhere but into their own
/// feed. The rules the import follows are printed here in full rather than
/// buried in a privacy policy, because they are the reason the feature is
/// defensible at all.
class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});

  static const String healthConnectPlayStore =
      'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata';

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _available = false;
  HealthAuthorization _status = HealthAuthorization.unavailable;
  HealthImportResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final HealthImportService service = ref.read(healthImportProvider);
    try {
      final bool available = await service.isAvailable();
      final HealthAccess access =
          available ? await service.currentAccess() : HealthAccess.unavailable;
      if (!mounted) return;
      setState(() {
        _available = available;
        _status = access.status;
        _loading = false;
      });
    } on Object {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _grant() async {
    setState(() => _busy = true);
    try {
      final HealthAccess access =
          await ref.read(healthImportProvider).requestAccess();
      if (!mounted) return;
      setState(() => _status = access.status);
      if (access.canRead) await _import();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    final HealthImportResult result =
        await ref.read(appStateProvider.notifier).importHealth();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastResult = result;
    });

    final AppLocalizations l10n = context.l10n;
    final int total = result.written + result.updated;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          total == 0 ? l10n.healthImportedNothing : l10n.healthImported(total),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final HealthPlatform platform = ref.watch(healthSourceProvider).platform;
    final Set<HabitCategory> enabled = ref.watch(healthCategoriesProvider);
    final AsyncValue<AppSnapshot> async = ref.watch(appStateProvider);
    final Challenge? challenge = async.valueOrNull?.challenge;

    // Only habits the user actually picked, and only those a sensor can speak
    // for. Offering the rest would be offering something that never fires.
    final List<Habit> linkable = <Habit>[
      for (final Habit habit in challenge?.habits ?? const <Habit>[])
        if (healthBindingFor(habit.category) != null) habit,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          _header(context, l10n, platform),
          if (platform == HealthPlatform.healthConnect && !_loading && !_available)
            _missingProvider(context, l10n)
          else ...<Widget>[
            // Habits first, then access: picking a habit is what decides
            // which permissions are asked for, so the order on screen is the
            // order the user has to do it in.
            SectionHeader(l10n.healthHabitsSection),
            if (linkable.isEmpty)
              AppCard(
                child: Text(
                  l10n.healthHabitsEmpty,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              )
            else
              for (final Habit habit in linkable)
                _HabitToggle(
                  habit: habit,
                  platform: platform,
                  enabled: enabled.contains(habit.category),
                ),
            SectionHeader(l10n.healthAccessSection),
            _accessCard(context, l10n, anyEnabled: enabled.isNotEmpty),
            SectionHeader(l10n.healthImportSection),
            _importCard(context, l10n, enabled.isNotEmpty),
          ],
          SectionHeader(l10n.healthRulesSection),
          _rulesCard(context, l10n),
          SectionHeader(l10n.healthHonestySection),
          AppCard(
            child: Text(
              l10n.healthHonestyBody,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(
    BuildContext context,
    AppLocalizations l10n,
    HealthPlatform platform,
  ) =>
      AppCard(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.lime.withValues(alpha: 0.16),
            AppColors.surface,
          ],
        ),
        border: AppColors.lime.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.watch, color: AppColors.lime),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Text(
                    l10n.healthPlatformName(platform),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.healthIntro(platform),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Pill(l10n.healthNoNetworkBadge,
                color: AppColors.lime, filled: true),
          ],
        ),
      );

  Widget _missingProvider(BuildContext context, AppLocalizations l10n) =>
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: AppCard(
          color: AppColors.surfaceHigh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.healthUnavailableTitle,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.healthUnavailableBody,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(HealthScreen.healthConnectPlayStore),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(l10n.healthGetHealthConnect),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _accessCard(
    BuildContext context,
    AppLocalizations l10n, {
    required bool anyEnabled,
  }) {
    if (_loading) {
      return const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final (String title, String? body, Color color) = switch (_status) {
      HealthAuthorization.granted => (
          l10n.healthGranted,
          null,
          AppColors.lime,
        ),
      HealthAuthorization.unknown => (
          l10n.healthUnknown,
          l10n.healthUnknownBody,
          AppColors.textSecondary,
        ),
      HealthAuthorization.denied => (
          l10n.healthDenied,
          l10n.healthDeniedBody,
          AppColors.danger,
        ),
      HealthAuthorization.unavailable => (
          l10n.setHealthOff,
          null,
          AppColors.textTertiary,
        ),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Pill(l10n.healthPlatformName(
                  ref.read(healthSourceProvider).platform),
                  color: color),
            ],
          ),
          if (body != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: _busy || !anyEnabled ? null : _grant,
                child: Text(l10n.healthGrant),
              ),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    ref.read(healthImportProvider).openSystemSettings(),
                child: Text(l10n.healthOpenSystem),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _importCard(
    BuildContext context,
    AppLocalizations l10n,
    bool anyEnabled,
  ) {
    final DateTime? last = ref.read(healthPreferencesProvider).lastImportAt();
    final HealthImportResult? result = _lastResult;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _AutoImportSwitch(enabled: anyEnabled),
          const Divider(height: AppSpacing.lg, color: AppColors.outline),
          Text(
            l10n.healthLastImport(
              last == null
                  ? l10n.healthNever
                  : MaterialLocalizations.of(context).formatMediumDate(last),
            ),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary, fontSize: 12.5),
          ),
          if (result != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              result.changedSomething
                  ? l10n.healthImported(result.written + result.updated)
                  : l10n.healthImportedNothing,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.lime, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _busy || !anyEnabled ? null : _import,
              icon: _busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download, size: 18),
              label: Text(_busy ? l10n.healthImporting : l10n.healthImportNow),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rulesCard(BuildContext context, AppLocalizations l10n) {
    final TextStyle? style = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: AppColors.textSecondary);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String rule in <String>[
            l10n.healthRuleManual,
            l10n.healthRuleRelapse,
            l10n.healthRuleAbstain,
            l10n.healthRuleRest,
            l10n.healthRuleUpwards,
            l10n.healthRuleBackfill(kHealthBackfillDays),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('· ', style: TextStyle(color: AppColors.lime)),
                  Expanded(child: Text(rule, style: style)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AutoImportSwitch extends ConsumerStatefulWidget {
  const _AutoImportSwitch({required this.enabled});

  final bool enabled;

  @override
  ConsumerState<_AutoImportSwitch> createState() => _AutoImportSwitchState();
}

class _AutoImportSwitchState extends ConsumerState<_AutoImportSwitch> {
  late bool _on = ref.read(healthPreferencesProvider).autoImport();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.healthAutoImport,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                l10n.healthAutoImportBody,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
              ),
            ],
          ),
        ),
        Switch(
          value: _on && widget.enabled,
          onChanged: widget.enabled
              ? (bool value) async {
                  setState(() => _on = value);
                  await ref
                      .read(healthPreferencesProvider)
                      .setAutoImport(value);
                }
              : null,
        ),
      ],
    );
  }
}

class _HabitToggle extends ConsumerWidget {
  const _HabitToggle({
    required this.habit,
    required this.platform,
    required this.enabled,
  });

  final Habit habit;
  final HealthPlatform platform;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final HealthBinding binding = healthBindingFor(habit.category)!;
    final bool supported =
        healthMetricSpec(binding.metric).isSupportedOn(platform);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: <Widget>[
            Text(habit.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.habitLabel(habit),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    supported
                        ? l10n.healthReads(
                            l10n.healthMetricName(binding.metric))
                        : l10n.healthNotOnPlatform,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: supported
                              ? AppColors.textSecondary
                              : AppColors.textTertiary,
                          fontSize: 12.5,
                        ),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled && supported,
              onChanged: supported
                  ? (bool value) => ref
                      .read(healthCategoriesProvider.notifier)
                      .toggle(habit.category, on: value)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
