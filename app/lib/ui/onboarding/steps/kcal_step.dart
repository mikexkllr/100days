import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/onboarding_state.dart';
import '../../widgets/body_form.dart';
import '../onboarding_flow.dart';

/// The computed calorie target, and the switch to set your own.
class KcalStep extends ConsumerWidget {
  const KcalStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final OnboardingDraft draft = ref.watch(onboardingProvider);
    if (draft.body == null || draft.archetype == null) {
      return OnboardingScaffold(
        title: l10n.obKcalTitle,
        child: const SizedBox.shrink(),
      );
    }
    return OnboardingScaffold(
      eyebrow: l10n.obKcalEyebrow,
      title: l10n.obKcalTitle,
      subtitle: l10n.obKcalSubtitle,
      child: NutritionGoalsForm(
        goal: draft.toGoal(),
        value: draft.nutritionGoals,
        onChanged: ref.read(onboardingProvider.notifier).setNutritionGoals,
      ),
    );
  }
}
