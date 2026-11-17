import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What the last sync did, for the settings screen and for notifications
/// about friends who were active.
class SyncReport {
  const SyncReport({
    required this.at,
    this.sent = 0,
    this.received = 0,
    this.error,
  });

  final DateTime at;
  final int sent;
  final int received;
  final Object? error;

  bool get ok => error == null;
  bool get broughtSomething => received > 0;
}

/// Port between the repository and the server's `events` table, so the
/// repository can be tested without a network.
abstract class FeedSync {
  /// Sends what is pending, then fetches what is new.
  Future<SyncReport> syncNow();

  /// Sends soon — called after every local write. Cheap to call often.
  void schedulePush();

  /// The set of authors whose feeds this device may hold: the user and
  /// their accepted friends. Feeds of anyone else are dropped, feeds of new
  /// friends are fetched in full.
  Future<void> setAuthors(Set<String> authors);

  Stream<SyncReport> get reports;

  Future<void> dispose();
}

/// Does nothing: tests, and the app's screens without a server.
class OfflineFeedSync implements FeedSync {
  final StreamController<SyncReport> _reports =
      StreamController<SyncReport>.broadcast();

  @override
  Future<SyncReport> syncNow() async => SyncReport(at: DateTime.now());

  @override
  void schedulePush() {}

  @override
  Future<void> setAuthors(Set<String> authors) async {}

  @override
  Stream<SyncReport> get reports => _reports.stream;

  @override
  Future<void> dispose() => _reports.close();
}

/// [FeedSync] against Supabase.
///
/// - **Push.** Pending events go up in batches with `ON CONFLICT DO
///   NOTHING`: the id is generated on the phone, so a send that timed out
///   and is retried cannot duplicate anything. The server's copy (with
///   `created_at` and `server_seq`) then replaces the pending one.
/// - **Pull.** Everything the user may read with a `server_seq` above the
///   highest one stored. Row Level Security decides what "may read" means;
///   this code never filters by author itself.
/// - **New friends.** Their history predates the cursor, so it is fetched in
///   full once, and remembered as fetched.
/// - **Live.** A realtime subscription delivers new events while the app is
///   open; the pull on resume catches whatever it missed.
class SupabaseFeedSync implements FeedSync {
  SupabaseFeedSync({
    required SupabaseClient client,
    required this.store,
    required this.userId,
  }) : _client = client;

  final SupabaseClient _client;
  final FeedStore store;
  final String userId;

  static const int _pageSize = 500;
  static const int _pushBatch = 100;

  final StreamController<SyncReport> _reports =
      StreamController<SyncReport>.broadcast();
  RealtimeChannel? _channel;
  Timer? _pushTimer;
  Future<SyncReport>? _running;
  Set<String> _authors = <String>{};

  @override
  Stream<SyncReport> get reports => _reports.stream;

  /// Starts listening for new events. Idempotent.
  void start() {
    _channel ??= _client
        .channel('events:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'events',
          callback: _onInsert,
        )
        .subscribe();
  }

  Future<void> _onInsert(PostgresChangePayload payload) async {
    try {
      final FeedEvent event = FeedEvent.fromRow(payload.newRecord);
      if (event.author != userId && !_authors.contains(event.author)) return;
      await store.put(event);
      _reports.add(SyncReport(at: DateTime.now(), received: 1));
    } on Object catch (error) {
      debugPrint('Realtime event ignored: $error');
    }
  }

  @override
  void schedulePush() {
    _pushTimer?.cancel();
    // Short enough to feel instant, long enough to send a check-in and the
    // workout behind it in one request.
    _pushTimer = Timer(const Duration(milliseconds: 800), () {
      unawaited(syncNow());
    });
  }

  @override
  Future<SyncReport> syncNow() =>
      _running ??= _sync().whenComplete(() => _running = null);

  Future<SyncReport> _sync() async {
    var sent = 0;
    var received = 0;
    try {
      sent = await _push();
      received = await _pull();
      final report =
          SyncReport(at: DateTime.now(), sent: sent, received: received);
      _reports.add(report);
      return report;
    } on Object catch (error) {
      final report = SyncReport(
        at: DateTime.now(),
        sent: sent,
        received: received,
        error: error,
      );
      _reports.add(report);
      return report;
    }
  }

  Future<int> _push() async {
    final List<FeedEvent> pending = await store.pending(userId);
    var sent = 0;
    for (var i = 0; i < pending.length; i += _pushBatch) {
      final List<FeedEvent> batch =
          pending.sublist(i, (i + _pushBatch).clamp(0, pending.length));
      await _client.from('events').upsert(
            batch.map((FeedEvent e) => e.toInsertRow()).toList(),
            onConflict: 'id',
            ignoreDuplicates: true,
          );
      final List<Map<String, dynamic>> confirmed = await _client
          .from('events')
          .select('id, created_at, server_seq')
          .inFilter('id', batch.map((FeedEvent e) => e.id).toList());
      final Map<String, Map<String, dynamic>> byId =
          <String, Map<String, dynamic>>{
        for (final Map<String, dynamic> row in confirmed) row['id'] as String: row,
      };
      await store.putAll(<FeedEvent>[
        for (final FeedEvent e in batch)
          if (byId[e.id] case final Map<String, dynamic> row)
            e.confirmed(
              createdAt: DateTime.parse(row['created_at'] as String),
              serverSeq: (row['server_seq'] as num).toInt(),
            ),
      ]);
      sent += byId.length;
    }
    return sent;
  }

  Future<int> _pull() async {
    var cursor = await store.cursor();
    var received = 0;
    while (true) {
      final List<Map<String, dynamic>> rows = await _client
          .from('events')
          .select()
          .gt('server_seq', cursor)
          .order('server_seq')
          .limit(_pageSize);
      if (rows.isEmpty) break;
      final List<FeedEvent> events = rows
          .map(FeedEvent.fromRow)
          // A friendship that ended between two pulls: not ours to keep.
          .where((FeedEvent e) => e.author == userId || _authors.contains(e.author))
          .toList();
      await store.putAll(events);
      received += events.where((FeedEvent e) => e.author != userId).length;
      cursor = (rows.last['server_seq'] as num).toInt();
      if (rows.length < _pageSize) break;
    }
    return received;
  }

  @override
  Future<void> setAuthors(Set<String> authors) async {
    _authors = <String>{...authors}..remove(userId);

    // Former friends: their events leave this device.
    for (final String author in await store.authors()) {
      if (author != userId && !_authors.contains(author)) {
        await store.removeAuthor(author);
      }
    }

    // New friends: everything they ever shared, once.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = 'sync.fetched.$userId';
    final Set<String> fetched = (prefs.getStringList(key) ?? <String>[]).toSet()
      ..retainAll(_authors);
    for (final String author in _authors.difference(fetched)) {
      try {
        await _fetchAll(author);
        fetched.add(author);
      } on Object catch (error) {
        debugPrint('Could not fetch $author yet: $error');
      }
    }
    await prefs.setStringList(key, fetched.toList());
  }

  Future<void> _fetchAll(String author) async {
    var after = 0;
    while (true) {
      final List<Map<String, dynamic>> rows = await _client
          .from('events')
          .select()
          .eq('author', author)
          .gt('server_seq', after)
          .order('server_seq')
          .limit(_pageSize);
      if (rows.isEmpty) return;
      await store.putAll(rows.map(FeedEvent.fromRow));
      after = (rows.last['server_seq'] as num).toInt();
      if (rows.length < _pageSize) return;
    }
  }

  @override
  Future<void> dispose() async {
    _pushTimer?.cancel();
    final RealtimeChannel? channel = _channel;
    _channel = null;
    if (channel != null) await _client.removeChannel(channel);
    await _reports.close();
  }
}
