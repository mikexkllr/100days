import 'dart:async';

import 'event.dart';

/// Where the head of a feed currently is. Peers exchange these first during
/// sync so that a fully caught-up pair transfers a few hundred bytes instead
/// of the whole history.
class FeedHead {
  const FeedHead({
    required this.did,
    required this.seq,
    required this.hash,
  });

  factory FeedHead.fromJson(Map<String, dynamic> json) => FeedHead(
        did: json['did'] as String,
        seq: (json['seq'] as num).toInt(),
        hash: json['hash'] as String,
      );

  final String did;
  final int seq;
  final String hash;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'did': did, 'seq': seq, 'hash': hash};

  @override
  String toString() => 'FeedHead($did @ $seq)';
}

/// Persistence port for the replicated log. The app ships a SQLite
/// implementation; tests and the sync simulator use [MemoryFeedStore].
abstract class FeedStore {
  Future<FeedHead?> head(String did);

  Future<List<FeedHead>> heads();

  /// Events of [did] with `seq > fromSeqExclusive`, ascending, capped at
  /// [limit] so a peer with a long history cannot force an unbounded frame.
  Future<List<FeedEvent>> eventsAfter(
    String did,
    int fromSeqExclusive, {
    int limit = 500,
  });

  Future<FeedEvent?> eventAt(String did, int seq);

  /// All events across all known feeds, newest first — the social timeline.
  Future<List<FeedEvent>> recent({int limit = 200, Set<String>? types});

  Future<List<FeedEvent>> eventsOf(String did, {Set<String>? types});

  /// Appends an already-validated event. Implementations must reject an event
  /// whose `seq` is not exactly `head.seq + 1`.
  Future<void> append(FeedEvent event);

  /// Emits every event as it lands, whether written locally or replicated in.
  Stream<FeedEvent> get changes;

  Future<void> close();
}

/// Raised when an append would tear the hash chain. Callers should treat this
/// as a bug in their own code: incoming peer events go through
/// [FeedReplicator], which validates before appending.
class FeedAppendException implements Exception {
  const FeedAppendException(this.message);
  final String message;

  @override
  String toString() => 'FeedAppendException: $message';
}

class MemoryFeedStore implements FeedStore {
  final Map<String, List<FeedEvent>> _feeds = <String, List<FeedEvent>>{};
  final StreamController<FeedEvent> _controller =
      StreamController<FeedEvent>.broadcast();

  @override
  Future<void> append(FeedEvent event) async {
    final feed = _feeds.putIfAbsent(event.author, () => <FeedEvent>[]);
    if (event.seq != feed.length + 1) {
      throw FeedAppendException(
        'Expected seq ${feed.length + 1} for ${event.author}, got ${event.seq}',
      );
    }
    feed.add(event);
    _controller.add(event);
  }

  @override
  Stream<FeedEvent> get changes => _controller.stream;

  @override
  Future<FeedEvent?> eventAt(String did, int seq) async {
    final feed = _feeds[did];
    if (feed == null || seq < 1 || seq > feed.length) return null;
    return feed[seq - 1];
  }

  @override
  Future<List<FeedEvent>> eventsAfter(
    String did,
    int fromSeqExclusive, {
    int limit = 500,
  }) async {
    final feed = _feeds[did];
    if (feed == null) return const <FeedEvent>[];
    final start = fromSeqExclusive.clamp(0, feed.length);
    return feed.sublist(start, (start + limit).clamp(0, feed.length));
  }

  @override
  Future<List<FeedEvent>> eventsOf(String did, {Set<String>? types}) async {
    final feed = _feeds[did] ?? const <FeedEvent>[];
    if (types == null) return List<FeedEvent>.unmodifiable(feed);
    return feed.where((FeedEvent e) => types.contains(e.type)).toList();
  }

  @override
  Future<FeedHead?> head(String did) async {
    final feed = _feeds[did];
    if (feed == null || feed.isEmpty) return null;
    final last = feed.last;
    return FeedHead(did: did, seq: last.seq, hash: last.hash);
  }

  @override
  Future<List<FeedHead>> heads() async {
    final result = <FeedHead>[];
    for (final did in _feeds.keys) {
      final h = await head(did);
      if (h != null) result.add(h);
    }
    return result;
  }

  @override
  Future<List<FeedEvent>> recent({int limit = 200, Set<String>? types}) async {
    final all = _feeds.values.expand((List<FeedEvent> e) => e).where(
        (FeedEvent e) => types == null || types.contains(e.type)).toList()
      ..sort((FeedEvent a, FeedEvent b) => b.timestamp.compareTo(a.timestamp));
    return all.take(limit).toList();
  }

  @override
  Future<void> close() async {
    await _controller.close();
  }
}
