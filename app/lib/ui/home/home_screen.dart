import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../plan/workout_detail.dart';
import '../widgets/app_card.dart';
import '../widgets/habit_tile.dart';
import '../widgets/pressure_banner.dart';
import '../widgets/streak_ring.dart';
import 'coach_card.dart';

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

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.snapshot, this.onOpenSocial});

  final AppSnapshot snapshot;
  final VoidCallback? onOpenSocial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return RefreshIndicator(
      color: AppColors.flame,
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
          Center(
            child: StreakRing(
              streak: snapshot.me.streak.current,
              progress: challenge.progressInCycle(today),
              dayNumber: challenge.dayNumber(today),
              totalDays: challenge.lengthDays * (challenge.cycle + 1),
              atRisk: snapshot.me.streak.atRisk,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const CoachCard(),
          const SizedBox(height: AppSpacing.sm + 4),
          PressureBanner(
            activePeers: snapshot.peerStates
                .where((PeerState p) => p.activeToday)
                .toList(),
            doneToday: snapshot.me.streak.doneToday,
            onTap: onOpenSocial,
          ),
          if (cycleDone) ...<Widget>[
            const SizedBox(height: AppSpacing.sm + 4),
            _AscendCard(challenge: challenge),
          ],
          if (workout != null) ...<Widget>[
            SectionHeader(l10n.homeTodaysWorkout),
            _WorkoutCard(workout: workout, challenge: challenge, day: today),
          ],
          if (snapshot.plan?.nutrition != null) ...<Widget>[
            SectionHeader(l10n.homeTodaysMacros),
            _MacroCard(plan: snapshot.plan!.nutrition!),
          ],
          SectionHeader(
            l10n.homeCheckOffToday,
            subtitle: todayHabits.isEmpty
                ? l10n.homeRestDay
                : l10n.homeDoneOfTotal(
                    _doneCount(todayHabits, log), todayHabits.length),
          ),
          for (final Habit habit in todayHabits)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
              child: HabitTile(
                habit: habit,
                streak: snapshot.me.habitStreaks[habit.id] ?? 0,
                entry: log?.entryFor(habit.id),
                onCheckIn: (num value) =>
                    _checkIn(context, ref, habit, value, snapshot),
                onRelapse: () => _confirmRelapse(context, ref, habit),
              ),
            ),
          if (otherHabits.isNotEmpty) ...<Widget>[
            SectionHeader(
              l10n.homeOptional,
              subtitle: l10n.homeOptionalSubtitle,
            ),
            for (final Habit habit in otherHabits)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                child: HabitTile(
                  habit: habit,
                  streak: snapshot.me.habitStreaks[habit.id] ?? 0,
                  entry: log?.entryFor(habit.id),
                  scheduledToday: false,
                  onCheckIn: (num value) =>
                      _checkIn(context, ref, habit, value, snapshot),
                  onRelapse: () => _confirmRelapse(context, ref, habit),
                ),
              ),
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

  Future<void> _checkIn(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
    num value,
    AppSnapshot before,
  ) async {
    await ref.read(appStateProvider.notifier).checkIn(habit, value: value);
    if (!context.mounted) return;

    final after = ref.read(appStateProvider).valueOrNull;
    final bool justCompleted =
        after != null && after.me.streak.doneToday && !before.me.streak.doneToday;

    final AppLocalizations l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(justCompleted
            ? l10n.homeDayCompleteToast(after.me.streak.current)
            : l10n.homeCheckInToast(habit.emoji, l10n.habitLabel(habit))),
        duration: const Duration(seconds: 2),
      ));
  }

  Future<void> _confirmRelapse(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
  ) async {
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
    if (confirmed != true || !context.mounted) return;
    await ref.read(appStateProvider.notifier).logRelapse(habit);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.snapshot});

  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Challenge challenge = snapshot.challenge!;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          EmojiAvatar(snapshot.me.profile.avatarEmoji, size: 44),
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
                    levelForXp(snapshot.me.lifetimeXp),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                ),
              ],
            ),
          ),
          Pill(
            l10n.homeXp(snapshot.me.lifetimeXp),
            color: AppColors.lime,
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.workout,
    required this.challenge,
    required this.day,
  });

  final Workout workout;
  final Challenge challenge;
  final DayKey day;

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
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.plan});

  final NutritionPlan plan;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: StatTile(
              value: '${plan.kcal}',
              label: l10n.planKcal,
              color: AppColors.flame,
            ),
          ),
          Expanded(
            child: StatTile(
              value: '${plan.proteinG}g',
              label: l10n.planProtein,
              color: AppColors.lime,
            ),
          ),
          Expanded(
            child: StatTile(
                value: '${plan.carbsG}g', label: l10n.planCarbsShort),
          ),
          Expanded(
            child: StatTile(value: '${plan.fatG}g', label: l10n.planFat),
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
      border: AppColors.lime,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          AppColors.lime.withValues(alpha: 0.2),
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
              backgroundColor: AppColors.lime,
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
