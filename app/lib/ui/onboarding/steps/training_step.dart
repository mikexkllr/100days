import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../../l10n/l10n.dart';
import '../../../state/onboarding_state.dart';
import '../../../theme/theme.dart';
import '../../widgets/app_card.dart';
import '../onboarding_flow.dart';

/// Everything the training generator needs and nothing it does not.
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
          Text(l10n.obTrainingDaysPerWeek,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              for (final int days in const <int>[2, 3, 4, 5, 6])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: _Choice(
                      label: '$days',
                      sublabel: 'x',
                      selected: draft.trainingDaysPerWeek == days,
                      onTap: () => notifier.setTrainingDays(days),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.splitPreview(draft.trainingDaysPerWeek),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.flameSoft, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.obTrainingExperience,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _OptionList<TrainingExperience>(
            value: draft.experience,
            onChanged: notifier.setExperience,
            options: <_Option<TrainingExperience>>[
              for (final TrainingExperience level in TrainingExperience.values)
                _Option<TrainingExperience>(
                  value: level,
                  emoji: const <String>['🌱', '⚙️', '🔥'][level.index],
                  title: l10n.experienceTitle(level),
                  body: l10n.experienceBody(level),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.obTrainingEquipment,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _OptionList<EquipmentAccess>(
            value: draft.equipment,
            onChanged: notifier.setEquipment,
            options: <_Option<EquipmentAccess>>[
              for (final EquipmentAccess access in EquipmentAccess.values)
                _Option<EquipmentAccess>(
                  value: access,
                  emoji: const <String>['🏟️', '🏠', '🤸'][access.index],
                  title: l10n.equipmentTitle(access),
                  body: l10n.equipmentBody(access),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Option<T> {
  const _Option({
    required this.value,
    required this.emoji,
    required this.title,
    required this.body,
  });

  final T value;
  final String emoji;
  final String title;
  final String body;
}

class _OptionList<T> extends StatelessWidget {
  const _OptionList({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<_Option<T>> options;
  final void Function(T value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final _Option<T> option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              onTap: () => onChanged(option.value),
              border: value == option.value ? AppColors.flame : null,
              color: value == option.value
                  ? AppColors.flame.withValues(alpha: 0.08)
                  : AppColors.surface,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 4,
              ),
              child: Row(
                children: <Widget>[
                  Text(option.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(option.title,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          option.body,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.5,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 4),
      border: selected ? AppColors.flame : null,
      color:
          selected ? AppColors.flame.withValues(alpha: 0.08) : AppColors.surface,
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: selected ? AppColors.flame : AppColors.textPrimary,
                ),
          ),
          Text(
            sublabel,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
