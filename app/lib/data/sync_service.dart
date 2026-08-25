import 'dart:async';

import 'package:hundred_core/hundred_core.dart';

/// What just happened on the network, for the status line in the UI.
class SyncEvent {
  const SyncEvent({
    required this.transportId,
    required this.result,
    required this.at,
    this.peerName,
  });

  final String transportId;
  final SyncResult result;
  final DateTime at;
  final String? peerName;

  bool get broughtSomething => result.received > 0;
}

/// Drives replication across every enabled transport.
///
/// Sync is opportunistic by design: whenever a peer shows up — a beacon on the
/// Wi-Fi, an inbound connection, a manual pull — we run one round and hang up.
/// There is no persistent connection to babysit and no server to be down.
class SyncService {
  SyncService({
    required this.store,
    required this.replicator,
    required this.localDid,
    required this.localDisplayName,
    required this.followedDids,
    this.minInterval = const Duration(seconds: 20),
  });

  final FeedStore store;
  final FeedReplicator replicator;
  final String localDid;
  final String Function() localDisplayName;

  /// Read lazily: the follow set changes while the service is running.
  final Set<String> Function() followedDids;

  /// Rate limit per peer. A phone announcing itself every five seconds must
  /// not trigger a sync round every five seconds.
  final Duration minInterval;

  final List<PeerTransport> _transports = <PeerTransport>[];
  final List<StreamSubscription<Object>> _subscriptions =
      <StreamSubscription<Object>>[];
  final Map<String, DateTime> _lastSyncByPeer = <String, DateTime>{};
  final Set<String> _inFlight = <String>{};

  final StreamController<SyncEvent> _events =
      StreamController<SyncEvent>.broadcast();

  final Map<String, DiscoveredPeer> _knownPeers = <String, DiscoveredPeer>{};

  Stream<SyncEvent> get events => _events.stream;

  List<DiscoveredPeer> get knownPeers => _knownPeers.values.toList();

  bool get isRunning => _transports.isNotEmpty;

  Future<void> addTransport(PeerTransport transport) async {
    _transports.add(transport);
    await transport.start();

    _subscriptions.add(transport.incoming.listen((PeerSession session) {
      unawaited(_runRound(transport.id, session, peerName: 'eingehend'));
    }));

    _subscriptions.add(transport.discoveries.listen((DiscoveredPeer peer) {
      final did = peer.did;
      if (did != null) _knownPeers[did] = peer;
      unawaited(_maybeConnect(transport, peer));
    }));
  }

  /// Forces a round with every peer we currently know about.
  Future<List<SyncEvent>> syncNow() async {
    final results = <SyncEvent>[];
    for (final transport in _transports) {
      for (final peer in _knownPeers.values.where(
          (DiscoveredPeer p) => p.transportId == transport.id)) {
        final event = await _connectAndSync(transport, peer, force: true);
        if (event != null) results.add(event);
      }
    }
    return results;
  }

  /// Connects to a peer we learned about from a scanned invite rather than
  /// from discovery.
  Future<SyncEvent?> syncWithAddress(String transportId, String address) async {
    final transport = _transports.firstWhere(
      (PeerTransport t) => t.id == transportId,
      orElse: () => throw StateError('Unknown transport $transportId'),
    );
    return _connectAndSync(
      transport,
      DiscoveredPeer(transportId: transportId, address: address),
      force: true,
    );
  }

  Future<void> _maybeConnect(
    PeerTransport transport,
    DiscoveredPeer peer,
  ) async {
    final did = peer.did;
    if (did != null && !followedDids().contains(did)) {
      // Seen but not befriended: discovery is public, replication is not.
      return;
    }
    await _connectAndSync(transport, peer);
  }

  Future<SyncEvent?> _connectAndSync(
    PeerTransport transport,
    DiscoveredPeer peer, {
    bool force = false,
  }) async {
    final key = '${transport.id}:${peer.address}';
    if (_inFlight.contains(key)) return null;
    if (!force) {
      final last = _lastSyncByPeer[key];
      if (last != null && DateTime.now().difference(last) < minInterval) {
        return null;
      }
    }

    _inFlight.add(key);
    try {
      final session = await transport.connect(peer);
      return await _runRound(
        transport.id,
        session,
        peerName: peer.displayName,
      );
    } on Object catch (error) {
      final event = SyncEvent(
        transportId: transport.id,
        peerName: peer.displayName,
        at: DateTime.now(),
        result: SyncResult(
          peerDid: peer.did,
          received: 0,
          sent: 0,
          rejections: const <EventRejection>[],
          error: error,
        ),
      );
      if (!_events.isClosed) _events.add(event);
      return event;
    } finally {
      _lastSyncByPeer[key] = DateTime.now();
      _inFlight.remove(key);
    }
  }

  Future<SyncEvent> _runRound(
    String transportId,
    PeerSession session, {
    String? peerName,
  }) async {
    final syncer = Syncer(
      store: store,
      replicator: replicator,
      localDid: localDid,
      localDisplayName: localDisplayName(),
      followedDids: <String>{localDid, ...followedDids()},
    );
    final result = await syncer.run(session);
    final event = SyncEvent(
      transportId: transportId,
      peerName: peerName,
      at: DateTime.now(),
      result: result,
    );
    if (!_events.isClosed) _events.add(event);
    return event;
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    for (final transport in _transports) {
      await transport.stop();
    }
    _transports.clear();
    await _events.close();
  }
}
