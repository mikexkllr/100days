import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "Nightglow": deep space, an aurora moving behind everything, glass on top.
///
/// The app is opened at 6am and at 11pm, both dark-room moments, so the base
/// is a violet-black night. Colour comes from light, not paint: the aurora
/// behind the screens, the plasma of the streak, the neon of what you can
/// press. Red, magenta, violet and blue carry the whole thing — the same
/// colours Funki burns through as the streak grows.
class AppColors {
  /// The night itself, and its deepest corner.
  static const Color ink = Color(0xFF07051A);
  static const Color inkDeep = Color(0xFF030210);

  /// Solid surfaces for what cannot be glass: sheets, dialogs, menus.
  static const Color surface = Color(0xFF14102E);
  static const Color surfaceHigh = Color(0xFF221B47);
  static const Color outline = Color(0xFF3A3170);

  /// What you can press, what is selected, what is yours. Electric violet.
  static const Color primary = Color(0xFF8B5CF6);
  static const Color primarySoft = Color(0xFFC4B5FD);

  /// The red root of the plasma: urgency, the streak at stake.
  static const Color hot = Color(0xFFF43F5E);

  /// Magenta, for the moments in between: today is open.
  static const Color attention = Color(0xFFE879F9);

  /// Near-white lavender: highlights, cores, the head of the comet.
  static const Color glow = Color(0xFFEDE9FE);

  /// XP and everything you earn. Electric cyan.
  static const Color reward = Color(0xFF22D3EE);

  /// Done. Mint.
  static const Color success = Color(0xFF34E0B5);

  /// Other people: blue.
  static const Color social = Color(0xFF60A5FA);

  /// Freezes and rest days: the streak is held, not fed.
  static const Color cool = Color(0xFF7DD3FC);

  /// Danger: a relapse, a broken day.
  static const Color danger = Color(0xFFFB7185);

  static const Color textPrimary = Color(0xFFF5F3FF);
  static const Color textSecondary = Color(0xFFB9B3DB);
  static const Color textTertiary = Color(0xFF7A73A6);

  /// Glass: a breath of white over whatever glows behind it.
  static const Color glass = Color(0x14FFFFFF);
  static const Color glassHigh = Color(0x22FFFFFF);
  static const Color glassEdge = Color(0x2EFFFFFF);

  /// The aurora's lights.
  static const Color auroraViolet = Color(0xFF6D28D9);
  static const Color auroraBlue = Color(0xFF1D4ED8);
  static const Color auroraRose = Color(0xFFBE123C);
  static const Color auroraCyan = Color(0xFF0E7490);

  static const List<Color> heat = <Color>[
    Color(0x1AFFFFFF),
    Color(0xFF3B1F7A),
    Color(0xFF6D3BD8),
    Color(0xFFA855F7),
    Color(0xFFF472B6),
  ];
}

class AppGradients {
  /// The streak's own light: red at the root, violet, blue at the tip.
  static const LinearGradient plasma = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[AppColors.hot, Color(0xFFD946EF), AppColors.primary],
  );

  /// The streak number: a synthwave sunset, blue sky down to red ground.
  static const LinearGradient streakText = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xFFBFDBFE),
      Color(0xFFA78BFA),
      Color(0xFFF472B6),
      AppColors.hot,
    ],
    stops: <double>[0, 0.35, 0.7, 1],
  );

  /// Holographic foil: rewards, jackpots, level-ups.
  static const LinearGradient holo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFC4B5FD),
      Color(0xFF67E8F9),
      Color(0xFFF9A8D4),
      Color(0xFFA78BFA),
    ],
    stops: <double>[0, 0.35, 0.7, 1],
  );

  /// Buttons: violet into blue.
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFA855F7), AppColors.primary, Color(0xFF3B82F6)],
  );

  static const LinearGradient success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF99F6E4), AppColors.success, Color(0xFF14B8A6)],
  );

  static const LinearGradient cool = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFE0F2FE), AppColors.cool, Color(0xFF3B82F6)],
  );

  static const LinearGradient danger = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFDA4AF), AppColors.danger, AppColors.hot],
  );

  /// Glass fill: brighter where the light comes from.
  static LinearGradient card([Color tint = Colors.white]) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          tint.withValues(alpha: tint == Colors.white ? 0.10 : 0.18),
          tint.withValues(alpha: tint == Colors.white ? 0.035 : 0.05),
        ],
      );

  /// Glass edge: a bright rim at the top left fading out.
  static LinearGradient edge([Color tint = Colors.white]) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          tint.withValues(alpha: tint == Colors.white ? 0.32 : 0.75),
          tint.withValues(alpha: tint == Colors.white ? 0.06 : 0.18),
        ],
      );
}

class AppShadows {
  /// A coloured glow, for anything that should feel lit.
  static List<BoxShadow> glow(Color color, {double strength = 1}) =>
      <BoxShadow>[
        BoxShadow(
          color: color.withValues(alpha: (0.5 * strength).clamp(0.0, 1.0)),
          blurRadius: 24,
          spreadRadius: -6,
        ),
        BoxShadow(
          color: color.withValues(alpha: (0.22 * strength).clamp(0.0, 1.0)),
          blurRadius: 48,
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
  static const Radius card = Radius.circular(26);
  static const BorderRadius cardAll = BorderRadius.all(card);
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// Wide, round, a little sci-fi: numbers, headlines and buttons.
const String kDisplayFont = 'Unbounded';

/// Everything that is read rather than glanced at.
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

ThemeData buildAppTheme() {
  const ColorScheme scheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.reward,
    onSecondary: AppColors.ink,
    tertiary: AppColors.hot,
    onTertiary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.danger,
    onError: Colors.white,
    outline: AppColors.outline,
  );

  final TextTheme text = TextTheme(
    displayLarge: displayStyle(64, height: 1),
    displayMedium: displayStyle(40),
    headlineMedium: displayStyle(24, height: 1.15),
    titleLarge: displayStyle(17, height: 1.2, weight: FontWeight.w700),
    titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    bodyLarge: const TextStyle(
        fontSize: 16, height: 1.45, fontWeight: FontWeight.w500),
    bodyMedium: const TextStyle(
        fontSize: 14.5, height: 1.45, fontWeight: FontWeight.w500),
    labelLarge: displayStyle(14.5, weight: FontWeight.w700)
        .copyWith(letterSpacing: 0.3),
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
    titleLarge: text.titleLarge!.copyWith(fontFamily: kDisplayFont),
    labelLarge: text.labelLarge!.copyWith(fontFamily: kDisplayFont),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: kTextFont,
    // Every screen is glass over the aurora painted behind the navigator.
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
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: displayStyle(21, color: AppColors.textPrimary),
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
        minimumSize: const Size.fromHeight(56),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.glassHigh,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
        textStyle: themed.labelLarge,
        elevation: 8,
        shadowColor: AppColors.primary.withValues(alpha: 0.7),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.glass,
        side: const BorderSide(color: AppColors.glassEdge, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
        textStyle: themed.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primarySoft,
        textStyle: themed.labelLarge?.copyWith(fontSize: 13.5),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary),
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
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.glassEdge),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.glassEdge),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      indicator: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: AppRadius.pill,
        boxShadow: AppShadows.glow(AppColors.primary, strength: 0.6),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: Colors.white,
      unselectedLabelColor: AppColors.textSecondary,
      labelStyle: const TextStyle(
          fontFamily: kTextFont, fontWeight: FontWeight.w800, fontSize: 13.5),
      unselectedLabelStyle: const TextStyle(
          fontFamily: kTextFont, fontWeight: FontWeight.w700, fontSize: 13.5),
      overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? Colors.white
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
      side: const BorderSide(color: AppColors.textTertiary, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
      selectedColor: AppColors.primary.withValues(alpha: 0.35),
      side: const BorderSide(color: AppColors.glassEdge),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
      labelStyle: themed.bodyMedium!,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.primarySoft,
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
      dragHandleColor: AppColors.textTertiary,
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
      indicatorColor: AppColors.primary.withValues(alpha: 0.25),
      labelTextStyle: WidgetStatePropertyAll<TextStyle>(themed.labelSmall!),
    ),
  );
}

/// Pages fade through each other over the one aurora they share: the old
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
