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
import '../mascot/flame_mascot.dart';

/// Feed, league and friends — the part that turns a tracker into pressure.
class SocialScreen extends ConsumerWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppSnapshot> async = ref.watch(appStateProvider);

    return async.when(
      loading: () => const FunkiLoader(),
      error: (Object error, StackTrace _) => Center(child: Text('$error')),
      data: (AppSnapshot snapshot) => DefaultTabController(
        length: 3,
        child: Column(
          children: <Widget>[
            GlassTabBar(
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

/// One card of the feed: a person's check-ins and workouts of one day, or
/// an event that stands on its own (a start, an ascent, a nudge, a cheer).
class FeedCard {
  FeedCard._(this.items, {required this.day});

  /// Newest first.
  final List<ActivityItem> items;

  /// The day a person's entries were for; null for an event on its own.
  final DayKey? day;

  ActivityItem get newest => items.first;
  bool get isDay => day != null;

  /// What a cheer from this card is for: the newest check-in or workout.
  /// Relapses are not cheered.
  ActivityItem? get cheerable => items
      .where((ActivityItem i) =>
          i.kind == ActivityKind.checkIn || i.kind == ActivityKind.workout)
      .firstOrNull;
}

/// Bundles [activity] (newest first) into one card per person and day.
/// Eight habits are one day, not eight posts; the order stays newest first,
/// by each card's newest entry.
List<FeedCard> groupActivity(List<ActivityItem> activity) {
  final List<FeedCard> cards = <FeedCard>[];
  final Map<String, FeedCard> byPersonAndDay = <String, FeedCard>{};
  for (final ActivityItem item in activity) {
    final bool partOfDay = item.kind == ActivityKind.checkIn ||
        item.kind == ActivityKind.relapse ||
        item.kind == ActivityKind.workout;
    if (!partOfDay) {
      cards.add(FeedCard._(<ActivityItem>[item], day: null));
      continue;
    }
    final DayKey day = item.claimedDay ?? DayKey.fromDateTime(item.timestamp);
    final String key = '${item.author}|$day';
    final FeedCard? card = byPersonAndDay[key];
    if (card != null) {
      card.items.add(item);
    } else {
      cards.add(byPersonAndDay[key] = FeedCard._(<ActivityItem>[item], day: day));
    }
  }
  return cards;
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
    final List<FeedCard> cards = groupActivity(snapshot.activity);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => ref.read(appStateProvider.notifier).syncNow(),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          // The dock floats over the end of the list.
          AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: cards.length,
        itemBuilder: (BuildContext context, int index) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
          child: _FeedCardView(card: cards[index], snapshot: snapshot),
        ),
      ),
    );
  }
}

class _FeedCardView extends ConsumerWidget {
  const _FeedCardView({required this.card, required this.snapshot});

  final FeedCard card;
  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final ActivityItem newest = card.newest;
    final bool single = card.items.length == 1;
    final int checkIns = card.items
        .where((ActivityItem i) => i.kind == ActivityKind.checkIn)
        .length;
    final String headline = single || checkIns == 0
        ? l10n.activityHeadline(newest)
        : l10n.feedCheckIns(newest.authorName, checkIns);
    final String? detail = single ? l10n.activityDetail(newest) : null;
    final bool relapse =
        card.items.any((ActivityItem i) => i.kind == ActivityKind.relapse);
    final ActivityItem? cheerable = newest.isOwn ? null : card.cheerable;
    final List<String> notes = <String>[
      if (!single)
        for (final ActivityItem i in card.items)
          if (i.note != null && i.note!.isNotEmpty) i.note!,
    ];

    return AppCard(
      key: Key('feed-card-${newest.eventId}'),
      onTap: newest.isOwn
          ? null
          : () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      FriendDetailScreen(userId: newest.author),
                ),
              ),
      border: relapse ? AppColors.danger.withValues(alpha: 0.4) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              EmojiAvatar(newest.authorEmoji, size: 42),
              if (single)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.ink,
                      shape: BoxShape.circle,
                    ),
                    child: Text(newest.emoji,
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
                  headline,
                  style: text.titleMedium?.copyWith(color: _accent(newest)),
                ),
                if (detail != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                if (!single) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs + 2),
                  Wrap(
                    spacing: AppSpacing.xs + 2,
                    runSpacing: AppSpacing.xs + 2,
                    children: <Widget>[
                      // Oldest first inside a day: the order they were done.
                      for (final ActivityItem i in card.items.reversed)
                        _EntryChip(item: i),
                    ],
                  ),
                  for (final String note in notes)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        '"$note"',
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.formatRelative(newest.timestamp),
                        style: text.labelSmall
                            ?.copyWith(color: AppColors.textTertiary),
                      ),
                    ),
                    if (cheerable != null)
                      _CheerButton(
                        item: cheerable,
                        alreadyCheered: card.items.any((ActivityItem i) =>
                            snapshot.cheeredEvents.contains(i.eventId)),
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

  Color _accent(ActivityItem item) {
    switch (item.kind) {
      case ActivityKind.relapse:
        return AppColors.danger;
      case ActivityKind.milestone:
      case ActivityKind.ascend:
        return AppColors.success;
      case ActivityKind.nudge:
        return AppColors.social;
      case ActivityKind.cheer:
        return AppColors.primary;
      case ActivityKind.checkIn:
      case ActivityKind.start:
      case ActivityKind.workout:
        return AppColors.textPrimary;
    }
  }
}

/// One entry of a day: the habit, a relapse in red, a workout with its
/// sets. Only the exception — an entry made after its day — says so.
class _EntryChip extends StatelessWidget {
  const _EntryChip({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool relapse = item.kind == ActivityKind.relapse;
    final String label = item.kind == ActivityKind.workout
        ? '${l10n.workoutName(item.workoutKind ?? WorkoutKind.fullBodyA)}'
            ' · ${l10n.activityDetail(item) ?? ''}'
        : l10n.habitTitle(item.category ?? HabitCategory.custom);
    final Color color = relapse ? AppColors.danger : AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.pill,
        border: Border.all(
          color: relapse
              ? AppColors.danger.withValues(alpha: 0.5)
              : AppColors.outline,
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(text: '${item.emoji} '),
            TextSpan(text: label),
            if (!item.isVerifiedLive)
              TextSpan(
                text: ' · ${l10n.feedBackfilledBadge}',
                style: const TextStyle(color: AppColors.textTertiary),
              ),
          ],
        ),
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: color, fontSize: 12),
      ),
    );
  }
}

class _CheerButton extends ConsumerStatefulWidget {
  const _CheerButton({required this.item, required this.alreadyCheered});

  final ActivityItem item;
  final bool alreadyCheered;

  @override
  ConsumerState<_CheerButton> createState() => _CheerButtonState();
}

class _CheerButtonState extends ConsumerState<_CheerButton> {
  /// Until the cheer is in the feed, a second tap would send another.
  bool _sending = false;

  Future<void> _cheer(String text) async {
    // The button may not have rebuilt since the last tap: ask the feed.
    final bool cheered = ref
            .read(appStateProvider)
            .valueOrNull
            ?.cheeredEvents
            .contains(widget.item.eventId) ??
        false;
    if (_sending || cheered) return;
    setState(() => _sending = true);
    try {
      await ref.read(appStateProvider.notifier).cheer(
            widget.item.author,
            text,
            eventId: widget.item.eventId,
          );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool cheered = widget.alreadyCheered;
    return TextButton.icon(
      key: Key('cheer-${widget.item.eventId}'),
      onPressed: cheered || _sending
          ? null
          : () => _cheer(l10n.nudgeCheerRespect(widget.item.emoji)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        disabledForegroundColor: AppColors.primary,
      ),
      icon: Icon(
        cheered ? Icons.local_fire_department : Icons.whatshot_outlined,
        size: 16,
      ),
      label: Text(cheered ? l10n.feedCheered : l10n.feedCheer),
    );
  }
}
