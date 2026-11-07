import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../celebration/day_complete.dart';
import '../motion/rolling_number.dart';
import '../nutrition/diary_view.dart';
import '../plan/workout_detail.dart';
import '../widgets/app_card.dart';
import '../widgets/habit_tile.dart';
import '../widgets/juicy_button.dart';
import '../widgets/pressure_banner.dart';
import 'coach_card.dart';
import 'streak_hero.dart';

/// Today. The only screen most users open on most days.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onOpenSocial});

  final VoidCallback? onOpenSocial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnapshot = ref.watch(appStateProvider);

    return asyncSnapshot.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(context.l10n.errorGeneric('$error')),
        ),
      ),
      data: (AppSnapshot snapshot) => _HomeBody(
        snapshot: snapshot,
        onOpenSocial: onOpenSocial,
      ),
    );
  }
}

class _HomeBody extends ConsumerStatefulWidget {
  const _HomeBody({required this.snapshot, this.onOpenSocial});

  final AppSnapshot snapshot;
  final VoidCallback? onOpenSocial;

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody> {
  final GlobalKey _habitsKey = GlobalKey();

  /// What each habit's last check-in earned, and a counter per habit that
  /// replays its celebration.
  final Map<String, int> _xpGain = <String, int>{};
  final Map<String, int> _celebrations = <String, int>{};

  void _scrollToHabits() {
    final BuildContext? target = _habitsKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppSnapshot snapshot = widget.snapshot;
    final AppLocalizations l10n = context.l10n;
    final Challenge challenge = snapshot.challenge!;
    final DayKey today = snapshot.today;
    final DayLog? log = snapshot.me.logsByDay[today.toString()];
    final List<Habit> todayHabits = requiredHabitsOn(challenge, today);
    final List<Habit> otherHabits = challenge.habits
        .where((Habit h) => !todayHabits.contains(h))
        .toList();
    final Workout? workout = snapshot.plan?.workoutFor(challenge.startDay, today);
    // Day 100 of the *current* cycle, finished. The cycleOf check keeps the
    // card from reappearing on the same day after the user has ascended.
    final bool cycleDone = challenge.cycleOf(today) >= challenge.cycle &&
        challenge.dayInCycle(today) >= challenge.lengthDays &&
        snapshot.me.streak.doneToday;

    Widget tile(Habit habit, {bool scheduled = true}) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
          child: HabitTile(
            key: ValueKey<String>('habit-${habit.id}'),
            habit: habit,
            streak: snapshot.me.habitStreaks[habit.id] ?? 0,
            entry: log?.entryFor(habit.id),
            scheduledToday: scheduled,
            xpGain: _xpGain[habit.id],
            celebration: _celebrations[habit.id] ?? 0,
            onCheckIn: (num value) => _checkIn(habit, value),
            onRelapse: () => _confirmRelapse(habit),
          ),
        );

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => ref.read(appStateProvider.notifier).syncNow(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          _Header(snapshot: snapshot),
          const SizedBox(height: AppSpacing.md),
          StreakHero(snapshot: snapshot, onTapStatus: _scrollToHabits),
          const SizedBox(height: AppSpacing.md),
          PressureBanner(
            activePeers: snapshot.peerStates
                .where((PeerState p) => p.activeToday)
                .toList(),
            doneToday: snapshot.me.streak.doneToday,
            onTap: widget.onOpenSocial,
          ),
          if (cycleDone) ...<Widget>[
            const SizedBox(height: AppSpacing.sm + 4),
            _AscendCard(challenge: challenge),
          ],
          SectionHeader(
            l10n.homeQuestsTitle,
            key: _habitsKey,
            subtitle: todayHabits.isEmpty
                ? l10n.homeRestDay
                : l10n.homeDoneOfTotal(
                    _doneCount(todayHabits, log), todayHabits.length),
          ),
          if (todayHabits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _DayProgress(
                done: _doneCount(todayHabits, log),
                total: todayHabits.length,
              ),
            ),
          for (final Habit habit in todayHabits) tile(habit),
          if (otherHabits.isNotEmpty) ...<Widget>[
            SectionHeader(
              l10n.homeOptional,
              subtitle: l10n.homeOptionalSubtitle,
            ),
            for (final Habit habit in otherHabits) tile(habit, scheduled: false),
          ],
          if (snapshot.me.streak.atRisk &&
              challenge.streakFreezesRemaining -
                      snapshot.me.streak.freezesUsed >
                  0) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _FreezeCard(
              remaining: challenge.streakFreezesRemaining -
                  snapshot.me.streak.freezesUsed,
            ),
          ],
          if (workout != null) ...<Widget>[
            SectionHeader(l10n.homeTodaysWorkout),
            _WorkoutCard(
              workout: workout,
              challenge: challenge,
              day: today,
              logged: snapshot.me.workoutLogOn(today) != null,
            ),
          ],
          if (snapshot.plan?.nutrition != null) ...<Widget>[
            SectionHeader(l10n.homeTodaysMacros),
            _MacroCard(
              plan: snapshot.plan!.nutrition!,
              eaten: snapshot.me.intakeOn(today).total,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const CoachCard(),
          const _WidgetPromo(),
        ],
      ),
    );
  }

  /// Habits that actually hit their target today — an under-target reading
  /// entry is progress, not a completed habit.
  int _doneCount(List<Habit> habits, DayLog? log) {
    if (log == null) return 0;
    return habits.where((Habit h) {
      final CheckIn? entry = log.entryFor(h.id);
      return entry != null && !entry.relapse && entry.value >= h.target;
    }).length;
  }

  Future<void> _checkIn(Habit habit, num value) async {
    final AppSnapshot before = widget.snapshot;
    await ref.read(appStateProvider.notifier).checkIn(habit, value: value);
    if (!mounted) return;

    final AppSnapshot? after = ref.read(appStateProvider).valueOrNull;
    if (after == null) return;
    final int gain = after.me.lifetimeXp - before.me.lifetimeXp;
    setState(() {
      _xpGain[habit.id] = gain;
      _celebrations[habit.id] = (_celebrations[habit.id] ?? 0) + 1;
    });

    final bool justCompleted =
        after.me.streak.doneToday && !before.me.streak.doneToday;
    final AppLocalizations l10n = context.l10n;
    // Screen readers get the words the animation shows.
    SemanticsService.sendAnnouncement(
      View.of(context),
      justCompleted
          ? l10n.homeDayCompleteToast(after.me.streak.current)
          : l10n.homeCheckInToast(habit.emoji, l10n.habitLabel(habit)),
      Directionality.of(context),
    );
    if (!justCompleted) return;

    final DayReward reward = rewardForDay(
      challenge: after.challenge!,
      today: after.today,
      before: before.me.streak,
      after: after.me.streak,
      xpBefore: before.me.lifetimeXp,
      xpAfter: after.me.lifetimeXp,
      xpToday: after.me.xpByDay[after.today.toString()] ?? gain,
    );
    // Let the tile's own burst land first, then roll the machine.
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    await showDayCompleteCelebration(
      context,
      reward: reward,
      challenge: after.challenge!,
      lifetimeXp: after.me.lifetimeXp,
    );
  }

  Future<void> _confirmRelapse(Habit habit) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.homeRelapseTitle(l10n.habitLabel(habit))),
        content: Text(l10n.homeRelapseBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(120, 44),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.homeRelapseConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(appStateProvider.notifier).logRelapse(habit);
  }
}

/// Today's habits as one bar that fills up — the last segment is the one
/// that sets off the machine.
class _DayProgress extends StatelessWidget {
  const _DayProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < total; i++)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              height: 10,
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
              decoration: BoxDecoration(
                borderRadius: AppRadius.pill,
                gradient: i < done ? AppGradients.plasma : null,
                color: i < done ? null : AppColors.surfaceHigh,
                boxShadow: i < done
                    ? AppShadows.glow(AppColors.primary, strength: 0.5)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.snapshot});

  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Challenge challenge = snapshot.challenge!;
    final int xp = snapshot.me.lifetimeXp;
    final int level = levelForXp(xp);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: <Widget>[
          EmojiAvatar(
            snapshot.me.profile.avatarEmoji,
            size: 46,
            ringColor: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  snapshot.me.profile.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  l10n.homeLevelAndTier(
                    challenge.tier.emoji,
                    l10n.tierName(challenge.tier),
                    level,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                ),
              ],
            ),
          ),
          _XpBadge(xp: xp, progress: levelProgress(xp)),
        ],
      ),
    );
  }
}

/// Lifetime XP as a neon counter with the level bar under it.
class _XpBadge extends StatelessWidget {
  const _XpBadge({required this.xp, required this.progress});

  final int xp;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 12, 8),
      decoration: BoxDecoration(
        // Opaque, so the glow stays a halo instead of soaking through.
        color: Color.lerp(AppColors.surface, AppColors.reward, 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.reward.withValues(alpha: 0.55)),
        boxShadow: AppShadows.glow(AppColors.reward, strength: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.bolt, size: 16, color: AppColors.reward),
              RollingNumber(
                value: xp,
                suffix: ' XP',
                style: displayStyle(14, color: AppColors.reward),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 74,
            child: ClipRRect(
              borderRadius: AppRadius.pill,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double value, Widget? _) =>
                    LinearProgressIndicator(
                  value: math.max(0.04, value),
                  minHeight: 5,
                  backgroundColor: AppColors.glassHigh,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.reward),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// On Android, while no streak widget is on the home screen: offer one.
class _WidgetPromo extends ConsumerWidget {
  const _WidgetPromo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canPin = ref.watch(canPinStreakWidgetProvider).valueOrNull ?? false;
    if (!canPin) return const SizedBox.shrink();
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        border: AppColors.primary.withValues(alpha: 0.5),
        glow: AppColors.primary.withValues(alpha: 0.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.widgets, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(l10n.widgetPromoTitle,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.widgetPromoBody,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            JuicyButton(
              label: l10n.widgetPromoAction,
              icon: Icons.add_to_home_screen,
              onPressed: () async {
                await ref.read(streakWidgetProvider).requestPin();
                ref.invalidate(canPinStreakWidgetProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.workout,
    required this.challenge,
    required this.day,
    required this.logged,
  });

  final Workout workout;
  final Challenge challenge;
  final DayKey day;
  final bool logged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCard(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => WorkoutDetailScreen(
            workout: workout,
            titleSuffix: l10n.friendsDayNumber(challenge.dayNumber(day)),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('🏋️', style: TextStyle(fontSize: 24)),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.workoutName(workout.kind),
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      l10n.workoutFocus(workout.kind),
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                              ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              Pill(l10n.homeExercisesCount(workout.blocks.length)),
              Pill(l10n.homeSetsCount(workout.totalSets)),
              Pill(l10n.homeMinutesApprox(workout.estimatedMinutes)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          if (logged)
            Pill(l10n.homeWorkoutLogged,
                color: AppColors.success, icon: Icons.check_circle)
          else
            FilledButton.icon(
              key: const Key('home-start-workout'),
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: () => WorkoutDetailScreen.startLogging(context, workout),
              icon: const Icon(Icons.play_arrow, size: 19),
              label: Text(l10n.homeStartWorkout(
                  ((kTrackedMultiplier - 1) * 100).round())),
            ),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.plan, required this.eaten});

  final NutritionPlan plan;
  final Nutrients eaten;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    String of(double value, int target, [String unit = '']) =>
        '${value.round()}$unit / $target$unit';
    return AppCard(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const DiaryScreen(),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  value: of(eaten.kcal, plan.kcal),
                  label: l10n.planKcal,
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: of(eaten.proteinG, plan.proteinG, 'g'),
                  label: l10n.planProtein,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              const Icon(Icons.restaurant_menu,
                  size: 16, color: AppColors.textTertiary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  l10n.homeOpenDiary,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary, fontSize: 12.5),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ],
      ),
    );
  }
}

class _FreezeCard extends ConsumerWidget {
  const _FreezeCard({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return AppCard(
      color: AppColors.surfaceHigh,
      child: Row(
        children: <Widget>[
          const Text('🧊', style: TextStyle(fontSize: 22)),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.homeFreezeTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  l10n.homeFreezeBody(remaining),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(appStateProvider.notifier).useStreakFreeze(),
            child: Text(l10n.homeFreezeUse),
          ),
        ],
      ),
    );
  }
}

class _AscendCard extends ConsumerWidget {
  const _AscendCard({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ChallengeTier next = tierForCycle(challenge.cycle + 1);
    final String nextName = l10n.tierName(next);
    return AppCard(
      border: AppColors.success,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          AppColors.success.withValues(alpha: 0.2),
          AppColors.surface,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.homeAscendTitle(challenge.lengthDays),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.homeAscendBody(next.emoji, nextName),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.ink,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => ref.read(appStateProvider.notifier).ascend(),
            child: Text(l10n.homeAscendAction(nextName)),
          ),
        ],
      ),
    );
  }
}
