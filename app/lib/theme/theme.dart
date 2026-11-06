import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The palette. A night sky with a fire in it.
///
/// Dark by default and unapologetically so: this app is opened at 6am and at
/// 11pm, both dark-room moments — and a flame only glows against the dark.
/// The base is a deep purple-black rather than grey, because orange and gold
/// are at their loudest next to violet.
class AppColors {
  static const Color ink = Color(0xFF0C0912);
  static const Color inkDeep = Color(0xFF07050B);
  static const Color surface = Color(0xFF171222);
  static const Color surfaceHigh = Color(0xFF221B31);
  static const Color outline = Color(0xFF342A49);

  /// Streak fire. The one colour that means "you did it".
  static const Color flame = Color(0xFFFF6B2C);
  static const Color flameSoft = Color(0xFFFFA574);

  /// The red-pink at the root of the fire.
  static const Color flameHot = Color(0xFFFF2E63);

  /// The amber and the yellow core.
  static const Color amber = Color(0xFFFFB830);
  static const Color spark = Color(0xFFFFE66D);

  /// Rewards: XP, levels, jackpots.
  static const Color gold = Color(0xFFFFD23F);

  /// Progress and success.
  static const Color lime = Color(0xFFB8F14B);

  /// Social pressure: someone else moved.
  static const Color violet = Color(0xFF8B7BFF);

  /// Freezes and rest days: the streak is held, not fed.
  static const Color ice = Color(0xFF5CC8FF);

  /// Danger: streak at risk, relapse.
  static const Color danger = Color(0xFFFF4D5E);

  static const Color textPrimary = Color(0xFFFFF7F0);
  static const Color textSecondary = Color(0xFFB3A8C7);
  static const Color textTertiary = Color(0xFF6E6487);

  static const List<Color> heat = <Color>[
    Color(0xFF1F1830),
    Color(0xFF4A2338),
    Color(0xFF8C3332),
    Color(0xFFD9522A),
    Color(0xFFFF8A2C),
  ];
}

class AppGradients {
  static const LinearGradient fire = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: <Color>[AppColors.flameHot, AppColors.flame, AppColors.amber],
  );

  /// Text that has to look like it is burning.
  static const LinearGradient fireText = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: <Color>[
      AppColors.flameHot,
      AppColors.flame,
      AppColors.amber,
      AppColors.spark,
    ],
    stops: <double>[0, 0.35, 0.7, 1],
  );

  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFFF0A8), AppColors.gold, Color(0xFFFF9F1C)],
  );

  static const LinearGradient success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFD7FF7A), AppColors.lime, Color(0xFF6FCF3B)],
  );

  static const LinearGradient ice = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFB8ECFF), AppColors.ice, Color(0xFF2E8BFF)],
  );

  static const LinearGradient danger = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFF8A80), AppColors.danger, Color(0xFFC2185B)],
  );

  /// Card fill: lit from the top left, like everything near a fire.
  static LinearGradient card([Color tint = AppColors.surfaceHigh]) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color.lerp(AppColors.surface, tint, 0.55)!,
          AppColors.surface,
        ],
      );
}

class AppShadows {
  /// A coloured glow, for anything that should feel lit.
  static List<BoxShadow> glow(Color color, {double strength = 1}) =>
      <BoxShadow>[
        BoxShadow(
          color: color.withValues(alpha: (0.45 * strength).clamp(0.0, 1.0)),
          blurRadius: 22,
          spreadRadius: -6,
        ),
        BoxShadow(
          color: color.withValues(alpha: (0.22 * strength).clamp(0.0, 1.0)),
          blurRadius: 44,
          spreadRadius: -2,
        ),
      ];
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  static const Radius card = Radius.circular(22);
  static const BorderRadius cardAll = BorderRadius.all(card);
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// The display face: chunky, round, a little like a game. Only for numbers,
/// headlines and buttons — body text stays in the system font.
const String kDisplayFont = 'LilitaOne';

/// The display face at [size]. It ships one weight, so any heavier request
/// would be faked by the renderer; this keeps it at the real one.
TextStyle displayStyle(double size, {Color? color, double? height}) =>
    TextStyle(
      fontFamily: kDisplayFont,
      fontSize: size,
      fontWeight: FontWeight.w400,
      height: height ?? 1.05,
      letterSpacing: size >= 40 ? -0.5 : 0.2,
      color: color,
    );

ThemeData buildAppTheme() {
  const ColorScheme scheme = ColorScheme.dark(
    primary: AppColors.flame,
    onPrimary: Color(0xFF1A0A02),
    secondary: AppColors.lime,
    onSecondary: Color(0xFF12200A),
    tertiary: AppColors.gold,
    onTertiary: Color(0xFF2A1C00),
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.danger,
    onError: Colors.white,
    outline: AppColors.outline,
  );

  final TextTheme text = TextTheme(
    displayLarge: displayStyle(72, height: 1),
    displayMedium: displayStyle(44),
    headlineMedium: displayStyle(27, height: 1.12),
    titleLarge: displayStyle(20, height: 1.15),
    titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    bodyLarge: const TextStyle(fontSize: 16, height: 1.45),
    bodyMedium: const TextStyle(fontSize: 14.5, height: 1.45),
    labelLarge: displayStyle(16.5).copyWith(letterSpacing: 0.5),
    labelSmall: const TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.9,
    ),
  ).apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ink,
    canvasColor: AppColors.ink,
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: displayStyle(23, color: AppColors.textPrimary),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.outline,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
        textStyle: text.labelLarge,
        elevation: 6,
        shadowColor: AppColors.flame.withValues(alpha: 0.6),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.outline, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.flameSoft,
        textStyle: text.labelLarge?.copyWith(fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      hintStyle: const TextStyle(color: AppColors.textTertiary),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.flame, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.inkDeep,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.flame.withValues(alpha: 0.2),
      height: 70,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
        (Set<WidgetState> states) => text.labelSmall!.copyWith(
          color: states.contains(WidgetState.selected)
              ? AppColors.flameSoft
              : AppColors.textTertiary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
        (Set<WidgetState> states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.flame
              : AppColors.textSecondary,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceHigh,
      side: const BorderSide(color: AppColors.outline),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
      labelStyle: text.bodyMedium!,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.flame,
      linearTrackColor: AppColors.surfaceHigh,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
