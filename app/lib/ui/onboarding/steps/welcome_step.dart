import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/theme.dart';
import '../onboarding_flow.dart';

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return OnboardingScaffold(
      eyebrow: l10n.obWelcomeEyebrow,
      title: l10n.obWelcomeTitle,
      subtitle: l10n.obWelcomeSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Point(
            emoji: '🎯',
            title: l10n.obPointGoalTitle,
            body: l10n.obPointGoalBody,
          ),
          _Point(
            emoji: '👀',
            title: l10n.obPointSocialTitle,
            body: l10n.obPointSocialBody,
          ),
          _Point(
            emoji: '🔒',
            title: l10n.obPointPrivacyTitle,
            body: l10n.obPointPrivacyBody,
          ),
          _Point(
            emoji: '♾️',
            title: l10n.obPointBeyondTitle,
            body: l10n.obPointBeyondBody,
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.emoji, required this.title, required this.body});

  final String emoji;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
