import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../../l10n/l10n.dart';
import '../../../state/onboarding_state.dart';
import '../../../theme/theme.dart';
import '../../plan/training_form.dart';
import '../onboarding_flow.dart';

/// Everything the training generator needs and nothing it does not — the
/// same questions the plan editor asks when the plan comes later.
class TrainingStep extends ConsumerWidget {
  const TrainingStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final draft = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return OnboardingScaffold(
      eyebrow: l10n.obTrainingEyebrow,
      title: l10n.obTrainingTitle,
      subtitle: l10n.obTrainingSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.obTrainingDaysPerWeek,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TrainingDaysPicker(
            value: draft.trainingDaysPerWeek,
            onChanged: notifier.setTrainingDays,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            draft.usesTrainingPlan
                ? l10n.obTrainingSplitHint(
                    l10n.splitName(recommendedSplit(draft.trainingDaysPerWeek)),
                  )
                : l10n.obTrainingNoPlanHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primarySoft,
              fontSize: 13,
            ),
          ),
          if (draft.usesTrainingPlan) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.obTrainingExperience,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            ExperiencePicker(
              value: draft.experience,
              onChanged: notifier.setExperience,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.obTrainingEquipment,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            EquipmentPicker(
              value: draft.equipment,
              onChanged: notifier.setEquipment,
            ),
          ],
        ],
      ),
    );
  }
}
