import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import 'data/app_repository.dart';
import 'data/locale_store.dart';
import 'l10n/l10n.dart';
import 'state/providers.dart';
import 'theme/theme.dart';
import 'ui/home/home_screen.dart';
import 'ui/mascot/flame_mascot.dart';
import 'ui/onboarding/onboarding_flow.dart';
import 'ui/plan/plan_screen.dart';
import 'ui/settings/settings_screen.dart';
import 'ui/social/social_screen.dart';
import 'ui/stats/stats_screen.dart';

class HundredDaysApp extends ConsumerWidget {
  const HundredDaysApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Null follows the device language; a stored choice overrides it.
    final Locale? locale = ref.watch(localeProvider);

    return MaterialApp(
      onGenerateTitle: (BuildContext context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const _Gate(),
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
      error: (Object error, StackTrace stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('💥', style: TextStyle(fontSize: 44)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  context.l10n.homeStorageError,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
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
                  onPressed: () => ref.invalidate(appStateProvider),
                  child: Text(context.l10n.actionRetry),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (AppSnapshot snapshot) =>
          snapshot.hasChallenge ? const AppShell() : const OnboardingFlow(),
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

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  void _openSocial() => setState(() => _index = 2);

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
    final int streak = stats?.current ?? 0;
    final bool doneToday = stats?.doneToday ?? false;
    final List<Widget> pages = <Widget>[
      HomeScreen(onOpenSocial: _openSocial),
      const PlanScreen(),
      const SocialScreen(),
      const StatsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: SafeArea(
        // Hidden tabs stay built, so their flames would keep flickering and
        // draining the battery; only the visible one gets to animate.
        child: IndexedStack(
          index: _index,
          children: <Widget>[
            for (int i = 0; i < pages.length; i++)
              TickerMode(enabled: i == _index, child: pages[i]),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int index) => setState(() => _index = index),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: _StreakBadge(
              streak: streak,
              doneToday: doneToday,
              child: const Icon(Icons.local_fire_department_outlined),
            ),
            selectedIcon: _StreakBadge(
              streak: streak,
              doneToday: doneToday,
              child: const Icon(Icons.local_fire_department),
            ),
            label: l10n.navToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
            selectedIcon: const Icon(Icons.assignment),
            label: l10n.navPlan,
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: l10n.navFriends,
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: l10n.navStats,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navMore,
          ),
        ],
      ),
    );
  }
}

/// The streak on the tab bar: flame-coloured once today is fed, a hungry
/// outline while it is not.
class _StreakBadge extends StatelessWidget {
  const _StreakBadge({
    required this.streak,
    required this.doneToday,
    required this.child,
  });

  final int streak;
  final bool doneToday;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (streak <= 0) return child;
    return Badge(
      label: Text('$streak'),
      backgroundColor: doneToday ? AppColors.flame : AppColors.amber,
      textColor: doneToday ? Colors.white : AppColors.ink,
      child: child,
    );
  }
}
