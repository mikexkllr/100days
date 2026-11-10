import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../theme/theme.dart';
import 'app_card.dart';

/// Sex, age, height, weight and activity — the inputs of the calorie
/// formula. Used in onboarding and when the nutrition plan is switched on
/// later.
class BodyForm extends StatelessWidget {
  const BodyForm({super.key, required this.value, required this.onChanged});

  static const BodyProfile defaults = BodyProfile(
    sex: BiologicalSex.male,
    ageYears: 28,
    heightCm: 180,
    weightKg: 80,
    activityLevel: ActivityLevel.moderate,
  );

  final BodyProfile value;
  final ValueChanged<BodyProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final BiologicalSex sex in BiologicalSex.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: AppCard(
                    onTap: () => onChanged(value.copyWith(sex: sex)),
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm + 4),
                    border: value.sex == sex ? AppColors.primary : null,
                    color: value.sex == sex
                        ? AppColors.primary.withValues(alpha: 0.08)
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
          value: l10n.obBodyAgeValue(value.ageYears),
          slider: Slider(
            value: value.ageYears.toDouble().clamp(14, 80),
            min: 14,
            max: 80,
            divisions: 66,
            activeColor: AppColors.primary,
            onChanged: (double v) =>
                onChanged(value.copyWith(ageYears: v.round())),
          ),
        ),
        _NumberRow(
          label: l10n.obBodyHeight,
          value: '${value.heightCm.round()} cm',
          slider: Slider(
            value: value.heightCm.clamp(140, 215),
            min: 140,
            max: 215,
            divisions: 75,
            activeColor: AppColors.primary,
            onChanged: (double v) => onChanged(value.copyWith(heightCm: v)),
          ),
        ),
        _NumberRow(
          label: l10n.obBodyWeight,
          value: '${value.weightKg.toStringAsFixed(0)} kg',
          slider: Slider(
            value: value.weightKg.clamp(40, 180),
            min: 40,
            max: 180,
            divisions: 140,
            activeColor: AppColors.primary,
            onChanged: (double v) =>
                onChanged(value.copyWith(weightKg: v.roundToDouble())),
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
                selected: value.activityLevel == level,
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                onSelected: (_) =>
                    onChanged(value.copyWith(activityLevel: level)),
              ),
          ],
        ),
      ],
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

/// Own calorie target and macro split, with the computed target alongside.
/// Used in onboarding and in the nutrition goals screen.
class NutritionGoalsForm extends StatelessWidget {
  const NutritionGoalsForm({
    super.key,
    required this.goal,
    required this.value,
    required this.onChanged,
  });

  /// Needs body stats: the suggestion is computed from them.
  final Goal goal;
  final NutritionGoals value;
  final ValueChanged<NutritionGoals> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final NutritionPlan suggested =
        buildNutritionPlan(goal.copyWith(nutrition: const NutritionGoals()));
    final NutritionPlan plan =
        buildNutritionPlan(goal.copyWith(nutrition: value));
    final bool custom = value.kcalTarget != null;
    final int kcal = value.kcalTarget ?? suggested.kcal;
    final ({int protein, int carbs, int fat}) percent = value.percentages ??
        (
          protein: (plan.proteinG * 4 * 100 / plan.kcal).round(),
          carbs: (plan.carbsG * 4 * 100 / plan.kcal).round(),
          fat: (plan.fatG * 9 * 100 / plan.kcal).round(),
        );

    void setKcal(int next) => onChanged(value.copyWith(
          kcalTarget: next.clamp(kMinCustomKcal, kMaxCustomKcal),
        ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppCard(
          color: AppColors.surfaceHigh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.goalsSuggested(suggested.kcal),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.nutritionRationale(suggested),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
              ),
            ],
          ),
        ),
        SwitchListTile(
          key: const Key('custom-kcal-switch'),
          contentPadding: EdgeInsets.zero,
          value: custom,
          title: Text(l10n.goalsOwnTarget),
          subtitle: Text(l10n.goalsOwnTargetSub),
          onChanged: (bool on) => onChanged(on
              ? value.copyWith(kcalTarget: suggested.kcal)
              : value.copyWith(clearKcal: true)),
        ),
        if (custom)
          Row(
            children: <Widget>[
              IconButton(
                onPressed: () => setKcal(kcal - 50),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    l10n.planKcalPerDay(kcal),
                    key: const Key('custom-kcal-value'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
              IconButton(
                key: const Key('custom-kcal-plus'),
                onPressed: () => setKcal(kcal + 50),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        if (custom && kcal < suggested.tdee * 0.75)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              l10n.goalsTooLow,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.danger, fontSize: 12.5),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.goalsMacroTitle,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final MacroPreset preset in MacroPreset.values)
              ChoiceChip(
                label: Text(l10n.macroPresetName(preset)),
                selected: value.preset == preset,
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                onSelected: (_) => onChanged(value.copyWith(
                  preset: preset,
                  proteinPercent: percent.protein,
                  carbsPercent: percent.carbs,
                  fatPercent: percent.fat,
                )),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.macroPresetBlurb(value.preset),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textTertiary,
                fontSize: 12.5,
              ),
        ),
        if (value.preset == MacroPreset.custom) ...<Widget>[
          _PercentSlider(
            label: l10n.planProtein,
            value: percent.protein,
            onChanged: (int p) => onChanged(value.copyWith(
              proteinPercent: p,
              fatPercent: (100 - p - percent.carbs).clamp(10, 70),
            )),
          ),
          _PercentSlider(
            label: l10n.planCarbs,
            value: percent.carbs,
            onChanged: (int c) => onChanged(value.copyWith(
              carbsPercent: c,
              fatPercent: (100 - percent.protein - c).clamp(10, 70),
            )),
          ),
          Text(
            l10n.goalsFatRest(percent.fat),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  value: '${plan.kcal}',
                  label: l10n.planKcal,
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: '${plan.proteinG} g',
                  label: l10n.planProtein,
                  color: AppColors.success,
                ),
              ),
              Expanded(
                child: StatTile(
                    value: '${plan.carbsG} g', label: l10n.planCarbsShort),
              ),
              Expanded(
                child: StatTile(value: '${plan.fatG} g', label: l10n.planFat),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PercentSlider extends StatelessWidget {
  const _PercentSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(width: 110, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble().clamp(5, 70),
            min: 5,
            max: 70,
            divisions: 65,
            activeColor: AppColors.primary,
            onChanged: (double v) => onChanged(v.round()),
          ),
        ),
        SizedBox(width: 44, child: Text('$value %', textAlign: TextAlign.end)),
      ],
    );
  }
}
