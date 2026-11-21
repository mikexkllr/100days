import 'dart:math';

import 'package:meta/meta.dart';

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

  /// The challenge after an edit: a new split, own nutrition targets, a habit
  /// added, a sharing change. Replaces goal and habits, never the history.
  static const String challengeUpdated = 'challenge.updated';

  /// A training session logged set by set.
  static const String workoutLogged = 'workout.logged';

  /// One line of the food diary, and its removal.
  static const String foodLogged = 'food.logged';
  static const String foodRemoved = 'food.removed';

  static const Set<String> all = <String>{
    profile,
    challengeStarted,
    challengeAscended,
    checkIn,
    missed,
    streakFreeze,
    nudge,
    cheer,
    challengeUpdated,
    workoutLogged,
    foodLogged,
    foodRemoved,
  };
}

/// Who may read an event. Enforced by the server (Row Level Security on the
/// `events` table), not by the client.
enum EventVisibility {
  /// Only the author: body stats, nutrition targets, the food diary, habits
  /// kept to oneself.
  private,

  /// The author's accepted friends as well.
  friends,
}

/// How long an event may sit unsent on a phone (a basement gym, a flight)
/// before its claimed time stops being believed. Past this, the time the
/// server received it counts instead — so a "live" check-in cannot be forged
/// by writing it with yesterday's clock and sending it a week later.
const Duration kOfflineGrace = Duration(hours: 48);

/// Tolerance for devices whose clocks run ahead. The server refuses anything
/// further in the future than this.
const Duration kClockSkewTolerance = Duration(minutes: 10);

/// One entry in a user's append-only feed.
///
/// The feed lives in the `events` table. Each account only ever appends to
/// its own feed (the server checks `author = auth.uid()`), nobody can edit
/// or delete an event, and the server stamps when it arrived. A friend's
/// streak is still computed by *your* device, from *their* events — they
/// cannot simply claim a number.
@immutable
class FeedEvent {
  const FeedEvent({
    required this.id,
    required this.author,
    required this.timestamp,
    required this.type,
    required this.payload,
    this.visibility = EventVisibility.friends,
    this.createdAt,
    this.serverSeq,
  });

  /// A new event, not yet sent.
  factory FeedEvent.create({
    required String author,
    required String type,
    required Map<String, dynamic> payload,
    EventVisibility visibility = EventVisibility.friends,
    DateTime? timestamp,
    String? id,
  }) =>
      FeedEvent(
        id: id ?? newEventId(),
        author: author,
        timestamp: (timestamp ?? DateTime.now()).toUtc(),
        type: type,
        payload: payload,
        visibility: visibility,
      );

  /// From a row of the `events` table (or the local cache, which stores the
  /// same columns).
  factory FeedEvent.fromRow(Map<String, dynamic> row) => FeedEvent(
        id: row['id'] as String,
        author: row['author'] as String,
        timestamp: DateTime.parse(row['client_ts'] as String).toUtc(),
        type: row['type'] as String,
        payload: Map<String, dynamic>.from(
            row['payload'] as Map? ?? const <String, dynamic>{}),
        visibility:
            EventVisibility.values.asNameMap()[row['visibility'] as String?] ??
                EventVisibility.private,
        createdAt: row['created_at'] == null
            ? null
            : DateTime.parse(row['created_at'] as String).toUtc(),
        serverSeq: (row['server_seq'] as num?)?.toInt(),
      );

  /// Generated on the device, so an event written offline keeps its identity
  /// when it is sent later, and a retried send is a no-op.
  final String id;

  /// Account id of the only user allowed to append to this feed.
  final String author;

  /// When the device says it happened.
  final DateTime timestamp;
  final String type;
  final Map<String, dynamic> payload;
  final EventVisibility visibility;

  /// When the server received it. Null while it waits in the outbox.
  final DateTime? createdAt;

  /// The server's pull cursor. Null while it waits in the outbox.
  final int? serverSeq;

  bool get isPending => serverSeq == null;

  /// The time to believe: the device's, unless it reached the server far
  /// later than [kOfflineGrace] allows.
  DateTime get loggedAt {
    final received = createdAt;
    if (received != null && received.difference(timestamp) > kOfflineGrace) {
      return received;
    }
    return timestamp;
  }

  /// What the client sends on insert. `created_at` and `server_seq` are the
  /// server's to set.
  Map<String, dynamic> toInsertRow() => <String, dynamic>{
        'id': id,
        'author': author,
        'type': type,
        'payload': payload,
        'visibility': visibility.name,
        'client_ts': timestamp.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toRow() => <String, dynamic>{
        ...toInsertRow(),
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (serverSeq != null) 'server_seq': serverSeq,
      };

  /// The same, not yet sent event at another time — for an outbox entry
  /// whose clock ran ahead of what the server accepts.
  FeedEvent restamped(DateTime timestamp) {
    assert(isPending, 'Only an unsent event may change its time.');
    return FeedEvent(
      id: id,
      author: author,
      timestamp: timestamp.toUtc(),
      type: type,
      payload: payload,
      visibility: visibility,
    );
  }

  /// The same event as confirmed by the server.
  FeedEvent confirmed({required DateTime createdAt, required int serverSeq}) =>
      FeedEvent(
        id: id,
        author: author,
        timestamp: timestamp,
        type: type,
        payload: payload,
        visibility: visibility,
        createdAt: createdAt.toUtc(),
        serverSeq: serverSeq,
      );

  @override
  String toString() => 'FeedEvent($type $id by $author)';

  @override
  bool operator ==(Object other) => other is FeedEvent && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Folding order: the device's clock, then the id. [FeedWriter] keeps the
/// timestamps of one device strictly increasing, so the order a phone wrote
/// its events in is the order every device folds them in.
int compareEvents(FeedEvent a, FeedEvent b) {
  final byTime = a.timestamp.compareTo(b.timestamp);
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}

final Random _random = Random.secure();

/// A random (version 4) UUID.
String newEventId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
