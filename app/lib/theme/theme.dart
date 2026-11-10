import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "Lights": a quiet night that you light yourself.
///
/// The app is opened at 6am and at 11pm, both dark-room moments, so the base
/// is a near-black night. The chrome on top of it is matte and has no colour
/// of its own: white is what you can press, grey is what you read. Colour is
/// earned — it comes from the fire of the streak ([Fire], which changes with
/// the form of the flame), from the stars of the days you finished and from
/// the aurora that rises as today gets done.
class AppColors {
  /// The night itself, and its deepest corner.
  static const Color ink = Color(0xFF05060B);
  static const Color inkDeep = Color(0xFF020308);

  /// Solid surfaces for what cannot be translucent: sheets, dialogs, menus.
  static const Color surface = Color(0xFF10121A);
  static const Color surfaceHigh = Color(0xFF1B1E2A);
  static const Color outline = Color(0xFF2C3040);

  /// What you can press, what is selected: light itself.
  static const Color primary = Color(0xFFF4F5FA);

  /// What sits on a lit surface.
  static const Color onPrimary = Color(0xFF07080D);
  static const Color primarySoft = Color(0xFFC6CADA);

  /// Urgency: the streak at stake, the last hours of the day.
  static const Color hot = Color(0xFFFF4D6D);

  /// Today is open.
  static const Color attention = Color(0xFFFF7EB6);

  /// Near-white: highlights, cores, stars.
  static const Color glow = Color(0xFFF1F2FF);

  /// XP and everything you earn. Lavender.
  static const Color reward = Color(0xFFB4A7FF);

  /// Done. Mint.
  static const Color success = Color(0xFF3FE0B0);

  /// Other people: blue.
  static const Color social = Color(0xFF6EA8FF);

  /// Freezes and rest days: the streak is held, not fed.
  static const Color cool = Color(0xFF8ADCFF);

  /// Danger: a relapse, a broken day.
  static const Color danger = Color(0xFFFF5A5F);

  static const Color textPrimary = Color(0xFFF4F5FA);
  static const Color textSecondary = Color(0xFFA4A9BC);
  static const Color textTertiary = Color(0xFF6C7186);

  /// Panels: a breath of white over the night.
  static const Color glass = Color(0x0FFFFFFF);
  static const Color glassHigh = Color(0x1CFFFFFF);
  static const Color glassEdge = Color(0x1FFFFFFF);

  static const List<Color> heat = <Color>[
    Color(0x14FFFFFF),
    Color(0x40FFFFFF),
    Color(0x73FFFFFF),
    Color(0xB3FFFFFF),
    Color(0xFFF4F5FA),
  ];
}

class AppGradients {
  /// Fire without a stage: where no streak is known.
  static const LinearGradient plasma = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[Color(0xFFFF5C8A), Color(0xFFE25CFF), Color(0xFF8F7CFF)],
  );

  /// The streak number in the celebration: cool sky down to hot ground.
  static const LinearGradient streakText = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xFFFFFFFF),
      Color(0xFFD9B8FF),
      Color(0xFFFF7EB6),
      AppColors.hot,
    ],
    stops: <double>[0, 0.4, 0.75, 1],
  );

  /// Holographic foil: jackpots only.
  static const LinearGradient holo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFC4B5FD),
      Color(0xFF8DE8F5),
      Color(0xFFF9A8D4),
      Color(0xFFB4A7FF),
    ],
    stops: <double>[0, 0.35, 0.7, 1],
  );

  /// Buttons: light, a touch warmer at the top.
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFFFFFFF), Color(0xFFE6E8F2)],
  );

  static const LinearGradient success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF9CF5DA), AppColors.success],
  );

  static const LinearGradient cool = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFDDF4FF), AppColors.cool],
  );

  static const LinearGradient danger = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFF9A9D), AppColors.danger],
  );

  /// Panel fill: flat, a tint of [tint] when it means something.
  static LinearGradient card([Color tint = Colors.white]) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          tint.withValues(alpha: tint == Colors.white ? 0.065 : 0.16),
          tint.withValues(alpha: tint == Colors.white ? 0.045 : 0.06),
        ],
      );

  /// Panel edge: a hairline, coloured when the panel is.
  static LinearGradient edge([Color tint = Colors.white]) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          tint.withValues(alpha: tint == Colors.white ? 0.14 : 0.55),
          tint.withValues(alpha: tint == Colors.white ? 0.06 : 0.22),
        ],
      );
}

class AppShadows {
  /// A soft halo, for the few things that are actually lit.
  static List<BoxShadow> glow(Color color, {double strength = 1}) =>
      <BoxShadow>[
        BoxShadow(
          color: color.withValues(alpha: (0.34 * strength).clamp(0.0, 1.0)),
          blurRadius: 28,
          spreadRadius: -8,
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

/// Wide and round: the numbers the app exists for, and the few lines that
/// are meant to be a statement.
const String kDisplayFont = 'Unbounded';

/// Everything else — titles, buttons and whatever is read.
const String kTextFont = 'Manrope';

/// The display face at [size].
TextStyle displayStyle(
  double size, {
  Color? color,
  double? height,
  FontWeight weight = FontWeight.w800,
}) =>
    TextStyle(
      fontFamily: kDisplayFont,
      fontSize: size,
      fontWeight: weight,
      height: height ?? 1.1,
      letterSpacing: size >= 40 ? -1.5 : (size >= 20 ? -0.4 : 0),
      color: color,
    );

/// A small caps label: what a number is, what a section holds.
TextStyle labelStyle({Color color = AppColors.textTertiary, double size = 11}) =>
    TextStyle(
      fontFamily: kTextFont,
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.4,
      height: 1.2,
      color: color,
    );

ThemeData buildAppTheme() {
  const ColorScheme scheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.reward,
    onSecondary: AppColors.ink,
    tertiary: AppColors.hot,
    onTertiary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.danger,
    onError: AppColors.ink,
    outline: AppColors.outline,
  );

  const TextStyle button = TextStyle(
    fontFamily: kTextFont,
    fontSize: 15.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.1,
  );

  final TextTheme text = TextTheme(
    displayLarge: displayStyle(64, height: 1),
    displayMedium: displayStyle(40),
    headlineMedium: displayStyle(23, height: 1.18),
    titleLarge: const TextStyle(
      fontSize: 18.5,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    ),
    titleMedium: const TextStyle(
      fontSize: 16,
      height: 1.25,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.1,
    ),
    bodyLarge: const TextStyle(
        fontSize: 16, height: 1.45, fontWeight: FontWeight.w500),
    bodyMedium: const TextStyle(
        fontSize: 14.5, height: 1.45, fontWeight: FontWeight.w500),
    labelLarge: button,
    labelSmall: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
    ),
  ).apply(
    fontFamily: kTextFont,
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );
  // apply() put the text face on everything; the display styles keep theirs.
  final TextTheme themed = text.copyWith(
    displayLarge: text.displayLarge!.copyWith(fontFamily: kDisplayFont),
    displayMedium: text.displayMedium!.copyWith(fontFamily: kDisplayFont),
    headlineMedium: text.headlineMedium!.copyWith(fontFamily: kDisplayFont),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: kTextFont,
    // Every screen lies over the one sky painted behind the navigator.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: AppColors.surface,
    textTheme: themed,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(),
        TargetPlatform.linux: FadeThroughPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeThroughPageTransitionsBuilder(),
        TargetPlatform.windows: FadeThroughPageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        fontFamily: kTextFont,
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: AppColors.textPrimary,
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.glass,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.glassEdge,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.glassHigh,
        disabledForegroundColor: AppColors.textTertiary,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
        textStyle: button,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.glass,
        side: const BorderSide(color: AppColors.glassEdge, width: 1.2),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
        textStyle: button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        textStyle: button.copyWith(fontSize: 14.5),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 0,
      highlightElevation: 0,
      extendedTextStyle: button,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.glass,
      hintStyle: const TextStyle(color: AppColors.textTertiary),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.glassEdge),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.glassEdge),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      indicator: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.pill,
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: AppColors.onPrimary,
      unselectedLabelColor: AppColors.textSecondary,
      labelStyle: TextStyle(
          fontFamily: kTextFont, fontWeight: FontWeight.w800, fontSize: 13.5),
      unselectedLabelStyle: TextStyle(
          fontFamily: kTextFont, fontWeight: FontWeight.w700, fontSize: 13.5),
      overlayColor: WidgetStatePropertyAll<Color>(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? AppColors.onPrimary
            : AppColors.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.glassHigh,
      ),
      trackOutlineColor:
          const WidgetStatePropertyAll<Color>(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll<Color>(AppColors.onPrimary),
      side: const BorderSide(color: AppColors.textTertiary, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.textTertiary,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.glassHigh,
      thumbColor: Colors.white,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: TextStyle(
          color: AppColors.textPrimary, fontFamily: kTextFont),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.glass,
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.textPrimary,
      side: const BorderSide(color: AppColors.glassEdge),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
      labelStyle: themed.bodyMedium!,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textSecondary,
      textColor: AppColors.textPrimary,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.glassHigh,
      circularTrackColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.outline,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: AppColors.primary.withValues(alpha: 0.16),
      labelTextStyle: WidgetStatePropertyAll<TextStyle>(themed.labelSmall!),
    ),
  );
}

/// Pages fade through each other over the one sky they share: the old
/// page sinks away as the new one rises, so two transparent screens never
/// sit on top of each other.
class FadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<double> incoming = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.3, 1, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0, 0.7, curve: Curves.easeInCubic),
    );
    final Animation<double> outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: const Interval(0, 0.4, curve: Curves.easeIn),
      reverseCurve: const Interval(0.6, 1, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(outgoing),
      child: FadeTransition(
        opacity: incoming,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(incoming),
          child: child,
        ),
      ),
    );
  }
}
