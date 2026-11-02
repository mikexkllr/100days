import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/onboarding_state.dart';
import '../../widgets/body_form.dart';
import '../onboarding_flow.dart';

/// Body stats — collected only when the goal actually needs a calorie target.
class BodyStep extends ConsumerStatefulWidget {
  const BodyStep({super.key});

  @override
  ConsumerState<BodyStep> createState() => _BodyStepState();
}

class _BodyStepState extends ConsumerState<BodyStep> {
  @override
  void initState() {
    super.initState();
    // The defaults count as an answer: publish them so "continue" works
    // for someone who happens to match them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(onboardingProvider).body == null) {
        ref.read(onboardingProvider.notifier).setBody(BodyForm.defaults);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final draft = ref.watch(onboardingProvider);
    return OnboardingScaffold(
      eyebrow: l10n.obBodyEyebrow,
      title: l10n.obBodyTitle,
      subtitle: l10n.obBodySubtitle,
      child: BodyForm(
        value: draft.body ?? BodyForm.defaults,
        onChanged: ref.read(onboardingProvider.notifier).setBody,
      ),
    );
  }
}
