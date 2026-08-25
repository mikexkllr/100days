import 'dart:async';

import 'transport.dart';

/// In-process transport used by tests and the demo mode.
///
/// Real transports are inherently awkward to test — you cannot spin up two
/// phones on a Wi-Fi network inside a unit test — so the sync logic is
/// verified against this and only the socket plumbing stays untested.
class LoopbackSession implements PeerSession {
  LoopbackSession._(this._outbound, this._inbound);

  /// Creates a connected pair of sessions.
  static (LoopbackSession, LoopbackSession) pair() {
    final a = StreamController<Map<String, dynamic>>();
    final b = StreamController<Map<String, dynamic>>();
    return (
      LoopbackSession._(a, b.stream),
      LoopbackSession._(b, a.stream),
    );
  }

  final StreamController<Map<String, dynamic>> _outbound;
  final Stream<Map<String, dynamic>> _inbound;
  bool _open = true;

  @override
  Stream<Map<String, dynamic>> get messages => _inbound;

  @override
  bool get isOpen => _open;

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (!_open || _outbound.isClosed) return;
    _outbound.add(message);
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    _open = false;
    if (!_outbound.isClosed) await _outbound.close();
  }
}
