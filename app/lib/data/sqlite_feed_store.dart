import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hundred_core/hundred_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The device's copy of every feed it can read, and the outbox of the
/// user's own events that the server has not confirmed yet.
///
/// Same columns as the server's `events` table. A row without `server_seq`
/// is pending; the sync replaces it with the confirmed copy once sent.
class SqliteFeedStore implements FeedStore {
  SqliteFeedStore._(this._db);

  final Database _db;
  final StreamController<FeedEvent> _changes =
      StreamController<FeedEvent>.broadcast();

  /// 2 added the `meta` side table (pull cursor, owner, friend list).
  static const int _schemaVersion = 2;

  /// The cache of the account-based app. The peer-to-peer app before it kept
  /// a signed log in `hundred_days_feed.db`; nothing in it belongs to an
  /// account, so it is removed rather than migrated.
  static const String _fileName = 'hundred_days_cache.db';
  static const String _legacyFileName = 'hundred_days_feed.db';

  static Future<SqliteFeedStore> open({String? directory}) async {
    final base = directory ?? await getDatabasesPath();
    final legacy = File(p.join(base, _legacyFileName));
    if (legacy.existsSync()) await legacy.delete();

    final db = await openDatabase(
      p.join(base, _fileName),
      version: _schemaVersion,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE events (
            id          TEXT PRIMARY KEY,
            author      TEXT    NOT NULL,
            type        TEXT    NOT NULL,
            payload     TEXT    NOT NULL,
            visibility  TEXT    NOT NULL,
            client_ts   TEXT    NOT NULL,
            created_at  TEXT,
            server_seq  INTEGER
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_events_author ON events (author, client_ts)');
        await db.execute('CREATE INDEX idx_events_ts ON events (client_ts DESC)');
        await db.execute('CREATE INDEX idx_events_seq ON events (server_seq)');
        await _createMeta(db);
      },
      onUpgrade: (Database db, int from, int to) async {
        // No pull cursor was kept before: the first sync after the update
        // pulls everything again, which also fetches what the old cursor
        // skipped.
        if (from < 2) await _createMeta(db);
      },
    );
    return SqliteFeedStore._(db);
  }

  static Future<void> _createMeta(Database db) => db.execute('''
        CREATE TABLE IF NOT EXISTS meta (
          key   TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

  static const String _cursorKey = 'pull_cursor';

  @override
  Future<void> put(FeedEvent event) async {
    await _db.insert('events', _encode(event),
        conflictAlgorithm: ConflictAlgorithm.replace);
    _changes.add(event);
  }

  @override
  Future<void> putAll(Iterable<FeedEvent> events) async {
    final list = events.toList();
    if (list.isEmpty) return;
    final batch = _db.batch();
    for (final event in list) {
      batch.insert('events', _encode(event),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    list.forEach(_changes.add);
  }

  @override
  Stream<FeedEvent> get changes => _changes.stream;

  @override
  Future<List<FeedEvent>> eventsOf(String author, {Set<String>? types}) async {
    final rows = await _db.query(
      'events',
      where: types == null
          ? 'author = ?'
          : 'author = ? AND type IN (${List<String>.filled(types.length, '?').join(',')})',
      whereArgs: <Object?>[author, ...?types],
      orderBy: 'client_ts ASC, id ASC',
    );
    return rows.map(_decode).toList();
  }

  @override
  Future<List<FeedEvent>> recent({int limit = 200, Set<String>? types}) async {
    final rows = await _db.query(
      'events',
      where: types == null
          ? null
          : 'type IN (${List<String>.filled(types.length, '?').join(',')})',
      whereArgs: types?.toList(),
      orderBy: 'client_ts DESC, id DESC',
      limit: limit,
    );
    return rows.map(_decode).toList();
  }

  @override
  Future<Set<String>> authors() async {
    final rows = await _db.rawQuery('SELECT DISTINCT author FROM events');
    return rows.map((Map<String, Object?> r) => r['author']! as String).toSet();
  }

  @override
  Future<List<FeedEvent>> pending(String author) async {
    final rows = await _db.query(
      'events',
      where: 'author = ? AND server_seq IS NULL',
      whereArgs: <Object?>[author],
      orderBy: 'client_ts ASC, id ASC',
    );
    return rows.map(_decode).toList();
  }

  @override
  Future<int> cursor() async =>
      int.tryParse(await meta(_cursorKey) ?? '') ?? 0;

  @override
  Future<void> setCursor(int serverSeq) => setMeta(_cursorKey, '$serverSeq');

  @override
  Future<String?> meta(String key) async {
    final rows = await _db.query('meta',
        columns: <String>['value'], where: 'key = ?', whereArgs: <Object?>[key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> setMeta(String key, String? value) async {
    if (value == null) {
      await _db.delete('meta', where: 'key = ?', whereArgs: <Object?>[key]);
    } else {
      await _db.insert('meta', <String, Object?>{'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  @override
  Future<void> removeAuthor(String author) async {
    await _db.delete('events', where: 'author = ?', whereArgs: <Object?>[author]);
  }

  @override
  Future<void> clear() async {
    await _db.delete('events');
    await _db.delete('meta');
  }

  @override
  Future<void> close() async {
    await _changes.close();
    await _db.close();
  }

  Map<String, Object?> _encode(FeedEvent event) => <String, Object?>{
        'id': event.id,
        'author': event.author,
        'type': event.type,
        'payload': jsonEncode(event.payload),
        'visibility': event.visibility.name,
        'client_ts': sortableTimestamp(event.timestamp),
        'created_at': event.createdAt?.toUtc().toIso8601String(),
        'server_seq': event.serverSeq,
      };

  FeedEvent _decode(Map<String, Object?> row) => FeedEvent.fromRow(
        <String, dynamic>{
          ...row,
          'payload': jsonDecode(row['payload']! as String),
        },
      );
}

/// A UTC timestamp with all six fractional digits, so that comparing the
/// text compares the time. `toIso8601String` drops trailing zero
/// microseconds, and `12.5Z` would sort after `12.500001Z`.
String sortableTimestamp(DateTime time) {
  final utc = time.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  final fraction =
      (utc.millisecond * 1000 + utc.microsecond).toString().padLeft(6, '0');
  return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
      '${two(utc.day)}T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}'
      '.${fraction}Z';
}
