import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/social_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';

/// Asks once, then blocks [userId]: the friendship and any request end on
/// the server, and the next sync takes their feed off this device. True when
/// they are blocked now.
Future<bool> confirmAndBlock(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
}) async {
  final AppLocalizations l10n = context.l10n;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(l10n.moderationBlockTitle(name)),
      content: Text(l10n.moderationBlockBody(name)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('block-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            minimumSize: const Size(120, 44),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.moderationBlock),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  return _block(ref, messenger, l10n, userId: userId, name: name);
}

Future<bool> _block(
  WidgetRef ref,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n, {
  required String userId,
  required String name,
}) async {
  try {
    await ref.read(repositoryProvider).social.blockUser(userId);
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.inviteErrorOffline)));
    return false;
  }
  messenger.showSnackBar(SnackBar(content: Text(l10n.moderationBlocked(name))));
  // Their feed leaves this device now, not with the next sync; the sync
  // then picks up the friend list without them.
  try {
    await ref.read(repositoryProvider).store.removeAuthor(userId);
    await ref.read(appStateProvider.notifier).syncNow();
  } on Object {
    // The next sync does it.
  }
  return true;
}

/// Lets the user tell the operator about [userId], and optionally block
/// them in the same step. True when they ended up blocked.
Future<bool> reportPerson(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
}) async {
  final AppLocalizations l10n = context.l10n;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final ({ReportReason reason, String details, bool block})? report =
      await showDialog<({ReportReason reason, String details, bool block})>(
    context: context,
    builder: (BuildContext context) => _ReportDialog(name: name),
  );
  if (report == null) return false;
  try {
    await ref.read(repositoryProvider).social.reportUser(
          userId,
          reason: report.reason,
          details: report.details,
        );
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.inviteErrorOffline)));
    return false;
  }
  messenger.showSnackBar(SnackBar(content: Text(l10n.moderationReported)));
  if (!report.block) return false;
  return _block(ref, messenger, l10n, userId: userId, name: name);
}

/// Report and block for someone the user sees but may not know: a search
/// result, a stranger in the league. True when they ended up blocked.
Future<bool> showPersonActions(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
}) async {
  final AppLocalizations l10n = context.l10n;
  final String? choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (BuildContext context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            title: Text(name, style: Theme.of(context).textTheme.titleMedium),
          ),
          ListTile(
            key: const Key('person-report'),
            leading: const Icon(Icons.flag_outlined),
            title: Text(l10n.moderationReport),
            onTap: () => Navigator.of(context).pop('report'),
          ),
          ListTile(
            key: const Key('person-block'),
            leading: const Icon(Icons.block, color: AppColors.danger),
            title: Text(l10n.moderationBlock,
                style: const TextStyle(color: AppColors.danger)),
            onTap: () => Navigator.of(context).pop('block'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return false;
  return choice == 'report'
      ? reportPerson(context, ref, userId: userId, name: name)
      : confirmAndBlock(context, ref, userId: userId, name: name);
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.name});

  final String name;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final TextEditingController _details = TextEditingController();
  ReportReason? _reason;
  bool _block = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  String _label(AppLocalizations l10n, ReportReason reason) => switch (reason) {
        ReportReason.spam => l10n.moderationReasonSpam,
        ReportReason.harassment => l10n.moderationReasonHarassment,
        ReportReason.inappropriate => l10n.moderationReasonInappropriate,
        ReportReason.cheating => l10n.moderationReasonCheating,
        ReportReason.other => l10n.moderationReasonOther,
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(l10n.moderationReportTitle(widget.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.moderationReportBody(widget.name),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (ReportReason? reason) =>
                  setState(() => _reason = reason),
              child: Column(
                children: <Widget>[
                  for (final ReportReason reason in ReportReason.values)
                    RadioListTile<ReportReason>(
                      key: Key('report-${reason.name}'),
                      value: reason,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(_label(l10n, reason)),
                    ),
                ],
              ),
            ),
            TextField(
              key: const Key('report-details'),
              controller: _details,
              maxLength: 1000,
              maxLines: 3,
              minLines: 1,
              decoration:
                  InputDecoration(hintText: l10n.moderationReportDetails),
            ),
            CheckboxListTile(
              key: const Key('report-also-block'),
              contentPadding: EdgeInsets.zero,
              value: _block,
              onChanged: (bool? on) => setState(() => _block = on ?? false),
              title: Text(l10n.moderationAlsoBlock),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('report-send'),
          onPressed: _reason == null
              ? null
              : () => Navigator.of(context).pop((
                    reason: _reason!,
                    details: _details.text.trim(),
                    block: _block,
                  )),
          child: Text(l10n.moderationReportSend),
        ),
      ],
    );
  }
}
