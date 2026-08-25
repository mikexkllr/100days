import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/onboarding_state.dart';
import '../../../state/providers.dart';
import '../../../theme/theme.dart';
import '../../widgets/app_card.dart';
import '../onboarding_flow.dart';

/// Name and face — no email, no password, no account.
class IdentityStep extends ConsumerStatefulWidget {
  const IdentityStep({super.key});

  @override
  ConsumerState<IdentityStep> createState() => _IdentityStepState();
}

class _IdentityStepState extends ConsumerState<IdentityStep> {
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(onboardingProvider).displayName);

  static const List<String> _emojis = <String>[
    '🔥', '🐺', '🦍', '🦈', '🐉', '⚡', '🗿', '🧊',
    '🦅', '🐻', '🥷', '👑', '🌱', '🚀', '🎯', '🧠',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final did = ref.watch(repositoryProvider).did;

    return OnboardingScaffold(
      eyebrow: 'Schritt 4',
      title: 'Wie sollen dich deine Leute sehen?',
      subtitle: 'Kein Konto, keine E-Mail, kein Passwort. Dein Schlüsselpaar '
          'liegt schon auf diesem Gerät.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              EmojiAvatar(draft.avatarEmoji, size: 64, ringColor: AppColors.flame),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  key: const Key('name-field'),
                  controller: _controller,
                  onChanged: (String value) =>
                      notifier.setIdentity(displayName: value),
                  maxLength: 24,
                  textCapitalization: TextCapitalization.words,
                  style: Theme.of(context).textTheme.titleLarge,
                  decoration: const InputDecoration(
                    hintText: 'Dein Name',
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final String emoji in _emojis)
                GestureDetector(
                  onTap: () => notifier.setIdentity(avatarEmoji: emoji),
                  child: EmojiAvatar(
                    emoji,
                    size: 46,
                    ringColor: draft.avatarEmoji == emoji
                        ? AppColors.flame
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            color: AppColors.surfaceHigh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.key, size: 17, color: AppColors.violet),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Deine Identität',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SelectableText(
                  did,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Ein Ed25519-Schlüsselpaar auf diesem Gerät, als did:key. '
                  'Jeder Check-in wird damit signiert — deshalb kann niemand '
                  'deinen Streak fälschen, und du brauchst niemandem zu '
                  'vertrauen. Den Wiederherstellungs-Key findest du in den '
                  'Einstellungen. Sichere ihn.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
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
