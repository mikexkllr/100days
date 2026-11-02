import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../../l10n/l10n.dart';
import '../../../state/onboarding_state.dart';
import '../../plan/session_editor.dart';
import '../../widgets/app_card.dart';
import '../onboarding_flow.dart';

/// Pick a split, see the proposed exercises, change whatever does not fit.
class SplitStep extends ConsumerWidget {
  const SplitStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final OnboardingDraft draft = ref.watch(onboardingProvider);
    final OnboardingController notifier = ref.read(onboardingProvider.notifier);
    final Goal goal = draft.toGoal();

    return OnboardingScaffold(
      eyebrow: l10n.obSplitEyebrow,
      title: l10n.obSplitTitle,
      subtitle: l10n.obSplitSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SplitPicker(
            daysPerWeek: draft.trainingDaysPerWeek,
            selected: draft.effectiveSplit,
            onSelected: notifier.chooseSplit,
          ),
          SectionHeader(
            l10n.editorSessionsTitle,
            subtitle: l10n.editorSessionsSubtitle,
          ),
          SessionEditorList(
            setup: draft.currentTrainingSetup(),
            goal: goal,
            onChanged: notifier.setTrainingSetup,
          ),
        ],
      ),
    );
  }
}
