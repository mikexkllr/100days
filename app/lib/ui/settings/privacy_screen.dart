import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// What friends see, switch by switch. There is no "public": everything
/// here goes to friends you connected yourself, or nowhere.
class SharingForm extends StatelessWidget {
  const SharingForm({
    super.key,
    required this.habits,
    required this.value,
    required this.onChanged,
  });

  final List<Habit> habits;
  final SharingPrefs value;
  final ValueChanged<SharingPrefs> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool trains = habits.any((Habit h) =>
        h.category == HabitCategory.gym || h.category == HabitCategory.cardio);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(l10n.privacyHabitsTitle, subtitle: l10n.privacyHabitsSub),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Column(
            children: <Widget>[
              for (final Habit habit in habits)
                SwitchListTile(
                  key: Key('share-${habit.id}'),
                  value: value.isHabitShared(habit.id),
                  activeThumbColor: AppColors.success,
                  secondary:
                      Text(habit.emoji, style: const TextStyle(fontSize: 22)),
                  title: Text(l10n.habitLabel(habit)),
                  subtitle: Text(value.isHabitShared(habit.id)
                      ? l10n.privacyShared
                      : l10n.privacyPrivate),
                  onChanged: (bool shared) => onChanged(value.withHabitShared(
                    habit.id,
                    shared,
                    since: DayKey.today(),
                  )),
                ),
            ],
          ),
        ),
        SectionHeader(l10n.privacyMoreTitle),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Column(
            children: <Widget>[
              SwitchListTile(
                key: const Key('share-statement'),
                value: value.shareStatement,
                activeThumbColor: AppColors.success,
                title: Text(l10n.privacyStatement),
                subtitle: Text(l10n.privacyStatementSub),
                onChanged: (bool v) =>
                    onChanged(value.copyWith(shareStatement: v)),
              ),
              if (trains)
                SwitchListTile(
                  key: const Key('share-workouts'),
                  value: value.shareWorkouts,
                  activeThumbColor: AppColors.success,
                  title: Text(l10n.privacyWorkouts),
                  subtitle: Text(l10n.privacyWorkoutsSub),
                  onChanged: (bool v) =>
                      onChanged(value.copyWith(shareWorkouts: v)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          color: AppColors.surfaceHigh,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.lock_outline, size: 19, color: AppColors.social),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  l10n.privacyAlwaysPrivate,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Settings → privacy: the same switches as in onboarding, for a running
/// challenge.
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  SharingPrefs? _value;

  Future<void> _save(AppSnapshot snapshot) async {
    final Challenge challenge = snapshot.challenge!;
    final SharingPrefs next = _value!;
    final AppController controller = ref.read(appStateProvider.notifier);
    // A habit made visible today is counted by friends from today on —
    // SharingPrefs records that, so its sealed past is not read as misses.
    await controller.updateChallenge(challenge.copyWith(sharing: next));
    // The goal sentence also sits on the public profile.
    if (next.shareStatement != challenge.sharing.shareStatement) {
      await controller.saveProfile(
        displayName: snapshot.me.profile.displayName,
        avatarEmoji: snapshot.me.profile.avatarEmoji,
        goalStatement: next.shareStatement ? challenge.goal.statement : null,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.privacySaved)),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<AppSnapshot> async = ref.watch(appStateProvider);
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace _) =>
          Scaffold(body: Center(child: Text('$error'))),
      data: (AppSnapshot snapshot) {
        final Challenge challenge = snapshot.challenge!;
        final SharingPrefs value = _value ?? challenge.sharing;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.privacyTitle),
            actions: <Widget>[
              TextButton(
                key: const Key('privacy-save'),
                onPressed: _value == null ? null : () => _save(snapshot),
                child: Text(l10n.actionSave),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              SharingForm(
                habits: challenge.habits,
                value: value,
                onChanged: (SharingPrefs next) =>
                    setState(() => _value = next),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.privacyFromNowOn,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 12.5,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}
