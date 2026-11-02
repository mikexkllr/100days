import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/theme.dart';
import '../../settings/ai_screen.dart';
import '../onboarding_flow.dart';

/// Detects the phone, proposes the model that fits it and starts the
/// download right here — so the coach can speak properly from day one. The
/// download keeps running while the user finishes the setup.
class AiStep extends StatelessWidget {
  const AiStep({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return OnboardingScaffold(
      eyebrow: l10n.obAiEyebrow,
      title: l10n.obAiTitle,
      subtitle: l10n.obAiSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ModelSetupCard(showAlternatives: false),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.obAiLater,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 12.5,
                ),
          ),
        ],
      ),
    );
  }
}
