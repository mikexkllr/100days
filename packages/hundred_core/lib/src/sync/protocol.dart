import '../feed/event.dart';
import '../feed/feed_store.dart';

/// Wire protocol for feed replication.
///
/// Deliberately tiny and stateless-per-round: two peers exchange heads, ask
/// for what they are missing, and hang up. There is no server to keep a
/// session on, and a phone that walks out of Wi-Fi range mid-sync must leave
/// both sides in a consistent state — which it does, because every event is
/// independently verifiable.
///
/// Version 2 added the handshake: each side proves it holds the key of the
/// DID it claims before the other side sends anything. A name in a `hello`
/// is a claim; a signature over the other side's fresh nonce is proof.
const int kProtocolVersion = 2;

/// Sent instead of heads when the peer is not someone we follow.
const String kNotFriendsError = 'not-friends';

/// Sent when a peer's handshake signature does not verify.
const String kAuthFailedError = 'auth-failed';

/// What a peer signs to prove it holds [signerDid]'s key in this round.
/// Binding both DIDs keeps a signature from being replayed to someone else.
String authChallenge({
  required String nonce,
  required String signerDid,
  required String verifierDid,
}) =>
    'hundred-days-sync-v2|$nonce|$signerDid|$verifierDid';

class SyncMessageType {
  static const String hello = 'hello';
  static const String auth = 'auth';
  static const String have = 'have';
  static const String want = 'want';
  static const String events = 'events';
  static const String done = 'done';
  static const String error = 'error';
}

/// Hard cap per frame, so a peer cannot force us to buffer their whole
/// history in memory at once.
const int kMaxEventsPerFrame = 200;

abstract class SyncMessage {
  const SyncMessage();

  String get type;

  Map<String, dynamic> toJson();

  static SyncMessage? decode(Map<String, dynamic> json) {
    switch (json['t'] as String?) {
      case SyncMessageType.hello:
        return HelloMessage.fromJson(json);
      case SyncMessageType.auth:
        return AuthMessage(json['sig'] as String? ?? '');
      case SyncMessageType.have:
        return HaveMessage.fromJson(json);
      case SyncMessageType.want:
        return WantMessage.fromJson(json);
      case SyncMessageType.events:
        return EventsMessage.fromJson(json);
      case SyncMessageType.done:
        return const DoneMessage();
      case SyncMessageType.error:
        return ErrorMessage(json['message'] as String? ?? 'unknown');
      default:
        return null;
    }
  }
}

class HelloMessage extends SyncMessage {
  const HelloMessage({
    required this.did,
    required this.displayName,
    this.nonce = '',
    this.avatarEmoji,
    this.protocolVersion = kProtocolVersion,
  });

  factory HelloMessage.fromJson(Map<String, dynamic> json) => HelloMessage(
        did: json['did'] as String,
        displayName: json['name'] as String? ?? 'Anonym',
        nonce: json['nonce'] as String? ?? '',
        avatarEmoji: json['emoji'] as String?,
        protocolVersion: (json['v'] as num?)?.toInt() ?? 1,
      );

  final String did;
  final String displayName;

  /// Fresh randomness the other side has to sign.
  final String nonce;

  /// Shown on a friend request, so "Marcel wants to connect" has a face.
  final String? avatarEmoji;
  final int protocolVersion;

  @override
  String get type => SyncMessageType.hello;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        't': type,
        'did': did,
        'name': displayName,
        'nonce': nonce,
        if (avatarEmoji != null) 'emoji': avatarEmoji,
        'v': protocolVersion,
      };
}

/// Proof of key possession: a signature over [authChallenge] for the other
/// side's nonce.
class AuthMessage extends SyncMessage {
  const AuthMessage(this.signature);

  final String signature;

  @override
  String get type => SyncMessageType.auth;

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'t': type, 'sig': signature};
}

class HaveMessage extends SyncMessage {
  const HaveMessage(this.heads);

  factory HaveMessage.fromJson(Map<String, dynamic> json) => HaveMessage(
        (json['heads'] as List<dynamic>)
            .map((dynamic e) =>
                FeedHead.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  final List<FeedHead> heads;

  @override
  String get type => SyncMessageType.have;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        't': type,
        'heads': heads.map((FeedHead h) => h.toJson()).toList(),
      };
}

class WantRange {
  const WantRange({required this.did, required this.fromSeq});

  factory WantRange.fromJson(Map<String, dynamic> json) => WantRange(
        did: json['did'] as String,
        fromSeq: (json['from'] as num).toInt(),
      );

  final String did;

  /// Exclusive: send me everything with `seq > fromSeq`.
  final int fromSeq;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'did': did, 'from': fromSeq};
}

class WantMessage extends SyncMessage {
  const WantMessage(this.ranges);

  factory WantMessage.fromJson(Map<String, dynamic> json) => WantMessage(
        (json['ranges'] as List<dynamic>)
            .map((dynamic e) =>
                WantRange.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  final List<WantRange> ranges;

  @override
  String get type => SyncMessageType.want;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        't': type,
        'ranges': ranges.map((WantRange r) => r.toJson()).toList(),
      };
}

class EventsMessage extends SyncMessage {
  const EventsMessage(this.events, {this.hasMore = false});

  factory EventsMessage.fromJson(Map<String, dynamic> json) => EventsMessage(
        (json['events'] as List<dynamic>)
            .map((dynamic e) =>
                FeedEvent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        hasMore: json['more'] as bool? ?? false,
      );

  final List<FeedEvent> events;
  final bool hasMore;

  @override
  String get type => SyncMessageType.events;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        't': type,
        'events': events.map((FeedEvent e) => e.toJson()).toList(),
        'more': hasMore,
      };
}

class DoneMessage extends SyncMessage {
  const DoneMessage();

  @override
  String get type => SyncMessageType.done;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'t': type};
}

class ErrorMessage extends SyncMessage {
  const ErrorMessage(this.message);

  final String message;

  @override
  String get type => SyncMessageType.error;

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'t': type, 'message': message};
}
