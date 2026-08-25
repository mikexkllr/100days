import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../util/codec.dart';

/// Multicodec prefix for an Ed25519 public key inside a `did:key`.
const List<int> _ed25519MulticodecPrefix = <int>[0xed, 0x01];

/// A self-sovereign identity. There is no account, no server and no sign-up:
/// the user *is* an Ed25519 keypair generated on device, addressed by a
/// W3C `did:key` DID so other decentralised tooling can resolve it.
class Identity {
  const Identity._(this.did, this._keyPair, this.publicKeyBytes);

  final String did;
  final SimpleKeyPairData _keyPair;
  final Uint8List publicKeyBytes;

  static final Ed25519 _algorithm = Ed25519();

  /// Creates a brand new identity from cryptographically secure randomness.
  static Future<Identity> generate() async {
    final seed = Uint8List(32);
    final random = Random.secure();
    for (var i = 0; i < seed.length; i++) {
      seed[i] = random.nextInt(256);
    }
    return fromSeed(seed);
  }

  /// Rebuilds the identity deterministically from its 32-byte seed. This is
  /// what makes the recovery key work: the seed is the whole account.
  static Future<Identity> fromSeed(List<int> seed) async {
    if (seed.length != 32) {
      throw ArgumentError.value(seed.length, 'seed', 'Seed must be 32 bytes');
    }
    final keyPair = await _algorithm.newKeyPairFromSeed(seed);
    final data = await keyPair.extract();
    final publicKey = await keyPair.extractPublicKey();
    final publicBytes = Uint8List.fromList(publicKey.bytes);
    return Identity._(didFromPublicKey(publicBytes), data, publicBytes);
  }

  /// Restores an identity from the base58 recovery key shown in settings.
  static Future<Identity> fromRecoveryKey(String recoveryKey) async {
    final trimmed = recoveryKey.trim().replaceAll(RegExp(r'\s+'), '');
    final decoded = base58Decode(trimmed);
    if (decoded.length != 32) {
      throw const FormatException('Recovery key does not decode to 32 bytes');
    }
    return fromSeed(decoded);
  }

  Future<String> get recoveryKey async {
    final bytes = await _keyPair.extractPrivateKeyBytes();
    return base58Encode(bytes);
  }

  Future<Uint8List> get seedBytes async =>
      Uint8List.fromList(await _keyPair.extractPrivateKeyBytes());

  /// Signs UTF-8 [message] and returns the signature as base64.
  Future<String> sign(String message) async {
    final signature =
        await _algorithm.sign(utf8.encode(message), keyPair: _keyPair);
    return base64Encode(signature.bytes);
  }

  /// `did:key:z…` encoding of an Ed25519 public key.
  static String didFromPublicKey(List<int> publicKeyBytes) {
    final buffer = Uint8List(_ed25519MulticodecPrefix.length +
        publicKeyBytes.length)
      ..setRange(0, _ed25519MulticodecPrefix.length, _ed25519MulticodecPrefix)
      ..setRange(_ed25519MulticodecPrefix.length, _ed25519MulticodecPrefix.length +
          publicKeyBytes.length, publicKeyBytes);
    return 'did:key:z${base58Encode(buffer)}';
  }

  /// Inverse of [didFromPublicKey]; throws if the DID is not a `did:key`
  /// carrying an Ed25519 multicodec prefix.
  static Uint8List publicKeyFromDid(String did) {
    if (!did.startsWith('did:key:z')) {
      throw FormatException('Unsupported DID method', did);
    }
    final decoded = base58Decode(did.substring('did:key:z'.length));
    if (decoded.length != _ed25519MulticodecPrefix.length + 32 ||
        decoded[0] != _ed25519MulticodecPrefix[0] ||
        decoded[1] != _ed25519MulticodecPrefix[1]) {
      throw FormatException('DID is not an Ed25519 did:key', did);
    }
    return Uint8List.sublistView(decoded, _ed25519MulticodecPrefix.length);
  }

  /// Verifies a base64 [signature] over [message] against any peer's DID.
  /// Returns false rather than throwing on malformed input, because this runs
  /// against bytes handed over by untrusted peers on every sync.
  static Future<bool> verify(
    String did,
    String message,
    String signature,
  ) async {
    try {
      final publicKey = SimplePublicKey(
        publicKeyFromDid(did),
        type: KeyPairType.ed25519,
      );
      return await _algorithm.verify(
        utf8.encode(message),
        signature: Signature(base64Decode(signature), publicKey: publicKey),
      );
    } on Object {
      return false;
    }
  }

  /// Short, human-readable form used in the UI (`z6Mk…9Fq2`).
  static String shortDid(String did) {
    final body = did.startsWith('did:key:') ? did.substring(8) : did;
    if (body.length <= 12) return body;
    return '${body.substring(0, 6)}…${body.substring(body.length - 4)}';
  }
}
