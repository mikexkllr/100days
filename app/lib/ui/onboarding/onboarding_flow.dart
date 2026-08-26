import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/onboarding_state.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import 'steps/body_step.dart';
import 'steps/goal_step.dart';
import 'steps/habits_step.dart';
import 'steps/identity_step.dart';
import 'steps/statement_step.dart';
import 'steps/summary_step.dart';
import 'steps/training_step.dart';
import 'steps/welcome_step.dart';

/// Sets up the challenge before anything else exists.
///
/// The order is deliberate: the goal comes first and everything after it is
/// derived from that answer, including which steps are shown at all. Someone
/// doing a dopamine detox is never asked their body-fat percentage.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Step> _steps(OnboardingDraft draft) => <_Step>[
        const _Step(id: 'welcome', child: WelcomeStep(), canAdvance: true),
        _Step(
          id: 'goal',
          child: const GoalStep(),
          canAdvance: draft.archetype != null,
        ),
        _Step(
          id: 'statement',
          child: const StatementStep(),
          canAdvance: draft.statement.trim().length >= 3,
        ),
        _Step(
          id: 'habits',
          child: const HabitsStep(),
          canAdvance: draft.selectedHabits.isNotEmpty,
        ),
        if (draft.needsTrainingDetails)
          const _Step(id: 'training', child: TrainingStep(), canAdvance: true),
        if (draft.needsBodyStats)
          _Step(
            id: 'body',
            child: const BodyStep(),
            canAdvance: draft.body != null,
          ),
        _Step(
          id: 'identity',
          child: const IdentityStep(),
          canAdvance: draft.displayName.trim().isNotEmpty,
        ),
        _Step(
          id: 'summary',
          child: const SummaryStep(),
          canAdvance: draft.isReady,
          isFinal: true,
        ),
      ];

  Future<void> _next(List<_Step> steps) async {
    if (_index >= steps.length - 1) {
      await _finish();
      return;
    }
    FocusScope.of(context).unfocus();
    await _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    final draft = ref.read(onboardingProvider);
    if (!draft.isReady || _submitting) return;
    setState(() => _submitting = true);
    try {
      final controller = ref.read(appStateProvider.notifier);
      await controller.saveProfile(
        displayName: draft.displayName.trim(),
        avatarEmoji: draft.avatarEmoji,
        goalStatement: draft.statement.trim(),
      );
      await controller.startChallenge(draft.toChallenge());
      ref.read(onboardingProvider.notifier).reset();
      // The gate normally replaces this widget on the next frame. Clearing the
      // flag anyway means a user is never stranded on a spinner if it does not.
      if (mounted) setState(() => _submitting = false);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.obStartFailed('$error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final draft = ref.watch(onboardingProvider);
    final steps = _steps(draft);
    final safeIndex = _index.clamp(0, steps.length - 1);
    final current = steps[safeIndex];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _ProgressBar(progress: (safeIndex + 1) / steps.length),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (int index) => setState(() => _index = index),
                children: <Widget>[
                  for (final _Step step in steps)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: step.child,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  if (safeIndex > 0)
                    IconButton(
                      onPressed: _submitting
                          ? null
                          : () => _controller.previousPage(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOut,
                              ),
                      icon: const Icon(Icons.arrow_back),
                      color: AppColors.textSecondary,
                    ),
                  Expanded(
                    child: FilledButton(
                      onPressed: current.canAdvance && !_submitting
                          ? () => _next(steps)
                          : null,
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : Text(current.isFinal
                              ? l10n.obStartChallenge
                              : l10n.actionNext),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  const _Step({
    required this.id,
    required this.child,
    required this.canAdvance,
    this.isFinal = false,
  });

  final String id;
  final Widget child;
  final bool canAdvance;
  final bool isFinal;
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.pill,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: progress),
          duration: const Duration(milliseconds: 320),
          builder: (BuildContext context, double value, Widget? _) =>
              LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: AppColors.surfaceHigh,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.flame),
          ),
        ),
      ),
    );
  }
}

/// Shared page scaffolding so every step reads the same way.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.eyebrow,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xl),
      children: <Widget>[
        if (eyebrow != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              eyebrow!.toUpperCase(),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.flame),
            ),
          ),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    );
  }
}
