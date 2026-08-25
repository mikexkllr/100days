import 'dart:async';

import '../identity/identity.dart';
import 'event.dart';
import 'feed_store.dart';

/// Serialises appends to the local feed.
///
/// Two concurrent check-ins that both read `head.seq == 41` would both try to
/// write 42 and one would tear the chain, so every local write goes through
/// the single-entry queue here.
class FeedWriter {
  FeedWriter({required this.identity, required this.store});

  final Identity identity;
  final FeedStore store;

  /// Completes when the append currently in flight has finished. Null when the
  /// writer is idle.
  ///
  /// Deliberately *not* seeded with a `Future.value()` at construction: that
  /// binds the whole chain to whatever zone built the writer, and an append
  /// issued from a different zone then never runs. Creating the link at call
  /// time keeps each append in its caller's zone.
  Future<void>? _pending;

  Future<FeedEvent> append(
    String type,
    Map<String, dynamic> payload, {
    DateTime? timestamp,
  }) async {
    final previous = _pending;
    final gate = Completer<void>();
    _pending = gate.future;

    try {
      // Two concurrent check-ins that both read `head.seq == 41` would both
      // try to write 42 and tear the chain, so appends are serialised.
      if (previous != null) await previous;

      final head = await store.head(identity.did);
      final event = await FeedEvent.create(
        identity: identity,
        seq: (head?.seq ?? 0) + 1,
        prevHash: head?.hash,
        type: type,
        payload: payload,
        timestamp: timestamp,
      );
      await store.append(event);
      return event;
    } finally {
      // Never completes with an error: a failed append must not poison every
      // append queued behind it.
      gate.complete();
      if (identical(_pending, gate.future)) _pending = null;
    }
  }
}

/// Applies events received from peers.
///
/// Validation happens here and only here, so there is exactly one place where
/// untrusted bytes become trusted state.
class FeedReplicator {
  FeedReplicator(this.store);

  final FeedStore store;

  /// Applies [incoming] in order, stopping at the first event that fails
  /// validation — after a break, everything downstream of it is unverifiable
  /// anyway, so continuing would let a peer inject a forged tail.
  Future<ReplicationReport> apply(
    Iterable<FeedEvent> incoming, {
    DateTime? now,
  }) async {
    var applied = 0;
    var skipped = 0;
    final rejections = <EventRejection>[];

    final ordered = incoming.toList()
      ..sort((FeedEvent a, FeedEvent b) {
        final byAuthor = a.author.compareTo(b.author);
        return byAuthor != 0 ? byAuthor : a.seq.compareTo(b.seq);
      });

    final blocked = <String>{};
    for (final event in ordered) {
      if (blocked.contains(event.author)) {
        skipped++;
        continue;
      }
      final head = await store.head(event.author);
      if (head != null && event.seq <= head.seq) {
        skipped++;
        continue;
      }
      if ((head?.seq ?? 0) + 1 != event.seq) {
        // A gap: we are missing an ancestor, so we cannot verify the chain.
        // The next sync round will request the missing range.
        blocked.add(event.author);
        skipped++;
        continue;
      }
      final previous =
          head == null ? null : await store.eventAt(event.author, head.seq);
      final result =
          await validateEvent(event, previous: previous, now: now);
      if (!result.isValid) {
        rejections.add(result.rejection!);
        blocked.add(event.author);
        continue;
      }
      await store.append(event);
      applied++;
    }

    return ReplicationReport(
      applied: applied,
      skipped: skipped,
      rejections: rejections,
    );
  }
}

class ReplicationReport {
  const ReplicationReport({
    required this.applied,
    required this.skipped,
    required this.rejections,
  });

  final int applied;
  final int skipped;
  final List<EventRejection> rejections;

  bool get hasRejections => rejections.isNotEmpty;

  @override
  String toString() =>
      'ReplicationReport(applied: $applied, skipped: $skipped, '
      'rejected: ${rejections.length})';
}
