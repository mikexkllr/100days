import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
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
          child: Text('Fehler: $error'),
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
            const SectionHeader('Heutiges Training'),
            _WorkoutCard(workout: workout, challenge: challenge, day: today),
          ],
          if (snapshot.plan?.nutrition != null) ...<Widget>[
            const SectionHeader('Heutige Makros'),
            _MacroCard(plan: snapshot.plan!.nutrition!),
          ],
          SectionHeader(
            'Heute abhaken',
            subtitle: todayHabits.isEmpty
                ? 'Heute steht nichts an — Pausentag laut Plan.'
                : '${_doneCount(todayHabits, log)} von '
                    '${todayHabits.length} erledigt',
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
            const SectionHeader(
              'Freiwillig',
              subtitle: 'Heute nicht eingeplant — zählt trotzdem als XP.',
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

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(justCompleted
            ? '🔥 Tag komplett — Streak steht bei '
                '${after.me.streak.current}.'
            : '${habit.emoji} ${habit.displayTitle} eingetragen.'),
        duration: const Duration(seconds: 2),
      ));
  }

  Future<void> _confirmRelapse(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Rückfall bei ${habit.displayTitle}?'),
        content: const Text(
          'Das setzt den Streak zurück und ist für deine Freunde sichtbar. '
          'Ehrlich bleiben ist der ganze Sinn — aber nur, wenn es stimmt.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(120, 44),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eintragen'),
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
                  '${challenge.tier.emoji} ${challenge.tier.nameDe} · '
                  'Level ${levelForXp(snapshot.me.lifetimeXp)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                ),
              ],
            ),
          ),
          Pill(
            '${snapshot.me.lifetimeXp} XP',
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
    return AppCard(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => WorkoutDetailScreen(
            workout: workout,
            titleSuffix: 'Tag ${challenge.dayNumber(day)}',
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
                    Text(workout.nameDe,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      workout.focusDe,
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
              Pill('${workout.blocks.length} Übungen'),
              Pill('${workout.totalSets} Sätze'),
              Pill('≈ ${workout.estimatedMinutes} Min'),
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
    return AppCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: StatTile(
              value: '${plan.kcal}',
              label: 'kcal',
              color: AppColors.flame,
            ),
          ),
          Expanded(
            child: StatTile(
              value: '${plan.proteinG}g',
              label: 'Protein',
              color: AppColors.lime,
            ),
          ),
          Expanded(
            child: StatTile(value: '${plan.carbsG}g', label: 'Carbs'),
          ),
          Expanded(
            child: StatTile(value: '${plan.fatG}g', label: 'Fett'),
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
                Text('Streak einfrieren',
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  'Noch $remaining übrig. Rettet den Streak, zählt aber '
                  'nicht als erledigter Tag.',
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
            child: const Text('Nutzen'),
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
    final ChallengeTier next = tierForCycle(challenge.cycle + 1);
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
            'Zyklus geschafft: ${challenge.lengthDays} Tage.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Hier hören die meisten Apps auf. Deine nächste Stufe: '
            '${next.emoji} ${next.nameDe}. Streak, XP und Historie bleiben.',
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
            child: Text('Weiter zu ${next.nameDe}'),
          ),
        ],
      ),
    );
  }
}
