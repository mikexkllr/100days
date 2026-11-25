import 'dart:async';

import 'event.dart';

/// The device's copy of every feed it can read: the user's own and their
/// friends'. The server is the source of truth; this cache is what makes the
/// app work in a basement gym. The user's own events land here first and
/// wait in it (pending) until the sync has sent them.
///
/// The app ships a SQLite implementation; tests use [MemoryFeedStore].
abstract class FeedStore {
  /// Inserts [event], or replaces the stored event with the same id — which
  /// is how a pending event becomes confirmed.
  Future<void> put(FeedEvent event);

  Future<void> putAll(Iterable<FeedEvent> events);

  /// Every stored event of [author] in folding order (see [compareEvents]).
  Future<List<FeedEvent>> eventsOf(String author, {Set<String>? types});

  /// All events across all known feeds, newest first — the social timeline.
  Future<List<FeedEvent>> recent({int limit = 200, Set<String>? types});

  /// The authors with at least one stored event.
  Future<Set<String>> authors();

  /// Events of [author] that the server has not confirmed yet, oldest first.
  Future<List<FeedEvent>> pending(String author);

  /// Where the next pull starts: the highest server sequence number a pull
  /// has fetched up to. Not the highest one stored — the user's own pushed
  /// events, live inserts and a new friend's history all carry numbers far
  /// above rows no pull has fetched yet.
  Future<int> cursor();

  /// Moves the pull cursor. Only a completed pull page does this.
  Future<void> setCursor(int serverSeq);

  /// A small key–value side table for what belongs to this cache but is not
  /// an event: whose cache it is, the last known friend list. Cleared with
  /// [clear].
  Future<String?> meta(String key);

  Future<void> setMeta(String key, String? value);

  /// Forgets everything of [author], e.g. after a friendship ended.
  Future<void> removeAuthor(String author);

  /// Forgets everything, e.g. on sign-out — the cursor and [meta] included.
  Future<void> clear();

  /// Emits every event as it lands, whether written here or pulled in.
  Stream<FeedEvent> get changes;

  Future<void> close();
}

class MemoryFeedStore implements FeedStore {
  final Map<String, FeedEvent> _events = <String, FeedEvent>{};
  final Map<String, String> _meta = <String, String>{};
  int _cursor = 0;
  final StreamController<FeedEvent> _controller =
      StreamController<FeedEvent>.broadcast();

  @override
  Future<void> put(FeedEvent event) async {
    _events[event.id] = event;
    _controller.add(event);
  }

  @override
  Future<void> putAll(Iterable<FeedEvent> events) async {
    for (final event in events) {
      await put(event);
    }
  }

  @override
  Stream<FeedEvent> get changes => _controller.stream;

  @override
  Future<List<FeedEvent>> eventsOf(String author, {Set<String>? types}) async =>
      _events.values
          .where((FeedEvent e) =>
              e.author == author && (types == null || types.contains(e.type)))
          .toList()
        ..sort(compareEvents);

  @override
  Future<List<FeedEvent>> recent({int limit = 200, Set<String>? types}) async {
    final all = _events.values
        .where((FeedEvent e) => types == null || types.contains(e.type))
        .toList()
      ..sort((FeedEvent a, FeedEvent b) => compareEvents(b, a));
    return all.take(limit).toList();
  }

  @override
  Future<Set<String>> authors() async =>
      _events.values.map((FeedEvent e) => e.author).toSet();

  @override
  Future<List<FeedEvent>> pending(String author) async => _events.values
      .where((FeedEvent e) => e.author == author && e.isPending)
      .toList()
    ..sort(compareEvents);

  @override
  Future<int> cursor() async => _cursor;

  @override
  Future<void> setCursor(int serverSeq) async => _cursor = serverSeq;

  @override
  Future<String?> meta(String key) async => _meta[key];

  @override
  Future<void> setMeta(String key, String? value) async {
    if (value == null) {
      _meta.remove(key);
    } else {
      _meta[key] = value;
    }
  }

  @override
  Future<void> removeAuthor(String author) async =>
      _events.removeWhere((String _, FeedEvent e) => e.author == author);

  @override
  Future<void> clear() async {
    _events.clear();
    _meta.clear();
    _cursor = 0;
  }

  @override
  Future<void> close() async {
    await _controller.close();
  }
}
