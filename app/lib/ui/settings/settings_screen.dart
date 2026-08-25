import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_repository.dart';
import '../../data/sync_service.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'ai_screen.dart';
import 'recovery_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String repositoryUrl =
      'https://github.com/mikexkllr/100days';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppSnapshot> async = ref.watch(appStateProvider);
    final AsyncValue<CoachEngine> coach = ref.watch(coachEngineProvider);
    final AsyncValue<SyncEvent> lastSync = ref.watch(syncEventsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) => Center(child: Text('$error')),
      data: (AppSnapshot snapshot) => ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
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
                      Text(
                        Identity.shortDid(snapshot.me.did),
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: AppColors.textTertiary,
                              fontFamily: 'monospace',
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: snapshot.me.did));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('DID kopiert.')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          const SectionHeader('Identität & Daten'),
          _Row(
            icon: Icons.key,
            iconColor: AppColors.violet,
            title: 'Wiederherstellungs-Key',
            subtitle: 'Der einzige Weg zurück zu deinem Account.',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const RecoveryScreen(),
              ),
            ),
          ),
          _Row(
            icon: Icons.storage_outlined,
            title: 'Auf diesem Gerät',
            subtitle: '${snapshot.me.headSeq} eigene Einträge · '
                '${snapshot.friends.length} verbundene Feeds',
          ),
          _Row(
            icon: Icons.delete_forever_outlined,
            iconColor: AppColors.danger,
            title: 'Alles löschen',
            subtitle: 'Identität, Challenge und alle Freunde entfernen.',
            onTap: () => _confirmWipe(context, ref),
          ),
          const SectionHeader('Netzwerk'),
          _Row(
            icon: Icons.wifi_tethering,
            iconColor: AppColors.lime,
            title: 'Lokales Netzwerk',
            subtitle: ref.watch(lanTransportProvider)?.isRunning ?? false
                ? 'Aktiv — findet Freunde im gleichen WLAN automatisch.'
                : 'Nicht aktiv.',
          ),
          _Row(
            icon: Icons.sync,
            title: 'Jetzt synchronisieren',
            subtitle: lastSync.maybeWhen(
              data: _describeSync,
              orElse: () => 'Noch keine Runde gelaufen.',
            ),
            onTap: () async {
              await ref.read(appStateProvider.notifier).syncNow();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync-Runde gestartet.')),
              );
            },
          ),
          const SectionHeader('Coach'),
          _Row(
            icon: Icons.memory,
            iconColor: AppColors.flame,
            title: 'KI auf dem Gerät',
            subtitle: coach.maybeWhen(
              data: (CoachEngine engine) => engine.name,
              orElse: () => 'Wird geladen …',
            ),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const AiScreen(),
              ),
            ),
          ),
          const SectionHeader('Über'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('100 Tage und weit darüber hinaus',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Kein Konto, kein Server, keine Werbung, kein Tracking. '
                  'Deine Daten liegen auf diesem Gerät und gehen nur an die '
                  'Freunde, die du selbst verbunden hast. Der Quellcode ist '
                  'offen — prüf es nach, statt es zu glauben.',
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
                  label: const Text('Quellcode ansehen'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmWipe(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Wirklich alles löschen?'),
        content: const Text(
          'Ohne deinen Wiederherstellungs-Key ist danach nichts mehr zu '
          'retten — es gibt keinen Server, der eine Kopie hat. Das ist der '
          'Preis dafür, dass auch sonst niemand eine hat.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(120, 44),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(repositoryProvider).wipeEverything();
    await ref.read(appStateProvider.notifier).refresh();
  }
}

/// One line describing the most recent replication round.
String _describeSync(SyncEvent event) {
  if (!event.result.isSuccess) {
    return 'Letzter Versuch fehlgeschlagen: ${event.result.error}';
  }
  return 'Zuletzt mit ${event.peerName ?? 'einem Peer'}: '
      '${event.result.received} empfangen, ${event.result.sent} gesendet.';
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
