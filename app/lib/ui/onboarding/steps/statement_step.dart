import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../../l10n/l10n.dart';
import '../../../state/onboarding_state.dart';
import '../../../theme/theme.dart';
import '../../widgets/app_card.dart';
import '../onboarding_flow.dart';

/// The user's goal in their own words, plus how long the first cycle runs.
class StatementStep extends ConsumerStatefulWidget {
  const StatementStep({super.key});

  @override
  ConsumerState<StatementStep> createState() => _StatementStepState();
}

class _StatementStepState extends ConsumerState<StatementStep> {
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(onboardingProvider).statement);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final draft = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final List<String> examples =
        l10n.goalExamples(draft.archetype ?? GoalArchetype.custom);

    return OnboardingScaffold(
      eyebrow: l10n.obStep2,
      title: l10n.obStatementTitle,
      subtitle: l10n.obStatementSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            key: const Key('statement-field'),
            controller: _controller,
            onChanged: notifier.setStatement,
            maxLength: 90,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            style: Theme.of(context).textTheme.titleLarge,
            decoration: InputDecoration(
              hintText: l10n.obStatementHint,
              counterStyle:
                  const TextStyle(color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final String example in examples)
                ActionChip(
                  label: Text(example),
                  onPressed: () {
                    _controller.text = example;
                    notifier.setStatement(example);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.obCycleLengthTitle,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              for (final int length in const <int>[30, 100, 365])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: _LengthOption(
                      days: length,
                      selected: draft.lengthDays == length,
                      onTap: () => notifier.setLength(length),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: AppColors.surfaceHigh,
            child: Row(
              children: <Widget>[
                const Text('♾️', style: TextStyle(fontSize: 20)),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Text(
                    l10n.obCycleNote,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LengthOption extends StatelessWidget {
  const _LengthOption({
    required this.days,
    required this.selected,
    required this.onTap,
  });

  final int days;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      border: selected ? AppColors.flame : null,
      color:
          selected ? AppColors.flame.withValues(alpha: 0.08) : AppColors.surface,
      child: Column(
        children: <Widget>[
          Text(
            '$days',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: selected ? AppColors.flame : AppColors.textPrimary,
                ),
          ),
          Text(
            context.l10n.obCycleDays,
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
