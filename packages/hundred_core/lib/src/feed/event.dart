import 'package:meta/meta.dart';

import '../identity/identity.dart';
import '../util/codec.dart';

/// The event types that make up a user's feed. Everything the app knows about
/// a person — their challenge, their check-ins, their misses — is derived by
/// folding these in order.
class FeedEventType {
  static const String profile = 'profile';
  static const String challengeStarted = 'challenge.started';
  static const String challengeAscended = 'challenge.ascended';
  static const String checkIn = 'checkin';
  static const String missed = 'missed';
  static const String streakFreeze = 'streak.freeze';
  static const String nudge = 'nudge';
  static const String cheer = 'cheer';
  static const String friendRequest = 'friend.request';

  static const Set<String> all = <String>{
    profile,
    challengeStarted,
    challengeAscended,
    checkIn,
    missed,
    streakFreeze,
    nudge,
    cheer,
    friendRequest,
  };
}

/// One entry in an append-only, hash-chained, signed feed.
///
/// The chain is what makes a streak worth bragging about: because every event
/// commits to the hash of its predecessor and the whole body is signed, a peer
/// can prove nobody spliced a workout into last Tuesday after the fact. It is
/// the same structure as a single-writer blockchain, minus the consensus — no
/// global ordering is needed because each DID only ever writes its own feed.
@immutable
class FeedEvent {
  const FeedEvent({
    required this.author,
    required this.seq,
    required this.prevHash,
    required this.timestamp,
    required this.type,
    required this.payload,
    required this.hash,
    required this.signature,
  });

  factory FeedEvent.fromJson(Map<String, dynamic> json) => FeedEvent(
        author: json['author'] as String,
        seq: (json['seq'] as num).toInt(),
        prevHash: json['prev'] as String?,
        timestamp:
            DateTime.parse(json['timestamp'] as String).toUtc(),
        type: json['type'] as String,
        payload: Map<String, dynamic>.from(
            json['payload'] as Map? ?? const <String, dynamic>{}),
        hash: json['hash'] as String,
        signature: json['sig'] as String,
      );

  /// DID of the only account allowed to append to this feed.
  final String author;

  /// 1-based position in the author's feed. Gaps are not permitted.
  final int seq;

  /// Hash of event `seq - 1`, or null for the genesis event.
  final String? prevHash;

  final DateTime timestamp;
  final String type;
  final Map<String, dynamic> payload;
  final String hash;
  final String signature;

  /// The exact bytes that get hashed and signed.
  static String canonicalBody({
    required String author,
    required int seq,
    required String? prevHash,
    required DateTime timestamp,
    required String type,
    required Map<String, dynamic> payload,
  }) =>
      canonicalJson(<String, Object?>{
        'author': author,
        'seq': seq,
        'prev': prevHash,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'type': type,
        'payload': payload,
      });

  String get body => canonicalBody(
        author: author,
        seq: seq,
        prevHash: prevHash,
        timestamp: timestamp,
        type: type,
        payload: payload,
      );

  /// Builds, hashes and signs the next event for [identity].
  static Future<FeedEvent> create({
    required Identity identity,
    required int seq,
    required String? prevHash,
    required String type,
    required Map<String, dynamic> payload,
    DateTime? timestamp,
  }) async {
    final ts = (timestamp ?? DateTime.now()).toUtc();
    final body = canonicalBody(
      author: identity.did,
      seq: seq,
      prevHash: prevHash,
      timestamp: ts,
      type: type,
      payload: payload,
    );
    final hash = sha256Hex(body);
    return FeedEvent(
      author: identity.did,
      seq: seq,
      prevHash: prevHash,
      timestamp: ts,
      type: type,
      payload: payload,
      hash: hash,
      signature: await identity.sign(hash),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'author': author,
        'seq': seq,
        'prev': prevHash,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'type': type,
        'payload': payload,
        'hash': hash,
        'sig': signature,
      };

  @override
  String toString() => 'FeedEvent($type #$seq by ${Identity.shortDid(author)})';

  @override
  bool operator ==(Object other) => other is FeedEvent && other.hash == hash;

  @override
  int get hashCode => hash.hashCode;
}

/// Why an incoming event was refused. Peers are untrusted, so every rejection
/// reason is something a malicious or buggy peer can actually trigger.
enum EventRejection {
  unknownType,
  badHash,
  badSignature,
  seqOutOfOrder,
  chainBroken,
  timestampRegression,
  timestampInFuture,
}

class EventValidationResult {
  const EventValidationResult.ok()
      : rejection = null,
        isValid = true;
  const EventValidationResult.rejected(EventRejection this.rejection)
      : isValid = false;

  final bool isValid;
  final EventRejection? rejection;
}

/// Tolerance for peers whose clocks run ahead of ours. Anything beyond this is
/// treated as an attempt to claim tomorrow's check-in today.
const Duration kClockSkewTolerance = Duration(minutes: 10);

/// Validates an event against the previous event in the same feed.
///
/// [previous] must be `null` exactly when [event] is the genesis event.
Future<EventValidationResult> validateEvent(
  FeedEvent event, {
  required FeedEvent? previous,
  DateTime? now,
}) async {
  if (!FeedEventType.all.contains(event.type)) {
    return const EventValidationResult.rejected(EventRejection.unknownType);
  }
  if (sha256Hex(event.body) != event.hash) {
    return const EventValidationResult.rejected(EventRejection.badHash);
  }

  final reference = (now ?? DateTime.now()).toUtc();
  if (event.timestamp.isAfter(reference.add(kClockSkewTolerance))) {
    return const EventValidationResult.rejected(
        EventRejection.timestampInFuture);
  }

  if (previous == null) {
    if (event.seq != 1) {
      return const EventValidationResult.rejected(EventRejection.seqOutOfOrder);
    }
    if (event.prevHash != null) {
      return const EventValidationResult.rejected(EventRejection.chainBroken);
    }
  } else {
    if (event.seq != previous.seq + 1) {
      return const EventValidationResult.rejected(EventRejection.seqOutOfOrder);
    }
    if (event.prevHash != previous.hash) {
      return const EventValidationResult.rejected(EventRejection.chainBroken);
    }
    if (event.timestamp.isBefore(previous.timestamp)) {
      return const EventValidationResult.rejected(
          EventRejection.timestampRegression);
    }
  }

  if (!await Identity.verify(event.author, event.hash, event.signature)) {
    return const EventValidationResult.rejected(EventRejection.badSignature);
  }
  return const EventValidationResult.ok();
}
