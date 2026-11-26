import 'package:flutter/material.dart';

import '../../ai/dartantic_llm_client.dart';
import '../../ai/funki/funki.dart';
import '../../l10n/l10n.dart';
import '../../theme/theme.dart';
import '../settings/ai_screen.dart' show showPaywall;
import '../widgets/app_card.dart';

/// Funki's face in a conversation: the flame, small.
class FunkiAvatar extends StatelessWidget {
  const FunkiAvatar({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: 0.16),
        ),
        child: Text('🔥', style: TextStyle(fontSize: size * 0.55)),
      );
}

/// What a turn says: the answer, or why there is none.
String funkiTurnText(AppLocalizations l10n, FunkiTurn turn) {
  if (turn.fromUser) return turn.text;
  return switch (turn.failure) {
    AiFailure.quotaExceeded || AiFailure.premiumOnly => l10n.funkiQuotaUsedUp,
    AiFailure.rateLimited => l10n.aiRateLimited,
    AiFailure.other => l10n.plannerFailed,
    null => turn.text.isEmpty ? l10n.plannerDone : turn.text,
  };
}

/// One message, with the changes it made below it.
class FunkiTurnView extends StatelessWidget {
  const FunkiTurnView({
    super.key,
    required this.turn,
    required this.conversation,
    this.compact = false,
  });

  final FunkiTurn turn;
  final FunkiConversation conversation;

  /// In the one-line question: no avatar, a little tighter.
  final bool compact;

  Future<void> _undo(BuildContext context, FunkiChange change) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String failed = context.l10n.funkiUndoFailed;
    if (!await conversation.undo(change)) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final Widget bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: turn.fromUser
            ? AppColors.social.withValues(alpha: 0.2)
            : AppColors.surfaceHigh,
        borderRadius: AppRadius.cardAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(funkiTurnText(l10n, turn), style: text.bodyMedium),
          if (turn.offersPaywall)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: FilledButton(
                key: const Key('funki-paywall'),
                onPressed: () => showPaywall(context),
                child: Text(l10n.aiPaywallAction),
              ),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment:
          turn.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: <Widget>[
        if (turn.fromUser || compact)
          bubble
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm, right: AppSpacing.xs),
                child: FunkiAvatar(size: 26),
              ),
              Flexible(child: bubble),
            ],
          ),
        for (final FunkiChange change in turn.changes)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  Icon(
                    change.undone ? Icons.undo : Icons.check_circle_outline,
                    size: 18,
                    color: change.undone ? AppColors.textTertiary : AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      change.label,
                      style: change.undone
                          ? text.bodySmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.textTertiary)
                          : text.bodySmall,
                    ),
                  ),
                  if (!change.undone)
                    TextButton(
                      onPressed:
                          change.undoing ? null : () => _undo(context, change),
                      child: Text(l10n.plannerUndo),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// What Funki is good for where he was opened: tapped, it is asked.
List<String> funkiSuggestions(AppLocalizations l10n, FunkiPlace place) =>
    switch (place) {
      FunkiPlace.home => <String>[l10n.funkiSuggestHome1, l10n.funkiSuggestHome2],
      FunkiPlace.diary => <String>[l10n.funkiSuggestDiary1, l10n.funkiSuggestDiary2],
      FunkiPlace.mealPlan => <String>[l10n.funkiSuggestPlan1, l10n.funkiSuggestPlan2],
    };

String funkiHint(AppLocalizations l10n, FunkiPlace place) => switch (place) {
      FunkiPlace.home => l10n.funkiHintHome,
      FunkiPlace.diary => l10n.funkiHintDiary,
      FunkiPlace.mealPlan => l10n.plannerHint,
    };
