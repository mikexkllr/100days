import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'find_friends_screen.dart';
import 'friend_detail.dart';
import 'friend_flame.dart';
import 'invite_flow.dart';
import 'moderation.dart';
import 'scan_screen.dart';

/// Your people, and the ready-made jabs to throw at them.
class FriendsTab extends ConsumerWidget {
  const FriendsTab({super.key, required this.snapshot});

  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<NudgeSuggestion>> nudges =
        ref.watch(nudgeSuggestionsProvider);
    final List<FriendLink> requests = snapshot.incomingRequests;
    final List<FriendLink> sent = snapshot.outgoingRequests;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        // The dock floats over the end of the list.
        AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        if (snapshot.friends.isNotEmpty) ...<Widget>[
          Text(
            l10n.campfireTitle.toUpperCase(),
            style: labelStyle(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Campfire(
            people: <UserProjection>[snapshot.me, ...snapshot.friends],
            today: snapshot.today,
            onOpen: (String userId) => _openProfile(context, userId),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                key: const Key('friends-find'),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        const FindFriendsScreen(),
                  ),
                ),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.person_add_alt, size: 19),
                label: Text(l10n.findTitle),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _scan(context, ref),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.qr_code_scanner, size: 19),
                label: Text(l10n.friendsScan),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('friends-enter-code'),
            onPressed: () => enterInviteCode(context, ref),
            child: Text(l10n.inviteEnterCode),
          ),
        ),
        if (requests.isNotEmpty) ...<Widget>[
          SectionHeader(l10n.friendsRequestsTitle,
              subtitle: l10n.friendsRequestsSub),
          for (final FriendLink request in requests)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _IncomingRequestCard(
                key: Key('request-${request.userId}'),
                request: request,
              ),
            ),
        ],
        if (snapshot.friends.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxl),
            child: EmptyState(
              emoji: '👥',
              title: l10n.friendsEmptyTitle,
              body: l10n.friendsEmptyBody,
            ),
          )
        else ...<Widget>[
          nudges.maybeWhen(
            data: (List<NudgeSuggestion> items) => items.isEmpty
                ? const SizedBox.shrink()
                : _NudgeSection(suggestions: items, snapshot: snapshot),
            orElse: () => const SizedBox.shrink(),
          ),
          SectionHeader(l10n.friendsYourPeople),
          for (final UserProjection friend in snapshot.friends)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _FriendRow(
                friend: friend,
                today: snapshot.today,
              ),
            ),
        ],
        if (sent.isNotEmpty) ...<Widget>[
          SectionHeader(l10n.friendsSentTitle, subtitle: l10n.friendsSentSub),
          for (final FriendLink request in sent)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _OutgoingRequestCard(
                key: Key('sent-${request.userId}'),
                request: request,
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          color: AppColors.surfaceHigh,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.lock_outline, size: 19, color: AppColors.social),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  l10n.friendsNetworkNote,
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

  void _openProfile(BuildContext context, String userId) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => FriendDetailScreen(userId: userId),
        ),
      );

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final String? raw = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => const ScanInviteScreen(),
      ),
    );
    if (raw == null || !context.mounted) return;
    await redeemInviteFlow(context, ref, raw);
  }
}

/// Someone asking to be friends: accept, decline, or — for a stranger who
/// should not be asking — report or block.
class _IncomingRequestCard extends ConsumerStatefulWidget {
  const _IncomingRequestCard({super.key, required this.request});

  final FriendLink request;

  @override
  ConsumerState<_IncomingRequestCard> createState() =>
      _IncomingRequestCardState();
}

class _IncomingRequestCardState extends ConsumerState<_IncomingRequestCard> {
  bool _busy = false;

  String get _name => widget.request.displayName.isEmpty
      ? context.l10n.friendsFallbackName
      : widget.request.displayName;

  Future<void> _respond({required bool accept}) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String offline = context.l10n.inviteErrorOffline;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(appStateProvider.notifier)
          .respondToRequest(widget.request, accept: accept);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(offline)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _moderate(String choice) async {
    if (choice == 'report') {
      await reportPerson(context, ref,
          userId: widget.request.userId, name: _name);
    } else {
      await confirmAndBlock(context, ref,
          userId: widget.request.userId, name: _name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final FriendLink request = widget.request;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              EmojiAvatar(request.emoji, size: 40),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Text(
                  l10n.friendsRequestFrom(_name),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              PopupMenuButton<String>(
                key: Key('request-menu-${request.userId}'),
                enabled: !_busy,
                onSelected: _moderate,
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<String>>[
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
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: _busy
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm + 2),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _respond(accept: false),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(40)),
                          child: Text(l10n.friendsRequestDecline),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(40)),
                          onPressed: () => _respond(accept: true),
                          child: Text(l10n.friendsRequestAccept),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// A request the user sent and nobody answered yet — withdrawable.
class _OutgoingRequestCard extends ConsumerStatefulWidget {
  const _OutgoingRequestCard({super.key, required this.request});

  final FriendLink request;

  @override
  ConsumerState<_OutgoingRequestCard> createState() =>
      _OutgoingRequestCardState();
}

class _OutgoingRequestCardState extends ConsumerState<_OutgoingRequestCard> {
  bool _busy = false;

  Future<void> _withdraw(String name) async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      // remove_friend() also withdraws a pending request.
      await ref
          .read(appStateProvider.notifier)
          .removeFriend(widget.request.userId);
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.friendsSentWithdrawn(name))));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.inviteErrorOffline)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String name = widget.request.displayName.isEmpty
        ? l10n.friendsFallbackName
        : widget.request.displayName;
    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          EmojiAvatar(widget.request.emoji, size: 36, dimmed: true),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: () => _withdraw(name),
              child: Text(l10n.friendsSentWithdraw),
            ),
        ],
      ),
    );
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
        SectionHeader(
          context.l10n.friendsNudgeSection,
          subtitle: context.l10n.friendsNudgeSubtitle,
        ),
        for (final NudgeSuggestion suggestion in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _NudgeCard(
              suggestion: suggestion,
              profile: snapshot.profiles[suggestion.targetId],
              alreadySent: snapshot.nudgedToday.contains(suggestion.targetId),
            ),
          ),
      ],
    );
  }
}

class _NudgeCard extends ConsumerStatefulWidget {
  const _NudgeCard({
    required this.suggestion,
    required this.alreadySent,
    this.profile,
  });

  final NudgeSuggestion suggestion;
  final bool alreadySent;
  final PeerProfile? profile;

  @override
  ConsumerState<_NudgeCard> createState() => _NudgeCardState();
}

class _NudgeCardState extends ConsumerState<_NudgeCard> {
  /// A second tap while the first nudge is still being written would send
  /// two: the feed only says "sent" once the first one is in it.
  bool _sending = false;

  Future<void> _send(String text) async {
    // The button may not have rebuilt yet: ask the feed itself.
    final bool sent = ref
            .read(appStateProvider)
            .valueOrNull
            ?.nudgedToday
            .contains(widget.suggestion.targetId) ??
        false;
    if (_sending || sent) return;
    setState(() => _sending = true);
    try {
      puffAt(ref, widget.suggestion.targetId);
      await ref
          .read(appStateProvider.notifier)
          .nudge(widget.suggestion.targetId, text);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String text = l10n.nudgeText(widget.suggestion);
    final bool sent = widget.alreadySent;
    return AppCard(
      border: AppColors.social.withValues(alpha: 0.35),
      child: Row(
        children: <Widget>[
          EmojiAvatar(widget.profile?.avatarEmoji ?? '🙂', size: 38),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.profile?.displayName ?? l10n.friendsFallbackName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '"$text"',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: sent || _sending ? null : () => _send(text),
            style: FilledButton.styleFrom(
              minimumSize: const Size(86, 40),
              backgroundColor: AppColors.social,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppColors.social.withValues(alpha: 0.25),
              disabledForegroundColor: Colors.white70,
            ),
            child: Text(sent ? l10n.actionSent : l10n.actionSend),
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
    final AppLocalizations l10n = context.l10n;
    final PeerState peer = friend.toPeerState(today: today);
    return AppCard(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              FriendDetailScreen(userId: friend.userId),
        ),
      ),
      child: Row(
        children: <Widget>[
          // Still in a list: one ticker per row would cost more than it
          // shows. The campfire above and the profile flicker.
          FriendFlame(person: friend, today: today, size: 46, alive: false),
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
                      ? l10n.friendsNoActivity
                      : '${l10n.peerActivityLabel(peer.lastActivity)} · '
                          '${l10n.formatRelative(peer.lastActivityAt!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: peer.activeToday
                            ? AppColors.success
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
              StreakCount(peer.currentStreak),
              Text(
                l10n.friendsDayNumber(peer.dayNumber),
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
