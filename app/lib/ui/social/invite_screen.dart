import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_repository.dart';
import '../../data/social_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// The user's invite code, as a QR code, a link and plain text.
final FutureProvider<String> myInviteCodeProvider =
    FutureProvider<String>((Ref ref) => ref.watch(repositoryProvider).myInviteCode());

/// Your invite as a QR code and a link. Whoever redeems it becomes your
/// friend straight away — sharing it is the yes.
class InviteScreen extends ConsumerWidget {
  const InviteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<AppSnapshot> async = ref.watch(appStateProvider);
    final AsyncValue<String> code = ref.watch(myInviteCodeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inviteTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Center(child: Text('$error')),
        data: (AppSnapshot snapshot) => code.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(l10n.inviteErrorOffline, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => ref.invalidate(myInviteCodeProvider),
                    child: Text(l10n.actionRetry),
                  ),
                ],
              ),
            ),
          ),
          data: (String code) {
            final String link = inviteLink(code).toString();
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(
                          data: link,
                          version: QrVersions.auto,
                          size: 232,
                          gapless: true,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        snapshot.me.profile.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SelectableText(
                        _spaced(code),
                        key: const Key('invite-code'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                              color: AppColors.reward,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // A Builder for the button's own box: on an iPad the share
                // sheet is a popover and needs to know where to point.
                Builder(
                  builder: (BuildContext buttonContext) => FilledButton.icon(
                    key: const Key('invite-share'),
                    onPressed: () => Share.share(
                      l10n.inviteShareText(link, code),
                      subject: l10n.inviteShareSubject,
                      sharePositionOrigin: _originOf(buttonContext),
                    ),
                    icon: const Icon(Icons.ios_share, size: 19),
                    label: Text(l10n.actionShare),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.inviteLinkCopied)),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(l10n.actionCopyLink),
                ),
                SectionHeader(l10n.inviteHowTitle),
                _Explainer(emoji: '1️⃣', text: l10n.inviteStep1),
                _Explainer(emoji: '2️⃣', text: l10n.inviteStep2),
                _Explainer(emoji: '3️⃣', text: l10n.inviteStep3),
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  onPressed: () async {
                    final ScaffoldMessengerState messenger =
                        ScaffoldMessenger.of(context);
                    try {
                      await ref
                          .read(repositoryProvider)
                          .social
                          .revokeInviteCodes();
                    } on Object {
                      messenger.showSnackBar(
                          SnackBar(content: Text(l10n.inviteErrorOffline)));
                      return;
                    }
                    ref.invalidate(myInviteCodeProvider);
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.inviteRevoked)),
                    );
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.inviteRevoke),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Where [context]'s widget sits on screen, for the share popover.
  static Rect? _originOf(BuildContext context) {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// `ABCDE23456` → `ABCDE 23456`: easier to read aloud.
  static String _spaced(String code) => code.length <= 5
      ? code
      : '${code.substring(0, 5)} ${code.substring(5)}';
}

class _Explainer extends StatelessWidget {
  const _Explainer({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 17)),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
