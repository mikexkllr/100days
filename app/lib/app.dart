import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import 'data/app_repository.dart';
import 'data/locale_store.dart';
import 'l10n/l10n.dart';
import 'state/providers.dart';
import 'theme/fire.dart';
import 'theme/theme.dart';
import 'ui/home/home_screen.dart';
import 'ui/mascot/flame_mascot.dart';
import 'ui/auth/login_screen.dart';
import 'ui/celebration/day_complete.dart';
import 'ui/motion/motion.dart';
import 'ui/home/today.dart';
import 'ui/motion/sky.dart';
import 'ui/onboarding/onboarding_flow.dart';
import 'ui/plan/plan_screen.dart';
import 'ui/settings/settings_screen.dart';
import 'ui/social/social_screen.dart';
import 'ui/stats/stats_screen.dart';

/// The root navigator, for what arrives from outside the widget tree — an
/// invite link opened from a chat.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class HundredDaysApp extends ConsumerWidget {
  const HundredDaysApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Null follows the device language; a stored choice overrides it.
    final Locale? locale = ref.watch(localeProvider);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      onGenerateTitle: (BuildContext context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // One sky behind every page.
      builder: (BuildContext context, Widget? child) =>
          _Sky(child: child ?? const SizedBox.shrink()),
      home: const _AuthGate(),
    );
  }
}

/// Sign-in until there is an account; then the account's data.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppRepository?> session =
        ref.watch(sessionRepositoryProvider);
    return session.when(
      loading: () => const _Splash(),
      error: (Object error, StackTrace stack) => _ErrorScreen(
        error: error,
        onRetry: () => ref.invalidate(sessionRepositoryProvider),
      ),
      data: (AppRepository? repository) =>
          repository == null ? const LoginScreen() : const _Gate(),
    );
  }
}

/// Onboarding until a challenge exists; the app shell afterwards.
class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppSnapshot> async = ref.watch(appStateProvider);

    return async.when(
      loading: () => const _Splash(),
      error: (Object error, StackTrace stack) => _ErrorScreen(
        error: error,
        onRetry: () => ref.invalidate(appStateProvider),
      ),
      data: (AppSnapshot snapshot) {
        if (snapshot.hasChallenge) return const AppShell();
        // A returning user on a new phone: the challenge is on the server,
        // not here yet. Onboarding now would start a second one.
        if (!snapshot.accountLoaded) return const _LoadingAccount();
        return const OnboardingFlow();
      },
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const FlameMascot(
                stage: FlameStage.ember,
                mood: MascotMood.sad,
                size: 120,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.l10n.gateErrorTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.l10n.homeStorageError,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: onRetry,
                child: Text(context.l10n.actionRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Signed in on a phone that has not seen the account's feed yet: Funki
/// waits for the first pull, and says so if it takes long.
class _LoadingAccount extends ConsumerStatefulWidget {
  const _LoadingAccount();

  @override
  ConsumerState<_LoadingAccount> createState() => _LoadingAccountState();
}

class _LoadingAccountState extends ConsumerState<_LoadingAccount> {
  bool _slow = false;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await ref.read(appStateProvider.notifier).syncNow();
    } on Object {
      // Still offline; the screen stays and says so.
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const FlameMascot(
                stage: FlameStage.spark,
                mood: MascotMood.hopeful,
                size: 150,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.gateLoadingAccount,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_slow) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.gateLoadingAccountSlow,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: _busy ? null : _retry,
                  child: Text(l10n.actionRetry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FlameMascot(
              stage: FlameStage.flame,
              mood: MascotMood.happy,
              size: 170,
            ),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sky of the person using the app: a star for every finished day, an
/// aurora as high as today is done, in the colour of their flame.
class _Sky extends ConsumerWidget {
  const _Sky({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSnapshot? snapshot = ref.watch(appStateProvider).valueOrNull;
    if (snapshot == null || !snapshot.hasChallenge) {
      // Before the first challenge: an inviting sky, no stars earned yet.
      return NightSky(glow: 0.55, child: child);
    }
    final TodayState today = TodayState.of(snapshot);
    return NightSky(
      fire: today.fire,
      glow: today.glow,
      stars: snapshot.me.streak.completedDays,
      child: child,
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  /// A short fade into the tab just opened; the tabs themselves stay built.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _open(int index) {
    if (index != _index && ambientMotionOf(context)) _fade.forward(from: 0);
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<String> titles = <String>[
      l10n.navToday,
      l10n.navPlan,
      l10n.navFriends,
      l10n.navStats,
      l10n.navSettingsTitle,
    ];
    final StreakStats? stats =
        ref.watch(appStateProvider).valueOrNull?.me.streak;
    final List<Widget> pages = <Widget>[
      HomeScreen(
        onOpenSocial: () => _open(2),
        onOpenStats: () => _open(3),
      ),
      const PlanScreen(),
      const SocialScreen(),
      const StatsScreen(),
      const SettingsScreen(),
    ];

    return CelebrationHost(
      child: Scaffold(
        extendBody: true,
        // Today is the whole screen: it needs no title above it.
        appBar: _index == 0 ? null : AppBar(title: Text(titles[_index])),
        body: SafeArea(
          bottom: false,
          // Hidden tabs stay built, so their flames would keep flickering and
          // draining the battery; only the visible one gets to animate.
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
            child: IndexedStack(
              index: _index,
              children: <Widget>[
                for (int i = 0; i < pages.length; i++)
                  TickerMode(enabled: i == _index, child: pages[i]),
              ],
            ),
          ),
        ),
        bottomNavigationBar: GlassDock(
          index: _index,
          onSelect: _open,
          items: <DockItem>[
            DockItem(
              icon: Icons.local_fire_department_outlined,
              selectedIcon: Icons.local_fire_department,
              label: l10n.navToday,
              // The streak is at stake: a dot in its colour until today is done.
              dot: stats != null && stats.atRisk
                  ? Fire.ofStreak(stats.current).main
                  : null,
            ),
            DockItem(
              icon: Icons.assignment_outlined,
              selectedIcon: Icons.assignment,
              label: l10n.navPlan,
            ),
            DockItem(
              icon: Icons.groups_outlined,
              selectedIcon: Icons.groups,
              label: l10n.navFriends,
            ),
            DockItem(
              icon: Icons.insights_outlined,
              selectedIcon: Icons.insights,
              label: l10n.navStats,
            ),
            DockItem(
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: l10n.navMore,
            ),
          ],
        ),
      ),
    );
  }
}

class DockItem {
  const DockItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.dot,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// A small light on the icon: something here is waiting.
  final Color? dot;
}

/// The navigation: a matte bar floating over the sky. What is selected is
/// lit, everything else is not.
class GlassDock extends StatelessWidget {
  const GlassDock({
    super.key,
    required this.index,
    required this.items,
    required this.onSelect,
  });

  final int index;
  final List<DockItem> items;
  final ValueChanged<int> onSelect;

  static const double height = 62;

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      // Whatever scrolls under the dock sinks into the night first.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.inkDeep.withValues(alpha: 0),
            AppColors.inkDeep.withValues(alpha: 0.92),
          ],
          stops: const <double>[0, 0.55],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 10 + bottom),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                color: AppColors.surface.withValues(alpha: 0.9),
                border: Border.all(color: AppColors.glassEdge),
              ),
              child: SizedBox(
                height: height,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double cell =
                        (constraints.maxWidth - 12) / items.length;
                    return Stack(
                      children: <Widget>[
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          left: 6 + cell * index,
                          top: 6,
                          width: cell,
                          height: height - 14,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.pill,
                              color: AppColors.glassHigh,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            children: <Widget>[
                              for (int i = 0; i < items.length; i++)
                                Expanded(
                                  child: _DockButton(
                                    item: items[i],
                                    selected: i == index,
                                    onTap: () {
                                      if (i != index) {
                                        HapticFeedback.selectionClick();
                                      }
                                      onSelect(i);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DockItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color =
        selected ? AppColors.textPrimary : AppColors.textTertiary;
    Widget icon = Icon(selected ? item.selectedIcon : item.icon,
        color: color, size: 23);
    if (item.dot != null) {
      icon = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          icon,
          Positioned(
            right: -4,
            top: -2,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.dot,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
            ),
          ),
        ],
      );
    }
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            icon,
            const SizedBox(height: 3),
            ExcludeSemantics(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kTextFont,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
