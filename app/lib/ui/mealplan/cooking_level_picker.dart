import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../theme/theme.dart';

/// How much is made at home, picked where a plan or a recipe is asked for:
/// three chips, and under them what the chosen one means for the shopping
/// and the cooking.
class CookingLevelPicker extends StatelessWidget {
  const CookingLevelPicker({
    super.key,
    required this.level,
    required this.onChanged,
    this.title = true,
  });

  final CookingLevel level;

  /// Null while something is being written: the chips stay as they are.
  final ValueChanged<CookingLevel>? onChanged;

  /// False where the picker stands under a heading of its own.
  final bool title;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (title) Text(l10n.cookingLevelTitle, style: text.titleSmall),
        Wrap(
          spacing: AppSpacing.xs,
          children: <Widget>[
            for (final CookingLevel option in CookingLevel.values)
              ChoiceChip(
                key: Key('cooking-${option.name}'),
                label: Text(l10n.cookingLevelName(option)),
                selected: level == option,
                // One of three, side by side on a phone: the chosen one
                // is the bright one, without a tick that would push the
                // last chip onto a line of its own.
                showCheckmark: false,
                labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                side: BorderSide(
                  color: level == option
                      ? AppColors.primary
                      : AppColors.glassEdge,
                ),
                onSelected:
                    onChanged == null ? null : (_) => onChanged!(option),
              ),
          ],
        ),
        Text(
          l10n.cookingLevelHint(level),
          style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
