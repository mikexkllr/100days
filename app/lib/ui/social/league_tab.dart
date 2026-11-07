import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// Weekly league among your friends.
///
/// Duolingo's mechanic with one deliberate change: the pool is people you
/// actually know, not strangers. Losing to a stranger costs nothing; losing to
/// your flatmate is a conversation at breakfast.
class LeagueTab extends StatelessWidget {
  const LeagueTab({super.key, required this.snapshot});

  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final LeagueStanding standing = snapshot.league;
    final int myRank = standing.rankOf(snapshot.me.did);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        AppCard(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.social.withValues(alpha: 0.2),
              AppColors.surface,
            ],
          ),
          border: AppColors.social.withValues(alpha: 0.4),
          child: Row(
            children: <Widget>[
              Text(standing.league.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.leagueTitle(l10n.leagueName(standing.league)),
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      l10n.leagueWeekAndPeople(
                          standing.weekKey, standing.entries.length),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                    ),
                  ],
                ),
              ),
              if (myRank > 0)
                Column(
                  children: <Widget>[
                    Text('#$myRank',
                        style: Theme.of(context).textTheme.headlineMedium),
                    Text(
                      l10n.leagueYourRank,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (standing.entries.length < 2) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: AppColors.surfaceHigh,
            child: Text(
              l10n.leagueTooSmall,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
        if (standing.entries.length >= 2) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _Podium(
            entries: standing.entries.take(3).toList(),
            meDid: snapshot.me.did,
          ),
        ],
        SectionHeader(l10n.leagueThisWeek),
        for (int i = 0; i < standing.entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _LeagueRow(
              rank: i + 1,
              entry: standing.entries[i],
              isMe: standing.entries[i].did == snapshot.me.did,
              promoting: standing.isPromoting(standing.entries[i].did),
              demoting: standing.isDemoting(standing.entries[i].did),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.leagueFooter,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textTertiary,
                fontSize: 12.5,
              ),
        ),
      ],
    );
  }
}

class _LeagueRow extends StatelessWidget {
  const _LeagueRow({
    required this.rank,
    required this.entry,
    required this.isMe,
    required this.promoting,
    required this.demoting,
  });

  final int rank;
  final LeagueEntry entry;
  final bool isMe;
  final bool promoting;
  final bool demoting;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Color? zone = promoting
        ? AppColors.success
        : demoting
            ? AppColors.danger
            : null;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      border: isMe ? AppColors.primary : zone?.withValues(alpha: 0.35),
      color: isMe ? AppColors.primary : null,
      glow: isMe ? AppColors.primary.withValues(alpha: 0.5) : null,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: zone ?? AppColors.textTertiary,
                  ),
            ),
          ),
          EmojiAvatar(
            entry.avatarEmoji,
            size: 38,
            ringColor: entry.activeToday ? AppColors.success : null,
            dimmed: !entry.activeToday,
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        isMe
                            ? l10n.leagueYouSuffix(entry.displayName)
                            : entry.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (entry.currentStreak > 0) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(Icons.local_fire_department,
                          size: 14, color: AppColors.attention),
                      Text(
                        '${entry.currentStreak}',
                        style: displayStyle(11.5,
                            color: AppColors.attention,
                            weight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
                Text(
                  entry.activeToday
                      ? l10n.leagueActiveToday
                      : l10n.leagueNothingToday,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: entry.activeToday
                            ? AppColors.success
                            : AppColors.textTertiary,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text('${entry.weeklyXp}',
                  style: displayStyle(17, color: AppColors.reward)),
              Text(
                l10n.statXp,
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

/// The top three on pedestals: gold-free, but unmistakably first.
class _Podium extends StatelessWidget {
  const _Podium({required this.entries, required this.meDid});

  final List<LeagueEntry> entries;
  final String meDid;

  @override
  Widget build(BuildContext context) {
    // Second on the left, first in the middle, third on the right.
    final List<int> order = entries.length >= 3
        ? <int>[1, 0, 2]
        : <int>[1, 0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (final int i in order)
          Expanded(
            child: _Pedestal(
              rank: i + 1,
              entry: entries[i],
              isMe: entries[i].did == meDid,
            ),
          ),
      ],
    );
  }
}

class _Pedestal extends StatelessWidget {
  const _Pedestal({required this.rank, required this.entry, required this.isMe});

  final int rank;
  final LeagueEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final Gradient gradient = switch (rank) {
      1 => AppGradients.holo,
      2 => AppGradients.cool,
      _ => AppGradients.plasma,
    };
    final Color glow = switch (rank) {
      1 => AppColors.primary,
      2 => AppColors.cool,
      _ => AppColors.hot,
    };
    final double height = switch (rank) { 1 => 112, 2 => 84, _ => 64 };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (rank == 1)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('👑', style: TextStyle(fontSize: 22)),
            ),
          EmojiAvatar(
            entry.avatarEmoji,
            size: rank == 1 ? 62 : 50,
            ringColor: glow,
          ),
          const SizedBox(height: 6),
          Text(
            entry.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 13.5,
                  color: isMe ? AppColors.primarySoft : AppColors.textPrimary,
                ),
          ),
          Text(
            '${entry.weeklyXp} XP',
            style: displayStyle(11.5,
                color: AppColors.reward, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            height: height,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  glow.withValues(alpha: 0.45),
                  glow.withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(color: glow.withValues(alpha: 0.5)),
              boxShadow: AppShadows.glow(glow, strength: rank == 1 ? 0.8 : 0.4),
            ),
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (Rect bounds) => gradient.createShader(bounds),
              child: Text('$rank', style: displayStyle(rank == 1 ? 34 : 26)),
            ),
          ),
        ],
      ),
    );
  }
}
