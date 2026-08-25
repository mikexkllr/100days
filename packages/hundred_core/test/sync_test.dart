import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

class _Node {
  _Node(this.identity, this.store)
      : writer = FeedWriter(identity: identity, store: store),
        replicator = FeedReplicator(store);

  static Future<_Node> create() async =>
      _Node(await Identity.generate(), MemoryFeedStore());

  final Identity identity;
  final MemoryFeedStore store;
  final FeedWriter writer;
  final FeedReplicator replicator;

  Syncer syncer({Set<String>? follows}) => Syncer(
        store: store,
        replicator: replicator,
        localDid: identity.did,
        localDisplayName: 'peer',
        followedDids: follows,
        timeout: const Duration(seconds: 5),
      );
}

Future<List<SyncResult>> _sync(
  _Node a,
  _Node b, {
  Set<String>? aFollows,
  Set<String>? bFollows,
}) async {
  final (PeerSession left, PeerSession right) = LoopbackSession.pair();
  return Future.wait(<Future<SyncResult>>[
    a.syncer(follows: aFollows).run(left),
    b.syncer(follows: bFollows).run(right),
  ]);
}

void main() {
  group('Syncer', () {
    test('replicates a feed to a peer that has none of it', () async {
      final alice = await _Node.create();
      final bob = await _Node.create();

      await alice.writer.append(
          FeedEventType.profile, <String, dynamic>{'displayName': 'Alice'});
      await alice.writer
          .append(FeedEventType.checkIn, <String, dynamic>{'habitId': 'gym'});

      final results = await _sync(alice, bob);

      expect(results.every((SyncResult r) => r.isSuccess), isTrue);
      expect((await bob.store.head(alice.identity.did))!.seq, 2);
    });

    test('replicates in both directions in one round', () async {
      final alice = await _Node.create();
      final bob = await _Node.create();

      await alice.writer.append(
          FeedEventType.profile, <String, dynamic>{'displayName': 'Alice'});
      await bob.writer.append(
          FeedEventType.profile, <String, dynamic>{'displayName': 'Bob'});

      await _sync(alice, bob);

      expect(await alice.store.head(bob.identity.did), isNotNull);
      expect(await bob.store.head(alice.identity.did), isNotNull);
    });

    test('a second round transfers nothing new', () async {
      final alice = await _Node.create();
      final bob = await _Node.create();
      await alice.writer.append(
          FeedEventType.profile, <String, dynamic>{'displayName': 'Alice'});

      await _sync(alice, bob);
      final second = await _sync(alice, bob);

      expect(second.fold<int>(0, (int a, SyncResult r) => a + r.received), 0);
    });

    test('catches up only the missing tail', () async {
      final alice = await _Node.create();
      final bob = await _Node.create();
      await alice.writer.append(
          FeedEventType.profile, <String, dynamic>{'displayName': 'Alice'});
      await _sync(alice, bob);

      for (var i = 0; i < 5; i++) {
        await alice.writer.append(
            FeedEventType.checkIn, <String, dynamic>{'habitId': 'gym', 'i': i});
      }
      final second = await _sync(alice, bob);

      final received =
          second.fold<int>(0, (int a, SyncResult r) => a + r.received);
      expect(received, 5);
      expect((await bob.store.head(alice.identity.did))!.seq, 6);
    });

    test('gossips a third party feed through a mutual friend', () async {
      final alice = await _Node.create();
      final bob = await _Node.create();
      final carol = await _Node.create();

      await carol.writer.append(
          FeedEventType.profile, <String, dynamic>{'displayName': 'Carol'});
      await _sync(carol, bob);
      await _sync(bob, alice);

      expect(await alice.store.head(carol.identity.did), isNotNull);
    });

    test('does not accept feeds outside the follow list', () async {
      final alice = await _Node.create();
      final bob = await _Node.create();
      final stranger = await _Node.create();

      await bob.writer.append(
          FeedEventType.profile, <String, dynamic>{'displayName': 'Bob'});
      await stranger.writer.append(
          FeedEventType.profile, <String, dynamic>{'displayName': 'Fremd'});
      await _sync(stranger, bob);

      await _sync(
        alice,
        bob,
        aFollows: <String>{alice.identity.did, bob.identity.did},
      );

      expect(await alice.store.head(stranger.identity.did), isNull);
      expect(await alice.store.head(bob.identity.did), isNotNull);
    });

    test('rejects a forged event without corrupting the local store',
        () async {
      final alice = await _Node.create();
      final bob = await _Node.create();

      await alice.writer.append(
          FeedEventType.profile, <String, dynamic>{'displayName': 'Alice'});
      final real = await alice.writer.append(
          FeedEventType.checkIn, <String, dynamic>{'habitId': 'gym'});

      // Bob's copy of Alice's second event, rewritten to claim a bigger day.
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

      final report = await bob.replicator.apply(<FeedEvent>[
        (await alice.store.eventsOf(alice.identity.did)).first,
        forged,
      ]);

      expect(report.rejections, contains(EventRejection.badHash));
      expect((await bob.store.head(alice.identity.did))!.seq, 1);

      // A clean round afterwards still repairs Bob's copy.
      await _sync(alice, bob);
      expect((await bob.store.head(alice.identity.did))!.seq, 2);
    });

    test('reports a protocol version mismatch instead of hanging', () async {
      final alice = await _Node.create();
      final (PeerSession left, PeerSession right) = LoopbackSession.pair();

      final resultFuture = alice.syncer().run(left);
      right.messages.listen((Map<String, dynamic> _) {});
      await right.send(const HelloMessage(
        did: 'did:key:zFuture',
        displayName: 'Future',
        protocolVersion: 99,
      ).toJson());

      final result = await resultFuture;
      expect(result.isSuccess, isFalse);
    });

    test('transfers a history longer than one frame', () async {
      final alice = await _Node.create();
      final bob = await _Node.create();

      for (var i = 0; i < kMaxEventsPerFrame + 20; i++) {
        await alice.writer
            .append(FeedEventType.checkIn, <String, dynamic>{'i': i});
      }

      await _sync(alice, bob);

      expect(
        (await bob.store.head(alice.identity.did))!.seq,
        kMaxEventsPerFrame + 20,
      );
    });
  });

  group('Invite', () {
    test('round-trips through its URI form', () async {
      final identity = await Identity.generate();
      final invite = Invite(
        did: identity.did,
        displayName: 'Mike',
        avatarEmoji: '🐺',
        addresses: const <String>['192.168.1.20:47100'],
      );

      final parsed = Invite.parse(invite.toUri());

      expect(parsed.did, identity.did);
      expect(parsed.displayName, 'Mike');
      expect(parsed.addresses, <String>['192.168.1.20:47100']);
      expect(parsed.isWellFormed, isTrue);
    });

    test('rejects a foreign URI', () {
      expect(() => Invite.parse('https://example.com/x'), throwsFormatException);
    });

    test('flags an invite whose DID could never verify', () {
      const invite = Invite(
        did: 'did:key:zNotReallyAKey',
        displayName: 'Fake',
        avatarEmoji: '🤖',
      );

      expect(invite.isWellFormed, isFalse);
    });
  });
}
