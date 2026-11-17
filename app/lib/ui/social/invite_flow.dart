import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// Shows whose invite [raw] is, asks once, and makes both friends.
///
/// [raw] may be a scanned QR code, a pasted link or a typed code. Used by the
/// scanner, the "enter code" field and incoming invite links alike.
Future<void> redeemInviteFlow(
  BuildContext context,
  WidgetRef ref,
  String raw,
) async {
  final AppLocalizations l10n = context.l10n;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final AppRepository repository = ref.read(repositoryProvider);

  InvitePreview? preview;
  try {
    preview = await repository.previewInvite(raw);
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.inviteErrorOffline)));
    return;
  }
  if (preview == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.inviteErrorMalformed)));
    return;
  }
  if (preview.userId == repository.userId) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.inviteErrorSelf)));
    return;
  }
  if (repository.follows.contains(preview.userId)) {
    messenger.showSnackBar(SnackBar(
        content: Text(l10n.inviteAlreadyFriends(preview.displayName))));
    return;
  }
  if (!context.mounted) return;

  final InvitePreview owner = preview;
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      backgroundColor: AppColors.surface,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          EmojiAvatar(owner.emoji, size: 64, ringColor: AppColors.primary),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.inviteConfirmTitle(owner.displayName),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.inviteConfirmBody,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.inviteConfirmAction),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await ref.read(appStateProvider.notifier).redeemInvite(raw);
    messenger.showSnackBar(
        SnackBar(content: Text(l10n.friendsConnected(owner.displayName))));
  } on InviteRejection catch (rejection) {
    messenger.showSnackBar(SnackBar(
      content: Text(switch (rejection.problem) {
        InviteProblem.self => l10n.inviteErrorSelf,
        InviteProblem.offline => l10n.inviteErrorOffline,
        InviteProblem.invalid => l10n.inviteErrorMalformed,
      }),
    ));
  }
}

/// A field for typing a friend's code by hand.
Future<void> enterInviteCode(BuildContext context, WidgetRef ref) async {
  final TextEditingController controller = TextEditingController();
  final String? code = await showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(context.l10n.inviteEnterCode),
      content: TextField(
        key: const Key('invite-code-field'),
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(hintText: context.l10n.inviteCodeHint),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(context.l10n.actionConnect),
        ),
      ],
    ),
  );
  controller.dispose();
  if (code == null || code.trim().isEmpty || !context.mounted) return;
  await redeemInviteFlow(context, ref, code);
}
