import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/theme.dart';
import '../../widgets/app_card.dart';
import '../onboarding_flow.dart';

/// What the AI does, what it costs, and that one's own key is an option.
class AiStep extends StatelessWidget {
  const AiStep({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    Widget point(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, color: AppColors.reward),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: text.titleMedium),
                      const SizedBox(height: 2),
                      Text(body,
                          style: text.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return OnboardingScaffold(
      eyebrow: l10n.obAiEyebrow,
      title: l10n.obAiTitle,
      subtitle: l10n.obAiSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          point(Icons.photo_camera_outlined, l10n.obAiFreeTitle,
              l10n.obAiFreeBody),
          point(Icons.workspace_premium_outlined, l10n.obAiPremiumTitle,
              l10n.obAiPremiumBody),
          point(Icons.key_outlined, l10n.obAiOwnKeyTitle, l10n.obAiOwnKeyBody),
          Text(
            l10n.obAiLater,
            style: text.bodyMedium
                ?.copyWith(color: AppColors.textTertiary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
