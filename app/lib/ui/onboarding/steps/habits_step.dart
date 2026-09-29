import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../../l10n/l10n.dart';
import '../../../state/onboarding_state.dart';
import '../../../theme/theme.dart';
import '../../widgets/app_card.dart';
import '../onboarding_flow.dart';

/// Which battles the user is actually fighting.
class HabitsStep extends ConsumerWidget {
  const HabitsStep({super.key});

  static const List<HabitCategory> _order = <HabitCategory>[
    HabitCategory.gym,
    HabitCategory.cardio,
    HabitCategory.steps,
    HabitCategory.nutrition,
    HabitCategory.noAlcohol,
    HabitCategory.noSugar,
    HabitCategory.dopamineDetox,
    HabitCategory.noFap,
    HabitCategory.noNicotine,
    HabitCategory.reading,
    HabitCategory.meditation,
    HabitCategory.coldShower,
    HabitCategory.sleep,
    HabitCategory.water,
    HabitCategory.journaling,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final draft = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final suggested = draft.archetype == null
        ? const <HabitCategory>{}
        : goalInfo(draft.archetype!).suggestedHabits.toSet();

    return OnboardingScaffold(
      eyebrow: l10n.obStep3,
      title: l10n.obHabitsTitle,
      subtitle: draft.selectedHabits.length > 4
          ? l10n.obHabitsSubtitleTooMany
          : l10n.obHabitsSubtitlePreselected,
      child: Column(
        children: <Widget>[
          for (final HabitCategory category in _order)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _HabitRow(
                definition: habitDefinition(category),
                selected: draft.selectedHabits.contains(category),
                suggested: suggested.contains(category),
                target: draft.habitTargets[category] ??
                    habitDefinition(category).defaultTarget,
                onToggle: () => notifier.toggleHabit(category),
                onTarget: (num value) => notifier.setTarget(category, value),
              ),
            ),
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.definition,
    required this.selected,
    required this.suggested,
    required this.target,
    required this.onToggle,
    required this.onTarget,
  });

  final HabitDefinition definition;
  final bool selected;
  final bool suggested;
  final num target;
  final VoidCallback onToggle;
  final void Function(num value) onTarget;

  bool get _hasAdjustableTarget => definition.unit != HabitUnit.done;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCard(
      onTap: onToggle,
      border: selected ? AppColors.lime.withValues(alpha: 0.7) : null,
      color:
          selected ? AppColors.lime.withValues(alpha: 0.06) : AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(definition.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            l10n.habitTitle(definition.category),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (suggested && !selected) ...<Widget>[
                          const SizedBox(width: AppSpacing.sm),
                          Pill(l10n.obHabitRecommended,
                              color: AppColors.flame),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.habitBlurb(definition.category),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: selected,
                onChanged: (bool? _) => onToggle(),
                activeColor: AppColors.lime,
                checkColor: AppColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
          if (selected && _hasAdjustableTarget) ...<Widget>[
            const Divider(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Text(
                  l10n.obHabitDailyTarget,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                Expanded(
                  child: Slider(
                    value: target.toDouble().clamp(_min, _max),
                    min: _min,
                    max: _max,
                    divisions: ((_max - _min) / _stepSize).round(),
                    activeColor: AppColors.lime,
                    onChanged: (double value) => onTarget(value.round()),
                  ),
                ),
                SizedBox(
                  width: 84,
                  child: Text(
                    l10n.formatTarget(
                      Habit.fromCategory(definition.category),
                      value: target,
                    ),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  double get _min {
    switch (definition.unit) {
      case HabitUnit.minutes:
        return definition.category == HabitCategory.sleep ? 360 : 5;
      case HabitUnit.pages:
        return 5;
      case HabitUnit.count:
        return 2;
      case HabitUnit.steps:
        return 2000;
      default:
        return 1;
    }
  }

  double get _max {
    switch (definition.unit) {
      case HabitUnit.minutes:
        return definition.category == HabitCategory.sleep ? 600 : 90;
      case HabitUnit.pages:
        return 100;
      case HabitUnit.count:
        return 15;
      case HabitUnit.steps:
        return 25000;
      default:
        return 10;
    }
  }

  double get _stepSize {
    switch (definition.unit) {
      case HabitUnit.minutes:
        return definition.category == HabitCategory.sleep ? 15 : 5;
      case HabitUnit.pages:
        return 5;
      case HabitUnit.steps:
        return 500;
      default:
        return 1;
    }
  }
}
