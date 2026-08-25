import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../../state/onboarding_state.dart';
import '../../../theme/theme.dart';
import '../../widgets/app_card.dart';
import '../onboarding_flow.dart';

/// Everything the training generator needs and nothing it does not.
class TrainingStep extends ConsumerWidget {
  const TrainingStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return OnboardingScaffold(
      eyebrow: 'Training',
      title: 'Wie oft und womit?',
      subtitle: 'Daraus baut die App deinen Split — inklusive Deload-Wochen, '
          'damit du nach sechs Wochen nicht auf dem Zahnfleisch gehst.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Trainingstage pro Woche',
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
            _splitPreview(draft.trainingDaysPerWeek),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.flameSoft, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Erfahrung', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _OptionList<TrainingExperience>(
            value: draft.experience,
            onChanged: notifier.setExperience,
            options: const <_Option<TrainingExperience>>[
              _Option<TrainingExperience>(
                value: TrainingExperience.beginner,
                emoji: '🌱',
                title: 'Anfänger',
                body: 'Unter einem Jahr regelmäßig. Technik vor Gewicht.',
              ),
              _Option<TrainingExperience>(
                value: TrainingExperience.intermediate,
                emoji: '⚙️',
                title: 'Fortgeschritten',
                body: 'Ein bis drei Jahre. Du weißt, wie sich RPE 8 anfühlt.',
              ),
              _Option<TrainingExperience>(
                value: TrainingExperience.advanced,
                emoji: '🔥',
                title: 'Erfahren',
                body: 'Mehr als drei Jahre. Volumen ist dein Hebel.',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Ausrüstung', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _OptionList<EquipmentAccess>(
            value: draft.equipment,
            onChanged: notifier.setEquipment,
            options: const <_Option<EquipmentAccess>>[
              _Option<EquipmentAccess>(
                value: EquipmentAccess.fullGym,
                emoji: '🏟️',
                title: 'Volles Studio',
                body: 'Langhantel, Maschinen, Kabelzug.',
              ),
              _Option<EquipmentAccess>(
                value: EquipmentAccess.homeBasic,
                emoji: '🏠',
                title: 'Home-Gym',
                body: 'Kurzhanteln, Bänder, Klimmzugstange.',
              ),
              _Option<EquipmentAccess>(
                value: EquipmentAccess.bodyweight,
                emoji: '🤸',
                title: 'Nur Körpergewicht',
                body: 'Kein Equipment. Geht trotzdem.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _splitPreview(int days) {
    switch (days) {
      case 2:
        return 'Ganzkörper 2x — jede Einheit trifft alles.';
      case 3:
        return 'Ganzkörper 3x — bester Kompromiss für die meisten.';
      case 4:
        return 'Upper / Lower — zweimal Oberkörper, zweimal Beine.';
      case 5:
        return 'Push / Pull / Legs plus Upper / Lower.';
      default:
        return 'Push / Pull / Legs, zweimal die Woche.';
    }
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
