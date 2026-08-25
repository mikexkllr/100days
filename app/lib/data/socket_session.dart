import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hundred_core/hundred_core.dart';

/// Newline-delimited JSON over a TCP socket.
///
/// Framing is deliberately boring — one JSON object per line — because the
/// protocol has to be implementable by anyone writing a second client, which
/// is the point of an open, serverless network.
class SocketPeerSession implements PeerSession {
  SocketPeerSession(this._socket) {
    _subscription = _socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      _onLine,
      onError: (Object error, StackTrace stack) {
        if (!_controller.isClosed) _controller.addError(error, stack);
      },
      onDone: () {
        _open = false;
        if (!_controller.isClosed) _controller.close();
      },
    );
  }

  /// Anything larger than this is either a bug or an attempt to exhaust our
  /// memory; a legitimate frame of 200 events is well under it.
  static const int maxFrameBytes = 4 * 1024 * 1024;

  final Socket _socket;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>();
  StreamSubscription<String>? _subscription;
  bool _open = true;

  @override
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  @override
  bool get isOpen => _open;

  void _onLine(String line) {
    if (_controller.isClosed) return;
    if (line.isEmpty) return;
    if (line.length > maxFrameBytes) {
      _controller.addError(
        const FormatException('Peer sent an oversized frame'),
      );
      unawaited(close());
      return;
    }
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic>) _controller.add(decoded);
    } on FormatException {
      // A peer speaking gibberish is not worth tearing the app down over;
      // the sync round will simply produce nothing.
    }
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (!_open) return;
    _socket.write('${jsonEncode(message)}\n');
    await _socket.flush();
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    _open = false;
    await _subscription?.cancel();
    if (!_controller.isClosed) await _controller.close();
    try {
      await _socket.close();
    } on SocketException {
      // Already gone.
    }
    _socket.destroy();
  }
}
