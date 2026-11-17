import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/backend_config.dart';
import '../../data/app_repository.dart';
import '../../data/feed_sync.dart';
import '../../data/locale_store.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'ai_screen.dart';
import 'privacy_screen.dart';
import 'social_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String repositoryUrl =
      'https://github.com/mikexkllr/100days';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<AppSnapshot> async = ref.watch(appStateProvider);
    final AsyncValue<CoachEngine> coach = ref.watch(coachEngineProvider);
    final AsyncValue<SyncReport> lastSync = ref.watch(syncReportsProvider);
    final String? email = ref.watch(accountEmailProvider);
    final BackendConfig backend = ref.watch(backendConfigProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) => Center(child: Text('$error')),
      data: (AppSnapshot snapshot) => ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          // The dock floats over the end of the list.
          AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          AppCard(
            child: Row(
              children: <Widget>[
                EmojiAvatar(snapshot.me.profile.avatarEmoji, size: 50),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(snapshot.me.profile.displayName,
                          style: Theme.of(context).textTheme.titleLarge),
                      if (email != null)
                        Text(
                          email,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.textTertiary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(l10n.setAccountSection),
          _Row(
            icon: Icons.lock_outline,
            iconColor: AppColors.success,
            title: l10n.setPrivacy,
            subtitle: l10n.setPrivacySub,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const PrivacyScreen(),
              ),
            ),
          ),
          _Row(
            icon: Icons.people_outline,
            iconColor: AppColors.social,
            title: l10n.socialSettingsTitle,
            subtitle: l10n.socialSettingsSub,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    const SocialSettingsScreen(),
              ),
            ),
          ),
          _Row(
            icon: Icons.sync,
            title: l10n.setSyncNow,
            subtitle: lastSync.maybeWhen(
              data: (SyncReport report) => _describeSync(l10n, report),
              orElse: () => l10n.setSyncNever,
            ),
            onTap: () async {
              final SyncReport report =
                  await ref.read(appStateProvider.notifier).syncNow();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_describeSync(l10n, report))),
              );
            },
          ),
          _Row(
            icon: Icons.dns_outlined,
            title: l10n.setServer,
            subtitle: backend.isCustom
                ? l10n.setServerCustom(
                    Uri.tryParse(backend.supabaseUrl)?.host ?? '')
                : l10n.setServerDefault,
          ),
          _Row(
            icon: Icons.logout,
            title: l10n.setSignOut,
            subtitle: l10n.setSignOutSub,
            onTap: () => _confirmSignOut(context, ref),
          ),
          _Row(
            icon: Icons.delete_forever_outlined,
            iconColor: AppColors.danger,
            title: l10n.setDeleteAccount,
            subtitle: l10n.setDeleteAccountSub,
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
          SectionHeader(l10n.setLanguageSection),
          const _LanguageRow(),
          SectionHeader(l10n.setCoachSection),
          _Row(
            icon: Icons.auto_awesome,
            iconColor: AppColors.reward,
            title: l10n.setAi,
            subtitle: coach.maybeWhen(
              data: (CoachEngine engine) => engine.modelName == null
                  ? l10n.setAiSubFree
                  : l10n.coachEngineModel(engine.modelName!),
              orElse: () => l10n.setAiSubFree,
            ),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const AiScreen(),
              ),
            ),
          ),
          SectionHeader(l10n.setAboutSection),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.setAboutTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.setAboutBody,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(repositoryUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.code, size: 18),
                  label: Text(l10n.setViewSource),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.setSignOut),
        content: Text(l10n.setSignOutBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.setSignOut),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final AppRepository repository = ref.read(repositoryProvider);
    // Send what is still waiting, so nothing logged offline is lost.
    await repository.sync.syncNow();
    await repository.clearLocal();
    await ref.read(authServiceProvider).signOut();
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.setDeleteAccountTitle),
        content: Text(l10n.setDeleteAccountBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(120, 44),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final AppRepository repository = ref.read(repositoryProvider);
    try {
      await ref.read(authServiceProvider).deleteAccount();
      await repository.clearLocal();
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.setDeleteAccountFailed)),
      );
    }
  }
}

/// One line describing the most recent sync.
String _describeSync(AppLocalizations l10n, SyncReport report) {
  if (!report.ok) return l10n.setSyncOffline;
  return l10n.setSyncDone(report.sent, report.received);
}

/// System language by default, with an explicit override for the many people
/// whose phone language is not the language they think in.
class _LanguageRow extends ConsumerWidget {
  const _LanguageRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final Locale? selected = ref.watch(localeProvider);
    final String activeName = _languageName(l10n, Localizations.localeOf(context));

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.translate,
                    size: 20, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l10n.setLanguage,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        selected == null
                            ? l10n.setLanguageSystemSub(activeName)
                            : _languageName(l10n, selected),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                ChoiceChip(
                  label: Text(l10n.setLanguageSystem),
                  selected: selected == null,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  onSelected: (_) =>
                      ref.read(localeProvider.notifier).set(null),
                ),
                for (final Locale locale in kSupportedLocales)
                  ChoiceChip(
                    label: Text(_languageName(l10n, locale)),
                    selected: selected?.languageCode == locale.languageCode,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    onSelected: (_) =>
                        ref.read(localeProvider.notifier).set(locale),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _languageName(AppLocalizations l10n, Locale locale) =>
      locale.languageCode == 'de'
          ? l10n.setLanguageGerman
          : l10n.setLanguageEnglish;
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: iconColor ?? AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
