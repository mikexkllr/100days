import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_prefs.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../mascot/flame_mascot.dart';
import '../settings/reminders_screen.dart';
import '../widgets/app_card.dart';
import 'package:hundred_core/hundred_core.dart';

/// Funki offers reminders once — after the first check-in, when the user
/// knows what there is to be reminded of — instead of a bare system dialog
/// right after signing in.
class ReminderPermissionCard extends ConsumerWidget {
  const ReminderPermissionCard({super.key, required this.stage});

  final FlameStage stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              FlameMascot(stage: stage, mood: MascotMood.hopeful, size: 44),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(l10n.remindCardTitle,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.remindCardBody,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('reminders-yes'),
            onPressed: () => askForReminders(ref),
            child: Text(l10n.remindCardYes),
          ),
          Center(
            child: TextButton(
              onPressed: () => ref.read(appPrefsProvider.notifier).update(
                  (AppPrefs p) => p.copyWith(permissionAsked: true)),
              child: Text(l10n.remindCardLater),
            ),
          ),
        ],
      ),
    );
  }
}
