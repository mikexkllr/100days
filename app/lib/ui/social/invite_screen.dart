import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_repository.dart';
import '../../data/lan_transport.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// Your invite as a QR code — the whole "add friend" flow, with no server to
/// look anyone up on.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  List<String> _addresses = const <String>[];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final LanTransport? transport = ref.read(lanTransportProvider);
    if (transport == null) return;
    final List<String> addresses =
        await LanTransport.localAddresses(transport.boundPort);
    if (mounted) setState(() => _addresses = addresses);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<AppSnapshot> async = ref.watch(appStateProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inviteTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Center(child: Text('$error')),
        data: (AppSnapshot snapshot) {
          final Invite invite = ref.read(repositoryProvider).inviteForMe(
                displayName: snapshot.me.profile.displayName,
                avatarEmoji: snapshot.me.profile.avatarEmoji,
                addresses: _addresses,
              );
          final String uri = invite.toUri();

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
                        data: uri,
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
                    Text(
                      Identity.shortDid(invite.did),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                            fontFamily: 'monospace',
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () => Share.share(
                  l10n.inviteShareText(uri),
                  subject: l10n.inviteShareSubject,
                ),
                icon: const Icon(Icons.ios_share, size: 19),
                label: Text(l10n.actionShare),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: uri));
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
              if (_addresses.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  color: AppColors.surfaceHigh,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.inviteReachableAt,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      for (final String address in _addresses)
                        Text(
                          address,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
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
