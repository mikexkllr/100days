import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../theme/theme.dart';
import '../motion/motion.dart';
import '../motion/particles.dart';
import '../motion/rolling_number.dart';
import 'app_card.dart';
import 'hold_button.dart';
import 'juicy_button.dart';

/// One habit for today, with the check-in control it actually needs.
///
/// A "no sugar" day is a yes/no; twenty pages of reading is a number you have
/// to be able to overshoot. Forcing both into a single checkbox is how habit
/// apps end up feeling like paperwork.
///
/// Checking in is the moment the app exists for, so it is loud: sparks out
/// of the button, the XP it earned floating up, the card lighting up green.
class HabitTile extends StatelessWidget {
  const HabitTile({
    super.key,
    required this.habit,
    required this.streak,
    required this.entry,
    required this.onCheckIn,
    required this.onRelapse,
    this.scheduledToday = true,
    this.xpGain,
    this.celebration = 0,
  });

  final Habit habit;
  final int streak;
  final CheckIn? entry;
  final void Function(num value) onCheckIn;
  final VoidCallback onRelapse;
  final bool scheduledToday;

  /// What the last check-in on this tile earned, shown as it floats away.
  final int? xpGain;

  /// Bumped by the screen after each check-in to replay the celebration.
  final int celebration;

  bool get _isDone =>
      entry != null && !entry!.relapse && entry!.value >= habit.target;

  bool get _isRelapse => entry?.relapse ?? false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    final Widget card = AppCard(
      border: _isRelapse
          ? AppColors.danger
          : _isDone
              ? AppColors.success
              : null,
      glow: _isDone ? AppColors.success.withValues(alpha: 0.5) : null,
      color: _isDone ? AppColors.success : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _EmojiBadge(emoji: habit.emoji, lit: _isDone),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.habitLabel(habit),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(l10n),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _isRelapse
                                ? AppColors.danger
                                : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                    ),
                  ],
                ),
              ),
              if (streak > 0 && !_isRelapse) _StreakBadge(streak: streak),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _control(context, l10n),
        ],
      ),
    );

    return TriggeredAnimation(
      trigger: celebration,
      duration: const Duration(milliseconds: 1300),
      child: card,
      builder: (BuildContext context, double t, Widget? card) {
        final bool playing = celebration > 0 && t < 1;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Transform.scale(
              scale: playing ? bounceScale((t / 0.4).clamp(0, 1)) : 1,
              child: ParticleBurst(
                trigger: celebration == 0 ? null : celebration,
                origin: const Alignment(0, 0.6),
                count: 34,
                kinds: const <ParticleKind>[
                  ParticleKind.spark,
                  ParticleKind.star,
                  ParticleKind.confetti,
                ],
                colors: kHoloParticles,
                power: 0.8,
                upward: true,
                child: card,
              ),
            ),
            if (playing && xpGain != null && xpGain! > 0)
              Positioned(
                right: AppSpacing.lg,
                bottom: 40 + 70 * Curves.easeOutCubic.transform(t),
                child: IgnorePointer(
                  child: Opacity(
                    opacity: t < 0.15 ? t / 0.15 : (1 - (t - 0.15) / 0.85),
                    child: Transform.scale(
                      scale: 0.6 + 0.6 * popCurve((t / 0.5).clamp(0, 1)),
                      child: GlowText(
                        '+${l10n.homeXp(xpGain!)}',
                        style: displayStyle(26, color: AppColors.reward),
                        gradient: AppGradients.holo,
                        glow: AppColors.reward,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _subtitle(AppLocalizations l10n) {
    if (_isRelapse) return l10n.tileRelapseLogged;
    if (!scheduledToday) return l10n.tileRestToday;
    if (_isDone) return l10n.tileDoneWith(l10n.formatTarget(habit));
    return l10n.tileTarget(l10n.formatTarget(habit));
  }

  Widget _control(BuildContext context, AppLocalizations l10n) {
    if (habit.definition.unit == HabitUnit.done) {
      return _DoneControl(
        isDone: _isDone,
        isRelapse: _isRelapse,
        isAbstain: habit.kind == HabitKind.abstain,
        onCheckIn: () => onCheckIn(habit.target),
        onRelapse: onRelapse,
      );
    }
    return _AmountControl(
      habit: habit,
      current: entry?.value ?? 0,
      onCheckIn: onCheckIn,
    );
  }
}

class _EmojiBadge extends StatelessWidget {
  const _EmojiBadge({required this.emoji, required this.lit});

  final String emoji;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final Color accent = lit ? AppColors.success : AppColors.primary;
    return Container(
      width: 50,
      height: 50,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: AppGradients.edge(accent),
        boxShadow: lit ? AppShadows.glow(accent, strength: 0.6) : null,
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15.5),
          gradient: RadialGradient(
            colors: <Color>[
              accent.withValues(alpha: 0.4),
              AppColors.surface,
            ],
          ),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: AppGradients.plasma,
        borderRadius: AppRadius.pill,
        boxShadow: AppShadows.glow(AppColors.hot, strength: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$streak',
            style:
                displayStyle(12, color: Colors.white, weight: FontWeight.w700),
          ),
          const SizedBox(width: 3),
          const Icon(Icons.local_fire_department, size: 14, color: Colors.white),
        ],
      ),
    );
  }
}

class _DoneControl extends StatelessWidget {
  const _DoneControl({
    required this.isDone,
    required this.isRelapse,
    required this.isAbstain,
    required this.onCheckIn,
    required this.onRelapse,
  });

  final bool isDone;
  final bool isRelapse;
  final bool isAbstain;
  final VoidCallback onCheckIn;
  final VoidCallback onRelapse;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Row(
      children: <Widget>[
        Expanded(
          child: isDone
              ? DoneBadge(label: l10n.tileDone)
              : HoldButton(
                  label: isAbstain ? l10n.tileCleanToday : l10n.tileCheckOff,
                  hint: l10n.tileHoldHint,
                  icon: isAbstain ? Icons.shield_outlined : Icons.bolt,
                  onConfirmed: onCheckIn,
                ),
        ),
        if (isAbstain) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: isRelapse ? null : onRelapse,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(60, 52),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                foregroundColor: AppColors.danger,
                side: BorderSide(
                  color: AppColors.danger.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                textStyle: displayStyle(12, weight: FontWeight.w700),
              ),
              child: Text(l10n.tileRelapse),
            ),
          ),
        ],
      ],
    );
  }
}

/// A finished check-in: the green of a done thing, nothing left to press.
class DoneBadge extends StatelessWidget {
  const DoneBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: AppRadius.pill,
        color: AppColors.success.withValues(alpha: 0.14),
        border: Border.all(
            color: AppColors.success.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.check_circle, color: AppColors.success, size: 21),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: displayStyle(14,
                  color: AppColors.success, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountControl extends StatefulWidget {
  const _AmountControl({
    required this.habit,
    required this.current,
    required this.onCheckIn,
  });

  final Habit habit;
  final num current;
  final void Function(num value) onCheckIn;

  @override
  State<_AmountControl> createState() => _AmountControlState();
}

class _AmountControlState extends State<_AmountControl> {
  late num _value = widget.current > 0 ? widget.current : widget.habit.target;

  @override
  void didUpdateWidget(_AmountControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current && widget.current > 0) {
      _value = widget.current;
    }
  }

  num get _step {
    final target = widget.habit.target;
    if (target >= 100) return 30;
    if (target >= 20) return 5;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isDone = widget.current >= widget.habit.target;
    return Row(
      children: <Widget>[
        _StepButton(
          icon: Icons.remove,
          onTap: () => setState(() {
            _value = (_value - _step).clamp(0, double.infinity);
          }),
        ),
        Expanded(
          child: Center(
            child: Text(
              l10n.formatTarget(widget.habit, value: _value),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          onTap: () => setState(() => _value = _value + _step),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 130,
          child: isDone
              ? JuicyButton.success(
                  label: l10n.tileUpdateAmount,
                  onPressed: () => widget.onCheckIn(_value),
                  fontSize: 15,
                )
              : HoldButton(
                  label: l10n.tileLogAmount,
                  icon: Icons.bolt,
                  compact: true,
                  onConfirmed: () => widget.onCheckIn(_value),
                ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      radius: 24,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.glass,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassEdge),
        ),
        child: Icon(icon, size: 19, color: AppColors.textPrimary),
      ),
    );
  }
}
