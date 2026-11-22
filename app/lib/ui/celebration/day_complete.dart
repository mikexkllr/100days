import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/fire.dart';
import '../../theme/theme.dart';
import '../mascot/flame_mascot.dart';
import '../mascot/flame_painter.dart';
import '../mascot/speech_bubble.dart';
import '../motion/motion.dart';
import '../motion/particles.dart';
import '../motion/rolling_number.dart';
import '../widgets/juicy_button.dart';
import 'share_card.dart';

/// Rolls the slot machine whenever [celebrationProvider] hands it a day just
/// completed — on Today, in the workout logger or in the food diary. Sits
/// around the app shell, which stays mounted under every pushed screen.
class CelebrationHost extends ConsumerWidget {
  const CelebrationHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<DayCelebration?>(celebrationProvider,
        (DayCelebration? _, DayCelebration? next) {
      if (next == null) return;
      ref.read(celebrationProvider.notifier).state = null;
      unawaited(_celebrate(context, next));
    });
    return child;
  }

  static Future<void> _celebrate(
    BuildContext context,
    DayCelebration celebration,
  ) async {
    // Let the check-in's own burst (or the logger closing) land first.
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!context.mounted) return;
    await showDayCompleteCelebration(
      context,
      reward: celebration.reward,
      challenge: celebration.challenge,
      lifetimeXp: celebration.lifetimeXp,
    );
  }
}

/// The day is done: spin the machine.
///
/// Three reels — the streak, the XP the day scored, and the loudest bonus it
/// earned — spin up and land one after the other, with a click for every
/// symbol that passes and a thud for every reel that stops. What they land
/// on is never random: it is today's real numbers. What varies is the size
/// of the moment, because real milestones, level-ups, new forms and records
/// do not come every day. When one does, the machine pays out.
Future<void> showDayCompleteCelebration(
  BuildContext context, {
  required DayReward reward,
  required Challenge challenge,
  required int lifetimeXp,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder:
          (BuildContext context, Animation<double> _, Animation<double> __) =>
              DayCompleteCelebration(
                reward: reward,
                challenge: challenge,
                lifetimeXp: lifetimeXp,
              ),
      transitionsBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> _,
            Widget child,
          ) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.12, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          ),
    ),
  );
}

class DayCompleteCelebration extends StatefulWidget {
  const DayCompleteCelebration({
    super.key,
    required this.reward,
    required this.challenge,
    required this.lifetimeXp,
  });

  final DayReward reward;
  final Challenge challenge;
  final int lifetimeXp;

  @override
  State<DayCompleteCelebration> createState() => _DayCompleteCelebrationState();
}

class _DayCompleteCelebrationState extends State<DayCompleteCelebration>
    with TickerProviderStateMixin {
  /// A day like the others spins briefly; a jackpot takes its time, so the
  /// rare moment feels bigger than the daily one.
  static const Duration _spinOrdinary = Duration(milliseconds: 1900);
  static const Duration _spinJackpot = Duration(milliseconds: 3400);

  /// Before the reels, a new form of the flame gets its own moment: the old
  /// form shakes, charges, flashes white — and the new one stands there.
  late final AnimationController _evolve = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  bool get _evolves =>
      widget.reward.highlights.contains(RewardHighlight.evolution) &&
      widget.reward.stageBefore != widget.reward.stage;

  /// When each reel stops, as a fraction of the whole spin.
  static const List<double> _stops = <double>[0.52, 0.74, 1];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.reward.isJackpot ? _spinJackpot : _spinOrdinary,
  );
  final List<int> _lastIndex = <int>[-1, -1, -1];
  final List<bool> _landed = <bool>[false, false, false];
  DateTime _lastClick = DateTime.fromMillisecondsSinceEpoch(0);
  int _payout = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (ambientMotionOf(context)) {
      HapticFeedback.mediumImpact();
      if (_evolves) {
        _evolve.addListener(_onEvolveTick);
        _evolve.forward().whenComplete(() {
          if (mounted) _controller.forward();
        });
      } else {
        _controller.forward();
      }
    } else {
      _evolve.value = 1;
      // Asked for less motion: the result, without the show.
      _controller.value = 1;
      for (int i = 0; i < 3; i++) {
        _landed[i] = true;
      }
      if (widget.reward.isJackpot) _payout = 1;
    }
  }

  double _reelT(int reel) => (_controller.value / _stops[reel]).clamp(0.0, 1.0);

  void _onTick() {
    final DateTime now = DateTime.now();
    for (int i = 0; i < 3; i++) {
      final double t = _reelT(i);
      final int index = (_reelPosition(t) * _symbolsOn(i)).floor();
      if (index != _lastIndex[i]) {
        _lastIndex[i] = index;
        if (!_landed[i] && now.difference(_lastClick).inMilliseconds > 45) {
          _lastClick = now;
          HapticFeedback.selectionClick();
        }
      }
      if (t >= 1 && !_landed[i]) {
        _landed[i] = true;
        HapticFeedback.heavyImpact();
        if (i == 2) _onAllLanded();
        setState(() {});
      }
    }
  }

  Future<void> _onAllLanded() async {
    if (!widget.reward.isJackpot) return;
    setState(() => _payout++);
    // Three hard knocks: the payout.
    for (int i = 0; i < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 140));
      HapticFeedback.heavyImpact();
    }
  }

  bool _flashed = false;

  void _onEvolveTick() {
    // The charge rattles in the hand; the change lands with a knock.
    if (_evolve.value < 0.55 && (_evolve.value * 40).floor().isEven) {
      HapticFeedback.selectionClick();
    }
    if (!_flashed && _evolve.value >= 0.55) {
      _flashed = true;
      HapticFeedback.heavyImpact();
    }
  }

  void _skip() {
    if (_evolve.isAnimating) {
      _evolve.value = 1;
      _controller.value = 1;
      return;
    }
    if (_controller.isAnimating) _controller.value = 1;
  }

  @override
  void dispose() {
    _evolve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final DayReward reward = widget.reward;
    final bool jackpot = reward.isJackpot;
    final bool done = _landed[2];
    // The night takes the colour of the form the streak just reached.
    final Color accent = Fire.of(reward.stage).main;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.35),
                    radius: 1.1,
                    colors: <Color>[
                      Color.lerp(AppColors.ink, accent, 0.28)!,
                      AppColors.ink,
                      AppColors.inkDeep,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: _Sunburst(color: accent, strong: done && jackpot),
            ),
            const Positioned.fill(
              child: EmberField(count: 30, intensity: 1.4, speed: 1.6),
            ),
            Positioned.fill(
              child: ParticleBurst(
                trigger: null,
                burstOnMount: ambientMotionOf(context),
                origin: const Alignment(0, -0.3),
                count: 70,
                kinds: const <ParticleKind>[
                  ParticleKind.confetti,
                  ParticleKind.spark,
                  ParticleKind.star,
                ],
                colors: kPartyParticles,
                power: 1.1,
              ),
            ),
            Positioned.fill(
              child: ParticleBurst(
                trigger: _payout == 0 ? null : _payout,
                origin: const Alignment(0, -0.05),
                count: 90,
                kinds: const <ParticleKind>[
                  ParticleKind.gem,
                  ParticleKind.star,
                  ParticleKind.confetti,
                ],
                colors: kHoloParticles,
                power: 1.5,
                gravity: 1100,
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _Title(
                        text: done && jackpot
                            ? l10n.celebrateJackpot
                            : l10n.celebrateTitle,
                        gold: done && jackpot,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SpeechBubble(
                        text: l10n.mascotLineFor(
                          MascotMood.hyped,
                          day: reward.dayNumber,
                          streak: reward.streak,
                          hoursLeft: 1,
                        ),
                        accent: accent,
                      ),
                      AnimatedBuilder(
                        animation: _evolve,
                        builder: (BuildContext context, Widget? _) =>
                            _EvolvingFunki(
                          from: reward.stageBefore,
                          to: reward.stage,
                          t: _evolves ? _evolve.value : 1,
                        ),
                      ),
                      _SlotMachine(
                        controller: _controller,
                        reelT: _reelT,
                        landed: _landed,
                        reward: reward,
                        jackpot: jackpot,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AnimatedOpacity(
                        opacity: done ? 1 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          children: <Widget>[
                            _Highlights(
                              reward: reward,
                              cycleLength: widget.challenge.lengthDays,
                              visible: done,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _NextUp(
                              reward: reward,
                              challenge: widget.challenge,
                              lifetimeXp: widget.lifetimeXp,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (done) ...<Widget>[
                        JuicyButton.holo(
                          key: const Key('celebration-continue'),
                          label: l10n.celebrateContinue,
                          icon: Icons.local_fire_department,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Builder(
                          builder: (BuildContext context) => TextButton.icon(
                            key: const Key('celebration-share'),
                            onPressed: () => shareStreak(
                              context,
                              stage: reward.stage,
                              streak: reward.streak,
                              dayNumber: reward.dayNumber,
                              text: l10n.celebrateShareText(
                                reward.streak,
                                reward.dayNumber,
                              ),
                            ),
                            icon: const Icon(Icons.ios_share, size: 18),
                            label: Text(l10n.celebrateShare),
                          ),
                        ),
                      ] else
                        Text(
                          l10n.celebrateSkip,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.textTertiary),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Symbols that pass the window before a reel lands; later reels run longer.
int _symbolsOn(int reel) => 18 + reel * 7;

/// How far along its strip a reel is: flat out at first, braking into the
/// stop, and a small kick past it and back as it catches.
double _reelPosition(double t) {
  final double clamped = t.clamp(0.0, 1.0);
  final double run = Curves.easeOutCubic.transform(clamped);
  final double kick = clamped > 0.86
      ? math.sin((clamped - 0.86) / 0.14 * math.pi) * 0.014
      : 0;
  return run + kick;
}

class _Title extends StatelessWidget {
  const _Title({required this.text, required this.gold});

  final String text;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return TriggeredAnimation(
      trigger: text,
      playOnFirstBuild: true,
      duration: const Duration(milliseconds: 900),
      builder: (BuildContext context, double t, Widget? _) => Transform.scale(
        scale: 0.4 + 0.6 * popCurve(t),
        child: Transform.rotate(
          angle: (1 - popCurve(t)) * -0.08,
          child: GlowText(
            text,
            style: displayStyle(gold ? 40 : 34),
            gradient: gold ? AppGradients.holo : AppGradients.streakText,
            glow: gold ? AppColors.reward : AppColors.attention,
          ),
        ),
      ),
    );
  }
}

/// Light rays turning behind everything — the look of a win.
class _Sunburst extends StatelessWidget {
  const _Sunburst({required this.color, required this.strong});

  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AmbientClock(
        builder: (BuildContext context, double seconds, Widget? _) =>
            CustomPaint(
              painter: _SunburstPainter(
                seconds: seconds,
                color: color,
                strength: strong ? 0.32 : 0.16,
              ),
            ),
      ),
    );
  }
}

class _SunburstPainter extends CustomPainter {
  _SunburstPainter({
    required this.seconds,
    required this.color,
    required this.strength,
  });

  final double seconds;
  final Color color;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.32);
    final double radius = size.longestSide;
    const int rays = 16;
    // A win throws rays of every colour; an ordinary day, its own.
    final List<Color> colors = strength > 0.2
        ? const <Color>[Color(0xFFA78BFA), Color(0xFF67E8F9), Color(0xFFF9A8D4)]
        : <Color>[color];
    for (int i = 0; i < rays; i++) {
      final Color c = colors[i % colors.length];
      final double a = seconds * 0.25 + i * math.pi * 2 / rays;
      const double half = math.pi / rays * 0.45;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(center.dx + math.cos(a - half) * radius,
              center.dy + math.sin(a - half) * radius)
          ..lineTo(center.dx + math.cos(a + half) * radius,
              center.dy + math.sin(a + half) * radius)
          ..close(),
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              c.withValues(alpha: strength),
              c.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 0.8)),
      );
    }
  }

  @override
  bool shouldRepaint(_SunburstPainter oldDelegate) =>
      oldDelegate.seconds != seconds ||
      oldDelegate.color != color ||
      oldDelegate.strength != strength;
}

class _SlotMachine extends StatelessWidget {
  const _SlotMachine({
    required this.controller,
    required this.reelT,
    required this.landed,
    required this.reward,
    required this.jackpot,
  });

  final AnimationController controller;
  final double Function(int reel) reelT;
  final List<bool> landed;
  final DayReward reward;
  final bool jackpot;

  static const List<String> _symbols = <String>[
    '🔥',
    '⭐',
    '💎',
    '⚡',
    '🏆',
    '👑',
    '💯',
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        gradient: AppGradients.holo,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppShadows.glow(
          AppColors.reward,
          strength: jackpot && landed[2] ? 1.4 : 0.8,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        decoration: BoxDecoration(
          color: AppColors.inkDeep,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Bulbs(lit: landed[2], jackpot: jackpot),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double reel = math.min(
                  _Reel.maxWidth,
                  (constraints.maxWidth - 16) / 3,
                );
                return AnimatedBuilder(
                  animation: controller,
                  builder: (BuildContext context, Widget? _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _Reel(
                        label: l10n.celebrateReelStreak,
                        width: reel,
                        count: _symbolsOn(0),
                        t: reelT(0),
                        landed: landed[0],
                        symbols: _symbols,
                        seed: 1,
                        result: GlowText(
                          '${reward.streak}',
                          style: displayStyle(38),
                          gradient: Fire.of(reward.stage).text,
                          glow: Fire.of(reward.stage).main,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Reel(
                        label: l10n.celebrateReelXp,
                        width: reel,
                        count: _symbolsOn(1),
                        t: reelT(1),
                        landed: landed[1],
                        symbols: _symbols,
                        seed: 4,
                        result: GlowText(
                          '+${reward.xpToday}',
                          style: displayStyle(32),
                          gradient: AppGradients.holo,
                          glow: AppColors.reward,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Reel(
                        label: l10n.celebrateReelBonus,
                        width: reel,
                        count: _symbolsOn(2),
                        t: reelT(2),
                        landed: landed[2],
                        symbols: _symbols,
                        seed: 2,
                        highlight: jackpot,
                        result: _BonusFace(reward: reward),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _Bulbs(lit: landed[2], jackpot: jackpot, offset: 1),
          ],
        ),
      ),
    );
  }
}

class _BonusFace extends StatelessWidget {
  const _BonusFace({required this.reward});

  final DayReward reward;

  @override
  Widget build(BuildContext context) {
    final RewardHighlight top = reward.top;
    final Widget icon = top == RewardHighlight.evolution
        ? CustomPaint(
            size: const Size.square(34),
            painter: FlamePainter(
              stage: reward.stage,
              mood: MascotMood.hyped,
              seconds: 1.2,
              blink: false,
            ),
          )
        : Text(switch (top) {
            RewardHighlight.cycleComplete => '👑',
            RewardHighlight.milestone => '🏆',
            RewardHighlight.record => '🥇',
            RewardHighlight.levelUp => '⭐',
            _ => '💯',
          }, style: const TextStyle(fontSize: 28));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        icon,
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            context.l10n.rewardBonusLabel(top),
            style: displayStyle(
              12,
              color: reward.isJackpot ? AppColors.reward : AppColors.success,
            ),
          ),
        ),
      ],
    );
  }
}

/// One reel: a window onto a strip of symbols that ends in [result].
class _Reel extends StatelessWidget {
  const _Reel({
    required this.label,
    required this.width,
    required this.count,
    required this.t,
    required this.landed,
    required this.symbols,
    required this.seed,
    required this.result,
    this.highlight = false,
  });

  final String label;
  final double width;

  /// Symbols before the result.
  final int count;
  final double t;
  final bool landed;
  final List<String> symbols;
  final int seed;
  final Widget result;
  final bool highlight;

  static const double _item = 78;
  static const double maxWidth = 96;

  @override
  Widget build(BuildContext context) {
    final int n = count;
    final double position = _reelPosition(t) * n;
    // How fast the strip moves right now, for the blur.
    final double speed =
        ((_reelPosition(math.min(1, t + 0.02)) - _reelPosition(t)) / 0.02)
            .abs();
    final double blur = landed ? 0 : (speed * 2.2).clamp(0.0, 6.0);

    Widget symbol(int i) => SizedBox(
      height: _item,
      child: Center(
        child: Text(
          symbols[(i * 3 + seed) % symbols.length],
          style: const TextStyle(fontSize: 34),
        ),
      ),
    );
    final List<Widget> strip = <Widget>[
      for (int i = 0; i < n; i++) symbol(i),
      SizedBox(
        height: _item,
        child: Center(child: result),
      ),
      // Past the result, so the kick at the stop never shows an empty slot.
      symbol(n),
      symbol(n + 1),
    ];

    final Widget window = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        height: _item,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF110C2B),
              Color(0xFF221A4D),
              Color(0xFF110C2B),
            ],
          ),
          border: Border.all(
            color: landed && highlight ? AppColors.reward : AppColors.outline,
            width: landed && highlight ? 2 : 1,
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              top: -position * _item,
              child: blur < 0.1
                  ? Column(children: strip)
                  : ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 0, sigmaY: blur),
                      child: Column(children: strip),
                    ),
            ),
            // Glass: darker at the edges, the way a real reel curves away.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                    stops: const <double>[0, 0.28, 0.72, 1],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: width,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: landed ? AppColors.textPrimary : AppColors.textTertiary,
                fontSize: 10.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        TriggeredAnimation(
          trigger: landed,
          duration: const Duration(milliseconds: 420),
          child: window,
          builder: (BuildContext context, double p, Widget? window) =>
              Transform.scale(
                scale: landed ? bounceScale(p) : 1,
                child: window,
              ),
        ),
      ],
    );
  }
}

/// Marquee lights along the frame, chasing while the reels spin.
class _Bulbs extends StatelessWidget {
  const _Bulbs({required this.lit, required this.jackpot, this.offset = 0});

  final bool lit;
  final bool jackpot;
  final int offset;

  @override
  Widget build(BuildContext context) {
    return AmbientClock(
      builder: (BuildContext context, double seconds, Widget? _) {
        final int step = (seconds * (lit && jackpot ? 12 : 7)).floor();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < 13; i++)
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.symmetric(horizontal: 5.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      (i + step + offset) % 3 == 0 || !ambientMotionOf(context)
                      ? (jackpot && lit ? AppColors.reward : AppColors.glow)
                      : AppColors.outline,
                  boxShadow: (i + step + offset) % 3 == 0
                      ? AppShadows.glow(AppColors.reward, strength: 0.9)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Every reason today was worth it, loudest first.
class _Highlights extends StatelessWidget {
  const _Highlights({
    required this.reward,
    required this.cycleLength,
    required this.visible,
  });

  final DayReward reward;
  final int cycleLength;
  final bool visible;

  static IconData _icon(RewardHighlight h) => switch (h) {
    RewardHighlight.cycleComplete => Icons.workspace_premium,
    RewardHighlight.milestone => Icons.emoji_events,
    RewardHighlight.evolution => Icons.local_fire_department,
    RewardHighlight.record => Icons.trending_up,
    RewardHighlight.levelUp => Icons.keyboard_double_arrow_up,
    RewardHighlight.perfectDay => Icons.verified,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (int i = 0; i < reward.highlights.length; i++)
          TriggeredAnimation(
            trigger: visible,
            duration: Duration(milliseconds: 500 + i * 160),
            builder: (BuildContext context, double t, Widget? child) {
              final double local = ((t * (500 + i * 160) - i * 160) / 500)
                  .clamp(0.0, 1.0);
              return Opacity(
                opacity: visible ? local : 0,
                child: Transform.scale(
                  scale: 0.5 + 0.5 * popCurve(local),
                  child: child,
                ),
              );
            },
            child: _HighlightChip(
              icon: _icon(reward.highlights[i]),
              text: l10n.rewardHighlightText(
                reward.highlights[i],
                reward,
                cycleLength: cycleLength,
              ),
              gold: reward.highlights[i] != RewardHighlight.perfectDay,
            ),
          ),
      ],
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({
    required this.icon,
    required this.text,
    required this.gold,
  });

  final IconData icon;
  final String text;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final Color color = gold ? AppColors.reward : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pill,
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
        boxShadow: gold ? AppShadows.glow(color, strength: 0.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What tomorrow and the days after can still pay out — every row a real
/// threshold, counted from where you stand.
class _NextUp extends StatelessWidget {
  const _NextUp({
    required this.reward,
    required this.challenge,
    required this.lifetimeXp,
  });

  final DayReward reward;
  final Challenge challenge;
  final int lifetimeXp;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final FlameStage? nextStage = reward.stage.next;
    final int? toStage = daysToNextStage(reward.streak);
    final int? milestone = challenge.nextMilestone(reward.dayNumber);
    final int nextLevel = reward.level + 1;
    final int toLevel = xpRequiredForLevel(nextLevel) - lifetimeXp;

    final List<Widget> rows = <Widget>[
      if (nextStage != null && toStage != null)
        _row(
          context,
          CustomPaint(
            size: const Size.square(24),
            painter: FlamePainter(
              stage: nextStage,
              mood: MascotMood.happy,
              seconds: 1.2,
              blink: false,
            ),
          ),
          l10n.stageNext(l10n.stageName(nextStage), toStage),
        ),
      if (milestone != null)
        _row(
          context,
          const Icon(Icons.flag, size: 20, color: AppColors.primarySoft),
          l10n.celebrateNextMilestone(milestone, milestone - reward.dayNumber),
        ),
      _row(
        context,
        const Icon(Icons.star, size: 20, color: AppColors.reward),
        l10n.celebrateNextLevel(nextLevel, math.max(1, toLevel)),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.celebrateNextUp.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Widget leading, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(width: 28, child: Center(child: leading)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
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
}

/// Funki through an evolution: the old form shakes and charges up to the
/// flash at [t] = 0.55, then the new form pops in and its name lands.
class _EvolvingFunki extends StatelessWidget {
  const _EvolvingFunki({required this.from, required this.to, required this.t});

  final FlameStage from;
  final FlameStage to;
  final double t;

  @override
  Widget build(BuildContext context) {
    const double flash = 0.55;
    final bool before = t < flash;
    final double charge = before ? t / flash : 0;
    final double after = before ? 0 : ((t - flash) / (1 - flash)).clamp(0, 1);
    final double shake = before ? math.sin(t * 90) * 7 * charge : 0;
    final double scale = before
        ? 1 + 0.12 * charge
        : 0.6 + 0.4 * popCurve(after);
    final double white = before
        ? math.pow(charge, 3).toDouble() * 0.9
        : (1 - after * 3).clamp(0.0, 1.0);
    return SizedBox(
      width: 200,
      height: 196,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Transform.translate(
            offset: Offset(shake, 0),
            child: Transform.scale(
              scale: scale,
              child: FlameMascot(
                stage: before ? from : to,
                mood: MascotMood.hyped,
                size: 170,
              ),
            ),
          ),
          if (white > 0.01)
            IgnorePointer(
              child: Container(
                width: 200,
                height: 196,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      Colors.white.withValues(alpha: white),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          if (!before && after > 0 && t < 1)
            Positioned(
              bottom: 0,
              child: Opacity(
                opacity: (1 - (after - 0.6).clamp(0.0, 0.4) / 0.4),
                child: GlowText(
                  context.l10n.celebrateEvolved(context.l10n.stageName(to)),
                  style: displayStyle(22),
                  gradient: Fire.of(to).text,
                  glow: Fire.of(to).main,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Day 100 done and the step up taken: the next tier, with the show it
/// deserves. [onAscend] writes the ascent when the user goes on.
Future<void> showAscendCelebration(
  BuildContext context, {
  required String tierName,
  required String tierEmoji,
  required FlameStage stage,
  required Future<void> Function() onAscend,
}) =>
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (BuildContext context, Animation<double> _,
                Animation<double> __) =>
            _AscendCelebration(
          tierName: tierName,
          tierEmoji: tierEmoji,
          stage: stage,
          onAscend: onAscend,
        ),
        transitionsBuilder: (BuildContext context, Animation<double> animation,
                Animation<double> _, Widget child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

class _AscendCelebration extends StatefulWidget {
  const _AscendCelebration({
    required this.tierName,
    required this.tierEmoji,
    required this.stage,
    required this.onAscend,
  });

  final String tierName;
  final String tierEmoji;
  final FlameStage stage;
  final Future<void> Function() onAscend;

  @override
  State<_AscendCelebration> createState() => _AscendCelebrationState();
}

class _AscendCelebrationState extends State<_AscendCelebration> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  Future<void> _go() async {
    setState(() => _busy = true);
    HapticFeedback.heavyImpact();
    await widget.onAscend();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Color accent = Fire.of(widget.stage).main;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 1.1,
                  colors: <Color>[
                    Color.lerp(AppColors.ink, accent, 0.35)!,
                    AppColors.ink,
                    AppColors.inkDeep,
                  ],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: _Sunburst(color: AppColors.reward, strong: true)),
          const Positioned.fill(
            child: EmberField(count: 40, intensity: 1.6, speed: 1.8),
          ),
          Positioned.fill(
            child: ParticleBurst(
              trigger: null,
              burstOnMount: ambientMotionOf(context),
              origin: const Alignment(0, -0.25),
              count: 120,
              kinds: const <ParticleKind>[
                ParticleKind.gem,
                ParticleKind.star,
                ParticleKind.confetti,
              ],
              colors: kHoloParticles,
              power: 1.6,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _Title(text: l10n.ascendTitle.toUpperCase(), gold: true),
                    const SizedBox(height: AppSpacing.md),
                    FlameMascot(
                      stage: widget.stage,
                      mood: MascotMood.hyped,
                      size: 190,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(widget.tierEmoji,
                        style: const TextStyle(fontSize: 48)),
                    const SizedBox(height: AppSpacing.sm),
                    GlowText(
                      l10n.ascendNext(widget.tierName),
                      style: displayStyle(24),
                      gradient: AppGradients.holo,
                      glow: AppColors.reward,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.ascendBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    JuicyButton.holo(
                      key: const Key('ascend-go'),
                      label: l10n.ascendGo,
                      icon: Icons.keyboard_double_arrow_up,
                      onPressed: _busy ? null : _go,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
