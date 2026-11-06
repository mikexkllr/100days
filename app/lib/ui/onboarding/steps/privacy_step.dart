import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/onboarding_state.dart';
import '../../settings/privacy_screen.dart';
import '../onboarding_flow.dart';

/// Friends only — and of that, only what the user wants them to see.
class PrivacyStep extends ConsumerWidget {
  const PrivacyStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final OnboardingDraft draft = ref.watch(onboardingProvider);
    return OnboardingScaffold(
      eyebrow: l10n.obPrivacyEyebrow,
      title: l10n.obPrivacyTitle,
      subtitle: l10n.obPrivacySubtitle,
      child: SharingForm(
        habits: draft.toHabits(),
        value: draft.sharing,
        onChanged: ref.read(onboardingProvider.notifier).setSharing,
      ),
    );
  }
}
