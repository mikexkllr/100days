import 'dart:async';

/// A peer we could talk to, however we found them.
class DiscoveredPeer {
  const DiscoveredPeer({
    required this.transportId,
    required this.address,
    this.did,
    this.displayName,
  });

  /// Which transport produced this: `lan`, `ble`, `relay`, `manual`.
  final String transportId;

  /// Transport-specific address (`192.168.1.42:47100`, a relay URL, …).
  final String address;

  /// Known only after a handshake for anonymous transports like mDNS.
  final String? did;
  final String? displayName;

  @override
  String toString() => 'DiscoveredPeer($transportId $address ${did ?? ''})';
}

/// A bidirectional, message-framed channel with exactly one peer.
abstract class PeerSession {
  /// Decoded protocol frames from the remote side.
  Stream<Map<String, dynamic>> get messages;

  Future<void> send(Map<String, dynamic> message);

  Future<void> close();

  bool get isOpen;
}

/// A way of reaching peers.
///
/// The app ships a LAN transport (mDNS + TCP) because gym buddies and
/// flatmates are physically near each other, and that path needs no
/// infrastructure at all. Wide-area transports (relay, WebRTC) plug in behind
/// the same interface without the sync layer knowing.
abstract class PeerTransport {
  String get id;

  String get displayName;

  bool get isRunning;

  /// Peers this transport can currently see.
  Stream<DiscoveredPeer> get discoveries;

  /// Sessions opened by remote peers.
  Stream<PeerSession> get incoming;

  Future<void> start();

  Future<PeerSession> connect(DiscoveredPeer peer);

  Future<void> stop();
}
