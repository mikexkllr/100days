import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// Camera scanner for an invite QR, with a paste fallback.
///
/// The fallback matters: cameras get denied, codes get sent over chat, and a
/// friend request that only works face to face is a friend request that often
/// does not happen.
class ScanInviteScreen extends StatefulWidget {
  const ScanInviteScreen({super.key});

  @override
  State<ScanInviteScreen> createState() => _ScanInviteScreenState();
}

class _ScanInviteScreenState extends State<ScanInviteScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final Barcode barcode in capture.barcodes) {
      final String? raw = barcode.rawValue;
      if (raw == null) continue;
      if (!raw.startsWith('${Invite.scheme}://')) continue;
      _handled = true;
      Navigator.of(context).pop(raw);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Code scannen'),
        actions: <Widget>[
          IconButton(
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (
                    BuildContext context,
                    MobileScannerException error,
                    Widget? _,
                  ) =>
                      _CameraUnavailable(error: error),
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 236,
                      height: 236,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.flame, width: 3),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: <Widget>[
                Text(
                  'Halte die Kamera auf den QR-Code deines Freundes.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _pasteLink(context),
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('Stattdessen Link einfügen'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteLink(BuildContext context) async {
    final String? link = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => const _PasteDialog(),
    );
    if (link == null || !context.mounted) return;
    Navigator.of(context).pop(link);
  }
}

class _PasteDialog extends StatefulWidget {
  const _PasteDialog();

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Einladungslink'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'hundreddays://invite?d=…',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
          onPressed: () =>
              Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Verbinden'),
        ),
      ],
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      emoji: '📷',
      title: 'Kamera nicht verfügbar',
      body: 'Ohne Kamerazugriff geht es auch: lass dir den Einladungslink '
          'schicken und füge ihn unten ein.\n\n${error.errorCode.name}',
    );
  }
}
