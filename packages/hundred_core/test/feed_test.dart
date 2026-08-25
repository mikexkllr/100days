import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

Future<FeedEvent> _append(
  FeedWriter writer,
  String type,
  Map<String, dynamic> payload, {
  DateTime? at,
}) =>
    writer.append(type, payload, timestamp: at);

/// Fails the first append, then behaves like a normal store.
class _ExplodingStore extends MemoryFeedStore {
  _ExplodingStore({required this.failOnSeq});

  final int failOnSeq;
  bool _exploded = false;

  @override
  Future<void> append(FeedEvent event) async {
    if (!_exploded && event.seq == failOnSeq) {
      _exploded = true;
      throw StateError('disk on fire');
    }
    return super.append(event);
  }
}

void main() {
  late Identity identity;
  late MemoryFeedStore store;
  late FeedWriter writer;

  setUp(() async {
    identity = await Identity.generate();
    store = MemoryFeedStore();
    writer = FeedWriter(identity: identity, store: store);
  });

  group('FeedWriter', () {
    test('builds a hash chain', () async {
      final first = await _append(writer, FeedEventType.profile,
          <String, dynamic>{'displayName': 'Mike'});
      final second = await _append(writer, FeedEventType.checkIn,
          <String, dynamic>{'habitId': 'gym'});

      expect(first.seq, 1);
      expect(first.prevHash, isNull);
      expect(second.seq, 2);
      expect(second.prevHash, equals(first.hash));
    });

    test('a failed append does not poison the ones queued behind it',
        () async {
      final failing = _ExplodingStore(failOnSeq: 1);
      final brokenWriter =
          FeedWriter(identity: identity, store: failing);

      await expectLater(
        brokenWriter.append(FeedEventType.checkIn, <String, dynamic>{}),
        throwsA(isA<StateError>()),
      );

      // The second append must still run rather than waiting forever on the
      // failed one.
      final recovered =
          await brokenWriter.append(FeedEventType.checkIn, <String, dynamic>{});
      expect(recovered.seq, 1);
    });

    test('serialises concurrent appends without tearing the chain', () async {
      final events = await Future.wait<FeedEvent>(<Future<FeedEvent>>[
        for (var i = 0; i < 25; i++)
          writer.append(FeedEventType.checkIn, <String, dynamic>{'i': i}),
      ]);

      final seqs = events.map((FeedEvent e) => e.seq).toList()..sort();
      expect(seqs, equals(List<int>.generate(25, (int i) => i + 1)));

      final stored = await store.eventsOf(identity.did);
      for (var i = 1; i < stored.length; i++) {
        expect(stored[i].prevHash, equals(stored[i - 1].hash));
      }
    });
  });

  group('validateEvent', () {
    test('accepts a well-formed genesis event', () async {
      final event = await _append(
          writer, FeedEventType.profile, <String, dynamic>{'displayName': 'M'});

      final result = await validateEvent(event, previous: null);
      expect(result.isValid, isTrue);
    });

    test('rejects a tampered payload', () async {
      final event = await _append(writer, FeedEventType.checkIn,
          <String, dynamic>{'habitId': 'gym', 'value': 1});
      final forged = FeedEvent(
        author: event.author,
        seq: event.seq,
        prevHash: event.prevHash,
        timestamp: event.timestamp,
        type: event.type,
        payload: <String, dynamic>{'habitId': 'gym', 'value': 99},
        hash: event.hash,
        signature: event.signature,
      );

      final result = await validateEvent(forged, previous: null);
      expect(result.rejection, EventRejection.badHash);
    });

    test('rejects an event signed by someone else', () async {
      final mallory = await Identity.generate();
      final malloryStore = MemoryFeedStore();
      final malloryWriter =
          FeedWriter(identity: mallory, store: malloryStore);
      final stolen = await _append(
          malloryWriter, FeedEventType.checkIn, <String, dynamic>{'x': 1});

      final impostor = FeedEvent(
        author: identity.did,
        seq: stolen.seq,
        prevHash: stolen.prevHash,
        timestamp: stolen.timestamp,
        type: stolen.type,
        payload: stolen.payload,
        hash: stolen.hash,
        signature: stolen.signature,
      );

      // The body commits to the author, so re-labelling breaks the hash first.
      final result = await validateEvent(impostor, previous: null);
      expect(result.rejection, EventRejection.badHash);
    });

    test('rejects an event whose prev hash points elsewhere', () async {
      final first = await _append(
          writer, FeedEventType.profile, <String, dynamic>{'displayName': 'M'});
      final second =
          await _append(writer, FeedEventType.checkIn, <String, dynamic>{});

      expect((await validateEvent(second, previous: first)).isValid, isTrue);

      // A different, genuinely stored predecessor: same author and seq, but a
      // different body, so its hash is not what `second` committed to.
      final divergent = await FeedEvent.create(
        identity: identity,
        seq: 1,
        prevHash: null,
        type: FeedEventType.profile,
        payload: const <String, dynamic>{'displayName': 'Anders'},
      );

      final result = await validateEvent(second, previous: divergent);
      expect(result.rejection, EventRejection.chainBroken);
    });

    test('rejects an event that skips a sequence number', () async {
      final first = await _append(
          writer, FeedEventType.profile, <String, dynamic>{'displayName': 'M'});
      await _append(writer, FeedEventType.checkIn, <String, dynamic>{});
      final third =
          await _append(writer, FeedEventType.checkIn, <String, dynamic>{});

      final result = await validateEvent(third, previous: first);
      expect(result.rejection, EventRejection.seqOutOfOrder);
    });

    test('rejects a check-in dated in the future', () async {
      final event = await _append(
        writer,
        FeedEventType.checkIn,
        <String, dynamic>{'habitId': 'gym'},
        at: DateTime.now().add(const Duration(hours: 6)),
      );

      final result = await validateEvent(event, previous: null);
      expect(result.rejection, EventRejection.timestampInFuture);
    });

    test('rejects an unknown event type', () async {
      final event = await FeedEvent.create(
        identity: identity,
        seq: 1,
        prevHash: null,
        type: 'checkin.premium',
        payload: const <String, dynamic>{},
      );

      final result = await validateEvent(event, previous: null);
      expect(result.rejection, EventRejection.unknownType);
    });
  });

  group('FeedReplicator', () {
    test('applies a peer feed in order', () async {
      final peer = await Identity.generate();
      final peerStore = MemoryFeedStore();
      final peerWriter = FeedWriter(identity: peer, store: peerStore);
      await _append(peerWriter, FeedEventType.profile,
          <String, dynamic>{'displayName': 'Lisa'});
      await _append(
          peerWriter, FeedEventType.checkIn, <String, dynamic>{'habitId': 'g'});

      final report = await FeedReplicator(store)
          .apply(await peerStore.eventsOf(peer.did));

      expect(report.applied, 2);
      expect(report.hasRejections, isFalse);
      expect((await store.head(peer.did))!.seq, 2);
    });

    test('stops at the first invalid event in a feed', () async {
      final peer = await Identity.generate();
      final peerStore = MemoryFeedStore();
      final peerWriter = FeedWriter(identity: peer, store: peerStore);
      final good = await _append(peerWriter, FeedEventType.profile,
          <String, dynamic>{'displayName': 'Lisa'});
      final real = await _append(
          peerWriter, FeedEventType.checkIn, <String, dynamic>{'habitId': 'g'});
      final third = await _append(
          peerWriter, FeedEventType.checkIn, <String, dynamic>{'habitId': 'h'});

      final forged = FeedEvent(
        author: real.author,
        seq: real.seq,
        prevHash: real.prevHash,
        timestamp: real.timestamp,
        type: real.type,
        payload: <String, dynamic>{'habitId': 'gym', 'value': 999},
        hash: real.hash,
        signature: real.signature,
      );

      final report = await FeedReplicator(store)
          .apply(<FeedEvent>[good, forged, third]);

      expect(report.applied, 1);
      expect(report.rejections, contains(EventRejection.badHash));
      expect((await store.head(peer.did))!.seq, 1);
    });

    test('ignores events it already has', () async {
      final peer = await Identity.generate();
      final peerStore = MemoryFeedStore();
      final peerWriter = FeedWriter(identity: peer, store: peerStore);
      await _append(peerWriter, FeedEventType.profile,
          <String, dynamic>{'displayName': 'Lisa'});
      final events = await peerStore.eventsOf(peer.did);

      final replicator = FeedReplicator(store);
      await replicator.apply(events);
      final second = await replicator.apply(events);

      expect(second.applied, 0);
      expect(second.skipped, 1);
    });

    test('holds back events that arrive before their ancestor', () async {
      final peer = await Identity.generate();
      final peerStore = MemoryFeedStore();
      final peerWriter = FeedWriter(identity: peer, store: peerStore);
      await _append(peerWriter, FeedEventType.profile,
          <String, dynamic>{'displayName': 'Lisa'});
      final second = await _append(
          peerWriter, FeedEventType.checkIn, <String, dynamic>{'habitId': 'g'});

      final report = await FeedReplicator(store).apply(<FeedEvent>[second]);

      expect(report.applied, 0);
      expect(await store.head(peer.did), isNull);
    });
  });
}
