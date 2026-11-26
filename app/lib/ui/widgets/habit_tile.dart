import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../theme/fire.dart';
import '../../theme/theme.dart';
import '../motion/motion.dart';
import '../motion/particles.dart';
import '../motion/rolling_number.dart';
import 'hold_button.dart';

/// One habit for today: a single row, and the whole row is the button.
///
/// Hold it and it fills with fire; when it is full the habit is logged at
/// its target. That is the one gesture for the common case, the same for
/// every habit. Whatever a habit needs beyond that sits one tap away, under
/// the row: a different amount than the target ("I read 35 pages"), or an
/// honest relapse.
///
/// Checking in is the moment the app exists for, so it is loud: sparks out
/// of the row, the XP it earned floating up, the row staying lit.
class HabitTile extends StatefulWidget {
  const HabitTile({
    super.key,
    required this.habit,
    required this.streak,
    required this.entry,
    required this.onCheckIn,
    required this.onRelapse,
    this.onUndo,
    this.onHoldFill,
    this.tapToCheckIn = false,
    this.fire = const Fire(
      light: Color(0xFFFFA3BC),
      main: Color(0xFFFF5C8A),
      deep: Color(0xFFB3184A),
    ),
    this.scheduledToday = true,
    this.xpGain,
    this.celebration = 0,
    this.onOpenDiary,
    this.diaryLine,
  });

  final Habit habit;
  final int streak;
  final CheckIn? entry;
  final void Function(num value) onCheckIn;
  final VoidCallback onRelapse;

  /// Takes today's entry back — a slip of the thumb is not a check-in.
  final VoidCallback? onUndo;

  /// How full the row is while it is held, for Funki to watch.
  final ValueChanged<double>? onHoldFill;

  /// A tap checks in (the setting for people who cannot hold a press); the
  /// extras then open from a button of their own.
  final bool tapToCheckIn;

  /// The colour a done habit is lit in.
  final Fire fire;
  final bool scheduledToday;

  /// What the last check-in on this tile earned, shown as it floats away.
  final int? xpGain;

  /// Bumped by the screen after each check-in to replay the celebration.
  final int celebration;

  /// Set on the nutrition row of someone who keeps a food diary: the row
  /// leads into it.
  final VoidCallback? onOpenDiary;

  /// Where the diary stands today — "Diary: 1240 / 2100 kcal" — on the
  /// line that leads there.
  final String? diaryLine;

  @override
  State<HabitTile> createState() => _HabitTileState();
}

class _HabitTileState extends State<HabitTile> {
  bool _open = false;
  int _nudges = 0;

  /// Let go too early: say so for a moment instead of doing nothing.
  bool _holdHint = false;
  Timer? _hintTimer;

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  void _onShortHold() {
    HapticFeedback.lightImpact();
    _hintTimer?.cancel();
    setState(() {
      _holdHint = true;
      _nudges++;
    });
    _hintTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _holdHint = false);
    });
  }

  Habit get _habit => widget.habit;
  CheckIn? get _entry => widget.entry;

  bool get _isDone =>
      _entry != null && !_entry!.relapse && _entry!.value >= _habit.target;
  bool get _isRelapse => _entry?.relapse ?? false;
  bool get _isAmount => _habit.definition.unit != HabitUnit.done;
  bool get _isAbstain => _habit.kind == HabitKind.abstain;

  /// Whether a tap has anything to reveal: always — a plain button for
  /// those who cannot hold, the amount, a relapse, or the undo.
  bool get _hasMore => true;

  @override
  void didUpdateWidget(HabitTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Logged: fold the extras away again.
    if (oldWidget.celebration != widget.celebration ||
        (!(oldWidget.entry?.relapse ?? false) && _isRelapse)) {
      _open = false;
    }
  }

  void _onTap() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_hasMore) {
        _open = !_open;
      } else {
        // Nothing to open: point at the gesture instead.
        _nudges++;
      }
    });
  }

  String _action(AppLocalizations l10n) => _isAmount
      ? l10n.tileLogAmount
      : _isAbstain
          ? l10n.tileCleanToday
          : l10n.tileCheckOff;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Fire fire = widget.fire;
    final bool canHold = !_isDone && !_isRelapse;
    final Color accent = _isRelapse ? AppColors.danger : fire.main;
    final bool tinted = _isDone || _isRelapse;

    final Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: tinted
            ? Color.alphaBlend(
                accent.withValues(alpha: 0.13),
                AppColors.ink.withValues(alpha: 0.6),
              )
            : Color.alphaBlend(
                AppColors.glass,
                AppColors.ink.withValues(alpha: 0.55),
              ),
        border: Border.all(
          color: tinted ? accent.withValues(alpha: 0.42) : AppColors.glassEdge,
        ),
      ),
      // The stepper's ink needs a Material to paint on.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            HoldButton(
              label: '${l10n.habitLabel(_habit)}, '
                  '${_isDone ? l10n.tileDone : _action(l10n)}',
              onConfirmed:
                  canHold ? () => widget.onCheckIn(_habit.target) : null,
              onTap: _onTap,
              onShortHold: _onShortHold,
              onFill: widget.onHoldFill,
              tapConfirms: widget.tapToCheckIn,
              builder: (BuildContext context, double fill) => Stack(
                children: <Widget>[
                  if (fill > 0)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _FlameFillPainter(fill: fill, fire: fire),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    child: Row(
                      children: <Widget>[
                        _EmojiBadge(
                          emoji: _habit.emoji,
                          tint: tinted ? accent : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                l10n.habitLabel(_habit),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              _Subtitle(
                                text: _holdHint
                                    ? l10n.tileHoldLonger
                                    : _subtitle(l10n),
                                streak: _isRelapse ? 0 : widget.streak,
                                color: _isRelapse
                                    ? AppColors.danger
                                    : AppColors.textSecondary,
                                fire: fire,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_isDone)
                          DoneBadge(label: l10n.tileDone, color: fire.light)
                        else if (canHold && widget.tapToCheckIn)
                          _HoldChip(label: _action(l10n), active: false)
                        else if (canHold)
                          TriggeredAnimation(
                            trigger: _nudges,
                            duration: const Duration(milliseconds: 520),
                            builder: (BuildContext context, double t,
                                    Widget? child) =>
                                Transform.scale(
                              scale: _nudges == 0 ? 1 : bounceScale(t),
                              child: child,
                            ),
                            child: _HoldChip(
                              label: _action(l10n),
                              active: fill > 0,
                            ),
                          ),
                        if (widget.tapToCheckIn)
                          IconButton(
                            tooltip: l10n.tileMoreSemantics(
                                l10n.habitLabel(_habit)),
                            onPressed: () => setState(() => _open = !_open),
                            icon: Icon(
                              _open ? Icons.expand_less : Icons.more_horiz,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Outside the row that is held: a tap here must never be the
            // start of a check-in, nor a check-in the start of a tap here.
            if (widget.onOpenDiary != null)
              InkWell(
                key: Key('tile-diary-${_habit.id}'),
                onTap: widget.onOpenDiary,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(64, 0, 12, 10),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.restaurant_menu,
                          size: 15, color: AppColors.textTertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.diaryLine ?? l10n.homeOpenDiary,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary),
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 18, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _open && _hasMore
                  ? _More(
                      habit: _habit,
                      current: _entry == null || _isRelapse ? 0 : _entry!.value,
                      isDone: _isDone,
                      canHold: canHold,
                      hasEntry: _entry != null,
                      showHoldTip: !widget.tapToCheckIn,
                      onCheckIn: widget.onCheckIn,
                      onRelapse: widget.onRelapse,
                      onUndo: widget.onUndo,
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );

    return TriggeredAnimation(
      trigger: widget.celebration,
      duration: const Duration(milliseconds: 1300),
      child: card,
      builder: (BuildContext context, double t, Widget? card) {
        final bool playing = widget.celebration > 0 && t < 1;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Transform.scale(
              scale: playing
                  ? 1 + (bounceScale((t / 0.4).clamp(0, 1)) - 1) * 0.35
                  : 1,
              child: ParticleBurst(
                trigger: widget.celebration == 0 ? null : widget.celebration,
                origin: const Alignment(0.7, 0),
                count: 30,
                kinds: const <ParticleKind>[
                  ParticleKind.spark,
                  ParticleKind.star,
                ],
                colors: <Color>[fire.light, fire.main, AppColors.glow],
                power: 0.75,
                upward: true,
                child: card,
              ),
            ),
            if (playing && widget.xpGain != null && widget.xpGain! > 0)
              Positioned(
                right: AppSpacing.md,
                bottom: 30 + 54 * Curves.easeOutCubic.transform(t),
                child: IgnorePointer(
                  child: Opacity(
                    opacity: t < 0.15 ? t / 0.15 : (1 - (t - 0.15) / 0.85),
                    child: Transform.scale(
                      scale: 0.6 + 0.6 * popCurve((t / 0.5).clamp(0, 1)),
                      child: GlowText(
                        '+${l10n.homeXp(widget.xpGain!)}',
                        style: displayStyle(22, color: AppColors.textPrimary),
                        glow: fire.main,
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

  String? _subtitle(AppLocalizations l10n) {
    if (_isRelapse) return l10n.tileRelapseLogged;
    if (_habit.optional && !_isDone) return l10n.tileOptional;
    if (!widget.scheduledToday && !_isDone) return l10n.tileRestToday;
    if (!_isAmount) return widget.streak > 0 ? null : l10n.tileHoldExplain;
    final num value = _entry?.value ?? 0;
    // Under the target: what is there, of what it takes.
    if (value > 0 && !_isDone) {
      return '${value.round()} / ${l10n.formatTarget(_habit)}';
    }
    return l10n.formatTarget(_habit, value: _isDone ? value : null);
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({
    required this.text,
    required this.streak,
    required this.color,
    required this.fire,
  });

  final String? text;
  final int streak;
  final Color color;
  final Fire fire;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = Theme.of(context)
        .textTheme
        .bodyMedium!
        .copyWith(color: color, fontSize: 12.5, height: 1.25);
    return Row(
      children: <Widget>[
        if (streak > 0) ...<Widget>[
          Icon(Icons.local_fire_department, size: 14, color: fire.main),
          const SizedBox(width: 2),
          Text(
            '$streak',
            style: style.copyWith(
              color: fire.light,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (text != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('·', style: style),
            ),
        ],
        if (text != null)
          Flexible(
            child: Text(
              text!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
      ],
    );
  }
}

class _EmojiBadge extends StatelessWidget {
  const _EmojiBadge({required this.emoji, required this.tint});

  final String emoji;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: tint == null
            ? AppColors.glassHigh
            : tint!.withValues(alpha: 0.22),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 21)),
    );
  }
}

/// What holding the row will do — the one place the gesture is spelled out.
class _HoldChip extends StatelessWidget {
  const _HoldChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    // With large system text the label would be cut to "Heute c…"; the
    // hand alone says "hold" and the row still names the habit.
    final bool compact = MediaQuery.textScalerOf(context).scale(10) > 13;
    if (compact) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? AppColors.primary : Colors.transparent,
          border: Border.all(
            color: active
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.32),
            width: 1.2,
          ),
        ),
        child: Icon(
          Icons.touch_app_outlined,
          size: 18,
          color: active ? AppColors.onPrimary : AppColors.textPrimary,
        ),
      );
    }
    return Container(
      height: 36,
      constraints: const BoxConstraints(maxWidth: 138),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: AppRadius.pill,
        color: active ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: active
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.32),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.touch_app_outlined,
            size: 14,
            color: active ? AppColors.onPrimary : AppColors.textSecondary,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kTextFont,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? AppColors.onPrimary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A finished check-in: lit, nothing left to press.
class DoneBadge extends StatelessWidget {
  const DoneBadge({
    super.key,
    required this.label,
    this.color = AppColors.success,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontFamily: kTextFont,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.check_circle, color: color, size: 24),
      ],
    );
  }
}

/// Under the row: a different amount than the target, or a relapse.
class _More extends StatefulWidget {
  const _More({
    required this.habit,
    required this.current,
    required this.isDone,
    required this.canHold,
    required this.hasEntry,
    required this.showHoldTip,
    required this.onCheckIn,
    required this.onRelapse,
    this.onUndo,
  });

  final Habit habit;
  final num current;
  final bool isDone;
  final bool canHold;
  final bool hasEntry;
  final bool showHoldTip;
  final void Function(num value) onCheckIn;
  final VoidCallback onRelapse;
  final VoidCallback? onUndo;

  @override
  State<_More> createState() => _MoreState();
}

class _MoreState extends State<_More> {
  late num _value = widget.current > 0 ? widget.current : widget.habit.target;

  bool get _isAmount => widget.habit.definition.unit != HabitUnit.done;

  num get _step {
    final num target = widget.habit.target;
    if (target >= 100) return 30;
    if (target >= 20) return 5;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.glassEdge)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_isAmount)
            Row(
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
                const SizedBox(width: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(104, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => widget.onCheckIn(_value),
                  child: Text(
                    widget.isDone ? l10n.tileUpdateAmount : l10n.tileLogAmount,
                  ),
                ),
              ],
            )
          else
            Row(
              children: <Widget>[
                // The same check-in as the hold, as a plain button: for
                // anyone who cannot or does not want to hold a press.
                if (widget.canHold)
                  Expanded(
                    child: FilledButton(
                      key: Key('tile-plain-${widget.habit.id}'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: () => widget.onCheckIn(widget.habit.target),
                      child: Text(
                        widget.habit.kind == HabitKind.abstain
                            ? l10n.tileCleanToday
                            : l10n.tileCheckOff,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (widget.habit.kind == HabitKind.abstain &&
                    widget.canHold) ...<Widget>[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: widget.onRelapse,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(60, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      foregroundColor: AppColors.danger,
                      backgroundColor: Colors.transparent,
                      side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    child: Text(l10n.tileRelapse),
                  ),
                ],
              ],
            ),
          if (widget.hasEntry && widget.onUndo != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: Key('tile-undo-${widget.habit.id}'),
                onPressed: widget.onUndo,
                icon: const Icon(Icons.undo, size: 18),
                label: Text(l10n.tileUndo),
              ),
            )
          else if (widget.canHold && widget.showHoldTip)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.tileHoldTip,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 12.5,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The fill of a held row: fire climbing from the left, with a ragged,
/// flickering edge of flame tongues and a few sparks at its front.
class _FlameFillPainter extends CustomPainter {
  _FlameFillPainter({required this.fill, required this.fire});

  final double fill;
  final Fire fire;

  @override
  void paint(Canvas canvas, Size size) {
    final double front = size.width * fill;
    final Rect body = Rect.fromLTWH(0, 0, front, size.height);
    canvas.drawRect(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            fire.main.withValues(alpha: 0.22),
            fire.main.withValues(alpha: 0.58),
          ],
        ).createShader(body),
    );
    // Tongues of flame licking past the front; they move as the fill grows.
    const int tongues = 5;
    final double phase = fill * 23;
    final Path edge = Path()..moveTo(front, 0);
    for (int i = 0; i < tongues; i++) {
      final double y0 = size.height * i / tongues;
      final double y1 = size.height * (i + 1) / tongues;
      final double reach =
          10 + 8 * (0.5 + 0.5 * math.sin(phase + i * 1.7)) * fill;
      edge.quadraticBezierTo(front + reach, (y0 + y1) / 2, front, y1);
    }
    edge.close();
    canvas.drawPath(
      edge,
      Paint()
        ..color = fire.light.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Sparks just ahead of the fire.
    final Paint spark = Paint()..color = fire.light.withValues(alpha: 0.9);
    for (int i = 0; i < 4; i++) {
      final double t = (phase * 0.37 + i * 0.29) % 1;
      canvas.drawCircle(
        Offset(front + 6 + 14 * t, size.height * (0.2 + 0.2 * i) - 6 * t),
        1.6 * (1 - t),
        spark,
      );
    }
  }

  @override
  bool shouldRepaint(_FlameFillPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.fire != fire;
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
