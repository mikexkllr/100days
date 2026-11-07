import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import '../widgets/body_form.dart';

/// The nutrition plan, adjustable by hand — and by the on-device model, which
/// proposes and never applies.
///
/// Also the way into the plan for someone who started without it: switching
/// it on asks for the body stats the calorie formula needs.
class NutritionGoalsScreen extends ConsumerStatefulWidget {
  const NutritionGoalsScreen({super.key, required this.challenge});

  final Challenge challenge;

  @override
  ConsumerState<NutritionGoalsScreen> createState() =>
      _NutritionGoalsScreenState();
}

class _NutritionGoalsScreenState extends ConsumerState<NutritionGoalsScreen> {
  late BodyProfile _body = widget.challenge.goal.body ?? BodyForm.defaults;
  late NutritionGoals _goals =
      widget.challenge.goal.nutrition ?? const NutritionGoals();
  late final bool _askBody = widget.challenge.goal.body == null;
  final TextEditingController _wish = TextEditingController();
  bool _asking = false;
  bool _aiFailed = false;
  TargetProposal? _proposal;

  @override
  void dispose() {
    _wish.dispose();
    super.dispose();
  }

  Goal get _goal => widget.challenge.goal.copyWith(
        body: _body,
        nutrition: _goals,
        nutritionPlanEnabled: true,
      );

  Future<void> _ask(NutritionAssistant assistant) async {
    setState(() {
      _asking = true;
      _aiFailed = false;
      _proposal = null;
    });
    final TargetProposal? proposal = await assistant.adjustTargets(
      plan: buildNutritionPlan(_goal),
      wish: _wish.text,
    );
    if (!mounted) return;
    setState(() {
      _asking = false;
      _proposal = proposal;
      _aiFailed = proposal == null;
    });
  }

  Future<void> _save() async {
    final Challenge challenge = widget.challenge;
    final bool hasHabit = challenge.habits
        .any((Habit h) => h.category == HabitCategory.nutrition);
    await ref.read(appStateProvider.notifier).updateChallenge(
          challenge.copyWith(
            goal: _goal,
            // Switching the plan on mid-challenge adds the habit from today:
            // the days before neither break nor build the streak.
            habits: hasHabit
                ? challenge.habits
                : <Habit>[
                    ...challenge.habits,
                    Habit.fromCategory(HabitCategory.nutrition)
                        .copyWith(activeFrom: DayKey.today()),
                  ],
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.goalsSaved)),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final NutritionAssistant? assistant =
        ref.watch(nutritionAssistantProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.goalsTitle),
        actions: <Widget>[
          TextButton(
            key: const Key('goals-save'),
            onPressed: _save,
            child: Text(l10n.actionSave),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          if (_askBody) ...<Widget>[
            SectionHeader(l10n.goalsBodyTitle, subtitle: l10n.goalsBodySub),
            BodyForm(
              value: _body,
              onChanged: (BodyProfile body) => setState(() => _body = body),
            ),
          ],
          SectionHeader(l10n.goalsTargetTitle),
          NutritionGoalsForm(
            goal: _goal,
            value: _goals,
            onChanged: (NutritionGoals goals) =>
                setState(() => _goals = goals),
          ),
          SectionHeader(l10n.goalsAiTitle, subtitle: l10n.goalsAiSub),
          if (assistant == null)
            AppCard(
              color: AppColors.surfaceHigh,
              child: Text(
                l10n.goalsAiUnavailable,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            )
          else ...<Widget>[
            TextField(
              controller: _wish,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(hintText: l10n.goalsAiHint),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _asking || _wish.text.trim().isEmpty
                  ? null
                  : () => _ask(assistant),
              icon: _asking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(l10n.goalsAiAsk),
            ),
            if (_aiFailed)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.goalsAiFailed,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.danger, fontSize: 12.5),
                ),
              ),
            if (_proposal != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                border: AppColors.social.withValues(alpha: 0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            l10n.goalsAiProposal(
                              _proposal!.kcal,
                              _proposal!.proteinPercent,
                              _proposal!.carbsPercent,
                              _proposal!.fatPercent,
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Pill(l10n.coachBadgeLlm, color: AppColors.social),
                      ],
                    ),
                    if (_proposal!.reason != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _proposal!.reason!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton(
                      onPressed: () => setState(() {
                        _goals = _proposal!.toGoals();
                        _proposal = null;
                      }),
                      child: Text(l10n.goalsAiApply),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
