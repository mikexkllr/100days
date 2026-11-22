import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/fire.dart';
import '../../theme/theme.dart';
import '../celebration/day_complete.dart';
import '../motion/rolling_number.dart';
import '../nutrition/diary_view.dart';
import '../plan/workout_detail.dart';
import '../settings/profile_edit_screen.dart';
import '../widgets/app_card.dart';
import '../widgets/day_board.dart';
import '../widgets/habit_tile.dart';
import '../widgets/juicy_button.dart';
import '../widgets/pressure_banner.dart';
import '../mascot/flame_mascot.dart';
import '../mascot/speech_bubble.dart';
import '../../data/app_prefs.dart';
import 'coach_card.dart';
import 'feeding.dart';
import '../motion/sounds.dart';
import 'reminder_card.dart';
import 'day_sheet.dart';
import 'streak_hero.dart';
import 'today.dart';

/// Today. The only screen most users open on most days.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onOpenSocial, this.onOpenStats});

  final VoidCallback? onOpenSocial;
  final VoidCallback? onOpenStats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnapshot = ref.watch(appStateProvider);

    return asyncSnapshot.when(
      loading: () => const FunkiLoader(),
      error: (Object error, StackTrace _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(context.l10n.errorGeneric('$error')),
        ),
      ),
      data: (AppSnapshot snapshot) => _HomeBody(
        snapshot: snapshot,
        onOpenSocial: onOpenSocial,
        onOpenStats: onOpenStats,
      ),
    );
  }
}

class _HomeBody extends ConsumerStatefulWidget {
  const _HomeBody({
    required this.snapshot,
    this.onOpenSocial,
    this.onOpenStats,
  });

  final AppSnapshot snapshot;
  final VoidCallback? onOpenSocial;
  final VoidCallback? onOpenStats;

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody> {
  /// What each habit's last check-in earned, and a counter per habit that
  /// replays its celebration.
  final Map<String, int> _xpGain = <String, int>{};
  final Map<String, int> _celebrations = <String, int>{};

  /// How full the row being held is — Funki watches it.
  final ValueNotifier<double> _holdFill = ValueNotifier<double>(0);

  /// Where Funki and the rows are, for the ember that flies between them,
  /// and a counter that makes him gulp when it lands.
  final GlobalKey _ringKey = GlobalKey(debugLabel: 'today-ring');
  final Map<String, GlobalKey> _tileKeys = <String, GlobalKey>{};
  int _feeds = 0;

  /// How long an undo stays offered, and how long friends wait for the push.
  static const Duration _undoWindow = Duration(seconds: 5);

  @override
  void dispose() {
    _holdFill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppSnapshot snapshot = widget.snapshot;
    final AppLocalizations l10n = context.l10n;
    final Challenge challenge = snapshot.challenge!;
    final DayKey today = snapshot.today;
    final DayLog? log = snapshot.me.logsByDay[today.toString()];
    final TodayState state = TodayState.of(snapshot);
    final Fire fire = state.fire;
    final List<Habit> todayHabits = state.habits;
    final List<Habit> otherHabits = challenge.habits
        .where((Habit h) => !todayHabits.contains(h) && !h.isRetiredOn(today))
        .toList();
    final Workout? workout = snapshot.plan?.workoutFor(challenge.startDay, today);
    // Day 100 of the *current* cycle, finished. The cycleOf check keeps the
    // card from reappearing on the same day after the user has ascended.
    // Day 100 of the current cycle done, or already behind: the way up stays
    // open until it is taken.
    final bool cycleDone = challenge.canAscend(
      today,
      lastDayDone: snapshot.me.streak.doneToday,
    );
    final int freezes =
        challenge.freezesLeftOn(today, snapshot.me.frozenDays);
    final _Yesterday? yesterday = _Yesterday.of(snapshot, freezes);
    _maybeTalkAboutLoss(snapshot, yesterday);
    final bool prefsTap = ref.watch(appPrefsProvider).tapToCheckIn;
    // The coach already says who was active; the banner would say it twice.
    final bool coachTellsPressure =
        selectTone(snapshot.toCoachContext()) == CoachTone.socialPressure;

    Widget tile(Habit habit, {bool scheduled = true}) => Padding(
          key: _tileKeys.putIfAbsent(
              habit.id, () => GlobalKey(debugLabel: 'tile-${habit.id}')),
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: HabitTile(
            key: ValueKey<String>('habit-${habit.id}'),
            habit: habit,
            streak: snapshot.me.habitStreaks[habit.id] ?? 0,
            entry: log?.entryFor(habit.id),
            fire: fire,
            scheduledToday: scheduled,
            xpGain: _xpGain[habit.id],
            celebration: _celebrations[habit.id] ?? 0,
            onCheckIn: (num value) => _checkIn(habit, value),
            onRelapse: () => _confirmRelapse(habit),
            onUndo: () => _undo(habit),
            onHoldFill: (double fill) => _holdFill.value = fill,
            tapToCheckIn: prefsTap,
          ),
        );

    return RefreshIndicator(
      color: AppColors.onPrimary,
      backgroundColor: AppColors.primary,
      onRefresh: () => ref.read(appStateProvider.notifier).syncNow(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          // The dock floats over the end of the list.
          AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          _Header(snapshot: snapshot, onOpenStats: widget.onOpenStats),
          const SizedBox(height: AppSpacing.sm),
          StreakHero(
            snapshot: snapshot,
            holdFill: _holdFill,
            ringKey: _ringKey,
            feeds: _feeds,
            onTapDay: (DayKey day) =>
                showDaySheet(context, snapshot: snapshot, day: day),
          ),
          if (yesterday != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _YesterdayCard(yesterday: yesterday, snapshot: snapshot),
          ],
          if (cycleDone) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _AscendCard(challenge: challenge),
          ],
          if (todayHabits.isEmpty)
            SectionHeader(l10n.homeQuestsTitle, subtitle: l10n.homeRestDay)
          else
            _TodayHeader(
              title: l10n.homeQuestsTitle,
              status:
                  l10n.homeDoneOfTotal(state.doneCount, todayHabits.length),
              lit: state.complete ? fire.light : null,
            ),
          for (final Habit habit in todayHabits) tile(habit),
          if (otherHabits.isNotEmpty) ...<Widget>[
            SectionHeader(
              l10n.homeOptional,
              subtitle: l10n.homeOptionalSubtitle,
            ),
            for (final Habit habit in otherHabits) tile(habit, scheduled: false),
          ],
          if (!ref.watch(appPrefsProvider).permissionAsked &&
              snapshot.me.logsByDay.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: ReminderPermissionCard(stage: flameStageFor(snapshot.me.streak.current)),
            ),
          if (!coachTellsPressure)
            PressureBanner(
              activePeers: snapshot.peerStates
                  .where((PeerState p) => p.activeToday)
                  .toList(),
              doneToday: snapshot.me.streak.doneToday,
              onTap: widget.onOpenSocial,
            ),
          // The way out for a day that cannot be done — offered, not pushed.
          if (snapshot.me.streak.atRisk &&
              snapshot.me.streak.current > 0 &&
              !state.frozen &&
              freezes > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _FreezeCard(remaining: freezes),
            ),
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
          const SizedBox(height: AppSpacing.md),
          const CoachCard(),
          const SizedBox(height: AppSpacing.md),
          _BoardCard(
            snapshot: snapshot,
            fire: fire,
            onTap: widget.onOpenStats,
          ),
          const _WidgetPromo(),
        ],
      ),
    );
  }

  /// The morning after a lost streak: Funki says so once, gently, and
  /// points at the next day — instead of the app opening on a bare 0. Not
  /// when yesterday can still be rescued: the card on Today offers that.
  void _maybeTalkAboutLoss(AppSnapshot snapshot, _Yesterday? yesterday) {
    final StreakStats streak = snapshot.me.streak;
    if (yesterday != null || streak.current > 0 || streak.doneToday) return;
    final int lost = _lastLostRun(snapshot);
    if (lost < 2) return;
    final String key = 'loss-${streak.completedDays}-$lost';
    if (ref.read(appPrefsProvider).lossShownFor == key) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || ref.read(appPrefsProvider).lossShownFor == key) return;
      await ref
          .read(appPrefsProvider.notifier)
          .update((AppPrefs p) => p.copyWith(lossShownFor: key));
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) => _LossSheet(
          lost: lost,
          stars: streak.completedDays,
        ),
      );
    });
  }

  /// The run that ended most recently: completed days back from the last
  /// done day, through held, frozen and rest days, to the miss before it.
  static int _lastLostRun(AppSnapshot snapshot) {
    final Challenge challenge = snapshot.challenge!;
    var run = 0;
    var counting = false;
    for (var day = snapshot.today.addDays(-1);
        !day.isBefore(challenge.startDay);
        day = day.addDays(-1)) {
      final DayMark mark = dayMarkFor(
        challenge: challenge,
        day: day,
        today: snapshot.today,
        logsByDay: snapshot.me.logsByDay,
        frozenDays: snapshot.me.frozenDays,
      );
      if (mark == DayMark.done) {
        counting = true;
        run++;
      } else if (mark == DayMark.missed && counting) {
        break;
      }
    }
    return run;
  }

  Future<void> _undo(Habit habit) async {
    HapticFeedback.selectionClick();
    await ref.read(appStateProvider.notifier).undoCheckIn(habit);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.tileUndone)));
  }

  /// The ember from the row to Funki — or to a small Funki peeking in at
  /// the top when the big one is scrolled out of sight.
  void _feed(Habit habit, Fire fire, FlameStage stage) {
    final RenderBox? tileBox =
        _tileKeys[habit.id]?.currentContext?.findRenderObject() as RenderBox?;
    if (tileBox == null || !tileBox.attached) return;
    final Offset from = tileBox.localToGlobal(
        Offset(tileBox.size.width - 60, tileBox.size.height / 2));
    final RenderBox? ringBox =
        _ringKey.currentContext?.findRenderObject() as RenderBox?;
    final double top = MediaQuery.paddingOf(context).top;
    Offset? ring;
    if (ringBox != null && ringBox.attached) {
      final Offset centre = ringBox.localToGlobal(
          Offset(ringBox.size.width / 2, ringBox.size.height * 0.58));
      if (centre.dy > top + 20) ring = centre;
    }
    final Offset to = ring ??
        Offset(MediaQuery.sizeOf(context).width - 48, top + 48);
    if (ring == null) showMiniFunki(context, at: to, stage: stage);
    flyEmber(
      context,
      from: from,
      to: to,
      fire: fire,
      onArrive: () {
        AppSounds.play(Sfx.gulp, volume: 0.7);
        if (!mounted || ring == null) return;
        HapticFeedback.lightImpact();
        setState(() => _feeds++);
      },
    );
  }

  Future<void> _checkIn(Habit habit, num value) async {
    final AppSnapshot before = widget.snapshot;
    _holdFill.value = 0;
    AppSounds.play(Sfx.ignite);
    _feed(habit, TodayState.of(before).fire,
        flameStageFor(before.me.streak.current));
    await ref
        .read(appStateProvider.notifier)
        .checkIn(habit, value: value, notifyDelay: _undoWindow);
    if (!mounted) return;
    final AppLocalizations l10nNow = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: _undoWindow,
        // With an action a snackbar would stay until dismissed; the undo
        // is an offer for the moment, not a fixture.
        persist: false,
        content: Text(
            l10nNow.homeCheckInToast(habit.emoji, l10nNow.habitLabel(habit))),
        action: SnackBarAction(
          label: l10nNow.tileUndo,
          onPressed: () => _undo(habit),
        ),
      ));

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
    // The slot machine for a completed day is rolled by the app shell, for
    // every way a day can be completed (see `celebrationProvider`).
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
              foregroundColor: AppColors.ink,
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

/// Yesterday was missed and the streak broke at midnight — but it can still
/// be logged late (it was done, just not ticked) or held with a freeze.
/// Offered on the day after only.
class _Yesterday {
  const _Yesterday({
    required this.day,
    required this.lostStreak,
    required this.freezesLeft,
  });

  final DayKey day;
  final int lostStreak;
  final int freezesLeft;

  static _Yesterday? of(AppSnapshot snapshot, int freezesLeft) {
    final Challenge challenge = snapshot.challenge!;
    final DayKey day = snapshot.today.addDays(-1);
    if (day.isBefore(challenge.startDay)) return null;
    final DayMark mark = dayMarkFor(
      challenge: challenge,
      day: day,
      today: snapshot.today,
      logsByDay: snapshot.me.logsByDay,
      frozenDays: snapshot.me.frozenDays,
    );
    if (mark != DayMark.missed) return null;
    // What the streak would be with yesterday held: worth saving only if
    // there was one.
    final StreakStats held = computeStreak(
      challenge: challenge,
      logsByDay: snapshot.me.logsByDay,
      frozenDays: <String>{...snapshot.me.frozenDays, day.toString()},
      today: snapshot.today,
    );
    if (held.current <= snapshot.me.streak.current || held.current == 0) {
      return null;
    }
    return _Yesterday(
      day: day,
      lostStreak: held.current,
      freezesLeft: freezesLeft,
    );
  }
}

class _YesterdayCard extends ConsumerWidget {
  const _YesterdayCard({required this.yesterday, required this.snapshot});

  final _Yesterday yesterday;
  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final bool canFreeze = yesterday.freezesLeft > 0;
    return AppCard(
      border: AppColors.danger.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.homeYesterdayTitle,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            canFreeze
                ? l10n.homeYesterdayBodyFreeze(
                    yesterday.lostStreak, yesterday.freezesLeft)
                : l10n.homeYesterdayBody(yesterday.lostStreak),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              OutlinedButton.icon(
                key: const Key('yesterday-log'),
                onPressed: () => showDaySheet(
                  context,
                  snapshot: snapshot,
                  day: yesterday.day,
                ),
                icon: const Icon(Icons.edit_calendar, size: 18),
                label: Text(l10n.homeYesterdayLog),
              ),
              if (canFreeze)
                OutlinedButton.icon(
                  key: const Key('yesterday-freeze'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.cool),
                  onPressed: () async {
                    if (!await confirmFreeze(
                        context, yesterday.freezesLeft - 1)) {
                      return;
                    }
                    await ref
                        .read(appStateProvider.notifier)
                        .useStreakFreeze(day: yesterday.day);
                  },
                  icon: const Icon(Icons.ac_unit, size: 18),
                  label: Text(l10n.homeYesterdayFreeze),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LossSheet extends StatelessWidget {
  const _LossSheet({required this.lost, required this.stars});

  final int lost;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SpeechBubble(text: l10n.lossFunki),
            const FlameMascot(
              stage: FlameStage.ember,
              mood: MascotMood.hopeful,
              size: 130,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.lossTitle(lost),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.lossBody(stars),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            JuicyButton(
              key: const Key('loss-relight'),
              label: l10n.lossRelight,
              icon: Icons.local_fire_department,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Freezes are scarce and cannot be taken back: ask once.
Future<bool> confirmFreeze(BuildContext context, int leftAfter) async {
  final AppLocalizations l10n = context.l10n;
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(l10n.homeFreezeConfirmTitle),
      content: Text(l10n.homeFreezeConfirmBody(leftAfter)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('freeze-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.cool,
            foregroundColor: AppColors.ink,
            minimumSize: const Size(110, 44),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.homeFreezeUse),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// The line over today's habits: what this list is and how far it is.
class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.title, required this.status, this.lit});

  final String title;
  final String status;

  /// Set once everything is done: the count is lit in this colour.
  final Color? lit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, AppSpacing.lg, 2, AppSpacing.sm + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Text(
              status,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: lit ?? AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The title of Today is the day itself: "Day 13 / 100".
class _Header extends StatelessWidget {
  const _Header({required this.snapshot, this.onOpenStats});

  final AppSnapshot snapshot;
  final VoidCallback? onOpenStats;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Challenge challenge = snapshot.challenge!;
    final int xp = snapshot.me.lifetimeXp;
    final int level = levelForXp(xp);
    final String day = l10n.ringDayOfTotal(
      challenge.dayNumber(snapshot.today),
      challenge.lengthDays * (challenge.cycle + 1),
    );
    // "Day 13" is the title; "/ 100" stands back.
    final int slash = day.indexOf('/');
    final TextStyle title = Theme.of(context).appBarTheme.titleTextStyle!;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm + 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                  slash < 0
                      ? TextSpan(text: day)
                      : TextSpan(
                          children: <TextSpan>[
                            TextSpan(text: day.substring(0, slash)),
                            TextSpan(
                              text: day.substring(slash),
                              style:
                                  const TextStyle(color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                  maxLines: 1,
                  style: title,
                ),
                ),
                Text(
                  l10n.homeLevelAndTier(
                    challenge.tier.emoji,
                    l10n.tierName(challenge.tier),
                    level,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onOpenStats,
            child: _XpBadge(xp: xp, progress: levelProgress(xp)),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Semantics(
            button: true,
            label: l10n.profileEditTitle,
            child: GestureDetector(
              key: const Key('home-avatar'),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const ProfileEditScreen(),
                ),
              ),
              child: EmojiAvatar(snapshot.me.profile.avatarEmoji, size: 42),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lifetime XP as a counter with the level bar under it.
class _XpBadge extends StatelessWidget {
  const _XpBadge({required this.xp, required this.progress});

  final int xp;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.fromLTRB(10, 0, 13, 0),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: 0.8),
        borderRadius: AppRadius.pill,
        border: Border.all(color: AppColors.glassEdge),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.bolt, size: 16, color: AppColors.reward),
              const SizedBox(width: 2),
              RollingNumber(
                value: xp,
                suffix: ' XP',
                style: const TextStyle(
                  fontFamily: kTextFont,
                  fontSize: 13.5,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 62,
            child: ClipRRect(
              borderRadius: AppRadius.pill,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double value, Widget? _) =>
                    LinearProgressIndicator(
                  value: math.max(0.04, value),
                  minHeight: 3,
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

/// The whole cycle at a glance: every day as a lamp. Opens the numbers.
class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.snapshot, required this.fire, this.onTap});

  final AppSnapshot snapshot;
  final Fire fire;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Challenge challenge = snapshot.challenge!;
    final List<DayMark> marks = cycleMarks(snapshot);
    final int done = marks.where((DayMark m) => m == DayMark.done).length;
    final int dayInCycle = challenge.dayInCycle(snapshot.today);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.boardTitle(challenge.lengthDays),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Flexible(
                child: Text(
                  l10n.boardSummary(
                      done, math.max(0, challenge.lengthDays - dayInCycle)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Twenty to a row keeps the board a strip here; the numbers
          // screen shows it ten by ten.
          IgnorePointer(
            child: DayBoard(
              marks: marks,
              fire: fire,
              todayIndex: dayInCycle - 1,
              columns: 20,
              gap: 4,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.widgets_outlined, color: AppColors.textPrimary),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppColors.cool.withValues(alpha: 0.14),
            ),
            child: const Icon(Icons.ac_unit, size: 21, color: AppColors.cool),
          ),
          const SizedBox(width: 12),
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
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
          TextButton(
            key: const Key('freeze-use'),
            onPressed: () async {
              if (!await confirmFreeze(context, remaining - 1)) return;
              await ref.read(appStateProvider.notifier).useStreakFreeze();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.cool),
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
    final ChallengeTier next =
        tierForCycle(challenge.ascentTarget(DayKey.today()));
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
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => showAscendCelebration(
              context,
              tierName: nextName,
              tierEmoji: next.emoji,
              stage: flameStageFor(
                  ref.read(appStateProvider).valueOrNull?.me.streak.current ??
                      0),
              onAscend: () => ref.read(appStateProvider.notifier).ascend(),
            ),
            child: Text(l10n.homeAscendAction(nextName)),
          ),
        ],
      ),
    );
  }
}
