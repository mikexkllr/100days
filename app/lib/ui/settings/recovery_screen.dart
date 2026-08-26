import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// Shows the recovery key, behind one deliberate tap.
///
/// It stays hidden by default because this string *is* the account: anyone who
/// photographs it over your shoulder can sign check-ins as you forever.
class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({super.key});

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  bool _revealed = false;
  String? _key;

  Future<void> _reveal() async {
    final String key = await ref.read(repositoryProvider).recoveryKey();
    if (!mounted) return;
    setState(() {
      _key = key;
      _revealed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recoveryTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          AppCard(
            border: AppColors.danger.withValues(alpha: 0.45),
            color: AppColors.danger.withValues(alpha: 0.07),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.danger, size: 20),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Text(
                    l10n.recoveryWarning,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!_revealed)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: <Widget>[
                  const Icon(Icons.visibility_off_outlined,
                      size: 40, color: AppColors.textTertiary),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.recoveryLookAround,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _reveal,
                    child: Text(l10n.recoveryShow),
                  ),
                ],
              ),
            )
          else ...<Widget>[
            AppCard(
              child: Column(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: _key!,
                      version: QrVersions.auto,
                      size: 190,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SelectableText(
                    _key!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontFamily: 'monospace',
                          letterSpacing: 0.6,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _key!));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.recoveryCopied)),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: Text(l10n.actionCopy),
            ),
          ],
          SectionHeader(l10n.recoveryWhereTitle),
          _Tip(emoji: '🔐', text: l10n.recoveryTip1),
          _Tip(emoji: '📄', text: l10n.recoveryTip2),
          _Tip(emoji: '🚫', text: l10n.recoveryTip3),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.emoji, required this.text});

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
