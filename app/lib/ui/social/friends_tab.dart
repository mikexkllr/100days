import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'friend_detail.dart';
import 'invite_screen.dart';
import 'scan_screen.dart';

/// Your people, and the ready-made jabs to throw at them.
class FriendsTab extends ConsumerWidget {
  const FriendsTab({super.key, required this.snapshot});

  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<NudgeSuggestion>> nudges =
        ref.watch(nudgeSuggestionsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const InviteScreen(),
                  ),
                ),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.qr_code_2, size: 19),
                label: const Text('Einladen'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _scan(context, ref),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.qr_code_scanner, size: 19),
                label: const Text('Scannen'),
              ),
            ),
          ],
        ),
        if (snapshot.friends.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxl),
            child: EmptyState(
              emoji: '👥',
              title: 'Noch niemand verbunden',
              body: 'Die App funktioniert allein — aber sie wirkt erst, wenn '
                  'jemand zuschaut. Zeig einem Freund deinen QR-Code.',
            ),
          )
        else ...<Widget>[
          nudges.maybeWhen(
            data: (List<NudgeSuggestion> items) => items.isEmpty
                ? const SizedBox.shrink()
                : _NudgeSection(suggestions: items, snapshot: snapshot),
            orElse: () => const SizedBox.shrink(),
          ),
          const SectionHeader('Deine Leute'),
          for (final UserProjection friend in snapshot.friends)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _FriendRow(
                friend: friend,
                today: snapshot.today,
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          color: AppColors.surfaceHigh,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.hub_outlined, size: 19, color: AppColors.violet),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  'Verbindungen laufen direkt zwischen euren Geräten — im '
                  'gleichen WLAN sofort, sonst beim nächsten Treffen. Kein '
                  'Server dazwischen, der eure Streaks kennt.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final String? raw = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => const ScanInviteScreen(),
      ),
    );
    if (raw == null || !context.mounted) return;

    try {
      final Invite invite = Invite.parse(raw);
      await ref.read(appStateProvider.notifier).addFriend(invite);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${invite.displayName} verbunden.')),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Einladung ungültig: $error')),
      );
    }
  }
}

class _NudgeSection extends ConsumerWidget {
  const _NudgeSection({required this.suggestions, required this.snapshot});

  final List<NudgeSuggestion> suggestions;
  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          'Anstupsen',
          subtitle: 'Die hier waren heute noch nicht dran.',
        ),
        for (final NudgeSuggestion suggestion in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _NudgeCard(
              suggestion: suggestion,
              profile: snapshot.profiles[suggestion.targetDid],
              alreadySent: snapshot.nudgedToday.contains(suggestion.targetDid),
            ),
          ),
      ],
    );
  }
}

class _NudgeCard extends ConsumerWidget {
  const _NudgeCard({
    required this.suggestion,
    required this.alreadySent,
    this.profile,
  });

  final NudgeSuggestion suggestion;
  final bool alreadySent;
  final PeerProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      border: AppColors.violet.withValues(alpha: 0.35),
      child: Row(
        children: <Widget>[
          EmojiAvatar(profile?.avatarEmoji ?? '🙂', size: 38),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  profile?.displayName ?? 'Freund',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '"${suggestion.text}"',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: alreadySent
                ? null
                : () => ref.read(appStateProvider.notifier).nudge(
                      suggestion.targetDid,
                      suggestion.text,
                    ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(86, 40),
              backgroundColor: AppColors.violet,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppColors.violet.withValues(alpha: 0.25),
              disabledForegroundColor: Colors.white70,
            ),
            child: Text(alreadySent ? 'Gesendet' : 'Senden'),
          ),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.today});

  final UserProjection friend;
  final DayKey today;

  @override
  Widget build(BuildContext context) {
    final PeerState peer = friend.toPeerState(today: today);
    return AppCard(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              FriendDetailScreen(did: friend.did),
        ),
      ),
      child: Row(
        children: <Widget>[
          EmojiAvatar(
            peer.profile.avatarEmoji,
            size: 46,
            ringColor: peer.activeToday ? AppColors.lime : null,
            dimmed: !peer.activeToday,
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(peer.profile.displayName,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  peer.lastActivityAt == null
                      ? 'Noch keine Aktivität'
                      : '${peer.lastActivityLabel} · '
                          '${formatRelative(peer.lastActivityAt!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: peer.activeToday
                            ? AppColors.lime
                            : AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text('${peer.currentStreak}🔥',
                  style: Theme.of(context).textTheme.titleMedium),
              Text(
                'Tag ${peer.dayNumber}',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
