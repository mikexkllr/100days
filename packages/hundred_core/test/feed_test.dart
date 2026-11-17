import 'dart:async';

import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

class _ExplodingStore extends MemoryFeedStore {
  _ExplodingStore(this.failOnCall);

  final int failOnCall;
  int calls = 0;

  @override
  Future<void> put(FeedEvent event) async {
    calls++;
    if (calls == failOnCall) throw StateError('disk full');
    return super.put(event);
  }
}

void main() {
  late MemoryFeedStore store;
  late FeedWriter writer;

  setUp(() {
    store = MemoryFeedStore();
    writer = FeedWriter(author: 'alice', store: store);
  });

  group('FeedWriter', () {
    test('writes pending events with unique ids', () async {
      final first =
          await writer.append(FeedEventType.profile, <String, dynamic>{});
      final second =
          await writer.append(FeedEventType.profile, <String, dynamic>{});
      expect(first.author, 'alice');
      expect(first.isPending, isTrue);
      expect(first.id, isNot(second.id));
      expect(await store.pending('alice'), <FeedEvent>[first, second]);
    });

    test('keeps one device\'s timestamps strictly increasing', () async {
      final at = DateTime.utc(2026, 11, 1, 12);
      final events = <FeedEvent>[
        for (var i = 0; i < 5; i++)
          await writer.append(FeedEventType.checkIn, <String, dynamic>{'i': i},
              timestamp: at),
      ];
      for (var i = 1; i < events.length; i++) {
        expect(events[i].timestamp.isAfter(events[i - 1].timestamp), isTrue);
      }
      final stored = await store.eventsOf('alice');
      expect(stored.map((FeedEvent e) => e.payload['i']), <int>[0, 1, 2, 3, 4]);
    });

    test('concurrent writes are serialised in call order', () async {
      final futures = <Future<FeedEvent>>[
        for (var i = 0; i < 20; i++)
          writer.append(FeedEventType.checkIn, <String, dynamic>{'i': i}),
      ];
      await Future.wait(futures);
      final stored = await store.eventsOf('alice');
      expect(stored.map((FeedEvent e) => e.payload['i']),
          List<int>.generate(20, (int i) => i));
    });

    test('a failed write does not block the ones behind it', () async {
      final failing = _ExplodingStore(1);
      final w = FeedWriter(author: 'alice', store: failing);
      await expectLater(w.append(FeedEventType.profile, <String, dynamic>{}),
          throwsStateError);
      final ok = await w.append(FeedEventType.profile, <String, dynamic>{});
      expect(await failing.eventsOf('alice'), <FeedEvent>[ok]);
    });

    test('tells the sync about every write', () async {
      final written = <FeedEvent>[];
      final w =
          FeedWriter(author: 'alice', store: store, onWritten: written.add);
      final e = await w.append(FeedEventType.profile, <String, dynamic>{});
      expect(written, <FeedEvent>[e]);
    });

    test('continues after the newest stored event, even from another device',
        () async {
      final later = DateTime.now().toUtc().add(const Duration(minutes: 5));
      await store.put(FeedEvent(
        id: 'other-device',
        author: 'alice',
        timestamp: later,
        type: FeedEventType.profile,
        payload: const <String, dynamic>{},
        createdAt: later,
        serverSeq: 7,
      ));
      final fresh = FeedWriter(author: 'alice', store: store);
      final e = await fresh.append(FeedEventType.profile, <String, dynamic>{});
      expect(e.timestamp.isAfter(later), isTrue);
    });
  });

  group('FeedEvent', () {
    test('round-trips through a table row', () {
      final e = FeedEvent.create(
        author: 'alice',
        type: FeedEventType.checkIn,
        payload: <String, dynamic>{'habitId': 'gym'},
        visibility: EventVisibility.private,
      ).confirmed(createdAt: DateTime.utc(2026, 11, 2), serverSeq: 42);
      final back = FeedEvent.fromRow(e.toRow());
      expect(back.id, e.id);
      expect(back.visibility, EventVisibility.private);
      expect(back.serverSeq, 42);
      expect(back.timestamp, e.timestamp);
      expect(back.payload['habitId'], 'gym');
    });

    test('an insert never carries the server\'s columns', () {
      final row = FeedEvent.create(
        author: 'alice',
        type: FeedEventType.profile,
        payload: <String, dynamic>{},
      ).confirmed(createdAt: DateTime.utc(2026), serverSeq: 1).toInsertRow();
      expect(row.containsKey('created_at'), isFalse);
      expect(row.containsKey('server_seq'), isFalse);
    });

    test('ids are random version-4 UUIDs', () {
      final ids = List<String>.generate(100, (_) => newEventId()).toSet();
      expect(ids, hasLength(100));
      expect(
          ids.first,
          matches(RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });

    test('a claimed time is believed within the offline grace', () {
      final claimed = DateTime.utc(2026, 11, 1, 20);
      final e = FeedEvent(
        id: 'x',
        author: 'alice',
        timestamp: claimed,
        type: FeedEventType.checkIn,
        payload: const <String, dynamic>{},
        createdAt: claimed.add(const Duration(hours: 30)),
        serverSeq: 1,
      );
      expect(e.loggedAt, claimed);
    });

    test('an event sent far later counts from when it arrived', () {
      final claimed = DateTime.utc(2026, 11, 1, 20);
      final arrived = claimed.add(const Duration(days: 5));
      final e = FeedEvent(
        id: 'x',
        author: 'alice',
        timestamp: claimed,
        type: FeedEventType.checkIn,
        payload: const <String, dynamic>{},
        createdAt: arrived,
        serverSeq: 1,
      );
      expect(e.loggedAt, arrived);
    });
  });

  group('MemoryFeedStore', () {
    test('confirming replaces the pending copy', () async {
      final e = await writer.append(FeedEventType.profile, <String, dynamic>{});
      await store.put(e.confirmed(createdAt: DateTime.utc(2026), serverSeq: 9));
      expect(await store.pending('alice'), isEmpty);
      expect(await store.cursor(), 9);
      expect(await store.eventsOf('alice'), hasLength(1));
    });

    test('forgets a former friend completely', () async {
      await store.put(FeedEvent.create(
          author: 'bob',
          type: FeedEventType.profile,
          payload: <String, dynamic>{}));
      await writer.append(FeedEventType.profile, <String, dynamic>{});
      await store.removeAuthor('bob');
      expect(await store.authors(), <String>{'alice'});
    });

    test('recent is newest first across authors', () async {
      await store.put(FeedEvent(
          id: 'b',
          author: 'bob',
          timestamp: DateTime.utc(2026, 1, 2),
          type: FeedEventType.profile,
          payload: const <String, dynamic>{}));
      await store.put(FeedEvent(
          id: 'a',
          author: 'alice',
          timestamp: DateTime.utc(2026, 1, 1),
          type: FeedEventType.profile,
          payload: const <String, dynamic>{}));
      expect((await store.recent()).map((FeedEvent e) => e.id),
          <String>['b', 'a']);
    });
  });
}
