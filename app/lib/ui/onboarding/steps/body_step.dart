import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../../l10n/l10n.dart';
import '../../../state/onboarding_state.dart';
import '../../../theme/theme.dart';
import '../../widgets/app_card.dart';
import '../onboarding_flow.dart';

/// Body stats — collected only when the goal actually needs a calorie target.
class BodyStep extends ConsumerStatefulWidget {
  const BodyStep({super.key});

  @override
  ConsumerState<BodyStep> createState() => _BodyStepState();
}

class _BodyStepState extends ConsumerState<BodyStep> {
  BiologicalSex _sex = BiologicalSex.male;
  int _age = 28;
  double _height = 180;
  double _weight = 80;
  ActivityLevel _activity = ActivityLevel.moderate;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(onboardingProvider).body;
    if (existing != null) {
      _sex = existing.sex;
      _age = existing.ageYears;
      _height = existing.heightCm;
      _weight = existing.weightKg;
      _activity = existing.activityLevel;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _publish());
  }

  void _publish() {
    ref.read(onboardingProvider.notifier).setBody(BodyProfile(
          sex: _sex,
          ageYears: _age,
          heightCm: _height,
          weightKg: _weight,
          activityLevel: _activity,
        ));
  }

  void _update(VoidCallback change) {
    setState(change);
    _publish();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final draft = ref.watch(onboardingProvider);
    final preview = draft.body == null || draft.archetype == null
        ? null
        : buildNutritionPlan(draft.toGoal());

    return OnboardingScaffold(
      eyebrow: l10n.obBodyEyebrow,
      title: l10n.obBodyTitle,
      subtitle: l10n.obBodySubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (final BiologicalSex sex in BiologicalSex.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: AppCard(
                      onTap: () => _update(() => _sex = sex),
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm + 4),
                      border: _sex == sex ? AppColors.flame : null,
                      color: _sex == sex
                          ? AppColors.flame.withValues(alpha: 0.08)
                          : AppColors.surface,
                      child: Center(
                        child: Text(
                          sex == BiologicalSex.male
                              ? l10n.obSexMale
                              : l10n.obSexFemale,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _NumberRow(
            label: l10n.obBodyAge,
            value: l10n.obBodyAgeValue(_age),
            slider: Slider(
              value: _age.toDouble(),
              min: 14,
              max: 80,
              divisions: 66,
              activeColor: AppColors.flame,
              onChanged: (double v) => _update(() => _age = v.round()),
            ),
          ),
          _NumberRow(
            label: l10n.obBodyHeight,
            value: '${_height.round()} cm',
            slider: Slider(
              value: _height,
              min: 140,
              max: 215,
              divisions: 75,
              activeColor: AppColors.flame,
              onChanged: (double v) => _update(() => _height = v),
            ),
          ),
          _NumberRow(
            label: l10n.obBodyWeight,
            value: '${_weight.toStringAsFixed(0)} kg',
            slider: Slider(
              value: _weight,
              min: 40,
              max: 180,
              divisions: 140,
              activeColor: AppColors.flame,
              onChanged: (double v) => _update(() => _weight = v),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.obBodyActivity,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final ActivityLevel level in ActivityLevel.values)
                ChoiceChip(
                  label: Text(l10n.activityLevelTitle(level)),
                  selected: _activity == level,
                  selectedColor: AppColors.flame.withValues(alpha: 0.2),
                  onSelected: (_) => _update(() => _activity = level),
                ),
            ],
          ),
          if (preview != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              color: AppColors.surfaceHigh,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.obBodyPreviewTitle,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: StatTile(
                          value: '${preview.kcal}',
                          label: l10n.planKcal,
                          color: AppColors.flame,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${preview.proteinG} g',
                          label: l10n.planProtein,
                          color: AppColors.lime,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${preview.carbsG} g',
                          label: l10n.planCarbs,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${preview.fatG} g',
                          label: l10n.planFat,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.nutritionRationale(preview),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.value,
    required this.slider,
  });

  final String label;
  final String value;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        slider,
      ],
    );
  }
}
