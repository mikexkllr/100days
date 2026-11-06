import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../theme/theme.dart';
import '../mascot/flame_painter.dart';
import '../mascot/speech_bubble.dart';
import '../motion/motion.dart';
import '../motion/particles.dart';
import '../motion/rolling_number.dart';
import '../widgets/streak_ring.dart';
import 'flame_evolution_sheet.dart';
import 'week_strip.dart';

/// Where the day stands, for the status line under the flame.
enum HeroStatus { open, done, rest, frozen, relapse }

/// The top of the home screen: Funki in the ring of the cycle, what Funki
/// has to say, the streak as a number that counts up, this week as a chain,
/// and the clock that is running on today.
class StreakHero extends StatefulWidget {
  const StreakHero({
    super.key,
    required this.snapshot,
    this.onTapStatus,
  });

  final AppSnapshot snapshot;

  /// Tapping the status line — the home screen scrolls to today's habits.
  final VoidCallback? onTapStatus;

  @override
  State<StreakHero> createState() => _StreakHeroState();
}

class _StreakHeroState extends State<StreakHero> {
  String? _pokeLine;
  Timer? _pokeTimer;
  final math.Random _random = math.Random();

  @override
  void dispose() {
    _pokeTimer?.cancel();
    super.dispose();
  }

  void _onPoke(int combo) {
    final List<String> pokes = context.l10n.mascotPokes;
    String line = combo >= 5
        ? context.l10n.mascotPokeCombo
        : pokes[_random.nextInt(pokes.length)];
    if (line == _pokeLine && combo < 5) {
      line = pokes[(pokes.indexOf(line) + 1) % pokes.length];
    }
    _pokeTimer?.cancel();
    setState(() => _pokeLine = line);
    _pokeTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _pokeLine = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppSnapshot snapshot = widget.snapshot;
    final Challenge challenge = snapshot.challenge!;
    final DayKey today = snapshot.today;
    final StreakStats streak = snapshot.me.streak;
    final DayLog? log = snapshot.me.logsByDay[today.toString()];
    final DateTime now = DateTime.now();
    final Duration left = DateTime(now.year, now.month, now.day + 1).difference(now);

    final bool restDay = isRestDay(challenge, today);
    final bool frozen = snapshot.me.frozenDays.contains(today.toString());
    final bool relapse = log?.hasRelapse ?? false;
    final HeroStatus status = relapse
        ? HeroStatus.relapse
        : streak.doneToday
            ? HeroStatus.done
            : frozen
                ? HeroStatus.frozen
                : restDay
                    ? HeroStatus.rest
                    : HeroStatus.open;

    final MascotMood mood = moodForToday(
      doneToday: streak.doneToday,
      restDay: restDay,
      frozenToday: frozen,
      relapseToday: relapse,
      streak: streak.current,
      now: now,
    );
    final FlameStage stage = flameStageFor(streak.current);
    final int dayNumber = challenge.dayNumber(today);
    final String line = _pokeLine ??
        l10n.mascotLineFor(
          mood,
          day: dayNumber,
          streak: streak.current,
          hoursLeft: left.inHours,
        );

    return Column(
      children: <Widget>[
        SizedBox(
          height: 74,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SpeechBubble(
              key: const Key('mascot-bubble'),
              text: line,
              accent: status == HeroStatus.open && mood == MascotMood.worried
                  ? AppColors.danger
                  : AppColors.flame,
            ),
          ),
        ),
        Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned.fill(
              child: EmberField(
                count: 14 + stage.index * 2,
                intensity: status == HeroStatus.done ? 1.3 : 0.8,
              ),
            ),
            StreakRing(
              progress: challenge.progressInCycle(today),
              dayInCycle: challenge.dayInCycle(today),
              cycleLength: challenge.lengthDays,
              stage: stage,
              mood: mood,
              atRisk: streak.atRisk && !frozen,
              size: 264,
              onPoke: _onPoke,
              mascotLabel: l10n.mascotSemantics,
            ),
          ],
        ),
        RollingNumber(
          value: streak.current,
          countFromZero: true,
          duration: Duration(
              milliseconds: (500 + streak.current * 25).clamp(500, 1600)),
          style: displayStyle(88, height: 0.95),
          gradient: AppGradients.fireText,
          glow: AppColors.flame,
        ),
        Text(
          l10n.ringDayStreak(streak.current).toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 3,
                fontSize: 12,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _HeroChip(
              child: Text(
                l10n.ringDayOfTotal(
                  dayNumber,
                  challenge.lengthDays * (challenge.cycle + 1),
                ),
                style: _chipText(context),
              ),
            ),
            _StageChip(streak: streak.current, stage: stage),
            if (streak.longest > streak.current)
              _HeroChip(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.emoji_events,
                        size: 15, color: AppColors.gold),
                    const SizedBox(width: 5),
                    Text(l10n.heroBest(streak.longest),
                        style: _chipText(context)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _StatusLine(
          status: status,
          streak: streak.current,
          onTap: widget.onTapStatus,
        ),
        const SizedBox(height: AppSpacing.md),
        WeekStrip(
          marks: weekMarks(
            challenge: challenge,
            day: today,
            today: today,
            logsByDay: snapshot.me.logsByDay,
            frozenDays: snapshot.me.frozenDays,
          ),
          monday: today.weekStart,
          today: today,
        ),
      ],
    );
  }
}

TextStyle? _chipText(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        );

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.child, this.onTap, this.border});

  final Widget child;
  final VoidCallback? onTap;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.pill,
        border: Border.all(color: border ?? AppColors.outline),
      ),
      child: child,
    );
    if (onTap == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: AppRadius.pill, onTap: onTap, child: chip),
    );
  }
}

/// The current form and how far the next one is — opens the whole ladder.
class _StageChip extends StatelessWidget {
  const _StageChip({required this.streak, required this.stage});

  final int streak;
  final FlameStage stage;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final int? toNext = daysToNextStage(streak);
    final FlameStage? next = stage.next;
    return _HeroChip(
      border: AppColors.flame.withValues(alpha: 0.5),
      onTap: () => showFlameEvolution(context, streak: streak),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CustomPaint(
            size: const Size.square(22),
            painter: FlamePainter(
              stage: stage,
              mood: MascotMood.happy,
              seconds: 1.2,
              blink: false,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              l10n.stageName(stage),
              style: _chipText(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (next != null && toNext != null) ...<Widget>[
            const Icon(Icons.arrow_right_alt,
                size: 18, color: AppColors.textTertiary),
            Flexible(
              flex: 2,
              child: Text(
                l10n.stageNext(l10n.stageName(next), toNext),
                style:
                    _chipText(context)?.copyWith(color: AppColors.flameSoft),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const Icon(Icons.chevron_right,
              size: 18, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

/// One line on the state of today. While today is open it is a clock that
/// runs to midnight — when the streak really does end.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.status,
    required this.streak,
    this.onTap,
  });

  final HeroStatus status;
  final int streak;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    switch (status) {
      case HeroStatus.done:
        return _line(context, Icons.check_circle, l10n.heroFedToday,
            AppColors.lime);
      case HeroStatus.rest:
        return _line(
            context, Icons.bedtime, l10n.heroRestDay, AppColors.ice);
      case HeroStatus.frozen:
        return _line(context, Icons.ac_unit, l10n.heroFrozen, AppColors.ice);
      case HeroStatus.relapse:
        return _line(context, Icons.restart_alt, l10n.heroRelapse,
            AppColors.flameSoft);
      case HeroStatus.open:
        return DayCountdown(
          builder: (BuildContext context, Duration left) {
            final String time = formatCountdown(left);
            final bool late = left.inHours < 4;
            final Color accent = late ? AppColors.danger : AppColors.amber;
            final String text = streak > 0
                ? l10n.heroCountdownSave(time)
                : l10n.heroCountdownFirst(time);
            final int at = text.indexOf(time);
            final TextStyle base = Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary);
            return _shell(
              context,
              accent: accent,
              pulse: late,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.hourglass_bottom, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text.rich(
                      at < 0
                          ? TextSpan(text: text)
                          : TextSpan(children: <TextSpan>[
                              TextSpan(text: text.substring(0, at)),
                              TextSpan(
                                text: time,
                                style: displayStyle(17, color: accent).copyWith(
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              TextSpan(text: text.substring(at + time.length)),
                            ]),
                      style: base,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          },
        );
    }
  }

  Widget _line(BuildContext context, IconData icon, String text, Color accent) {
    return _shell(
      context,
      accent: accent,
      pulse: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shell(
    BuildContext context, {
    required Color accent,
    required bool pulse,
    required Widget child,
  }) {
    Widget shell(double glow) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pill,
            color: accent.withValues(alpha: 0.1),
            border: Border.all(color: accent.withValues(alpha: 0.65), width: 1.5),
            boxShadow: glow > 0 ? AppShadows.glow(accent, strength: glow) : null,
          ),
          child: child,
        );
    final Widget body = pulse
        ? AmbientClock(
            builder: (BuildContext context, double s, Widget? _) =>
                shell(0.35 + 0.35 * math.sin(s * 5)),
          )
        : shell(0.25);
    if (onTap == null) return body;
    return GestureDetector(onTap: onTap, child: body);
  }
}

/// Rebuilds every second with the time left until midnight.
class DayCountdown extends StatefulWidget {
  const DayCountdown({super.key, required this.builder});

  final Widget Function(BuildContext context, Duration left) builder;

  @override
  State<DayCountdown> createState() => _DayCountdownState();
}

class _DayCountdownState extends State<DayCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final Duration left =
        DateTime(now.year, now.month, now.day + 1).difference(now);
    return widget.builder(context, left);
  }
}

/// 05:12:33.
String formatCountdown(Duration left) {
  String two(int n) => n.toString().padLeft(2, '0');
  final int seconds = math.max(0, left.inSeconds);
  return '${two(seconds ~/ 3600)}:${two(seconds % 3600 ~/ 60)}:${two(seconds % 60)}';
}
