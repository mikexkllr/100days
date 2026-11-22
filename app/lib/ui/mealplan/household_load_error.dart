import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/household_providers.dart';
import '../../theme/theme.dart';

/// What the plan, the list and the household screen show when the
/// household could not be loaded: what happened, and a button that starts
/// over from the household's id — a failed one would otherwise stay cached
/// for the session, and none of these screens can be pulled.
class HouseholdLoadError extends ConsumerWidget {
  const HouseholdLoadError({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.householdLoadFailed,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('household-retry'),
              onPressed: () => retryHousehold(ref),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.actionRetry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tells the user a household write did not go through. The screens put
/// their optimistic change back before they call this.
void showHouseholdSaveFailed(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(context.l10n.householdSaveFailed)));
}
