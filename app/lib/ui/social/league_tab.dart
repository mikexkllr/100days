import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
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
              AppColors.violet.withValues(alpha: 0.2),
              AppColors.surface,
            ],
          ),
          border: AppColors.violet.withValues(alpha: 0.4),
          child: Row(
            children: <Widget>[
              Text(standing.league.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${standing.league.nameDe}-Liga',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      'Woche ${standing.weekKey} · '
                      '${standing.entries.length} Teilnehmer',
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
                      'dein Platz',
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
              'Eine Liga mit einer Person ist nur eine Liste. Verbinde '
              'Freunde, dann fängt der Wettkampf an.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
        const SectionHeader('Diese Woche'),
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
          'XP gibt es pro Check-in, skaliert mit Schwierigkeit und Streak. '
          'Am Sonntag steigen die oberen Plätze auf, die unteren ab.',
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
    final Color? zone = promoting
        ? AppColors.lime
        : demoting
            ? AppColors.danger
            : null;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      border: isMe ? AppColors.flame : zone?.withValues(alpha: 0.35),
      color: isMe ? AppColors.flame.withValues(alpha: 0.07) : AppColors.surface,
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
            ringColor: entry.activeToday ? AppColors.lime : null,
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
                        isMe ? '${entry.displayName} (du)' : entry.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (entry.currentStreak > 0) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${entry.currentStreak}🔥',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
                Text(
                  entry.activeToday
                      ? 'Heute schon aktiv'
                      : 'Heute noch nichts',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: entry.activeToday
                            ? AppColors.lime
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
                  style: Theme.of(context).textTheme.titleLarge),
              Text(
                'XP',
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
