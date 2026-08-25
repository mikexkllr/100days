import '../feed/event.dart';
import '../feed/feed_store.dart';

/// Wire protocol for feed replication.
///
/// Deliberately tiny and stateless-per-round: two peers exchange heads, ask
/// for what they are missing, and hang up. There is no server to keep a
/// session on, and a phone that walks out of Wi-Fi range mid-sync must leave
/// both sides in a consistent state — which it does, because every event is
/// independently verifiable.
const int kProtocolVersion = 1;

class SyncMessageType {
  static const String hello = 'hello';
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
    this.protocolVersion = kProtocolVersion,
  });

  factory HelloMessage.fromJson(Map<String, dynamic> json) => HelloMessage(
        did: json['did'] as String,
        displayName: json['name'] as String? ?? 'Anonym',
        protocolVersion: (json['v'] as num?)?.toInt() ?? 1,
      );

  final String did;
  final String displayName;
  final int protocolVersion;

  @override
  String get type => SyncMessageType.hello;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        't': type,
        'did': did,
        'name': displayName,
        'v': protocolVersion,
      };
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
