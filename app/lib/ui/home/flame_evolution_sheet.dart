import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../theme/theme.dart';
import '../mascot/flame_painter.dart';
import '../widgets/app_card.dart';

/// Every form the flame can take — the ones you have reached, the next one
/// in full colour, and the rest as silhouettes you have to earn to see.
Future<void> showFlameEvolution(BuildContext context, {required int streak}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => FlameEvolutionSheet(streak: streak),
    );

class FlameEvolutionSheet extends StatefulWidget {
  const FlameEvolutionSheet({super.key, required this.streak});

  final int streak;

  @override
  State<FlameEvolutionSheet> createState() => _FlameEvolutionSheetState();
}

class _FlameEvolutionSheetState extends State<FlameEvolutionSheet> {
  final GlobalKey _current = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Open on where you stand, with the next form in view below it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? row = _current.currentContext;
      if (row != null && mounted) {
        Scrollable.ensureVisible(row, alignment: 0.35);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final FlameStage current = flameStageFor(widget.streak);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (BuildContext context, ScrollController controller) =>
          ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
        children: <Widget>[
          Text(l10n.evolutionTitle,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.evolutionSubtitle,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final FlameStage stage in FlameStage.values)
            Padding(
              key: stage == current ? _current : null,
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _StageRow(
                stage: stage,
                current: current,
                streak: widget.streak,
              ),
            ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.stage,
    required this.current,
    required this.streak,
  });

  final FlameStage stage;
  final FlameStage current;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool reached = stage.index <= current.index;
    final bool isCurrent = stage == current;
    final bool isNext = stage.index == current.index + 1;
    final bool hidden = !reached && !isNext;

    Widget flame = CustomPaint(
      size: const Size.square(64),
      painter: FlamePainter(
        stage: stage,
        mood: isCurrent ? MascotMood.happy : MascotMood.hopeful,
        seconds: 1.2 + stage.index * 0.37,
        blink: false,
      ),
    );
    if (hidden) {
      flame = ColorFiltered(
        colorFilter: const ColorFilter.mode(Color(0xFF05030A), BlendMode.srcIn),
        child: flame,
      );
    } else if (isNext) {
      flame = Opacity(opacity: 0.55, child: flame);
    }

    final int? left = isNext ? stage.minStreak - streak : null;

    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 4, vertical: AppSpacing.sm),
      border: isCurrent
          ? AppColors.flame
          : reached
              ? AppColors.flame.withValues(alpha: 0.35)
              : AppColors.outline,
      glow: isCurrent ? AppColors.flame : null,
      child: Row(
        children: <Widget>[
          flame,
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  hidden ? '???' : l10n.stageName(stage),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: hidden
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  left != null
                      ? l10n.stageNext(l10n.stageName(stage), left)
                      : l10n.stageFrom(stage.minStreak),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                ),
                if (left != null) ...<Widget>[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: AppRadius.pill,
                    child: LinearProgressIndicator(
                      value: stageProgress(streak),
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceHigh,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (isCurrent)
            Pill(l10n.evolutionCurrent, color: AppColors.flame, filled: true)
          else if (reached)
            const Icon(Icons.check_circle, color: AppColors.lime)
          else if (left != null)
            const Icon(Icons.lock_open, color: AppColors.flameSoft)
          else
            const Icon(Icons.lock_outline, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
