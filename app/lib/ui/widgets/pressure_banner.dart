import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../theme/theme.dart';
import 'app_card.dart';

/// The guilt engine, rendered.
///
/// Shows exactly who moved today while you did not. Names and faces, not a
/// count — "3 Freunde waren aktiv" is a statistic; "Marcel war heute im Gym"
/// is a reason to put your shoes on.
class PressureBanner extends StatelessWidget {
  const PressureBanner({
    super.key,
    required this.activePeers,
    required this.doneToday,
    this.onTap,
  });

  final List<PeerState> activePeers;
  final bool doneToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (activePeers.isEmpty) return const SizedBox.shrink();
    final AppLocalizations l10n = context.l10n;

    final bool behind = !doneToday;
    final Color accent = behind ? AppColors.violet : AppColors.lime;

    return AppCard(
      onTap: onTap,
      border: accent.withValues(alpha: 0.45),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          accent.withValues(alpha: 0.16),
          AppColors.surface.withValues(alpha: 0.9),
        ],
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: (activePeers.length.clamp(1, 4) * 22.0) + 20,
            height: 42,
            child: Stack(
              children: <Widget>[
                for (int i = activePeers.length.clamp(0, 4) - 1; i >= 0; i--)
                  Positioned(
                    left: i * 22,
                    child: EmojiAvatar(
                      activePeers[i].profile.avatarEmoji,
                      size: 42,
                      ringColor: accent,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _headline(l10n),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: accent),
                ),
                const SizedBox(height: 2),
                Text(
                  _body(l10n),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }

  String _headline(AppLocalizations l10n) => activePeers.length == 1
      ? l10n.pressureOneActive(activePeers.first.profile.displayName)
      : l10n.pressureManyActive(activePeers.length);

  String _body(AppLocalizations l10n) {
    if (doneToday) return l10n.pressureBodyDone;
    final PeerState leader = activePeers.first;
    return l10n.pressureBodyBehind(
      l10n.peerActivityLabel(leader.lastActivity),
      leader.currentStreak,
    );
  }
}
