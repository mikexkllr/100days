import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../theme/theme.dart';
import 'app_card.dart';

/// One habit for today, with the check-in control it actually needs.
///
/// A "no sugar" day is a yes/no; twenty pages of reading is a number you have
/// to be able to overshoot. Forcing both into a single checkbox is how habit
/// apps end up feeling like paperwork.
class HabitTile extends StatelessWidget {
  const HabitTile({
    super.key,
    required this.habit,
    required this.streak,
    required this.entry,
    required this.onCheckIn,
    required this.onRelapse,
    this.scheduledToday = true,
  });

  final Habit habit;
  final int streak;
  final CheckIn? entry;
  final void Function(num value) onCheckIn;
  final VoidCallback onRelapse;
  final bool scheduledToday;

  bool get _isDone =>
      entry != null && !entry!.relapse && entry!.value >= habit.target;

  bool get _isRelapse => entry?.relapse ?? false;

  @override
  Widget build(BuildContext context) {
    final Color accent = _isRelapse
        ? AppColors.danger
        : _isDone
            ? AppColors.lime
            : AppColors.outline;

    return AppCard(
      border: accent.withValues(alpha: _isDone || _isRelapse ? 0.6 : 1),
      color: _isDone
          ? AppColors.lime.withValues(alpha: 0.06)
          : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(habit.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      habit.displayTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(),
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
              if (streak > 0 && !_isRelapse)
                Pill(
                  '$streak 🔥',
                  color: AppColors.flame,
                  filled: true,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _control(context),
        ],
      ),
    );
  }

  String _subtitle() {
    if (_isRelapse) return 'Rückfall eingetragen — morgen neu.';
    if (!scheduledToday) return 'Heute Pause laut Plan';
    if (_isDone) return 'Erledigt · ${formatHabitTarget(habit)}';
    return 'Ziel: ${formatHabitTarget(habit)}';
  }

  Widget _control(BuildContext context) {
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
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: isDone
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    onCheckIn();
                  },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              backgroundColor:
                  isDone ? AppColors.lime.withValues(alpha: 0.2) : null,
              disabledBackgroundColor: AppColors.lime.withValues(alpha: 0.18),
              disabledForegroundColor: AppColors.lime,
            ),
            icon: Icon(isDone ? Icons.check_circle : Icons.check, size: 19),
            label: Text(isDone
                ? 'Erledigt'
                : isAbstain
                    ? 'Heute clean'
                    : 'Abhaken'),
          ),
        ),
        if (isAbstain) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            onPressed: isRelapse ? null : onRelapse,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(60, 46),
              foregroundColor: AppColors.danger,
              side: BorderSide(
                color: AppColors.danger.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: const Text('Rückfall'),
          ),
        ],
      ],
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
              formatHabitTarget(widget.habit.copyWith(target: _value)),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          onTap: () => setState(() => _value = _value + _step),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            widget.onCheckIn(_value);
          },
          style: FilledButton.styleFrom(
            minimumSize: const Size(96, 46),
            backgroundColor:
                isDone ? AppColors.lime.withValues(alpha: 0.2) : null,
            foregroundColor: isDone ? AppColors.lime : null,
          ),
          child: Text(isDone ? 'Update' : 'Eintragen'),
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
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.surfaceHigh,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: AppColors.textPrimary),
      ),
    );
  }
}
