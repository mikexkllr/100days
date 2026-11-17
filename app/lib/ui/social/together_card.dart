import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// What two friends have together: the days in a row both showed up, and
/// this week's shared quest.
class TogetherCard extends StatelessWidget {
  const TogetherCard({
    super.key,
    required this.me,
    required this.friend,
    required this.today,
  });

  final UserProjection me;
  final UserProjection friend;
  final DayKey today;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final int streak = friendStreak(a: me, b: friend, today: today);
    final FriendQuest quest = friendQuest(me: me, friend: friend, today: today);

    return AppCard(
      key: const Key('together-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('🤝', style: TextStyle(fontSize: 26)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  streak == 0
                      ? l10n.togetherNoStreak(friend.profile.displayName)
                      : l10n.togetherStreak(streak),
                  style: text.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.questTitle(quest.target), style: text.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: AppRadius.pill,
            child: LinearProgressIndicator(
              value: quest.fraction,
              minHeight: 8,
              backgroundColor: AppColors.surfaceHigh,
              color: quest.done ? AppColors.success : AppColors.social,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            quest.done
                ? l10n.questDone
                : l10n.questProgress(quest.mine, quest.theirs,
                    friend.profile.displayName),
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
