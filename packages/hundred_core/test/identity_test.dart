import 'package:hundred_core/hundred_core.dart';
import 'package:test/test.dart';

void main() {
  group('Identity', () {
    test('generates a did:key that round-trips to the public key', () async {
      final identity = await Identity.generate();

      expect(identity.did, startsWith('did:key:z'));
      expect(
        Identity.publicKeyFromDid(identity.did),
        equals(identity.publicKeyBytes),
      );
    });

    test('signatures verify against the DID alone', () async {
      final identity = await Identity.generate();
      final signature = await identity.sign('tag 42 im gym');

      expect(
        await Identity.verify(identity.did, 'tag 42 im gym', signature),
        isTrue,
      );
    });

    test('rejects a signature over different content', () async {
      final identity = await Identity.generate();
      final signature = await identity.sign('tag 42 im gym');

      expect(
        await Identity.verify(identity.did, 'tag 43 im gym', signature),
        isFalse,
      );
    });

    test('rejects a signature from another identity', () async {
      final alice = await Identity.generate();
      final mallory = await Identity.generate();
      final signature = await mallory.sign('100 tage clean');

      expect(
        await Identity.verify(alice.did, '100 tage clean', signature),
        isFalse,
      );
    });

    test('recovery key restores the same identity', () async {
      final original = await Identity.generate();
      final restored =
          await Identity.fromRecoveryKey(await original.recoveryKey);

      expect(restored.did, equals(original.did));
      expect(
        await Identity.verify(
          original.did,
          'beweis',
          await restored.sign('beweis'),
        ),
        isTrue,
      );
    });

    test('recovery key tolerates whitespace from copy-paste', () async {
      final original = await Identity.generate();
      final key = await original.recoveryKey;
      final messy = '  ${key.substring(0, 8)} ${key.substring(8)}\n';

      expect((await Identity.fromRecoveryKey(messy)).did, equals(original.did));
    });

    test('rejects a malformed DID', () {
      expect(
        () => Identity.publicKeyFromDid('did:web:example.com'),
        throwsFormatException,
      );
    });

    test('verify returns false rather than throwing on garbage', () async {
      expect(await Identity.verify('not-a-did', 'x', 'y'), isFalse);
    });
  });

  group('base58', () {
    test('round-trips arbitrary bytes including leading zeros', () {
      const List<int> input = <int>[0, 0, 1, 2, 3, 250, 255, 17];
      expect(base58Decode(base58Encode(input)), equals(input));
    });

    test('rejects characters outside the alphabet', () {
      expect(() => base58Decode('abc0def'), throwsFormatException);
    });
  });

  group('canonicalJson', () {
    test('sorts keys so two peers hash the same bytes', () {
      expect(
        canonicalJson(<String, Object?>{'b': 1, 'a': 2}),
        equals(canonicalJson(<String, Object?>{'a': 2, 'b': 1})),
      );
    });

    test('encodes whole doubles as integers', () {
      expect(canonicalJson(<String, Object?>{'v': 3.0}), equals('{"v":3}'));
    });

    test('preserves list order', () {
      expect(canonicalJson(<Object?>[3, 1, 2]), equals('[3,1,2]'));
    });
  });
}
