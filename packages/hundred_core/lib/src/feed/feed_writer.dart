import 'dart:async';

import 'event.dart';
import 'feed_store.dart';

/// How far ahead of the real time a device's last timestamp may be before
/// the writer stops counting on from it. The server accepts ten minutes.
const Duration kClockTolerance = Duration(minutes: 5);

/// Writes the user's own events into the local store, where they wait as
/// pending until the sync sends them.
///
/// Every write goes through a single-entry queue so that one device's
/// timestamps are strictly increasing: two events written in the same
/// microsecond (a challenge's public view and its private twin) must fold in
/// the order they were written, on every device.
class FeedWriter {
  FeedWriter({required this.author, required this.store, this.onWritten});

  final String author;
  final FeedStore store;

  /// Called after each write — the sync uses it to send soon.
  final void Function(FeedEvent event)? onWritten;

  /// Completes when the write currently in flight has finished. Null when
  /// the writer is idle.
  ///
  /// Deliberately *not* seeded with a `Future.value()` at construction: that
  /// binds the whole chain to whatever zone built the writer, and a write
  /// issued from a different zone then never runs.
  Future<void>? _pending;
  DateTime? _last;

  Future<FeedEvent> append(
    String type,
    Map<String, dynamic> payload, {
    EventVisibility visibility = EventVisibility.friends,
    DateTime? timestamp,
  }) async {
    final previous = _pending;
    final gate = Completer<void>();
    _pending = gate.future;

    try {
      if (previous != null) await previous;

      final now = DateTime.now().toUtc();
      var ts = (timestamp ?? now).toUtc();
      final last = _last ?? await _lastTimestamp();
      // A clock that once ran ahead must not drag every later event into the
      // future with it: the server refuses those, and the whole outbox would
      // wait behind them. Past that tolerance, the order of this device's
      // writes yields to the real time.
      final lastIsSane =
          last != null && !last.isAfter(now.add(kClockTolerance));
      if (lastIsSane && !ts.isAfter(last)) {
        ts = last.add(const Duration(microseconds: 1));
      }
      final event = FeedEvent.create(
        author: author,
        type: type,
        payload: payload,
        visibility: visibility,
        timestamp: ts,
      );
      await store.put(event);
      _last = ts;
      onWritten?.call(event);
      return event;
    } finally {
      // Never completes with an error: a failed write must not poison every
      // write queued behind it.
      gate.complete();
      if (identical(_pending, gate.future)) _pending = null;
    }
  }

  Future<DateTime?> _lastTimestamp() async {
    final own = await store.eventsOf(author);
    return own.isEmpty ? null : own.last.timestamp;
  }
}
