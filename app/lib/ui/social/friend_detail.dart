import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import '../widgets/heatmap.dart';

/// One friend, in detail — and the two buttons that make the app social.
class FriendDetailScreen extends ConsumerWidget {
  const FriendDetailScreen({super.key, required this.did});

  final String did;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppSnapshot> async = ref.watch(appStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Center(child: Text('$error')),
        data: (AppSnapshot snapshot) {
          final UserProjection? friend = <UserProjection>[
            snapshot.me,
            ...snapshot.friends,
          ].where((UserProjection f) => f.did == did).firstOrNull;

          if (friend == null) {
            return const EmptyState(
              emoji: '🕳️',
              title: 'Unbekannt',
              body: 'Zu dieser Identität liegt nichts auf deinem Gerät.',
            );
          }

          final PeerState peer = friend.toPeerState(today: snapshot.today);
          final bool isMe = friend.did == snapshot.me.did;

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
                    (peer.activeToday ? AppColors.lime : AppColors.violet)
                        .withValues(alpha: 0.16),
                    AppColors.surface,
                  ],
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        EmojiAvatar(
                          peer.profile.avatarEmoji,
                          size: 58,
                          ringColor:
                              peer.activeToday ? AppColors.lime : null,
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
                                '${peer.tier.emoji} ${peer.tier.nameDe} · '
                                'Level ${peer.level}',
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
                            label: 'Streak',
                            color: AppColors.flame,
                          ),
                        ),
                        Expanded(
                          child: StatTile(
                            value: '${peer.longestStreak}',
                            label: 'Rekord',
                          ),
                        ),
                        Expanded(
                          child: StatTile(
                            value: '${peer.dayNumber}',
                            label: 'Tag',
                          ),
                        ),
                        Expanded(
                          child: StatTile(
                            value: '${peer.lifetimeXp}',
                            label: 'XP',
                            color: AppColors.lime,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isMe) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _send(
                          context,
                          ref,
                          nudge: true,
                          text: peer.activeToday
                              ? 'Stark heute. Morgen wieder?'
                              : 'Ich war heute schon. Und du?',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: AppColors.violet,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Anstupsen'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _send(
                          context,
                          ref,
                          nudge: false,
                          text: 'Respekt, ${peer.currentStreak} Tage!',
                        ),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                        icon: const Icon(Icons.whatshot_outlined, size: 18),
                        label: const Text('Feiern'),
                      ),
                    ),
                  ],
                ),
              ],
              if (friend.challenge != null) ...<Widget>[
                const SectionHeader('Verlauf'),
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
                const SectionHeader('Gewohnheiten'),
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
                            child: Text(habit.displayTitle,
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                          ),
                          Text(
                            '${friend.habitStreaks[habit.id] ?? 0} Tage',
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
                  onPressed: () => _confirmRemove(context, ref, peer),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger),
                  icon: const Icon(Icons.person_remove_outlined, size: 18),
                  label: const Text('Verbindung trennen'),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    Identity.shortDid(peer.did),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textTertiary,
                          fontFamily: 'monospace',
                        ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _send(
    BuildContext context,
    WidgetRef ref, {
    required bool nudge,
    required String text,
  }) async {
    final controller = ref.read(appStateProvider.notifier);
    if (nudge) {
      await controller.nudge(did, text);
    } else {
      await controller.cheer(did, text);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nudge ? 'Anstupser gesendet.' : 'Gefeiert.'),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    PeerState peer,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('${peer.profile.displayName} entfernen?'),
        content: const Text(
          'Die komplette Historie dieser Person wird von deinem Gerät '
          'gelöscht. Rückgängig geht das nur durch erneutes Verbinden.',
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
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(appStateProvider.notifier).removeFriend(peer.did);
    if (context.mounted) Navigator.of(context).pop();
  }
}
