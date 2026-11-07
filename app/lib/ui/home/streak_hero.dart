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

    final bool worried = status == HeroStatus.open && mood == MascotMood.worried;
    final FlameStage? next = stage.next;
    final int? toNext = daysToNextStage(streak.current);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: AppGradients.edge(worried ? AppColors.hot : AppColors.primary),
        boxShadow: AppShadows.glow(
            worried ? AppColors.hot : AppColors.primary, strength: 0.55),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(31),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.65, -0.1),
                radius: 1.15,
                colors: <Color>[
                  Color.lerp(AppColors.surface, AppColors.primary, 0.32)!,
                  AppColors.surface.withValues(alpha: 0.92),
                  AppColors.ink.withValues(alpha: 0.95),
                ],
              ),
            ),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: EmberField(
                    count: 12 + stage.index * 2,
                    colors: const <Color>[
                      AppColors.primarySoft,
                      AppColors.attention,
                      AppColors.reward,
                    ],
                    intensity: status == HeroStatus.done ? 1.2 : 0.7,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerRight,
                        child: SpeechBubble(
                          key: const Key('mascot-bubble'),
                          text: line,
                          accent: worried ? AppColors.hot : AppColors.primary,
                          tailAt: 0.78,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: RollingNumber(
                                    value: streak.current,
                                    countFromZero: true,
                                    textAlign: TextAlign.left,
                                    duration: Duration(
                                        milliseconds:
                                            (500 + streak.current * 25)
                                                .clamp(500, 1600)),
                                    style: displayStyle(66, height: 1),
                                    gradient: AppGradients.streakText,
                                    glow: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.ringDayStreak(streak.current).toUpperCase(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                        letterSpacing: 2.2,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                _StageBlock(
                                  streak: streak.current,
                                  stage: stage,
                                  next: next,
                                  toNext: toNext,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: <Widget>[
                                    _HeroChip(
                                      child: Text(
                                        l10n.ringDayOfTotal(
                                          dayNumber,
                                          challenge.lengthDays *
                                              (challenge.cycle + 1),
                                        ),
                                        style: _chipText(context),
                                      ),
                                    ),
                                    if (streak.longest > streak.current)
                                      _HeroChip(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            const Icon(Icons.emoji_events,
                                                size: 13,
                                                color: AppColors.reward),
                                            const SizedBox(width: 4),
                                            Text(
                                                l10n.heroBest(streak.longest),
                                                style: _chipText(context)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          StreakRing(
                            progress: challenge.progressInCycle(today),
                            dayInCycle: challenge.dayInCycle(today),
                            cycleLength: challenge.lengthDays,
                            stage: stage,
                            mood: mood,
                            atRisk: streak.atRisk && !frozen,
                            size: 176,
                            onPoke: _onPoke,
                            mascotLabel: l10n.mascotSemantics,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _StatusLine(
                        status: status,
                        streak: streak.current,
                        onTap: widget.onTapStatus,
                      ),
                      const SizedBox(height: 14),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The current form, the next one and the bar between them — opens the
/// whole ladder.
class _StageBlock extends StatelessWidget {
  const _StageBlock({
    required this.streak,
    required this.stage,
    required this.next,
    required this.toNext,
  });

  final int streak;
  final FlameStage stage;
  final FlameStage? next;
  final int? toNext;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showFlameEvolution(context, streak: streak),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: displayStyle(13, color: AppColors.textPrimary,
                      weight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textTertiary),
            ],
          ),
          if (next != null && toNext != null) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              l10n.stageNext(l10n.stageName(next!), toNext!),
              maxLines: 2,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primarySoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: AppRadius.pill,
              child: SizedBox(
                height: 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    const ColoredBox(color: AppColors.glassHigh),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: math.max(0.04, stageProgress(streak)),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(gradient: AppGradients.plasma),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 3),
            Text(
              l10n.stageFinal,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primarySoft,
                    fontSize: 12,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

TextStyle? _chipText(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        );

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: AppRadius.pill,
        border: Border.all(color: AppColors.glassEdge),
      ),
      child: child,
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
            AppColors.success);
      case HeroStatus.rest:
        return _line(
            context, Icons.bedtime, l10n.heroRestDay, AppColors.cool);
      case HeroStatus.frozen:
        return _line(context, Icons.ac_unit, l10n.heroFrozen, AppColors.cool);
      case HeroStatus.relapse:
        return _line(context, Icons.restart_alt, l10n.heroRelapse,
            AppColors.primarySoft);
      case HeroStatus.open:
        return DayCountdown(
          builder: (BuildContext context, Duration left) {
            final String time = formatCountdown(left);
            final bool late = left.inHours < 4;
            final Color accent = late ? AppColors.danger : AppColors.attention;
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
            color: Color.lerp(AppColors.surface, accent, 0.14),
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
