import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import 'data/app_repository.dart';
import 'data/locale_store.dart';
import 'l10n/l10n.dart';
import 'state/providers.dart';
import 'theme/theme.dart';
import 'ui/home/home_screen.dart';
import 'ui/mascot/flame_mascot.dart';
import 'ui/motion/aurora.dart';
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
      // One sky behind every page: screens are glass over it.
      builder: (BuildContext context, Widget? child) =>
          AuroraBackdrop(child: child ?? const SizedBox.shrink()),
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
    final List<Widget> pages = <Widget>[
      HomeScreen(onOpenSocial: _openSocial),
      const PlanScreen(),
      const SocialScreen(),
      const StatsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      // Today is the whole screen: Funki needs no title above him.
      appBar: _index == 0 ? null : AppBar(title: Text(titles[_index])),
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
      bottomNavigationBar: GlassDock(
        index: _index,
        onSelect: (int index) => setState(() => _index = index),
        items: <DockItem>[
          DockItem(
            icon: Icons.local_fire_department_outlined,
            selectedIcon: Icons.local_fire_department,
            label: l10n.navToday,
            badge: _StreakBadge.of(stats),
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
            icon: Icons.tune_outlined,
            selectedIcon: Icons.tune,
            label: l10n.navMore,
          ),
        ],
      ),
    );
  }
}

class DockItem {
  const DockItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget? badge;
}

/// The navigation: a pane of frosted glass floating over the aurora, with a
/// neon pill that glides to whatever you pick.
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

  static const double height = 68;

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 6, 14, 10 + bottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  AppColors.surfaceHigh.withValues(alpha: 0.72),
                  AppColors.surface.withValues(alpha: 0.82),
                ],
              ),
              border: Border.all(color: AppColors.glassEdge),
            ),
            child: SizedBox(
              height: height,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double cell = constraints.maxWidth / items.length;
                  return Stack(
                    children: <Widget>[
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutBack,
                        left: cell * index + 6,
                        top: 7,
                        width: cell - 12,
                        height: height - 14,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: AppGradients.primary,
                            boxShadow:
                                AppShadows.glow(AppColors.primary, strength: 0.9),
                          ),
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          for (int i = 0; i < items.length; i++)
                            Expanded(
                              child: _DockButton(
                                item: items[i],
                                selected: i == index,
                                onTap: () {
                                  if (i != index) HapticFeedback.selectionClick();
                                  onSelect(i);
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
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
    final Color color = selected ? Colors.white : AppColors.textSecondary;
    Widget icon = AnimatedScale(
      scale: selected ? 1.12 : 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      child: Icon(selected ? item.selectedIcon : item.icon,
          color: color, size: 24),
    );
    if (item.badge != null) {
      icon = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          icon,
          Positioned(right: -12, top: -6, child: item.badge!),
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

/// The streak on the dock: plasma once today is fed, a hungry magenta
/// while it is not.
class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streak, required this.doneToday});

  final int streak;
  final bool doneToday;

  static Widget? of(StreakStats? stats) {
    if (stats == null || stats.current <= 0) return null;
    return _StreakBadge(streak: stats.current, doneToday: stats.doneToday);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      constraints: const BoxConstraints(minWidth: 18),
      decoration: BoxDecoration(
        borderRadius: AppRadius.pill,
        gradient: doneToday ? AppGradients.plasma : null,
        color: doneToday ? null : AppColors.attention,
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Text(
        '$streak',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: kDisplayFont,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: doneToday ? Colors.white : AppColors.ink,
        ),
      ),
    );
  }
}
