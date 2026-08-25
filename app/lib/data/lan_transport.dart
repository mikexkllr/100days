import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hundred_core/hundred_core.dart';

import 'socket_session.dart';

/// Peer discovery and transport over the local network.
///
/// This is the transport that makes the app work with no infrastructure at
/// all: two phones on the same gym or flat Wi-Fi find each other with a UDP
/// beacon and replicate over TCP. No relay, no account, no bill.
class LanTransport implements PeerTransport {
  LanTransport({
    required this.localDid,
    required this.localName,
    this.port = 47100,
    this.beaconPort = 47101,
    this.beaconInterval = const Duration(seconds: 5),
  });

  static const String multicastGroup = '239.100.100.1';

  final String localDid;
  /// Read lazily: the user can rename themselves while the transport runs.
  final String Function() localName;
  final int port;
  final int beaconPort;
  final Duration beaconInterval;

  ServerSocket? _server;
  RawDatagramSocket? _beacon;
  Timer? _beaconTimer;
  int _boundPort = 0;

  final StreamController<DiscoveredPeer> _discoveries =
      StreamController<DiscoveredPeer>.broadcast();
  final StreamController<PeerSession> _incoming =
      StreamController<PeerSession>.broadcast();

  /// Last time each DID was heard from, so stale entries can age out.
  final Map<String, DateTime> _lastSeen = <String, DateTime>{};

  @override
  String get id => 'lan';

  @override
  String get displayName => 'Lokales Netzwerk';

  @override
  bool get isRunning => _server != null;

  @override
  Stream<DiscoveredPeer> get discoveries => _discoveries.stream;

  @override
  Stream<PeerSession> get incoming => _incoming.stream;

  @override
  Future<void> start() async {
    if (isRunning) return;

    // Port 0 means "any free port" — falling back keeps a second instance on
    // the same device (or a squatting app) from disabling sync entirely.
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    } on SocketException {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    }
    _boundPort = _server!.port;
    _server!.listen(
      (Socket socket) => _incoming.add(SocketPeerSession(socket)),
      onError: (Object _) {},
    );

    try {
      _beacon = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        beaconPort,
        reuseAddress: true,
        reusePort: true,
      );
      _beacon!
        ..broadcastEnabled = true
        ..multicastLoopback = false
        ..joinMulticast(InternetAddress(multicastGroup));
      _beacon!.listen(_onDatagram);
      _beaconTimer = Timer.periodic(beaconInterval, (_) => _announce());
      _announce();
    } on Object {
      // Multicast is blocked on plenty of networks (guest Wi-Fi, some
      // carriers). TCP still works for peers reached via a scanned invite,
      // so a failed beacon must not take the transport down.
      _beacon = null;
    }
  }

  void _announce() {
    final socket = _beacon;
    if (socket == null) return;
    final payload = utf8.encode(jsonEncode(<String, dynamic>{
      'v': kProtocolVersion,
      'did': localDid,
      'name': localName(),
      'port': _boundPort,
    }));
    try {
      socket.send(payload, InternetAddress(multicastGroup), beaconPort);
    } on SocketException {
      // Interface went away mid-announce; the next tick will retry.
    }
  }

  void _onDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _beacon?.receive();
    if (datagram == null) return;
    try {
      final json = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      final did = json['did'] as String?;
      final peerPort = (json['port'] as num?)?.toInt();
      if (did == null || peerPort == null || did == localDid) return;

      _lastSeen[did] = DateTime.now();
      _discoveries.add(DiscoveredPeer(
        transportId: id,
        address: '${datagram.address.address}:$peerPort',
        did: did,
        displayName: json['name'] as String?,
      ));
    } on Object {
      // Some other app on the same multicast port. Ignore it.
    }
  }

  @override
  Future<PeerSession> connect(DiscoveredPeer peer) async {
    final parts = peer.address.split(':');
    if (parts.length != 2) {
      throw FormatException('Not a host:port address', peer.address);
    }
    final socket = await Socket.connect(
      parts[0],
      int.parse(parts[1]),
      timeout: const Duration(seconds: 8),
    );
    return SocketPeerSession(socket);
  }

  int get boundPort => _boundPort;

  /// Addresses this device can be reached at, for embedding in an invite.
  ///
  /// Best-effort: a phone's IP changes with every network, so an invite's
  /// addresses are a shortcut for "we are on the same Wi-Fi right now", not a
  /// durable locator. Discovery is what makes it work afterwards.
  static Future<List<String>> localAddresses(int port) async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      return <String>[
        for (final NetworkInterface interface in interfaces)
          for (final InternetAddress address in interface.addresses)
            '${address.address}:$port',
      ];
    } on Object {
      return const <String>[];
    }
  }

  /// Peers heard from within [within]. Used to grey out friends in the UI.
  Set<String> recentlySeen({Duration within = const Duration(seconds: 30)}) {
    final cutoff = DateTime.now().subtract(within);
    return _lastSeen.entries
        .where((MapEntry<String, DateTime> e) => e.value.isAfter(cutoff))
        .map((MapEntry<String, DateTime> e) => e.key)
        .toSet();
  }

  @override
  Future<void> stop() async {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _beacon?.close();
    _beacon = null;
    await _server?.close();
    _server = null;
  }

  Future<void> dispose() async {
    await stop();
    await _discoveries.close();
    await _incoming.close();
  }
}
