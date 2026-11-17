import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/social_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// This week's group in the public league, or null before the first report.
final FutureProvider<GlobalLeague?> globalLeagueProvider =
    FutureProvider<GlobalLeague?>((Ref ref) async {
  ref.watch(appStateProvider);
  try {
    return await ref
        .watch(repositoryProvider)
        .social
        .league(DayKey.today().isoWeekKey);
  } on Object {
    return null;
  }
});

/// The weekly league with people beyond one's friends: a group of up to 30
/// in a division, the top ones go up on Monday, the bottom ones down.
class GlobalLeagueCard extends ConsumerWidget {
  const GlobalLeagueCard({super.key, required this.myId});

  final String myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final GlobalLeague? league = ref.watch(globalLeagueProvider).valueOrNull;
    if (league == null) {
      return AppCard(
        key: const Key('global-league-empty'),
        child: Text(l10n.globalLeagueEmpty,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
      );
    }

    final League division =
        League.values[league.division.clamp(0, League.values.length - 1)];
    final int size = league.rows.length;
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
                    Text(l10n.globalLeagueSub(size, up, down),
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
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(
                color: row.userId == myId
                    ? AppColors.social.withValues(alpha: 0.12)
                    : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 30,
                    child: Text('${row.rank}',
                        style: text.bodyMedium?.copyWith(
                          color: row.rank <= up
                              ? AppColors.success
                              : row.rank > size - down
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
                  Text(l10n.globalLeagueXp(row.xp),
                      style: text.bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.globalLeagueHonesty,
              style: text.bodySmall?.copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}
