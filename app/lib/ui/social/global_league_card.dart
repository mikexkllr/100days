import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../data/social_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'moderation.dart';

/// The week and the XP the user reports for it: all the public league card
/// depends on. A check-in changes the XP; a nudge, a sync or a profile edit
/// changes neither and refetches nothing.
({String week, int xp, bool reporting})? _leagueKey(AsyncValue<AppSnapshot> state) {
  final AppSnapshot? snapshot = state.valueOrNull;
  if (snapshot == null) return null;
  final String me = snapshot.userId;
  return (
    week: snapshot.today.isoWeekKey,
    xp: snapshot.league.entries
            .where((LeagueEntry e) => e.userId == me)
            .firstOrNull
            ?.weeklyXp ??
        0,
    reporting: snapshot.hasChallenge,
  );
}

/// This week's group in the public league, or null before the first report.
///
/// Fetched when the card opens and when the week or the user's XP changes —
/// and only after this XP was reported, so the standing never shows the
/// number from before the check-in that triggered it. Disposed with the
/// card, so a failed fetch is not kept for the session.
final AutoDisposeFutureProvider<GlobalLeague?> globalLeagueProvider =
    FutureProvider.autoDispose<GlobalLeague?>((Ref ref) async {
  final ({String week, int xp, bool reporting})? key =
      ref.watch(appStateProvider.select(_leagueKey));
  if (key == null) return null;
  final AppRepository repository = ref.watch(repositoryProvider);
  final AppSnapshot? snapshot = ref.read(appStateProvider).valueOrNull;
  // Sends nothing when this XP is already reported for this week.
  if (key.reporting && snapshot != null) {
    await repository.reportLeagueXp(snapshot);
  }
  return repository.social.league(key.week);
});

/// The weekly league with people beyond one's friends: a group of up to 30
/// in a division, closed on Monday — the top ones go up, the bottom ones
/// down.
class GlobalLeagueCard extends ConsumerWidget {
  const GlobalLeagueCard({super.key, required this.myId});

  final String myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final AsyncValue<GlobalLeague?> async = ref.watch(globalLeagueProvider);
    if (async.hasError && !async.hasValue) {
      return AppCard(
        key: const Key('global-league-offline'),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(l10n.inviteErrorOffline,
                  style:
                      text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => ref.invalidate(globalLeagueProvider),
              child: Text(l10n.actionRetry),
            ),
          ],
        ),
      );
    }
    final GlobalLeague? league = async.valueOrNull;
    if (league == null) {
      return AppCard(
        key: const Key('global-league-empty'),
        child: async.isLoading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Text(l10n.globalLeagueEmpty,
                style:
                    text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
      );
    }

    final League division =
        League.values[league.division.clamp(0, League.values.length - 1)];
    // The whole group counts, also anyone hidden from this list by a block:
    // the server promotes and demotes by the same numbers.
    final int size = league.groupSize;
    final int up = promotionSlots(size);
    final int down = demotionSlots(size);
    final GlobalLeagueRow? me =
        league.rows.where((GlobalLeagueRow r) => r.userId == myId).firstOrNull;

    return AppCard(
      key: const Key('global-league'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(division.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.leagueTitle(l10n.leagueName(division)),
                        style: text.titleLarge),
                    Text(
                        '${l10n.globalLeagueSize(size)} · '
                        '${switch ((up, down)) {
                          (0, _) => l10n.globalLeagueMovesNone,
                          (_, 0) => l10n.globalLeagueMovesUp(up),
                          _ => l10n.globalLeagueMoves(up, down),
                        }}',
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (me != null)
                Text('#${me.rank}', style: text.headlineSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final GlobalLeagueRow row in league.rows)
            _Row(
              row: row,
              isMe: row.userId == myId,
              // Moves up only with XP to show for the week, as on the server.
              promoting: row.rank <= up && row.xp > 0,
              demoting: row.rank > size - down,
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.globalLeagueHonesty,
              style: text.bodySmall?.copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

/// One person of the group. A stranger's row opens report and block.
class _Row extends ConsumerWidget {
  const _Row({
    required this.row,
    required this.isMe,
    required this.promoting,
    required this.demoting,
  });

  final GlobalLeagueRow row;
  final bool isMe;
  final bool promoting;
  final bool demoting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme text = Theme.of(context).textTheme;
    void actions() => showPersonActions(context, ref,
        userId: row.userId, name: row.displayName);

    return InkWell(
      key: Key('league-row-${row.userId}'),
      borderRadius: BorderRadius.circular(10),
      onTap: isMe ? null : actions,
      onLongPress: isMe ? null : actions,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isMe ? AppColors.social.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 30,
              child: Text('${row.rank}',
                  style: text.bodyMedium?.copyWith(
                    color: promoting
                        ? AppColors.success
                        : demoting
                            ? AppColors.hot
                            : AppColors.textSecondary,
                  )),
            ),
            Text(row.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(row.displayName,
                  overflow: TextOverflow.ellipsis, style: text.bodyMedium),
            ),
            Text(context.l10n.globalLeagueXp(row.xp),
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
