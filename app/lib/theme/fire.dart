import 'package:flutter/painting.dart';
import 'package:hundred_core/hundred_core.dart';

/// The colour of the streak.
///
/// The chrome of the app has no colour of its own; whatever is lit — the
/// streak number, the ring around Funki, a habit that is done, the lamps of
/// the week, the aurora — burns in the colour of the flame's current form.
/// So the app looks different on day 3, day 30 and day 100: pink, violet,
/// blue, cyan, white-hot. Breaking the streak takes the colour back with the
/// form.
class Fire {
  const Fire({
    required this.light,
    required this.main,
    required this.deep,
    this.far,
  });

  /// The bright end: text on the night, the top of a gradient.
  final Color light;

  /// The colour itself: fills, rings, lamps.
  final Color main;

  /// The dark end: the root of the flame, the far side of the aurora.
  final Color deep;

  /// A third colour for the top form, which burns in more than one.
  final Color? far;

  /// What sits on a lit fill.
  Color get on => const Color(0xFF07080D);

  /// A lit fill, corner to corner.
  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[light, main, if (far != null) far!],
      );

  /// A lit bar, left to right.
  LinearGradient get sweep => LinearGradient(
        colors: <Color>[main, light, if (far != null) far!],
      );

  /// Lit type: bright at the top, the colour itself at the foot.
  LinearGradient get text => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFFFFFFFF),
          light,
          main,
          if (far != null) far!,
        ],
        stops: far == null
            ? const <double>[0, 0.35, 1]
            : const <double>[0, 0.3, 0.7, 1],
      );

  static Fire of(FlameStage stage) => switch (stage) {
        FlameStage.ember || FlameStage.spark => const Fire(
            light: Color(0xFFFFA3BC),
            main: Color(0xFFFF5C8A),
            deep: Color(0xFFB3184A),
          ),
        FlameStage.flicker => const Fire(
            light: Color(0xFFFF9CCB),
            main: Color(0xFFFF4FA3),
            deep: Color(0xFFB01668),
          ),
        FlameStage.flame => const Fire(
            light: Color(0xFFF6A8FF),
            main: Color(0xFFE25CFF),
            deep: Color(0xFF8E1FB0),
          ),
        FlameStage.blaze => const Fire(
            light: Color(0xFFDCBCFF),
            main: Color(0xFFB57BFF),
            deep: Color(0xFF6A2BD1),
          ),
        FlameStage.inferno => const Fire(
            light: Color(0xFFC8BDFF),
            main: Color(0xFF8F7CFF),
            deep: Color(0xFF4A2FD6),
          ),
        FlameStage.blue => const Fire(
            light: Color(0xFFAACDFF),
            main: Color(0xFF5B9BFF),
            deep: Color(0xFF1D4ED8),
          ),
        FlameStage.plasma => const Fire(
            light: Color(0xFFA8F3FC),
            main: Color(0xFF3FD9F2),
            deep: Color(0xFF0E7490),
          ),
        FlameStage.nova => const Fire(
            light: Color(0xFFFFFFFF),
            main: Color(0xFFCBD5FF),
            deep: Color(0xFF818CF8),
          ),
        FlameStage.galaxy => const Fire(
            light: Color(0xFFF9A8D4),
            main: Color(0xFFB4A7FF),
            deep: Color(0xFF6D28D9),
            far: Color(0xFF7DE3F4),
          ),
      };

  /// The fire of a streak of [streak] days.
  static Fire ofStreak(int streak) => of(flameStageFor(streak));
}
