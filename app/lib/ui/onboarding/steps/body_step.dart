import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

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
    final draft = ref.watch(onboardingProvider);
    final preview = draft.body == null || draft.archetype == null
        ? null
        : buildNutritionPlan(draft.toGoal());

    return OnboardingScaffold(
      eyebrow: 'Ernährung',
      title: 'Ein paar Zahlen.',
      subtitle: 'Nur für die Kalorien- und Proteinberechnung. Alles bleibt '
          'auf diesem Gerät.',
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
                          sex == BiologicalSex.male ? 'männlich' : 'weiblich',
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
            label: 'Alter',
            value: '$_age Jahre',
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
            label: 'Größe',
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
            label: 'Gewicht',
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
          Text('Alltag & Bewegung',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final ActivityLevel level in ActivityLevel.values)
                ChoiceChip(
                  label: Text(_activityLabel(level)),
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
                  Text('Dein Tagesziel',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: StatTile(
                          value: '${preview.kcal}',
                          label: 'kcal',
                          color: AppColors.flame,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${preview.proteinG} g',
                          label: 'Protein',
                          color: AppColors.lime,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${preview.carbsG} g',
                          label: 'Kohlenhydrate',
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${preview.fatG} g',
                          label: 'Fett',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    preview.rationaleDe,
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

  String _activityLabel(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 'Sitzend';
      case ActivityLevel.light:
        return 'Leicht aktiv';
      case ActivityLevel.moderate:
        return 'Moderat';
      case ActivityLevel.high:
        return 'Sehr aktiv';
      case ActivityLevel.athlete:
        return 'Sportler';
    }
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
