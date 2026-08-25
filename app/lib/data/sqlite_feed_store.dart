import 'dart:async';
import 'dart:convert';

import 'package:hundred_core/hundred_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite-backed replicated log.
///
/// The primary key is `(author, seq)`, which makes the "one writer per feed,
/// no gaps" rule a database constraint rather than a convention: a bug in the
/// sync layer cannot silently produce a forked feed.
class SqliteFeedStore implements FeedStore {
  SqliteFeedStore._(this._db);

  final Database _db;
  final StreamController<FeedEvent> _changes =
      StreamController<FeedEvent>.broadcast();

  static const int _schemaVersion = 1;

  static Future<SqliteFeedStore> open({String? directory}) async {
    final base = directory ?? await getDatabasesPath();
    final db = await openDatabase(
      p.join(base, 'hundred_days_feed.db'),
      version: _schemaVersion,
      onConfigure: (Database db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE events (
            author      TEXT    NOT NULL,
            seq         INTEGER NOT NULL,
            prev        TEXT,
            ts          TEXT    NOT NULL,
            type        TEXT    NOT NULL,
            payload     TEXT    NOT NULL,
            hash        TEXT    NOT NULL,
            sig         TEXT    NOT NULL,
            received_at TEXT    NOT NULL,
            PRIMARY KEY (author, seq)
          )
        ''');
        await db.execute(
            'CREATE UNIQUE INDEX idx_events_hash ON events (hash)');
        await db.execute('CREATE INDEX idx_events_ts ON events (ts DESC)');
        await db.execute('''
          CREATE TABLE follows (
            did      TEXT PRIMARY KEY,
            name     TEXT,
            emoji    TEXT,
            added_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE kv (
            k TEXT PRIMARY KEY,
            v TEXT NOT NULL
          )
        ''');
      },
    );
    return SqliteFeedStore._(db);
  }

  @override
  Future<void> append(FeedEvent event) async {
    final head = await this.head(event.author);
    if (event.seq != (head?.seq ?? 0) + 1) {
      throw FeedAppendException(
        'Expected seq ${(head?.seq ?? 0) + 1} for ${event.author}, '
        'got ${event.seq}',
      );
    }
    await _db.insert(
      'events',
      <String, Object?>{
        'author': event.author,
        'seq': event.seq,
        'prev': event.prevHash,
        'ts': event.timestamp.toUtc().toIso8601String(),
        'type': event.type,
        'payload': jsonEncode(event.payload),
        'hash': event.hash,
        'sig': event.signature,
        'received_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    _changes.add(event);
  }

  @override
  Stream<FeedEvent> get changes => _changes.stream;

  @override
  Future<FeedEvent?> eventAt(String did, int seq) async {
    final rows = await _db.query(
      'events',
      where: 'author = ? AND seq = ?',
      whereArgs: <Object?>[did, seq],
      limit: 1,
    );
    return rows.isEmpty ? null : _decode(rows.first);
  }

  @override
  Future<List<FeedEvent>> eventsAfter(
    String did,
    int fromSeqExclusive, {
    int limit = 500,
  }) async {
    final rows = await _db.query(
      'events',
      where: 'author = ? AND seq > ?',
      whereArgs: <Object?>[did, fromSeqExclusive],
      orderBy: 'seq ASC',
      limit: limit,
    );
    return rows.map(_decode).toList();
  }

  @override
  Future<List<FeedEvent>> eventsOf(String did, {Set<String>? types}) async {
    final rows = await _db.query(
      'events',
      where: types == null
          ? 'author = ?'
          : 'author = ? AND type IN (${List<String>.filled(
              types.length, '?').join(',')})',
      whereArgs: <Object?>[did, ...?types],
      orderBy: 'seq ASC',
    );
    return rows.map(_decode).toList();
  }

  @override
  Future<FeedHead?> head(String did) async {
    final rows = await _db.query(
      'events',
      columns: <String>['author', 'seq', 'hash'],
      where: 'author = ?',
      whereArgs: <Object?>[did],
      orderBy: 'seq DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FeedHead(
      did: rows.first['author']! as String,
      seq: rows.first['seq']! as int,
      hash: rows.first['hash']! as String,
    );
  }

  @override
  Future<List<FeedHead>> heads() async {
    final rows = await _db.rawQuery('''
      SELECT e.author, e.seq, e.hash
      FROM events e
      JOIN (SELECT author, MAX(seq) AS seq FROM events GROUP BY author) m
        ON e.author = m.author AND e.seq = m.seq
    ''');
    return rows
        .map((Map<String, Object?> r) => FeedHead(
              did: r['author']! as String,
              seq: r['seq']! as int,
              hash: r['hash']! as String,
            ))
        .toList();
  }

  @override
  Future<List<FeedEvent>> recent({int limit = 200, Set<String>? types}) async {
    final rows = await _db.query(
      'events',
      where: types == null
          ? null
          : 'type IN (${List<String>.filled(types.length, '?').join(',')})',
      whereArgs: types?.toList(),
      orderBy: 'ts DESC',
      limit: limit,
    );
    return rows.map(_decode).toList();
  }

  /// Feeds we replicate. The local user is always included by the caller.
  Future<List<FollowRecord>> follows() async {
    final rows = await _db.query('follows', orderBy: 'added_at ASC');
    return rows
        .map((Map<String, Object?> r) => FollowRecord(
              did: r['did']! as String,
              name: r['name'] as String?,
              emoji: r['emoji'] as String?,
              addedAt: DateTime.parse(r['added_at']! as String),
            ))
        .toList();
  }

  Future<void> addFollow(String did, {String? name, String? emoji}) =>
      _db.insert(
        'follows',
        <String, Object?>{
          'did': did,
          'name': name,
          'emoji': emoji,
          'added_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> removeFollow(String did) async {
    await _db.delete('follows', where: 'did = ?', whereArgs: <Object?>[did]);
    // Drop their history too: unfollowing has to actually delete, or the
    // "your data stays on your device" promise is only half true.
    await _db.delete('events', where: 'author = ?', whereArgs: <Object?>[did]);
  }

  Future<String?> getValue(String key) async {
    final rows = await _db
        .query('kv', where: 'k = ?', whereArgs: <Object?>[key], limit: 1);
    return rows.isEmpty ? null : rows.first['v'] as String?;
  }

  Future<void> setValue(String key, String value) => _db.insert(
        'kv',
        <String, Object?>{'k': key, 'v': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// Wipes everything. Used by "Alles löschen" in settings.
  Future<void> wipe() async {
    await _db.delete('events');
    await _db.delete('follows');
    await _db.delete('kv');
  }

  @override
  Future<void> close() async {
    await _changes.close();
    await _db.close();
  }

  FeedEvent _decode(Map<String, Object?> row) => FeedEvent(
        author: row['author']! as String,
        seq: row['seq']! as int,
        prevHash: row['prev'] as String?,
        timestamp: DateTime.parse(row['ts']! as String).toUtc(),
        type: row['type']! as String,
        payload: Map<String, dynamic>.from(
            jsonDecode(row['payload']! as String) as Map),
        hash: row['hash']! as String,
        signature: row['sig']! as String,
      );
}

class FollowRecord {
  const FollowRecord({
    required this.did,
    required this.addedAt,
    this.name,
    this.emoji,
  });

  final String did;
  final DateTime addedAt;
  final String? name;
  final String? emoji;
}
