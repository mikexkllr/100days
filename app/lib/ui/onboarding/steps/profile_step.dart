import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/onboarding_state.dart';
import '../../../state/providers.dart';
import '../../../theme/theme.dart';
import '../../widgets/app_card.dart';
import '../onboarding_flow.dart';

/// Name and face — what friends see in a request, in the feed and in the
/// league.
class ProfileStep extends ConsumerStatefulWidget {
  const ProfileStep({super.key});

  @override
  ConsumerState<ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends ConsumerState<ProfileStep> {
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(onboardingProvider).displayName);

  @override
  void initState() {
    super.initState();
    // The name Google or Apple reported, as a starting point.
    if (_controller.text.isEmpty) {
      final String? given = ref.read(accountGivenNameProvider);
      if (given != null) {
        _controller.text = given;
        WidgetsBinding.instance.addPostFrameCallback((_) => ref
            .read(onboardingProvider.notifier)
            .setIdentity(displayName: given));
      }
    }
  }

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
    final AppLocalizations l10n = context.l10n;
    final draft = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return OnboardingScaffold(
      eyebrow: l10n.obStep4,
      title: l10n.obIdentityTitle,
      subtitle: l10n.obIdentitySubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              EmojiAvatar(draft.avatarEmoji, size: 64, ringColor: AppColors.primary),
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
                  decoration: InputDecoration(
                    hintText: l10n.obIdentityNameHint,
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
                        ? AppColors.primary
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
