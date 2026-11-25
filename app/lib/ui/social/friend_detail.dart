import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import '../widgets/heatmap.dart';
import 'friend_flame.dart';
import 'moderation.dart';
import 'together_card.dart';

/// One friend, in detail — and the two buttons that make the app social.
class FriendDetailScreen extends ConsumerWidget {
  const FriendDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<AppSnapshot> async = ref.watch(appStateProvider);
    final AppSnapshot? loaded = async.valueOrNull;
    final UserProjection? shown = loaded?.friends
        .where((UserProjection f) => f.userId == userId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: <Widget>[
          if (shown != null)
            PopupMenuButton<String>(
              key: const Key('profile-menu'),
              onSelected: (String choice) =>
                  _moderate(context, ref, choice, shown.profile.displayName),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'report',
                  child: Text(l10n.moderationReport),
                ),
                PopupMenuItem<String>(
                  value: 'block',
                  child: Text(l10n.moderationBlock),
                ),
              ],
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Center(child: Text('$error')),
        data: (AppSnapshot snapshot) {
          final UserProjection? friend = <UserProjection>[
            snapshot.me,
            ...snapshot.friends,
          ].where((UserProjection f) => f.userId == userId).firstOrNull;

          if (friend == null) {
            return EmptyState(
              emoji: '🕳️',
              title: l10n.profileUnknownTitle,
              body: l10n.profileUnknownBody,
            );
          }

          final PeerState peer = friend.toPeerState(today: snapshot.today);
          final bool isMe = friend.userId == snapshot.me.userId;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              AppCard(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    (peer.activeToday ? AppColors.success : AppColors.social)
                        .withValues(alpha: 0.16),
                    AppColors.surface,
                  ],
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        FriendFlame(
                          key: const Key('profile-flame'),
                          person: friend,
                          today: snapshot.today,
                          size: 64,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(peer.profile.displayName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                              Text(
                                l10n.homeLevelAndTier(
                                  peer.tier.emoji,
                                  l10n.tierName(peer.tier),
                                  peer.level,
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 12.5,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (peer.profile.goalStatement != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '"${peer.profile.goalStatement}"',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: StatTile(
                            value: '${peer.currentStreak}',
                            label: l10n.statStreak,
                            color: AppColors.primary,
                          ),
                        ),
                        Expanded(
                          child: StatTile(
                            value: '${peer.longestStreak}',
                            label: l10n.statRecord,
                          ),
                        ),
                        Expanded(
                          child: StatTile(
                            value: '${peer.dayNumber}',
                            label: l10n.statDay,
                          ),
                        ),
                        Expanded(
                          child: StatTile(
                            value: '${peer.lifetimeXp}',
                            label: l10n.statXp,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isMe) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                // Both phones compute this from what friends can see of
                // each of them, so they show the same numbers.
                TogetherCard(
                  me: snapshot.meAsFriendsSeeMe,
                  friend: friend,
                  today: snapshot.today,
                ),
                const SizedBox(height: AppSpacing.md),
                _ProfileActions(
                  snapshot: snapshot,
                  friendId: friend.userId,
                  peer: peer,
                ),
              ],
              if (friend.challenge != null) ...<Widget>[
                SectionHeader(l10n.profileHistory),
                AppCard(
                  child: Column(
                    children: <Widget>[
                      ChallengeHeatmap(
                        startDay: friend.challenge!.startDay,
                        today: snapshot.today,
                        intensityForDay: (DayKey day) {
                          final DayLog? log = friend.logsByDay[day.toString()];
                          if (log == null || log.entries.isEmpty) return 0;
                          if (log.hasRelapse) return 0.25;
                          return (log.entries.length /
                                  friend.challenge!.habits.length)
                              .clamp(0.25, 1.0);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const HeatmapLegend(),
                    ],
                  ),
                ),
                SectionHeader(l10n.profileHabits),
                for (final Habit habit in friend.challenge!.habits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 4,
                      ),
                      child: Row(
                        children: <Widget>[
                          Text(habit.emoji,
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: AppSpacing.sm + 4),
                          Expanded(
                            child: Text(l10n.habitLabel(habit),
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                          ),
                          Text(
                            l10n.profileDaysCount(
                                friend.habitStreaks[habit.id] ?? 0),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (!isMe) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                TextButton.icon(
                  key: const Key('profile-disconnect'),
                  onPressed: () => _confirmRemove(context, ref, peer),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger),
                  icon: const Icon(Icons.person_remove_outlined, size: 18),
                  label: Text(l10n.profileDisconnect),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _moderate(
    BuildContext context,
    WidgetRef ref,
    String choice,
    String name,
  ) async {
    final bool blocked = choice == 'report'
        ? await reportPerson(context, ref, userId: userId, name: name)
        : await confirmAndBlock(context, ref, userId: userId, name: name);
    // Nothing of theirs is left to show.
    if (blocked && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    PeerState peer,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.profileRemoveTitle(peer.profile.displayName)),
        content: Text(l10n.profileRemoveBody),
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
            child: Text(l10n.actionRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(appStateProvider.notifier).removeFriend(peer.userId);
    } on Object {
      // Nothing changed on the server; say so rather than closing as if it
      // had worked.
      messenger.showSnackBar(SnackBar(content: Text(l10n.inviteErrorOffline)));
      return;
    }
    if (context.mounted) Navigator.of(context).pop();
  }
}

/// Nudge and cheer, by the same rules as everywhere else: one nudge a day
/// per friend, one cheer per check-in — and never two for one tap.
class _ProfileActions extends ConsumerStatefulWidget {
  const _ProfileActions({
    required this.snapshot,
    required this.friendId,
    required this.peer,
  });

  final AppSnapshot snapshot;
  final String friendId;
  final PeerState peer;

  @override
  ConsumerState<_ProfileActions> createState() => _ProfileActionsState();
}

class _ProfileActionsState extends ConsumerState<_ProfileActions> {
  bool _sending = false;

  /// Their newest check-in or workout: what a cheer from here is for, so it
  /// counts against the same once-per-check-in rule as the feed's.
  ActivityItem? get _cheerable => widget.snapshot.activity
      .where((ActivityItem item) =>
          item.author == widget.friendId &&
          (item.kind == ActivityKind.checkIn ||
              item.kind == ActivityKind.workout))
      .firstOrNull;

  Future<void> _send({required bool nudge, required String text}) async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppController controller = ref.read(appStateProvider.notifier);
    // The buttons may not have rebuilt since the last tap: ask the feed.
    final AppSnapshot? latest = ref.read(appStateProvider).valueOrNull;
    final String? cheerFor = _cheerable?.eventId;
    final bool done = nudge
        ? latest?.nudgedToday.contains(widget.friendId) ?? false
        : cheerFor == null || (latest?.cheeredEvents.contains(cheerFor) ?? false);
    if (_sending || done) return;
    setState(() => _sending = true);
    try {
      if (nudge) {
        puffAt(ref, widget.friendId);
        await controller.nudge(widget.friendId, text);
      } else {
        await controller.cheer(widget.friendId, text, eventId: cheerFor);
      }
      messenger.showSnackBar(SnackBar(
        content: Text(nudge ? l10n.profileNudgeSent : l10n.profileCheerSent),
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool nudged = widget.snapshot.nudgedToday.contains(widget.friendId);
    final ActivityItem? cheerable = _cheerable;
    final bool cheered = cheerable != null &&
        widget.snapshot.cheeredEvents.contains(cheerable.eventId);
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            key: const Key('profile-nudge'),
            onPressed: nudged || _sending
                ? null
                : () => _send(
                      nudge: true,
                      text: widget.peer.activeToday
                          ? l10n.nudgeStrongToday
                          : l10n.nudgeDefaultPoke,
                    ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: AppColors.social,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppColors.social.withValues(alpha: 0.25),
              disabledForegroundColor: Colors.white70,
            ),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: Text(nudged ? l10n.profileNudgedToday : l10n.profileNudge),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('profile-cheer'),
            // Nothing to cheer yet, or this check-in already got one.
            onPressed: cheerable == null || cheered || _sending
                ? null
                : () => _send(
                      nudge: false,
                      text: l10n.cheerRespectStreak(widget.peer.currentStreak),
                    ),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
            icon: Icon(
              cheered ? Icons.local_fire_department : Icons.whatshot_outlined,
              size: 18,
            ),
            label: Text(cheered ? l10n.feedCheered : l10n.profileCheer),
          ),
        ),
      ],
    );
  }
}
