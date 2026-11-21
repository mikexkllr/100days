import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_prefs.dart';
import '../../data/push_service.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// Asks for notification permission the way the app wants to be asked: in
/// its own words, saying what it will send, and only when the user says yes
/// does the system dialog appear.
Future<bool> askForReminders(WidgetRef ref) async {
  await ref
      .read(appPrefsProvider.notifier)
      .update((AppPrefs p) => p.copyWith(permissionAsked: true));
  final bool granted = await ref.read(notificationsProvider).requestPermission();
  final repository = ref.read(sessionRepositoryProvider).valueOrNull;
  if (repository != null) {
    await PushService.start(repository.social, askPermission: true);
  }
  ref.invalidate(notificationsPermittedProvider);
  return granted;
}

/// Whether notifications reach the user right now.
final FutureProvider<bool> notificationsPermittedProvider =
    FutureProvider<bool>(
        (Ref ref) => ref.watch(notificationsProvider).isPermitted());

/// Settings → reminders: when, and which.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppPrefs prefs = ref.watch(appPrefsProvider);
    final bool permitted =
        ref.watch(notificationsPermittedProvider).valueOrNull ?? true;
    final AppPrefsController controller = ref.read(appPrefsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.remindTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          if (!permitted)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                border: AppColors.danger.withValues(alpha: 0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.remindBlocked,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.remindBlockedHint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton(
                      onPressed: () => askForReminders(ref),
                      child: Text(l10n.remindAllow),
                    ),
                  ],
                ),
              ),
            ),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  key: const Key('reminders-daily'),
                  value: prefs.remindersOn,
                  title: Text(l10n.remindDaily),
                  subtitle: Text(l10n.remindDailySub),
                  onChanged: (bool on) => controller
                      .update((AppPrefs p) => p.copyWith(remindersOn: on)),
                ),
                ListTile(
                  enabled: prefs.remindersOn,
                  leading: const Icon(Icons.schedule),
                  title: Text(l10n.remindTime),
                  trailing: Text(
                    prefs.reminderTime.format(context),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: prefs.reminderTime,
                    );
                    if (picked == null) return;
                    await controller.update(
                        (AppPrefs p) => p.copyWith(reminderTime: picked));
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  key: const Key('reminders-warning'),
                  value: prefs.streakWarningOn,
                  title: Text(l10n.remindWarning),
                  subtitle: Text(l10n.remindWarningSub),
                  onChanged: (bool on) => controller
                      .update((AppPrefs p) => p.copyWith(streakWarningOn: on)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
