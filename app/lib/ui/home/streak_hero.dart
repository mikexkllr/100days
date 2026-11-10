import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../theme/fire.dart';
import '../../theme/theme.dart';
import '../mascot/flame_painter.dart';
import '../mascot/speech_bubble.dart';
import '../motion/rolling_number.dart';
import '../widgets/streak_ring.dart';
import 'flame_evolution_sheet.dart';
import 'today.dart';
import 'week_strip.dart';

/// Where the day stands, for the line under the streak.
enum HeroStatus { open, done, rest, frozen, relapse }

/// The top of the home screen, straight on the sky: the streak as a number,
/// Funki in the ring of today, the clock that is running on the day, this
/// week as a chain of lamps and the way to Funki's next form.
///
/// The number says whether the streak is safe without a word: it is hollow
/// while today is open, and it fills with fire once the day is done.
class StreakHero extends StatefulWidget {
  const StreakHero({
    super.key,
    required this.snapshot,
    this.onTapDay,
  });

  final AppSnapshot snapshot;

  /// A day of the week strip was tapped.
  final ValueChanged<DayKey>? onTapDay;

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
    final TodayState state = TodayState.of(snapshot);
    final Fire fire = state.fire;
    final DateTime now = DateTime.now();
    final Duration left =
        DateTime(now.year, now.month, now.day + 1).difference(now);

    final HeroStatus status = state.relapse
        ? HeroStatus.relapse
        : state.complete
            ? HeroStatus.done
            : state.frozen
                ? HeroStatus.frozen
                : state.rest
                    ? HeroStatus.rest
                    : HeroStatus.open;

    final MascotMood mood = moodForToday(
      doneToday: state.complete,
      restDay: state.rest,
      frozenToday: state.frozen,
      relapseToday: state.relapse,
      streak: streak.current,
      now: now,
    );
    final FlameStage stage = flameStageFor(streak.current);
    final String line = _pokeLine ??
        l10n.mascotLineFor(
          mood,
          day: challenge.dayNumber(today),
          streak: streak.current,
          hoursLeft: left.inHours,
        );
    final bool worried = status == HeroStatus.open && mood == MascotMood.worried;
    // Safe until tomorrow: done, held by a freeze, or nothing scheduled.
    final bool safe = streak.current > 0 && !(streak.atRisk && !state.frozen);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: SpeechBubble(
            key: const Key('mascot-bubble'),
            text: line,
            maxWidth: 310,
            accent: worried ? AppColors.hot : AppColors.primary,
            tailAt: 0.74,
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
                            (500 + streak.current * 25).clamp(500, 1600),
                      ),
                      style: displayStyle(76, height: 1),
                      gradient: safe ? fire.text : null,
                      glow: safe ? fire.main : null,
                      stroke: safe
                          ? null
                          : AppColors.textPrimary.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: l10n.ringDayStreak(streak.current).toUpperCase(),
                        ),
                        if (streak.longest > streak.current)
                          TextSpan(
                            text:
                                '  ·  ${l10n.heroBest(streak.longest).toUpperCase()}',
                            style:
                                const TextStyle(color: AppColors.textTertiary),
                          ),
                      ],
                    ),
                    style: labelStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  _StatusLine(status: status, streak: streak.current, fire: fire),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TodayRing(
              parts: state.parts,
              fire: fire,
              stage: stage,
              mood: mood,
              held: state.frozen && !state.complete,
              onPoke: _onPoke,
              mascotLabel: l10n.mascotSemantics,
            ),
          ],
        ),
        const SizedBox(height: 18),
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
          fire: fire,
          onTapDay: widget.onTapDay,
        ),
        const SizedBox(height: 14),
        _NextForm(streak: streak.current, fire: fire),
      ],
    );
  }
}

/// The current form, the next one and the bar between them — opens the
/// whole ladder.
class _NextForm extends StatelessWidget {
  const _NextForm({required this.streak, required this.fire});

  final int streak;
  final Fire fire;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final FlameStage stage = flameStageFor(streak);
    final FlameStage? next = stage.next;
    final int? toNext = daysToNextStage(streak);
    final TextStyle small = Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 12.5,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showFlameEvolution(context, streak: streak),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
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
                const SizedBox(width: 6),
                Text(
                  l10n.stageName(stage),
                  style: small.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    next != null && toNext != null
                        ? l10n.stageNext(l10n.stageName(next), toNext)
                        : l10n.stageFinal,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: small,
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textTertiary),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: AppRadius.pill,
              child: SizedBox(
                height: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    const ColoredBox(color: AppColors.glassHigh),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: math.max(0.02, stageProgress(streak)),
                      child: DecoratedBox(
                        decoration: BoxDecoration(gradient: fire.sweep),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    required this.fire,
  });

  final HeroStatus status;
  final int streak;
  final Fire fire;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    switch (status) {
      case HeroStatus.done:
        return _line(context, Icons.check_circle, l10n.heroFedToday, fire.light);
      case HeroStatus.rest:
        return _line(context, Icons.bedtime, l10n.heroRestDay, AppColors.cool);
      case HeroStatus.frozen:
        return _line(context, Icons.ac_unit, l10n.heroFrozen, AppColors.cool);
      case HeroStatus.relapse:
        return _line(context, Icons.restart_alt, l10n.heroRelapse,
            AppColors.textSecondary);
      case HeroStatus.open:
        return DayCountdown(
          builder: (BuildContext context, Duration left) {
            final String time = formatCountdown(left);
            final bool late = left.inHours < 4;
            final Color accent = late ? AppColors.danger : AppColors.textPrimary;
            final String text = streak > 0
                ? l10n.heroCountdownSave(time)
                : l10n.heroCountdownFirst(time);
            final int at = text.indexOf(time);
            return _line(
              context,
              Icons.hourglass_bottom_rounded,
              text,
              late ? AppColors.danger : AppColors.textSecondary,
              emphasis: at < 0 ? null : time,
              emphasisColor: accent,
            );
          },
        );
    }
  }

  Widget _line(
    BuildContext context,
    IconData icon,
    String text,
    Color accent, {
    String? emphasis,
    Color? emphasisColor,
  }) {
    final TextStyle base = Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 13,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        );
    final int at = emphasis == null ? -1 : text.indexOf(emphasis);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            at < 0
                ? TextSpan(text: text)
                : TextSpan(
                    children: <TextSpan>[
                      TextSpan(text: text.substring(0, at)),
                      TextSpan(
                        text: emphasis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: emphasisColor,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      TextSpan(text: text.substring(at + emphasis!.length)),
                    ],
                  ),
            style: base,
          ),
        ),
      ],
    );
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
