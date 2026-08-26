import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'friend_detail.dart';
import 'friends_tab.dart';
import 'league_tab.dart';

/// Feed, league and friends — the part that turns a tracker into pressure.
class SocialScreen extends ConsumerWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppSnapshot> async = ref.watch(appStateProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) => Center(child: Text('$error')),
      data: (AppSnapshot snapshot) => DefaultTabController(
        length: 3,
        child: Column(
          children: <Widget>[
            TabBar(
              labelColor: AppColors.flame,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.flame,
              dividerColor: AppColors.outline,
              tabs: <Widget>[
                Tab(text: context.l10n.socialTabFeed),
                Tab(text: context.l10n.socialTabLeague),
                Tab(
                  text: context.l10n.socialTabFriends(snapshot.friends.length),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _FeedTab(snapshot: snapshot),
                  LeagueTab(snapshot: snapshot),
                  FriendsTab(snapshot: snapshot),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedTab extends ConsumerWidget {
  const _FeedTab({required this.snapshot});

  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (snapshot.activity.isEmpty) {
      return EmptyState(
        emoji: '📡',
        title: context.l10n.feedEmptyTitle,
        body: context.l10n.feedEmptyBody,
      );
    }

    return RefreshIndicator(
      color: AppColors.flame,
      backgroundColor: AppColors.surface,
      onRefresh: () => ref.read(appStateProvider.notifier).syncNow(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        itemCount: snapshot.activity.length,
        itemBuilder: (BuildContext context, int index) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
          child: _ActivityRow(
            item: snapshot.activity[index],
            snapshot: snapshot,
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends ConsumerWidget {
  const _ActivityRow({required this.item, required this.snapshot});

  final ActivityItem item;
  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final Color accent = _accent();
    final String? detail = l10n.activityDetail(item);
    return AppCard(
      onTap: item.isOwn
          ? null
          : () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      FriendDetailScreen(did: item.author),
                ),
              ),
      border: item.kind == ActivityKind.relapse
          ? AppColors.danger.withValues(alpha: 0.4)
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              EmojiAvatar(item.authorEmoji, size: 42),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Text(item.emoji,
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.activityHeadline(item),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: accent),
                ),
                if (detail != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                // Wrap rather than Row: on a narrow phone the timestamp, the
                // verification badge and the cheer button do not fit on one
                // line, and a feed row must never clip.
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      l10n.formatRelative(item.timestamp),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.textTertiary),
                    ),
                    if (item.isVerifiedLive)
                      Pill(
                        l10n.feedVerified,
                        color: AppColors.lime,
                        icon: Icons.verified_outlined,
                      )
                    else
                      Pill(l10n.feedBackfilledBadge,
                          color: AppColors.textTertiary),
                    if (!item.isOwn && item.kind == ActivityKind.checkIn)
                      _CheerButton(
                        item: item,
                        alreadyCheered:
                            snapshot.cheeredEvents.contains(item.eventHash),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _accent() {
    switch (item.kind) {
      case ActivityKind.relapse:
        return AppColors.danger;
      case ActivityKind.milestone:
      case ActivityKind.ascend:
        return AppColors.lime;
      case ActivityKind.nudge:
        return AppColors.violet;
      case ActivityKind.cheer:
        return AppColors.flame;
      case ActivityKind.checkIn:
      case ActivityKind.start:
        return AppColors.textPrimary;
    }
  }
}

class _CheerButton extends ConsumerWidget {
  const _CheerButton({required this.item, required this.alreadyCheered});

  final ActivityItem item;
  final bool alreadyCheered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return TextButton.icon(
      onPressed: alreadyCheered
          ? null
          : () => ref.read(appStateProvider.notifier).cheer(
                item.author,
                l10n.nudgeCheerRespect(item.emoji),
                eventHash: item.eventHash,
              ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        disabledForegroundColor: AppColors.flame,
      ),
      icon: Icon(
        alreadyCheered
            ? Icons.local_fire_department
            : Icons.whatshot_outlined,
        size: 16,
      ),
      label: Text(alreadyCheered ? l10n.feedCheered : l10n.feedCheer),
    );
  }
}
