import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The palette. Dark by default and unapologetically so: this app is opened at
/// 6am and at 11pm, and both of those are dark-room moments.
class AppColors {
  static const Color ink = Color(0xFF0B0D10);
  static const Color surface = Color(0xFF14181D);
  static const Color surfaceHigh = Color(0xFF1D232B);
  static const Color outline = Color(0xFF2C343E);

  /// Streak fire. The one colour that means "you did it".
  static const Color flame = Color(0xFFFF6B2C);
  static const Color flameSoft = Color(0xFFFFA574);

  /// Progress and success.
  static const Color lime = Color(0xFFB8F14B);

  /// Social pressure: someone else moved.
  static const Color violet = Color(0xFF8B7BFF);

  /// Danger: streak at risk, relapse.
  static const Color danger = Color(0xFFFF4D5E);

  static const Color textPrimary = Color(0xFFF3F5F7);
  static const Color textSecondary = Color(0xFF97A2B0);
  static const Color textTertiary = Color(0xFF5D6875);

  static const List<Color> heat = <Color>[
    Color(0xFF1A2027),
    Color(0xFF3A2A1E),
    Color(0xFF6B3A1C),
    Color(0xFFB2521F),
    Color(0xFFFF6B2C),
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
  static const Radius card = Radius.circular(20);
  static const BorderRadius cardAll = BorderRadius.all(card);
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

ThemeData buildAppTheme() {
  const ColorScheme scheme = ColorScheme.dark(
    primary: AppColors.flame,
    onPrimary: Color(0xFF1A0A02),
    secondary: AppColors.lime,
    onSecondary: Color(0xFF12200A),
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.danger,
    onError: Colors.white,
    outline: AppColors.outline,
  );

  final TextTheme text = const TextTheme(
    displayLarge: TextStyle(
      fontSize: 72,
      fontWeight: FontWeight.w800,
      letterSpacing: -2.5,
      height: 1,
    ),
    displayMedium: TextStyle(
      fontSize: 44,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.5,
      height: 1.05,
    ),
    headlineMedium: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      height: 1.15,
    ),
    titleLarge: TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16, height: 1.45),
    bodyMedium: TextStyle(fontSize: 14.5, height: 1.45),
    labelLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
    labelSmall: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
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
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.4,
      ),
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
      style: TextButton.styleFrom(foregroundColor: AppColors.flameSoft),
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
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.flame.withValues(alpha: 0.18),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll<TextStyle>(text.labelSmall!),
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
  );
}
